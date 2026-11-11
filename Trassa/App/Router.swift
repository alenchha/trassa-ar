import SwiftUI
import Observation

/// Экраны внутри стека навигации
enum AppRoute: Hashable {
    case newProject
    case project(Project)
    case routes(Room)
    case route(Route)
    case export(Room)
}

/// Запрос на AR-запись: в новый или существующий объект/комнату
struct RecordRequest: Identifiable {
    let id = UUID()
    let project: Project
    /// nil - новая комната; иначе дописываем трассы в существующую
    let room: Room?
}

/// Запрос на AR-просмотр комнаты
struct ViewRequest: Identifiable {
    let id = UUID()
    let room: Room
    /// Трасса, которую нужно подсветить («Показать на стене»)
    var focusRouteID: UUID? = nil
}

/// Навигация приложения: стек экранов и полноэкранные AR-режимы
@Observable
final class Router {
    var path: [AppRoute] = []
    var record: RecordRequest?
    var view: ViewRequest?

    func push(_ route: AppRoute) { path.append(route) }
}
