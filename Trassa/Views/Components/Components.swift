import SwiftUI
import UIKit

// MARK: - Кнопки (UI KIT: оранжевая, тёмная с обводкой, текстовая)

struct PrimaryButtonStyle: ButtonStyle {
    var font: Font = Theme.Fonts.button
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(Theme.Colors.onAccent)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.buttonHeight)
            .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.button)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.buttonHeight)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.radius)
                .stroke(Theme.Colors.border, lineWidth: Theme.Metrics.hairline))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(Rectangle())
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.button)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.buttonHeight)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: PrimaryButtonStyle { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var secondary: SecondaryButtonStyle { .init() } }
extension ButtonStyle where Self == GhostButtonStyle { static var ghost: GhostButtonStyle { .init() } }

/// Квадратная кнопка 56×56 («Закрыть», «Список трасс»)
struct IconButton: View {
    let systemName: String
    var background: Color = Theme.Colors.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: Theme.Metrics.iconButton, height: Theme.Metrics.iconButton)
                .background(background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Навигационная шапка (кнопка «Назад» + заголовок 18/600)

struct NavHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 8) {
            Button { onBack?() ?? dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")

            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(height: 56)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

// MARK: - Карточки и плашки

struct CardBackground: ViewModifier {
    var stroke: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: Theme.Metrics.radius).stroke(stroke, lineWidth: 1)
                }
            }
    }
}

extension View {
    func card(stroke: Color? = nil) -> some View { modifier(CardBackground(stroke: stroke)) }

    /// Стандартный экран: фон макета, скрытая системная панель навигации
    func trassaScreen() -> some View {
        self
            .background(Theme.Colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// Карточка-подсказка: заголовок 16/600 + текст 13/400
struct InfoCard: View {
    var icon: String? = nil
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(Theme.Fonts.button).foregroundStyle(Theme.Colors.textPrimary)
                Text(text).font(Theme.Fonts.footnoteRegular).foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Metrics.cardPadding)
        .card()
    }
}

/// Капслок-метка в тёмной плашке («ДО ОТДЕЛКИ», «12 ТРАСС СОХРАНЕНО»)
struct TagLabel: View {
    let text: String
    var color: Color = Theme.Colors.accent
    var background: Color = Theme.Colors.background

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Fonts.label)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Плашка поверх камеры (#101214, радиус 8–12)
struct OverlayPill<Content: View>: View {
    var radius: CGFloat = Theme.Metrics.smallRadius
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: radius))
    }
}

/// Чип выбора типа трассы: цветная точка + название, выбранный — с обводкой цвета трассы
struct RouteTypeChip: View {
    let type: RouteType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(type.color).frame(width: Theme.Metrics.routeDot, height: Theme.Metrics.routeDot)
                Text(type.title).font(Theme.Fonts.subheadline).foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.buttonHeight)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.radius)
                .stroke(isSelected ? type.color : Theme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Индикатор качества: 4 столбика высотой 8/12/16/20
struct QualityBars: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < level ? Theme.Colors.safe : Theme.Colors.border)
                    .frame(width: 4, height: CGFloat(8 + i * 4))
            }
        }
    }
}

/// Плашка результата «Безопасно» / «Трасса в 8 см — электрика»
struct DrillResultCard: View {
    let isDangerous: Bool
    let title: String
    let subtitle: String

    var body: some View {
        let color = isDangerous ? Theme.Colors.danger : Theme.Colors.safe
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(Theme.Fonts.title3).foregroundStyle(color)
            Text(subtitle).font(Theme.Fonts.footnoteRegular).foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(.horizontal, 16)
        .card(stroke: color)
    }
}

/// Прицел 56×56 в центре экрана
struct Reticle: View {
    var color: Color = Theme.Colors.accent

    var body: some View {
        Image(systemName: "plus.viewfinder")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(color)
            .frame(width: Theme.Metrics.reticle, height: Theme.Metrics.reticle)
            .background(Theme.Colors.overlay, in: RoundedRectangle(cornerRadius: Theme.Metrics.reticleRadius))
    }
}

/// Уголки рамки поиска на экране «Наведите на ту же стену»
struct CornerBrackets: Shape {
    var length: CGFloat = 32

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = length
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

/// Поле ввода в стиле макета: подпись сверху, тёмное поле 64 pt
struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(Theme.Fonts.subheadlineRegular).foregroundStyle(Theme.Colors.textSecondary)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.Colors.textMuted))
                .font(Theme.Fonts.inter(17, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 64)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
        }
    }
}

/// Картинка из Data или запасное фото из макета
struct PhotoView: View {
    let data: Data?
    var placeholder: String = "wall_rough"

    var body: some View {
        GeometryReader { geo in
            Group {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(placeholder).resizable().scaledToFill()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

// MARK: - Возвращаем жест «смахнуть назад» при скрытой панели навигации

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
