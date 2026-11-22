// Pinball Lab Table 08 (Neon Labyrinth): the table scene. Milestone 1 v1 = one cell standing on its own, in grey box:
// the shared cell kit (walls with bulges, outlanes, lane guides, inlanes, slings, CHOMP!'s real-scale flippers and
// flipper model, the centre drain) and the Switchyard room's floor parts (the ramp's solid low end, the SWITCH and
// RAILS targets on their blocks, the turntable's base, the top lane). The ramp's raised part, the turntable, the
// light-rail ring and the rails are drawn only; they work from the next round.
//
// Every way into a cell is here, so they can be played before the maze exists. With no grid yet a drain costs
// nothing: the ball comes back in by the next way in, in turn —
//   FROM BELOW  : rises up through the drain chute and the flipper gap, then pops onto a flipper (sides alternate);
//   FROM ABOVE  : falls in through the top port onto a return wire, rides it round to an inlane (sides alternate);
//   FROM LEFT / FROM RIGHT : through a side entry portal onto that side's return wire, down to its inlane.
// Geometry: NlCellLayout.swift (generated from tools/nl_layout.py, checked by nl_checks.py / nl_sim.py).
// M2 v1: the Switchyard works. A ramp shot rides up onto the turntable; SWITCH ◄ / ► turn the turntable (W N E,
// stepping), RAILS steps the light-rail ring's bridge (W → N → E → W). Lined up, the turntable fires the ball down that
// light-rail and out through the exit portal; not lined up, the ball derails to the floor. With no maze yet, a ball
// out of an exit comes straight back in as the cell next door would get it (out the left → in from the right, out the
// top → in from below), costing nothing.
// M1 v2: the Shot Lab and Play Lab hosts (CHOMP!'s pattern; `-shotlab neon`, `-playlab neon`). In the Play Lab the cell
// plays as a bottom-row cell: a drain costs a ball (the next ball still comes in by the next way in).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class NlTableScene: SKScene, RendererHostedScene {
    private enum Control { case left, right }

    /// The ways a ball comes into a cell (the drain cycles through them in M1).
    enum Arrival: CaseIterable {
        case fromBelow, fromAbove, fromLeft, fromRight
        var banner: String {
            switch self {
            case .fromBelow: return "FROM BELOW"
            case .fromAbove: return "FROM ABOVE"
            case .fromLeft: return "FROM THE LEFT"
            case .fromRight: return "FROM THE RIGHT"
            }
        }
    }

    /// A ball being moved along a path by the scene (collisions and gravity off), then let go with a set velocity.
    private struct Ride {
        let ball: NlBall
        let path: [CGPoint]
        let cumulative: [CGFloat]
        var s: CGFloat = 0
        let speed: CGFloat
        let height: CGFloat
        let release: CGVector
        /// The lab event when the ride lets go (which arrival it was).
        var event: String? = nil
        /// M2 v1: the height at the end of the path (the height eases from `height` to this along the path).
        var heightEnd: CGFloat? = nil
        /// M2 v1: what happens at the end of the path.
        var end: RideEnd = .release
        /// M2 v1: seconds to wait at the end of the path before it ends.
        var hold: CGFloat = 0
        var total: CGFloat { cumulative.last ?? 0 }
    }

    /// M2 v1: how a ride ends: dropped to the floor with its release velocity, onto the turntable (held, then fired),
    /// fired off the turntable (down a rail or a derail, decided as it fires), out through an exit, or derailed.
    private enum RideEnd { case release, turntable, fire, exit(Int), derail(Int) }

    /// M2 v1: the three ways the turntable and the bridge can point: 0 = W (◄), 1 = N (▲), 2 = E (►).
    static let headingGlyph = ["◄", "▲", "►"]
    static let headingAngle: [CGFloat] = [.pi, .pi / 2, 0]

    private let game: NlGameState
    private let settings: GameSettings
    private let cameraRig = NlCameraRig()
    private let sound = MonSoundPlayer()
    /// The touch surface when the SKRenderer host draws the scene (devices); `view` is nil then.
    weak var hostView: UIView?
    private var buildTag: SKLabelNode?
    private var buildTagBack: SKShapeNode?
    private var buildTagAt: TimeInterval = 0
    private var fpsWindowStart: CFTimeInterval = 0
    private var fpsLastFrame: CFTimeInterval = 0
    private var fpsFrames = 0
    private var fpsWorstGap: CFTimeInterval = 0
    private var fpsShown = 0
    private var fpsWorstShown = 0
    private var fpsLow = 0
    private var lastStep: CGFloat = 0

    private var balls: [NlBall] = []
    private var rides: [Ride] = []
    private var slingshots: [NlSlingshot] = []
    private var leftFlipper: NlFlipper!
    private var rightFlipper: NlFlipper!
    private var isBuilt = false
    private let hitHaptic = Haptic(style: .medium)

    // The Switchyard's targets (placeholders until its rules): which body is which, and a short cooldown each.
    private var targets: [(body: SKNode, name: String, face: SKShapeNode)] = []
    private var targetLastHit: [String: TimeInterval] = [:]
    private var targetFlashUntil: [String: TimeInterval] = [:]

    // M1: the arrival the next drain brings, and which side the alternating arrivals use next.
    private var nextArrival: Arrival = .fromBelow
    private var nextBelowLeft = true
    private var nextAboveLeft = true
    private var drains = 0
    // M1 v4: the outlane saves. Left = the kickback, lit at the start of every ball; right = the outlane save, lit by
    // hitting all three Switchyard targets (placeholder goal until the room's rules). Each fires once.
    private var kickbackLit = true
    private var saveLit = false
    private var targetsHitForSave: Set<String> = []
    private var kickLamps: [SKShapeNode] = []
    // M2 v1: the Switchyard. Where the turntable and the bridge point (0 W, 1 N, 2 E), their drawn angles, and the
    // nodes that show the route.
    private var turntable = 1
    private var bridge = 0
    private var turntableShown: CGFloat = .pi / 2
    private var bridgeShown: CGFloat = .pi
    private var turntablePointer: SKShapeNode?
    private var bridgeNode: SKShapeNode?
    private var railNodes: [[SKShapeNode]] = []
    private var routeLamps: [(lamp: SKShapeNode, label: SKLabelNode)] = []
    private var routeOpen: Bool { turntable == bridge }
    /// The arrival a ball out of an exit comes back in by (the cell next door's view), ahead of the drain cycle.
    private var pendingArrival: Arrival?
    private var nextNorthDerailRight = true

    #if DEBUG
    /// M1 v2: the Shot Lab robot (shared ShotLab) and its own clock.
    fileprivate var shotLab: ShotLab?
    fileprivate var shotLabTime: TimeInterval = 0
    /// M1 v2: the Play Lab (shared PlayLab): the run, when its next game starts.
    private var playLab: PlayLab?
    private var playLabNextAt: TimeInterval?
    private var playLabStarting = false
    /// The Play Lab's watchdog: where each ball was last seen moving, and when.
    private var watchSpots: [ObjectIdentifier: (CGPoint, TimeInterval)] = [:]
    #endif
    /// The Play Lab robot's buttons (always false outside it).
    private var robotLeft = false
    private var robotRight = false

    // Input
    private var activeTouches: [UITouch: Control] = [:]
    private let nudge = Nudge()
    private var padLeft = false
    private var padRight = false

    // Game clock: advances by the clamped frame time only, so pauses and hitches never eat timers.
    private var lastRealTime: TimeInterval?
    private var gameTime: TimeInterval = 0
    private var nextBallAt: TimeInterval?
    private var bannerClearAt: TimeInterval?

    /// The menu: physics stopped, touches ignored.
    var isAttractMode = false {
        didSet {
            guard isAttractMode != oldValue else { return }
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode { releaseAllControls() }
            #if DEBUG
            if isAttractMode { shotLab = nil }                  // Menu stops the Shot Lab
            if isAttractMode { stopPlayLab(saving: true) }      // and the Play Lab (saving the games so far)
            #endif
            refreshCamera()
        }
    }

    var isGamePaused = false {
        didSet {
            if isGamePaused { releaseNonTouchControls() }
            isPaused = isGamePaused
            lastRealTime = nil
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    // Grey-box colours (the skill's): green walls on near-black, orange for anything that kicks or is one-way,
    // silver for wires and rails. The neon look replaces these in the art milestone.
    static let wallColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
    static let floorColor = SKColor(red: 0.03, green: 0.05, blue: 0.07, alpha: 1)
    static let wireColor = SKColor(white: 0.78, alpha: 0.75)
    static let entryColor = SKColor(red: 0.25, green: 0.80, blue: 1.0, alpha: 1)
    static let exitColor = SKColor(red: 1.0, green: 0.30, blue: 0.85, alpha: 1)
    static let targetColor = SKColor(red: 1.0, green: 0.90, blue: 0.50, alpha: 1)
    static let buildTagText = "T8 M2 v1"
    /// The targets' lab event names.
    static let targetEvent = ["SWITCH ◄": "switchLeft", "SWITCH ►": "switchRight", "RAILS": "rails"]

    init(game: NlGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: NlTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: NlTableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        buildTable()
        addBuildTag()
        refreshCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        refreshCamera()
    }

    /// A cell is one screen: always the whole cell (Top-Down).
    private var effectiveCameraMode: CameraMode { .topDown }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addFloor()
        typealias C = NlCellLayout
        addWall(points: C.outerWall, friction: NlTableLayout.railFriction, restitution: NlTableLayout.railRestitution)
        for pts in [C.laneGuideLeft, C.laneGuideRight, C.outlaneWallLeft, C.outlaneWallRight,
                    C.outlanePostRailLeft, C.outlanePostRailRight, C.topLaneWallLeft, C.topLaneWallRight,
                    C.switchBlockLeft, C.switchBlockRight, C.railsBlock, C.rampU] {
            addWall(points: pts)
        }
        for p in [C.laneGuidePostLeft, C.laneGuidePostRight, C.outlanePostLeft, C.outlanePostRight] {
            addPost(at: p, radius: C.laneGuidePostRadius)
        }
        for p in C.topLanePosts { addPost(at: p, radius: C.topLanePostRadius) }
        for p in C.rampMouthPosts { addPost(at: p, radius: C.rampMouthPostRadius) }
        addPost(at: C.hubCenter, radius: C.hubBaseRadius, fill: SKColor(red: 0.08, green: 0.16, blue: 0.11, alpha: 1))

        for s in [C.slingLeft, C.slingRight] {
            let sling = NlSlingshot(top: s[0], corner: s[1], tip: s[2], artBaked: false,
                                    kickFrom: NlTableLayout.slingKickFrom, kickTo: NlTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = NlFlipper(side: .left, pivot: C.pivotLeft)
        rightFlipper = NlFlipper(side: .right, pivot: C.pivotRight)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)

        addTarget(name: "SWITCH ◄", face: C.switchLeftFace, normal: C.switchLeftNormal)
        addTarget(name: "SWITCH ►", face: C.switchRightFace, normal: C.switchRightNormal)
        addTarget(name: "RAILS", face: C.railsFace, normal: C.railsNormal)

        addDrawnSwitchyard()
        addPortals()
        for p in [NlTableLayout.kickLampLeft, CGPoint(x: NlTableLayout.mirrorSum - NlTableLayout.kickLampLeft.x,
                                                       y: NlTableLayout.kickLampLeft.y)] {
            let lamp = SKShapeNode(circleOfRadius: 9)
            lamp.position = p
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            addChild(lamp)
            kickLamps.append(lamp)
        }
        refreshKickLamps()
    }

    /// The floor inside the outer wall, with a faint 50 pt grid (the neon look's grid floor, in grey-box form).
    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: NlCellLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
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
        crop.zPosition = -19.8
        addChild(crop)
    }

    private func addWall(points: [CGPoint],
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
        node.strokeColor = Self.wallColor
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        let body = closed ? SKPhysicsBody(edgeLoopFrom: path) : SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = NlPhysicsCategory.wall
        body.collisionBitMask = NlPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    private func addPost(at p: CGPoint, radius r: CGFloat, fill: SKColor = SKColor(white: 0.85, alpha: 1)) {
        let post = SKShapeNode(circleOfRadius: r)
        post.position = p
        post.fillColor = fill
        post.strokeColor = Self.wallColor
        post.lineWidth = 1.5
        post.zPosition = -19
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
    private func addTarget(name: String, face: (CGPoint, CGPoint), normal: CGVector) {
        let path = CGMutablePath()
        path.addLines(between: [face.0, face.1])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.targetColor
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
        let mid = CGPoint(x: (face.0.x + face.1.x) / 2 - normal.dx * 24, y: (face.0.y + face.1.y) / 2 - normal.dy * 24)
        let label = SKLabelNode(text: name)
        label.fontName = "Menlo-Bold"
        label.fontSize = 11
        label.fontColor = Self.targetColor.withAlphaComponent(0.85)
        label.verticalAlignmentMode = .center
        label.position = mid
        label.zPosition = -17
        addChild(label)
        targets.append((body: node, name: name, face: node))
    }

    /// Drawn only in M1 v1 (they work next round): the ramp's raised part, the turntable, the light-rail ring, the three
    /// light-rails, the return wires and entry stubs, and the route lamps in the open lower table.
    private func addDrawnSwitchyard() {
        typealias C = NlCellLayout
        // The ramp's plastic above its solid low end.
        let ramp = CGMutablePath()
        let left = C.rampLeftRail.filter { $0.y >= C.rampUTopY }
        let right = C.rampRightRail.filter { $0.y >= C.rampUTopY }
        ramp.addLines(between: left + right.reversed())
        ramp.closeSubpath()
        let plastic = SKShapeNode(path: ramp)
        plastic.fillColor = Self.wallColor.withAlphaComponent(0.16)
        plastic.strokeColor = Self.wallColor.withAlphaComponent(0.5)
        plastic.lineWidth = 1.5
        plastic.zPosition = 15
        addChild(plastic)
        // Turntable and the light-rail ring.
        for (r, w, a) in [(C.hubTrackRadius, CGFloat(2.5), CGFloat(0.9)), (C.railRingRadii.0, 1.2, 0.6), (C.railRingRadii.1, 1.2, 0.6)] {
            let ring = SKShapeNode(circleOfRadius: r)
            ring.position = C.hubCenter
            ring.strokeColor = Self.wireColor.withAlphaComponent(a)
            ring.fillColor = r == C.hubTrackRadius ? SKColor(white: 0.08, alpha: 1) : .clear
            ring.lineWidth = w
            ring.zPosition = 16
            addChild(ring)
        }
        // M2 v1: the turntable's pointer and the ring's bridge (drawn pointing east; turned by zRotation).
        let pointer = CGMutablePath()
        pointer.addLines(between: [CGPoint(x: -14, y: 9), CGPoint(x: C.hubTrackRadius - 4, y: 0), CGPoint(x: -14, y: -9)])
        pointer.closeSubpath()
        let pointerNode = SKShapeNode(path: pointer)
        pointerNode.position = C.hubCenter
        pointerNode.lineWidth = 2
        pointerNode.zPosition = 16.5
        addChild(pointerNode)
        turntablePointer = pointerNode
        let bridgeShape = SKShapeNode(rect: CGRect(x: C.railRingRadii.0 - 2, y: -C.railHalfWidth,
                                                   width: C.railRingRadii.1 - C.railRingRadii.0 + 6, height: 2 * C.railHalfWidth),
                                      cornerRadius: 3)
        bridgeShape.position = C.hubCenter
        bridgeShape.lineWidth = 2
        bridgeShape.zPosition = 16.4
        addChild(bridgeShape)
        bridgeNode = bridgeShape
        // Light-rails and return wires: two silver rails each.
        railNodes = [C.railW, C.railN, C.railE].map { addRails($0, halfWidth: C.railHalfWidth, z: 16) }
        for wire in [C.returnWireLeft, C.returnWireRight, C.entryStubLeft, C.entryStubRight] {
            addRails(wire, halfWidth: 17, z: 17)
        }
        // Route lamps (◄ ▲ ►) in the open lower table.
        for (dx, glyph) in [(CGFloat(-46), "◄"), (0, "▲"), (46, "►")] {
            let lamp = SKShapeNode(circleOfRadius: 15)
            lamp.position = CGPoint(x: C.centerX + dx, y: 505)
            lamp.strokeColor = Self.entryColor.withAlphaComponent(0.5)
            lamp.fillColor = SKColor(white: 0.05, alpha: 1)
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            addChild(lamp)
            let label = SKLabelNode(text: glyph)
            label.fontName = "Menlo-Bold"
            label.fontSize = 14
            label.fontColor = Self.entryColor.withAlphaComponent(0.6)
            label.verticalAlignmentMode = .center
            label.position = lamp.position
            label.zPosition = -17.9
            addChild(label)
            routeLamps.append((lamp: lamp, label: label))
        }
        refreshRoute(snap: true)
    }

    @discardableResult
    private func addRails(_ centre: [CGPoint], halfWidth: CGFloat, z: CGFloat) -> [SKShapeNode] {
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
            node.strokeColor = Self.wireColor
            node.lineWidth = 1.6
            node.zPosition = z
            addChild(node)
            nodes.append(node)
        }
        return nodes
    }

    // MARK: - The Switchyard (M2 v1)

    /// Colours the route: the turntable's pointer and its route lamp cyan when the bridge lines up (the route is
    /// open), orange when it doesn't (a ramp shot would derail); the bridge and its lamp's ring magenta; the open
    /// route's light-rail bright. `snap` puts the drawn angles straight on their headings.
    private func refreshRoute(snap: Bool = false) {
        if snap {
            turntableShown = Self.headingAngle[turntable]
            bridgeShown = Self.headingAngle[bridge]
        }
        let orange = SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        let aim = routeOpen ? Self.entryColor : orange
        turntablePointer?.strokeColor = aim
        turntablePointer?.fillColor = aim.withAlphaComponent(0.35)
        turntablePointer?.zRotation = turntableShown
        bridgeNode?.strokeColor = routeOpen ? Self.entryColor : Self.exitColor
        bridgeNode?.fillColor = (routeOpen ? Self.entryColor : Self.exitColor).withAlphaComponent(0.25)
        bridgeNode?.zRotation = bridgeShown
        for (i, nodes) in railNodes.enumerated() {
            let open = routeOpen && i == turntable
            for n in nodes {
                n.strokeColor = open ? Self.entryColor : Self.wireColor
                n.lineWidth = open ? 2.6 : 1.6
            }
        }
        for (i, l) in routeLamps.enumerated() {
            let aimed = i == turntable
            l.lamp.fillColor = aimed ? aim.withAlphaComponent(routeOpen ? 0.85 : 0.45) : SKColor(white: 0.05, alpha: 1)
            l.lamp.strokeColor = i == bridge ? Self.exitColor : Self.entryColor.withAlphaComponent(0.5)
            l.lamp.lineWidth = i == bridge ? 3 : 1.5
            l.label.fontColor = aimed ? .white : Self.entryColor.withAlphaComponent(0.6)
        }
    }

    /// Eases the drawn turntable and bridge toward their headings (update(), so a pause holds them).
    private func turnRoute(_ dt: CGFloat) {
        let step = NlTableLayout.turnRate * dt
        func ease(_ shown: inout CGFloat, _ target: CGFloat) -> Bool {
            let d = target - shown
            guard abs(d) > 0.0001 else { return false }
            shown = abs(d) <= step ? target : shown + (d > 0 ? step : -step)
            return true
        }
        let a = ease(&turntableShown, Self.headingAngle[turntable])
        let b = ease(&bridgeShown, Self.headingAngle[bridge])
        if a || b {
            turntablePointer?.zRotation = turntableShown
            bridgeNode?.zRotation = bridgeShown
        }
    }

    /// A target turned the turntable (SWITCH ◄ / ►, stepping, stopping at W and E) or stepped the bridge (RAILS).
    private func switchyardHit(_ name: String) {
        switch name {
        case "SWITCH ◄": turntable = max(0, turntable - 1)
        case "SWITCH ►": turntable = min(2, turntable + 1)
        case "RAILS": bridge = (bridge + 1) % 3
        default: return
        }
        refreshRoute()
        sfx(.diverter)
    }

    /// The banner for a Switchyard target: the route open, or which way the part now points.
    private func switchyardBanner(_ name: String) -> String {
        if routeOpen { return "ROUTE OPEN \(Self.headingGlyph[turntable])" }
        return name == "RAILS" ? "RAILS \(Self.headingGlyph[bridge])" : "TURNTABLE \(Self.headingGlyph[turntable])"
    }

    /// A floor ball crossing into the ramp's mouth going up fast enough is taken up the ramp to the turntable.
    private func checkRampEntry(_ ball: NlBall) {
        let p0 = ball.previousPosition, p = ball.position
        let entryY = NlCellLayout.rampMouthY + 12
        guard ball.isOnFloor, p0.y < entryY, p.y >= entryY,
              abs(p.x - NlCellLayout.centerX) < NlCellLayout.rampMouthPosts[1].x - NlCellLayout.centerX,
              let v = ball.physicsBody?.velocity, v.dy >= NlTableLayout.rampMinSpeed else { return }
        let speed = min(max(hypot(v.dx, v.dy) * NlTableLayout.rampRideScale, NlTableLayout.rampRideSpeeds.lowerBound),
                        NlTableLayout.rampRideSpeeds.upperBound)
        let c = NlCellLayout.centerX
        ride(ball, path: [p, CGPoint(x: c, y: NlCellLayout.rampUTopY), CGPoint(x: c, y: NlCellLayout.rampTopY),
                          NlCellLayout.hubCenter],
             speed: speed, height: 0, heightEnd: NlTableLayout.rampTopHeight, release: .zero, end: .turntable)
        game.add(NlPoints.ramp)
        sfx(.ramp)
        labEvent("ramp")
    }

    /// The end of a Switchyard ride (from updateRides, after the ride is removed).
    private func endSwitchyardRide(_ done: Ride) {
        typealias C = NlCellLayout
        let ball = done.ball
        let hub = C.hubCenter
        let h = NlTableLayout.rampTopHeight
        switch done.end {
        case .release:
            break
        case .turntable:
            ride(ball, path: [hub, hub], speed: 0, height: h, release: .zero, end: .fire,
                 hold: NlTableLayout.turntableHold)
            showBanner("SWITCHYARD \(Self.headingGlyph[turntable])")
            sfx(.scoopIn)
        case .fire:
            let k = turntable
            let a = Self.headingAngle[k]
            if routeOpen {
                let rail = [C.railW, C.railN, C.railE][k]
                ride(ball, path: [hub] + rail, speed: NlTableLayout.railRideSpeed, height: h, release: .zero, end: .exit(k))
                sfx(.launch)
            } else {
                let out = k == 1 ? NlTableLayout.derailNorthOut : NlTableLayout.derailOut
                let to = CGPoint(x: hub.x + out * cos(a), y: hub.y + out * sin(a))
                ride(ball, path: [hub, to], speed: NlTableLayout.railRideSpeed, height: h, heightEnd: 0,
                     release: .zero, end: .derail(k))
            }
        case .exit(let k):
            removeBall(ball)
            if !nudge.tilted { game.add(NlPoints.exit) }   // a tilted ball still leaves, but scores nothing
            showBanner("EXIT \(Self.headingGlyph[k]) · \(NlPoints.exit)")
            labEvent(["exitLeft", "exitTop", "exitRight"][k])
            sfx(.jackpot)
            hitHaptic.impactOccurred(intensity: 1)
            // No maze yet: it comes straight back in as the cell next door would get it.
            pendingArrival = [Arrival.fromRight, .fromBelow, .fromLeft][k]
            if balls.isEmpty, nextBallAt == nil { nextBallAt = gameTime + 0.8 }
        case .derail(let k):
            let v: CGVector
            switch k {
            case 0: v = CGVector(dx: -NlTableLayout.derailSideVelocity.dx, dy: NlTableLayout.derailSideVelocity.dy)
            case 2: v = NlTableLayout.derailSideVelocity
            default:
                let n = NlTableLayout.derailNorthVelocity
                v = CGVector(dx: nextNorthDerailRight ? n.dx : -n.dx, dy: n.dy)
                nextNorthDerailRight.toggle()
            }
            ball.setLayer(.floor)
            ball.rampHeight = 0
            ball.physicsBody?.velocity = v
            ball.previousPosition = ball.position
            showBanner("DERAIL")
            labEvent("derail")
            sfx(.gate)
        }
    }

    /// The portals on the walls: entries (cyan), exits (magenta; all locked by the maze in M1, drawn only).
    private func addPortals() {
        typealias C = NlCellLayout
        func bar(_ a: CGPoint, _ b: CGPoint, _ color: SKColor) {
            let path = CGMutablePath()
            path.addLines(between: [a, b])
            let node = SKShapeNode(path: path)
            node.strokeColor = color
            node.lineWidth = 6
            node.lineCap = .round
            node.zPosition = -18.5
            addChild(node)
        }
        let entryX = C.entryStubLeft.first!.x + 6
        bar(CGPoint(x: entryX, y: C.entryPortalY.lowerBound), CGPoint(x: entryX, y: C.entryPortalY.upperBound), Self.entryColor)
        bar(CGPoint(x: 2 * C.centerX - entryX, y: C.entryPortalY.lowerBound),
            CGPoint(x: 2 * C.centerX - entryX, y: C.entryPortalY.upperBound), Self.entryColor)
        bar(CGPoint(x: C.wallLeftX, y: C.sideExitY.lowerBound), CGPoint(x: C.wallLeftX, y: C.sideExitY.upperBound), Self.exitColor)
        bar(CGPoint(x: C.wallRightX, y: C.sideExitY.lowerBound), CGPoint(x: C.wallRightX, y: C.sideExitY.upperBound), Self.exitColor)
        bar(CGPoint(x: C.topPortX.lowerBound, y: C.topY - 1), CGPoint(x: C.topPortX.upperBound, y: C.topY - 1), Self.exitColor)
    }

    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: Self.buildTagText)
        label.fontName = "Menlo-Bold"
        label.fontSize = 12
        label.fontColor = SKColor(white: 1, alpha: 0.85)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        label.numberOfLines = 0
        label.zPosition = 50
        cameraRig.node.addChild(label)
        let back = SKShapeNode()
        back.fillColor = SKColor(white: 0, alpha: 0.6)
        back.strokeColor = .clear
        back.zPosition = 49
        cameraRig.node.addChild(back)
        buildTagBack = back
        buildTag = label
        #endif
    }

    /// Camera children use screen points, centred on the screen. Text changes at most 4 times a second.
    private func placeBuildTag() {
        guard let buildTag else { return }
        buildTag.position = CGPoint(x: -size.width / 2 + 10, y: -size.height / 2 + 10)
        let t = CACurrentMediaTime()
        let gap = t - fpsLastFrame
        fpsLastFrame = t
        if gap > 0.5 {
            fpsWindowStart = t; fpsFrames = 0; fpsWorstGap = 0
        } else {
            fpsFrames += 1
            fpsWorstGap = max(fpsWorstGap, gap)
            let window = t - fpsWindowStart
            if window >= 0.5 {
                fpsShown = Int((Double(fpsFrames) / window).rounded())
                fpsWorstShown = Int((fpsWorstGap * 1000).rounded())
                if fpsLow == 0 || fpsShown < fpsLow { fpsLow = fpsShown }
                fpsWindowStart = t; fpsFrames = 0; fpsWorstGap = 0
            }
        }
        guard gameTime - buildTagAt >= 0.25 else { return }
        buildTagAt = gameTime
        var speed = 0
        if let v = focusBall?.physicsBody?.velocity {
            speed = Int(hypot(v.dx, v.dy) / 10) * 10
        }
        let fps = fpsShown > 0 ? "\(fpsShown) fps · low \(fpsLow) · worst \(fpsWorstShown) ms\n" : ""
        let route = "\(Self.headingGlyph[turntable])\(routeOpen ? "=" : "≠")\(Self.headingGlyph[bridge])"
        let text = "\(fps)\(Self.buildTagText) · \(speed) · \(route) · drains \(drains) · next \(nextArrival.banner.lowercased())"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls and arrivals

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: NlBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func removeBall(_ ball: NlBall) {
        rides.removeAll(where: { $0.ball === ball })
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
    }

    private func removeAllBalls() {
        rides.removeAll()
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
    }

    /// Brings a ball into the cell by `arrival`. The alternating ones (below, above) take the next side.
    private func arrive(_ arrival: Arrival) {
        typealias C = NlCellLayout
        kickbackLit = true                          // every ball starts with the kickback lit
        refreshKickLamps()
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // a tilt ends here
        switch arrival {
        case .fromBelow:
            let left = nextBelowLeft
            nextBelowLeft.toggle()
            let start = CGPoint(x: C.centerX, y: C.upRiseStartY)
            startRide(from: start, path: [start, C.upRelease], speed: NlTableLayout.riseSpeed, height: 0,
                      release: left ? C.upPopLeft : C.upPopRight, event: "fromBelow")
        case .fromAbove:
            let left = nextAboveLeft
            nextAboveLeft.toggle()
            let wire = left ? C.returnWireLeft : C.returnWireRight
            let top = CGPoint(x: C.centerX, y: C.topY - 4)          // through the top port, down the top lane
            startRide(from: top, path: [top] + wire, speed: NlTableLayout.wireRideSpeed,
                      height: NlTableLayout.wireHeight, release: CGVector(dx: 0, dy: -C.wireReleaseSpeed), event: "fromAbove")
        case .fromLeft, .fromRight:
            let isLeft = arrival == .fromLeft
            let stub = isLeft ? C.entryStubLeft : C.entryStubRight
            let wire = isLeft ? C.returnWireLeft : C.returnWireRight
            let join = stub.last!
            let j = wire.indices.min(by: { hypot(wire[$0].x - join.x, wire[$0].y - join.y)
                                           < hypot(wire[$1].x - join.x, wire[$1].y - join.y) }) ?? 0
            let path = stub + wire[(j + 1)...]
            startRide(from: stub[0], path: path, speed: NlTableLayout.wireRideSpeed,
                      height: NlTableLayout.wireHeight, release: CGVector(dx: 0, dy: -C.wireReleaseSpeed),
                      event: isLeft ? "fromLeft" : "fromRight")
        }
        showBanner(arrival.banner)
        sfx(arrival == .fromBelow ? .upKick : .launch)
    }

    private func startRide(from start: CGPoint, path: [CGPoint], speed: CGFloat, height: CGFloat, release: CGVector,
                           event: String? = nil) {
        let ball = NlBall(at: start)
        addChild(ball)
        balls.append(ball)
        ride(ball, path: path, speed: speed, height: height, release: release, event: event)
    }

    /// Puts a ball (new or in play) on a ride along `path`.
    private func ride(_ ball: NlBall, path: [CGPoint], speed: CGFloat, height: CGFloat, heightEnd: CGFloat? = nil,
                      release: CGVector, event: String? = nil, end: RideEnd = .release, hold: CGFloat = 0) {
        rides.removeAll(where: { $0.ball === ball })
        ball.setLayer(.ride)
        ball.physicsBody?.velocity = .zero
        ball.flipperGhostSteps = 0
        var cumulative: [CGFloat] = [0]
        for i in 1..<max(path.count, 1) {
            cumulative.append(cumulative[i - 1] + hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y))
        }
        rides.append(Ride(ball: ball, path: path, cumulative: cumulative, speed: speed, height: height, release: release,
                          event: event, heightEnd: heightEnd, end: end, hold: hold))
    }

    /// Moves every riding ball along its path; at the end it drops to the floor with its release velocity.
    private func updateRides(_ dt: CGFloat) {
        var finished: [Int] = []
        for i in rides.indices {
            rides[i].s += rides[i].speed * dt
            let ride = rides[i]
            let s = min(ride.s, ride.total)
            var k = 1
            while k < ride.cumulative.count - 1 && ride.cumulative[k] < s { k += 1 }
            let a = ride.path[k - 1], b = ride.path[min(k, ride.path.count - 1)]
            let seg = max(ride.cumulative[min(k, ride.cumulative.count - 1)] - ride.cumulative[k - 1], 0.001)
            let f = min(max((s - ride.cumulative[k - 1]) / seg, 0), 1)
            ride.ball.position = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            ride.ball.physicsBody?.velocity = .zero
            if let h1 = ride.heightEnd, ride.total > 0 {
                ride.ball.rampHeight = ride.height + (h1 - ride.height) * s / ride.total
            } else {
                ride.ball.rampHeight = ride.heightEnd ?? ride.height
            }
            if ride.s >= ride.total {
                if ride.hold > 0 { rides[i].hold -= dt } else { finished.append(i) }
            }
        }
        for i in finished.reversed() {
            let ride = rides.remove(at: i)
            if let name = ride.event { labEvent(name) }
            if case .release = ride.end {
                ride.ball.setLayer(.floor)
                ride.ball.rampHeight = 0
                ride.ball.physicsBody?.velocity = ride.release
                ride.ball.previousPosition = ride.ball.position
            } else {
                endSwitchyardRide(ride)
            }
        }
    }

    func newGame() {
        fpsLow = 0
        isAttractMode = false
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game stops the Shot Lab
        if !playLabStarting { stopPlayLab(saving: true) }   // and the Play Lab, unless it's starting its next game
        #endif
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        targetLastHit = [:]
        kickbackLit = true
        saveLit = false
        targetsHitForSave = []
        refreshKickLamps()
        turntable = 1                              // M2 v1: the turntable points N, the bridge W (not lined up)
        bridge = 0
        pendingArrival = nil
        nextNorthDerailRight = true
        refreshRoute(snap: true)
        drains = 0
        nextBelowLeft = true
        nextAboveLeft = true
        game.reset()
        nextArrival = .fromAbove                   // after the first ball (from below), the drains cycle on
        arrive(.fromBelow)
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        #if DEBUG
        playLab?.banner(text)
        labObjective(forBanner: text)
        #endif
        game.banner = text
        bannerClearAt = gameTime + NlTableLayout.bannerSeconds
    }

    private func sfx(_ s: MonSound) {
        #if DEBUG
        if shotLab != nil { return }
        if playLab != nil, playLab?.isWatching != true { return }   // the robot plays silently unless watched
        #endif
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView, !isAttractMode else { return }
        for touch in touches {
            let p = touch.location(in: view)   // screen points
            activeTouches[touch] = p.x < view.bounds.midX ? .left : .right
            nudge.swipeBegan(touch, at: p)
        }
        updateFlippers()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView else { return }
        for touch in touches where activeTouches[touch] != nil {
            // A quick flick of a flipper finger nudges the table.
            if let direction = nudge.swipeMoved(touch, to: touch.location(in: view)) { applyNudge(direction) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            nudge.swipeEnded(touch)
            activeTouches.removeValue(forKey: touch)
        }
        updateFlippers()
    }

    private func updateFlippers() {
        #if DEBUG
        if shotLab != nil { return }               // the robot has the flippers
        #endif
        var left = activeTouches.values.contains(.left) || padLeft || robotLeft
        var right = activeTouches.values.contains(.right) || padRight || robotRight
        if nudge.tilted { left = false; right = false }      // tilted: dead flippers until the next ball
        if left && !leftFlipper.isPressed { sfx(.flipper) }
        if right && !rightFlipper.isPressed { sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
    }

    private func applyNudge(_ direction: Nudge.Direction) {
        guard !isAttractMode, !game.isGameOver else { return }
        let free = balls.filter { $0.isOnFloor }
        let outcome = nudge.nudge(direction, at: gameTime, balls: free.compactMap { $0.physicsBody })
        Nudge.haptic(for: outcome)
        switch outcome {
        case .ignored:
            return
        case .nudged:
            cameraRig.jolt(direction.unit, strength: Nudge.joltNudge)
        case .warning:
            cameraRig.jolt(direction.unit, strength: Nudge.joltWarning)
            cameraRig.shake(strength: 4, duration: 0.3)
            showBanner("TILT WARNING")
        case .tilt:
            cameraRig.jolt(direction.unit, strength: Nudge.joltTilt, duration: 0.35)
            cameraRig.shake(strength: 8, duration: 0.7)
            showBanner("TILT")
            updateFlippers()                                 // the flippers drop
        }
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        if leftFlipper != nil { updateFlippers() }
    }

    /// Pausing (Table 06's fix): a flipper finger still down stays held, so a cradled ball is still cradled after resume.
    private func releaseNonTouchControls() {
        padLeft = false
        padRight = false
        if leftFlipper != nil { updateFlippers() }
    }

    /// Game controller, every frame of play: shoulders/triggers flip; touches keep working alongside.
    private func updateGamepad() {
        let pad = LabGamepad.shared.state
        if let direction = pad.nudge { applyNudge(direction) }
        if pad.left != padLeft || pad.right != padRight {
            padLeft = pad.left
            padRight = pad.right
            updateFlippers()
        }
    }

    // MARK: - Game loop

    override func update(_ realTime: TimeInterval) {
        var step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
        #if DEBUG
        if let lab = playLab { step *= Double(lab.physicsSpeed) }   // the Play Lab's pass (120 Hz steps)
        #endif
        lastRealTime = realTime
        gameTime += step
        let now = gameTime
        #if DEBUG
        if shotLab != nil {                        // Shot Lab: the robot's frame instead of a game frame
            updateShotLab(CGFloat(step))
            return
        }
        #endif
        if isAttractMode { return }

        let dt = CGFloat(step)
        lastStep = dt
        updateGamepad()
        #if DEBUG
        updatePlayLab(now)
        #endif
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        updateRides(dt)
        turnRoute(dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        governInlanes()                          // the inlane speed limit (InlaneGovernor, shared)

        for t in targets {
            if let until = targetFlashUntil[t.name], now >= until {
                targetFlashUntil[t.name] = nil
                t.face.strokeColor = Self.targetColor
            }
        }

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // The drain: a floor ball across the drain line drops to the cell below. M1 has no grid, so in play it costs
        // nothing and comes back in by the next way in; in the Play Lab the cell plays as a bottom-row cell (a ball lost).
        let drained = balls.filter { $0.isOnFloor && $0.position.y < NlCellLayout.drainLineY }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            drains += drained.count
            cameraRig.shake(strength: 3, duration: 0.25)
            sfx(.drain)
            if balls.isEmpty, nextBallAt == nil {
                if drainsCostBalls {
                    game.ballDrained()
                    if !game.isGameOver { nextBallAt = now + 0.8 }
                } else {
                    nextBallAt = now + 0.8
                }
            }
        }

        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            if let back = pendingArrival {         // M2 v1: back in from an exit (the drain cycle doesn't move)
                pendingArrival = nil
                arrive(back)
            } else {
                let arrival = nextArrival
                let all = Arrival.allCases
                nextArrival = all[(all.firstIndex(of: arrival)! + 1) % all.count]
                arrive(arrival)
            }
        }
        #if DEBUG
        checkPlayLabGame(now)
        #endif
    }

    /// Whether a drain costs a ball: only in the Play Lab for now (the cell as a bottom-row cell).
    private var drainsCostBalls: Bool {
        #if DEBUG
        return playLab != nil
        #else
        return false
        #endif
    }

    /// A floor ball within reach of a flipper swinging up this frame belongs to the flipper model for the physics step
    /// (ghosted from the flippers); NlFlipper.solveSwing works out the frame afterwards (CHOMP! M2 v10).
    private func handBallsToSwingingFlippers() {
        guard NlTableLayout.flipperModel else { return }
        let r = NlTableLayout.ballRadius
        for ball in balls where ball.isOnFloor {
            for f in [leftFlipper!, rightFlipper!] where f.isSwingingUp && f.reaches(ball.position, ballRadius: r) {
                ball.flipperGhostSteps = max(ball.flipperGhostSteps, 1)
            }
        }
    }

    /// Hot inlane feeds: a ball rolling down an inlane is held to InlaneGovernor.maxSpeed so a held flipper can trap it.
    private func governInlanes() {
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody,
                  let v = InlaneGovernor.limited(body.velocity, at: ball.position,
                                                 leftGuide: NlTableLayout.governorGuide,
                                                 mirrorSum: NlTableLayout.mirrorSum) else { continue }
            body.velocity = v
        }
    }

    /// The solid blocks (closed outlines): a floor ball whose centre ends up inside one is put back just outside its
    /// nearest edge, with any velocity into that edge removed (CHOMP! M3 v13).
    private let solidBlocks: [[CGPoint]] = [NlCellLayout.switchBlockLeft, NlCellLayout.switchBlockRight,
                                            NlCellLayout.railsBlock]

    private func keepOutOfSolids(_ ball: NlBall) {
        let p = ball.position
        for closed in solidBlocks where closed.count > 3 {
            let poly = Array(closed.dropLast())                  // last point repeats the first
            var inside = false
            var j = poly.count - 1
            for i in 0..<poly.count {
                let a = poly[i], b = poly[j]
                if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
                j = i
            }
            guard inside else { continue }
            var best = CGFloat.greatestFiniteMagnitude
            var q = p
            for i in 0..<poly.count {
                let a = poly[i], b = poly[(i + 1) % poly.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 0.001)))
                let c = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
                let d = hypot(p.x - c.x, p.y - c.y)
                if d < best { best = d; q = c }
            }
            let len = max(best, 0.001)
            let n = CGVector(dx: (q.x - p.x) / len, dy: (q.y - p.y) / len)      // outward (inside → the edge)
            let r = NlTableLayout.ballRadius + 0.5
            ball.position = CGPoint(x: q.x + n.dx * r, y: q.y + n.dy * r)
            if let body = ball.physicsBody {
                let v = body.velocity
                let vn = v.dx * n.dx + v.dy * n.dy
                if vn < 0 { body.velocity = CGVector(dx: v.dx - vn * n.dx, dy: v.dy - vn * n.dy) }
            }
            return
        }
    }

    override func didSimulatePhysics() {
        let r = NlTableLayout.ballRadius
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if ball.flipperGhostSteps > 0 { ball.flipperGhostSteps -= 1 }
            if ball.isOnFloor {
                leftFlipper.solveSwing(ball, ballRadius: r)
                rightFlipper.solveSwing(ball, ballRadius: r)
                keepOutOfSolids(ball)
                checkOutlaneSave(ball)
            }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            if speed > NlTableLayout.maxBallSpeed {
                let scale = NlTableLayout.maxBallSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            checkRampEntry(ball)                   // M2 v1: up the ramp onto the turntable
            ball.previousPosition = ball.position
            ball.previousVelocity = body.velocity
            ball.updateLook()
        }
    }

    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: lastStep)
        placeBuildTag()
    }

    // MARK: - Outlane saves

    /// A lit save fires when a floor ball crosses the trigger height going down in its outlane: the ball is put at the
    /// outlane's centre and kicked out through the mouth, across to the far flipper (NlTableLayout.kick…).
    private func checkOutlaneSave(_ ball: NlBall) {
        let p0 = ball.previousPosition, p = ball.position
        let y = NlTableLayout.outlaneTriggerY
        guard p0.y >= y, p.y < y else { return }
        let left = p.x < NlTableLayout.outlaneMaxX
        let right = p.x > NlTableLayout.mirrorSum - NlTableLayout.outlaneMaxX
        guard (left && kickbackLit) || (right && saveLit), let body = ball.physicsBody else { return }
        let a = NlTableLayout.kickAngle, k = NlTableLayout.kickSpeed
        let from = NlTableLayout.kickFromLeft
        if left {
            kickbackLit = false
            ball.position = from
            body.velocity = CGVector(dx: k * cos(a), dy: k * sin(a))
            showBanner("KICKBACK")
            labEvent("kickback")
        } else {
            saveLit = false
            ball.position = CGPoint(x: NlTableLayout.mirrorSum - from.x, y: from.y)
            body.velocity = CGVector(dx: -k * cos(a), dy: k * sin(a))
            showBanner("OUTLANE SAVE")
            labEvent("outlaneSave")
        }
        ball.previousPosition = ball.position
        refreshKickLamps()
        sfx(.kickback)
        hitHaptic.impactOccurred(intensity: 0.9)
        cameraRig.shake(strength: 3, duration: 0.2)
    }

    private func refreshKickLamps() {
        let on = SKColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1)
        let off = SKColor(red: 0.14, green: 0.28, blue: 0.18, alpha: 0.9)
        for (i, lamp) in kickLamps.enumerated() {
            let lit = i == 0 ? kickbackLit : saveLit
            lamp.fillColor = lit ? on : off
            lamp.strokeColor = lit ? .white : on.withAlphaComponent(0.4)
        }
    }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        let ballish = NlPhysicsCategory.ball | NlPhysicsCategory.ghostBall
        if a.categoryBitMask & ballish != 0 {
            ballBody = a; other = b
        } else if b.categoryBitMask & ballish != 0 {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? NlBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case NlPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? NlSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                labEvent("sling")
                game.add(NlPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case NlPhysicsCategory.target:
            // The Switchyard's targets: placeholder scoring and a flash until they turn the turntable and the rails.
            guard let t = targets.first(where: { $0.body === node }) else { break }
            if let last = targetLastHit[t.name], gameTime - last < 0.15 { break }
            targetLastHit[t.name] = gameTime
            if !saveLit {
                targetsHitForSave.insert(t.name)
                if targetsHitForSave.count == targets.count {      // all three: light the right outlane save
                    saveLit = true
                    targetsHitForSave = []
                    refreshKickLamps()
                    showBanner("OUTLANE SAVE LIT")
                    labEvent("saveLit")
                }
            }
            labEvent(Self.targetEvent[t.name] ?? "target")
            game.add(NlPoints.target)
            switchyardHit(t.name)
            showBanner(switchyardBanner(t.name))
            sfx(.standup)
            hitHaptic.impactOccurred(intensity: 0.7)
            t.face.strokeColor = .white                     // back to its colour in update()
            targetFlashUntil[t.name] = gameTime + 0.12
        default:
            break
        }
    }
}

