import SwiftUI
import SwiftData
import PhotosUI

/// Экраны 15, 23-25 · Карточка трассы
struct RouteDetailView: View {
    @Bindable var route: Route
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @State private var editing = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: route.type.title) {
                Button("Изменить") { editing = true }
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.accent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomTrailing) {
                        PhotoView(data: route.photoData ?? route.room?.previewImageData)
                            .frame(height: 298)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(route.photoData == nil ? "Фото штробы" : "Заменить фото", systemImage: "camera")
                                .font(Theme.Fonts.captionBold)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Theme.Colors.overlay, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                        }
                        .padding(12)
                    }
                    .padding(.top, 22)

                    Text(route.displayTitle)
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 27)

                    HStack(alignment: .top, spacing: 0) {
                        stat("ДЛИНА", Formatters.meters(route.length), route.type.color, Theme.Fonts.headline)
                        stat("ДАТА ЗАПИСИ", Formatters.numeric.string(from: route.createdAt),
                             Theme.Colors.textPrimary, Theme.Fonts.button)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 72)
                    .card()
                    .padding(.top, 21)

                    Text("ЗАМЕТКА")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 27)
                    Text(route.note.isEmpty ? "Нажмите «Изменить», чтобы добавить марку кабеля или трубы и как проходит трасса." : route.note)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(route.note.isEmpty ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                        .padding(.top, 13)
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Показать на стене") {
                if let room = route.room { router.view = ViewRequest(room: room, focusRouteID: route.id) }
            }
            .buttonStyle(.primary)
            .disabled(route.room?.hasWorldMap != true)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 8)
        }
        .trassaScreen()
        .sheet(isPresented: $editing) { RouteEditSheet(route: route) }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = image.jpegData(compressionQuality: 0.7) {
                    route.photoData = jpeg
                    route.room?.touch()
                    try? context.save()
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color, _ font: Font) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.Fonts.microLabel).foregroundStyle(Theme.Colors.textSecondary)
            Text(value).font(font).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Редактирование описания, заметки и типа трассы
private struct RouteEditSheet: View {
    @Bindable var route: Route
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Трасса").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button("Готово") {
                    route.room?.touch()
                    try? context.save()
                    dismiss()
                }
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(Theme.Colors.accent)
            }
            LabeledField(label: "Куда идёт трасса", placeholder: "К розеткам над столешницей", text: $route.title)
            VStack(alignment: .leading, spacing: 12) {
                Text("Заметка").font(Theme.Fonts.subheadlineRegular).foregroundStyle(Theme.Colors.textSecondary)
                TextField("", text: $route.note, prompt: Text("Кабель ВВГнг 3×2,5…").foregroundStyle(Theme.Colors.textMuted), axis: .vertical)
                    .lineLimit(3...6)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(16)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 8) {
                ForEach(RouteType.allCases) { type in
                    RouteTypeChip(type: type, isSelected: route.type == type) { route.type = type }
                }
            }
            Spacer()
        }
        .padding(Theme.Metrics.screenPadding)
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
