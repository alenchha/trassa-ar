import SwiftUI

/// Экраны 07, 08, 17-22, 26 · AR-запись трасс
struct RecordView: View {
    @StateObject private var model: RecordViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClose = false

    init(request: RecordRequest) {
        _model = StateObject(wrappedValue: RecordViewModel(request: request))
    }

    var body: some View {
        ZStack {
            ARViewContainer(controller: model.controller)
                .ignoresSafeArea()
            Theme.Colors.cameraDim.ignoresSafeArea().allowsHitTesting(false)

            // Прицел строго в центре ARView - туда же направлен raycast
            Reticle()
                .overlay(alignment: .topLeading) {
                    if let label = model.currentLineLabel {
                        Text(label)
                            .font(Theme.Fonts.captionBold)
                            .foregroundStyle(model.current.type.color)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: 6))
                            .fixedSize()
                            .offset(x: 44, y: -24)
                    }
                }
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                ARTopBar(title: model.existingRoom?.name ?? "Новая комната", mode: "●  ЗАПИСЬ",
                         modeColor: Theme.Colors.accent, onClose: close) {
                    saveButton
                }
                hints
                Spacer()
                cameraFooter
                bottomPanel
            }

            if model.isCapturing {
                ProgressView("Сохраняем карту…")
                    .tint(Theme.Colors.accent)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(24)
                    .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            }

            if let payload = model.savePayload {
                SaveRoomView(model: model, payload: payload) { dismiss() }
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.savePayload != nil)
        .background(Theme.Colors.background)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .alert("Трасса", isPresented: Binding(get: { model.alertMessage != nil },
                                               set: { if !$0 { model.alertMessage = nil } })) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .alert("Ошибка AR", isPresented: Binding(get: { model.controller.errorMessage != nil },
                                                 set: { if !$0 { model.controller.errorMessage = nil } })) {
            Button("Закрыть", role: .cancel) { dismiss() }
        } message: {
            Text(model.controller.errorMessage ?? "")
        }
        .confirmationDialog("Выйти без сохранения?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Выйти, трассы не сохранятся", role: .destructive) { dismiss() }
            Button("Продолжить запись", role: .cancel) {}
        }
    }

    private func close() {
        if model.drafts.isEmpty && model.current.points.isEmpty { dismiss() } else { confirmClose = true }
    }

    /// «Сохранить» - визуально неактивна, пока карта не .mapped, но по нажатию объясняет почему
    private var saveButton: some View {
        Button(action: model.requestSave) {
            VStack(spacing: 2) {
                Image(systemName: model.isMapped ? "checkmark" : "square.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                Text("Сохранить").font(Theme.Fonts.microLabel)
            }
            .foregroundStyle(model.isMapped ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
            .frame(width: 72, height: Theme.Metrics.iconButton)
            .background(model.isMapped ? Theme.Colors.accent : Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
        }
        .buttonStyle(.plain)
        .accessibilityHint(model.isMapped ? "Сохранить комнату" : model.mappingStatus.saveExplanation)
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 17) {
                QualityBars(level: model.hint.level)
                Text(model.hint.qualityText).font(Theme.Fonts.footnote).foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: 0)
                Text(model.isMapped ? "Карта готова" : "Карта: \(mappingShort)")
                    .font(Theme.Fonts.microLabel)
                    .foregroundStyle(model.isMapped ? Theme.Colors.safe : Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))

            Text(model.needsRelocalization ? "Наведите на ту же стену, что при записи - старые трассы появятся на месте" : model.hint.message)
                .font(Theme.Fonts.callout)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 16)
    }

    private var mappingShort: String {
        switch model.mappingStatus {
        case .notAvailable: "нет"
        case .limited: "мало данных"
        case .extending: "почти"
        case .mapped: "готова"
        @unknown default: "-"
        }
    }

    private var cameraFooter: some View {
        HStack(spacing: 16) {
            Button(action: model.undo) {
                HStack(spacing: 11) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 18, weight: .medium))
                    Text("Отменить").font(Theme.Fonts.footnote)
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .frame(width: 150, height: 56, alignment: .leading)
                .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            }
            .buttonStyle(.plain)
            .opacity(model.canUndo ? 1 : 0.45)
            .disabled(!model.canUndo)

            Text(model.statusText)
                .font(Theme.Fonts.inter(11, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 12)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.panelTitle)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 16)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 8) {
                ForEach(RouteType.allCases) { type in
                    RouteTypeChip(type: type, isSelected: model.selectedType == type) { model.select(type) }
                }
            }
            .padding(.top, 12)

            HStack(spacing: 16) {
                Button("Поставить точку", action: model.placePoint)
                    .buttonStyle(PrimaryButtonStyle(font: Theme.Fonts.inter(14, .bold)))
                    .disabled(!model.canPlacePoint)
                Button(action: model.finishLine) {
                    Text("Закончить линию")
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
                }
                .buttonStyle(.plain)
                .opacity(model.current.points.isEmpty ? 0.45 : 1)
                .disabled(model.current.points.isEmpty)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .background(Theme.Colors.background.ignoresSafeArea(edges: .bottom))
    }
}
