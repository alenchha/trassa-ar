import SwiftUI
import SwiftData

/// Экран 06 · Новый объект
struct NewProjectView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @State private var name = ""
    @State private var address = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavHeader(title: "Новый объект")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("С чего начнём?")
                        .font(Theme.Fonts.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 16)
                    Text("Объедините комнаты одной квартиры\nили дома в общий объект.")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 12)

                    LabeledField(label: "Название объекта", placeholder: "ЖК «Речной» · кв. 42", text: $name)
                        .padding(.top, 39)
                    LabeledField(label: "Адрес · необязательно", placeholder: "Ленинградский пр-т, 18", text: $address)
                        .padding(.top, 24)

                    InfoCard(icon: "cube", title: "Сначала — первая комната",
                             text: "Наведите камеру на открытую стену\nи отметьте трубы и кабели.")
                        .padding(.top, 48)
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Создать и записать комнату", action: create)
                .buttonStyle(.primary)
                .disabled(name.trimmed.isEmpty)
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 8)
        }
        .trassaScreen()
    }

    private func create() {
        let project = RoomRepository(context: context).createProject(name: name, address: address)
        // Заменяем экран создания на список комнат и сразу открываем AR-запись
        router.path = [.project(project)]
        router.record = RecordRequest(project: project, room: nil)
    }
}
