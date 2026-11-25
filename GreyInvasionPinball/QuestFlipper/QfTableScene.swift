// Pinball Lab Table 09 (Quest & Flipper): the Haunted Forest region table. Milestone 1 v1 = the whole layout in grey
// box, playable:
//   - the lower table (Neon Labyrinth's cell kit: CHOMP!'s real-scale flippers and flipper model, slings, inlanes,
//     outlanes, the inlane speed limit), the shooter lane with CHOMP!'s plunger and a one-way launch gate;
//   - the Old Well (a catch goes by subway to the left inlane), the Graveyard orbit with its spinner, the Hollow Log
//     scoop, the Treant's clearing (three bark drops in front of the trunk), the Old Road ramp's solid low end, the
//     East lantern and the forest island's solid block;
//   - drains cost HP from the run (QfRunState), not balls: zero HP ends the game. Hits on the trunk and the lantern
//     show their damage (impact speed × the run's ball strength); the trunk only takes damage once all the bark is down.
// M1 v2: the Old Road is a real ramp (QfRamp, CHOMP!'s ramp layer): up through the island, over the hook, down its wire
// into the right inlane. Felling the Treant lights the exit: then a made Old Road rides into the Forest Gate and the visit
// ends ("You Escaped").
// M1 v3: the monsters that fight back. Three wisps drift on their glade loops (moving toys, one hit each, 5 gold); a
// ghost fades in at one of the two haunts between the shot paths and can only be hit while it's visible (20 HP, 10
// gold). Wisps, ghosts and the Treant all count toward the exit (3 to open the Forest Gate).
// M1 v4: a drifting ghost crosses the lower table every so often; the ball passes through it, and a touch while it's
// visible deals bonus damage (15 HP, 10 gold, a defeat). During the Treant fight (any bark down, or the Treant hurt)
// roots rise on the right sling's top: a slow ball is grabbed for a second; a fast hit knocks them back for 8 s.
// Geometry: QfForestLayout.swift (generated from tools/qf_layout.py, checked by qf_checks.py / qf_sim.py).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class QfTableScene: SKScene, RendererHostedScene {
    private enum Control { case left, right, plunger }

    /// A ball moved along a path by the scene (collisions and gravity off), then let go with a set velocity.
    private struct Ride {
        let ball: QfBall
        let path: [CGPoint]
        let cumulative: [CGFloat]
        var s: CGFloat = 0
        let speed: CGFloat
        let release: CGVector
        /// Hidden while riding (a subway under the table).
        let hidden: Bool
        /// Into the Forest Gate: the ball leaves the table at the end and the visit ends.
        var exits = false
        var total: CGFloat { cumulative.last ?? 0 }
    }

    /// A scoop: catches a floor ball whose path passes within `radius` of `center`, holds it, then lets it go.
    private struct Scoop {
        enum Kind { case well, log }
        let kind: Kind
        let center: CGPoint
        let radius: CGFloat
        var held: QfBall? = nil
        var releaseAt: TimeInterval = 0
        var ignored: QfBall? = nil
        var ignoreUntil: TimeInterval = 0
    }

    /// A wisp: a drifting toy on its glade loop (Cthulhu's moving-toy pattern: a heavy body whose velocity is set every
    /// frame so it lands exactly on its path, so a ball meeting it is batted with its real speed). One hit beats it.
    private struct Wisp {
        let node: SKShapeNode
        let center: CGPoint
        let amplitude: CGVector
        let period: Double
        var alive = true
        var respawnAt: TimeInterval = 0
        var hitPending = false

        func position(at t: TimeInterval) -> CGPoint {
            let a = 2 * Double.pi * t / period
            return CGPoint(x: center.x + amplitude.dx * CGFloat(sin(a)), y: center.y + amplitude.dy * CGFloat(sin(2 * a)))
        }
    }

    /// The ghost: fades in at a haunt, solid only while visible, fades out, comes back at the other haunt.
    private struct Ghost {
        enum Phase { case gone, fadingIn, visible, fadingOut }
        let node: SKShapeNode
        var haunt = 1
        var phase: Phase = .gone
        var phaseEnds: TimeInterval = 0
        var hp = QfMonsterHP.ghost
        var solid = false
        var lastHit: TimeInterval = -1
        var banished = false
    }

    /// One drop target of the Treant's bark.
    private struct Bark {
        let node: SKShapeNode
        let center: CGPoint
        var isDown = false
        var hitPending = false
    }

    private let game: QfGameState
    private let settings: GameSettings
    private let cameraRig = QfCameraRig()
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

    private var balls: [QfBall] = []
    private var rides: [Ride] = []
    private var slingshots: [QfSlingshot] = []
    private var leftFlipper: QfFlipper!
    private var rightFlipper: QfFlipper!
    /// T9 M1 v5 (Aaron's mark): the upper flipper on the forest block's top, under the glade. The right button.
    private var upperFlipper: QfFlipper!
    /// Its feed: a one-way diverter from the arch, raised while any wisp is alive (Aaron: "sometimes" = option 1).
    private var diverterNode: SKShapeNode!
    /// M1 v6 (Aaron: right-lane orbits "just go all the way around"; fix 1): the one-way orbit stop, up with the diverter.
    private var orbitStopNode: SKShapeNode!
    private var diverterUp = false
    private var plunger: SKShapeNode!
    private var isBuilt = false
    private let hitHaptic = Haptic(style: .medium)

    // Targets (placeholders until the fights): the trunk and the East lantern, a short cooldown and a flash each.
    private var targets: [(node: SKShapeNode, name: String)] = []
    private var targetLastHit: [String: TimeInterval] = [:]
    private var targetFlashUntil: [String: TimeInterval] = [:]
    private var bark: [Bark] = []
    private var barkDownAt: TimeInterval?
    private var treantHP = QfMonsterHP.treant
    private var scoops: [Scoop] = []
    private var spinnerFlash: SKShapeNode?
    private var digSpins: CGFloat = 0
    private var lastSpinAt: TimeInterval = 0
    private var hpLostLast = 0
    private var ramps: [QfRamp] = []
    private var oldRoad: QfRamp!
    /// Monsters defeated this visit, and whether the exit (the Forest Gate on the Old Road) is lit.
    private var defeats = 0
    private var exitLit = false
    private var forestGate: SKShapeNode!
    private var wisps: [Wisp] = []
    // T9 M1 v7: the Lantern Witch. She hides in one of three lanterns: 0 the Old Well, 1 the stump, 2 the East lantern.
    private struct Witch {
        var active = false
        var hp = QfMonsterHP.witch
        var lantern = 0
        var moveAt: TimeInterval = 0
        var lastHit: TimeInterval = -10
        var banishPending = false
        var fleeing = false                                    // the next move follows a hit

    }
    private static let lanternNames = ["OLD WELL", "STUMP", "EAST LANTERN"]
    private var witch = Witch()
    private var witchStartAt: TimeInterval?
    private var witchMarker: SKShapeNode!
    private var lanternLamps: [SKShapeNode] = []
    private var gravestone: SKShapeNode!
    private var graveUp = false
    private var graveWanted = false
    private var graveHits = 0
    private var graveLastHit: TimeInterval = -10
    private var graveSinkPending = false
    private var graveDownUntil: TimeInterval = 0
    // The drifting ghost (no physics body: touches are found by distance, the ball passes through).
    private var drifter: SKShapeNode!
    private var drifterStart: TimeInterval = 0
    private var drifterLeftToRight = true
    private var drifterActive = false
    private var drifterHP = QfMonsterHP.drifter
    private var drifterLastTouch: TimeInterval = -1
    // The roots (a pop-up on the right sling's top during the Treant fight).
    private var roots: SKShapeNode!
    private var rootsUp = false
    private var rootsDownUntil: TimeInterval = 0
    private var rootsKnockPending = false
    private var rootsHeld: QfBall?
    private var rootsReleaseAt: TimeInterval = 0
    private var rootsIgnored: QfBall?
    private var rootsIgnoreUntil: TimeInterval = 0
    static let rootsColor = SKColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1)
    private var ghost: Ghost!
    static let ghostColor = SKColor(red: 0.80, green: 0.90, blue: 0.95, alpha: 1)
    #if DEBUG
    /// DEBUG `-questRampProbe`: balls fired up the Old Road's mouth at rising speeds; prints what each one does.
    private var probeSpeeds: [CGFloat] = []
    private var probeNextAt: TimeInterval = 0
    private var probeSpeed: CGFloat = 0
    #endif

    // Plunger and input
    private var plungerStartY: CGFloat = 0
    private var plungerPull: CGFloat = 0
    private var activeTouches: [UITouch: Control] = [:]
    private let nudge = Nudge()
    private var padLeft = false
    private var padRight = false
    private var padAArmed = false
    private var padPulling = false
    private var padPeakPull: CGFloat = 0
    private var padPullByA = false

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
    // silver for wires, gold for targets, a translucent green band for ramp plastic.
    static let wallColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
    static let floorColor = SKColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
    static let islandColor = SKColor(red: 0.07, green: 0.14, blue: 0.10, alpha: 1)
    static let kickColor = SKColor(red: 1.0, green: 0.60, blue: 0.24, alpha: 1)
    static let wireColor = SKColor(white: 0.78, alpha: 0.75)
    static let targetColor = SKColor(red: 1.0, green: 0.82, blue: 0.42, alpha: 1)
    static let barkColor = SKColor(red: 0.79, green: 0.54, blue: 0.29, alpha: 1)
    static let wispColor = SKColor(red: 0.50, green: 0.89, blue: 1.0, alpha: 1)
    static let labelColor = SKColor(white: 1, alpha: 0.35)
    static let buildTagText = "T9 M2 v2"

    init(game: QfGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: QfTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: QfTableLayout.gravity)
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

    /// The table menu is shown Top-Down; play uses the saved camera (Flying, Wide or Top-Down).
    private var effectiveCameraMode: CameraMode { isAttractMode ? .topDown : settings.cameraMode }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        typealias F = QfForestLayout
        addFloor()
        addWall(points: F.outerWall, friction: QfTableLayout.railFriction, restitution: QfTableLayout.railRestitution)
        addWall(points: F.rightWall)
        addWall(points: F.shooterLaneWall)
        for pts in [F.laneGuideLeft, F.laneGuideRight, F.outlaneWallLeft, F.outlaneWallRight,
                    F.outlanePostRailLeft, F.outlanePostRailRight, F.wellLowerRim, F.wellRoof, F.lanternBlock] {
            addWall(points: pts)
        }
        addWall(points: F.island, fill: Self.islandColor)
        for p in [F.laneGuidePostLeft, F.laneGuidePostRight, F.outlanePostLeft, F.outlanePostRight] {
            addPost(at: p, radius: F.laneGuidePostRadius)
        }
        for p in F.wellPosts { addPost(at: p, radius: F.wellPostRadius) }
        for p in F.laneMouthPosts + [F.orbitPost] { addPost(at: p, radius: F.postRadius) }

        for s in [F.slingLeft, F.slingRight] {
            let sling = QfSlingshot(top: s[0], corner: s[1], tip: s[2], artBaked: false,
                                    kickFrom: QfTableLayout.slingKickFrom, kickTo: QfTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = QfFlipper(side: .left, pivot: F.pivotLeft)
        rightFlipper = QfFlipper(side: .right, pivot: F.pivotRight)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)
        upperFlipper = QfFlipper(side: .right, pivot: F.upperFlipperPivot, length: F.upperFlipperLength,
                                 pivotRadius: F.upperFlipperPivotRadius, tipRadius: F.upperFlipperTipRadius)
        upperFlipper.attach(to: self)

        addPlunger()
        addLaunchGate()
        addOrbitStop()
        addDiverter()
        addTarget(name: "TRUNK", face: F.trunkFace)
        addTarget(name: "EAST LANTERN", face: F.lanternFace)
        addBark()
        scoops = [Scoop(kind: .well, center: F.wellHole, radius: F.wellCaptureRadius),
                  Scoop(kind: .log, center: F.logHole, radius: F.logCaptureRadius)]
        for s in scoops { addHole(at: s.center) }
        addSpinner()
        addOldRoad()
        addForestGate()
        addWisps()
        addGhost()
        addDrifter()
        addRoots()
        addWitchParts()
        let face = SKSpriteNode()
        face.position = CGPoint(x: QfForestLayout.centerX, y: 1056)     // bottom at 1014, just above the trunk plate
        face.zPosition = -16.5
        addChild(face)
        treantFace = face
        updateTreantFace()
        addAreaLabels()
    }

    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: QfForestLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = QfTableLayout.wallFriction,
                         restitution: CGFloat = QfTableLayout.wallRestitution,
                         fill: SKColor? = nil,
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
        node.fillColor = fill ?? .clear
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        let body = closed ? SKPhysicsBody(edgeLoopFrom: path) : SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = QfPhysicsCategory.wall
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    private func addPost(at p: CGPoint, radius r: CGFloat) {
        let post = SKShapeNode(circleOfRadius: r)
        post.position = p
        post.fillColor = SKColor(white: 0.85, alpha: 1)
        post.strokeColor = Self.wallColor
        post.lineWidth = 1.5
        post.zPosition = -19
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = QfTableLayout.postRestitution
        body.friction = 0.2
        body.categoryBitMask = QfPhysicsCategory.wall
        body.collisionBitMask = QfPhysicsCategory.ball
        post.physicsBody = body
        addChild(post)
    }

    private func addPlunger() {
        let size = QfTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = QfTableLayout.plungerRestPosition
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = QfPhysicsCategory.wall
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        plunger = node
    }

    /// The one-way flap at the top of the shooter lane: solid only for a ball above it (QfBall.launchGateSolid).
    private func addLaunchGate() {
        let (a, b) = QfForestLayout.launchGate
        let path = CGMutablePath()
        path.addLines(between: [a, b])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.kickColor
        node.lineWidth = 4
        node.lineCap = .round
        node.zPosition = -18.5
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = QfPhysicsCategory.launchGate
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    /// T9 M1 v5: the upper flipper's diverter, from the arch's right side down-left to just above its pivot. Solid per
    /// ball (QfBall.diverterSolid): only for a ball above it, and only while raised. An orbit coming down the arch rolls
    /// down it onto the upper flipper; lowered, orbits ride on past to the right lane.
    private func addDiverter() {
        let (a, b) = QfForestLayout.diverter
        let path = CGMutablePath()
        path.addLines(between: [a, b])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.kickColor
        node.lineWidth = 5
        node.lineCap = .round
        node.zPosition = -18.5
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = QfPhysicsCategory.diverter
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        diverterNode = node
        setDiverterUp(true)
    }

    /// M1 v6: a short flap hanging from the arch just right of the top. Solid per ball (QfBall.orbitStopSolid) only on
    /// its right side and only while raised: a ball riding the arch counterclockwise (up the right lane, or a plunge)
    /// stops and drops onto the diverter, then the upper flipper. Clockwise orbits (the Graveyard lane) pass it.
    private func addOrbitStop() {
        let (a, b) = QfForestLayout.orbitStop
        let path = CGMutablePath()
        path.addLines(between: [a, b])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.kickColor
        node.lineWidth = 5
        node.lineCap = .round
        node.zPosition = -18.5
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = QfPhysicsCategory.orbitStop
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        orbitStopNode = node
    }

    private func setDiverterUp(_ up: Bool) {
        guard up != diverterUp else { return }          // (starts false, so the first call draws it)
        diverterUp = up
        diverterNode.strokeColor = up ? Self.kickColor : SKColor(white: 0.45, alpha: 1)
        diverterNode.alpha = up ? 1 : 0.35
        diverterNode.lineWidth = up ? 5 : 2
        orbitStopNode.strokeColor = diverterNode.strokeColor
        orbitStopNode.alpha = diverterNode.alpha
        orbitStopNode.lineWidth = diverterNode.lineWidth
    }

    /// Which side of the diverter's line a point is on (true = above it, the glade side), and how far it is from the
    /// segment.
    private static func aboveDiverter(_ p: CGPoint) -> Bool {
        let (a, b) = QfForestLayout.diverter
        return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) < 0
    }

    /// The orbit stop's solid side: the side a point right of it (inside the arch) is on.
    private static let orbitStopSign: CGFloat = {
        let (a, b) = QfForestLayout.orbitStop
        let q = CGPoint(x: a.x + 60, y: a.y - 20)
        return (b.x - a.x) * (q.y - a.y) - (b.y - a.y) * (q.x - a.x) > 0 ? 1 : -1
    }()

    private static func rightOfOrbitStop(_ p: CGPoint) -> Bool {
        let (a, b) = QfForestLayout.orbitStop
        return ((b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)) * orbitStopSign > 0
    }

    private static func distance(_ p: CGPoint, toSegment s: (CGPoint, CGPoint)) -> CGFloat {
        let (a, b) = s
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let t = min(max(((p.x - a.x) * ab.dx + (p.y - a.y) * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy), 0), 1)
        return hypot(p.x - (a.x + t * ab.dx), p.y - (a.y + t * ab.dy))
    }

    private static func distanceToDiverter(_ p: CGPoint) -> CGFloat {
        let (a, b) = QfForestLayout.diverter
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let t = min(max(((p.x - a.x) * ab.dx + (p.y - a.y) * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy), 0), 1)
        return hypot(p.x - (a.x + t * ab.dx), p.y - (a.y + t * ab.dy))
    }

    /// A standup: a thick drawn face with an edge body (category target).
    private func addTarget(name: String, face: (CGPoint, CGPoint)) {
        let path = CGMutablePath()
        path.addLines(between: [face.0, face.1])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.targetColor
        node.lineWidth = 7
        node.lineCap = .round
        node.zPosition = -18
        let body = SKPhysicsBody(edgeFrom: face.0, to: face.1)
        body.restitution = QfTableLayout.wallRestitution
        body.friction = QfTableLayout.wallFriction
        body.categoryBitMask = QfPhysicsCategory.target
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        targets.append((node: node, name: name))
    }

    private func addBark() {
        for c in QfForestLayout.barkCenters {
            let node = SKShapeNode(rectOf: QfForestLayout.barkSize, cornerRadius: 2)
            node.position = c
            node.fillColor = Self.barkColor
            node.strokeColor = .clear
            node.zPosition = -18
            node.physicsBody = Self.barkBody()
            addChild(node)
            bark.append(Bark(node: node, center: c))
        }
    }

    private static func barkBody() -> SKPhysicsBody {
        let body = SKPhysicsBody(rectangleOf: QfForestLayout.barkSize)
        body.isDynamic = false
        body.restitution = QfTableLayout.wallRestitution
        body.friction = QfTableLayout.wallFriction
        body.categoryBitMask = QfPhysicsCategory.target
        body.collisionBitMask = QfPhysicsCategory.ball
        return body
    }

    private func addHole(at p: CGPoint) {
        let hole = SKShapeNode(circleOfRadius: 15)
        hole.position = p
        hole.fillColor = .black
        hole.strokeColor = Self.targetColor
        hole.lineWidth = 2
        hole.zPosition = -18.8
        addChild(hole)
    }

    private func addSpinner() {
        let (a, b) = QfForestLayout.spinnerLine
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: a.x + 3, y: a.y), CGPoint(x: b.x - 3, y: b.y)])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.kickColor
        node.lineWidth = 4
        node.zPosition = -18
        addChild(node)
        spinnerFlash = node
    }

    /// The Old Road (CHOMP!'s ramp class): its plastic climbs from the mouth up through the island (whose solid U is
    /// the low end for floor balls, so no U of its own here), hooks right over the glade, and its wire runs down the
    /// right lane into the right inlane.
    private func addOldRoad() {
        let ramp = QfRamp(path: QfTableLayout.oldRoadPath, apexDistance: QfForestLayout.rampApexDistance,
                          mouthHalfWidth: QfForestLayout.rampMouthHalfWidth,
                          halfWidth: QfForestLayout.rampChannelHalfWidth,
                          flareLength: 60, postLength: 0, lowLength: 0)
        addChild(ramp)
        ramps.append(ramp)
        oldRoad = ramp
    }

    /// The Forest Gate beside the Old Road's hook: dark until the exit lights, then a blinking gold ring.
    private func addForestGate() {
        let gate = SKShapeNode(circleOfRadius: 16)
        gate.position = QfForestLayout.forestGate
        gate.strokeColor = Self.targetColor.withAlphaComponent(0.35)
        gate.fillColor = SKColor(white: 0.05, alpha: 1)
        gate.lineWidth = 2
        gate.zPosition = 19                                     // under the Old Road's art (z 20–21), which crosses it
        addChild(gate)
        forestGate = gate
    }

    private func addWisps() {
        for w in QfForestLayout.wisps {
            let r = QfForestLayout.wispRadius
            let node = SKShapeNode(circleOfRadius: r)
            node.fillColor = Self.wispColor.withAlphaComponent(0.85)
            node.strokeColor = Self.wispColor
            node.glowWidth = 4
            node.lineWidth = 2
            node.zPosition = -17
            let body = SKPhysicsBody(circleOfRadius: r)
            body.isDynamic = true
            body.mass = 500
            body.affectedByGravity = false
            body.allowsRotation = false
            body.friction = 0
            body.restitution = 0.6
            body.linearDamping = 0
            body.categoryBitMask = QfPhysicsCategory.target
            body.collisionBitMask = QfPhysicsCategory.ball
            body.contactTestBitMask = 0
            node.physicsBody = body
            Self.hideShape(node)
            addSprite("qf_wisp", to: node, height: 34)
            let wisp = Wisp(node: node, center: w.0, amplitude: w.1, period: w.2)
            node.position = wisp.position(at: gameTime)
            addChild(node)
            wisps.append(wisp)
        }
    }

    // MARK: - Sprites (T9 M2 art round 1: SpriteCook picks in Assets.xcassets/QfArt)

    /// Adds a QfArt sprite to a node, drawn `height` pt tall (aspect kept), with nearest filtering.
    @discardableResult
    private func addSprite(_ name: String, to parent: SKNode, height: CGFloat, at p: CGPoint = .zero,
                           z: CGFloat = 0.1) -> SKSpriteNode {
        let tex = SKTexture(imageNamed: name)
        tex.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: tex)
        let size = tex.size()
        sprite.size = CGSize(width: height * size.width / max(size.height, 1), height: height)
        sprite.position = p
        sprite.zPosition = z
        parent.addChild(sprite)
        return sprite
    }

    /// A shape node whose drawing the sprite replaces (its body, position and alpha still drive the monster).
    private static func hideShape(_ node: SKShapeNode) {
        node.fillColor = .clear
        node.strokeColor = .clear
        node.glowWidth = 0
    }

    private var treantFace: SKSpriteNode!
    private var treantFaceName = ""

    /// The Treant's face over its trunk: calm, hurt (once damaged), felled (from its fall until the next one's bark rises).
    private func updateTreantFace() {
        let felled = witch.active || witchStartAt != nil || treantRegrowing
        let name = felled ? "qf_treant_felled" : (treantHP < QfMonsterHP.treant ? "qf_treant_hurt" : "qf_treant_face")
        guard name != treantFaceName else { return }
        treantFaceName = name
        let tex = SKTexture(imageNamed: name)
        tex.filteringMode = .nearest
        treantFace.texture = tex
        let size = tex.size()
        treantFace.size = CGSize(width: Self.treantFaceHeight * size.width / max(size.height, 1), height: Self.treantFaceHeight)
    }
    private static let treantFaceHeight: CGFloat = 84      // M2 v2: bigger (Aaron); grows out over the block's top
    /// From the Witch's banishing until the new Treant's bark rises (the face stays felled).
    private var treantRegrowing = false

    // MARK: - The Lantern Witch (T9 M1 v7)

    private static var lanternSpots: [CGPoint] {
        let F = QfForestLayout.self
        let (ta, tb) = F.trunkFace, (la, lb) = F.lanternFace
        return [CGPoint(x: F.wellHole.x, y: F.wellHole.y + 36),
                CGPoint(x: (ta.x + tb.x) / 2, y: (ta.y + tb.y) / 2 + 31),       // on the stump (over the felled face)
                CGPoint(x: (la.x + lb.x) / 2 - 22, y: (la.y + lb.y) / 2 + 24)]
    }
    static let witchColor = SKColor(red: 0.72, green: 0.35, blue: 1.0, alpha: 1)
    static let lampColor = SKColor(red: 1.0, green: 0.68, blue: 0.25, alpha: 1)

    private func addWitchParts() {
        for spot in Self.lanternSpots {
            let lamp = SKShapeNode(circleOfRadius: 8)
            lamp.position = spot
            lamp.fillColor = .clear
            lamp.strokeColor = Self.lampColor.withAlphaComponent(0.35)
            lamp.glowWidth = 6
            addSprite("qf_lantern", to: lamp, height: 26)
            lamp.zPosition = -16
            lamp.alpha = 0
            addChild(lamp)
            lanternLamps.append(lamp)
        }
        let marker = SKShapeNode(circleOfRadius: 20)
        marker.strokeColor = Self.witchColor
        marker.fillColor = Self.witchColor.withAlphaComponent(0.25)
        marker.lineWidth = 3
        marker.glowWidth = 6
        marker.zPosition = -15.5
        marker.alpha = 0
        addSprite("qf_witch", to: marker, height: 74, at: CGPoint(x: 0, y: 22), z: 0.2)      // M2 v2: bigger (Aaron)
        addChild(marker)
        witchMarker = marker
        // The gravestone: a pop-up in the centre (drawn only while it's down).
        let pts = Array(QfForestLayout.gravestone.dropLast())
        let path = CGMutablePath()
        path.addLines(between: pts)
        path.closeSubpath()
        let stone = SKShapeNode(path: path)
        stone.fillColor = SKColor(red: 0.42, green: 0.42, blue: 0.50, alpha: 1)
        stone.strokeColor = SKColor(red: 0.70, green: 0.70, blue: 0.80, alpha: 1)
        stone.lineWidth = 2
        stone.zPosition = -17
        stone.alpha = 0
        Self.hideShape(stone)
        addSprite("qf_gravestone", to: stone, height: 44, at: CGPoint(x: 300, y: 567.5))
        addChild(stone)
        gravestone = stone
    }

    private static func gravestoneBody() -> SKPhysicsBody {
        let path = CGMutablePath()
        path.addLines(between: Array(QfForestLayout.gravestone.dropLast()))
        path.closeSubpath()
        let body = SKPhysicsBody(polygonFrom: path)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.35
        body.categoryBitMask = QfPhysicsCategory.target
        body.collisionBitMask = QfPhysicsCategory.ball
        body.contactTestBitMask = QfPhysicsCategory.ball
        return body
    }

    /// Raises the gravestone unless a ball is where it would rise (then it tries again next frame).
    private func raiseGravestone() -> Bool {
        let r = QfTableLayout.ballRadius + 4
        if balls.contains(where: { $0.isOnFloor && $0.position.x > 284 - r && $0.position.x < 316 + r
                                   && $0.position.y > 548 - r && $0.position.y < 587 + r }) { return false }
        gravestone.physicsBody = Self.gravestoneBody()
        gravestone.removeAllActions()
        gravestone.run(.fadeIn(withDuration: 0.25))
        graveUp = true
        graveHits = 0
        return true
    }

    private func sinkGravestone() {
        gravestone.physicsBody = nil
        gravestone.removeAllActions()
        gravestone.run(.fadeAlpha(to: 0, duration: 0.3))
        graveUp = false
    }

    private func startWitch() {
        witch = Witch()
        witch.active = true
        witch.lantern = Int.random(in: 0..<3)
        witch.moveAt = gameTime + QfTableLayout.witchMoveEvery
        for lamp in lanternLamps { lamp.removeAllActions(); lamp.run(.fadeIn(withDuration: 0.4)) }
        placeWitchMarker()
        witchMarker.removeAllActions()
        witchMarker.alpha = 1
        witchMarker.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.45), .scale(to: 0.9, duration: 0.45)])),
                        withKey: "pulse")
        graveWanted = true
        graveDownUntil = gameTime + QfTableLayout.bannerSeconds   // review: after her banner, not over it
        barkDownAt = nil                                         // (the bark stays down through her fight)
        showBanner("THE LANTERN WITCH RISES")
        cameraRig.shake(strength: 3, duration: 0.3)
        updateStatus()
    }

    /// Ends her fight: banished (rewarded) or a new game (not).
    private func endWitch() {
        witch.active = false
        witch.banishPending = false
        witchStartAt = nil
        for lamp in lanternLamps { lamp.removeAllActions(); lamp.run(.fadeOut(withDuration: 0.4)) }
        witchMarker.removeAllActions()
        witchMarker.run(.fadeOut(withDuration: 0.3))
        graveWanted = false
        graveSinkPending = false
        if graveUp { sinkGravestone() }
    }

    private func placeWitchMarker() {
        witchMarker.position = Self.lanternSpots[witch.lantern]
        Effects.burst(in: self, at: witchMarker.position, color: Self.witchColor, count: 10, speed: 120,
                      lifetime: 0.35, size: 0.25)
    }

    private func moveWitch(_ now: TimeInterval, quiet: Bool = false) {
        let others = [0, 1, 2].filter { $0 != witch.lantern }
        witch.lantern = others.randomElement() ?? 0
        witch.moveAt = now + QfTableLayout.witchMoveEvery
        placeWitchMarker()
        if !quiet { showBanner("THE WITCH FLITS TO THE \(Self.lanternNames[witch.lantern])") }
        updateStatus()
    }

    /// A lantern was hit (or the well caught a ball). Her lantern takes damage; an empty one tells where she is.
    private func witchLanternHit(_ lantern: Int, damage: Int) {
        guard witch.active, !witch.banishPending, gameTime - witch.lastHit > 0.3 else { return }
        witch.lastHit = gameTime
        guard lantern == witch.lantern else {
            showBanner("EMPTY LANTERN · SHE'S IN THE \(Self.lanternNames[witch.lantern])")
            return
        }
        witch.hp = max(0, witch.hp - damage)
        game.add(QfPoints.target * 2)
        hitHaptic.impactOccurred(intensity: 1)
        Effects.burst(in: self, at: witchMarker.position, color: Self.witchColor, count: 16, speed: 220,
                      lifetime: 0.4, size: 0.3)
        if witch.hp == 0 {
            witch.banishPending = true                         // banished in update()
        } else {
            showBanner("WITCH −\(damage) · \(witch.hp) HP LEFT")
            witch.moveAt = gameTime + QfTableLayout.witchFleeAfterHit
            witch.fleeing = true
        }
        updateStatus()
    }

    /// Every frame: her start, her moves, her banishing, and the gravestone (body changes here only).
    private func updateWitch(_ now: TimeInterval) {
        if game.isGameOver {                                   // review: she stops when the visit ends
            if witch.active || witchStartAt != nil { endWitch() }
            return
        }
        if let start = witchStartAt, now >= start {
            witchStartAt = nil
            startWitch()
        }
        if graveSinkPending {
            graveSinkPending = false
            sinkGravestone()
            graveDownUntil = now + QfTableLayout.gravestoneDownFor
            showBanner("THE GRAVESTONE SINKS · THE STUMP IS OPEN")
        }
        if graveWanted, !graveUp, now >= graveDownUntil {
            if raiseGravestone(), witch.active { showBanner("THE GRAVESTONE RISES") }
        }
        guard witch.active else { return }
        if witch.banishPending {
            endWitch()
            showBanner("LANTERN WITCH BANISHED · +\(QfGold.witch) GOLD")
            game.add(QfPoints.treantFelled * 2)
            game.run.gold += QfGold.witch
            cameraRig.shake(strength: 7, duration: 0.6)
            monsterDefeated()
            barkDownAt = now - QfTableLayout.barkRegrow + 1.5          // a new Treant: its bark rises in 1.5 s
            treantRegrowing = true
            return
        }
        if now >= witch.moveAt {
            moveWitch(now, quiet: witch.fleeing)
            witch.fleeing = false
        }
    }

    private func addDrifter() {
        let node = SKShapeNode(circleOfRadius: QfTableLayout.drifterRadius)
        node.fillColor = Self.ghostColor.withAlphaComponent(0.45)
        node.strokeColor = Self.ghostColor
        node.lineWidth = 1.5
        node.glowWidth = 3
        node.zPosition = 12                                   // over the floor ball: it passes through
        node.alpha = 0
        Self.hideShape(node)
        addSprite("qf_ghost", to: node, height: 54).alpha = 0.65
        addChild(node)
        drifter = node
        drifterStart = gameTime + QfTableLayout.drifterPause / 2
    }

    private func addRoots() {
        let node = SKShapeNode(circleOfRadius: QfForestLayout.rootsRadius)
        node.position = QfForestLayout.roots
        node.fillColor = Self.rootsColor
        node.strokeColor = SKColor(red: 0.70, green: 0.50, blue: 0.30, alpha: 1)
        node.lineWidth = 2
        node.zPosition = -17
        node.alpha = 0
        Self.hideShape(node)
        addSprite("qf_roots", to: node, height: 34)
        let body = SKPhysicsBody(circleOfRadius: QfForestLayout.rootsRadius)
        body.isDynamic = false
        body.restitution = 0.2
        body.friction = 0.4
        body.categoryBitMask = QfPhysicsCategory.none
        body.collisionBitMask = QfPhysicsCategory.none
        node.physicsBody = body
        addChild(node)
        roots = node
    }

    private func addGhost() {
        let r = QfForestLayout.ghostRadius
        let node = SKShapeNode(circleOfRadius: r)
        node.fillColor = Self.ghostColor.withAlphaComponent(0.85)
        node.strokeColor = .white
        node.lineWidth = 2
        node.zPosition = -17
        node.alpha = 0
        node.position = QfForestLayout.ghostHaunts[1]
        Self.hideShape(node)
        addSprite("qf_ghost", to: node, height: 54)
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = 0.4
        body.friction = 0.1
        body.categoryBitMask = QfPhysicsCategory.none
        body.collisionBitMask = QfPhysicsCategory.none
        node.physicsBody = body
        addChild(node)
        ghost = Ghost(node: node, phaseEnds: gameTime + 2)
    }

    private func addAreaLabels() {
        typealias F = QfForestLayout
        let items: [(String, CGPoint)] = [
            ("OLD WELL", CGPoint(x: 78, y: 690)), ("GRAVEYARD", CGPoint(x: 46, y: 1000)),
            ("HOLLOW LOG", CGPoint(x: F.logHole.x, y: 960)),
            ("OLD ROAD", CGPoint(x: F.rampCenterX, y: 940)), ("WITCH'S GLADE", CGPoint(x: 318, y: 1290)),
            ("FOREST GATE", CGPoint(x: F.forestGate.x - 4, y: F.forestGate.y + 26)),
        ]
        for (text, p) in items {
            let label = SKLabelNode(text: text)
            label.fontName = "Menlo-Bold"
            label.fontSize = text == "GRAVEYARD" ? 8 : 11
            label.fontColor = Self.labelColor
            label.verticalAlignmentMode = .center
            label.position = p
            label.zPosition = 17
            if text == "GRAVEYARD" { label.zRotation = .pi / 2 }
            addChild(label)
        }
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
        let text = "\(fps)\(Self.buildTagText) · \(speed) · treant \(treantHP) · dig \(Int(digSpins)) · beaten \(defeats)"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: QfBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func removeBall(_ ball: QfBall) {
        if rootsHeld === ball { rootsHeld = nil }
        rides.removeAll(where: { $0.ball === ball })
        for i in scoops.indices where scoops[i].held === ball { scoops[i].held = nil }
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
    }

    private func removeAllBalls() {
        rootsHeld = nil
        rides.removeAll()
        for i in scoops.indices { scoops[i].held = nil; scoops[i].ignored = nil }
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
    }

    private func placeBallOnPlunger() {
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // a tilt ends here
        let r = QfTableLayout.ballRadius
        let ball = QfBall(at: CGPoint(x: QfTableLayout.laneCenterX, y: QfTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
    }

    private func isOnPlunger(_ ball: QfBall) -> Bool {
        ball.isOnFloor && ball.position.x > QfForestLayout.laneWallX
            && ball.position.y < QfTableLayout.plungerRestTop + QfTableLayout.ballRadius * 3
    }

    private var plungerBall: QfBall? { balls.first(where: { isOnPlunger($0) }) }
    private var isBallOnPlunger: Bool { plungerBall != nil }

    /// Snaps the plunger back without a launch; a ball resting on the pulled plunger goes back on top of it (review:
    /// it would otherwise end up inside the plunger's body and be pushed through the lane floor).
    private func resetPlungerKeepingBall() {
        if plungerPull > 0, let b = plungerBall {
            b.position.y = QfTableLayout.plungerRestTop + QfTableLayout.ballRadius + 2
            b.physicsBody?.velocity = .zero
        }
        plungerPull = 0
        plunger?.position = QfTableLayout.plungerRestPosition
    }

    private func releasePlunger() {
        let power = plungerPull < 4 ? QfTableLayout.tapLaunchPower : plungerPull / QfTableLayout.plungerMaxPull
        if let body = plungerBall?.physicsBody {
            let speed = QfTableLayout.minLaunchSpeed
                + pow(power, QfTableLayout.plungePowerExponent) * (QfTableLayout.maxLaunchSpeed - QfTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
            sfx(.launch)
        }
        plunger.run(.move(to: QfTableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    /// Puts a ball on a scripted ride (collisions and gravity off) from where it is along `path`.
    private func startRide(_ ball: QfBall, path: [CGPoint], speed: CGFloat, release: CGVector, hidden: Bool,
                           exits: Bool = false) {
        ball.setLayer(.ride)
        ball.physicsBody?.velocity = .zero
        if hidden { ball.alpha = 0 }
        var cumulative: [CGFloat] = [0]
        for i in 1..<max(path.count, 1) {
            cumulative.append(cumulative[i - 1] + hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y))
        }
        rides.append(Ride(ball: ball, path: path, cumulative: cumulative, speed: speed, release: release, hidden: hidden,
                          exits: exits))
    }

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
            if ride.s >= ride.total { finished.append(i) }
        }
        for i in finished.reversed() {
            let ride = rides.remove(at: i)
            if ride.exits {
                leaveForest(ride.ball)
                continue
            }
            ride.ball.alpha = 1
            ride.ball.rampHeight = 0
            ride.ball.setLayer(.floor)
            ride.ball.physicsBody?.velocity = ride.release
            ride.ball.previousPosition = ride.ball.position
        }
    }

    func newGame() {
        fpsLow = 0
        isAttractMode = false
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        targetLastHit = [:]
        treantHP = QfMonsterHP.treant
        digSpins = 0
        defeats = 0
        removeAction(forKey: "gateBanner")
        setExitLit(false)
        resetMonsters()
        resetDrifterAndRoots()
        endWitch()
        graveDownUntil = 0
        raiseBark()
        game.reset()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-questWitch") {     // test her fight without the Treant
            for i in bark.indices { bark[i].hitPending = true }
            witchStartAt = gameTime + 2
        }
        #endif
        updateStatus()
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        plungerPull = 0
        plunger.position = QfTableLayout.plungerRestPosition
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + QfTableLayout.bannerSeconds
    }

    private func updateStatus() {
        if witch.active {
            game.status = "LANTERN WITCH · \(witch.hp) HP · IN THE \(Self.lanternNames[witch.lantern])"
                + (exitLit ? " · EXIT LIT" : "")
        } else if exitLit {
            game.status = "EXIT LIT · THE OLD ROAD LEAVES THE FOREST"
        } else {
            game.status = "MONSTERS \(defeats)/\(QfTableLayout.exitAfterDefeats) · THEN THE OLD ROAD OUT"
        }
    }

    private func sfx(_ s: MonSound) {
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView, !isAttractMode else { return }
        for touch in touches {
            let p = touch.location(in: view)   // screen points: the camera moves the table
            if isBallOnPlunger, !activeTouches.values.contains(.plunger), isInPlungerZone(p, of: view) {
                activeTouches[touch] = .plunger
                plungerStartY = p.y
                plungerPull = 0
            } else {
                activeTouches[touch] = p.x < view.bounds.midX ? .left : .right
                nudge.swipeBegan(touch, at: p)
            }
        }
        updateFlippers()
    }

    private func isInPlungerZone(_ p: CGPoint, of view: UIView) -> Bool {
        let b = view.bounds
        return p.x > b.width * QfTableLayout.plungerZoneMinX && p.y > b.height * QfTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView else { return }
        for touch in touches {
            let p = touch.location(in: view)
            switch activeTouches[touch] {
            case .plunger:
                let dragged = (p.y - plungerStartY) * cameraRig.node.yScale
                plungerPull = min(max(dragged, 0), QfTableLayout.plungerMaxPull)
                plunger.position.y = QfTableLayout.plungerRestPosition.y - plungerPull
            case .left, .right:
                if let direction = nudge.swipeMoved(touch, to: p) { applyNudge(direction) }
            case nil:
                break
            }
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
            if activeTouches.removeValue(forKey: touch) == .plunger {
                releasePlunger()
            }
        }
        updateFlippers()
    }

    private func updateFlippers() {
        var left = activeTouches.values.contains(.left) || padLeft
        var right = activeTouches.values.contains(.right) || padRight
        if nudge.tilted { left = false; right = false }      // tilted: dead flippers until the next ball
        if left && !leftFlipper.isPressed { sfx(.flipper) }
        if right && !rightFlipper.isPressed { sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
        upperFlipper.isPressed = right
    }

    private func applyNudge(_ direction: Nudge.Direction) {
        guard !isAttractMode, !game.isGameOver else { return }
        let free = balls.filter { $0.isOnFloor && !isOnPlunger($0) }
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
            updateFlippers()
        }
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        resetPlungerKeepingBall()
        if leftFlipper != nil { updateFlippers() }
    }

    /// Pausing (Table 06's fix): a flipper finger still down stays held, so a cradled ball is still cradled after
    /// resume. The plunger pull and the gamepad let go.
    private func releaseNonTouchControls() {
        for (touch, kind) in activeTouches where kind == .plunger { activeTouches.removeValue(forKey: touch) }
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        resetPlungerKeepingBall()
        if leftFlipper != nil { updateFlippers() }
    }

    /// Game controller (CHOMP!'s): shoulders/triggers flip, A held or the right stick pulled down works the plunger.
    private func updateGamepad() {
        let pad = LabGamepad.shared.state
        if !pad.aDown { padAArmed = true }
        if let direction = pad.nudge { applyNudge(direction) }
        if pad.left != padLeft || pad.right != padRight {
            padLeft = pad.left
            padRight = pad.right
            updateFlippers()
        }
        let pull = padAArmed ? pad.pull : 0
        let touchPlunger = activeTouches.values.contains(.plunger)
        if isBallOnPlunger, !touchPlunger, pull > 0 || (padAArmed && pad.aDown) {
            padPulling = true
            if pad.aDown { padPullByA = true }
            padPeakPull = max(padPeakPull, pull)
            plungerPull = pull * QfTableLayout.plungerMaxPull
            plunger.position.y = QfTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            let peak = padPeakPull * QfTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = QfTableLayout.plungerRestPosition
                }
            }
        }
    }

    // MARK: - Game loop

    override func update(_ realTime: TimeInterval) {
        let step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
        lastRealTime = realTime
        gameTime += step
        let now = gameTime
        if isAttractMode { return }

        let dt = CGFloat(step)
        lastStep = dt
        #if DEBUG
        updateRampProbe(now)
        #endif
        updateGamepad()
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        upperFlipper.step(dt: dt)
        updateRides(dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        governInlanes()
        updateScoops(now)
        updateBark(now)
        updateWisps(now, dt: step)
        setDiverterUp(wisps.contains { $0.alive })
        updateGhost(now)
        updateDrifter(now)
        updateRoots(now)
        updateWitch(now)
        updateTreantFace()
        let onPlunger = isBallOnPlunger
        if game.ballOnPlunger != onPlunger { game.ballOnPlunger = onPlunger }

        for t in targets {
            if let until = targetFlashUntil[t.name], now >= until {
                targetFlashUntil[t.name] = nil
                t.node.strokeColor = Self.targetColor
            }
        }
        if now - lastSpinAt > 0.15 { spinnerFlash?.strokeColor = Self.kickColor }

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // A drain costs HP (the run's drain damage less armour); zero HP ends the game.
        let drained = balls.filter { $0.isOnFloor && $0.position.y < QfForestLayout.drainLineY }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            cameraRig.shake(strength: 3, duration: 0.25)
            sfx(.drain)
            if balls.isEmpty, nextBallAt == nil, !game.isGameOver {
                let lost = game.ballDrained()
                showBanner(game.isGameOver ? "THE FOREST TAKES YOU" : "−\(lost) HP · \(game.hp) LEFT")
                if !game.isGameOver { nextBallAt = now + 0.8 }
            }
        }

        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            placeBallOnPlunger()
        }
    }

    /// A floor ball within reach of a flipper swinging up this frame belongs to the flipper model for the physics step.
    private func handBallsToSwingingFlippers() {
        guard QfTableLayout.flipperModel else { return }
        let r = QfTableLayout.ballRadius
        for ball in balls where ball.isOnFloor {
            for f in [leftFlipper!, rightFlipper!, upperFlipper!] where f.isSwingingUp && f.reaches(ball.position, ballRadius: r) {
                ball.flipperGhostSteps = max(ball.flipperGhostSteps, 1)
            }
        }
    }

    /// Hot inlane feeds: a ball rolling down an inlane is held to InlaneGovernor.maxSpeed so a held flipper can trap it.
    private func governInlanes() {
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody,
                  let v = InlaneGovernor.limited(body.velocity, at: ball.position,
                                                 leftGuide: QfTableLayout.governorGuide,
                                                 mirrorSum: QfTableLayout.mirrorSum) else { continue }
            body.velocity = v
        }
    }

    // MARK: - Scoops

    /// Catches by path (the scoop rule): a floor ball whose path this frame passed within the radius. The Old Well's
    /// cavity is a catch zone too (no ball rests behind its rim).
    private func catchInScoops(_ ball: QfBall, from p0: CGPoint, to p: CGPoint) {
        guard ball.isOnFloor else { return }
        for i in scoops.indices where scoops[i].held == nil {
            if scoops[i].ignored === ball, gameTime < scoops[i].ignoreUntil { continue }
            let c = scoops[i].center
            let dx = p.x - p0.x, dy = p.y - p0.y
            let t = max(0, min(1, ((c.x - p0.x) * dx + (c.y - p0.y) * dy) / max(dx * dx + dy * dy, 0.001)))
            let q = CGPoint(x: p0.x + dx * t, y: p0.y + dy * t)
            let inWell = scoops[i].kind == .well && Self.inside(p, QfForestLayout.wellCavity)
            guard hypot(q.x - c.x, q.y - c.y) < scoops[i].radius || inWell else { continue }
            scoops[i].held = ball
            scoops[i].releaseAt = gameTime + QfTableLayout.scoopHold
            ball.setLayer(.ride)
            ball.position = c
            ball.physicsBody?.velocity = .zero
            game.add(QfPoints.scoop)
            sfx(.scoopIn)
            hitHaptic.impactOccurred(intensity: 0.8)
            switch scoops[i].kind {
            case .well:
                if witch.active {
                    witchLanternHit(0, damage: max(1, Int((QfTableLayout.witchWellDamage * game.run.ballStrength).rounded())))
                } else {
                    showBanner("OLD WELL · SEARCHED")
                }
            case .log: showBanner("HOLLOW LOG · SEARCHED")
            }
            return
        }
    }

    private func updateScoops(_ now: TimeInterval) {
        for i in scoops.indices {
            guard let ball = scoops[i].held else { continue }
            ball.position = scoops[i].center
            ball.physicsBody?.velocity = .zero
            guard now >= scoops[i].releaseAt else { continue }
            scoops[i].held = nil
            scoops[i].ignored = ball
            scoops[i].ignoreUntil = now + QfTableLayout.scoopRecapture
            sfx(.scoopOut)
            switch scoops[i].kind {
            case .log:
                ball.setLayer(.floor)
                ball.physicsBody?.velocity = QfForestLayout.logEject
                ball.previousPosition = ball.position
            case .well:
                // The subway under the table to the left inlane; it comes out heading straight down.
                let release = QfForestLayout.inlaneReleaseLeft
                startRide(ball, path: [scoops[i].center, release], speed: QfTableLayout.subwaySpeed,
                          release: CGVector(dx: 0, dy: -QfTableLayout.inlaneReleaseSpeed), hidden: true)
            }
        }
    }

    // MARK: - The Treant's bark

    private func updateBark(_ now: TimeInterval) {
        var dropped = false
        for i in bark.indices where bark[i].hitPending {
            bark[i].hitPending = false
            guard !bark[i].isDown else { continue }
            bark[i].isDown = true
            bark[i].node.physicsBody = nil
            bark[i].node.alpha = 0.18
            dropped = true
        }
        if dropped, bark.allSatisfy({ $0.isDown }) {
            barkDownAt = now
            showBanner("BARK BROKEN · HIT THE TRUNK")
            game.add(QfPoints.bark)
        }
        if let down = barkDownAt, now - down >= QfTableLayout.barkRegrow {
            if raiseBark() { showBanner("THE BARK GROWS BACK") }
        }
    }

    /// Raises every fallen bark drop unless a ball sits where it would rise (then it tries again next frame).
    @discardableResult
    private func raiseBark() -> Bool {
        let r = QfTableLayout.ballRadius + 2
        let half = CGSize(width: QfForestLayout.barkSize.width / 2 + r, height: QfForestLayout.barkSize.height / 2 + r)
        for b in bark where b.isDown {
            if balls.contains(where: { abs($0.position.x - b.center.x) < half.width && abs($0.position.y - b.center.y) < half.height }) {
                return false
            }
        }
        for i in bark.indices {
            bark[i].hitPending = false
            if bark[i].isDown {
                bark[i].isDown = false
                bark[i].node.physicsBody = Self.barkBody()
                bark[i].node.alpha = 1
            }
        }
        barkDownAt = nil
        treantRegrowing = false
        return true
    }

    // MARK: - Wisps and the ghost

    private func resetMonsters() {
        for i in wisps.indices {
            wisps[i].hitPending = false
            reviveWisp(i)                                      // every wisp back on its loop (review: after the menu)
        }
        ghost.node.removeAllActions()
        ghost.node.alpha = 0
        setGhostSolid(false)
        ghost.phase = .gone
        ghost.phaseEnds = gameTime + 2
        ghost.hp = QfMonsterHP.ghost
        ghost.banished = false
    }

    private func reviveWisp(_ i: Int) {
        wisps[i].alive = true
        wisps[i].hitPending = false
        let node = wisps[i].node
        node.position = wisps[i].position(at: gameTime)
        node.physicsBody?.velocity = .zero
        node.physicsBody?.categoryBitMask = QfPhysicsCategory.target
        node.physicsBody?.collisionBitMask = QfPhysicsCategory.ball
        node.removeAllActions()
        node.run(.fadeIn(withDuration: 0.4))
    }

    /// Every frame: live wisps follow their loops; a hit wisp bursts (gold, a defeat); a beaten one drifts back later,
    /// once no ball is where it would appear.
    private func updateWisps(_ now: TimeInterval, dt: TimeInterval) {
        for i in wisps.indices {
            let node = wisps[i].node
            guard let body = node.physicsBody else { continue }
            if wisps[i].hitPending {
                wisps[i].hitPending = false
                wisps[i].alive = false
                wisps[i].respawnAt = now + QfTableLayout.wispRespawn
                body.categoryBitMask = QfPhysicsCategory.none
                body.collisionBitMask = QfPhysicsCategory.none
                body.velocity = .zero
                Effects.burst(in: self, at: node.position, color: Self.wispColor, count: 14, speed: 200,
                              lifetime: 0.4, size: 0.3)
                node.removeAllActions()
                node.run(.fadeOut(withDuration: 0.15))
                game.add(QfPoints.target)
                game.run.gold += QfGold.wisp
                sfx(.standup)
                showBanner("WISP · +\(QfGold.wisp) GOLD")
                monsterDefeated()
                continue
            }
            if !wisps[i].alive {
                body.velocity = .zero
                guard now >= wisps[i].respawnAt else { continue }
                let p = wisps[i].position(at: now)
                if ballNear(p, clear: QfForestLayout.wispRadius + QfTableLayout.ballRadius + 10) { continue }
                reviveWisp(i)
                continue
            }
            let target = wisps[i].position(at: now + dt)
            let d = CGFloat(max(dt, 1.0 / 240))
            body.velocity = CGVector(dx: (target.x - node.position.x) / d, dy: (target.y - node.position.y) / d)
        }
    }

    private func ballNear(_ p: CGPoint, clear: CGFloat) -> Bool {
        balls.contains { $0.isOnFloor && hypot($0.position.x - p.x, $0.position.y - p.y) < clear }
    }

    /// The ghost (body changes in update() only). Solid while visible; the Lantern ball (run.lightBall) also hits it
    /// while it fades.
    private func setGhostSolid(_ solid: Bool) {
        ghost.solid = solid
        ghost.node.physicsBody?.categoryBitMask = solid ? QfPhysicsCategory.target : QfPhysicsCategory.none
        ghost.node.physicsBody?.collisionBitMask = solid ? QfPhysicsCategory.ball : QfPhysicsCategory.none
    }

    private func updateGhost(_ now: TimeInterval) {
        let node = ghost.node
        if ghost.banished, ghost.phase != .gone {
            setGhostSolid(false)
            Effects.burst(in: self, at: node.position, color: Self.ghostColor, count: 16, speed: 180,
                          lifetime: 0.5, size: 0.3)
            node.removeAllActions()
            node.run(.fadeOut(withDuration: 0.25))
            game.run.gold += QfGold.ghost
            showBanner("GHOST BANISHED · +\(QfGold.ghost) GOLD")
            monsterDefeated()
            ghost.phase = .gone
            ghost.phaseEnds = now + QfTableLayout.ghostRespawn
            return
        }
        let light = game.run.lightBall
        guard now >= ghost.phaseEnds else { return }
        switch ghost.phase {
        case .gone:
            let next = 1 - ghost.haunt
            let p = QfForestLayout.ghostHaunts[next]
            // never appear on top of a ball: wait until the haunt is clear
            if ballNear(p, clear: QfForestLayout.ghostRadius + QfTableLayout.ballRadius + 6) { return }
            ghost.haunt = next
            ghost.hp = QfMonsterHP.ghost
            ghost.banished = false
            node.position = p
            node.removeAllActions()
            node.run(.fadeAlpha(to: 0.4, duration: QfTableLayout.ghostFade))
            ghost.phase = .fadingIn
            ghost.phaseEnds = now + QfTableLayout.ghostFade
            if light { setGhostSolid(true) }
        case .fadingIn:
            if ballNear(node.position, clear: QfForestLayout.ghostRadius + QfTableLayout.ballRadius + 1) { return }
            node.removeAllActions()
            node.run(.fadeAlpha(to: 1, duration: 0.12))
            setGhostSolid(true)
            ghost.phase = .visible
            ghost.phaseEnds = now + QfTableLayout.ghostVisible
        case .visible:
            node.removeAllActions()
            node.run(.fadeAlpha(to: 0.4, duration: 0.12))
            setGhostSolid(light)
            ghost.phase = .fadingOut
            ghost.phaseEnds = now + QfTableLayout.ghostFade
        case .fadingOut:
            node.removeAllActions()
            node.run(.fadeOut(withDuration: 0.2))
            setGhostSolid(false)
            ghost.phase = .gone
            ghost.phaseEnds = now + QfTableLayout.ghostGone
        }
    }

    // MARK: - The drifting ghost and the roots

    private func resetDrifterAndRoots() {
        drifterActive = false
        drifter.removeAllActions()
        drifter.alpha = 0
        drifterStart = gameTime + QfTableLayout.drifterPause / 2
        drifterHP = QfMonsterHP.drifter
        if let b = rootsHeld { b.setLayer(.floor) }
        rootsHeld = nil
        rootsIgnored = nil
        rootsIgnoreUntil = 0
        rootsKnockPending = false
        rootsDownUntil = 0
        setRootsUp(false)
    }

    private func drifterPosition(_ f: CGFloat) -> CGPoint {
        let ff = drifterLeftToRight ? f : 1 - f
        let x = QfTableLayout.drifterFromX + (QfTableLayout.drifterToX - QfTableLayout.drifterFromX) * ff
        let y = QfTableLayout.drifterBaseY + QfTableLayout.drifterAmplitude * sin(QfTableLayout.drifterWaves * .pi * ff)
        return CGPoint(x: x, y: y)
    }

    /// The drifting ghost: waits, fades in at one side, crosses, fades out at the other; sides alternate. A floor
    /// ball touching it while it's fully visible deals bonus damage; it has no body, so the ball passes through.
    private func updateDrifter(_ now: TimeInterval) {
        let cross = QfTableLayout.drifterCross, fade = QfTableLayout.drifterFade
        if !drifterActive {
            guard now >= drifterStart else { return }
            drifterActive = true
            drifterHP = QfMonsterHP.drifter
            drifter.position = drifterPosition(0)
            drifter.removeAllActions()
        }
        let t = now - drifterStart
        guard t < cross else {
            drifterActive = false
            drifterLeftToRight.toggle()
            drifterStart = now + QfTableLayout.drifterPause
            return
        }
        drifter.position = drifterPosition(CGFloat(t / cross))
        drifter.alpha = max(0, min(1, CGFloat(t / fade), CGFloat((cross - t) / fade)))   // on game time (review)
        guard t > fade, t < cross - fade, now - drifterLastTouch > 0.4 else { return }
        let reach = QfTableLayout.drifterRadius + QfTableLayout.ballRadius
        for ball in balls where ball.isOnFloor {
            guard hypot(ball.position.x - drifter.position.x, ball.position.y - drifter.position.y) < reach,
                  let v = ball.physicsBody?.velocity else { continue }
            drifterLastTouch = now
            let damage = QfDamage.of(impactSpeed: hypot(v.dx, v.dy) * QfTableLayout.drifterBonus,
                                     strength: game.run.ballStrength)
            drifterHP = max(0, drifterHP - damage)
            game.add(QfPoints.target)
            sfx(.standup)
            if drifterHP == 0 {
                Effects.burst(in: self, at: drifter.position, color: Self.ghostColor, count: 16, speed: 180,
                              lifetime: 0.5, size: 0.3)
                drifter.removeAllActions()
                drifter.run(.fadeOut(withDuration: 0.2))
                drifterActive = false
                drifterLeftToRight.toggle()
                drifterStart = now + QfTableLayout.drifterPause
                game.run.gold += QfGold.drifter
                showBanner("DRIFTING GHOST BANISHED · +\(QfGold.drifter) GOLD")
                monsterDefeated()
            } else {
                showBanner("DRIFTING GHOST −\(damage) · \(drifterHP) HP LEFT")
            }
            return
        }
    }

    /// The Treant fight: any bark down, or the Treant already hurt.
    private var treantFight: Bool {
        guard !witch.active, witchStartAt == nil else { return false }   // v7: not during the Witch's fight
        return bark.contains(where: { $0.isDown }) || treantHP < QfMonsterHP.treant
    }

    private func setRootsUp(_ up: Bool) {
        rootsUp = up
        roots.physicsBody?.categoryBitMask = up ? QfPhysicsCategory.target : QfPhysicsCategory.none
        roots.physicsBody?.collisionBitMask = up ? QfPhysicsCategory.ball : QfPhysicsCategory.none
        roots.removeAllActions()
        roots.run(up ? .fadeIn(withDuration: 0.3) : .fadeOut(withDuration: 0.3))
    }

    /// The roots (body changes here only): up during the Treant fight unless knocked back; a slow ball near them is
    /// grabbed (held on the ride layer) for a moment, then dropped.
    private func updateRoots(_ now: TimeInterval) {
        if let held = rootsHeld {
            held.physicsBody?.velocity = .zero
            if now >= rootsReleaseAt {
                rootsHeld = nil
                held.setLayer(.floor)
                // pushed off to its side so it can't balance on top of the roots (review)
                let side: CGFloat = held.position.x < QfForestLayout.roots.x ? -1 : 1
                held.physicsBody?.velocity = CGVector(dx: side * 110, dy: -120)
                held.previousPosition = held.position
                rootsIgnored = held
                rootsIgnoreUntil = now + QfTableLayout.rootsIgnore
            }
            return
        }
        if rootsKnockPending {
            rootsKnockPending = false
            if rootsUp {
                setRootsUp(false)
                rootsDownUntil = now + QfTableLayout.rootsKnockedBack
                game.add(QfPoints.target)
                sfx(.standup)
                showBanner("ROOTS KNOCKED BACK")
                return
            }
        }
        let want = treantFight && now >= rootsDownUntil && !game.isGameOver
        if want && !rootsUp {
            // never rise into a ball
            if !ballNear(QfForestLayout.roots, clear: QfForestLayout.rootsRadius + QfTableLayout.ballRadius + 6) {
                setRootsUp(true)
                showBanner("ROOTS RISE")
            }
        } else if !want && rootsUp {
            setRootsUp(false)
        }
        guard rootsUp else { return }
        let reach = QfForestLayout.rootsRadius + QfTableLayout.ballRadius + 6
        for ball in balls where ball.isOnFloor {
            if ball === rootsIgnored, now < rootsIgnoreUntil { continue }
            guard let v = ball.physicsBody?.velocity, hypot(v.dx, v.dy) < QfTableLayout.rootsGrabSpeed,
                  hypot(ball.position.x - QfForestLayout.roots.x, ball.position.y - QfForestLayout.roots.y) < reach
            else { continue }
            rootsHeld = ball
            rootsReleaseAt = now + QfTableLayout.rootsHold
            ball.setLayer(.ride)
            ball.physicsBody?.velocity = .zero
            hitHaptic.impactOccurred(intensity: 0.5)
            showBanner("THE ROOTS GRAB YOU")
            return
        }
    }

    // MARK: - The Old Road and the Forest Gate

    /// The ramps' switches, from the ball's move this frame (CHOMP!'s updateRampLayer): the entry puts a floor ball on
    /// the ramp (backward = it fell back out), the made switch just past the top scores it, the exit at the end of the
    /// wire puts it back on the floor. A ramp ball found far from its channel drops to the floor (the safety net).
    private func updateRampLayer(_ ball: QfBall, from p0: CGPoint, to p: CGPoint) {
        if ball.isOnFloor {
            if let ramp = ramps.first(where: { $0.entrySwitch.crossing(from: p0, to: p) == .forward
                                               && $0.distanceToCenterline(p) < $0.maxHalfWidth }) {
                ball.activeRamp = ramp
                ball.setLayer(.rampUp)
            }
            return
        }
        guard let ramp = ball.activeRamp else { ball.setLayer(.floor); return }
        switch ball.layer {
        case .floor, .ride:
            return
        case .rampUp:
            if ramp.entrySwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.floor)
                probeLog("BACK", p)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.rampDown)
                rampMade(ball, ramp)
                if ball.layer == .ride { return }              // into the Forest Gate
            }
        case .rampDown:
            if ramp.exitSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.floor)
                probeLog("EXIT", p, ball.physicsBody?.velocity)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.rampUp)
            }
        }
        if !ball.isOnFloor, ramp.distanceToCenterline(p) > ramp.maxHalfWidth + QfTableLayout.ballRadius + 12 {
            ball.setLayer(.floor)
        }
    }

    /// The Old Road made: with the exit lit the ball turns into the Forest Gate (the visit ends); otherwise it scores
    /// and rides the wire back to the right inlane.
    private func rampMade(_ ball: QfBall, _ ramp: QfRamp) {
        probeLog("MADE", ball.position, ball.physicsBody?.velocity)
        if exitLit, !game.isGameOver {
            ball.rampHeight = QfTableLayout.rampTopHeight
            startRide(ball, path: [ball.position, QfForestLayout.forestGate], speed: QfTableLayout.gateRideSpeed,
                      release: .zero, hidden: false, exits: true)
            showBanner("THE FOREST GATE")
            sfx(.scoopIn)
            hitHaptic.impactOccurred()
            return
        }
        game.add(QfPoints.ramp)
        showBanner("OLD ROAD")
        sfx(.ramp)
        hitHaptic.impactOccurred()
    }

    /// A monster beaten (the Treant, for now). Enough of them light the exit.
    private func monsterDefeated() {
        defeats += 1
        if !exitLit, defeats >= QfTableLayout.exitAfterDefeats {
            setExitLit(true)
            // after the defeat's own banner (review: TREANT FELLED was overwritten at once)
            run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.showBanner("THE FOREST GATE OPENS") }]),
                withKey: "gateBanner")
        }
        updateStatus()
    }

    private func setExitLit(_ lit: Bool) {
        exitLit = lit
        guard let gate = forestGate else { return }
        gate.removeAction(forKey: "blink")
        if lit {
            gate.strokeColor = Self.targetColor
            gate.fillColor = Self.targetColor.withAlphaComponent(0.25)
            gate.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])),
                     withKey: "blink")
        } else {
            gate.strokeColor = Self.targetColor.withAlphaComponent(0.35)
            gate.fillColor = SKColor(white: 0.05, alpha: 1)
            gate.alpha = 1
        }
    }

    /// The ball reached the Forest Gate: it leaves the table and the visit ends with the HP the player still has.
    private func leaveForest(_ ball: QfBall) {
        probeLog("GATE", ball.position)
        removeBall(ball)
        nextBallAt = nil
        game.leaveForest()
        showBanner("YOU LEAVE THE FOREST")
        cameraRig.shake(strength: 2, duration: 0.2)
    }

    // MARK: - DEBUG ramp probe

    func debugStartRampProbe() {
        #if DEBUG
        newGame()
        game.isRobot = true                                     // a probe never records a high score
        if ProcessInfo.processInfo.arguments.contains("-questExitLit") { setExitLit(true) }   // test the Forest Gate
        removeAllBalls()
        probeSpeeds = stride(from: CGFloat(600), through: 2000, by: 100).map { $0 }
        probeNextAt = gameTime + 0.5
        #endif
    }

    private func probeLog(_ what: String, _ p: CGPoint, _ v: CGVector? = nil) {
        #if DEBUG
        guard probeSpeed > 0 else { return }
        let sp = v.map { Int(hypot($0.dx, $0.dy)) } ?? 0
        print("RAMPPROBE \(Int(probeSpeed)) \(what) x \(Int(p.x)) y \(Int(p.y)) v \(sp) t \(String(format: "%.2f", gameTime - (probeNextAt - 3)))")
        #endif
    }

    #if DEBUG
    private func updateRampProbe(_ now: TimeInterval) {
        guard probeSpeed > 0 || !probeSpeeds.isEmpty, now >= probeNextAt else { return }
        removeAllBalls()
        guard !probeSpeeds.isEmpty else { probeSpeed = 0; print("RAMPPROBE DONE"); return }
        probeSpeed = probeSpeeds.removeFirst()
        let ball = QfBall(at: CGPoint(x: QfForestLayout.rampCenterX, y: QfForestLayout.rampMouthY - 20))
        addChild(ball)
        balls.append(ball)
        ball.physicsBody?.velocity = CGVector(dx: 0, dy: probeSpeed)
        probeNextAt = now + 3
    }
    #endif

    // MARK: - Physics frame

    /// The solid blocks (closed outlines): a floor ball whose centre ends up inside one is put back just outside its
    /// nearest edge, with any velocity into that edge removed (CHOMP! M3 v13).
    private let solidBlocks: [[CGPoint]] = [QfForestLayout.island]

    private static func inside(_ p: CGPoint, _ closed: [CGPoint]) -> Bool {
        let poly = closed.first == closed.last ? Array(closed.dropLast()) : closed
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    private func keepOutOfSolids(_ ball: QfBall) {
        let p = ball.position
        for closed in solidBlocks where closed.count > 3 && Self.inside(p, closed) {
            let poly = Array(closed.dropLast())
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
            let r = QfTableLayout.ballRadius + 0.5
            ball.position = CGPoint(x: q.x + n.dx * r, y: q.y + n.dy * r)
            if let body = ball.physicsBody {
                let v = body.velocity
                let vn = v.dx * n.dx + v.dy * n.dy
                if vn < 0 { body.velocity = CGVector(dx: v.dx - vn * n.dx, dy: v.dy - vn * n.dy) }
            }
            return
        }
    }

    /// Which side of the launch gate's line a point is on (> 0 = above it, the playfield side).
    private static func aboveLaunchGate(_ p: CGPoint) -> Bool {
        let (a, b) = QfForestLayout.launchGate
        return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) > 0
    }

    override func didSimulatePhysics() {
        typealias F = QfForestLayout
        let r = QfTableLayout.ballRadius
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if ball.flipperGhostSteps > 0 { ball.flipperGhostSteps -= 1 }
            let p0 = ball.previousPosition
            if ball.layer != .ride {
                updateRampLayer(ball, from: p0, to: ball.position)
                if ball.layer != .ride {                       // (the Forest Gate ride keeps the ramp's height)
                    ball.rampHeight = ball.isOnFloor ? 0 : (ball.activeRamp?.height(at: ball.position) ?? 0)
                }
                if !ball.isOnFloor, ball.layer != .ride {
                    let v = body.velocity
                    let speed = hypot(v.dx, v.dy)
                    if speed > QfTableLayout.maxBallSpeed {
                        body.velocity = CGVector(dx: v.dx * QfTableLayout.maxBallSpeed / speed,
                                                 dy: v.dy * QfTableLayout.maxBallSpeed / speed)
                    }
                }
            }
            if ball.isOnFloor {
                leftFlipper.solveSwing(ball, ballRadius: r)
                rightFlipper.solveSwing(ball, ballRadius: r)
                upperFlipper.solveSwing(ball, ballRadius: r)
                keepOutOfSolids(ball)
                let v = body.velocity
                let speed = hypot(v.dx, v.dy)
                if speed > QfTableLayout.maxBallSpeed {
                    let scale = QfTableLayout.maxBallSpeed / speed
                    body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
                }
                let p = ball.position
                // The launch gate is solid only for a ball on its playfield side (a plunge passes up through it).
                ball.setLaunchGateSolid(p.x > F.laneWallX - 40 && Self.aboveLaunchGate(p))
                // The upper flipper's diverter: solid only while raised, for a ball above it. A ball turns it solid
                // only once clear of the line (so a ball rising up through it is never caught inside it), then keeps
                // it while it stays above.
                if !diverterUp || !Self.aboveDiverter(p) {
                    ball.setDiverterSolid(false)
                } else if !ball.diverterSolid, Self.distanceToDiverter(p) > r + 1 {
                    ball.setDiverterSolid(true)
                }
                // The orbit stop: the same rule, on its right side (counterclockwise orbits and plunges meet it).
                if !diverterUp || !Self.rightOfOrbitStop(p) {
                    ball.setOrbitStopSolid(false)
                } else if !ball.orbitStopSolid, Self.distance(p, toSegment: QfForestLayout.orbitStop) > r + 1 {
                    ball.setOrbitStopSolid(true)
                }
                // The Graveyard spinner: every crossing digs (spins from the ball's speed).
                let (sa, sb) = F.spinnerLine
                if (p0.y - sa.y) * (p.y - sa.y) < 0, p.x > sa.x, p.x < sb.x {
                    let spins = max(1, hypot(v.dx, v.dy) / 250)
                    digSpins += spins
                    lastSpinAt = gameTime
                    spinnerFlash?.strokeColor = .white
                    game.add(QfPoints.spin * Int(spins.rounded()))
                    sfx(.spinner)
                    showBanner("GRAVEYARD · DIG \(Int(digSpins))")
                }
                // The Graveyard orbit made: crossing the line along the top of the arch going right.
                let (oa, ob) = F.orbitMadeLine
                if p0.x < oa.x, p.x >= oa.x, p.y > oa.y, p.y < ob.y, p.y > 1270 {
                    game.add(QfPoints.orbit)
                    sfx(.orbit)
                    showBanner("GRAVEYARD ORBIT")
                }
                catchInScoops(ball, from: p0, to: p)
            }
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

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        let ballish = QfPhysicsCategory.ball | QfPhysicsCategory.ghostBall
        if a.categoryBitMask & ballish != 0 {
            ballBody = a; other = b
        } else if b.categoryBitMask & ballish != 0 {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? QfBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case QfPhysicsCategory.slingshot:
            if let sling = node.parent as? QfSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                game.add(QfPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case QfPhysicsCategory.target:
            let impact = hypot(ballNode.previousVelocity.dx, ballNode.previousVelocity.dy)
            let damage = QfDamage.of(impactSpeed: impact, strength: game.run.ballStrength)
            if node === roots {
                if impact >= QfTableLayout.rootsGrabSpeed { rootsKnockPending = true }   // sinks in update()
                break
            }
            if let i = wisps.firstIndex(where: { $0.node === node }) {
                guard wisps[i].alive, !wisps[i].hitPending else { break }
                wisps[i].hitPending = true                    // beaten in update()
                break
            }
            if node === ghost.node {
                guard ghost.solid, !ghost.banished, gameTime - ghost.lastHit > 0.15 else { break }
                ghost.lastHit = gameTime
                ghost.hp = max(0, ghost.hp - damage)
                sfx(.standup)
                hitHaptic.impactOccurred(intensity: 0.8)
                game.add(QfPoints.target)
                if ghost.hp == 0 {
                    ghost.banished = true                      // vanishes in update()
                } else {
                    showBanner("GHOST −\(damage) · \(ghost.hp) HP LEFT")
                }
                break
            }
            if node === gravestone {
                guard graveUp, !graveSinkPending, gameTime - graveLastHit > 0.15 else { break }
                graveLastHit = gameTime
                graveHits += 1
                sfx(.standup)
                hitHaptic.impactOccurred(intensity: 0.7)
                game.add(QfPoints.target)
                if graveHits >= QfTableLayout.gravestoneHits {
                    graveSinkPending = true                    // sinks in update()
                } else {
                    showBanner("GRAVESTONE \(graveHits)/\(QfTableLayout.gravestoneHits)")
                }
                break
            }
            if let i = bark.firstIndex(where: { $0.node === node }) {
                guard !bark[i].isDown, !bark[i].hitPending else { break }
                bark[i].hitPending = true                     // drops in update()
                game.add(QfPoints.target)
                sfx(.standup)
                hitHaptic.impactOccurred(intensity: 0.7)
                break
            }
            guard let t = targets.first(where: { $0.node === node }) else { break }
            if let last = targetLastHit[t.name], gameTime - last < 0.15 { break }
            targetLastHit[t.name] = gameTime
            sfx(.standup)
            hitHaptic.impactOccurred(intensity: 0.7)
            t.node.strokeColor = .white                     // back to its colour in update()
            targetFlashUntil[t.name] = gameTime + 0.12
            if t.name == "TRUNK", witch.active || witchStartAt != nil {
                witchLanternHit(1, damage: damage)
                break
            }
            if t.name == "EAST LANTERN", witch.active {
                witchLanternHit(2, damage: damage)
                break
            }
            if t.name == "TRUNK" {
                guard bark.allSatisfy({ $0.isDown }) else {
                    showBanner("THE BARK HOLDS")
                    break
                }
                treantHP = max(0, treantHP - damage)
                game.add(QfPoints.target)
                if treantHP == 0 {
                    showBanner("TREANT FELLED")
                    game.add(QfPoints.treantFelled)
                    game.run.gold += QfGold.treant
                    monsterDefeated()
                    cameraRig.shake(strength: 6, duration: 0.5)
                    treantHP = QfMonsterHP.treant              // the next Treant, after the Witch
                    barkDownAt = nil                            // v7: the bark stays down through the Witch's fight
                    witchStartAt = gameTime + QfTableLayout.witchStartDelay
                } else {
                    showBanner("TRUNK −\(damage) · \(treantHP) HP LEFT")
                }
                updateStatus()
            } else {
                game.add(QfPoints.target)
                showBanner("\(t.name) · HIT \(damage)")
            }
        default:
            break
        }
    }
}

extension QfTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}
