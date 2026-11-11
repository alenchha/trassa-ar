import UIKit

/// Тактильная отдача
enum Haptics {
    /// Лёгкая вибрация - прицел попал в опасную зону
    static func danger() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Щелчок при постановке точки
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
