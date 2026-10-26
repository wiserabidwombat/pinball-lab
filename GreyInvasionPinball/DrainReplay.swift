import SpriteKit

/// Improve mode, drain replay (2026-10-26). While Improve is on (pause card), the table records where each ball has
/// been for the last `window` seconds. When a ball drains, its last stretch draws on the table as a red trail for a
/// few seconds, brighter toward the end, with a ring where it crossed the flipper line (the point of no return,
/// the same line the Play Lab's heat maps use). A player sees how the ball got away: an outlane, down the middle,
/// off a flipper tip, a bounce off a sling.
///
/// With `exits`, a label over the ring names the way out (LEFT OUTLANE, RIGHT OUTLANE or CENTRE), read from where
/// the trail last crossed a line just above the outlane walls' bottom ends. The trail is kept back to that crossing
/// (up to 4 s), so a ball that rolls around under the flippers before it drains is still read correctly.
///
/// Shared by every table (one instance per table scene); the table feeds it ball positions and its drains.
@MainActor
final class DrainReplay: SKNode {
    private let window: TimeInterval
    private let lossLineY: CGFloat
    private let exits: Exits?
    private var trails: [ObjectIdentifier: [(t: TimeInterval, p: CGPoint)]] = [:]
    /// When each ball last went down through the exit line: its trail is kept back to then (up to `maxKeep`), so a
    /// ball that loiters under the flippers before it drains still shows how it got there and gets its label.
    private var exitCrossedAt: [ObjectIdentifier: TimeInterval] = [:]
    private let maxKeep: TimeInterval = 4
    /// This game's drains by way out (the pause card's tally); the table clears it on a new game.
    private var tally: [String: Int] = [:]

    /// Where a lost ball left the playfield: the line it's read on (going down) and the outlanes' inner edges.
    struct Exits {
        let lineY: CGFloat        // just above the bottom of the outlane walls
        let leftOutlaneX: CGFloat // a ball left of this on the line was in the left outlane
        let rightOutlaneX: CGFloat
    }

    private static let red = SKColor(red: 1.00, green: 0.36, blue: 0.30, alpha: 1)

    /// `lossLineY`: the flipper line in table points (just above the resting flipper tips).
    init(lossLineY: CGFloat, exits: Exits? = nil, window: TimeInterval = 1.5) {
        self.lossLineY = lossLineY
        self.exits = exits
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
        var crossed: [ObjectIdentifier: TimeInterval] = [:]
        for ball in balls {
            var trail = trails[ball.id] ?? []
            var crossedAt = exitCrossedAt[ball.id]
            if let last = trail.last {
                if hypot(last.p.x - ball.position.x, last.p.y - ball.position.y) >= 2 {
                    if let exits, last.p.y >= exits.lineY, ball.position.y < exits.lineY { crossedAt = now }
                    trail.append((now, ball.position))
                }
            } else {
                trail.append((now, ball.position))
            }
            // Keep the last `window` seconds, or back to the exit crossing if that's older (never more than maxKeep).
            var keepFrom = now - window
            if let t = crossedAt { keepFrom = min(keepFrom, max(t - 0.05, now - maxKeep)) }
            while let first = trail.first, first.t < keepFrom, trail.count > 2 { trail.removeFirst() }
            next[ball.id] = trail
            crossed[ball.id] = crossedAt
        }
        trails = next                     // balls that left (drained, removed) drop out here
        exitCrossedAt = crossed
    }

    /// Forget every trail and clear the table (a new game, Improve turned off).
    func reset() {
        trails = [:]
        exitCrossedAt = [:]
        removeAllChildren()
    }

    /// Start a new game's tally.
    func resetTally() {
        tally = [:]
    }

    /// The pause card's tally: one column per way out, left to right (a table without a left outlane leaves it
    /// out). Nil without exits.
    var tallyColumns: [(label: String, count: Int)]? {
        guard let exits else { return nil }
        var columns: [(label: String, count: Int)] = []
        if exits.leftOutlaneX > -500 { columns.append(("LEFT", tally["LEFT OUTLANE", default: 0])) }
        columns.append(("CENTRE", tally["CENTRE", default: 0]))
        columns.append(("RIGHT", tally["RIGHT OUTLANE", default: 0]))
        return columns
    }

    /// A ball drained: draw its last stretch, then fade it out.
    func drained(_ id: ObjectIdentifier, at exit: CGPoint) {
        exitCrossedAt[id] = nil
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
        let ringAt = lastCrossing(trail, lineY: lossLineY)
        if let cross = ringAt {
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
        // The way out, over the ring.
        if let exits {
            // No crossing at all means it never came down past the line in the kept stretch: it was already
            // below the outlane walls, between them, so it left through the centre.
            let read = lastCrossing(trail, lineY: exits.lineY)
            let name = read.map { $0.x < exits.leftOutlaneX ? "LEFT OUTLANE"
                : $0.x > exits.rightOutlaneX ? "RIGHT OUTLANE" : "CENTRE" } ?? "CENTRE"
            tally[name, default: 0] += 1
            let anchor = ringAt ?? read ?? CGPoint(x: (exits.leftOutlaneX + exits.rightOutlaneX) / 2, y: lossLineY)
            let x = min(max(anchor.x, exits.leftOutlaneX + 46), exits.rightOutlaneX - 46)   // keep it on the table
            let at = CGPoint(x: x, y: anchor.y + 26)
            let shadow = SKLabelNode(text: name)
            shadow.fontName = "Menlo-Bold"
            shadow.fontSize = 13
            shadow.fontColor = SKColor(white: 0, alpha: 0.85)
            shadow.verticalAlignmentMode = .center
            shadow.position = CGPoint(x: at.x + 1, y: at.y - 1)
            shadow.zPosition = 0.4
            replay.addChild(shadow)
            let text = SKLabelNode(text: name)
            text.fontName = "Menlo-Bold"
            text.fontSize = 13
            text.fontColor = .white
            text.verticalAlignmentMode = .center
            text.position = at
            text.zPosition = 0.5
            replay.addChild(text)
        }
        replay.alpha = 0
        addChild(replay)
        replay.run(.sequence([.fadeIn(withDuration: 0.12), .wait(forDuration: 2.6),
                              .fadeOut(withDuration: 0.6), .removeFromParent()]))
    }

    /// The point where the trail last went from above a line to below it.
    private func lastCrossing(_ trail: [CGPoint], lineY: CGFloat) -> CGPoint? {
        guard trail.count >= 2 else { return nil }
        for k in stride(from: trail.count - 1, to: 0, by: -1) {
            let p = trail[k - 1], q = trail[k]
            if p.y >= lineY, q.y < lineY {
                let f = (p.y - lineY) / max(p.y - q.y, 0.001)
                return CGPoint(x: p.x + (q.x - p.x) * f, y: lineY)
            }
        }
        return nil
    }
}
