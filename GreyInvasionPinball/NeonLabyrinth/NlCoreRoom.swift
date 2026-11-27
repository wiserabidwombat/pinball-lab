// Pinball Lab Table 08 (Neon Labyrinth): THE CORE, the maze's finish (T8 M6 v1; Aaron 2026-11-27: same size as the
// other rooms, and play goes on after it; sketch tools/nl_render_rooms_r1.py). The Core sits in the upper table
// inside two FIREWALL rings that turn opposite ways, each with one gap. A shot through both gaps hits the Core: 3 hits =
// CORE BREACHED (jackpot and a second ball). When the multiball is over the Core resets with faster rings.
// The room never sends the ball on: its portals stay locked (the left one is only there so B3 can come in).
import SpriteKit
import CoreGraphics

@MainActor
final class NlCoreRoom: NlRoom {
    // MARK: Geometry (cell coordinates)
    static let center = CGPoint(x: 300, y: 780)
    static let coreRadius: CGFloat = 34              // the hexagon's corners
    /// The rings: radius, starting gap angle (deg), turn rate (rad/s). Ball-clear: core → inner 58, inner → outer 58.
    static let rings: [(r: CGFloat, gap: CGFloat, rate: CGFloat)] = [(92, 250, 0.55), (150, 290, -0.4)]
    /// Each ring's gap along its arc (1.7 balls).
    static let gapLength: CGFloat = 50
    static let hitsToBreach = 3
    static let hitPoints = 25_000
    static let breachPoints = 500_000
    /// After each breach the rings turn this much faster.
    static let speedUp: CGFloat = 1.25

    private weak var cell: NlCellFloor?
    private var ringNodes: [SKNode] = []
    private var hits = 0
    private var breaches = 0
    private var multiballOn = false
    private var lamps: [SKShapeNode] = []
    /// How many times the rings have sped up (after each multiball, capped by `maxSpeed`).
    private var speedLevel = 0
    static let maxSpeed: CGFloat = 2.5
    /// A breach's second ball waits for the next frame (not inside the physics contact).
    private var pendingExtraBall = false
    /// T8 M6 v1 (review): a ball resting inside the rings for `stuckAfter` s makes them turn their gaps to the bottom.
    private var slowInside = false
    private var stuckFor: CGFloat = 0
    private var ejectFor: CGFloat = 0
    static let stuckAfter: CGFloat = 0.8
    static let ejectTime: CGFloat = 1.6
    static let ejectRate: CGFloat = 4

    // MARK: NlRoom

    let exits: Set<NlExit> = [.left, .top, .right]
    let solidBlocks: [[CGPoint]] = []
    let targetEvents = ["CORE": "coreHit"]

    func build(in cell: NlCellFloor) {
        self.cell = cell
        let c = Self.center
        // The Core: a target whose body and drawing are the hexagon.
        let hex = CGMutablePath()
        for k in 0..<6 {
            let a = CGFloat.pi / 6 + CGFloat(k) * .pi / 3
            let p = CGPoint(x: c.x + Self.coreRadius * cos(a), y: c.y + Self.coreRadius * sin(a))
            if k == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
        }
        hex.closeSubpath()
        cell.addTarget(name: "CORE", face: (CGPoint(x: c.x - 10, y: c.y - Self.coreRadius), CGPoint(x: c.x + 10, y: c.y - Self.coreRadius)),
                       normal: CGVector(dx: 0, dy: -1))
        if let node = cell.targets.last?.body as? SKShapeNode {
            node.path = hex
            node.fillColor = NlNeon.magenta.withAlphaComponent(0.3)
            let body = SKPhysicsBody(polygonFrom: hex)
            body.isDynamic = false
            body.restitution = 0.5
            body.friction = NlTableLayout.wallFriction
            body.categoryBitMask = NlPhysicsCategory.target
            body.collisionBitMask = NlPhysicsCategory.ball
            node.physicsBody = body
            for case let h as SKShapeNode in node.children { h.path = hex }    // its halos and bloom follow the shape
        }
        // The firewall rings: arcs with one gap, edge chains on a node turned every frame (their bodies turn with it).
        for ring in Self.rings {
            let node = SKNode()
            node.position = c
            node.zPosition = -17.5
            let half = (Self.gapLength / 2) / ring.r                        // half the gap, radians
            let arc = CGMutablePath()
            arc.addArc(center: .zero, radius: ring.r, startAngle: half, endAngle: 2 * .pi - half, clockwise: false)
            let shape = SKShapeNode(path: arc)
            shape.lineWidth = 3
            shape.lineCap = .round
            shape.strokeColor = cell.neon ? NlNeon.orange : NlTableScene.exitColor
            if cell.neon { NlNeon.core(shape, NlNeon.orange, width: 3); NlNeon.addHalo(to: shape, NlNeon.orange, width: 12, alpha: 0.35) }
            node.addChild(shape)
            let body = SKPhysicsBody(edgeChainFrom: arc)
            body.friction = NlTableLayout.wallFriction
            body.restitution = NlTableLayout.wallRestitution
            body.categoryBitMask = NlPhysicsCategory.wall
            body.collisionBitMask = NlPhysicsCategory.ball
            node.physicsBody = body
            node.zRotation = ring.gap * .pi / 180                         // the gap starts at its angle
            cell.addChild(node)
            ringNodes.append(node)
        }
        // Three hit lamps.
        for i in 0..<Self.hitsToBreach {
            let lamp = SKShapeNode(circleOfRadius: 10)
            lamp.position = CGPoint(x: 260 + CGFloat(i) * 40, y: 505)
            lamp.lineWidth = 1.6
            lamp.zPosition = -18
            if cell.neon { lamp.blendMode = .add }
            cell.addChild(lamp)
            lamps.append(lamp)
        }
        newGame()
    }

