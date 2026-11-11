import Foundation
import SwiftData
import simd

// Схема данных:
// Project (объект) 1-N Room (комната) 1-N Route (трасса) 1-N RoutePoint (точка)
//                                     1-N RoomNote (заметка)
// Сама карта ARWorldMap хранится отдельным файлом (см. WorldMapStore),
// в базе - только имя файла.

/// Объект: квартира или дом
@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Room.project)
    var rooms: [Room] = []

    init(name: String, address: String = "", createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var sortedRooms: [Room] { rooms.sorted { $0.createdAt < $1.createdAt } }
    var routesCount: Int { rooms.reduce(0) { $0 + $1.routes.count } }

    /// Превью объекта - снимок последней обновлённой комнаты
    var coverImageData: Data? {
        rooms.sorted { $0.updatedAt > $1.updatedAt }.first { $0.previewImageData != nil }?.previewImageData
    }

    func touch() { updatedAt = .now }
}

/// Комната с сохранённой AR-картой
@Model
final class Room {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    /// Имя файла ARWorldMap в Documents/WorldMaps
    var worldMapFileName: String?
    /// Снимок камеры с трассами в момент сохранения
    @Attribute(.externalStorage) var previewImageData: Data?

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Route.room)
    var routes: [Route] = []

    @Relationship(deleteRule: .cascade, inverse: \RoomNote.room)
    var notes: [RoomNote] = []

    init(name: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var sortedRoutes: [Route] { routes.sorted { $0.createdAt < $1.createdAt } }
    var sortedNotes: [RoomNote] { notes.sorted { $0.createdAt > $1.createdAt } }
    var totalLength: Float { routes.reduce(0) { $0 + $1.length } }
    var hasWorldMap: Bool { worldMapFileName != nil }

    func touch() {
        updatedAt = .now
        project?.touch()
    }
}

/// Одна трасса - ломаная из точек одного типа
@Model
final class Route {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var title: String
    var note: String
    var createdAt: Date
    /// Фото штробы до отделки
    @Attribute(.externalStorage) var photoData: Data?

    var room: Room?

    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.route)
    var points: [RoutePoint] = []

    init(type: RouteType, title: String = "", note: String = "", createdAt: Date = .now) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.title = title
        self.note = note
        self.createdAt = createdAt
    }

    var type: RouteType {
        get { RouteType(rawValue: typeRaw) ?? .electric }
        set { typeRaw = newValue.rawValue }
    }

    /// Точки в порядке постановки
    var orderedPoints: [RoutePoint] { points.sorted { $0.index < $1.index } }

    /// Длина ломаной в метрах
    var length: Float { Geometry.polylineLength(orderedPoints.map(\.position)) }

    /// Заголовок для списков: заметка-название или тип
    var displayTitle: String { title.isEmpty ? type.title : title }
}

/// Точка трассы. Связана с ARAnchor, который сохраняется внутри ARWorldMap.
@Model
final class RoutePoint {
    @Attribute(.unique) var id: UUID
    var index: Int
    /// identifier ARAnchor в карте комнаты
    var anchorID: UUID
    // Мировые координаты в момент записи (метры). Используются,
    // если якорь по какой-то причине не восстановился из карты.
    var x: Float
    var y: Float
    var z: Float
    // Нормаль стены в этой точке - нужна, чтобы «положить» линию и зону на стену
    var nx: Float
    var ny: Float
    var nz: Float

    var route: Route?

    init(index: Int, anchorID: UUID, position: SIMD3<Float>, normal: SIMD3<Float>) {
        self.id = UUID()
        self.index = index
        self.anchorID = anchorID
        self.x = position.x
        self.y = position.y
        self.z = position.z
        self.nx = normal.x
        self.ny = normal.y
        self.nz = normal.z
    }

    var position: SIMD3<Float> { SIMD3(x, y, z) }
    var normal: SIMD3<Float> { SIMD3(nx, ny, nz) }
}

/// Заметка к комнате (с необязательным фото)
@Model
final class RoomNote {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?

    var room: Room?

    init(text: String, photoData: Data? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.text = text
        self.photoData = photoData
        self.createdAt = createdAt
    }
}

enum TrassaSchema {
    static let models: [any PersistentModel.Type] = [
        Project.self, Room.self, Route.self, RoutePoint.self, RoomNote.self
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