extension NlTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}

private extension SKShapeNode {
    /// Configure a freshly made shape inline.
    func then(_ configure: (SKShapeNode) -> Void) -> SKShapeNode {
        configure(self)
        return self
    }
}

extension NlTableScene {
    /// A shot event for the labs (a no-op in play and in Release builds).
    fileprivate func labEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        playLab?.shot(name, now: gameTime)
        if Self.playLabShotObjectives.contains(name) { playLab?.objective(name, now: gameTime) }
        #endif
    }
}

#if DEBUG
// MARK: - M1 v2: the Shot Lab host (CHOMP!'s pattern). The robot sweeps flip timings from both flippers and records
// the first shot each flip makes. Run in the Simulator: tools/shotlab_run.sh neon
extension NlTableScene: ShotLabHost {
    var shotLabTableName: String { "Neon" }

    /// The Switchyard's shots end a trial; slings are noted only.
    var shotLabMajorEvents: Set<String> { ["ramp", "switchLeft", "switchRight", "rails"] }

    /// CHOMP!'s gravity (−6.0) rolls a cradled ball slowly; its sweep runs to 0.85 s, so this one does too.
    var shotLabCradleDelays: ClosedRange<Double> { 0.20...0.85 }

    /// Cradled as on CHOMP! (same flipper: 80 long, 30° rest, 51° stroke, 30 pt ball): dropped 40 pt out, above the raised
    /// flipper by the ball's radius + 5. The inlane start is the inlane's centre line under the guide post.
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = NlTableLayout.flipperTravel - NlTableLayout.flipperRestAngle
        let along: CGFloat = 40, above: CGFloat = NlTableLayout.ballRadius + 5
        let l = NlCellLayout.pivotLeft
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: NlTableLayout.mirrorSum - left.x, y: left.y)
        let ix = (NlCellLayout.laneGuidePostLeft.x + NlCellLayout.slingLeft[0].x) / 2
        let iy = NlCellLayout.laneGuidePostLeft.y + 10
        let r = NlCellLayout.pivotRight
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left,
                                    starts: ShotLab.lowerStarts(pivot: l, pointsLeft: false, inlaneX: ix, inlaneTopY: iy)),
                ShotLab.FlipperSpec(name: "right", pivot: r, cradle: right,
                                    starts: ShotLab.lowerStarts(pivot: r, pointsLeft: true,
                                                                inlaneX: NlTableLayout.mirrorSum - ix, inlaneTopY: iy))]
    }

    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        if index == 0 { leftFlipper.isPressed = pressed } else { rightFlipper.isPressed = pressed }
    }

    func shotLabPlaceBall(at point: CGPoint) {
        let ball = NlBall(at: point)
        addChild(ball)
        balls.append(ball)
    }

    func shotLabPlaceBall(at point: CGPoint, velocity: CGVector) {
        shotLabPlaceBall(at: point)
        balls.last?.physicsBody?.velocity = velocity
    }

    /// Every ball gone, nothing riding, no ball due.
    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        kickbackLit = false                         // the robot measures the bare table: no saves
        saveLit = false
        refreshKickLamps()
        turntable = 1                               // M2 v1: and the route as a new game has it
        bridge = 0
        refreshRoute(snap: true)
    }

    /// Where shots cross the shot line (the ramp mouth and the SWITCH targets, y ~560–610) and the RAILS target's height.
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "shotLine", y: 580), ShotLab.Probe(name: "rails", y: 752)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }

    func debugStartShotLab() {
        stopPlayLab(saving: true)                  // a Shot Lab started mid Play Lab ends that run first
        isAttractMode = false
        removeAllBalls()
        shotLabTime = 0
        kickbackLit = false
        saveLit = false
        refreshKickLamps()
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// The robot's frame: only what the physics and shot detection need (no arrivals, drains or banners).
    fileprivate func updateShotLab(_ realDt: CGFloat) {
        guard let lab = shotLab else { return }
        let speed = CGFloat(lab.physicsSpeed)
        physicsWorld.speed = speed
        let dt = realDt * speed
        shotLabTime += TimeInterval(dt)
        let now = shotLabTime
        lastStep = dt
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        governInlanes()
        if lab.update(now: now) {
            game.banner = lab.progressText
        } else {
            let saved = lab.save(now: now)
            shotLab = nil
            physicsWorld.speed = 1
            shotLabResetTable()
            game.banner = "SHOT LAB DONE · \(lab.trials.count) TRIALS · \(saved)"
            ShotLab.quitIfLaunchedForLab()          // launched by tools/shotlab_run.sh neon → quit
        }
    }
}

