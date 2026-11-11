import SwiftUI
import ARKit
import Combine

/// Логика AR-записи трасс
@MainActor
final class RecordViewModel: ObservableObject {
    let controller: ARSessionController
    let project: Project
    let existingRoom: Room?

    @Published var selectedType: RouteType = .electric
    /// Законченные в этой сессии линии
    @Published private(set) var drafts: [DraftRoute] = []
    /// Линия, которую пользователь сейчас ставит
    @Published private(set) var current = DraftRoute(type: .electric)

    @Published var alertMessage: String?
    @Published var savePayload: SavePayload?
    @Published var isCapturing = false

    struct SavePayload {
        let worldMapData: Data
        let preview: UIImage?
    }

    private var cancellables = Set<AnyCancellable>()

    init(request: RecordRequest) {
        project = request.project
        existingRoom = request.room

        // Дописываем трассы в существующую комнату — нужно сначала релокализоваться
        // по её карте, иначе новые точки окажутся в другой системе координат.
        var map: ARWorldMap?
        var loadError: String?
        if let file = request.room?.worldMapFileName {
            do { map = try WorldMapStore.default.loadWorldMap(fileName: file) }
            catch { loadError = error.localizedDescription }
        }
        controller = ARSessionController(worldMap: map)
        alertMessage = loadError

        // Пробрасываем изменения контроллера в SwiftUI
        controller.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        controller.onFrame = { [weak self] in self?.updatePreview() }
        controller.anchorRefresh = { [weak self] positions in self?.showExistingRoutes(positions) }
        showExistingRoutes([:])
    }

    // MARK: - Состояние для интерфейса

    var hint: TrackingHint { controller.hint }
    var mappingStatus: ARFrame.WorldMappingStatus { controller.mappingStatus }
    var isMapped: Bool { controller.mappingStatus == .mapped }
    var needsRelocalization: Bool { !controller.isRelocalized }

    var canPlacePoint: Bool { hint.canPlacePoints && controller.isRelocalized && controller.hit != nil }
    var canUndo: Bool { !current.points.isEmpty || !drafts.isEmpty }
    var canFinishLine: Bool { current.points.count >= 2 }

    private var existingCount: Int { existingRoom?.routes.count ?? 0 }

    var panelTitle: String {
        current.points.isEmpty ? "Тип новой трассы" : "\(current.type.title) · новая линия"
    }

    var statusText: String {
        let saved = Formatters.routes(drafts.count + existingCount)
        return current.points.isEmpty ? "\(saved) сохранено" : "\(saved) · новая линия"
    }

    /// «3,2 м · 3 точки» возле прицела
    var currentLineLabel: String? {
        guard !current.points.isEmpty else { return nil }
        return "\(Formatters.meters(current.length)) · \(Formatters.points(current.points.count))"
    }

    // MARK: - Жизненный цикл

    func start() { controller.start() }
    func stop() { controller.pause() }

    // MARK: - Действия

    func select(_ type: RouteType) {
        selectedType = type
        current.type = type
        render()
    }

    func placePoint() {
        guard canPlacePoint, let hit = controller.hit else { return }
        let anchorID = controller.addAnchor(at: hit)
        current.points.append(DraftPoint(anchorID: anchorID, position: hit.position, normal: hit.normal))
        Haptics.tap()
        render()
    }

    func finishLine() {
        if current.points.count >= 2 {
            drafts.append(current)
        } else {
            // Одиночная точка — не линия, удаляем её якорь из карты
            current.points.forEach { controller.removeAnchor(id: $0.anchorID) }
        }
        current = DraftRoute(type: selectedType)
        render()
    }

    /// Отменяет последнюю точку. Если текущая линия пуста — «открывает» предыдущую.
    func undo() {
        if current.points.isEmpty, let last = drafts.popLast() {
            current = last
            selectedType = last.type
        }
        if let removed = current.points.popLast() {
            controller.removeAnchor(id: removed.anchorID)
        }
        render()
    }

    /// Проверяет готовность карты и готовит данные для экрана сохранения
    func requestSave() {
        if canFinishLine { finishLine() }
        guard !drafts.isEmpty else {
            alertMessage = "Отметьте хотя бы одну трассу: поставьте две точки и нажмите «Закончить линию»."
            return
        }
        guard isMapped else {
            // ARKit ещё не набрал достаточно опорных точек — карта может не узнаться потом
            alertMessage = "Карта комнаты ещё не готова. \(mappingStatus.saveExplanation)"
            Haptics.warning()
            return
        }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                let map = try await controller.captureWorldMap()
                let data = try WorldMapStore.archive(map)
                let preview = await controller.snapshot()
                savePayload = SavePayload(worldMapData: data, preview: preview)
            } catch {
                alertMessage = "Не удалось получить карту: \(error.localizedDescription). Поводите телефоном и попробуйте ещё раз."
            }
        }
    }

    var totalLength: Float { drafts.reduce(0) { $0 + $1.length } + (existingRoom?.totalLength ?? 0) }
    var totalCount: Int { drafts.count + existingCount }

    // MARK: - Отрисовка

    private func render() {
        controller.setDraftRoutes(drafts.map(\.render) + [current.render])
        updatePreview()
    }

    /// «Резинка» от последней точки до прицела
    private func updatePreview() {
        guard let last = current.points.last, let hit = controller.hit else {
            controller.setPreviewSegment(from: nil, to: nil, normal: .zero, type: nil)
            return
        }
        controller.setPreviewSegment(from: last.position, to: hit.position, normal: hit.normal, type: current.type)
    }

    private func showExistingRoutes(_ anchorPositions: [UUID: SIMD3<Float>]) {
        guard let room = existingRoom else { return }
        controller.setSavedRoutes(room.renderRoutes(anchorPositions: anchorPositions), showZones: false)
    }
}

extension Room {
    /// Трассы комнаты для отрисовки. Если якорь восстановлен из карты — берём его
    /// уточнённое положение, иначе сохранённые координаты.
    func renderRoutes(anchorPositions: [UUID: SIMD3<Float>]) -> [RenderRoute] {
        sortedRoutes.map { route in
            RenderRoute(id: route.id, type: route.type, points: route.orderedPoints.map { p in
                RenderPoint(position: anchorPositions[p.anchorID] ?? p.position, normal: p.normal)
            })
        }
    }
}
