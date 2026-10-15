// Pinball Lab Table 03: copied from Grey Invasion (milestone 3) with the "Cth" prefix.
import SpriteKit
import CoreGraphics
import Foundation

/// A scoop (kick-out hole), from Orbit Pinball's wormhole pattern. The scene checks the
/// ball's position each frame: a floor ball whose centre comes within `captureRadius`
/// is caught, held in the hole for a moment, then kicked out along `ejectVelocity`.
/// No physics body, so capture can't tunnel and is never decided in a contact callback.
final class CthScoop: SKNode {
    let ejectVelocity: CGVector
    let points: Int
    private let rim: SKShapeNode

    /// Table 03 milestone 5: each hole can have its own catch radius (the Lagoon's is tighter).
    let captureRadius: CGFloat

    /// Milestone 8: the hole and its chrome rim are baked into the table art; this node only flashes.
    private let artBaked: Bool

    init(at center: CGPoint, ejectVelocity: CGVector, points: Int,
         captureRadius: CGFloat = CthTableLayout.scoopCaptureRadius, artBaked: Bool = false) {
        self.artBaked = artBaked
        self.captureRadius = captureRadius
        self.ejectVelocity = ejectVelocity
        self.points = points
        let r = CthTableLayout.scoopRadius
        rim = SKShapeNode(circleOfRadius: r)
        super.init()
        position = center

        // M8 art round 3 (concept): chrome rim round a dark hole (the hazard ring / glow is painted
        // into the playfield art)
        rim.fillColor = SKColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1)
        rim.strokeColor = SKColor(red: 0.79, green: 0.80, blue: 0.84, alpha: 1)
        rim.lineWidth = 2.5
        addChild(rim)
        if artBaked {
            // Only a white ring that flashes over the painted hole when a ball drops in.
            rim.fillColor = .clear
            rim.strokeColor = SKColor(white: 1, alpha: 0.9)
            rim.blendMode = .add
            rim.alpha = 0
            return
        }
        let hole = SKShapeNode(circleOfRadius: r * 0.7)
        hole.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        hole.strokeColor = .clear
        rim.addChild(hole)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Whether a ball that moved from `start` to `end` this frame passed over the hole.
    /// M10 v4: the whole path is tested, not just where the ball ended up; a hard shot moves
    /// 12–17 pt a frame and used to skip straight over the edge of the hole.
    func catches(from start: CGPoint, to end: CGPoint) -> Bool {
        let dx = end.x - start.x, dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        var t: CGFloat = 1
        if lengthSquared > 0.0001 {
            t = max(0, min(1, ((position.x - start.x) * dx + (position.y - start.y) * dy) / lengthSquared))
        }
        let closest = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(closest.x - position.x, closest.y - position.y) < captureRadius
    }

    /// A quick pulse when the ball drops in.
    func flash() {
        rim.removeAction(forKey: "flash")
        rim.setScale(1.25)
        if artBaked {
            rim.alpha = 1
            rim.run(.group([.scale(to: 1, duration: 0.2), .fadeOut(withDuration: 0.35)]), withKey: "flash")
        } else {
            rim.run(.scale(to: 1, duration: 0.2), withKey: "flash")
        }
    }
}
