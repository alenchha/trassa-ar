import SwiftUI
import SwiftData

/// Экран 14 · Трассы комнаты
struct RoomRoutesView: View {
    @Bindable var room: Room
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var renaming = false
    @State private var newName = ""
    @State private var deletingRoom = false
    @State private var deletingRoute: Route?
    @State private var addingNote = false
    @State private var noteText = ""

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "\(room.name) · трассы") {
                Menu {
                    if let project = room.project {
                        Button("Дописать трассы", systemImage: "plus.viewfinder") {
                            router.record = RecordRequest(project: project, room: room)
                        }
                    }
                    Button("Добавить заметку", systemImage: "note.text") { noteText = ""; addingNote = true }
                    Button("Переименовать", systemImage: "pencil") { newName = room.name; renaming = true }
                    Button("Удалить комнату", systemImage: "trash", role: .destructive) { deletingRoom = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 44, height: 56)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Что внутри стены")
                        .font(Theme.Fonts.inter(28, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 14)
                    Text("\(Formatters.routes(room.routes.count)) · \(Formatters.meters(room.totalLength)) · \(Formatters.fullDate.string(from: room.updatedAt))")
                        .font(Theme.Fonts.footnoteRegular)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 9)

                    LazyVStack(spacing: 12) {
                        ForEach(room.sortedRoutes) { route in
                            Button { router.push(.route(route)) } label: { RouteCard(route: route) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Удалить трассу", systemImage: "trash", role: .destructive) { deletingRoute = route }
                                }
                        }
                        if room.routes.isEmpty {
                            InfoCard(title: "Трасс нет", text: "Откройте меню «…» → «Дописать трассы».")
                        }
                    }
                    .padding(.top, 24)

                    if !room.notes.isEmpty {
                        Text("ЗАМЕТКИ")
                            .font(Theme.Fonts.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.top, 24)
                        ForEach(room.sortedNotes) { note in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.text).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                                Text(Formatters.numeric.string(from: note.createdAt))
                                    .font(Theme.Fonts.inter(11, .medium)).foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .card()
                            .padding(.top, 12)
                            .contextMenu {
                                Button("Удалить", systemImage: "trash", role: .destructive) {
                                    context.delete(note)
                                    try? context.save()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button("Открыть в AR") { router.view = ViewRequest(room: room) }
                    .buttonStyle(.secondary)
                    .disabled(!room.hasWorldMap)
                Button("Экспорт схемы в PDF") { router.push(.export(room)) }
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 8)
            .background(Theme.Colors.background)
        }
        .trassaScreen()
        .alert("Переименовать комнату", isPresented: $renaming) {
            TextField("Название", text: $newName)
            Button("Сохранить") { RoomRepository(context: context).rename(room, to: newName) }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Заметка к комнате", isPresented: $addingNote) {
            TextField("Например: короб под ванной", text: $noteText)
            Button("Добавить") {
                guard !noteText.trimmed.isEmpty else { return }
                let note = RoomNote(text: noteText.trimmed)
                context.insert(note)
                note.room = room
                room.touch()
                try? context.save()
            }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog("Удалить комнату?", isPresented: $deletingRoom, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                dismiss()
                RoomRepository(context: context).delete(room)
            }
        } message: { Text("Карта комнаты и все трассы будут удалены.") }
        .confirmationDialog("Удалить трассу?", isPresented: Binding(get: { deletingRoute != nil }, set: { if !$0 { deletingRoute = nil } }),
                            titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { if let r = deletingRoute { RoomRepository(context: context).delete(r) } }
        }
    }
}

/// Карточка трассы: цветная полоса, тип, описание, дата, длина
struct RouteCard: View {
    let route: Route

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(route.type.color)
                .frame(width: Theme.Metrics.routeStripe)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                Text(route.type.title)
                    .font(Theme.Fonts.inter(17, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(route.title.isEmpty ? (route.note.isEmpty ? "Без описания" : route.note) : route.title)
                    .font(Theme.Fonts.footnoteRegular)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 9)
                HStack(spacing: 6) {
                    Text(Formatters.numeric.string(from: route.createdAt))
                    if route.photoData != nil {
                        Text("·")
                        Text("Фото штробы")
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                    }
                }
                .font(Theme.Fonts.inter(11, .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, 12)
            }
            Spacer(minLength: 0)
            Text(Formatters.meters(route.length))
                .font(Theme.Fonts.inter(15, .semibold))
                .foregroundStyle(route.type.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
    }
}
