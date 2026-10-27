import UIKit

/// iPad polish (2026-10-26): the frame rate to ask SpriteKit for — the screen's own maximum (120 on a ProMotion
/// iPhone, 60 on an iPad Air or a non-Pro iPhone). Asking for 120 on a 60 Hz screen left the frame pacing to the
/// system; asking for exactly what the screen can show keeps every frame evenly spaced. The tables' physics already
/// follow the real frame time (their 60 Hz flip assist switches itself on), so nothing else changes.
@MainActor
enum DisplayRate {
    static var max: Int {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        return Swift.max(60, screen?.maximumFramesPerSecond ?? 60)
    }
}
