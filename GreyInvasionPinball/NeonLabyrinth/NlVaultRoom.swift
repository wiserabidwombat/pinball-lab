// Pinball Lab Table 08 (Neon Labyrinth): the DATA VAULT room (T8 M6 v1, a Corridor; Aaron 2026-11-27: "the way on",
// sketch tools/nl_render_rooms_r1.py). Four data blocks stand across the upper table in front of the UPLINK. Knock
// all four down (SECTOR BREACHED) and the uplink opens: a ball rolling into it is lifted onto a light-rail and carried
// out the cell's way on (the open exit it didn't come in by), which glows magenta. The blocks come back up when the
// ball leaves, or on a new game.
import SpriteKit
import CoreGraphics

@MainActor
final class NlVaultRoom: NlRoom {
    typealias Y = NlSwitchyardLayout                   // the light-rails out are the Switchyard's (from the hub)

    // MARK: Geometry (cell coordinates)
    /// The four blocks: centres along y 722, 44 wide × 20 deep, 8 apart (closed: a 30 ball can't pass between).
    static let blockXs: [CGFloat] = [222, 274, 326, 378]
    static let blockFaceY: CGFloat = 712
    static let blockHalf: CGFloat = 22
    static let blockDepth: CGFloat = 20
    /// The uplink saucer behind the bank: a floor ball within `uplinkCatch` of its centre is taken (once breached).
    static let uplink = CGPoint(x: 300, y: 830)
    static let uplinkRadius: CGFloat = 20
    static let uplinkCatch: CGFloat = 24
    static let uplinkHold: CGFloat = 0.45
    static let railRideSpeed: CGFloat = 700
    /// T8 M6 v1: points for breaching the vault (each block scores the cell's target points as well).
    static let breachPoints = 10_000

    private enum Tag {
        static let lifted = 1
        static let exitBase = 10                       // + exit raw value
    }

    private weak var cell: NlCellFloor?
    private var down: Set<Int> = []
    private var breached: Bool { down.count == Self.blockXs.count }
    private var blockNodes: [SKNode] = []
    private var lamps: [SKShapeNode] = []
    private var uplinkNode: SKShapeNode?
    private var railNodes: [NlExit: [SKShapeNode]] = [:]
    private var carrying = false
    /// The way on, fixed when the vault is breached (so the lit rail is the one the ball takes).
    private var way: NlExit?
    /// The blocks' number labels (addTarget's), hidden with their blocks.
    private var labels: [SKNode] = []

    // MARK: NlRoom

    let exits: Set<NlExit> = [.left, .top, .right]
    let solidBlocks: [[CGPoint]] = []
    var targetEvents: [String: String] {
        Dictionary(uniqueKeysWithValues: Self.blockXs.indices.map { ("\($0 + 1)", "block") })
    }

    func build(in cell: NlCellFloor) {
        self.cell = cell
        for (i, x) in Self.blockXs.enumerated() {
            let a = CGPoint(x: x - Self.blockHalf + 2, y: Self.blockFaceY), b = CGPoint(x: x + Self.blockHalf - 2, y: Self.blockFaceY)
            cell.addTarget(name: "\(i + 1)", face: (a, b), normal: CGVector(dx: 0, dy: -1))
            if let label = cell.children.last as? SKLabelNode, label.text == "\(i + 1)" { labels.append(label) }
            guard let node = cell.targets.last?.body else { continue }
            // The block itself, drawn on the target so it drops with it.
            let box = SKShapeNode(rect: CGRect(x: x - Self.blockHalf, y: Self.blockFaceY,
                                               width: 2 * Self.blockHalf, height: Self.blockDepth), cornerRadius: 3)
            box.fillColor = (cell.neon ? NlNeon.white : NlTableScene.targetColor).withAlphaComponent(0.10)
            box.strokeColor = cell.neon ? NlNeon.white : NlTableScene.targetColor
            box.lineWidth = 2
            if cell.neon { box.blendMode = .add }
            box.zPosition = 0.1
            node.addChild(box)
            blockNodes.append(node)
        }
        // The uplink saucer (orange while locked, magenta once breached).
        let saucer = SKShapeNode(circleOfRadius: Self.uplinkRadius)
        saucer.position = Self.uplink
        saucer.lineWidth = 2.5
        saucer.zPosition = -18
        cell.addChild(saucer)
        if cell.neon { NlNeon.core(saucer, NlNeon.orange, width: 2.5); NlNeon.addHalo(to: saucer, NlNeon.orange, width: 12, alpha: 0.35) }
        uplinkNode = saucer
        let label = SKLabelNode(text: "UPLINK")
        label.fontName = "Menlo-Bold"
        label.fontSize = 11
        label.fontColor = (cell.neon ? NlNeon.orange : NlTableScene.exitColor).withAlphaComponent(0.8)
        label.position = CGPoint(x: Self.uplink.x, y: Self.uplink.y + 34)
        label.verticalAlignmentMode = .center
        label.zPosition = -17.9
        cell.addChild(label)
        // The light-rails out, drawn dim; the way on lights when breached.
        for (exit, rail) in [(NlExit.left, Y.railW), (.top, Y.railN), (.right, Y.railE)]
            where !cell.walled.contains(exit) {
            let nodes = cell.addRails([Self.uplink, Y.hubCenter] + rail, halfWidth: Y.railHalfWidth, z: 16, bakeHalo: false)
            if cell.neon { nodes.forEach { NlNeon.core($0, NlNeon.cyan, width: 1.1, alpha: 0.25) } }
            railNodes[exit] = nodes
        }
        // Four lamps in the open lower table, one per block.
        for i in Self.blockXs.indices {
            let lamp = SKShapeNode(circleOfRadius: 9)
            lamp.position = CGPoint(x: 255 + CGFloat(i) * 30, y: 505)
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            if cell.neon { lamp.blendMode = .add }
            cell.addChild(lamp)
            lamps.append(lamp)
        }
        newGame()
    }

