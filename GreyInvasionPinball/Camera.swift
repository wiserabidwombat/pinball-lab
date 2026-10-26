import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// Camera modes, closest to farthest. Flying is the default.
/// Wide was added after the first playtest (Aaron: a level between Flying and the full table).
enum CameraMode: String, CaseIterable {
    case flying, wide, topDown

    var label: String {
        switch self {
        case .flying: return "Flying"
        case .wide: return "Wide"
        case .topDown: return "Top-Down"
        }
    }

    /// The next mode for the camera button: Flying → Wide → Top-Down → Flying.
    var next: CameraMode {
        switch self {
        case .flying: return .wide
        case .wide: return .topDown
        case .topDown: return .flying
        }
    }

    /// Short name for the debug build tag.
    var tag: String {
        switch self {
        case .flying: return "FLY"
        case .wide: return "WIDE"
        case .topDown: return "TOP"
        }
    }
}

/// Camera numbers, tuned on device in milestone 2.
enum CameraTuning {
    /// How much of the table's width Flying shows (world points). The phone and the
    /// table have almost the same aspect, so this also shows about 63% of the height.
    /// Aaron, playtest 1: "I like the current zoom level."
    static let flyingVisibleWidth: CGFloat = 380
    /// Wide: about halfway between Flying and the full table (~83% of the width,
    /// so it only follows a little up and down). Same follow rules as Flying.
    static let wideVisibleWidth: CGFloat = 500
    /// iPad (2026-10-25): the least table height (world points, of 1300) Flying and Wide show, so a squarer
    /// screen zooms out instead of showing a strip. An iPhone 17 Pro Max shows 826 / 1086 by the width rule,
    /// so phones keep their framing. Shared by all four table cameras.
    static let flyingMinVisibleHeight: CGFloat = 780
    static let wideMinVisibleHeight: CGFloat = 1040
    /// 0 = never follow sideways, 1 = keep the ball centred. Light follow, per the skill.
    static let horizontalFollow: CGFloat = 0.45
    /// Look ahead along the ball's vertical speed (seconds of travel), capped.
    static let lookAheadTime: CGFloat = 0.12
    static let maxLookAhead: CGFloat = 140
    /// Below this height the view locks to the bottom of the table so the flippers stay in view.
    static let lowerThirdY: CGFloat = 1300 / 3
    /// Critically damped follow: higher = snappier.
    static let followRate: CGFloat = 6
    /// The camera ignores target moves smaller than this (world points), so it doesn't jitter.
    static let deadZone: CGFloat = 6
    /// World points shown past each table edge.
    static let margin: CGFloat = 12
    /// Screen points at the top kept clear for the HUD.
    static let hudHeight: CGFloat = 56
}

/// Owns the scene's camera and moves it each frame toward the framing for the current mode.
@MainActor
final class CameraRig {
    let node = SKCameraNode()
    /// Where the follow logic wants the camera; the node sits here plus any shake offset (M9), so
    /// a shake never disturbs the follow.
    private var base = CGPoint.zero
    private var shakeLeft: TimeInterval = 0
    private var shakeDuration: TimeInterval = 0
    private var shakeStrength: CGFloat = 0
    // Round 8: a directional lurch (the nudge) — the table jumps along the shove and springs back.
    private var joltLeft: TimeInterval = 0
    private var joltDuration: TimeInterval = 0
    private var joltVector = CGVector.zero          // screen points the TABLE appears to move at the peak

