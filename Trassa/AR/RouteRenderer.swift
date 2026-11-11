import RealityKit
import UIKit
import simd

/// Точка трассы для отрисовки: положение и нормаль стены
struct RenderPoint: Equatable {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

/// Трасса для отрисовки в AR
struct RenderRoute: Equatable {
    let id: UUID
    let type: RouteType
    var points: [RenderPoint]
}

/// Строит RealityKit-сущности для линий трасс и красной зоны ±15 см.
///
/// Все примитивы — единичные меши (куб 1×1×1, сфера Ø1), которые растягиваются
/// через scale. Так не нужно генерировать новую геометрию на каждый кадр.
@MainActor
enum RouteRenderer {
    // Размеры в метрах
    static let lineWidth: Float = 0.012       // толщина линии на стене
    static let lineDepth: Float = 0.003
    static let pointRadius: Float = 0.014
    static let zoneDepth: Float = 0.001
    /// Линия приподнята над стеной на 3 мм, зона — на 1 мм, чтобы не «мерцали» со стеной
    static let lineOffset: Float = 0.003
    static let zoneOffset: Float = 0.001

    static let unitBox = MeshResource.generateBox(size: 1)
    static let unitSphere = MeshResource.generateSphere(radius: 0.5)

    static func lineMaterial(_ type: RouteType, alpha: CGFloat = 1) -> RealityKit.Material {
        var material = UnlitMaterial(color: type.uiColor)
        if alpha < 1 { material.blending = .transparent(opacity: .init(floatLiteral: Float(alpha))) }
        return material
    }

    static var zoneMaterial: RealityKit.Material {
        var material = UnlitMaterial(color: UIColor(hex: 0xFF5D60))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.24))
        return material
    }

    /// Собирает одну трассу: линии, точки и (опционально) зону запрета.
    static func makeRoute(_ route: RenderRoute, showZone: Bool, showPoints: Bool, zoneRadius: Float = DrillCheck.dangerRadius) -> Entity {
        let root = Entity()
        let lineMat = lineMaterial(route.type)
        let pts = route.points

        for i in 0..<max(pts.count - 1, 0) {
            let a = pts[i], b = pts[i + 1]
            let normal = simd_normalize(a.normal + b.normal)
            if let t = segmentTransform(a.position, b.position, normal: normal,
                                        width: lineWidth, depth: lineDepth, offset: lineOffset) {
                let line = ModelEntity(mesh: unitBox, materials: [lineMat])
                line.transform = t
                root.addChild(line)
            }
            if showZone, let t = segmentTransform(a.position, b.position, normal: normal,
                                                  width: zoneRadius * 2, depth: zoneDepth, offset: zoneOffset) {
                let zone = ModelEntity(mesh: unitBox, materials: [zoneMaterial])
                zone.transform = t
                root.addChild(zone)
            }
        }

        for p in pts {
            if showPoints {
                let dot = ModelEntity(mesh: unitSphere, materials: [lineMat])
                dot.transform = Transform(scale: SIMD3(repeating: pointRadius * 2), rotation: simd_quatf(), translation: p.position + p.normal * lineOffset)
                root.addChild(dot)
            }
            // Скругление зоны на концах и изломах — плоский «диск» радиусом 15 см
            if showZone {
                let cap = ModelEntity(mesh: unitSphere, materials: [zoneMaterial])
                cap.transform = discTransform(at: p.position, normal: p.normal, radius: zoneRadius, depth: zoneDepth, offset: zoneOffset)
                root.addChild(cap)
            }
        }
        return root
    }

    /// Трансформ, превращающий единичный куб в «полоску» от A до B, лежащую на стене.
    ///
    /// Строим ортонормированный базис:
    ///  y — вдоль отрезка (длина),
    ///  z — нормаль стены, ортогонализованная к y (толщина),
    ///  x = y × z — поперёк отрезка по стене (ширина).
    /// Тройка (x, y, z) правая, поэтому из неё получается корректный кватернион поворота.
    static func segmentTransform(_ a: SIMD3<Float>, _ b: SIMD3<Float>, normal: SIMD3<Float>,
                                 width: Float, depth: Float, offset: Float) -> Transform? {
        let d = b - a
        let length = simd_length(d)
        guard length > 1e-4 else { return nil }
        let y = d / length
        // Убираем из нормали составляющую вдоль отрезка (Грам — Шмидт)
        var z = normal - simd_dot(normal, y) * y
        if simd_length(z) < 1e-3 {
            z = abs(y.y) < 0.9 ? simd_cross(y, SIMD3(0, 1, 0)) : simd_cross(y, SIMD3(1, 0, 0))
        }
        z = simd_normalize(z)
        let x = simd_normalize(simd_cross(y, z))
        let rotation = simd_quatf(simd_float3x3(columns: (x, y, z)))
        let center = (a + b) / 2 + z * offset
        return Transform(scale: SIMD3(width, length, depth), rotation: rotation, translation: center)
    }

    /// Плоский диск: сфера, сплющенная вдоль нормали стены
    static func discTransform(at p: SIMD3<Float>, normal: SIMD3<Float>, radius: Float, depth: Float, offset: Float) -> Transform {
        let n = simd_length(normal) > 1e-3 ? simd_normalize(normal) : SIMD3<Float>(0, 0, 1)
        let rotation = simd_quatf(from: SIMD3(0, 0, 1), to: n)
        return Transform(scale: SIMD3(radius * 2, radius * 2, depth), rotation: rotation, translation: p + n * offset)
    }
}
