// Pinball Lab Table 07 (CHOMP!), M3 v9: the fishing reel — a disc over the round end of a keyhole lane that a passing
// ball sets spinning (the real table's "Fishing Reel Spinner Top Assembly"; stronger shots, more spins).
import SpriteKit
import CoreGraphics
import Foundation

/// A spinning disc. Like ChompSpinner it has no physics body: the scene kicks it when a ball crosses the switch into the
/// round end, and `update` returns the whole turns made this frame (each scores, as the real reel's magnet switch counts).
final class ChompReel: SKNode {
    private let disc = SKNode()
    /// Turns per second, and the turns counted so far this spin.
    private var rate: CGFloat = 0
    private var turns: CGFloat = 0
    private var counted = 0
    private(set) var spinsThisRun = 0

    var isSpinning: Bool { rate > 0 }

    /// Tuning (placeholders until play): a hard shot (~2,500 pt/s) gives ~8 turns/s and about 6 turns.
    static let turnsPerPoint: CGFloat = 1.0 / 300
    static let maxRate: CGFloat = 12
    static let decayTime: CGFloat = 0.9
    static let drag: CGFloat = 1.5

    init(centre: CGPoint, radius: CGFloat) {
        super.init()
        position = centre
        zPosition = 22                                         // over the ball in the lane (the disc sits above it)
        let base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = SKColor(red: 0.16, green: 0.30, blue: 0.62, alpha: 0.78)
        base.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.7)
        base.lineWidth = 2
        addChild(base)
        let rim = SKShapeNode(circleOfRadius: radius - 3)
        rim.fillColor = .clear
        rim.strokeColor = SKColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 0.85)
        rim.lineWidth = 1.5
        addChild(rim)
        // Spokes and a handle so the turning reads.
        let spokes = CGMutablePath()
        for i in 0..<3 {
            let a = CGFloat(i) * 2 * .pi / 3
            spokes.move(to: .zero)
            spokes.addLine(to: CGPoint(x: cos(a) * (radius - 6), y: sin(a) * (radius - 6)))
        }
        let s = SKShapeNode(path: spokes)
        s.strokeColor = SKColor(red: 0.90, green: 0.92, blue: 0.97, alpha: 0.9)
        s.lineWidth = 3
        s.lineCap = .round
        disc.addChild(s)
        let handle = SKShapeNode(circleOfRadius: 5)
        handle.position = CGPoint(x: radius - 12, y: 0)
        handle.fillColor = SKColor(red: 0.95, green: 0.80, blue: 0.35, alpha: 1)
        handle.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.7)
        handle.lineWidth = 1
        disc.addChild(handle)
        let hub = SKShapeNode(circleOfRadius: 6)
        hub.fillColor = SKColor(red: 0.75, green: 0.77, blue: 0.82, alpha: 1)
        hub.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.7)
        disc.addChild(hub)
        addChild(disc)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A ball went into the round end at `ballSpeed`.
    func kick(ballSpeed: CGFloat) {
        if !isSpinning { spinsThisRun = 0 }
        rate = min(Self.maxRate, rate + ballSpeed * Self.turnsPerPoint)
    }

    /// Advances the disc; returns the whole turns completed this frame.
    func update(dt: CGFloat) -> Int {
        guard rate > 0 else { return 0 }
        turns += rate * dt
        rate = max(0, rate * exp(-dt / Self.decayTime) - Self.drag * dt)
        disc.zRotation = -turns * 2 * .pi
        let whole = Int(turns)
        let n = whole - counted
        counted = whole
        spinsThisRun += n
        return n
    }

    func reset() {
        rate = 0
        spinsThisRun = 0
    }
}
