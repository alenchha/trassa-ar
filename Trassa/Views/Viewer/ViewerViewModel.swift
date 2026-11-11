import SwiftUI
import ARKit
import Combine

/// Логика AR-просмотра: релокализация по карте, отрисовка трасс, проверка сверления
@MainActor
final class ViewerViewModel: ObservableObject {
    enum Mode { case overview, check }

    let controller: ARSessionController
    let room: Room
    let focusRouteID: UUID?

    @Published var mode: Mode = .overview
    @Published private(set) var drill: DrillCheckResult?
    @Published var loadError: String?

    /// Трассы в текущих мировых координатах (после релокализации)
    private var polylines: [DrillCheck.Polyline] = []
    private var wasDangerous = false
    private var cancellables = Set<AnyCancellable>()

    init(request: ViewRequest) {
        room = request.room
        focusRouteID = request.focusRouteID

        // Загрузка карты: файл → NSKeyedUnarchiver → ARWorldMap → initialWorldMap
        var map: ARWorldMap?
        if let file = room.worldMapFileName {
            do { map = try WorldMapStore.default.loadWorldMap(fileName: file) }
            catch { loadError = error.localizedDescription }
        } else {
            loadError = "У этой комнаты нет сохранённой карты. Запишите трассы заново."
        }
        controller = ARSessionController(worldMap: map)

        controller.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        controller.onFrame = { [weak self] in self?.tick() }
        controller.anchorRefresh = { [weak self] positions in self?.applyRoutes(positions) }
        applyRoutes([:])
    }

    var isSearching: Bool { !controller.isRelocalized }
    var hint: TrackingHint { controller.hint }

    func start() { if loadError == nil { controller.start() } }
    func stop() { controller.pause() }

    func startCheck() {
        mode = .check
        wasDangerous = false
        tick()
    }

    func endCheck() {
        mode = .overview
        drill = nil
        controller.setPreviewSegment(from: nil, to: nil, normal: .zero, type: nil)
    }

    /// Подпись выбранной трассы («Электрика · 3,2 м»)
    var focusLabel: (String, Color)? {
        guard let id = focusRouteID, let route = room.routes.first(where: { $0.id == id }) else { return nil }
        return ("\(route.type.title) · \(Formatters.meters(route.length))", route.type.color)
    }

    private func applyRoutes(_ anchorPositions: [UUID: SIMD3<Float>]) {
        let routes = room.renderRoutes(anchorPositions: anchorPositions)
        polylines = routes.map { DrillCheck.Polyline(type: $0.type, points: $0.points.map(\.position)) }
        controller.setSavedRoutes(routes, showZones: true)
    }

    /// Каждый кадр в режиме проверки: расстояние от точки прицела на стене до ближайшего отрезка
    private func tick() {
        guard mode == .check, controller.isRelocalized else { return }
        guard let hit = controller.hit else {
            drill = nil
            controller.setPreviewSegment(from: nil, to: nil, normal: .zero, type: nil)
            return
        }
        let result = DrillCheck.evaluate(point: hit.position, routes: polylines)
        if result != drill { drill = result }

        // Вибрация только в момент входа в опасную зону, а не каждый кадр
        if result.isDangerous && !wasDangerous { Haptics.danger() }
        wasDangerous = result.isDangerous

        // «Линейка» от прицела до ближайшей трассы
        controller.setPreviewSegment(
            from: hit.position, to: result.nearestPoint, normal: hit.normal, type: nil,
            color: result.isDangerous ? UIColor(hex: 0xFF5D60) : UIColor(hex: 0x52DBA0)
        )
    }
}