// MARK: - M1 v2: the Play Lab host (CHOMP!'s pattern). Robot players at four skills play whole games of the cell as a
// bottom-row cell; the report shows drains, stuck balls and which shots get made. tools/playlab_run.sh neon
extension NlTableScene: PlayLabHost {
    var playLabTableName: String { "Neon" }
    var playLabBallRadius: CGFloat { NlTableLayout.ballRadius }
    var playLabVariantCount: Int { 1 }

    /// Shot events that count as objectives the first time each game (labEvent reports them).
    static let playLabShotObjectives: Set<String> = ["ramp", "switchLeft", "switchRight", "rails",
                                                      "fromBelow", "fromAbove", "fromLeft", "fromRight",
                                                      "kickback", "saveLit", "outlaneSave",
                                                      "exitLeft", "exitTop", "exitRight", "derail"]

    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "ramp", text: "Shoot into the ramp's mouth"),
         PlayObjective(name: "switchLeft", text: "Hit SWITCH ◄"),
         PlayObjective(name: "switchRight", text: "Hit SWITCH ►"),
         PlayObjective(name: "rails", text: "Hit RAILS"),
         PlayObjective(name: "fromBelow", text: "A ball comes in from below"),
         PlayObjective(name: "fromAbove", text: "A ball comes in from above"),
         PlayObjective(name: "fromLeft", text: "A ball comes in from the left"),
         PlayObjective(name: "fromRight", text: "A ball comes in from the right"),
         PlayObjective(name: "kickback", text: "The kickback saves a ball"),
         PlayObjective(name: "saveLit", text: "Light the outlane save (all three targets)"),
         PlayObjective(name: "outlaneSave", text: "The outlane save saves a ball"),
         PlayObjective(name: "exitLeft", text: "Out the left exit (turntable and bridge ◄, then the ramp)"),
         PlayObjective(name: "exitTop", text: "Out the top exit (▲)"),
         PlayObjective(name: "exitRight", text: "Out the right exit (►)"),
         PlayObjective(name: "derail", text: "A ramp shot derails"),
         PlayObjective(name: "tilt", text: "Tilt")]
    }

    /// Where a 30 pt ball rests on the raised flipper: CHOMP!'s measured spot (M4 v2) moved with the pivot — the same
    /// flipper. Flip delays: the middle of each Shot Lab window, 120 Hz (filled in from this table's own Shot Lab).
    var playLabFlippers: [PlayRobotFlipper] {
        let specs = shotLabFlippers
        let rest = NlTableLayout.flipperRestAngle
        let rightRest = CGPoint(x: NlCellLayout.pivotRight.x - 7, y: NlCellLayout.pivotRight.y + 32)
        let leftRest = CGPoint(x: NlTableLayout.mirrorSum - rightRest.x, y: rightRest.y)
        return [PlayRobotFlipper(name: "left", pivot: specs[0].pivot, length: NlTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: false, cradle: leftRest, rightButton: false, upper: false,
                                 shots: Self.leftShots, inlane: Self.leftInlane, feedCatchSpeed: 300),
                PlayRobotFlipper(name: "right", pivot: specs[1].pivot, length: NlTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: rightRest, rightButton: true, upper: false,
                                 shots: Self.rightShots, inlane: Self.rightInlane, feedCatchSpeed: 300)]
    }

    // Shot delays: the middle of each 120 Hz cradle window, shotlab-neon-2026-11-22T19-47-37Z (FAST=8). Inlane bands:
    // shotlab-neon-inlane-2026-11-22T19-50-16Z, 4 pt bins of the ball's distance from the pivot at the flip, 3+ trials.
    static let leftShots: [(name: String, delay: Double)] = [("switchLeft", 0.244), ("ramp", 0.471),
                                                              ("switchRight", 0.557), ("rails", 0.621)]
    static let rightShots: [(name: String, delay: Double)] = [("switchRight", 0.252), ("ramp", 0.471),
                                                               ("switchLeft", 0.558)]
    static let leftInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("ramp", 28, 31), ("switchRight", 36, 39),
                                                                          ("rails", 40, 47)]
    static let rightInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("ramp", 28, 31), ("switchLeft", 36, 39)]

    func playLabStartGame(variant: Int) -> String {
        game.isRobot = true
        playLabStarting = true
        newGame()
        playLabStarting = false
        physicsWorld.speed = playLab?.physicsSpeed ?? 1
        return ""
    }

    func playLabEndGame() -> [String: Int] {
        if !game.isGameOver {
            removeAllBalls()
            nextBallAt = nil
        }
        return ["drains": drains]
    }

    func playLabStop() {
        game.isRobot = false
    }

    /// Starts the Play Lab (robot players at four skills, 120 Hz, or as the launch arguments say). Menu or a new game
    /// stops it, saving the games played so far.
    func debugStartPlayLab() {
        shotLab = nil
        stopPlayLab(saving: true)
        isAttractMode = false
        let lab = PlayLab(host: self)
        playLab = lab
        lab.beginGame(now: gameTime)
    }

    /// Everything the robot needs to know this frame, and its buttons applied. Riding balls count as held.
    fileprivate func updatePlayLab(_ now: TimeInterval) {
        guard let lab = playLab else { return }
        if game.isGameOver || playLabNextAt != nil {
            if robotLeft || robotRight { robotLeft = false; robotRight = false; updateFlippers() }
            return
        }
        let view = PlayRobotView(now: now, balls: balls.map { b in
            PlayRobotView.Ball(position: b.position, velocity: b.physicsBody?.velocity ?? .zero, isUpper: !b.isOnFloor,
                               isHeld: !b.isOnFloor, onPlunger: false, id: ObjectIdentifier(b).hashValue)
        }, wanted: robotWanted())
        runWatchdog(now, lab)
        guard let cmd = lab.frame(view) else { return }
        if let direction = cmd.nudge { applyNudge(direction) }
        if cmd.left != robotLeft || cmd.right != robotRight {
            robotLeft = cmd.left
            robotRight = cmd.right
            updateFlippers()
        }
    }

    /// A ball off the table, or one that hasn't moved 4 pt in 5 s while not riding or cradled, is recorded as an
    /// incident and served again (no ball lost).
    private func runWatchdog(_ now: TimeInterval, _ lab: PlayLab) {
        let w = NlTableLayout.worldSize
        for ball in balls {
            let id = ObjectIdentifier(ball)
            let p = ball.position
            if !p.x.isFinite || !p.y.isFinite || p.x < -30 || p.x > w.width + 30 || p.y > w.height + 30 {
                watchdogRescue("offTable", ball, now, lab)
                continue
            }
            if !ball.isOnFloor || isCradled(ball) || p.y < NlCellLayout.drainLineY {
                watchSpots[id] = (p, now)
                continue
            }
            if let spot = watchSpots[id], hypot(p.x - spot.0.x, p.y - spot.0.y) < 4 {
                if now - spot.1 > 5 { watchdogRescue("stuck", ball, now, lab) }
            } else {
                watchSpots[id] = (p, now)
            }
        }
    }

    /// A ball resting on a raised flipper is being held on purpose.
    private func isCradled(_ ball: NlBall) -> Bool {
        let flippers = playLabFlippers
        for (i, pressed) in [leftFlipper.isPressed, rightFlipper.isPressed].enumerated() where pressed {
            let c = flippers[i].cradle
            if hypot(ball.position.x - c.x, ball.position.y - c.y) < 30 { return true }
        }
        return false
    }

    private func watchdogRescue(_ kind: String, _ ball: NlBall, _ now: TimeInterval, _ lab: PlayLab) {
        let p = ball.position
        let x = p.x.isFinite ? Double(p.x) : -1, y = p.y.isFinite ? Double(p.y) : -1
        lab.incident(PlayIncident(kind: kind, x: x.rounded(), y: y.rounded(), upper: !ball.isOnFloor,
                                  time: lab.elapsed(now: now).rounded()))
        watchSpots[ObjectIdentifier(ball)] = nil
        removeBall(ball)
        if balls.isEmpty, nextBallAt == nil { nextBallAt = now + 0.5 }      // served again, no ball lost
        showBanner("WATCHDOG · \(kind == "stuck" ? "STUCK BALL" : "BALL OFF THE TABLE") AT \(Int(x)), \(Int(y))")
    }

    /// The shots the table wants, most wanted first (no rules yet): the ramp, then the targets.
    private func robotWanted() -> [String] {
        // The targets still needed for the outlane save first, then the ramp and the rest.
        // M2 v1: then the route: the ramp when it's open, else the target that lines it up soonest.
        let need = targets.map(\.name).filter { !targetsHitForSave.contains($0) }.compactMap { Self.targetEvent[$0] }
        var route: [String] = ["ramp"]
        if !routeOpen {
            let switchHits = abs(turntable - bridge)
            let railsHits = (turntable - bridge + 3) % 3
            route = railsHits <= switchHits ? ["rails"] : [turntable > bridge ? "switchLeft" : "switchRight"]
        }
        var out: [String] = []
        for s in route + (saveLit ? [] : need) + ["ramp", "switchLeft", "switchRight", "rails"] where !out.contains(s) {
            out.append(s)
        }
        return out
    }

    /// Banners that double as objectives.
    fileprivate func labObjective(forBanner text: String) {
        guard let lab = playLab else { return }
        if text == "TILT" { lab.objective("tilt", now: gameTime) }
    }

    /// At game over (or after the cap) the game is recorded; the next one starts 2 s later.
    fileprivate func checkPlayLabGame(_ now: TimeInterval) {
        guard let lab = playLab else { return }
        if let due = playLabNextAt {
            if now >= due {
                playLabNextAt = nil
                if lab.isDone { finishPlayLab() } else { lab.beginGame(now: now) }
            }
            return
        }
        guard lab.current != nil, game.isGameOver || lab.isTimeUp(now: now) else { return }
        let over = game.isGameOver
        lab.endGame(score: game.score, ballsPlayed: NlGameState.ballsPerGame - game.ballsLeft + (over ? 0 : 1),
                    endedBy: over ? "gameOver" : "time", now: now)
        physicsWorld.speed = lab.physicsSpeed
        playLabNextAt = now + 2
    }

    private func finishPlayLab() {
        guard let lab = playLab else { return }
        let saved = lab.save()
        let count = lab.games.count
        stopPlayLab(saving: false)
        newGame()
        game.banner = "PLAY LAB DONE · \(count) GAMES · \(saved)"
        bannerClearAt = nil
        PlayLab.quitIfLaunchedForLab()
    }

    fileprivate func stopPlayLab(saving: Bool) {
        guard let lab = playLab else { return }
        playLab = nil
        lab.stop(saving: saving)
        playLabNextAt = nil
        watchSpots.removeAll()
        robotLeft = false
        robotRight = false
        if leftFlipper != nil { updateFlippers() }
        physicsWorld.speed = isAttractMode ? 0 : 1
    }
}
#endif
