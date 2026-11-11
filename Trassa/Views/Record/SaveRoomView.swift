import SwiftUI
import SwiftData

/// Экран 09 · Сохранение комнаты
struct SaveRoomView: View {
    @ObservedObject var model: RecordViewModel
    let payload: RecordViewModel.SavePayload
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var name: String = ""
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Сохранение комнаты") { model.savePayload = nil }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Карта готова")
                        .font(Theme.Fonts.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 16)
                    Text("Привязка к стене сохранится вместе с трассами.")
                        .font(Theme.Fonts.subheadlineRegular)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 10)

                    ZStack(alignment: .topLeading) {
                        Group {
                            if let image = payload.preview {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Image("wall_rough").resizable().scaledToFill()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 224)
                        .clipped()

                        TagLabel(text: "\(Formatters.routes(model.totalCount)) · \(Formatters.meters(model.totalLength))",
                                 color: Theme.Colors.safe)
                            .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
                    .padding(.top, 26)

                    LabeledField(label: "Название комнаты", placeholder: "Кухня", text: $name)
                        .padding(.top, 24)

                    Text("Объект: \(model.project.name)")
                        .font(Theme.Fonts.subheadlineRegular)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 22)

                    InfoCard(title: "Оставьте ориентир в кадре",
                             text: "Угол стены или проём помогут найти её позже.")
                        .padding(.top, 22)

                    if let errorText {
                        Text(errorText).font(Theme.Fonts.footnoteRegular).foregroundStyle(Theme.Colors.danger)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Сохранить", action: save)
                .buttonStyle(.primary)
                .disabled(name.trimmed.isEmpty)
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 8)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .onAppear { if name.isEmpty { name = model.existingRoom?.name ?? "" } }
    }

    private func save() {
        do {
            try RoomRepository(context: context).saveRecording(
                project: model.project,
                existingRoom: model.existingRoom,
                name: name,
                drafts: model.drafts,
                worldMapData: payload.worldMapData,
                previewData: payload.preview?.jpegData(compressionQuality: 0.7)
            )
            Haptics.success()
            onSaved()
        } catch {
            errorText = "Не удалось сохранить: \(error.localizedDescription)"
        }
    }
}
