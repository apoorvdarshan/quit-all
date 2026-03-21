import UIKit

// MARK: - Haptic Feedback Manager
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    func sosButton() {
        impact(.heavy)
    }

    func milestone() {
        notification(.success)
    }

    func relapse() {
        notification(.warning)
    }

    func cravingSurvived() {
        notification(.success)
    }
}
