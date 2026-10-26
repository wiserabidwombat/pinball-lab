import SpriteKit

/// Improve mode, drain replay (2026-10-26). While Improve is on (pause card), the table records where each ball has
/// been for the last `window` seconds. When a ball drains, its last stretch draws on the table as a red trail for a
/// few seconds, brighter toward the end, with a ring where it crossed the flipper line (the point of no return,
/// the same line the Play Lab's heat maps use). A player sees how the ball got away: an outlane, down the middle,
/// off a flipper tip, a bounce off a sling.
///
/// Shared by every table (one instance per table scene); the table feeds it ball positions and its drains.
@MainActor
final class DrainReplay: SKNode {
    private let window: TimeInterval
    private let lossLineY: CGFloat
    private var trails: [ObjectIdentifier: [(t: TimeInterval, p: CGPoint)]] = [:]

    private static let red = SKColor(red: 1.00, green: 0.36, blue: 0.30, alpha: 1)

    /// `lossLineY`: the flipper line in table points (just above the resting flipper tips).
    init(lossLineY: CGFloat, window: TimeInterval = 1.5) {
        self.lossLineY = lossLineY
        self.window = window
        super.init()
        zPosition = 45                    // over the drain dim (40), under the banners (49)
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Every game frame: the balls in play (physics positions). Points closer than 2 pt to the last are skipped.
    func record(_ balls: [(id: ObjectIdentifier, position: CGPoint)], now: TimeInterval) {
        var next: [ObjectIdentifier: [(t: TimeInterval, p: CGPoint)]] = [:]
        for ball in balls {
            var trail = trails[ball.id] ?? []
            if let last = trail.last {
                if hypot(last.p.x - ball.position.x, last.p.y - ball.position.y) >= 2 { trail.append((now, ball.position)) }
            } else {
                trail.append((now, ball.position))
            }
            while let first = trail.first, first.t < now - window, trail.count > 2 { trail.removeFirst() }
            next[ball.id] = trail
        }
        trails = next                     // balls that left (drained, removed) drop out here
    }

    /// Forget every trail and clear the table (a new game, Improve turned off).
    func reset() {
        trails = [:]
        removeAllChildren()
    }

    /// A ball drained: draw its last stretch, then fade it out.
    func drained(_ id: ObjectIdentifier, at exit: CGPoint) {
        guard var trail = trails.removeValue(forKey: id)?.map({ $0.p }), !trail.isEmpty else { return }
        trail.append(exit)
        guard trail.count >= 2 else { return }
        let replay = SKNode()
        // Eight pieces, fainter at the start: the ball's direction reads at a glance.
        let pieces = min(8, trail.count - 1)
        for i in 0..<pieces {
            let a = i * (trail.count - 1) / pieces, b = (i + 1) * (trail.count - 1) / pieces
            guard b > a else { continue }
            let path = CGMutablePath()
            path.move(to: trail[a])
            for k in (a + 1)...b { path.addLine(to: trail[k]) }
            let strength = 0.3 + 0.7 * CGFloat(i + 1) / CGFloat(pieces)
            let backing = SKShapeNode(path: path)
            backing.strokeColor = .black
            backing.lineWidth = 7
            backing.lineCap = .round
            backing.lineJoin = .round
            backing.alpha = 0.55 * strength
            replay.addChild(backing)
            let line = SKShapeNode(path: path)
            line.strokeColor = Self.red
            line.lineWidth = 3.5
            line.lineCap = .round
            line.lineJoin = .round
            line.glowWidth = 1.5
            line.alpha = strength
            line.zPosition = 0.1
            replay.addChild(line)
        }
        // The ring where it crossed the flipper line for the last time (on its way down).
        if let cross = lastCrossing(trail) {
            let back = SKShapeNode(circleOfRadius: 11)
            back.strokeColor = SKColor(white: 0, alpha: 0.7)
            back.lineWidth = 5
            back.position = cross
            back.zPosition = 0.2
            replay.addChild(back)
            let ring = SKShapeNode(circleOfRadius: 11)
            ring.strokeColor = .white
            ring.lineWidth = 2
            ring.position = cross
            ring.zPosition = 0.3
            replay.addChild(ring)
        }
        replay.alpha = 0
        addChild(replay)
        replay.run(.sequence([.fadeIn(withDuration: 0.12), .wait(forDuration: 2.6),
                              .fadeOut(withDuration: 0.6), .removeFromParent()]))
    }

    /// The point where the trail last went from above the flipper line to below it.
    private func lastCrossing(_ trail: [CGPoint]) -> CGPoint? {
        guard trail.count >= 2 else { return nil }
        for k in stride(from: trail.count - 1, to: 0, by: -1) {
            let p = trail[k - 1], q = trail[k]
            if p.y >= lossLineY, q.y < lossLineY {
                let f = (p.y - lossLineY) / max(p.y - q.y, 0.001)
                return CGPoint(x: p.x + (q.x - p.x) * f, y: lossLineY)
            }
        }
        return nil
    }
}
