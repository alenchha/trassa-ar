import SwiftUI
import SwiftData

@main
struct TrassaApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try TrassaSchema.makeContainer()
        } catch {
            fatalError("Не удалось открыть базу данных: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.accent)
        }
        .modelContainer(container)
    }
}

/// Первый запуск - онбординг, затем список объектов
struct RootView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var router = Router()

    var body: some View {
        Group {
            if onboardingCompleted {
                NavigationStack(path: $router.path) {
                    ProjectsListView()
                        .navigationDestination(for: AppRoute.self, destination: destination)
                }
                .fullScreenCover(item: $router.record) { request in
                    RecordView(request: request)
                }
                .fullScreenCover(item: $router.view) { request in
                    ViewerView(request: request)
                }
            } else {
                OnboardingView { onboardingCompleted = true }
            }
        }
        .environment(router)
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .newProject: NewProjectView()
        case .project(let project): RoomsListView(project: project)
        case .routes(let room): RoomRoutesView(room: room)
        case .route(let route): RouteDetailView(route: route)
        case .export(let room): ExportView(room: room)
        }
    }
}