    func newGame() {
        carrying = false
        resetBlocks()
    }

    func update(_ dt: CGFloat) {}

    func ballMoved(_ ball: NlBall) {
        if carrying, ball.isOnFloor,                       // let go (no way on): free again once it's clear
           hypot(ball.position.x - Self.uplink.x, ball.position.y - Self.uplink.y) > Self.uplinkCatch + 20 {
            carrying = false
        }
        guard breached, !carrying, ball.isOnFloor, let cell,
              hypot(ball.position.x - Self.uplink.x, ball.position.y - Self.uplink.y) < Self.uplinkCatch else { return }
        carrying = true
        cell.ride(ball, path: [ball.position, Self.uplink], speed: 300, height: 0, heightEnd: NlTableLayout.rampTopHeight,
                  release: .zero, end: .room(Tag.lifted), hold: Self.uplinkHold)
        cell.sfx(.scoopIn)
        cell.labEvent("uplink")
        cell.showBanner("UPLINK")
    }

    func targetHit(_ name: String) -> String {
        guard let i = Int(name).map({ $0 - 1 }), Self.blockXs.indices.contains(i), !down.contains(i) else { return name }
        down.insert(i)
        setBlock(i, up: false)
        refreshLamps()
        if breached {
            way = wayOn
            cell?.score(Self.breachPoints)
            cell?.labEvent("breach")
            cell?.sfx(.lanesComplete)
            refreshUplink()
            return "SECTOR BREACHED · UPLINK OPEN"
        }
        return "DATA BLOCK \(down.count)/\(Self.blockXs.count)"
    }

    func rideEnded(_ ball: NlBall, tag: Int) {
        guard let cell else { return }
        switch tag {
        case Tag.lifted:
            guard let exit = way ?? wayOn else {           // nowhere to go: back onto the floor, pushed clear
                ball.setLayer(.floor)
                ball.rampHeight = 0
                ball.physicsBody?.velocity = CGVector(dx: 0, dy: -500)
                ball.previousPosition = ball.position
                return                                     // `carrying` clears once it's away (ballMoved)
            }
            let rail = [Y.railW, Y.railN, Y.railE][exit.rawValue]
            cell.ride(ball, path: [Self.uplink, Y.hubCenter] + rail, speed: Self.railRideSpeed,
                      height: NlTableLayout.rampTopHeight, release: .zero, end: .room(Tag.exitBase + exit.rawValue))
            cell.sfx(.launch)
        case Tag.exitBase...(Tag.exitBase + 2):
            if let exit = NlExit(rawValue: tag - Tag.exitBase) { cell.leave(ball, by: exit) }
        default:
            break
        }
    }

    func ballLeft(by exit: NlExit) {
        guard let cell else { return }
        if !cell.isTilted { cell.score(NlPoints.exit) }
        cell.showBanner("EXIT \(exit.glyph) · \(NlPoints.exit)")
        cell.sfx(.jackpot)
        cell.haptic(1)
        carrying = false
        resetBlocks()                                      // the vault locks again behind the ball
    }

