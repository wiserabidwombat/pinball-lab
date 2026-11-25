// Pinball Lab Table 08 (Neon Labyrinth): copied from CHOMP!'s committed file (fa86dbb, real ball scale) with the "Nl" prefix.
// It shares Grey Invasion's CameraMode and CameraTuning (the same saved camera setting drives both tables).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// Owns the scene's camera and moves it each frame toward the framing for the current mode.
@MainActor
final class NlCameraRig {
    let node = SKCameraNode()
    private var base = CGPoint.zero
    private var shakeLeft: TimeInterval = 0
    private var shakeDuration: TimeInterval = 0
    private var shakeStrength: CGFloat = 0
    // Round 8: a directional lurch (the nudge) — the table jumps along the shove and springs back.
    private var joltLeft: TimeInterval = 0
    private var joltDuration: TimeInterval = 0
    private var joltVector = CGVector.zero          // screen points the TABLE appears to move at the peak
    /// T8 M2 round B: where the framed cell sits in the world (the ball's floor in the column). The camera frames the
    /// cell at this origin and eases across when it changes (a floor change pans).
    var origin = CGPoint.zero

    // MARK: T8 M4 v3: the cell transition (Notion: "camera pulls back to the whole wireframe grid with your position
    // lit, then dives into the next cell"). Pull back to the grid, hold, then dive into the new origin's framing.
    static let flightOut: CGFloat = 0.45
    static let flightHold: CGFloat = 0.35
    static let flightIn: CGFloat = 0.5
    static var flightTotal: CGFloat { flightOut + flightHold + flightIn }
    private struct Flight {
        var t: CGFloat = 0
        let startPosition: CGPoint
        let startScale: CGFloat
        let overPosition: CGPoint
        let overScale: CGFloat
    }
    private var flight: Flight?
    var isFlying: Bool { flight != nil }
    /// How far pulled back to the grid (0 = framing the cell, 1 = the whole grid), for the scene's highlights.
    private(set) var overviewAmount: CGFloat = 0
    /// The grid framing's scale while a flight runs (the scene sizes its highlight lines with it).
    var overviewScale: CGFloat { flight?.overScale ?? 1 }

    /// Starts a transition: out to frame `gridBounds` (world) under the HUD, hold, then in to the current origin.
    /// Skipped with Reduce Motion (the plain pan).
    func flyVia(gridBounds: CGRect, viewSize: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled, viewSize.width > 0, viewSize.height > 0 else { return }
        let m = CameraTuning.margin, hud = CameraTuning.hudHeight
        let usable = max(viewSize.height - hud, 1)
        let scale = max((gridBounds.width + 2 * m) / viewSize.width, (gridBounds.height + 2 * m) / usable)
        // centred in the area under the HUD
        let position = CGPoint(x: gridBounds.midX, y: gridBounds.midY + hud * scale / 2)
        flight = Flight(startPosition: base, startScale: node.xScale, overPosition: position, overScale: scale)
    }

    /// Smoothstep, and a zoom that's even in log space (so the pull-back doesn't rush at the start).
    private static func ease(_ k: CGFloat) -> CGFloat { let x = min(max(k, 0), 1); return x * x * (3 - 2 * x) }
    private static func zoom(_ a: CGFloat, _ b: CGFloat, _ k: CGFloat) -> CGFloat { exp(log(a) + (log(b) - log(a)) * k) }
    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ k: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
    }

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
            flight = nil
            overviewAmount = 0
            node.setScale(goal.scale)
            base = goal.position
            node.position = base
            return
        }

        if var f = flight {                        // T8 M4 v3: the cell transition owns the camera while it runs
            f.t += dt
            let out = Self.flightOut, hold = Self.flightHold, inn = Self.flightIn
            var position: CGPoint, scale: CGFloat
            if f.t < out {
                let k = Self.ease(f.t / out)
                position = Self.lerp(f.startPosition, f.overPosition, k)
                scale = Self.zoom(f.startScale, f.overScale, k)
                overviewAmount = k
            } else if f.t < out + hold {
                position = f.overPosition
                scale = f.overScale
                overviewAmount = 1
            } else if f.t < out + hold + inn {
                let k = Self.ease((f.t - out - hold) / inn)
                position = Self.lerp(f.overPosition, goal.position, k)
                scale = Self.zoom(f.overScale, goal.scale, k)
                overviewAmount = 1 - k
            } else {
                position = goal.position
                scale = goal.scale
                overviewAmount = 0
            }
            flight = f.t < out + hold + inn ? f : nil
            node.setScale(scale)
            base = position
            node.position = base
            return
        }

        let a = 1 - exp(-dt * CameraTuning.followRate)
        let scale = node.xScale + (goal.scale - node.xScale) * a
        node.setScale(scale)

        // T8 M2 round B: no dead zone in Top-Down (its goal only moves when the floor changes; a dead zone stopped the
        // pan short of the new floor).
        let dead = mode == .topDown ? 0 : CameraTuning.deadZone
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
        let w = NlTableLayout.worldSize.width
        let h = NlTableLayout.worldSize.height
        let m = CameraTuning.margin
        let hud = CameraTuning.hudHeight

        switch mode {
        case .topDown:
            let usableHeight = max(viewSize.height - hud, 1)
            let scale = max((w + 2 * m) / viewSize.width, (h + 2 * m) / usableHeight)
            let visibleHeight = viewSize.height * scale
            return (CGPoint(x: origin.x + w / 2, y: origin.y - m + visibleHeight / 2), scale)

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
            // When the view is wider than the table (iPad Wide, landscape), keep the table centred.
            let x = visW >= w + 2 * m ? w / 2 : min(max(tx, minX), maxX)
            return (CGPoint(x: origin.x + x, y: origin.y + min(max(ty, minY), maxY)), scale)
        }
    }
}
