import ARKit
import RealityKit
import Combine
import SwiftUI

/// Точка на стене под прицелом
struct SurfaceHit: Equatable {
    let position: SIMD3<Float>
    /// Нормаль стены, направленная к пользователю
    let normal: SIMD3<Float>
    let transform: simd_float4x4
}

/// Управляет AR-сессией: конфигурация, raycast от центра экрана, якоря,
/// получение ARWorldMap и релокализация по сохранённой карте.
@MainActor
final class ARSessionController: NSObject, ObservableObject {

    let arView: ARView

    @Published private(set) var trackingState: ARCamera.TrackingState = .notAvailable
    @Published private(set) var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published private(set) var hit: SurfaceHit?
    /// true, когда координаты сессии совпали с сохранённой картой
    @Published private(set) var isRelocalized = false
    @Published private(set) var hint = TrackingHint.make(tracking: .notAvailable, mapping: .notAvailable, hasSurface: false)
    @Published var errorMessage: String?

    /// Вызывается ~15 раз в секунду после обновления прицела
    var onFrame: (() -> Void)?

    /// Есть ли LiDAR (поддержка реконструкции сцены)
    let hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    private let initialWorldMap: ARWorldMap?
    private var updateSubscription: Cancellable?
    private var frameCounter = 0

    // Отдельные корневые сущности: сохранённые трассы, черновики, «линейка» до трассы
    private let savedRoot = AnchorEntity(world: .zero)
    private let draftRoot = AnchorEntity(world: .zero)
    private let previewRoot = AnchorEntity(world: .zero)

    private var savedRoutes: [RenderRoute] = []
    private var showSavedZones = false
    private var lastAnchorRefresh = Date.distantPast

    /// - Parameter worldMap: карта комнаты для релокализации (nil — новая запись)
    init(worldMap: ARWorldMap? = nil) {
        self.initialWorldMap = worldMap
        self.arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        super.init()
        // Без карты система координат новая — «релокализоваться» не нужно
        isRelocalized = worldMap == nil
        arView.renderOptions.insert(.disableMotionBlur)
        arView.scene.addAnchor(savedRoot)
        arView.scene.addAnchor(draftRoot)
        arView.scene.addAnchor(previewRoot)
        savedRoot.isEnabled = isRelocalized
    }

