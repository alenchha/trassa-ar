import SwiftUI
import UIKit

/// Дизайн-токены из макета Figma «Трасса / UI KIT».
/// Все цвета, размеры и шрифты интерфейса берутся только отсюда.
enum Theme {

    // MARK: - Цвета

    enum Colors {
        /// Фон экранов — #101214
        static let background = Color(hex: 0x101214)
        /// Карточки, поля ввода, вторичные кнопки — #1C1F23
        static let surface = Color(hex: 0x1C1F23)
        /// Обводка карточек и неактивные элементы — #34393F
        static let border = Color(hex: 0x34393F)
        /// Основной текст — #F6F7F9
        static let textPrimary = Color(hex: 0xF6F7F9)
        /// Вторичный текст — #AAB2BC
        static let textSecondary = Color(hex: 0xAAB2BC)
        /// Неактивный текст, точки пейджера — #5B6169
        static let textMuted = Color(hex: 0x5B6169)
        /// Фирменный оранжевый — #FF6B00
        static let accent = Color(hex: 0xFF6B00)
        /// Текст на оранжевой кнопке
        static let onAccent = Color(hex: 0x101214)
        /// Плашки поверх камеры (#101214, 75 %)
        static let overlay = Color(hex: 0x101214).opacity(0.75)
        /// Затемнение камеры (#101214, 16 %)
        static let cameraDim = Color(hex: 0x101214).opacity(0.16)

        /// «Безопасно» — #52DBA0
        static let safe = Color(hex: 0x52DBA0)
        /// «Опасно» — #FF5D60
        static let danger = Color(hex: 0xFF5D60)
        /// Красная зона ±15 см (#FF5D60, 24 %)
        static let dangerZone = Color(hex: 0xFF5D60).opacity(0.24)

        // Цвета PDF-листа (светлая «бумага»)
        static let paper = Color(hex: 0xF2F1ED)
        static let paperWall = Color(hex: 0xE0E1DC)
        static let paperDanger = Color(hex: 0xBA3333)
    }

    // MARK: - Цвета трасс

    enum RouteColors {
        static let electric = Color(hex: 0xFFD447)
        static let water = Color(hex: 0x48A8FF)
        static let heating = Color(hex: 0xFF5D60)
        static let lowVoltage = Color(hex: 0x52DBA0)

        // Более тёмные варианты для печати на светлом листе PDF
        static let electricPrint = UIColor(hex: 0xB48700)
        static let waterPrint = UIColor(hex: 0x1877BC)
        static let heatingPrint = UIColor(hex: 0xCE4343)
        static let lowVoltagePrint = UIColor(hex: 0x178858)
    }

    // MARK: - Размеры

    enum Metrics {
        /// Боковой отступ экрана
        static let screenPadding: CGFloat = 24
        /// Внутренний отступ карточки
        static let cardPadding: CGFloat = 16
        /// Расстояние между карточками
        static let cardSpacing: CGFloat = 16
        /// Расстояние между кнопками в сетке
        static let gridSpacing: CGFloat = 16
        /// Высота основной кнопки и touch target
        static let buttonHeight: CGFloat = 56
        /// Квадратные кнопки «Назад», «Закрыть», «Список»
        static let iconButton: CGFloat = 56
        /// Радиус карточек и кнопок
        static let radius: CGFloat = 12
        /// Радиус небольших плашек
        static let smallRadius: CGFloat = 8
        /// Радиус прицела
        static let reticleRadius: CGFloat = 10
        /// Размер прицела
        static let reticle: CGFloat = 56
        /// Толщина обводки
        static let hairline: CGFloat = 1
        /// Высота фото в карточке объекта
        static let projectPhotoHeight: CGFloat = 132
        /// Миниатюра комнаты
        static let roomThumb: CGFloat = 72
        /// Точка-маркер цвета трассы
        static let routeDot: CGFloat = 10
        /// Вертикальная полоса цвета в карточке трассы
        static let routeStripe: CGFloat = 4
    }

    // MARK: - Шрифты (Inter, как в макете)

    enum Fonts {
        static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "Inter-Bold"
            case .semibold: name = "Inter-SemiBold"
            case .medium: name = "Inter-Medium"
            default: name = "Inter-Regular"
            }
            // Если шрифт не зарегистрировался, используем системный той же насыщенности
            if UIFont(name: name, size: size) != nil {
                return .custom(name, fixedSize: size)
            }
            return .system(size: size, weight: weight)
        }

        /// 30/700 — крупный заголовок («Стены помнят.»)
        static let hero = inter(30, .bold)
        /// 32/700 — заголовок экрана («Комнаты»)
        static let largeTitle = inter(32, .bold)
        /// 27/700 — заголовок карточки трассы
        static let title = inter(27, .bold)
        /// 22/700 — заголовок нижней панели AR
        static let title2 = inter(22, .bold)
        /// 21/700 — заголовок плашки результата
        static let title3 = inter(21, .bold)
        /// 18/600 — навбар и названия карточек
        static let headline = inter(18, .semibold)
        /// 16/600 — текст кнопок
        static let button = inter(16, .semibold)
        /// 15/500 — подсказки
        static let callout = inter(15, .medium)
        /// 15/400 — основной текст
        static let body = inter(15)
        /// 14/600 — подписи и чипы
        static let subheadline = inter(14, .semibold)
        /// 14/400 — описания
        static let subheadlineRegular = inter(14)
        /// 13/600 — мелкие подписи
        static let footnote = inter(13, .semibold)
        /// 13/400
        static let footnoteRegular = inter(13)
        /// 12/400
        static let caption = inter(12)
        /// 12/600
        static let captionBold = inter(12, .semibold)
        /// 11/700 — капслок-метки («ЗАПИСЬ»)
        static let label = inter(11, .bold)
        /// 10/700 — капслок-подписи в таблицах
        static let microLabel = inter(10, .bold)
    }
}

// MARK: - Вспомогательные инициализаторы

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
