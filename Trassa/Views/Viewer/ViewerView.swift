import SwiftUI

/// Экраны 10–13 · Поиск стены, просмотр трасс, проверка сверления
struct ViewerView: View {
    @StateObject private var model: ViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRoutes = false
    @State private var bracketsPulse = false
    @State private var checkTip = false

    init(request: ViewRequest) {
        _model = StateObject(wrappedValue: ViewerViewModel(request: request))
    }

    var body: some View {
        ZStack {
            ARViewContainer(controller: model.controller).ignoresSafeArea()
            Theme.Colors.cameraDim.ignoresSafeArea().allowsHitTesting(false)

            if model.isSearching { searchingBrackets } else { reticle }

            VStack(spacing: 0) {
                ARTopBar(title: model.room.name, mode: "AR / ПРОСМОТР", modeColor: Theme.Colors.safe,
                         onClose: { dismiss() }) {
                    IconButton(systemName: "list.bullet") { showRoutes = true }
                        .accessibilityLabel("Список трасс")
                }
                topOverlay
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 16)
                Spacer()
                bottomPanel
            }
        }
        .background(Theme.Colors.background)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showRoutes) {
            NavigationStack { RoutesSheet(room: model.room) }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.Colors.background)
        }
        .alert("Карта не загружена", isPresented: Binding(get: { model.loadError != nil }, set: { if !$0 { model.loadError = nil } })) {
            Button("Закрыть", role: .cancel) { dismiss() }
        } message: { Text(model.loadError ?? "") }
        .alert("Ошибка AR", isPresented: Binding(get: { model.controller.errorMessage != nil },
                                                 set: { if !$0 { model.controller.errorMessage = nil } })) {
            Button("Закрыть", role: .cancel) { dismiss() }
        } message: { Text(model.controller.errorMessage ?? "") }
    }

    // MARK: - Поиск стены (экран 10)

    private var searchingBrackets: some View {
        VStack(spacing: 24) {
            CornerBrackets(length: 32)
                .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 4))
                .frame(width: 200, height: 180)
                .scaleEffect(bracketsPulse ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bracketsPulse)
                .onAppear { bracketsPulse = true }
            Text("ПОИСК ОРИЕНТИРОВ")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .allowsHitTesting(false)
    }

    private var reticle: some View {
        Reticle(color: reticleColor)
            .overlay(alignment: .bottom) {
                if model.mode == .check, let label = drillLabel {
                    Text(label.0)
                        .font(Theme.Fonts.captionBold)
                        .foregroundStyle(label.1)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                        .fixedSize()
                        .offset(y: 62)
                }
            }
            .allowsHitTesting(false)
    }

    private var reticleColor: Color {
        guard model.mode == .check, let drill = model.drill else { return Theme.Colors.textPrimary }
        return drill.isDangerous ? Theme.Colors.danger : Theme.Colors.safe
    }

    private var drillLabel: (String, Color)? {
        guard let drill = model.drill else { return ("Наведите прицел на стену", Theme.Colors.textSecondary) }
        guard let distance = drill.distance, let type = drill.nearestType else {
            return ("Трасс поблизости нет", Theme.Colors.safe)
        }
        return drill.isDangerous
            ? ("\(Formatters.centimeters(distance)) до \(type.objectNoun)", Theme.Colors.danger)
            : ("Ближайшая трасса: \(Formatters.centimeters(distance))", Theme.Colors.safe)
    }

    // MARK: - Плашки сверху

    @ViewBuilder
    private var topOverlay: some View {
        if model.isSearching {
            VStack(alignment: .leading, spacing: 12) {
                Text("Наведите на ту же стену…").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(searchSubtitle).font(Theme.Fonts.footnoteRegular).foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
        } else if model.mode == .check {
            HStack {
                Button(action: model.endCheck) {
                    HStack(spacing: 8) {
                        Text("ПРОВЕРКА МЕСТА СВЕРЛЕНИЯ").font(Theme.Fonts.label)
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("●  Стена распознана")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.safe)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                if let focus = model.focusLabel {
                    Text(focus.0)
                        .font(Theme.Fonts.captionBold)
                        .foregroundStyle(focus.1)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Во время поиска подсказываем причину, если трекинг плохой не из-за релокализации
    private var searchSubtitle: String {
        if case .limited(let reason) = model.controller.trackingState, reason != .relocalizing {
            return model.hint.message
        }
        return "Найдите угол или дверной проём."
    }

    // MARK: - Нижняя панель

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSearching {
                Text("Восстанавливаем привязку").font(Theme.Fonts.title2).foregroundStyle(Theme.Colors.textPrimary)
                Text("Двигайтесь медленно. Трассы появятся,\nкогда приложение узнает стену.")
                    .font(Theme.Fonts.footnoteRegular)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 12)
                Button("Отменить поиск") { dismiss() }
                    .buttonStyle(.secondary)
                    .padding(.top, 20)
            } else if model.mode == .check {
                checkPanel
            } else {
                Text("Трассы под отделкой").font(Theme.Fonts.title2).foregroundStyle(Theme.Colors.textPrimary)
                Text("\(Formatters.routes(model.room.routes.count)) · обновлено \(Formatters.dayMonth.string(from: model.room.updatedAt))")
                    .font(Theme.Fonts.footnoteRegular)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 7)
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.danger.opacity(0.75)).frame(width: 16, height: 16)
                    Text("Красная зона: не сверлить ±15 см").font(Theme.Fonts.footnoteRegular)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.smallRadius))
                .padding(.top, 16)
                Button("Можно ли тут сверлить?", action: model.startCheck)
                    .buttonStyle(.primary)
                    .padding(.top, 19)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.background.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private var checkPanel: some View {
        let drill = model.drill
        let dangerous = drill?.isDangerous ?? false
        Group {
            if let drill, let distance = drill.distance, let type = drill.nearestType, drill.isDangerous {
                DrillResultCard(isDangerous: true,
                                title: "Трасса в \(Formatters.centimeters(distance)) — \(type.lowercasedTitle)",
                                subtitle: "Не сверлите в этой зоне")
            } else if drill != nil {
                DrillResultCard(isDangerous: false, title: "Безопасно",
                                subtitle: "По сохранённой схеме трасс нет")
            } else {
                DrillResultCard(isDangerous: false, title: "Наведите на стену",
                                subtitle: "Прицел должен попасть на стену, чтобы проверить место")
            }
        }
        .animation(.easeInOut(duration: 0.15), value: dangerous)

        Text(checkTip
             ? "Медленно сдвигайте прицел — результат обновляется сразу."
             : "Оценка по сохранённой карте.\nПеред сверлением проверьте детектором.")
            .font(Theme.Fonts.footnoteRegular)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.top, 14)
        Button(dangerous ? "Найти безопасное место" : "Проверить рядом") { checkTip = true }
            .buttonStyle(.secondary)
            .padding(.top, 22)
    }
}

/// Список трасс поверх AR (кнопка справа вверху)
private struct RoutesSheet: View {
    let room: Room
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Трассы · \(room.name)").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, 20)
                ForEach(room.sortedRoutes) { route in
                    RouteCard(route: route)
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
        }
    }
}