    func newGame() {
        hits = 0
        breaches = 0
        speedLevel = 0
        multiballOn = false
        pendingExtraBall = false
        stuckFor = 0
        ejectFor = 0
        for (i, n) in ringNodes.enumerated() { n.zRotation = Self.rings[i].gap * .pi / 180 }
        refreshLamps()
    }

    func update(_ dt: CGFloat) {
        if pendingExtraBall {
            pendingExtraBall = false
            cell?.extraBall()
        }
        // A ball resting inside the rings: after a moment, turn both gaps to the bottom so it drops out.
        stuckFor = slowInside ? stuckFor + dt : 0
        slowInside = false
        if stuckFor > Self.stuckAfter, ejectFor <= 0 { ejectFor = Self.ejectTime }
        if ejectFor > 0 {
            ejectFor -= dt
            for n in ringNodes {                           // the gap (at the node's angle 0) toward straight down
                var d = (-CGFloat.pi / 2 - n.zRotation).truncatingRemainder(dividingBy: 2 * .pi)
                if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                n.zRotation += max(-Self.ejectRate * dt, min(Self.ejectRate * dt, d))
            }
        } else {
            let fast = min(pow(Self.speedUp, CGFloat(speedLevel)), Self.maxSpeed)
            for (i, n) in ringNodes.enumerated() { n.zRotation += Self.rings[i].rate * fast * dt }
        }
        // The multiball is over when only one ball is left in play: the Core is ready again.
        if multiballOn, (cell?.ballsInPlay ?? 1) <= 1 {
            multiballOn = false
            hits = 0
            speedLevel += 1
            refreshLamps()
            cell?.showBanner("CORE REBOOTING · FIREWALLS FASTER")
        }
    }

    func ballMoved(_ ball: NlBall) {
        guard ball.isOnFloor, let v = ball.physicsBody?.velocity else { return }
        let c = Self.center
        if hypot(ball.position.x - c.x, ball.position.y - c.y) < Self.rings[1].r + 10, hypot(v.dx, v.dy) < 60 {
            slowInside = true
        }
    }

    func targetHit(_ name: String) -> String {
        guard name == "CORE", let cell else { return name }
        if multiballOn { cell.score(Self.hitPoints); return "CORE HIT" }
        hits += 1
        cell.score(Self.hitPoints)
        refreshLamps()
        guard hits >= Self.hitsToBreach else { return "CORE HIT \(hits)/\(Self.hitsToBreach)" }
        breaches += 1
        multiballOn = true
        cell.score(Self.breachPoints)
        cell.sfx(.superJackpot)
        cell.haptic(1)
        cell.labEvent("coreBreach")
        pendingExtraBall = true
        return "CORE BREACHED · JACKPOT \(Self.breachPoints.formatted()) · MULTIBALL"
    }

    func rideEnded(_ ball: NlBall, tag: Int) {}
    func ballLeft(by exit: NlExit) {}

    var tagText: String { "core \(hits)/\(Self.hitsToBreach) ×\(breaches)" }
    var status: String? { nil }

    private func refreshLamps() {
        for (i, lamp) in lamps.enumerated() {
            let lit = i < hits
            let col = cell?.neon == true ? NlNeon.magenta : NlTableScene.exitColor
            lamp.strokeColor = lit ? col : col.withAlphaComponent(0.35)
            lamp.fillColor = lit ? col.withAlphaComponent(0.5) : .clear
        }
    }

    // MARK: Labs

    #if DEBUG
    var shotLabMajorEvents: Set<String> { ["coreHit"] }
    var shotLabProbes: [ShotLab.Probe] { [ShotLab.Probe(name: "rings", y: 630)] }
    func shotLabReset() { newGame() }
    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "coreHit", text: "Hit the Core through both firewalls"),
         PlayObjective(name: "coreBreach", text: "Breach the Core (3 hits): jackpot and multiball")]
    }
    var playLabShotObjectives: Set<String> { ["coreHit", "coreBreach"] }
    // PLACEHOLDER (T8 M6 v1): not measured; the rings make every shot a timing gamble anyway.
    let leftShots: [(name: String, delay: Double)] = [("coreHit", 0.621)]
    let rightShots: [(name: String, delay: Double)] = [("coreHit", 0.621)]
    let leftInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("coreHit", 40, 43)]
    let rightInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("coreHit", 40, 43)]
    func robotWanted(saveNeeds: [String]) -> [String] { ["coreHit"] }
    #endif
}