    var tagText: String { "vault \(down.count)/\(Self.blockXs.count)\(breached ? " open" : "")" }
    var status: String? { nil }

    // MARK: The vault

    /// The open exit the ball didn't come in by (top first, then right, then left); the way it came if that's all.
    private var wayOn: NlExit? {
        guard let cell else { return nil }
        let open = [NlExit.top, .right, .left].filter { exits.contains($0) && !cell.walled.contains($0) }
        return open.first(where: { $0 != cell.cameFrom }) ?? open.first
    }

    private func resetBlocks() {
        down = []
        way = nil
        for i in Self.blockXs.indices { setBlock(i, up: true) }
        refreshLamps()
        refreshUplink()
    }

    /// A block up (solid, drawn) or down (no body, hidden). The body's category goes to 0 instead of removing it.
    private func setBlock(_ i: Int, up: Bool) {
        guard blockNodes.indices.contains(i) else { return }
        let node = blockNodes[i]
        node.isHidden = !up
        if labels.indices.contains(i) { labels[i].isHidden = !up }
        node.physicsBody?.categoryBitMask = up ? NlPhysicsCategory.target : 0
        node.physicsBody?.collisionBitMask = up ? NlPhysicsCategory.ball : 0
    }

    private func refreshLamps() {
        let neon = cell?.neon ?? false
        for (i, lamp) in lamps.enumerated() {
            let lit = down.contains(i)
            let on = neon ? NlNeon.white : SKColor(red: 0.45, green: 1, blue: 0.55, alpha: 1)
            let off = neon ? NlNeon.cyan.withAlphaComponent(0.35) : SKColor(white: 0.3, alpha: 1)
            lamp.strokeColor = lit ? on : off
            lamp.fillColor = lit ? on.withAlphaComponent(0.5) : .clear
        }
    }

    /// The saucer and the way-on rail: magenta and lit once breached; orange / dim before. The way on's portal lights.
    private func refreshUplink() {
        guard let cell else { return }
        let open = breached
        if let s = uplinkNode {
            if cell.neon {
                NlNeon.setColor(s, open ? NlNeon.magenta : NlNeon.orange)
            } else {
                s.strokeColor = open ? NlTableScene.entryColor : NlTableScene.exitColor
            }
            s.fillColor = (open ? NlNeon.magenta : NlNeon.orange).withAlphaComponent(open ? 0.25 : 0.08)
        }
        let way = open ? (self.way ?? wayOn) : nil
        for (exit, nodes) in railNodes {
            let lit = exit == way
            for n in nodes {
                if cell.neon {
                    NlNeon.core(n, lit ? NlNeon.magenta : NlNeon.cyan, width: lit ? 1.8 : 1.1, alpha: lit ? 1 : 0.25)
                } else {
                    n.strokeColor = lit ? NlTableScene.entryColor : NlTableScene.wireColor.withAlphaComponent(0.4)
                }
            }
        }
        for exit in NlExit.allCases { cell.setExitLit(exit, exit == way) }
    }

    // MARK: Labs

    #if DEBUG
    var shotLabMajorEvents: Set<String> { ["block", "uplink"] }
    var shotLabProbes: [ShotLab.Probe] { [ShotLab.Probe(name: "bank", y: 712)] }
    func shotLabReset() { newGame() }
    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "block", text: "Knock down a data block"),
         PlayObjective(name: "breach", text: "All four blocks down (SECTOR BREACHED)"),
         PlayObjective(name: "uplink", text: "Into the open uplink"),
         PlayObjective(name: "exitLeft", text: "Out the left exit"),
         PlayObjective(name: "exitTop", text: "Out the top exit"),
         PlayObjective(name: "exitRight", text: "Out the right exit")]
    }
    var playLabShotObjectives: Set<String> { ["block", "breach", "uplink", "exitLeft", "exitTop", "exitRight"] }
    // PLACEHOLDER (T8 M6 v1): not measured yet; the Switchyard's centre shot (its ramp) aims up the middle, at the
    // inner blocks and the uplink. Run the Shot Lab on a Vault cell before trusting robot runs here.
    let leftShots: [(name: String, delay: Double)] = [("block", 0.621)]
    let rightShots: [(name: String, delay: Double)] = [("block", 0.621)]
    let leftInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("block", 40, 43)]
    let rightInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("block", 40, 43)]
    func robotWanted(saveNeeds: [String]) -> [String] { ["block"] }
    #endif
}
