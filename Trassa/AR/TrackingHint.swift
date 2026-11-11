import ARKit

/// Понятная пользователю интерпретация состояния ARKit.
struct TrackingHint: Equatable {
    /// Уровень качества 0…4 - число зелёных столбиков индикатора
    let level: Int
    /// «Качество: хорошее»
    let qualityText: String
    /// Подсказка, что делать
    let message: String
    /// Можно ли ставить точки
    let canPlacePoints: Bool

    /// Сопоставляет состояние трекинга камеры и картирования с подсказками на русском.
    static func make(
        tracking: ARCamera.TrackingState,
        mapping: ARFrame.WorldMappingStatus,
        hasSurface: Bool
    ) -> TrackingHint {
        switch tracking {
        case .notAvailable:
            return TrackingHint(level: 0, qualityText: "Качество: нет трекинга",
                                message: "Камера недоступна. Проверьте разрешение в Настройках.",
                                canPlacePoints: false)
        case .limited(let reason):
            let message: String
            switch reason {
            case .initializing:
                message = "Запуск AR… Медленно поводите телефоном по комнате"
            case .excessiveMotion:
                message = "Слишком быстро. Двигайте телефон медленнее"
            case .insufficientFeatures:
                message = "Мало деталей. Добавьте света или наведите на участок с текстурой"
            case .relocalizing:
                message = "Наведите на ту же стену, что при записи"
            @unknown default:
                message = "Трекинг ограничен. Медленно поводите телефоном"
            }
            return TrackingHint(level: 1, qualityText: "Качество: плохое",
                                message: message, canPlacePoints: false)
        case .normal:
            let level: Int
            let quality: String
            switch mapping {
            case .mapped: (level, quality) = (4, "Качество: отличное")
            case .extending: (level, quality) = (3, "Качество: хорошее")
            case .limited: (level, quality) = (2, "Качество: среднее")
            default: (level, quality) = (2, "Качество: среднее")
            }
            let message = hasSurface
                ? "Медленно ведите телефоном\nпо стене"
                : "Наведите прицел на стену.\nСтена должна быть в 0,3-3 м"
            return TrackingHint(level: level, qualityText: quality, message: message, canPlacePoints: hasSurface)
        }
    }
}

extension ARFrame.WorldMappingStatus {
    /// Объяснение, почему карту ещё нельзя сохранить
    var saveExplanation: String {
        switch self {
        case .mapped:
            "Карта готова - можно сохранять."
        case .extending:
            "Почти готово. Поводите телефоном ещё немного: захватите угол стены или проём."
        case .limited:
            "Карта ещё неполная. Медленно обведите камерой стену, углы и соседние стены."
        case .notAvailable:
            "Карта не начата. Пройдитесь с телефоном вдоль стены, не закрывая камеру."
        @unknown default:
            "Поводите телефоном ещё немного."
        }
    }
}