    /// Camera shake (milestone 9): `strength` is the largest offset in SCREEN points (2 small hit,
    /// 4–6 big hit, 10 jackpot). A stronger shake replaces a weaker one. Skipped with Reduce Motion.
    func shake(strength: CGFloat, duration: TimeInterval = 0.3) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let current = shakeDuration > 0 ? shakeStrength * CGFloat(shakeLeft / shakeDuration) : 0
        guard strength >= current else { return }
        shakeStrength = strength
        shakeDuration = duration
        shakeLeft = duration
    }

    /// Round 8: the table lurches `strength` SCREEN points along `direction` (world axes) and springs back over
    /// `duration`. Rides on top of any shake. Skipped with Reduce Motion.
    func jolt(_ direction: CGVector, strength: CGFloat, duration: TimeInterval = 0.22) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        joltVector = CGVector(dx: direction.dx * strength, dy: direction.dy * strength)
        joltDuration = duration
        joltLeft = duration
    }

    func install(in scene: SKScene) {
        scene.addChild(node)
        scene.camera = node
    }

    /// Call once per frame after physics. `viewSize` is the view in points
    /// (the scene's size under .resizeFill). `snap` jumps straight to the target.
    func update(viewSize: CGSize, ball: SKNode?, mode: CameraMode, dt: CGFloat, snap: Bool = false) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let goal = target(viewSize: viewSize, ball: ball, mode: mode)

        if snap || dt <= 0 {
            node.setScale(goal.scale)
            base = goal.position
            node.position = base
            return
        }

        let a = 1 - exp(-dt * CameraTuning.followRate)
        let scale = node.xScale + (goal.scale - node.xScale) * a
        node.setScale(scale)

        // Move only by how far the target sits outside the dead zone.
        let dead = CameraTuning.deadZone
        let dx = goal.position.x - base.x
        let dy = goal.position.y - base.y
        let ex = dx - min(max(dx, -dead), dead)
        let ey = dy - min(max(dy, -dead), dead)
        base = CGPoint(x: base.x + ex * a, y: base.y + ey * a)

        var offset = CGPoint.zero
        if shakeLeft > 0 {
            shakeLeft = max(0, shakeLeft - TimeInterval(dt))
            let amount = shakeStrength * CGFloat(shakeLeft / max(shakeDuration, 0.001)) * node.xScale
            offset = CGPoint(x: .random(in: -1...1) * amount, y: .random(in: -1...1) * amount)
        }
        if joltLeft > 0 {
            joltLeft = max(0, joltLeft - TimeInterval(dt))
            let p = 1 - CGFloat(joltLeft / max(joltDuration, 0.001))          // 0 → 1 over the jolt
            let a = sin(p * .pi) * (1 - 0.5 * p) * node.xScale
            // the camera goes the other way, so the table jumps along the nudge and eases back
            offset.x -= joltVector.dx * a
            offset.y -= joltVector.dy * a
        }
        node.position = CGPoint(x: base.x + offset.x, y: base.y + offset.y)
    }

    private func target(viewSize: CGSize, ball: SKNode?, mode: CameraMode) -> (position: CGPoint, scale: CGFloat) {
        let w = TableLayout.worldSize.width
        let h = TableLayout.worldSize.height
        let m = CameraTuning.margin
        let hud = CameraTuning.hudHeight

        switch mode {
        case .topDown:
            // Whole table fits below the HUD with a small margin.
            let usableHeight = max(viewSize.height - hud, 1)
            let scale = max((w + 2 * m) / viewSize.width, (h + 2 * m) / usableHeight)
            let visibleHeight = viewSize.height * scale
            return (CGPoint(x: w / 2, y: -m + visibleHeight / 2), scale)

        case .flying, .wide:
            let visibleWidth = mode == .flying ? CameraTuning.flyingVisibleWidth : CameraTuning.wideVisibleWidth
            // iPad (2026-10-25): the width rule alone shows only ~1/3 of the table's height on a 3:4 screen and
            // a sliver in landscape, so a minimum visible height applies too. Phones (~9:19.5) already show
            // more than the minimum, so their framing is unchanged.
            let minVisibleHeight = mode == .flying ? CameraTuning.flyingMinVisibleHeight : CameraTuning.wideMinVisibleHeight
            let scale = max(visibleWidth / viewSize.width, minVisibleHeight / viewSize.height)
            let visW = viewSize.width * scale
            let visH = viewSize.height * scale
            let minX = -m + visW / 2
            let maxX = max(minX, w + m - visW / 2)
            let minY = -m + visH / 2                          // bottom of the view at the apron
            let maxY = max(minY, h + m + hud * scale - visH / 2)  // top of the arch just under the HUD

            var tx = w / 2
            var ty = minY
            if let ball {
                let b = ball.position
                tx = w / 2 + (b.x - w / 2) * CameraTuning.horizontalFollow
                if b.y >= CameraTuning.lowerThirdY {
                    let vy = ball.physicsBody?.velocity.dy ?? 0
                    let look = min(max(vy * CameraTuning.lookAheadTime, -CameraTuning.maxLookAhead),
                                   CameraTuning.maxLookAhead)
                    ty = b.y + look
                }
            }
            // When the view is wider than the table (iPad Wide, landscape), keep the table centred.
            let x = visW >= w + 2 * m ? w / 2 : min(max(tx, minX), maxX)
            return (CGPoint(x: x, y: min(max(ty, minY), maxY)), scale)
        }
    }
}
