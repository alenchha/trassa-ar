import SwiftUI
import SwiftData

/// Экран 05 · Комнаты объекта
struct RoomsListView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var renamingRoom: Room?
    @State private var renamingProject = false
    @State private var newName = ""
    @State private var deletingRoom: Room?
    @State private var deletingProject = false

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: project.name) {
                Menu {
                    Button("Переименовать объект", systemImage: "pencil") {
                        newName = project.name
                        renamingProject = true
                    }
                    Button("Удалить объект", systemImage: "trash", role: .destructive) { deletingProject = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 44, height: 56)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Комнаты")
                        .font(Theme.Fonts.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 16)
                    if !project.address.isEmpty {
                        Text(project.address)
                            .font(Theme.Fonts.subheadlineRegular)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.top, 8)
                    }
                    TagLabel(text: "\(Formatters.routes(project.routesCount)) сохранено",
                             color: Theme.Colors.safe, background: Theme.Colors.background)
                        .padding(.top, 14)
                        .padding(.leading, -10)

                    LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                        ForEach(project.sortedRooms) { room in
                            Button { router.push(.routes(room)) } label: { RoomRow(room: room) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Переименовать", systemImage: "pencil") {
                                        newName = room.name
                                        renamingRoom = room
                                    }
                                    Button("Дописать трассы", systemImage: "plus.viewfinder") {
                                        router.record = RecordRequest(project: project, room: room)
                                    }
                                    Button("Удалить", systemImage: "trash", role: .destructive) { deletingRoom = room }
                                }
                        }
                    }
                    .padding(.top, 26)

                    InfoCard(title: project.rooms.isEmpty ? "Комнат пока нет" : "Схема остаётся с объектом",
                             text: project.rooms.isEmpty
                                ? "Нажмите «Добавить комнату» и отметьте трассы на открытой стене."
                                : "Откройте комнату, чтобы увидеть трассы.")
                        .padding(.top, 34)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button("+ Добавить комнату") { router.record = RecordRequest(project: project, room: nil) }
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 8)
                .background(Theme.Colors.background)
        }
        .trassaScreen()
        .alert("Переименовать комнату", isPresented: Binding(get: { renamingRoom != nil }, set: { if !$0 { renamingRoom = nil } })) {
            TextField("Название", text: $newName)
            Button("Сохранить") { if let r = renamingRoom { RoomRepository(context: context).rename(r, to: newName) } }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Переименовать объект", isPresented: $renamingProject) {
            TextField("Название", text: $newName)
            Button("Сохранить") { RoomRepository(context: context).rename(project, to: newName) }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog("Удалить комнату?", isPresented: Binding(get: { deletingRoom != nil }, set: { if !$0 { deletingRoom = nil } }),
                            titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { if let r = deletingRoom { RoomRepository(context: context).delete(r) } }
        } message: {
            Text("Карта комнаты и все трассы будут удалены.")
        }
        .confirmationDialog("Удалить объект?", isPresented: $deletingProject, titleVisibility: .visible) {
            Button("Удалить объект и все комнаты", role: .destructive) {
                dismiss()
                RoomRepository(context: context).delete(project)
            }
        }
    }
}

/// Строка комнаты: миниатюра 72 pt, название, «4 трассы · 10 ноября», стрелка
struct RoomRow: View {
    let room: Room

    var body: some View {
        HStack(spacing: 14) {
            PhotoView(data: room.previewImageData, placeholder: "wall_finished")
                .frame(width: Theme.Metrics.roomThumb, height: Theme.Metrics.roomThumb)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
            VStack(alignment: .leading, spacing: 8) {
                Text(room.name)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(Formatters.routes(room.routes.count)) · \(Formatters.dayMonth.string(from: room.updatedAt))")
                    .font(Theme.Fonts.subheadlineRegular)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.trailing, 16)
        }
        .padding(12)
        .frame(height: 96)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
    }
}
