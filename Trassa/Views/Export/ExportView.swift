import SwiftUI

/// Экраны 16, 27 · Экспорт схемы в PDF
struct ExportView: View {
    let room: Room
    @State private var result: PDFExporter.Result?
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Экспорт схемы")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Для мебельщиков")
                        .font(Theme.Fonts.inter(28, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 14)
                    Text("Схема трасс и зоны, где нельзя сверлить.")
                        .font(Theme.Fonts.subheadlineRegular)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 13)

                    PDFPreviewCard(room: room)
                        .frame(width: 288, height: 344)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 25)

                    Text("В PDF войдут")
                        .font(Theme.Fonts.button)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, 30)
                    Text("Схема · типы и длины · фото штроб\nЗаметки · дата · зона запрета ±15 см")
                        .font(Theme.Fonts.subheadlineRegular)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 13)

                    Group {
                        if let result {
                            Text("✓  \(result.url.lastPathComponent) · \(pagesText(result.pageCount))")
                                .foregroundStyle(Theme.Colors.safe)
                        } else if let errorText {
                            Text(errorText).foregroundStyle(Theme.Colors.danger)
                        } else {
                            Text("Готовим файл…").foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .font(Theme.Fonts.captionBold)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                    .padding(.top, 28)
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if let result {
                    ShareLink(item: result.url, preview: SharePreview("Схема · \(room.name)")) {
                        Text("Поделиться PDF")
                    }
                    .buttonStyle(.primary)
                } else {
                    Button("Поделиться PDF") {}.buttonStyle(.primary).disabled(true)
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 8)
        }
        .trassaScreen()
        .task {
            do { result = try PDFExporter.export(room: room) }
            catch { errorText = "Не удалось создать PDF: \(error.localizedDescription)" }
        }
    }

    private func pagesText(_ n: Int) -> String { Formatters.plural(n, "страница", "страницы", "страниц") }
}

/// Мини-превью первой страницы PDF (светлый лист, как в макете)
struct PDFPreviewCard: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ТРАССА / СХЕМА КОМНАТЫ")
                .font(Theme.Fonts.microLabel)
                .foregroundStyle(Theme.Colors.textMuted)
            Text(room.name)
                .font(Theme.Fonts.inter(24, .bold))
                .foregroundStyle(Theme.Colors.background)
                .padding(.top, 12)
            Text(room.project?.name ?? "")
                .font(Theme.Fonts.inter(11))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.top, 4)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.withCGContext { cg in
                    Schematic.draw(Schematic.layout(for: room, in: rect.insetBy(dx: 8, dy: 8)), in: cg, rect: rect, forPrint: true)
                }
            }
            .frame(height: 132)
            .padding(.top, 18)

            Text("±15 см от трассы - не сверлить")
                .font(Theme.Fonts.inter(10, .semibold))
                .foregroundStyle(Theme.Colors.paperDanger)
                .padding(.top, 14)
            Text("\(Formatters.routes(room.routes.count)) · \(Formatters.meters(room.totalLength)) · \(Formatters.numeric.string(from: room.updatedAt))")
                .font(Theme.Fonts.inter(10))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.top, 10)
            Text("Проверьте детектором перед сверлением.")
                .font(Theme.Fonts.inter(9))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Theme.Colors.paper, in: RoundedRectangle(cornerRadius: 4))
    }
}
