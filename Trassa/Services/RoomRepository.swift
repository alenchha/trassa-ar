import Foundation
import SwiftData

/// Операции с объектами и комнатами, которые затрагивают и базу, и файлы карт.
struct RoomRepository {
    let context: ModelContext
    var store: WorldMapStore = .default

    // MARK: - Объекты

    @discardableResult
    func createProject(name: String, address: String) -> Project {
        let project = Project(name: name.trimmed.isEmpty ? "Новый объект" : name.trimmed, address: address.trimmed)
        context.insert(project)
        try? context.save()
        return project
    }

    func rename(_ project: Project, to name: String) {
        guard !name.trimmed.isEmpty else { return }
        project.name = name.trimmed
        project.touch()
        try? context.save()
    }

    func delete(_ project: Project) {
        project.rooms.compactMap(\.worldMapFileName).forEach(store.delete(fileName:))
        context.delete(project)
        try? context.save()
    }

    // MARK: - Комнаты

    func rename(_ room: Room, to name: String) {
        guard !name.trimmed.isEmpty else { return }
        room.name = name.trimmed
        room.touch()
        try? context.save()
    }

    func delete(_ room: Room) {
        if let file = room.worldMapFileName { store.delete(fileName: file) }
        room.project?.touch()
        context.delete(room)
        try? context.save()
    }

    func delete(_ route: Route) {
        route.room?.touch()
        context.delete(route)
        try? context.save()
    }

    /// Сохраняет результат AR-записи: файл карты + трассы + превью.
    ///
    /// Порядок важен: сначала пишем файл карты (если запись упадёт - база
    /// не изменится), затем создаём/обновляем комнату и трассы в SwiftData.
    @discardableResult
    func saveRecording(
        project: Project,
        existingRoom: Room?,
        name: String,
        drafts: [DraftRoute],
        worldMapData: Data,
        previewData: Data?
    ) throws -> Room {
        let room = existingRoom ?? Room(name: name.trimmed.isEmpty ? "Комната" : name.trimmed)
        let fileName = try store.save(data: worldMapData, roomID: room.id)

        if existingRoom == nil {
            context.insert(room)
            room.project = project
        } else if !name.trimmed.isEmpty {
            room.name = name.trimmed
        }
        room.worldMapFileName = fileName
        if let previewData { room.previewImageData = previewData }

        // Трассы из одной точки не сохраняем - это не линия
        for draft in drafts where draft.points.count >= 2 {
            let route = Route(type: draft.type)
            context.insert(route)
            route.room = room
            for (index, p) in draft.points.enumerated() {
                let point = RoutePoint(index: index, anchorID: p.anchorID, position: p.position, normal: p.normal)
                context.insert(point)
                point.route = route
            }
        }
        room.touch()
        try context.save()
        return room
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
