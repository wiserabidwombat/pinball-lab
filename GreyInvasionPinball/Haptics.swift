import UIKit
import CoreGraphics

/// A UIImpactFeedbackGenerator that stays quiet when the player has turned haptics off
/// (milestone 10). Same calls as the generator it wraps.
@MainActor
final class Haptic {
    /// Set from GameSettings.hapticsOn.
    static var enabled = true

    private let generator: UIImpactFeedbackGenerator

    init(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        generator = UIImpactFeedbackGenerator(style: style)
    }

    func prepare() {
        generator.prepare()
    }

    func impactOccurred() {
        guard Self.enabled else { return }
        generator.impactOccurred()
    }

    func impactOccurred(intensity: CGFloat) {
        guard Self.enabled else { return }
        generator.impactOccurred(intensity: intensity)
    }
}
