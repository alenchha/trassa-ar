import SwiftUI

/// Верхняя панель AR-экранов: «Закрыть», название комнаты, режим, кнопка справа
struct ARTopBar<Trailing: View>: View {
    let title: String
    let mode: String
    let modeColor: Color
    let onClose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            IconButton(systemName: "xmark", action: onClose)
                .accessibilityLabel("Закрыть")
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary).lineLimit(1)
                Text(mode).font(Theme.Fonts.label).foregroundStyle(modeColor)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea(edges: .top))
    }
}
