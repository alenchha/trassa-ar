import Foundation
import simd

/// Точка трассы, ещё не сохранённая в базу (во время AR-записи)
struct DraftPoint: Equatable {
    let anchorID: UUID
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}

/// Трасса, записываемая в текущей AR-сессии
struct DraftRoute: Identifiable, Equatable {
    let id = UUID()
    var type: RouteType
    var points: [DraftPoint] = []

    var length: Float { Geometry.polylineLength(points.map(\.position)) }

    var render: RenderRoute {
        RenderRoute(id: id, type: type, points: points.map { RenderPoint(position: $0.position, normal: $0.normal) })
    }
}
