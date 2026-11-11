import SwiftUI
import SwiftData

/// Экран 04 · Объекты
struct ProjectsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @State private var renaming: Project?
    @State private var newName = ""
    @State private var deleting: Project?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Мои объекты")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(height: 56)
                    .padding(.top, 4)

                Text("Стены помнят.\nВы — спокойны.")
                    .font(Theme.Fonts.hero)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, 20)

                Text(projects.isEmpty
                     ? "Создайте первый объект, чтобы записать трассы"
                     : "\(Formatters.projects(projects.count)) · все схемы под рукой")
                    .font(Theme.Fonts.subheadlineRegular)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 11)

                LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                    ForEach(projects) { project in
                        Button { router.push(.project(project)) } label: {
                            ProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Переименовать", systemImage: "pencil") {
                                newName = project.name
                                renaming = project
                            }
                            Button("Удалить", systemImage: "trash", role: .destructive) { deleting = project }
                        }
                    }
                    if projects.isEmpty {
                        InfoCard(icon: "cube", title: "Пока пусто",
                                 text: "Объект — это квартира или дом. Внутри — комнаты с картами трасс.")
                    }
                }
                .padding(.top, 21)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button("+ Новый объект") { router.push(.newProject) }
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 8)
                .background(Theme.Colors.background)
        }
        .trassaScreen()
        .alert("Переименовать объект", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Название", text: $newName)
            Button("Сохранить") { if let p = renaming { RoomRepository(context: context).rename(p, to: newName) } }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog("Удалить объект?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Удалить объект и все комнаты", role: .destructive) {
                if let p = deleting { RoomRepository(context: context).delete(p) }
            }
        } message: {
            Text("Карты комнат и трассы будут удалены без возможности восстановления.")
        }
    }
}

/// Карточка объекта: фото 132 pt + название, счётчики, дата
struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoView(data: project.coverImageData)
                .frame(height: Theme.Metrics.projectPhotoHeight)
            VStack(alignment: .leading, spacing: 0) {
                Text(project.name)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(Formatters.rooms(project.rooms.count))  ·  \(Formatters.routes(project.routesCount))")
                    .font(Theme.Fonts.subheadlineRegular)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 7)
                Text("Обновлено \(Formatters.dayMonth.string(from: project.updatedAt))")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 6)
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.top, 16)
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
    }
}
