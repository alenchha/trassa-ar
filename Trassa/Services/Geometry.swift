import Foundation
import simd

/// Чистая геометрия без зависимостей от ARKit — легко тестируется.
enum Geometry {

    /// Ближайшая к `p` точка на отрезке AB.
    ///
    /// Математика: параметризуем отрезок как A + t·(B − A), t ∈ [0, 1].
    /// Проекция P на прямую AB даёт t = ((P − A)·(B − A)) / |B − A|².
    /// Если t < 0, ближайшая точка — A, если t > 1 — B, иначе внутренняя точка.
    /// Ограничение t отрезком [0, 1] (clamp) и превращает «расстояние до прямой»
    /// в «расстояние до отрезка».
    static func closestPointOnSegment(_ p: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
        let ab = b - a
        let lengthSquared = simd_length_squared(ab)
        // Вырожденный отрезок (A == B) — это просто точка
        guard lengthSquared > .ulpOfOne else { return a }
        let t = simd_clamp(simd_dot(p - a, ab) / lengthSquared, 0, 1)
        return a + t * ab
    }

    /// Расстояние (в метрах) от точки P до отрезка AB.
    static func distancePointToSegment(_ p: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_distance(p, closestPointOnSegment(p, a, b))
    }

    /// Расстояние от точки до ломаной. Для одной точки — расстояние до неё.
    static func distancePointToPolyline(_ p: SIMD3<Float>, _ points: [SIMD3<Float>]) -> (distance: Float, closest: SIMD3<Float>)? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else { return (simd_distance(p, first), first) }
        var best: (Float, SIMD3<Float>) = (.greatestFiniteMagnitude, first)
        for i in 0..<(points.count - 1) {
            let c = closestPointOnSegment(p, points[i], points[i + 1])
            let d = simd_distance(p, c)
            if d < best.0 { best = (d, c) }
        }
        return best
    }

    /// Длина ломаной в метрах
    static func polylineLength(_ points: [SIMD3<Float>]) -> Float {
        guard points.count > 1 else { return 0 }
        var sum: Float = 0
        for i in 1..<points.count { sum += simd_distance(points[i - 1], points[i]) }
        return sum
    }
}

/// Результат проверки «Можно ли тут сверлить?»
struct DrillCheckResult: Equatable {
    /// Расстояние до ближайшей трассы (м), nil — трасс нет
    let distance: Float?
    let nearestType: RouteType?
    /// Ближайшая точка на трассе — для рисования «линейки» в AR
    let nearestPoint: SIMD3<Float>?
    let isDangerous: Bool
}

/// Сервис проверки места сверления по сохранённым трассам.
enum DrillCheck {
    /// Радиус запретной зоны: ±15 см от трассы
    static let dangerRadius: Float = 0.15

    struct Polyline {
        let type: RouteType
        let points: [SIMD3<Float>]
    }

    /// Ищет ближайший отрезок среди всех трасс комнаты.
    static func evaluate(point: SIMD3<Float>, routes: [Polyline], radius: Float = dangerRadius) -> DrillCheckResult {
        var bestDistance = Float.greatestFiniteMagnitude
        var bestType: RouteType?
        var bestPoint: SIMD3<Float>?
        for route in routes {
            guard let hit = Geometry.distancePointToPolyline(point, route.points) else { continue }
            if hit.distance < bestDistance {
                bestDistance = hit.distance
                bestType = route.type
                bestPoint = hit.closest
            }
        }
        guard let bestType else {
            return DrillCheckResult(distance: nil, nearestType: nil, nearestPoint: nil, isDangerous: false)
        }
        return DrillCheckResult(
            distance: bestDistance,
            nearestType: bestType,
            nearestPoint: bestPoint,
            isDangerous: bestDistance < radius
        )
    }
}

/// Форматирование чисел по-русски: «3,2 м», «8 см»
enum Formatters {
    static func meters(_ value: Float) -> String {
        String(format: "%.1f м", value).replacingOccurrences(of: ".", with: ",")
    }

    static func centimeters(_ value: Float) -> String {
        "\(Int((value * 100).rounded())) см"
    }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static let numeric: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    /// Склонение: 1 трасса, 2 трассы, 5 трасс
    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let n10 = n % 10, n100 = n % 100
        let word: String
        if n10 == 1 && n100 != 11 { word = one }
        else if (2...4).contains(n10) && !(12...14).contains(n100) { word = few }
        else { word = many }
        return "\(n) \(word)"
    }

    static func routes(_ n: Int) -> String { plural(n, "трасса", "трассы", "трасс") }
    static func rooms(_ n: Int) -> String { plural(n, "комната", "комнаты", "комнат") }
    static func projects(_ n: Int) -> String { plural(n, "объект", "объекта", "объектов") }
    static func points(_ n: Int) -> String { plural(n, "точка", "точки", "точек") }
}