    // MARK: - Жизненный цикл

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            errorMessage = "Это устройство не поддерживает AR. Нужен iPhone с процессором A12 или новее."
            return
        }
        let config = ARWorldTrackingConfiguration()
        // Трассы проходят по стенам — ищем только вертикальные плоскости
        config.planeDetection = [.vertical]
        // С LiDAR строим меш комнаты: raycast по estimatedPlane становится точнее,
        // а карта — плотнее. Без LiDAR приложение работает по визуальным точкам.
        if hasLiDAR {
            config.sceneReconstruction = .mesh
        }
        // Релокализация: передаём сохранённую карту. ARKit начнёт в состоянии
        // .limited(.relocalizing) и, узнав комнату по опорным точкам, «совместит»
        // новую систему координат со старой. После этого все ARAnchor из карты
        // (наши точки трасс) окажутся на прежних местах на стене.
        config.initialWorldMap = initialWorldMap

        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        // Событие обновления сцены RealityKit приходит на главном потоке каждый кадр
        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func pause() {
        updateSubscription?.cancel()
        updateSubscription = nil
        arView.session.pause()
    }

    // MARK: - Кадр

    private func tick() {
        frameCounter += 1
        guard frameCounter % 4 == 0 else { return } // ~15 Гц достаточно для интерфейса
        guard let frame = arView.session.currentFrame else { return }

        let mapping = frame.worldMappingStatus
        if mapping != mappingStatus { mappingStatus = mapping }

        let newHit = raycastCenter(cameraPosition: frame.camera.transform.translation)
        if newHit != hit { hit = newHit }

        let newHint = TrackingHint.make(tracking: trackingState, mapping: mapping, hasSurface: hit != nil)
        if newHint != hint { hint = newHint }

        onFrame?()
    }

    /// Raycast из центра экрана (точки прицела) в вертикальную поверхность.
    private func raycastCenter(cameraPosition: SIMD3<Float>) -> SurfaceHit? {
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        guard center.x > 0 else { return nil }
        // Сначала — найденная геометрия плоскости (самая стабильная),
        // затем — оценочная плоскость (работает сразу, с LiDAR опирается на меш).
        let targets: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]
        for target in targets {
            if let result = arView.raycast(from: center, allowing: target, alignment: .vertical).first {
                return makeHit(result.worldTransform, cameraPosition: cameraPosition)
            }
        }
        return nil
    }

    private func makeHit(_ transform: simd_float4x4, cameraPosition: SIMD3<Float>) -> SurfaceHit {
        let position = transform.translation
        // У результата raycast по плоскости ось Y — нормаль поверхности
        var normal = simd_normalize(SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z))
        // Нормаль должна смотреть на пользователя, иначе линии окажутся «внутри» стены
        if simd_dot(normal, cameraPosition - position) < 0 { normal = -normal }
        return SurfaceHit(position: position, normal: normal, transform: transform)
    }

    // MARK: - Якоря

    /// Добавляет ARAnchor в точке прицела. Якорь попадёт в ARWorldMap при сохранении.
    func addAnchor(at hit: SurfaceHit) -> UUID {
        let anchor = ARAnchor(name: "trassa.point", transform: hit.transform)
        arView.session.add(anchor: anchor)
        return anchor.identifier
    }

    func removeAnchor(id: UUID) {
        guard let anchor = arView.session.currentFrame?.anchors.first(where: { $0.identifier == id }) else { return }
        arView.session.remove(anchor: anchor)
    }

    /// Актуальные положения якорей. После релокализации ARKit уточняет их,
    /// поэтому берём позиции из сессии, а сохранённые координаты — запасной вариант.
    func anchorPositions() -> [UUID: SIMD3<Float>] {
        guard let anchors = arView.session.currentFrame?.anchors else { return [:] }
        var result: [UUID: SIMD3<Float>] = [:]
        for anchor in anchors where anchor.name == "trassa.point" {
            result[anchor.identifier] = anchor.transform.translation
        }
        return result
    }

    // MARK: - Отрисовка

    /// Сохранённые трассы. До релокализации они скрыты: их координаты ещё не совпадают с комнатой.
    func setSavedRoutes(_ routes: [RenderRoute], showZones: Bool) {
        savedRoutes = routes
        showSavedZones = showZones
        rebuildSaved()
    }

    private func rebuildSaved() {
        savedRoot.children.removeAll()
        for route in savedRoutes {
            savedRoot.addChild(RouteRenderer.makeRoute(route, showZone: showSavedZones, showPoints: false))
        }
    }

    func setDraftRoutes(_ routes: [RenderRoute]) {
        draftRoot.children.removeAll()
        for route in routes {
            draftRoot.addChild(RouteRenderer.makeRoute(route, showZone: false, showPoints: true))
        }
    }

    /// Тонкая линия-подсказка: от последней точки к прицелу (запись)
    /// или от прицела к ближайшей трассе (проверка сверления).
    func setPreviewSegment(from a: SIMD3<Float>?, to b: SIMD3<Float>?, normal: SIMD3<Float>, type: RouteType?, color: UIColor? = nil) {
        previewRoot.children.removeAll()
        guard let a, let b,
              let t = RouteRenderer.segmentTransform(a, b, normal: normal, width: 0.006, depth: 0.002, offset: 0.004)
        else { return }
        let uiColor = color ?? type?.uiColor ?? .white
        var material = UnlitMaterial(color: uiColor)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.7))
        let entity = ModelEntity(mesh: RouteRenderer.unitBox, materials: [material])
        entity.transform = t
        previewRoot.addChild(entity)
    }

    // MARK: - Сохранение карты

    /// Получает ARWorldMap текущей сессии. Вызывать только при mappingStatus == .mapped —
    /// иначе карта получится неполной и релокализация потом может не сработать.
    func captureWorldMap() async throws -> ARWorldMap {
        try await withCheckedThrowingContinuation { continuation in
            arView.session.getCurrentWorldMap { map, error in
                if let map {
                    continuation.resume(returning: map)
                } else {
                    continuation.resume(throwing: error ?? WorldMapStore.StoreError.corrupted)
                }
            }
        }
    }

    /// Снимок экрана AR вместе с нарисованными трассами — превью комнаты
    func snapshot() async -> UIImage? {
        await withCheckedContinuation { continuation in
            arView.snapshot(saveToHDR: false) { image in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Состояние трекинга

    fileprivate func handleTracking(_ state: ARCamera.TrackingState) {
        trackingState = state
        // С загруженной картой состояние .normal наступает только после того,
        // как ARKit узнал комнату. Это и есть момент релокализации.
        if case .normal = state, !isRelocalized {
            isRelocalized = true
            savedRoot.isEnabled = true
            refreshSavedFromAnchors(force: true)
            Haptics.success()
        }
        hint = TrackingHint.make(tracking: state, mapping: mappingStatus, hasSurface: hit != nil)
    }

    /// Подставляет в трассы уточнённые положения восстановленных якорей
    fileprivate func refreshSavedFromAnchors(force: Bool = false) {
        guard isRelocalized, !savedRoutes.isEmpty else { return }
        guard force || Date().timeIntervalSince(lastAnchorRefresh) > 2 else { return }
        lastAnchorRefresh = Date()
        anchorRefresh?(anchorPositions())
    }

    /// Колбэк: модель экрана пересчитывает трассы по актуальным якорям
    var anchorRefresh: (([UUID: SIMD3<Float>]) -> Void)?
}

// MARK: - ARSessionDelegate

extension ARSessionController: ARSessionDelegate {
    // Делегат ARSession по умолчанию вызывается на главной очереди

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        MainActor.assumeIsolated { self.handleTracking(state) }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0.name == "trassa.point" }) else { return }
        MainActor.assumeIsolated { self.refreshSavedFromAnchors() }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = (error as? ARError)?.code == .cameraUnauthorized
            ? "Нет доступа к камере. Разрешите его в Настройках → Трасса."
            : "Ошибка AR: \(error.localizedDescription)"
        MainActor.assumeIsolated { self.errorMessage = message }
    }

    /// После прерывания (звонок, сворачивание) просим ARKit восстановить привязку к карте
    nonisolated func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool { true }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> { SIMD3(columns.3.x, columns.3.y, columns.3.z) }
}
