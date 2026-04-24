import UIKit

struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // Convenience
    static func handSelected()   { impact(.medium) }
    static func stampSent()      { impact(.light) }
    static func gameStarted()    { impact(.heavy) }
    static func handsRevealed()  { notification(.success) }
    static func announcement()   { notification(.warning) }
    static func drawDetected()   { notification(.error) }
    static func nameChanged()    { impact(.soft) }
}
