import XCTest
import simd
@testable import Trassa

/// Расстояние от точки до отрезка и проверка «Можно ли тут сверлить?»
final class GeometryTests: XCTestCase {
    private let eps: Float = 1e-5

    // Вертикальный отрезок на стене: от пола (0) до 1 м
    private let a = SIMD3<Float>(0, 0, 0)
    private let b = SIMD3<Float>(0, 1, 0)

    func testPointProjectsInsideSegment() {
        // Точка в 10 см сбоку от середины отрезка
        let p = SIMD3<Float>(0.10, 0.5, 0)
        XCTAssertEqual(Geometry.distancePointToSegment(p, a, b), 0.10, accuracy: eps)
        let c = Geometry.closestPointOnSegment(p, a, b)
        XCTAssertEqual(c.y, 0.5, accuracy: eps)
    }

    func testPointBeyondEndClampsToEndpoint() {
        // Выше конца B на 30 см и в 40 см сбоку → до B: √(0.3² + 0.4²) = 0.5
        let p = SIMD3<Float>(0.4, 1.3, 0)
        XCTAssertEqual(Geometry.distancePointToSegment(p, a, b), 0.5, accuracy: eps)
        XCTAssertEqual(Geometry.closestPointOnSegment(p, a, b), b)
    }

    func testPointBeforeStartClampsToStart() {
        let p = SIMD3<Float>(0, -0.2, 0)
        XCTAssertEqual(Geometry.distancePointToSegment(p, a, b), 0.2, accuracy: eps)
        XCTAssertEqual(Geometry.closestPointOnSegment(p, a, b), a)
    }

    func testPointOnSegmentHasZeroDistance() {
        XCTAssertEqual(Geometry.distancePointToSegment(SIMD3(0, 0.7, 0), a, b), 0, accuracy: eps)
    }

    func testDegenerateSegmentIsPoint() {
        let p = SIMD3<Float>(3, 4, 0)
        XCTAssertEqual(Geometry.distancePointToSegment(p, a, a), 5, accuracy: eps)
    }

    func testDiagonalSegmentIn3D() {
        // Отрезок по диагонали стены в плоскости XY, точка выдвинута по Z на 5 см
        let p = SIMD3<Float>(0.5, 0.5, 0.05)
        XCTAssertEqual(Geometry.distancePointToSegment(p, SIMD3(0, 0, 0), SIMD3(1, 1, 0)), 0.05, accuracy: eps)
    }

    func testPolylineLengthAndDistance() {
        // Г-образная трасса: вверх на 1 м, вправо на 0,5 м
        let pts: [SIMD3<Float>] = [a, b, SIMD3(0.5, 1, 0)]
        XCTAssertEqual(Geometry.polylineLength(pts), 1.5, accuracy: eps)
        // Точка под горизонтальным участком: ближайший — второй отрезок
        let hit = Geometry.distancePointToPolyline(SIMD3(0.3, 0.92, 0), pts)
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.distance, 0.08, accuracy: eps)
    }

    func testDrillCheckDangerBelow15cm() {
        let routes = [
            DrillCheck.Polyline(type: .water, points: [SIMD3(1, 0, 0), SIMD3(1, 1, 0)]),
            DrillCheck.Polyline(type: .electric, points: [a, b]),
        ]
        let result = DrillCheck.evaluate(point: SIMD3(0.08, 0.5, 0), routes: routes)
        XCTAssertTrue(result.isDangerous)
        XCTAssertEqual(result.nearestType, .electric)
        XCTAssertEqual(result.distance!, 0.08, accuracy: eps)
    }

    func testDrillCheckSafeAt15cmAndMore() {
        let routes = [DrillCheck.Polyline(type: .heating, points: [a, b])]
        // Ровно 15 см — уже за границей зоны (условие «< 15 см»)
        XCTAssertFalse(DrillCheck.evaluate(point: SIMD3(0.15, 0.5, 0), routes: routes).isDangerous)
        let far = DrillCheck.evaluate(point: SIMD3(0.34, 0.5, 0), routes: routes)
        XCTAssertFalse(far.isDangerous)
        XCTAssertEqual(far.distance!, 0.34, accuracy: eps)
    }

    func testDrillCheckWithoutRoutesIsSafe() {
        let result = DrillCheck.evaluate(point: .zero, routes: [])
        XCTAssertFalse(result.isDangerous)
        XCTAssertNil(result.distance)
    }

    func testRussianFormatting() {
        XCTAssertEqual(Formatters.meters(3.24), "3,2 м")
        XCTAssertEqual(Formatters.centimeters(0.081), "8 см")
        XCTAssertEqual(Formatters.routes(1), "1 трасса")
        XCTAssertEqual(Formatters.routes(3), "3 трассы")
        XCTAssertEqual(Formatters.routes(12), "12 трасс")
        XCTAssertEqual(Formatters.routes(22), "22 трассы")
    }
}
