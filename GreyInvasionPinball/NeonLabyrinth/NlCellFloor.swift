// Pinball Lab Table 08 (Neon Labyrinth): one FLOOR of the column (T8 M2 round B). A floor is one cell: the shared kit
// (walls, lanes, outlanes, slings, its own two flippers, the return wires, the portals, the kickback / save lamps) and
// its room, all children of this node, which sits at its place in the column. A ball in play is a child of its floor,
// so everything about a cell (the room's rules, rides, the flipper model, line crossings) works in the cell's own
// coordinates, the same as when the scene was one cell. The scene (NlTableScene) runs the column: which floor the ball
// is on, moving between floors, input, scoring, the labs.
import SpriteKit
import CoreGraphics

@MainActor
final class NlCellFloor: SKNode {
    private typealias S = NlTableScene
    /// Where this floor is in the column (0 = the bottom).
    let index: Int
    /// The room on this floor.
    let room: NlRoom
    private(set) var leftFlipper: NlFlipper!
    private(set) var rightFlipper: NlFlipper!
    private(set) var slingshots: [NlSlingshot] = []
    /// The room's targets on this floor: which body is which, and when each flash ends.
    private(set) var targets: [(body: SKNode, name: String, face: SKShapeNode)] = []
    var targetFlashUntil: [String: TimeInterval] = [:]
    private(set) var kickLamps: [SKShapeNode] = []
    // T8 M2 round C (Aaron: "Per floor"): this floor's outlane saves. The kickback (left) is lit on every floor at the
    // start of each new ball; the outlane save (right) is lit by hitting all of this floor's room's targets. Each fires
    // once, and moving between floors doesn't relight either.
    var kickbackLit = true
    var saveLit = false
    var targetsHitForSave: Set<String> = []
    private var exitPortals: [NlExit: SKShapeNode] = [:]
    /// T8 M4 v1: the room's exits a maze wall closes (set by the scene before build). A walled exit is a solid orange
    /// wall that never opens, and its side has no entry portal or stub (nothing can come in that way).
    var walled: Set<NlExit> = []
    private var exitsLit: Set<NlExit> = []
    /// T8 M3 v1: the neon look (the table's column opts in). `halos` collects the fixed parts' halos while the floor
    /// builds (the kit's and the room's); they're baked into one sprite at the end of build().
    let neon: Bool
    let halos = NlHaloBaker()
    /// Neon: the hatching across each locked exit portal (hidden while the exit is open).
    private var exitHatches: [NlExit: [SKShapeNode]] = [:]
    /// The room's solid blocks (a floor ball inside one is pushed back out).
    private(set) lazy var solidBlocks: [[CGPoint]] = room.solidBlocks
    private weak var column: NlTableScene?

