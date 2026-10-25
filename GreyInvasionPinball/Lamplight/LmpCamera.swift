// Pinball Lab Table 05 (The Lamplight): Table 03's camera rig with the "Lmp" prefix. It shares Grey
// Invasion's CameraMode and CameraTuning (the same saved camera setting drives both tables).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// Owns the scene's camera and moves it each frame toward the framing for the current mode.
@MainActor
final class LmpCameraRig {
    let node = SKCameraNode()
    private var base = CGPoint.zero
    private var shakeLeft: TimeInterval = 0
    private var shakeDuration: TimeInterval = 0
    private var shakeStrength: CGFloat = 0
    // Round 8: a directional lurch (the nudge) — the table jumps along the shove and springs back.
    private var joltLeft: TimeInterval = 0
    private var joltDuration: TimeInterval = 0
    private var joltVector = CGVector.zero          // screen points the TABLE appears to move at the peak

    /// `strength` is the largest offset in SCREEN points. Skipped with Reduce Motion.
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

    /// Call once per frame after physics. `snap` jumps straight to the target.
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
        let w = LmpTableLayout.worldSize.width
        let h = LmpTableLayout.worldSize.height
        let m = CameraTuning.margin
        let hud = CameraTuning.hudHeight

        switch mode {
        case .topDown:
            let usableHeight = max(viewSize.height - hud, 1)
            let scale = max((w + 2 * m) / viewSize.width, (h + 2 * m) / usableHeight)
            let visibleHeight = viewSize.height * scale
            return (CGPoint(x: w / 2, y: -m + visibleHeight / 2), scale)

        case .flying, .wide:
            let visibleWidth = mode == .flying ? CameraTuning.flyingVisibleWidth : CameraTuning.wideVisibleWidth
            let scale = visibleWidth / viewSize.width
            let visW = viewSize.width * scale
            let visH = viewSize.height * scale
            let minX = -m + visW / 2
            let maxX = max(minX, w + m - visW / 2)
            let minY = -m + visH / 2
            let maxY = max(minY, h + m + hud * scale - visH / 2)

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
            return (CGPoint(x: min(max(tx, minX), maxX), y: min(max(ty, minY), maxY)), scale)
        }
    }
}
