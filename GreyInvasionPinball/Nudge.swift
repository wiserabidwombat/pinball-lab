import SpriteKit
import UIKit
import QuartzCore

/// Pinball Lab · the nudge and the tilt, shared by every table (Play Lab plan 2, round 8).
///
/// A nudge is a short shove of the whole machine: every free ball on the floor gets the same velocity kick
/// (sideways, or a smaller one upward). Nudges are counted in a rolling window: the second within `window` seconds
/// shows TILT WARNING, the third tilts — the table's flippers go dead until the next ball is served. The table owns
/// the input (a flick of a flipper finger, the pad's left stick or d-pad — see `Swipe` and `LabGamepad.State.nudge`),
/// the feel (camera shake, haptic, banner) and which balls count as free; this class does the physics and the rule.
///
///   let nudge = Nudge()
///   switch nudge.nudge(.left, at: gameTime, balls: freeBodies) { case .nudged … case .warning … case .tilt … }
///   if nudge.tilted { left = false; right = false }          // in updateFlippers
///   nudge.newBall()                                           // when a ball is served
@MainActor
final class Nudge {
    /// pt/s added to every free ball by one sideways nudge. About a ball width of travel for a slow ball — enough
    /// to pull a ball off an outlane wall onto the lane guide, never enough to throw a ball across the table.
    static let sideKick: CGFloat = 110
    /// The upward kick. A real machine barely lifts the ball; this one gives a ball dying in the centre gap a
    /// chance to touch a flipper tip.
    static let upKick: CGFloat = 80
    /// Seconds of the rolling window the nudges are counted in.
    static let window: TimeInterval = 3
    /// The second nudge in the window warns; the third tilts.
    static let warningAt = 2
    static let tiltAt = 3
    /// A swipe that spills over two frames, or a stick bounce, is one nudge, not two.
    static let debounce: TimeInterval = 0.12

    enum Direction: String {
        case left, right, up

        var kick: CGVector {
            switch self {
            case .left:  return CGVector(dx: -Nudge.sideKick, dy: 0)
            case .right: return CGVector(dx: Nudge.sideKick, dy: 0)
            case .up:    return CGVector(dx: 0, dy: Nudge.upKick)
            }
        }

        /// The direction as a unit vector (world axes: y up), for the camera's lurch.
        var unit: CGVector {
            switch self {
            case .left:  return CGVector(dx: -1, dy: 0)
            case .right: return CGVector(dx: 1, dy: 0)
            case .up:    return CGVector(dx: 0, dy: 1)
            }
        }
    }

    // MARK: Feel, shared so every table nudges alike

    /// The camera lurch in screen points for a nudge, the warning and the tilt.
    static let joltNudge: CGFloat = 16
    static let joltWarning: CGFloat = 24
    static let joltTilt: CGFloat = 36

    private static let thump = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    /// A heavy thump for a nudge; the system's warning pattern for TILT WARNING and its error pattern for TILT.
    /// Quiet when the player has turned haptics off.
    static func haptic(for outcome: Outcome) {
        guard Haptic.enabled else { return }
        switch outcome {
        case .nudged:  thump.impactOccurred(intensity: 1)
        case .warning: notice.notificationOccurred(.warning)
        case .tilt:    notice.notificationOccurred(.error)
        case .ignored: break
        }
    }

    enum Outcome { case nudged, warning, tilt, ignored }

    /// Tilted: the flippers are dead until `newBall()`.
    private(set) var tilted = false
    /// How many nudges count against the player right now (0…2 before a tilt).
    var warnings: Int { times.count }
    private var times: [TimeInterval] = []
    private var lastAt: TimeInterval = -.infinity

    /// One nudge. `now` is the table's game clock; `balls` the bodies of the balls that are free to be shoved.
    func nudge(_ direction: Direction, at now: TimeInterval, balls: [SKPhysicsBody]) -> Outcome {
        guard !tilted, now - lastAt >= Self.debounce else { return .ignored }
        lastAt = now
        let k = direction.kick
        for body in balls {
            body.velocity = CGVector(dx: body.velocity.dx + k.dx, dy: body.velocity.dy + k.dy)
        }
        times = times.filter { now - $0 < Self.window } + [now]
        if times.count >= Self.tiltAt {
            tilted = true
            return .tilt
        }
        return times.count >= Self.warningAt ? .warning : .nudged
    }

    /// A ball is served: the tilt and the warnings clear.
    func newBall() {
        tilted = false
        times.removeAll()
        lastAt = -.infinity
    }

    // MARK: Touch: a flick of a flipper finger

    /// A finger holding a flipper button can nudge without letting go: a quick move of `swipeDistance` screen points
    /// within `swipeTime` seconds is a nudge in the dominant direction (up, left or right; a downward flick does
    /// nothing). After a flick the finger re-arms from where it is, so a second flick can follow — the tilt rule
    /// above decides whether that was wise.
    static let swipeDistance: CGFloat = 40
    static let swipeTime: TimeInterval = 0.25

    private var swipeStarts: [ObjectIdentifier: (point: CGPoint, time: TimeInterval)] = [:]

    func swipeBegan(_ touch: UITouch, at point: CGPoint) {
        swipeStarts[ObjectIdentifier(touch)] = (point, CACurrentMediaTime())
    }

    /// Screen points (UIKit: y grows downward). Returns the nudge direction when this move completes a flick.
    func swipeMoved(_ touch: UITouch, to point: CGPoint) -> Direction? {
        let id = ObjectIdentifier(touch)
        let now = CACurrentMediaTime()
        guard let start = swipeStarts[id] else { return nil }
        if now - start.time > Self.swipeTime {
            swipeStarts[id] = (point, now)          // too slow: measure from here
            return nil
        }
        let dx = point.x - start.point.x, dy = point.y - start.point.y
        guard max(abs(dx), abs(dy)) >= Self.swipeDistance else { return nil }
        swipeStarts[id] = (point, now)              // re-arm from here
        if abs(dy) > abs(dx) { return dy < 0 ? .up : nil }
        return dx < 0 ? .left : .right
    }

    func swipeEnded(_ touch: UITouch) {
        swipeStarts.removeValue(forKey: ObjectIdentifier(touch))
    }
}