    init(index: Int, room: NlRoom, column: NlTableScene, neon: Bool = false) {
        self.index = index
        self.room = room
        self.column = column
        self.neon = neon
        super.init()
        name = "floor\(index)"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Builds the kit, then the room (once, when the scene builds the column).
    func build() {
        typealias C = NlCellLayout
        addGridFloor()
        addWall(points: C.outerWall, friction: NlTableLayout.railFriction, restitution: NlTableLayout.railRestitution)
        for pts in [C.laneGuideLeft, C.laneGuideRight, C.outlaneWallLeft, C.outlaneWallRight,
                    C.outlanePostRailLeft, C.outlanePostRailRight, C.topLaneWallLeft, C.topLaneWallRight] {
            addWall(points: pts)
        }
        for p in [C.laneGuidePostLeft, C.laneGuidePostRight, C.outlanePostLeft, C.outlanePostRight] {
            addPost(at: p, radius: C.laneGuidePostRadius)
        }
        for p in C.topLanePosts { addPost(at: p, radius: C.topLanePostRadius) }

        for s in [C.slingLeft, C.slingRight] {
            let sling = NlSlingshot(top: s[0], corner: s[1], tip: s[2], artBaked: false,
                                    kickFrom: NlTableLayout.slingKickFrom, kickTo: NlTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
            if neon {
                sling.applyNeon()
                halos.add(points: [s[0], s[1], s[2]], NlNeon.cyan, alpha: 0.5)
            }
        }

        // The floor's own flippers, pinned to this node (`pinned` holds them to their parent).
        leftFlipper = NlFlipper(side: .left, pivot: C.pivotLeft)
        rightFlipper = NlFlipper(side: .right, pivot: C.pivotRight)
        for f in [leftFlipper!, rightFlipper!] {
            addChild(f)
            f.physicsBody?.pinned = true
            if neon { f.applyNeon() }
        }

        addWires()
        addPortals()
        room.build(in: self)                       // the room's parts, targets and drawn parts
        for p in [NlTableLayout.kickLampLeft, CGPoint(x: NlTableLayout.mirrorSum - NlTableLayout.kickLampLeft.x,
                                                       y: NlTableLayout.kickLampLeft.y)] {
            let lamp = SKShapeNode(circleOfRadius: 9)
            lamp.position = p
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            addChild(lamp)
            kickLamps.append(lamp)
            if neon {
                lamp.blendMode = .add
                NlNeon.addHalo(to: lamp, NlNeon.white, width: 10, alpha: 0.3)
            }
        }
        if neon {
            addHazardChevrons()
            if let sprite = halos.makeSprite(size: NlCellLayout.cellSize) {
                sprite.zPosition = -19.6               // under every core line, over the grid
                addChild(sprite)
            }
        }
    }

    /// Neon: orange chevrons on the floor at the two outlane mouths and over the drain chute (hazards).
    private func addHazardChevrons() {
        let all = CGMutablePath()                  // one node for every chevron (fewer draws); each has its own halo
        func chevron(_ c: CGPoint, half: CGFloat, alpha: CGFloat) {
            let pts = [CGPoint(x: c.x - half, y: c.y + half * 0.5), c, CGPoint(x: c.x + half, y: c.y + half * 0.5)]
            all.addLines(between: pts)
            halos.add(points: pts, NlNeon.orange, width: 5, alpha: alpha * 0.9)
        }
        defer {
            let n = SKShapeNode(path: all)
            NlNeon.core(n, NlNeon.orange, width: 1.6, alpha: 0.5)
            n.zPosition = -19.4
            addChild(n)
        }
        for x in [CGFloat(47), NlCellLayout.cellSize.width - 47] {
            for k in 0..<3 { chevron(CGPoint(x: x, y: 294 - CGFloat(k) * 22), half: 12, alpha: 0.55 - CGFloat(k) * 0.12) }
        }
        for k in 0..<2 { chevron(CGPoint(x: NlCellLayout.centerX, y: 64 - CGFloat(k) * 22), half: 16, alpha: 0.6 - CGFloat(k) * 0.2) }
    }

    /// This floor's two save lamps (left = kickback, right = outlane save): green when lit.
    func refreshKickLamps() {
        let on = SKColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1)
        let off = SKColor(red: 0.14, green: 0.28, blue: 0.18, alpha: 0.9)
        for (i, lamp) in kickLamps.enumerated() {
            let lit = i == 0 ? kickbackLit : saveLit
            if neon {                              // lit = white (active); off = a dim cyan ring
                lamp.fillColor = lit ? NlNeon.white.withAlphaComponent(0.55) : .clear
                NlNeon.setColor(lamp, lit ? NlNeon.white : NlNeon.cyan, alpha: lit ? 1 : 0.3)
                lamp.lineWidth = lit ? 1.8 : 1.2
                continue
            }
            lamp.fillColor = lit ? on : off
            lamp.strokeColor = lit ? .white : on.withAlphaComponent(0.4)
        }
    }

    // MARK: - Services for the room (forwarded to the column)

    var isTilted: Bool { column?.isTilted ?? false }
    func score(_ points: Int) { column?.score(points) }
    func haptic(_ intensity: CGFloat) { column?.haptic(intensity) }
    func showBanner(_ text: String) { column?.showBanner(text) }
    func sfx(_ s: MonSound) { column?.sfx(s) }
    func labEvent(_ name: String) { column?.labEvent(name) }

    /// Puts a ball on this floor on a ride along `path` (this floor's coordinates).
    func ride(_ ball: NlBall, path: [CGPoint], speed: CGFloat, height: CGFloat, heightEnd: CGFloat? = nil,
              release: CGVector, event: String? = nil, end: NlRideEnd = .release, hold: CGFloat = 0) {
        column?.ride(ball, path: path, speed: speed, height: height, heightEnd: heightEnd, release: release,
                     event: event, end: end, hold: hold)
    }

    /// The ball went out through `exit`: the column takes it to where that exit leads.
    func leave(_ ball: NlBall, by exit: NlExit) {
        column?.leave(ball, by: exit, from: self)
    }

    // MARK: - Building the kit

    /// The floor inside the outer wall, with a faint 50 pt grid (the neon look's grid floor, in grey-box form).
    private func addGridFloor() {
        let path = CGMutablePath()
        path.addLines(between: NlCellLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = neon ? NlNeon.void : S.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
        let grid = CGMutablePath()
        let w = NlCellLayout.cellSize.width, h = NlCellLayout.cellSize.height
        for x in stride(from: CGFloat(0), through: w, by: 50) {
            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h))
        }
        for y in stride(from: CGFloat(0), through: h, by: 50) {
            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y))
        }
        let lines = SKShapeNode(path: grid)
        lines.strokeColor = SKColor(red: 0.10, green: 0.55, blue: 0.75, alpha: 0.18)
        lines.lineWidth = 1
        lines.zPosition = -19.8
        let crop = SKCropNode()
        crop.maskNode = SKShapeNode(path: path).then { $0.fillColor = .white; $0.strokeColor = .clear }
        crop.addChild(lines)
        if neon {                                  // neon: faint cyan every 50, brighter every 200
            lines.strokeColor = NlNeon.cyan.withAlphaComponent(0.11)
            lines.blendMode = .add
            let major = CGMutablePath()
            for x in stride(from: CGFloat(100), through: w, by: 200) {
                major.move(to: CGPoint(x: x, y: 0)); major.addLine(to: CGPoint(x: x, y: h))
            }
            for y in stride(from: CGFloat(0), through: h, by: 200) {
                major.move(to: CGPoint(x: 0, y: y)); major.addLine(to: CGPoint(x: w, y: y))
            }
            let majorLines = SKShapeNode(path: major)
            majorLines.strokeColor = NlNeon.cyan.withAlphaComponent(0.26)
            majorLines.lineWidth = 1.3
            majorLines.blendMode = .add
            crop.addChild(majorLines)
        }
        crop.zPosition = -19.8
        addChild(crop)
    }

    func addWall(points: [CGPoint],
                 friction: CGFloat = NlTableLayout.wallFriction,
                 restitution: CGFloat = NlTableLayout.wallRestitution,
                 z: CGFloat = -19.5) {
        // A closed outline (last point = first) is an edge LOOP (CHOMP! M3 v13b: an edge chain lost its closing edge).
        let closed = points.count > 2 && points.first == points.last
        let path = CGMutablePath()
        if closed {
            path.addLines(between: Array(points.dropLast()))
            path.closeSubpath()
        } else {
            path.addLines(between: points)
        }
        let node = SKShapeNode(path: path)
        node.strokeColor = S.wallColor
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        if neon {                                  // a cyan core; its halo is baked
            NlNeon.core(node, NlNeon.cyan)
            halos.add(path, NlNeon.cyan)
        }
        let body = closed ? SKPhysicsBody(edgeLoopFrom: path) : SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = NlPhysicsCategory.wall
        body.collisionBitMask = NlPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    func addPost(at p: CGPoint, radius r: CGFloat, fill: SKColor = SKColor(white: 0.85, alpha: 1)) {
        let post = SKShapeNode(circleOfRadius: r)
        post.position = p
        post.fillColor = fill
        post.strokeColor = S.wallColor
        post.lineWidth = 1.5
        post.zPosition = -19
        if neon {                                  // a dark disc with a cyan rim
            post.fillColor = NlNeon.void
            NlNeon.core(post, NlNeon.cyan, width: 1.6)
            post.blendMode = .alpha
            halos.addCircle(p, r, NlNeon.cyan)
        }
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = NlTableLayout.postRestitution
        body.friction = 0.2
        body.categoryBitMask = NlPhysicsCategory.wall
        body.collisionBitMask = NlPhysicsCategory.ball
        post.physicsBody = body
        addChild(post)
    }

    /// A standup: a thick drawn face with an edge body (category target) along it, and its label behind it.
    func addTarget(name: String, face: (CGPoint, CGPoint), normal: CGVector) {
        let path = CGMutablePath()
        path.addLines(between: [face.0, face.1])
        let node = SKShapeNode(path: path)
        node.strokeColor = S.targetColor
        node.lineWidth = 6
        node.lineCap = .round
        node.zPosition = -18
        let body = SKPhysicsBody(edgeFrom: face.0, to: face.1)
        body.restitution = NlTableLayout.wallRestitution
        body.friction = NlTableLayout.wallFriction
        body.categoryBitMask = NlPhysicsCategory.target
        body.collisionBitMask = NlPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        if neon {                                  // white (active), with a live halo for the hit flash
            NlNeon.core(node, targetRestColor, width: 4.5)
            NlNeon.addHalo(to: node, targetRestColor, width: 14, alpha: 0.3)
        }
        let mid = CGPoint(x: (face.0.x + face.1.x) / 2 - normal.dx * 24, y: (face.0.y + face.1.y) / 2 - normal.dy * 24)
        let label = SKLabelNode(text: name)
        label.fontName = "Menlo-Bold"
        label.fontSize = 11
        label.fontColor = neon ? NlNeon.cyan.withAlphaComponent(0.75) : S.targetColor.withAlphaComponent(0.85)
        label.verticalAlignmentMode = .center
        label.position = mid
        label.zPosition = -17
        addChild(label)
        targets.append((body: node, name: name, face: node))
    }

    /// A target's colour at rest, and its hit flash (the scene flashes it for 0.12 s).
    var targetRestColor: SKColor { neon ? SKColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1) : S.targetColor }
    func setTargetFlash(_ face: SKShapeNode, _ on: Bool) {
        if neon {
            NlNeon.setColor(face, on ? NlNeon.magenta : targetRestColor)
            NlNeon.setBloom(face, on, base: 14)
        } else {
            face.strokeColor = on ? .white : S.targetColor
        }
    }

    /// The kit's wires (drawn; ridden as scripted rides): both return wires (arrivals from above use them), and the entry
    /// stubs of the sides the room has open.
    private func addWires() {
        typealias C = NlCellLayout
        var wires = [C.returnWireLeft, C.returnWireRight]
        if room.exits.contains(.left), !walled.contains(.left) { wires.append(C.entryStubLeft) }
        if room.exits.contains(.right), !walled.contains(.right) { wires.append(C.entryStubRight) }
        for wire in wires { addRails(wire, halfWidth: 17, z: 17) }
    }

    @discardableResult
    func addRails(_ centre: [CGPoint], halfWidth: CGFloat, z: CGFloat, bakeHalo: Bool = true) -> [SKShapeNode] {
        guard centre.count >= 2 else { return [] }
        var sides: [[CGPoint]] = [[], []]
        for (i, p) in centre.enumerated() {
            let a = centre[max(0, i - 1)], b = centre[min(centre.count - 1, i + 1)]
            let len = max(hypot(b.x - a.x, b.y - a.y), 0.001)
            let n = CGVector(dx: -(b.y - a.y) / len, dy: (b.x - a.x) / len)
            sides[0].append(CGPoint(x: p.x + n.dx * halfWidth, y: p.y + n.dy * halfWidth))
            sides[1].append(CGPoint(x: p.x - n.dx * halfWidth, y: p.y - n.dy * halfWidth))
        }
        var nodes: [SKShapeNode] = []
        for side in sides {
            let path = CGMutablePath()
            path.addLines(between: side)
            let node = SKShapeNode(path: path)
            node.strokeColor = S.wireColor
            node.lineWidth = 1.6
            node.zPosition = z
            if neon {                              // dim cyan rails with a faint baked halo
                NlNeon.core(node, NlNeon.cyan, width: 1.1, alpha: 0.3)
                if bakeHalo { halos.add(path, NlNeon.cyan, width: 5, alpha: 0.4) }
            }
            addChild(node)
            nodes.append(node)
        }
        return nodes
    }

    /// The room's way out `exit` is open (lit) or not: its portal glows.
    func setExitLit(_ exit: NlExit, _ lit: Bool) {
        if lit { exitsLit.insert(exit) } else { exitsLit.remove(exit) }
        guard let node = exitPortals[exit], !walled.contains(exit) else { return }   // a wall stays a wall
        if neon {                                  // locked = an orange barrier; open = a magenta bloom
            NlNeon.setColor(node, lit ? NlNeon.magenta : NlNeon.orange)
            NlNeon.setBloom(node, lit, base: 14)
            node.lineWidth = lit ? 5 : 4
            exitHatches[exit]?.forEach { $0.isHidden = lit }
            return
        }
        node.strokeColor = lit ? SKColor(red: 1.0, green: 0.75, blue: 0.95, alpha: 1) : S.exitColor
        node.lineWidth = lit ? 9 : 6
    }

    /// The portals on the walls: entries (cyan) and exits (magenta, glowing while the room has that exit open), only on
    /// the sides the room has (a side's entry comes with its exit).
    private func addPortals() {
        typealias C = NlCellLayout
        @discardableResult
        func bar(_ a: CGPoint, _ b: CGPoint, _ color: SKColor) -> SKShapeNode {
            let path = CGMutablePath()
            path.addLines(between: [a, b])
            let node = SKShapeNode(path: path)
            node.strokeColor = color
            node.lineWidth = 6
            node.lineCap = .round
            node.zPosition = -18.5
            addChild(node)
            if neon {
                NlNeon.core(node, color, width: 4)
                if color == S.entryColor {
                    halos.add(points: [a, b], NlNeon.cyan, width: 12, alpha: 0.9)
                } else {
                    NlNeon.addHalo(to: node, NlNeon.orange, width: 14, alpha: 0.32)
                }
            }
            return node
        }
        /// Neon: orange hatching across a locked exit, leaning into the cell.
        func hatch(_ exit: NlExit, along a: CGPoint, _ b: CGPoint, into n: CGVector) {
            guard neon else { return }
            let len = hypot(b.x - a.x, b.y - a.y)
            let u = CGVector(dx: (b.x - a.x) / len, dy: (b.y - a.y) / len)
            let path = CGMutablePath()                 // one node for all of this exit's hatching
            var t: CGFloat = 8
            while t < len - 4 {
                let p0 = CGPoint(x: a.x + u.dx * t, y: a.y + u.dy * t)
                path.move(to: p0)
                path.addLine(to: CGPoint(x: p0.x + n.dx * 10 + u.dx * 8, y: p0.y + n.dy * 10 + u.dy * 8))
                t += 14
            }
            let l = SKShapeNode(path: path)
            NlNeon.core(l, NlNeon.orange, width: 1.2, alpha: 0.5)
            l.zPosition = -18.4
            addChild(l)
            exitHatches[exit] = [l]
        }
        /// T8 M4 v1: a maze wall across an exit: a solid orange bar (neon: a steady core, a faint baked halo).
        func wall(_ a: CGPoint, _ b: CGPoint) {
            let path = CGMutablePath()
            path.addLines(between: [a, b])
            let node = SKShapeNode(path: path)
            node.strokeColor = S.exitColor.withAlphaComponent(0.55)
            node.lineWidth = 10
            node.lineCap = .butt
            node.zPosition = -18.5
            addChild(node)
            if neon {
                NlNeon.core(node, NlNeon.orange, width: 6, alpha: 0.8)
                node.lineCap = .butt
                halos.add(points: [a, b], NlNeon.orange, width: 16, alpha: 0.45)
            }
        }
        /// The exit's portal, or its wall when the maze closes it. A walled TOP stays a locked portal that never opens:
        /// a drain from the cell above still drops in through it (drains always drop a cell).
        func exitBar(_ exit: NlExit, _ a: CGPoint, _ b: CGPoint, into n: CGVector) {
            if walled.contains(exit), exit != .top { wall(a, b); return }
            let portal = bar(a, b, S.exitColor)
            if !walled.contains(exit) { exitPortals[exit] = portal }
            hatch(exit, along: a, b, into: n)
        }
        let entryX = C.entryStubLeft.first!.x + 6
        if room.exits.contains(.left) {
            if !walled.contains(.left) {
                bar(CGPoint(x: entryX, y: C.entryPortalY.lowerBound), CGPoint(x: entryX, y: C.entryPortalY.upperBound), S.entryColor)
            }
            exitBar(.left, CGPoint(x: C.wallLeftX, y: C.sideExitY.lowerBound),
                    CGPoint(x: C.wallLeftX, y: C.sideExitY.upperBound), into: CGVector(dx: 1, dy: 0))
        }
        if room.exits.contains(.right) {
            if !walled.contains(.right) {
                bar(CGPoint(x: 2 * C.centerX - entryX, y: C.entryPortalY.lowerBound),
                    CGPoint(x: 2 * C.centerX - entryX, y: C.entryPortalY.upperBound), S.entryColor)
            }
            exitBar(.right, CGPoint(x: C.wallRightX, y: C.sideExitY.lowerBound),
                    CGPoint(x: C.wallRightX, y: C.sideExitY.upperBound), into: CGVector(dx: -1, dy: 0))
        }
        if room.exits.contains(.top) {
            exitBar(.top, CGPoint(x: C.topPortX.lowerBound, y: C.topY - 1),
                    CGPoint(x: C.topPortX.upperBound, y: C.topY - 1), into: CGVector(dx: 0, dy: -1))
        }
        for exit in NlExit.allCases { setExitLit(exit, exitsLit.contains(exit)) }
    }
}

private extension SKShapeNode {
    /// Configure a freshly made shape inline.
    func then(_ configure: (SKShapeNode) -> Void) -> SKShapeNode {
        configure(self)
        return self
    }
}
