import Foundation
import ARKit

/// Хранилище файлов ARWorldMap.
///
/// Почему файлом, а не в SwiftData: карта комнаты весит от сотен килобайт
/// до десятков мегабайт (облако опорных точек + якоря), её удобнее хранить
/// отдельно и грузить только при открытии AR. В базе остаётся только имя файла.
struct WorldMapStore {
    let directory: URL

    /// Папка по умолчанию: Documents/WorldMaps
    static var `default`: WorldMapStore {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return WorldMapStore(directory: docs.appendingPathComponent("WorldMaps", isDirectory: true))
    }

    enum StoreError: LocalizedError {
        case notFound
        case corrupted

        var errorDescription: String? {
            switch self {
            case .notFound: "Карта комнаты не найдена. Запишите комнату заново."
            case .corrupted: "Файл карты повреждён. Запишите комнату заново."
            }
        }
    }

    static func fileName(for roomID: UUID) -> String { "\(roomID.uuidString).arworldmap" }

    func url(for fileName: String) -> URL { directory.appendingPathComponent(fileName) }

    // MARK: - Сырые данные (используются и в тестах)

    /// Атомарная запись: сначала во временный файл, затем замена —
    /// чтобы при сбое не потерять предыдущую версию карты.
    @discardableResult
    func save(data: Data, roomID: UUID) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = Self.fileName(for: roomID)
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtection])
        return name
    }

    func loadData(fileName: String) throws -> Data {
        let fileURL = url(for: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw StoreError.notFound }
        return try Data(contentsOf: fileURL)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    // MARK: - ARWorldMap

    /// Сериализация карты. ARWorldMap поддерживает NSSecureCoding,
    /// поэтому её можно заархивировать NSKeyedArchiver целиком — вместе со всеми
    /// ARAnchor точек трасс, которые мы добавили в сессию.
    static func archive(_ map: ARWorldMap) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
    }

    /// Обратная операция: безопасная распаковка только класса ARWorldMap.
    static func unarchive(_ data: Data) throws -> ARWorldMap {
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw StoreError.corrupted
        }
        return map
    }

    func loadWorldMap(fileName: String) throws -> ARWorldMap {
        try Self.unarchive(loadData(fileName: fileName))
    }
}
