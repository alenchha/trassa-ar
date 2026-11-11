import XCTest
import SwiftData
import simd
@testable import Trassa

/// Сохранение и загрузка модели: SwiftData (в памяти) + файлы карт
@MainActor
final class PersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: WorldMapStore!
    private var tempDir: URL!

    override func setUp() async throws {
        container = try TrassaSchema.makeContainer(inMemory: true)
        context = container.mainContext
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = WorldMapStore(directory: tempDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        container = nil
    }

    private func draft(_ type: RouteType, _ pts: [SIMD3<Float>]) -> DraftRoute {
        var d = DraftRoute(type: type)
        d.points = pts.map { DraftPoint(anchorID: UUID(), position: $0, normal: SIMD3(0, 0, 1)) }
        return d
    }

    func testSaveRecordingAndFetchBack() throws {
        let repo = RoomRepository(context: context, store: store)
        let project = repo.createProject(name: "ЖК «Речной» · кв. 42", address: "Ленинградский пр-т, 18")
        let mapData = Data("fake-world-map".utf8)

        let room = try repo.saveRecording(
            project: project, existingRoom: nil, name: "  Кухня ",
            drafts: [
                draft(.electric, [SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0.5, 1, 0)]),
                draft(.water, [SIMD3(1, 0, 0), SIMD3(1, 0.4, 0)]),
                draft(.heating, [SIMD3(2, 0, 0)]), // одна точка - не сохраняется
            ],
            worldMapData: mapData, previewData: nil
        )

        // Загружаем из базы заново
        let fetched = try context.fetch(FetchDescriptor<Room>())
        XCTAssertEqual(fetched.count, 1)
        let loaded = try XCTUnwrap(fetched.first)
        XCTAssertEqual(loaded.id, room.id)
        XCTAssertEqual(loaded.name, "Кухня")
        XCTAssertEqual(loaded.project?.name, "ЖК «Речной» · кв. 42")
        XCTAssertEqual(loaded.routes.count, 2)

        // Точки восстанавливаются в порядке постановки
        let electric = try XCTUnwrap(loaded.routes.first { $0.type == .electric })
        XCTAssertEqual(electric.orderedPoints.map(\.position), [SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0.5, 1, 0)])
        XCTAssertEqual(electric.length, 1.5, accuracy: 1e-5)
        XCTAssertEqual(loaded.totalLength, 1.9, accuracy: 1e-5)

        // Файл карты записан и читается обратно байт в байт
        let fileName = try XCTUnwrap(loaded.worldMapFileName)
        XCTAssertEqual(try store.loadData(fileName: fileName), mapData)
    }

    func testAppendToExistingRoomOverwritesMap() throws {
        let repo = RoomRepository(context: context, store: store)
        let project = repo.createProject(name: "Дом", address: "")
        let room = try repo.saveRecording(project: project, existingRoom: nil, name: "Ванная",
                                          drafts: [draft(.water, [.zero, SIMD3(0, 1, 0)])],
                                          worldMapData: Data([1]), previewData: nil)
        try repo.saveRecording(project: project, existingRoom: room, name: "Ванная",
                               drafts: [draft(.lowVoltage, [.zero, SIMD3(1, 0, 0)])],
                               worldMapData: Data([2]), previewData: Data([9]))

        XCTAssertEqual(try context.fetch(FetchDescriptor<Room>()).count, 1)
        XCTAssertEqual(room.routes.count, 2)
        XCTAssertEqual(room.previewImageData, Data([9]))
        XCTAssertEqual(try store.loadData(fileName: room.worldMapFileName!), Data([2]))
    }

    func testRenameAndCascadeDelete() throws {
        let repo = RoomRepository(context: context, store: store)
        let project = repo.createProject(name: "Старое", address: "")
        let room = try repo.saveRecording(project: project, existingRoom: nil, name: "Спальня",
                                          drafts: [draft(.electric, [.zero, SIMD3(0, 1, 0)])],
                                          worldMapData: Data([7]), previewData: nil)
        let fileName = try XCTUnwrap(room.worldMapFileName)

        repo.rename(project, to: "Новое")
        repo.rename(room, to: "Детская")
        XCTAssertEqual(project.name, "Новое")
        XCTAssertEqual(room.name, "Детская")

        repo.delete(project)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Project>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Room>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Route>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RoutePoint>()).isEmpty)
        // Файл карты удалён вместе с комнатой
        XCTAssertThrowsError(try store.loadData(fileName: fileName))
    }

    func testMissingMapFileThrows() {
        XCTAssertThrowsError(try store.loadData(fileName: "нет.arworldmap")) { error in
            XCTAssertEqual(error as? WorldMapStore.StoreError, .notFound)
        }
    }
}
