import UIKit
import simd

/// Плоская схема трасс («вид на стену спереди») для экспорта и превью.
enum Schematic {

    struct Line {
        let type: RouteType
        let points: [CGPoint]
    }

    struct Layout {
        let lines: [Line]
        /// Сколько пунктов схемы приходится на 1 метр
        let pointsPerMeter: CGFloat
    }

    /// Проецирует 3D-точки трасс на плоскость стены и вписывает их в `rect`.
    ///
    /// Базис плоскости: «вверх» - мировая ось Y (ARKit выравнивает её по гравитации),
    /// нормаль - средняя нормаль точек без вертикальной составляющей,
    /// «вправо» = up × normal. Координаты точки на схеме: (p·right, p·up).
    /// Для нескольких стен это «развёртка» на одну плоскость - для MVP достаточно.
    static func layout(routes: [(RouteType, [SIMD3<Float>])], normals: [SIMD3<Float>], in rect: CGRect) -> Layout {
        let up = SIMD3<Float>(0, 1, 0)
        var n = normals.reduce(SIMD3<Float>.zero, +)
        n.y = 0
        if simd_length(n) < 1e-3 { n = SIMD3(0, 0, 1) }
        n = simd_normalize(n)
        let right = simd_normalize(simd_cross(up, n))

        let projected = routes.map { type, pts in
            (type, pts.map { SIMD2<Float>(simd_dot($0, right), simd_dot($0, up)) })
        }
        let all = projected.flatMap(\.1)
        guard let first = all.first else { return Layout(lines: [], pointsPerMeter: 1) }

        var minP = first, maxP = first
        for p in all { minP = simd_min(minP, p); maxP = simd_max(maxP, p) }
        // Поля: зона ±15 см не должна обрезаться краем
        let margin: Float = 0.25
        minP -= margin; maxP += margin
        let size = maxP - minP
        let scale = CGFloat(min(Float(rect.width) / size.x, Float(rect.height) / size.y))
        // Центрируем схему в прямоугольнике
        let offsetX = rect.minX + (rect.width - CGFloat(size.x) * scale) / 2
        let offsetY = rect.minY + (rect.height - CGFloat(size.y) * scale) / 2

        let lines = projected.map { type, pts in
            Line(type: type, points: pts.map {
                CGPoint(x: offsetX + CGFloat($0.x - minP.x) * scale,
                        // Ось Y экрана направлена вниз - переворачиваем
                        y: offsetY + CGFloat(maxP.y - $0.y) * scale)
            })
        }
        return Layout(lines: lines, pointsPerMeter: scale)
    }

    static func layout(for room: Room, in rect: CGRect) -> Layout {
        let routes = room.sortedRoutes
        return layout(routes: routes.map { ($0.type, $0.orderedPoints.map(\.position)) },
                      normals: routes.flatMap { $0.orderedPoints.map(\.normal) },
                      in: rect)
    }

    /// Рисует схему: фон стены, красные зоны ±15 см, линии трасс
    static func draw(_ layout: Layout, in cg: CGContext, rect: CGRect, forPrint: Bool) {
        cg.saveGState()
        cg.setFillColor(UIColor(hex: 0xE0E1DC).cgColor)
        cg.fill(rect)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)

        // Ширина зоны = 2 × 15 см в масштабе схемы (минимум, чтобы была видна)
        let zoneWidth = max(CGFloat(DrillCheck.dangerRadius * 2) * layout.pointsPerMeter, 8)
        cg.setStrokeColor(UIColor(hex: 0xD95757, alpha: 0.28).cgColor)
        cg.setLineWidth(zoneWidth)
        for line in layout.lines { stroke(line.points, cg) }

        cg.setLineWidth(2)
        for line in layout.lines {
            cg.setStrokeColor((forPrint ? line.type.printColor : line.type.uiColor).cgColor)
            stroke(line.points, cg)
        }
        cg.restoreGState()
    }

    private static func stroke(_ pts: [CGPoint], _ cg: CGContext) {
        guard let first = pts.first else { return }
        cg.beginPath()
        cg.move(to: first)
        pts.dropFirst().forEach { cg.addLine(to: $0) }
        cg.strokePath()
    }
}
