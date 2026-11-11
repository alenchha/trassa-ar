import SwiftUI
import UIKit

/// Тип инженерной трассы. Цвета взяты из макета («Система трасс»).
enum RouteType: String, CaseIterable, Codable, Identifiable {
    case electric
    case water
    case heating
    case lowVoltage

    var id: String { rawValue }

    /// Название для интерфейса
    var title: String {
        switch self {
        case .electric: "Электрика"
        case .water: "Вода"
        case .heating: "Отопление"
        case .lowVoltage: "Слаботочка"
        }
    }

    /// Что именно в стене - для фразы «8 см до кабеля»
    var objectNoun: String {
        switch self {
        case .electric: "кабеля"
        case .water: "трубы"
        case .heating: "трубы отопления"
        case .lowVoltage: "слаботочного кабеля"
        }
    }

    /// Название в нижнем регистре: «Трасса в 8 см - электрика»
    var lowercasedTitle: String { title.lowercased() }

    var color: Color {
        switch self {
        case .electric: Theme.RouteColors.electric
        case .water: Theme.RouteColors.water
        case .heating: Theme.RouteColors.heating
        case .lowVoltage: Theme.RouteColors.lowVoltage
        }
    }

    var uiColor: UIColor { UIColor(color) }

    /// Более тёмный цвет для печати на светлом листе PDF
    var printColor: UIColor {
        switch self {
        case .electric: Theme.RouteColors.electricPrint
        case .water: Theme.RouteColors.waterPrint
        case .heating: Theme.RouteColors.heatingPrint
        case .lowVoltage: Theme.RouteColors.lowVoltagePrint
        }
    }
}
