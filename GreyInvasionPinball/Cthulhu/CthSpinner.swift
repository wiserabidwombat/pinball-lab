// Pinball Lab Table 03 (Cthulhu Rising), milestone 4 round 1: the spinner, the table's first new toy.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// A spinner: a flat blade on an axle across a lane. A ball passing under it sets it spinning, faster for a
/// faster ball; it slows down by itself. Seen from above, the blade's depth along the lane is
/// |cos(angle)| of its full depth, with a light face and a dark face, so it reads as turning.
/// No physics body: the scene tells it when a ball crossed (a line-crossing check, like the ramp switches),
/// so it can't tunnel and never acts inside a contact callback. `update` returns how many half-turns
/// (spins, as scored on a real table) happened this frame.
final class CthSpinner: SKNode {
    /// Rotation, in turns (1 = one full revolution).
    private var angle: CGFloat = 0
    /// Turns per second.
    private var rate: CGFloat = 0
    private var halfTurnsCounted = 0
    private let blade: SKShapeNode
    /// Art round 2b: 24 rendered frames of one turn (frame 0 = hanging), used instead of the drawn blade.
    private var frames: [SKTexture] = []
    private var art: SKSpriteNode?
    private let width: CGFloat
    private let depth: CGFloat
    /// Spins since this spin started (for the banner when it stops).
    private(set) var spinsThisRun = 0

    var isSpinning: Bool { rate > 0 }

    // Tuning: a hard orbit shot (~1,500 pt/s) gives ~19 turns/s and about 20 spins.
    static let turnsPerPoint: CGFloat = 1.0 / 80      // turns/s per pt/s of ball speed
    static let maxRate: CGFloat = 30
    static let decayTime: CGFloat = 1.5               // exponential slow-down (seconds)
    static let drag: CGFloat = 1.2                    // plus a steady drag (turns/s²) so it stops
    /// The ball keeps this share of its speed going through (a real spinner barely slows it).
    static let ballSpeedKept: CGFloat = 0.97

    init(from a: CGPoint, to b: CGPoint, depth: CGFloat = 12) {
        width = hypot(b.x - a.x, b.y - a.y) - 6
        self.depth = depth
        blade = SKShapeNode(rectOf: CGSize(width: width, height: depth), cornerRadius: 2)
        super.init()
        position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        zRotation = atan2(b.y - a.y, b.x - a.x)
        zPosition = 2

        // Axle: a thin steel wire across the lane, always visible.
        let axle = SKShapeNode(rectOf: CGSize(width: width + 6, height: 2))
        axle.fillColor = SKColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        axle.strokeColor = .clear
        axle.zPosition = 0.2
        addChild(axle)

        blade.lineWidth = 1
        if UIImage(named: "cth_spinner_sheet") != nil {
            let sheet = SKTexture(imageNamed: "cth_spinner_sheet")
            let (cols, rows) = CthTableLayout.spinnerFrames
            for i in 0..<(cols * rows) {
                let c = CGFloat(i % cols), r = CGFloat(i / cols)
                let rect = CGRect(x: c / CGFloat(cols), y: 1 - (r + 1) / CGFloat(rows),
                                  width: 1 / CGFloat(cols), height: 1 / CGFloat(rows))
                frames.append(SKTexture(rect: rect, in: sheet))
            }
            let box = CthTableLayout.spinnerArtBox
            let s = SKSpriteNode(texture: frames[0], size: box.size)
            s.anchorPoint = CGPoint(x: -box.minX / box.width, y: -box.minY / box.height)
            s.zRotation = -zRotation                 // the frames are rendered with the lane along x
            addChild(s)
            art = s
            axle.isHidden = true
        } else {
            addChild(blade)
        }
        setLook()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A ball passed under the blade at this speed (pt/s). Spins it up; never slows a faster spin.
    func kick(ballSpeed: CGFloat) {
        let wanted = min(ballSpeed * Self.turnsPerPoint, Self.maxRate)
        if rate == 0 { spinsThisRun = 0 }
        rate = max(rate, wanted)
    }

    /// Advances the spin. Returns the spins (half-turns) completed this frame.
    func update(dt: CGFloat) -> Int {
        guard rate > 0 else { return 0 }
        angle += rate * dt
        rate = max(0, rate - rate / Self.decayTime * dt - Self.drag * dt)
        let half = Int((angle * 2).rounded(.down))
        let spins = max(0, half - halfTurnsCounted)
        halfTurnsCounted = half
        spinsThisRun += spins
        if rate == 0 {
            // come to rest: hanging down (a whole turn) with the rendered frames, flat with the drawn blade
            angle = art != nil ? angle.rounded() : (angle * 2).rounded() / 2
            halfTurnsCounted = Int(angle * 2)
        }
        setLook()
        return spins
    }

    /// Depth = |cos| of the angle; the face shown flips every half turn.
    private func setLook() {
        if let art, !frames.isEmpty {
            var f = angle - angle.rounded(.down)
            if f < 0 { f += 1 }
            let i = min(Int(f * CGFloat(frames.count)), frames.count - 1)
            if art.texture !== frames[i] { art.texture = frames[i] }
            return
        }
        let c = cos(angle * 2 * .pi)
        blade.yScale = max(abs(c), 0.08)
        let front = c >= 0
        blade.fillColor = front ? SKColor(red: 0.93, green: 0.86, blue: 0.62, alpha: 1)   // bone-gold face
                                : SKColor(red: 0.20, green: 0.30, blue: 0.30, alpha: 1)    // dark back
        blade.strokeColor = SKColor(red: 0.85, green: 0.66, blue: 0.28, alpha: 1)
    }
}
