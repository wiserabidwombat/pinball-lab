// Pinball Lab Table 07 (CHOMP! The Terror of Calamity Island): the table scene. Milestone 1 = grey box of the lower
// table, from Table 06's milestone-1 scene (e023ac3): walls, flippers, slings, lane switches, plunger and one-way
// launch gate, the three camera modes, 3 balls and the ball save. New: the inner tube save in the left outlane (the
// action button arms it), the inlane up-posts, the right outlane save (post + one-way gate) and the pier mini-flipper
// pocket on the right (feed lane, mini-lane switch, beach-ball bumper, buoy target). The upper table is open floor
// until milestones 2–3. Monsoon's sounds stand in until the table's own (juice milestone).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class ChompTableScene: SKScene, RendererHostedScene {
    private enum Control { case left, right, plunger }

    private let game: ChompGameState
    private let settings: GameSettings
    private let cameraRig = ChompCameraRig()
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
    /// M3 v19b (Aaron: "lows 102 fps, 13 ms; the ball doesn't move super smooth, very subtle steps"): what the frames
    /// look like — jitter (the spread of frame-to-frame gaps), missed frames (a gap over 10.8 ms) and our CPU time per
    /// frame (update → physics → didSimulatePhysics → camera; render encoding is not included), each over 0.5 s.
    private var fpsGapSum: Double = 0
    private var fpsGapSq: Double = 0
    private var fpsMisses = 0
    private var cpuStart: CFTimeInterval = 0
    private var cpuSum: Double = 0
    private var cpuWorst: Double = 0
    private var cpuFrames = 0
    private var frameStatsShown = ""
    private var lastStep: CGFloat = 0

    private var balls: [ChompBall] = []
    private var servedBall: ChompBall?
    private var slingshots: [ChompSlingshot] = []
    private var leftFlipper: ChompFlipper!
    private var rightFlipper: ChompFlipper!
    private var plunger: SKShapeNode!
    private var launchGateFlap: SKNode?
    private var launchGateClosedAngle: CGFloat = 0
    private var isBuilt = false
    private let hitHaptic = Haptic(style: .medium)
    private let bigHaptic = Haptic(style: .heavy)

    // Milestone 1: lane switches, the inner tube, the up-posts, the outlane save and the pier pocket.
    private var rollovers: [ChompRollover] = []
    private var miniLane: ChompRollover?
    private var miniFlipper: ChompFlipper!
    private var bumper: ChompBumper?
    private var buoy: SKShapeNode?
    private var buoyLastHit: TimeInterval = -10
    /// The inner tube (the old kickback): lit = qualified; armed for a moment by the action button.
    private var kickbackLit = true
    private var kickbackLamp: SKShapeNode?
    private var innerTubeArmedUntil: TimeInterval = -1
    private var innerTubeReadyAt: TimeInterval = 0
    /// The inlane up-posts (left, right). Raised in update(), never inside a contact callback.
    private var upPosts: [SKShapeNode] = []
    private var upPostUp = [false, false]
    private var upPostRaisePending = [false, false]
    private var upPostDropAt: [TimeInterval?] = [nil, nil]
    private var upPostsArmed = false
    private var laneOffAt: [ObjectIdentifier: TimeInterval] = [:]
    // Milestone 2 v1: the left side.
    private var spinner: ChompSpinner?
    /// M2 v5: the wave ramp (more ramps join this list later).
    private var ramps: [ChompRamp] = []
    /// M3 v1: the center ramp (rampMade tells the ramps apart).
    private weak var centerRamp: ChompRamp?
    /// M3 v10: the right ramp.
    private weak var rightRamp: ChompRamp?
    /// M3 v4: the boat's captive ball.
    private var boat: ChompCaptiveBall?
    /// M3 v9: the fishing reel's disc.
    private var reel: ChompReel?
    private var fin: ChompFin?
    private var chumBucket: SKNode?
    private var sharkTargets: [SKShapeNode] = []
    private var sharkDown = [false, false, false]
    private var sharkRelightPending = false
    private var chumLastHit: TimeInterval = -10
    private var finHitPending = false
    #if DEBUG
    /// M2 v6: the Shot Lab robot (shared ShotLab, Table 06's host pattern) and its own clock.
    fileprivate var shotLab: ShotLab?
    fileprivate var shotLabTime: TimeInterval = 0
    /// M2 v8: the flipper fan probe (`-shotlab chomp -shotlab-scenario fanprobe`).
    fileprivate var fanProbe: ChompFanProbe?
    /// M2 v15: the pier probe's clock (nil when it isn't running).
    fileprivate var pierProbeT: Double?
    fileprivate var dropProbeT: Double?          // M3 v13: the drop probe
    fileprivate var catchProbe = false           // M4 v2: the drop probe's clock runs the catch probe
    /// M4 v1: the Play Lab (shared, PlayLab.swift; Table 06's host pattern): the run, when its next game starts.
    private var playLab: PlayLab?
    private var playLabNextAt: TimeInterval?
    private var playLabStarting = false
    /// The Play Lab's watchdog: where each ball was last seen moving, and when.
    private var watchSpots: [ObjectIdentifier: (CGPoint, TimeInterval)] = [:]
    #endif
    /// M4 v1: the Play Lab robot's buttons (always false outside it).
    private var robotLeft = false
    private var robotRight = false
    private var lastSpinSound: TimeInterval = 0
    private var quickshotLanes: [ChompRollover] = []
    private var bankTargets: [SKShapeNode] = []
    private var bankDown = [false, false, false]
    private var bankRelightPending = false
    // The ball save: once per player ball, on the plunger and for 10 s after launch.
    private var ballSaveUsed = false
    private var launchedAt: TimeInterval?
    /// M5 v1: the skill shot is lit from the serve until the first switch after the launch.
    private var skillShotLive = false
    /// M5 v1: the Fish Phone target flashing for skill shot 3, and the one the latest bank hit struck.
    private var skillTarget: Int?
    private var bankHitIndex: Int?
    /// M5 v1: seconds the skill shots added to this ball's save.
    private var ballSaveBonus: TimeInterval = 0
    /// M5 v1b: the served ball's highest point since the launch, while the skill shot is lit.
    private var skillPeakY: CGFloat = 0
    /// M5 v2c: a skill shot / cameo banner holds the line this long; plain shot-name banners don't cover it.
    private var bannerHoldUntil: TimeInterval = 0
    /// M5 v2: Kevin's cameos (rules in ChompCameos) and the shot lamps that show them.
    let cameos = ChompCameos()
    /// M5 v3: tourists and beach closures (Mayor Meltdown hurry-ups).
    let beaches = ChompBeaches()
    /// M5 v4: the Stink Line, the flamingos and Kevin Multiball.
    let kevin = ChompKevin()
    private var mbLaunchesPending = 0
    private var mbNextLaunchAt: TimeInterval = 0
    private var mbSaveUntil: TimeInterval = -1
    /// M5 v5: flip-lock — in a multiball, ACTION while a ball sits on the raised pier flipper keeps it raised 20 s.
    private var flipLockUntil: TimeInterval = -1
    private var flipLockUsed = false
    #if DEBUG
    private var pierCatchUntil: TimeInterval = -1           // M5 v5c: the robot holding right for a flip-lock catch
    #endif
    private var flipLocked: Bool { flipLockUntil > gameTime }
    static let flipLockSeconds: TimeInterval = 20
    static let flipLockSpot = CGPoint(x: 490, y: 562)       // where a held ball rests on the raised pier flipper
    private var touristDots: [ChompShot: [SKShapeNode]] = [:]
    private var sharkHitAt: [TimeInterval] = [-1, -1, -1]
    private var shotLamps: [ChompShot: SKShapeNode] = [:]
    private var wasOnPlunger = false

    // Input
    private var activeTouches: [UITouch: Control] = [:]
    private let nudge = Nudge()
    private var plungerStartY: CGFloat = 0
    private var plungerPull: CGFloat = 0
    // Game controller (LabGamepad): the flippers it holds, whether it's pulling the plunger and how far at most,
    // and whether A has been let go since the last Play / Resume (so that press doesn't also pull the plunger).
    private var padLeft = false
    private var padRight = false
    private var padPulling = false
    private var padPeakPull: CGFloat = 0
    private var padPullByA = false
    private var padAArmed = false

    // Game clock: advances by the clamped frame time only, so pauses and hitches never eat timers.
    private var lastRealTime: TimeInterval?
    private var gameTime: TimeInterval = 0
    private var nextBallAt: TimeInterval?
    private var bannerClearAt: TimeInterval?

    /// The menu: physics stopped, whole-table camera, touches ignored.
    var isAttractMode = false {
        didSet {
            guard isAttractMode != oldValue else { return }
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode { releaseAllControls() }
            #if DEBUG
            if isAttractMode { shotLab = nil }         // Menu stops the Shot Lab
            if isAttractMode { stopPlayLab(saving: true) }      // and the Play Lab (saving the games so far)
            #endif
            refreshCamera()
        }
    }

    var isGamePaused = false {
        didSet {
            if isGamePaused { releaseNonTouchControls() } else { padAArmed = false }
            isPaused = isGamePaused
            lastRealTime = nil
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    // Grey-box colours: cool steel-blue lines on deep-space navy.
    static let wallColor = SKColor(red: 0.62, green: 0.71, blue: 1.0, alpha: 1)
    static let floorColor = SKColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 1)
    /// M3 v20: the plastic between the play area and the playfield's edge (dark blue, as the real plastics are blue).
    static let plasticColor = SKColor(red: 0.09, green: 0.13, blue: 0.30, alpha: 1)
    /// Orange = anything one-way (the skill's grey-box colours).
    static let oneWayColor = SKColor(red: 1.0, green: 0.62, blue: 0.24, alpha: 1)
    /// The build tag shown on screen (one place: the live readout used to carry its own stale copy, "T7 M2 v15").
    static let buildTagText = "T7 M5 v5d"
    static let bankLitColor = SKColor(red: 1.0, green: 0.84, blue: 0.36, alpha: 1)
    static let bankDarkColor = SKColor(red: 0.35, green: 0.30, blue: 0.16, alpha: 1)
    static let lampOnColor = SKColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1)
    static let lampOffColor = SKColor(red: 0.14, green: 0.28, blue: 0.18, alpha: 0.9)

    init(game: ChompGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: ChompTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: ChompTableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        buildTable()
        addBuildTag()
        placeBallOnPlunger()
        refreshCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        refreshCamera()
    }

    private var effectiveCameraMode: CameraMode {
        #if DEBUG
        if shotLab != nil { return .topDown }
        #endif
        return isAttractMode ? .topDown : settings.cameraMode
    }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addFloor()
        addWall(points: ChompTableLayout.outerWall,
                friction: ChompTableLayout.railFriction, restitution: ChompTableLayout.railRestitution)
        addWall(points: ChompTableLayout.leftLaneGuide)
        addWall(points: ChompTableLayout.leftOutlaneWall)
        addWall(points: ChompTableLayout.leftOutlanePostRail)
        addWall(points: ChompTableLayout.rightOutlanePostRail)
        addWall(points: ChompTableLayout.rightOutlaneWall)
        addWall(points: ChompTableLayout.rightApron)
        addWall(points: ChompTableLayout.rightLaneGuide)           // M2 v16: solid (the save gate is gone, as on the real table)
        addWall(points: ChompTableLayout.pierPlastic)              // M2 v2: the pier flipper hangs from this block

        for s in [ChompTableLayout.leftSling, ChompTableLayout.rightSling] {
            let sling = ChompSlingshot(top: s.top, corner: s.corner, tip: s.tip, artBaked: false,
                                      kickFrom: ChompTableLayout.slingKickFrom, kickTo: ChompTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = ChompFlipper(side: .left, pivot: ChompTableLayout.leftFlipperPivot)
        rightFlipper = ChompFlipper(side: .right, pivot: ChompTableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)
        // The pier mini-flipper: on the right button, same angles and speeds as the main flippers, shorter.
        miniFlipper = ChompFlipper(side: .right, pivot: ChompTableLayout.miniFlipperPivot,
                                   length: ChompTableLayout.miniFlipperLength,
                                   pivotRadius: ChompTableLayout.miniFlipperPivotRadius,
                                   tipRadius: ChompTableLayout.miniFlipperTipRadius,
                                   restAngle: ChompTableLayout.miniFlipperRestAngle,
                                   travel: ChompTableLayout.miniFlipperTravel)
        miniFlipper.attach(to: self)

        for (i, x) in ChompTableLayout.laneRolloverXs.enumerated() {
            let lane = ChompRollover(letter: ChompTableLayout.laneLetters[i], x: x)
            addChild(lane)
            rollovers.append(lane)
        }
        let mini = ChompRollover(letter: "", x: ChompTableLayout.miniLaneSwitch.x, y: ChompTableLayout.miniLaneSwitch.y)
        addChild(mini)
        miniLane = mini
        let b = ChompBumper(at: ChompTableLayout.bumperCenter)
        addChild(b)
        bumper = b
        do {                                                         // M4 v4b: the plunge pin
            let r = ChompTableLayout.plungePinRadius
            let pin = SKShapeNode(circleOfRadius: r)
            pin.position = ChompTableLayout.plungePin
            pin.fillColor = SKColor(white: 0.6, alpha: 1)
            pin.strokeColor = SKColor(white: 1, alpha: 0.6)
            pin.lineWidth = 1
            pin.zPosition = 1
            let body = SKPhysicsBody(circleOfRadius: r)
            body.isDynamic = false
            body.restitution = ChompTableLayout.outlaneSavePostRestitution
            body.friction = 0.2
            body.categoryBitMask = ChompPhysicsCategory.wall
            body.collisionBitMask = ChompPhysicsCategory.ball
            pin.physicsBody = body
            addChild(pin)
        }
        addWall(points: ChompTableLayout.barrelEnd)                  // M4 v4c: the yellow barrel's end
        addBuoy()
        addKickbackLamp()
        addUpPosts()
        addOutlaneSave()
        addLeftSide()
        addWaveRamp()
        addCenterRamp()
        addBoat()
        addRightRamp()
        addPlunger()
        // addLaunchGate()   // M4 v4: no gate — the plunge comes out beside the bumper and rides the right lane up
        if ChompTableLayout.flattenStaticArt { flattenStaticArt() }
    }

    /// M3 v19c: paints the shapes that never change into two sprites (ChompFlatten): the floor level — the floor, the
    /// walls (wall-category edge bodies) and the ramps' floor-level parts (shadows, feet, plastic edges) — under
    /// everything that moves or lights, and the ramps' raised parts (plastics, wires, ties, posts) at z 15: over floor
    /// balls (10), targets and the bumper, under the ramp labels (20–21), the reel (22) and ramp balls (29–30), as before.
    private func flattenStaticArt() {
        var low: [SKShapeNode] = []
        var high: [SKShapeNode] = []
        for case let n as SKShapeNode in children where n !== plunger {
            if n.zPosition <= -20 { low.append(n); continue }          // the outline (M3 v20) and the floor
            if let body = n.physicsBody, body.categoryBitMask == ChompPhysicsCategory.wall,
               !upPosts.contains(where: { $0 === n }), n.zPosition <= -5 {
                low.append(n)
            }
        }
        for ramp in ramps {
            ramp.enumerateChildNodes(withName: ".//*") { node, _ in
                guard let shape = node as? SKShapeNode else { return }
                var z = shape.zPosition
                var p = shape.parent
                while let cur = p, cur !== self { z += cur.zPosition; p = cur.parent }
                if z <= -5 { low.append(shape) } else if z >= 11 { high.append(shape) }
            }
        }
        let pixels = min(max(UITraitCollection.current.displayScale, 2), 3)
        ChompFlatten.flatten(low, in: self, spriteZ: -19.5, pixelsPerPoint: pixels)
        ChompFlatten.flatten(high, in: self, spriteZ: 15, pixelsPerPoint: pixels)
    }

    /// The playfield floor inside the outer wall.
    private func addFloor() {
        // M3 v20: the real playfield's outline (square top at y 1305); outside our play area it reads as plastic.
        let outline = SKShapeNode(rect: ChompTableLayout.playfieldRect)
        outline.fillColor = Self.plasticColor
        outline.strokeColor = Self.wallColor
        outline.lineWidth = 3
        outline.zPosition = -20.5
        addChild(outline)
        let path = CGMutablePath()
        path.addLines(between: ChompTableLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = ChompTableLayout.wallFriction,
                         restitution: CGFloat = ChompTableLayout.wallRestitution,
                         z: CGFloat = -19.5) {
        // M3 v13b: a closed outline (last point = first) is built as an edge LOOP. As an edge chain its closing segment
        // went missing in physics (the drop probe: a ball rested where the reel block's top edge should be; balls got
        // inside the pier block and the reel block through their closing edges).
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
        body.categoryBitMask = ChompPhysicsCategory.wall
        body.collisionBitMask = ChompPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
    }

    /// The kickback lamp over the left outlane: lit = the next ball down that outlane is fired back up.
    private func addKickbackLamp() {
        let lamp = SKShapeNode(circleOfRadius: 7)
        lamp.position = ChompTableLayout.kickbackLamp
        lamp.fillColor = Self.lampOnColor
        lamp.strokeColor = SKColor(white: 1, alpha: 0.3)
        lamp.lineWidth = 1
        lamp.zPosition = -18
        addChild(lamp)
        kickbackLamp = lamp
    }

    private func setKickbackLit(_ lit: Bool) {
        kickbackLit = lit
        kickbackLamp?.fillColor = lit ? Self.lampOnColor : Self.lampOffColor
    }

    /// The inlane up-posts. Down: a dim cap flush with the floor and no body. Up: a grey post (a wall) the ball sits on.
    private func addUpPosts() {
        for p in [ChompTableLayout.leftUpPost, ChompTableLayout.rightUpPost] {
            let post = SKShapeNode(circleOfRadius: ChompTableLayout.upPostRadius)
            post.position = p
            post.zPosition = 1
            post.lineWidth = 1.5
            addChild(post)
            upPosts.append(post)
        }
        for i in upPosts.indices { setUpPost(i, up: false) }
    }

    private func setUpPost(_ i: Int, up: Bool) {
        let post = upPosts[i]
        upPostUp[i] = up
        upPostDropAt[i] = nil
        post.removeAllActions()
        if up {
            let body = SKPhysicsBody(circleOfRadius: ChompTableLayout.upPostRadius)
            body.isDynamic = false
            body.restitution = 0.1
            body.friction = 0.2
            body.categoryBitMask = ChompPhysicsCategory.wall
            body.collisionBitMask = ChompPhysicsCategory.ball
            post.physicsBody = body
            post.fillColor = SKColor(white: 0.78, alpha: 1)
            post.strokeColor = SKColor(white: 1, alpha: 0.9)
            post.setScale(0.4)
            post.run(.scale(to: 1, duration: 0.08))
        } else {
            // Wake a ball resting on the post, or it can stay asleep in mid-air once the body under it is gone.
            let clear = ChompTableLayout.upPostRadius + ChompTableLayout.ballRadius + 2
            for b in balls where hypot(b.position.x - post.position.x, b.position.y - post.position.y) < clear {
                b.physicsBody?.isResting = false
            }
            post.physicsBody = nil
            post.fillColor = SKColor(white: 0.25, alpha: 1)
            post.strokeColor = SKColor(white: 1, alpha: 0.2)
            post.setScale(1)
        }
    }

    /// The right outlane save: a rubber post on the outer wall. M2 v16: the one-way gate in the right lane guide is gone
    /// (the real table has only the post, which saves a ball with a nudge).
    private func addOutlaneSave() {
        let r = ChompTableLayout.outlaneSavePostRadius
        let post = SKShapeNode(circleOfRadius: r)
        post.position = ChompTableLayout.outlaneSavePost
        post.fillColor = SKColor(white: 0.6, alpha: 1)
        post.strokeColor = SKColor(white: 1, alpha: 0.6)
        post.lineWidth = 1
        post.zPosition = 1
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = ChompTableLayout.outlaneSavePostRestitution
        body.friction = 0.2
        body.categoryBitMask = ChompPhysicsCategory.wall
        body.collisionBitMask = ChompPhysicsCategory.ball
        post.physicsBody = body
        addChild(post)

    }

    /// Milestone 2 v1: the harpoon lane, the left loop and tongue, the spinner, the quickshot gate and rollovers, the
    /// harpoon lane's deflector and the Fish Phone 3-bank.
    private func addLeftSide() {
        addWall(points: ChompTableLayout.harpoonInner)
        addWall(points: ChompTableLayout.tongue)
        addWall(points: ChompTableLayout.loopRight)
        addWall(points: ChompTableLayout.harpoonDeflector)
        addWall(points: ChompTableLayout.bankBackboard)

        let g = ChompTableLayout.quickshotGate
        let gate = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: g.a)
        path.addLine(to: g.b)
        gate.path = path
        gate.strokeColor = Self.oneWayColor
        gate.lineWidth = 2
        gate.zPosition = -19
        let gb = SKPhysicsBody(edgeFrom: g.a, to: g.b)
        gb.friction = 0.05
        gb.restitution = 0.2
        gb.categoryBitMask = ChompPhysicsCategory.diverter
        gb.collisionBitMask = ChompPhysicsCategory.ball
        gate.physicsBody = gb
        addChild(gate)

        let s = ChompSpinner(from: ChompTableLayout.spinnerLine.a, to: ChompTableLayout.spinnerLine.b)
        addChild(s)
        spinner = s

        for p in ChompTableLayout.quickshotSwitches {
            let lane = ChompRollover(letter: "", x: p.x, y: p.y)
            addChild(lane)
            quickshotLanes.append(lane)
        }

        let size = ChompTableLayout.bankTargetSize
        for c in ChompTableLayout.bankCenters {
            let node = SKShapeNode(rectOf: size, cornerRadius: 2)
            node.position = c
            node.zRotation = (ChompTableLayout.bankNormalDegrees - 90) * .pi / 180   // the long side faces the normal
            node.strokeColor = SKColor(white: 1, alpha: 0.6)
            node.lineWidth = 1
            node.zPosition = 1
            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic = false
            body.restitution = 0.2
            body.friction = 0.2
            body.categoryBitMask = ChompPhysicsCategory.target
            body.collisionBitMask = ChompPhysicsCategory.ball
            body.contactTestBitMask = ChompPhysicsCategory.ball
            node.physicsBody = body
            addChild(node)
            bankTargets.append(node)
        }
        resetBank()
    }

    /// The Fish Phone bank's standups: lit = still to hit, dark = hit (M2 v1 placeholder until the fish finder rules).
    private func resetBank() {
        bankDown = [false, false, false]
        for t in bankTargets { t.fillColor = Self.bankLitColor }
    }

    /// The loop's switches and the spinner, from the ball's move this frame (after physics: velocities and score only).
    private func leftSideSwitches(_ ball: ChompBall, from p0: CGPoint, to p: CGPoint) {
        guard ball.isOnFloor, let body = ball.physicsBody else { return }
        let inLoop = p.x > ChompTableLayout.tongueRightX - 4 && p.x < 151                     // the switches reach ~10 pt past their ends
        guard inLoop else { return }
        if ChompTableLayout.spinnerSwitch.crossing(from: p0, to: p) != .none {
            let v = body.velocity
            spinner?.kick(ballSpeed: hypot(v.dx, v.dy))
            labEvent("spinner")
            body.velocity = CGVector(dx: v.dx * ChompSpinner.ballSpeedKept, dy: v.dy * ChompSpinner.ballSpeedKept)
        }
        if ChompTableLayout.loopEntranceSwitch.crossing(from: p0, to: p) == .forward {
            showBanner("LEFT LOOP")
            labEvent("leftLoop")
            game.add(ChompPoints.loop)
            sfx(.orbit)
        }
    }

    /// M2 v5: the wave ramp (ChompRamp, Table 06's ramp): a plastic ramp from the mouth beside the loop up and over the
    /// top-left, then a wire down the right side onto the pier flipper's block.
    private func addWaveRamp() {
        let ramp = ChompRamp(path: ChompTableLayout.wavePath, apexDistance: ChompTableLayout.waveApexDistance,
                             mouthHalfWidth: ChompTableLayout.waveMouthHalfWidth, halfWidth: ChompTableLayout.waveHalfWidth,
                             flareLength: ChompTableLayout.waveFlareLength, postLength: 0,
                             lowLength: ChompTableLayout.waveLowLength)
        addChild(ramp)
        ramps.append(ramp)
        // M2 v11: the lane's floor walls below the ramp's entrance — the left one down to the loop's post, the right one
        // ending higher with a rounded rubber end (the staggered opening).
        addWall(points: ChompTableLayout.waveLaneLeft)
        addWall(points: ChompTableLayout.waveRightBlock)       // M2 v12: the fat rounded end
    }

    /// M3 v1: the center ramp: up the lane right of the wave ramp's block, round a U-turn and down its wire into the
    /// left inlane. Its own wire level (lowWire), drawn just under the wave ramp where they cross.
    private func addCenterRamp() {
        let ramp = ChompRamp(path: ChompTableLayout.centerPath, apexDistance: ChompTableLayout.centerApexDistance,
                             mouthHalfWidth: ChompTableLayout.centerMouthHalfWidth,
                             halfWidth: ChompTableLayout.centerHalfWidth,
                             flareLength: ChompTableLayout.centerFlareLength, postLength: 0,
                             lowLength: ChompTableLayout.centerLowLength,
                             wallCategory: ChompPhysicsCategory.lowWireWall, ballCategory: ChompPhysicsCategory.lowWireBall,
                             zShift: -1)
        addChild(ramp)
        ramps.append(ramp)
        centerRamp = ramp
        // M3 v2: the real entrance's funnel — the block's edge up to the flap, a rubber post and the wall from it.
        addWall(points: ChompTableLayout.centerJamb)
        addWall(points: ChompTableLayout.centerFunnel)
        let r = ChompTableLayout.centerPostRadius
        let post = SKShapeNode(circleOfRadius: r)
        post.position = ChompTableLayout.centerPost
        post.fillColor = SKColor(white: 0.6, alpha: 1)
        post.strokeColor = SKColor(white: 1, alpha: 0.6)
        post.lineWidth = 1
        post.zPosition = 1
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = ChompTableLayout.outlaneSavePostRestitution      // the same rubber
        body.friction = 0.2
        body.categoryBitMask = ChompPhysicsCategory.wall
        body.collisionBitMask = ChompPhysicsCategory.ball
        post.physicsBody = body
        addChild(post)
    }

    /// M3 v10: the right ramp: up the tight lane right of the reel, round a J-hook to the left and down its wire into
    /// the right inlane. Its own wire level (hookWire), drawn under the wave ramp where they cross.
    private func addRightRamp() {
        let ramp = ChompRamp(path: ChompTableLayout.rightPath, apexDistance: ChompTableLayout.rightApexDistance,
                             mouthHalfWidth: ChompTableLayout.rightMouthHalfWidth,
                             halfWidth: ChompTableLayout.rightHalfWidth,
                             flareLength: ChompTableLayout.rightFlareLength, postLength: 0,
                             lowLength: ChompTableLayout.rightLowLength,
                             riseLength: ChompTableLayout.rightApexDistance,     // M3 v12: a short climb to the hook
                             wallCategory: ChompPhysicsCategory.hookWireWall, ballCategory: ChompPhysicsCategory.hookWireBall,
                             zShift: -1)
        addChild(ramp)
        ramps.append(ramp)
        rightRamp = ramp
    }

    /// M3 v4: the boat — its housing and the captive ball in the channel up its middle.
    private func addBoat() {
        addWall(points: ChompTableLayout.boatHousing)
        addWall(points: ChompTableLayout.boatFunnelLeft)    // M5 v4d: one ball wide above the mouth
        addWall(points: ChompTableLayout.boatFunnelRight)
        addWall(points: ChompTableLayout.rampIsland)       // M3 v8: the real plastics that close the stuck-ball traps
        addWall(points: ChompTableLayout.bankWedge)
        addReel()
        addFin()
        addChumBucket()
        addSharkTower()
        let b = ChompCaptiveBall(mouth: ChompTableLayout.boatMouth, heading: .pi / 2,
                                 length: ChompTableLayout.boatChannelLength, halfWidth: ChompTableLayout.boatHalfWidth,
                                 postRadius: ChompTableLayout.boatPostRadius, lip: ChompTableLayout.boatLip)
        addChild(b)
        boat = b
        addShotLamps()
    }

    // MARK: - M5 v2: Kevin's cameos

    /// Arrow inserts below the shots the cameos light (grey-box lamps until the art).
    private func addShotLamps() {
        for (shot, spot) in ChompTableLayout.shotLampSpots {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 11, y: 0))
            path.addLine(to: CGPoint(x: -7, y: 8))
            path.addLine(to: CGPoint(x: -7, y: -8))
            path.closeSubpath()
            let lamp = SKShapeNode(path: path)
            lamp.position = spot.0
            lamp.zRotation = spot.1 * .pi / 180
            lamp.strokeColor = SKColor(white: 0, alpha: 0.5)
            lamp.lineWidth = 1
            lamp.fillColor = Self.shotLampOff
            lamp.zPosition = 0.8
            addChild(lamp)
            shotLamps[shot] = lamp
            guard ChompShot.beach.contains(shot) else { continue }
            var dots: [SKShapeNode] = []                   // M5 v3: the beach's three tourists, under its arrow
            for k in 0..<ChompBeaches.touristsPerBeach {
                let dot = SKShapeNode(circleOfRadius: 4)
                dot.position = CGPoint(x: spot.0.x + CGFloat(k - 1) * 11, y: spot.0.y - 20)
                dot.strokeColor = SKColor(white: 0, alpha: 0.5)
                dot.lineWidth = 1
                dot.fillColor = Self.shotLampOff
                dot.zPosition = 0.8
                addChild(dot)
                dots.append(dot)
            }
            touristDots[shot] = dots
        }
    }

    static let touristLit = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
    static let touristSaved = SKColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1)
    static let meltdownRed = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1)

    /// M5 v3: the tourist lamps under each beach shot (lit = yellow blinking, saved = green, closed = red).
    private func updateTouristDots(_ now: TimeInterval) {
        let slow = Int(now * 4) % 2 == 0, fast = Int(now * 10) % 2 == 0
        for (shot, dots) in touristDots {
            let saved = beaches.rescued[shot] ?? 0, lit = beaches.lit[shot] ?? 0
            for (k, dot) in dots.enumerated() {
                let c: SKColor
                if shot == beaches.meltdownShot { c = fast ? Self.meltdownRed : .white }
                else if beaches.closed.contains(shot) { c = Self.meltdownRed }
                else if k < saved { c = Self.touristSaved }
                else if k < saved + lit { c = slow ? Self.touristLit : Self.shotLampOff }
                else { c = Self.shotLampOff }
                if dot.fillColor != c { dot.fillColor = c }
            }
        }
    }

    private func applyBeaches(_ effects: [ChompBeaches.Effect]) {
        for e in effects {
            switch e {
            case .score(let points, let banner):
                if points > 0 { game.add(points) }
                if let banner { showBanner(banner, hold: true) }
            case .note(let text):
                showBanner(text)
            case .meltdownStarted:
                sfx(.skillShot)
                bigHaptic.impactOccurred()
            case .extraBall:
                game.ballsLeft += 1
                game.extraBallsEarned += 1
                showBanner("EXTRA BALL", hold: true)
                sfx(.ballSave)
                bigHaptic.impactOccurred()
            case .beachJunk:
                game.beachJunkLit += 1
            }
        }
    }

    static let shotLampOff = SKColor(white: 0.35, alpha: 0.35)
    static let shotLampBlue = SKColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)
    static let shotLampFinal = SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
    static let shotLampGold = SKColor(red: 1.0, green: 0.84, blue: 0.30, alpha: 1)

    private func lampColor(_ lamp: ChompCameos.Lamp, _ now: TimeInterval) -> SKColor? {
        let slow = Int(now * 4) % 2 == 0, fast = Int(now * 10) % 2 == 0
        switch lamp {
        case .off: return nil
        case .white: return slow ? .white : Self.shotLampOff
        case .blue: return Self.shotLampBlue
        case .blueFast: return fast ? Self.shotLampBlue : .white
        case .final: return slow ? Self.shotLampFinal : Self.shotLampBlue
        case .jackpot: return fast ? Self.shotLampGold : .white
        }
    }

    /// Every frame of play: the cameo clock (stopped while the ball waits on the plunger), the fin window, the lamps
    /// and the HUD line.
    private func updateCameos(_ dt: CGFloat, _ now: TimeInterval) {
        if !isBallOnPlunger, !balls.isEmpty {
            applyCameo(cameos.tick(dt: TimeInterval(dt), now: now))
            applyBeaches(beaches.tick(dt: TimeInterval(dt)))        // M5 v3
        }
        if !balls.isEmpty { kevin.tick(now: now) }                    // M5 v4: the red arrows move
        let meltdownFlash = Int(now * 10) % 2 == 0
        if cameos.jackpotUntil != nil, fin?.isUp == true { cameos.startJackpotWindow(now: now) }
        for (shot, node) in shotLamps {
            // M5 v4: Kevin Multiball's lamps first, then a cameo's, then the Stink Line / flamingo / KMB-lit lamps.
            let cameoLamp = lampColor(cameos.lamp(shot), now)
            let kevinLamp = kevinColor(kevin.lamp(shot), now)
            var c = (kevin.multiballActive ? kevinLamp ?? cameoLamp : cameoLamp ?? kevinLamp) ?? Self.shotLampOff
            if shot == beaches.meltdownShot { c = meltdownFlash ? Self.meltdownRed : .white }     // M5 v3
            if node.fillColor != c { node.fillColor = c }
        }
        let flamingoGlow: SKColor? = kevin.stage == .finUp ? (Int(now * 4) % 2 == 0 ? Self.flamingoPink : .white) : nil
        fin?.setGlow(lampColor(cameos.lamp(.fin), now) ?? flamingoGlow)
        updateTouristDots(now)
        if flipLockUntil > 0, now >= flipLockUntil { endFlipLock() }        // M5 v5
        if !skillShotLive {
            let kmb = flipLocked ? "FLIP-LOCK · \(Int((flipLockUntil - now).rounded(.up)))s · ACTION TO LET GO"
                : kevin.multiballActive ? kevin.statusText() : nil
            game.status = beaches.statusText() ?? kmb ?? cameos.statusText(now: now) ?? kevin.statusText()
        }
    }

    static let kevinRed = SKColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1)
    static let kevinYellow = SKColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1)
    static let flamingoPink = SKColor(red: 1.0, green: 0.45, blue: 0.75, alpha: 1)

    private func kevinColor(_ lamp: ChompKevin.Lamp, _ now: TimeInterval) -> SKColor? {
        let slow = Int(now * 4) % 2 == 0, fast = Int(now * 10) % 2 == 0
        switch lamp {
        case .off: return nil
        case .red: return slow ? Self.kevinRed : Self.shotLampOff
        case .yellow: return slow ? Self.kevinYellow : Self.shotLampOff
        case .start: return fast ? Self.shotLampFinal : Self.kevinYellow
        case .jackpot: return fast ? Self.shotLampGold : Self.kevinRed
        }
    }

    private func applyKevin(_ effects: [ChompKevin.Effect]) {
        for e in effects {
            switch e {
            case .score(let points, let banner):
                if points > 0 { game.add(points) }
                if let banner { showBanner(banner, hold: true) }
            case .startMultiball(let n):
                mbLaunchesPending += max(0, n - balls.count)
                mbNextLaunchAt = gameTime + 0.5
                mbSaveUntil = gameTime + ChompKevin.multiballSaveSeconds
                sfx(.skillShot)
                bigHaptic.impactOccurred()
            case .addBall:                                       // M5 v5: the Stink Line refilled
                if balls.count + mbLaunchesPending < ChompKevin.maxBalls {
                    mbLaunchesPending += 1
                    mbNextLaunchAt = max(mbNextLaunchAt, gameTime + 0.5)
                    sfx(.skillShot)
                }
            case .multiballOver:
                mbLaunchesPending = 0
                mbSaveUntil = -1
            }
        }
    }

    /// M5 v4: a multiball ball (or a saved one) served and launched by itself, off the pin and down to the flippers.
    private func launchExtraBall() {
        let r = ChompTableLayout.ballRadius
        let ball = ChompBall(at: CGPoint(x: ChompTableLayout.laneCenterX, y: ChompTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        ball.physicsBody?.velocity = CGVector(dx: 0, dy: ChompKevin.launchSpeed)
        sfx(.launch)
    }

    /// A switch, for the cameos (from labEvent).
    private func cameoEvent(_ name: String) {
        if name == "sharkTower" { cameos.sharkTowerHit(); return }
        if name == "chumBucket" { applyKevin(kevin.bucketHit(now: gameTime)); return }      // M5 v4
        guard let shot = ChompShot(rawValue: name) else { return }
        let cameoOwnsFin = cameos.finWanted != nil          // v4b: a cameo's fin hit isn't also a flamingo
        let fx = cameos.shot(shot, now: gameTime)
        // M5 v3: a closed beach's boost (20 % of its Mayor Meltdown) on each later lit shot there.
        if let b = beaches.boost[shot], b > 0,
           fx.contains(where: { if case .score(let p, _) = $0 { return p > 0 }; return false }) { game.add(b) }
        applyCameo(fx)
        if !kevin.multiballActive { applyBeaches(beaches.shot(shot)) }   // tourists wait out a multiball
        if !(shot == .fin && cameoOwnsFin) { applyKevin(kevin.shot(shot, now: gameTime)) }   // M5 v4
    }

    private func applyCameo(_ effects: [ChompCameos.Effect]) {
        for e in effects {
            switch e {
            case .score(let points, let banner):
                game.add(points)
                if let banner { showBanner(banner, hold: true) }
            case .banner(let text):
                showBanner(text, hold: true)
            case .beachJunk:
                game.beachJunkLit += 1
            case .started:
                sfx(.skillShot)
                bigHaptic.impactOccurred()
            case .ended(_, let completed):
                if completed { game.smackBonus = cameos.macheteBonus }
            case .raiseFin, .dropFin:
                break                                     // updateFin follows cameos.finWanted
            }
        }
    }

    /// M3 v9: the fishing reel — the keyhole's blue blocks and the disc over its round end.
    private func addReel() {
        addWall(points: ChompTableLayout.reelLeftBlock)
        addWall(points: ChompTableLayout.reelRightBlock)
        let r = ChompReel(centre: ChompTableLayout.reelCentre, radius: ChompTableLayout.reelDiscRadius)
        addChild(r)
        reel = r
    }

    /// M3 v17: the shark tower standups (switches 45 / 47 / 48, "Tgt 1–3"): one in front of the loop / wave ramp post,
    /// two either side of the reel's keyhole mouth, each on a closed backing that slopes off (no ledge to rest on).
    private func addSharkTower() {
        for back in ChompTableLayout.sharkBacks { addWall(points: back) }
        let size = ChompTableLayout.sharkTargetSize
        for (i, c) in ChompTableLayout.sharkTargetCentres.enumerated() {
            let node = SKShapeNode(rectOf: size, cornerRadius: 2)
            node.position = c
            node.zRotation = ChompTableLayout.sharkTargetAngles[i]   // M3 v24: Tgt1 faces the right flipper
            node.strokeColor = SKColor(white: 1, alpha: 0.6)
            node.lineWidth = 1
            node.zPosition = 1
            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic = false
            body.restitution = 0.2
            body.friction = 0.2
            body.categoryBitMask = ChompPhysicsCategory.target
            body.collisionBitMask = ChompPhysicsCategory.ball
            body.contactTestBitMask = ChompPhysicsCategory.ball
            node.physicsBody = body
            addChild(node)
            sharkTargets.append(node)
        }
        resetSharkTower()
    }

    /// Lit = still to hit, dark = hit (placeholder until the rules: all three → SHARK TOWER, then they relight).
    private func resetSharkTower() {
        sharkDown = [false, false, false]
        for t in sharkTargets { t.fillColor = Self.bankLitColor }
    }

    /// M3 v16: the chum bucket — on the Pro, a bucket hung over the rounded nose of the plastic between the ramps on a
    /// leaf switch (manual 5.27 / 5.28, switch 46 "Chum Bucket Tgt"). Ours: a round target over the block's nose, 1 pt
    /// proud of it so the ball meets the target first; it swings when hit.
    private func addChumBucket() {
        let r = ChompTableLayout.chumBucketRadius
        let node = SKNode()
        node.position = ChompTableLayout.chumBucketCentre
        node.zPosition = 2
        let bucket = SKShapeNode(circleOfRadius: r)
        bucket.fillColor = SKColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1)         // galvanised pail
        bucket.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.8)
        bucket.lineWidth = 1.5
        node.addChild(bucket)
        let inside = SKShapeNode(circleOfRadius: r - 4)
        inside.fillColor = SKColor(red: 0.55, green: 0.12, blue: 0.10, alpha: 1)          // chum
        inside.strokeColor = SKColor(white: 0.9, alpha: 0.7)
        inside.lineWidth = 1
        node.addChild(inside)
        let handle = CGMutablePath()
        handle.addArc(center: .zero, radius: r + 2, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
        let h = SKShapeNode(path: handle)
        h.strokeColor = SKColor(white: 0.85, alpha: 0.9)
        h.lineWidth = 1.5
        node.addChild(h)
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = 0.3
        body.friction = 0.2
        body.categoryBitMask = ChompPhysicsCategory.target
        body.collisionBitMask = ChompPhysicsCategory.ball
        body.contactTestBitMask = ChompPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        chumBucket = node
    }

    /// M3 v15: the fin — its slot in the floor and the blade that roams along it.
    private func addFin() {
        let f = ChompFin(slot: ChompTableLayout.finSlot, minS: ChompTableLayout.finMinS, maxS: ChompTableLayout.finMaxS,
                         length: ChompTableLayout.finLength, thickness: ChompTableLayout.finThickness)
        addChild(f.slotNode())
        addChild(f)
        fin = f
    }

    /// M3 v15: a hit drops the fin (placeholder: up again after finRelightTime, if no ball is over it); while up it roams.
    private func updateFin(_ dt: CGFloat, _ now: TimeInterval) {
        guard let f = fin else { return }
        if finHitPending {
            finHitPending = false
            if f.isUp {
                f.drop(at: now)
                showBanner("FIN")
                labEvent("fin")
                game.add(ChompPoints.fin)
                hitHaptic.impactOccurred(intensity: 0.8)
                sfx(.standup)
            }
        }
        let floorBalls = balls.filter { $0.isOnFloor }.map { $0.position }
        if let want = cameos.finWanted ?? kevin.finWanted {   // M5 v2: a cameo raises / holds the fin down (v4: or a flamingo)
            if want, !f.isUp { f.raise(clearOf: floorBalls, ballRadius: ChompTableLayout.ballRadius) }
            if !want, f.isUp { f.drop(at: now) }
        } else if !f.isUp, now - f.droppedAt >= ChompTableLayout.finRelightTime {
            f.raise(clearOf: floorBalls, ballRadius: ChompTableLayout.ballRadius)
        }
        f.update(dt: dt, speed: ChompTableLayout.finRoamSpeed)
    }

    /// M3 v9: a floor ball crossing into the keyhole's round end kicks the reel (stronger shots, more turns).
    private func reelSwitch(_ ball: ChompBall, from p0: CGPoint, to p: CGPoint) {
        guard ball.isOnFloor, let body = ball.physicsBody,
              ChompTableLayout.reelSwitch.crossing(from: p0, to: p) == .forward else { return }
        let v = body.velocity
        reel?.kick(ballSpeed: hypot(v.dx, v.dy))
        labEvent("reel")
    }

    /// M3 v9: turns the reel; each whole turn scores.
    private func updateReel(_ dt: CGFloat, _ now: TimeInterval) {
        guard let r = reel, r.isSpinning else { return }
        let turns = r.update(dt: dt)
        guard turns > 0 else { return }
        game.add(ChompPoints.reelTurn * turns)
        if now - lastSpinSound >= 0.05 {
            lastSpinSound = now
            sfx(.spinner)
        }
        if !r.isSpinning { showBanner("FISHING REEL \(r.spinsThisRun)") }
    }

    /// M3 v4: the captive ball reached the boat target (placeholder scoring until the rules, M4).
    private func updateBoat(_ now: TimeInterval) {
        guard let b = boat, b.reachedTop(at: now, length: ChompTableLayout.boatChannelLength) else { return }
        showBanner("BOAT")
        labEvent("boat")
        game.add(ChompPoints.boat)
        hitHaptic.impactOccurred()
    }

    /// The ramps' switches, from the ball's move this frame (Table 06's updateRampLayer): the entry puts a floor ball on
    /// the ramp (backward = it fell back out), the made switch just past the top scores it, the exit at the end of the
    /// wire puts it back on the floor. A ramp ball found far from its channel drops to the floor (the safety net).
    private func updateRampLayer(_ ball: ChompBall, from p0: CGPoint, to p: CGPoint) {
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
        case .floor:
            return
        case .rampUp:
            if ramp.entrySwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.floor)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.rampDown)
                rampMade(ball, ramp)
            }
        case .rampDown:
            if ramp.exitSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.floor)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.rampUp)
            }
        }
        if !ball.isOnFloor, ramp.distanceToCenterline(p) > ramp.maxHalfWidth + ChompTableLayout.ballRadius + 12 {
            ball.setLayer(.floor)
        }
    }

    /// M2 v5: the wave ramp is made (placeholder scoring until the rules, M4).
    private func rampMade(_ ball: ChompBall, _ ramp: ChompRamp) {
        let event: String, points: Int, banner: String
        if ramp === centerRamp {                            // M3 v1
            (event, points, banner) = ("centerRamp", ChompPoints.centerRamp, "CENTER RAMP")
        } else if ramp === rightRamp {                      // M3 v10
            (event, points, banner) = ("rightRamp", ChompPoints.rightRamp, "RIGHT RAMP")
        } else {
            (event, points, banner) = ("waveRamp", ChompPoints.waveRamp, "WAVE RAMP")
        }
        showBanner(banner)
        labEvent(event)
        game.add(points)
        hitHaptic.impactOccurred()
        sfx(.ramp)
    }

    /// Turns the spinner; each half-turn scores, with one tick sound per 50 ms.
    private func updateSpinner(_ dt: CGFloat, _ now: TimeInterval) {
        guard let s = spinner, s.isSpinning else { return }
        let spins = s.update(dt: dt)
        guard spins > 0 else { return }
        game.add(ChompPoints.spin * spins)
        if now - lastSpinSound >= 0.05 {
            lastSpinSound = now
            sfx(.spinner)
        }
    }

    /// The buoy standup above the pier pocket (category target): two quick hits light the inner tube.
    private func addBuoy() {
        let size = ChompTableLayout.buoySize
        let node = SKShapeNode(rectOf: size, cornerRadius: 2)
        node.position = ChompTableLayout.buoyCenter
        node.zRotation = (ChompTableLayout.buoyFacingDegrees - 90) * .pi / 180   // the long side faces the normal
        node.fillColor = SKColor(red: 1.0, green: 0.84, blue: 0.36, alpha: 1)
        node.strokeColor = SKColor(white: 1, alpha: 0.6)
        node.lineWidth = 1
        node.zPosition = 1
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.restitution = 0.2
        body.friction = 0.2
        body.categoryBitMask = ChompPhysicsCategory.target
        body.collisionBitMask = ChompPhysicsCategory.ball
        body.contactTestBitMask = ChompPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        buoy = node
    }

    private func addPlunger() {
        let size = ChompTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = ChompTableLayout.plungerRestPosition

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = ChompPhysicsCategory.wall
        body.collisionBitMask = ChompPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    /// The launch gate across the top of the shooter lane: solid per ball, only for a ball above it moving down
    /// (a plunge going up swings the flap and passes; a ball coming back rolls off it into play).
    private func addLaunchGate() {
        let low = ChompTableLayout.gateLow, high = ChompTableLayout.gateHigh
        let node = SKNode()
        let gatePath = CGMutablePath()                          // M3 v14b: the gate is an arc (ChompTableLayout.gateArc)
        gatePath.addLines(between: ChompTableLayout.gateArc)
        let body = SKPhysicsBody(edgeChainFrom: gatePath)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = ChompPhysicsCategory.launchGate
        body.collisionBitMask = ChompPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)

        let flap = SKNode()
        flap.position = high
        flap.zPosition = 2
        let closed = atan2(low.y - high.y, low.x - high.x) + .pi / 2
        let length = hypot(low.x - high.x, low.y - high.y)
        let blade = SKShapeNode(rect: CGRect(x: -2.5, y: -length, width: 5, height: length), cornerRadius: 2)
        blade.fillColor = SKColor(white: 0.82, alpha: 1)
        blade.strokeColor = SKColor(white: 0.25, alpha: 1)
        blade.lineWidth = 1
        flap.addChild(blade)
        let pin = SKShapeNode(circleOfRadius: 4)
        pin.fillColor = SKColor(white: 0.9, alpha: 1)
        pin.strokeColor = SKColor(white: 0.25, alpha: 1)
        pin.lineWidth = 1
        flap.addChild(pin)
        flap.zRotation = closed
        addChild(flap)
        launchGateFlap = flap
        launchGateClosedAngle = closed
    }

    /// The launch gate, per ball: solid for a ball above it moving down; a ball crossing it going up swings it.
    private func updateGates() {
        // M3 v14: the gate sits at the top of the reel lane: solid for a ball whose centre is on the reel-lane side of it
        // (the turn centre's side), so the plunge passes inward and nothing goes back out into the plunger lane.
        for ball in balls {
            ball.setLaunchGateSolid(isOnReelLaneSideOfGate(ball.position))
        }
    }

    /// M3 v14: which side of the gate's line a point is on (true = the reel lane's side, where the turn centre is).
    private func isOnReelLaneSideOfGate(_ p: CGPoint) -> Bool {
        let c = ChompTableLayout.turnCentre                     // M3 v14b: the gate lies on r 80, so inside = past it
        return hypot(p.x - c.x, p.y - c.y) < ChompTableLayout.turnInnerR
    }

    private func swingLaunchGate() {
        guard let flap = launchGateFlap else { return }
        sfx(.gate)
        let closed = launchGateClosedAngle
        flap.removeAction(forKey: "swing")
        let open = SKAction.rotate(toAngle: closed - 1.4, duration: 0.07, shortestUnitArc: true)
        let back = SKAction.rotate(toAngle: closed, duration: 0.55, shortestUnitArc: true)
        back.timingMode = .easeIn
        flap.run(.sequence([open, back]), withKey: "swing")
    }

    // MARK: - Lanes

    /// A lane switch rolled over (M1: plain switches; the rules milestone gives them their jobs). The mini-lane arms the
    /// up-posts as a test; an inlane with the up-posts armed raises its post to hold that ball.
    private func rollOver(_ lane: ChompRollover, at now: TimeInterval) {
        lane.isLit = true
        labEvent(lane === miniLane ? "miniLane" : "lane")
        laneOffAt[ObjectIdentifier(lane)] = now + 0.25        // a short blink; updateUpPosts puts it out
        if lane === miniLane {
            game.add(ChompPoints.miniLane)
            sfx(.lane)
            if !upPostsArmed {
                upPostsArmed = true
                if game.banner == nil { showBanner("UP-POSTS ARMED · TEST") }   // M5 v1: not over a skill shot's
            }
            return
        }
        if let i = quickshotLanes.firstIndex(where: { $0 === lane }) {
            game.add(ChompPoints.quickshotLane)
            sfx(.lane)
            if i == 2 { showBanner("HARPOON LANE") }          // the bottom one: the lane was made
            return
        }
        game.add(ChompPoints.lane)
        sfx(.lane)
        // Inlanes are rollovers 1 (left) and 2 (right).
        if let i = rollovers.firstIndex(where: { $0 === lane }), i == 1 || i == 2, upPostsArmed {
            let side = i == 1 ? 0 : 1
            if !upPostUp[side] {
                upPostsArmed = false
                upPostRaisePending[side] = true
                showBanner("UP-POST HOLD · TEST")
            }
        }
    }

    /// Raises a pending up-post once no ball overlaps it, and drops a raised one when its hold runs out.
    private func updateUpPosts(_ now: TimeInterval) {
        for lane in rollovers + quickshotLanes + [miniLane].compactMap({ $0 }) {
            if let due = laneOffAt[ObjectIdentifier(lane)], now >= due {
                lane.isLit = false
                laneOffAt[ObjectIdentifier(lane)] = nil
            }
        }
        for i in upPosts.indices {
            if upPostRaisePending[i] {
                let p = upPosts[i].position
                let clear = ChompTableLayout.upPostRadius + ChompTableLayout.ballRadius + 1
                if !balls.contains(where: { hypot($0.position.x - p.x, $0.position.y - p.y) < clear }) {
                    upPostRaisePending[i] = false
                    setUpPost(i, up: true)
                    upPostDropAt[i] = now + ChompTableLayout.upPostHoldSeconds
                }
            }
            if let due = upPostDropAt[i], now >= due { setUpPost(i, up: false) }
        }
    }

    /// The one-way gates (category diverter; M2 v16: now only the quickshot gate): solid for each ball only while it moves right.
    /// M5 v4e (Play Lab 03-10-05Z: a ball left the table at (−33, 923); wall probe: a 3,500 pt/s shot off Tgt1 into
    /// the harpoon lane went through the outer wall at x 20, and 2,500 pt/s ones sank 13 pt into it): a ball moves
    /// ~29 pt a 120 Hz step at top speed, almost a whole ball, and SpriteKit's edge chain can let its centre through.
    /// If a floor ball's centre crossed the outer wall this step, it goes back to the playfield side, one radius off
    /// the wall, with its velocity into the wall bounced (wall restitution).
    /// M5 v5d (Play Lab 13-58-20Z: a ~3,000 pt/s left-flipper shot straight up at x 321 went through the boat's
    /// channel and stuck inside the housing at (321, 1058)): the same guard for the boat — its housing, the captive
    /// ball's channel (sides and end cap) and the v4d funnel.
    private lazy var outerWallSegments: [(CGPoint, CGPoint)] = {
        let m = ChompTableLayout.boatMouth, hw = ChompTableLayout.boatHalfWidth, l = ChompTableLayout.boatChannelLength
        let channel = [CGPoint(x: m.x - hw, y: m.y), CGPoint(x: m.x - hw, y: m.y + l),
                       CGPoint(x: m.x + hw, y: m.y + l), CGPoint(x: m.x + hw, y: m.y)]
        let chains = [ChompTableLayout.outerWall, ChompTableLayout.boatHousing, channel,
                      ChompTableLayout.boatFunnelLeft, ChompTableLayout.boatFunnelRight]
        return chains.flatMap { w in zip(w, w.dropFirst()).map { ($0, $1) } }
    }()

    private func keepInsideOuterWall(_ ball: ChompBall, _ body: SKPhysicsBody) {
        let p0 = ball.previousPosition, p = ball.position
        guard p0 != p else { return }
        let d = CGVector(dx: p.x - p0.x, dy: p.y - p0.y)
        guard hypot(d.dx, d.dy) < 80 else { return }              // a ball placed by a lab, not a physics step
        for (a, b) in outerWallSegments {
            let e = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            let den = d.dx * e.dy - d.dy * e.dx
            guard abs(den) > 1e-6 else { continue }
            let w = CGVector(dx: a.x - p0.x, dy: a.y - p0.y)
            let t = (w.dx * e.dy - w.dy * e.dx) / den          // along the ball's step
            let u = (w.dx * d.dy - w.dy * d.dx) / den          // along the wall segment
            guard t >= 0, t <= 1, u >= 0, u <= 1 else { continue }
            let len = max(hypot(e.dx, e.dy), 1e-6)
            var n = CGVector(dx: -e.dy / len, dy: e.dx / len)
            if (p0.x - a.x) * n.dx + (p0.y - a.y) * n.dy < 0 { n = CGVector(dx: -n.dx, dy: -n.dy) }   // toward where it came from
            let hit = CGPoint(x: p0.x + d.dx * t, y: p0.y + d.dy * t)
            let r = ChompTableLayout.ballRadius
            ball.position = CGPoint(x: hit.x + n.dx * (r + 0.5), y: hit.y + n.dy * (r + 0.5))
            let v = body.velocity
            let vn = v.dx * n.dx + v.dy * n.dy
            if vn < 0 {
                let k = (1 + ChompTableLayout.wallRestitution) * vn
                body.velocity = CGVector(dx: v.dx - n.dx * k, dy: v.dy - n.dy * k)
            }
            return
        }
    }

    private func updateSaveGate() {
        for ball in balls {
            ball.setSaveGateSolid((ball.physicsBody?.velocity.dx ?? 0) > 0)
        }
    }

    // MARK: - Saves

    /// Whether a ball that drains now is saved: once per player ball, while it waits on the plunger and for the first
    /// 10 s after launch.
    private var ballSaveNow: Bool {
        guard !ballSaveUsed else { return false }
        if let t = launchedAt { return gameTime - t <= ChompTableLayout.ballSaveSeconds + ballSaveBonus }
        return true
    }

    /// The inner tube: while lit AND armed by the action button, it fires a ball draining down the left outlane straight
    /// back up it (the kickback's kicker). M1: lit at the start of every ball; two quick buoy hits relight it.
    private func updateKickback() {
        let armed = gameTime <= innerTubeArmedUntil
        kickbackLamp?.fillColor = !kickbackLit ? Self.lampOffColor
            : armed ? (Int(gameTime * 16) % 2 == 0 ? .white : Self.lampOnColor) : Self.lampOnColor
        guard kickbackLit, armed, !nudge.tilted else { return }
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            let p = ball.position
            if p.x < ChompTableLayout.kickbackMaxX, p.y < ChompTableLayout.kickbackTriggerY, p.y > 0, body.velocity.dy < 0 {
                body.velocity = CGVector(dx: 0, dy: ChompTableLayout.kickbackSpeed)
                setKickbackLit(false)
                innerTubeArmedUntil = -1
                buoyLastHit = -10                            // relighting takes two fresh buoy hits
                game.add(ChompPoints.innerTube)
                bigHaptic.impactOccurred()
                Effects.burst(in: self, at: p, color: Self.wallColor, count: 18, speed: 240, lifetime: 0.4)
                cameraRig.shake(strength: 3, duration: 0.25)
                sfx(.kickback)
                showBanner("INNER TUBE SAVE")
                return
            }
        }
    }

    /// The action button (the view's ACTION button): arms the inner tube for a moment, once per cooldown. A press
    /// with the inner tube unlit does nothing yet (flip-lock and the wheel use it in later milestones).
    func actionPressed() {
        guard isBuilt, !isAttractMode, !isGamePaused, !game.isGameOver else { return }
        if flipLockAction() { return }                          // M5 v5: flip-lock first, in a multiball
        guard kickbackLit, gameTime >= innerTubeReadyAt else { return }
        innerTubeArmedUntil = gameTime + ChompTableLayout.innerTubeArmSeconds
        innerTubeReadyAt = gameTime + ChompTableLayout.innerTubeCooldown
        hitHaptic.impactOccurred(intensity: 0.5)
    }

    /// M5 v5 flip-lock (rulesheet: "while a ball is held at the flipper, press the action button; the mini-flipper stays
    /// raised" 20 s; once per ball; releasing early: we use a second press). Returns true if ACTION was used for it.
    private func flipLockAction() -> Bool {
        if flipLocked {                                         // a second press lets it go
            endFlipLock()
            return true
        }
        guard kevin.multiballActive, !flipLockUsed, !nudge.tilted, miniFlipper?.isPressed == true else { return false }
        let held = balls.contains { $0.isOnFloor && hypot($0.position.x - Self.flipLockSpot.x, $0.position.y - Self.flipLockSpot.y) < 24 }
        guard held else { return false }
        flipLockUsed = true
        flipLockUntil = gameTime + Self.flipLockSeconds
        updateFlippers()
        showBanner("FLIP-LOCK · \(Int(Self.flipLockSeconds))s", hold: true)
        hitHaptic.impactOccurred(intensity: 0.7)
        return true
    }

    private func endFlipLock() {
        guard flipLockUntil > 0 else { return }
        flipLockUntil = -1
        updateFlippers()
        showBanner("FLIP-LOCK OFF")
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
            fpsGapSum = 0; fpsGapSq = 0; fpsMisses = 0; cpuSum = 0; cpuWorst = 0; cpuFrames = 0
        } else {
            fpsFrames += 1
            fpsWorstGap = max(fpsWorstGap, gap)
            fpsGapSum += gap; fpsGapSq += gap * gap
            if gap > 0.0108 { fpsMisses += 1 }
            let window = t - fpsWindowStart
            if window >= 0.5 {
                fpsShown = Int((Double(fpsFrames) / window).rounded())
                fpsWorstShown = Int((fpsWorstGap * 1000).rounded())
                if fpsLow == 0 || fpsShown < fpsLow { fpsLow = fpsShown }
                let n = Double(max(fpsFrames, 1))
                let mean = fpsGapSum / n
                let jitter = sqrt(max(0, fpsGapSq / n - mean * mean)) * 1000
                let cpuAvg = cpuFrames > 0 ? cpuSum / Double(cpuFrames) * 1000 : 0
                frameStatsShown = String(format: "jitter %.2f ms · missed %d · cpu %.1f / %.1f ms\n",
                                         jitter, fpsMisses, cpuAvg, cpuWorst * 1000)
                fpsWindowStart = t; fpsFrames = 0; fpsWorstGap = 0
                fpsGapSum = 0; fpsGapSq = 0; fpsMisses = 0; cpuSum = 0; cpuWorst = 0; cpuFrames = 0
            }
        }
        guard gameTime - buildTagAt >= 0.25 else { return }
        buildTagAt = gameTime
        var speed = 0
        if let v = focusBall?.physicsBody?.velocity {
            speed = Int(hypot(v.dx, v.dy) / 10) * 10
        }
        let fps = fpsShown > 0 ? "\(fpsShown) fps · low \(fpsLow) · worst \(fpsWorstShown) ms\n" : ""
        var text = "\(fps)\(frameStatsShown)\(Self.buildTagText) \(effectiveCameraMode.tag) · \(speed)"
        #if DEBUG
        if let lab = playLab { text += "\n" + lab.progressText }   // M4 v1
        #endif
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: ChompBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func placeBallOnPlunger() {
        wasOnPlunger = false
        launchedAt = nil
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // a tilt ends here
        let r = ChompTableLayout.ballRadius
        let ball = ChompBall(at: CGPoint(x: ChompTableLayout.laneCenterX, y: ChompTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        servedBall = ball
        startSkillShot()
    }

    // MARK: - Skill shots (M5 v1)

    /// Lit on every serve: plunge onto the bumper (L1), into the lane above the mini flipper without touching the
    /// bumper (L2), or to the flippers and then hit the flashing Fish Phone target before any other switch (L3).
    private func startSkillShot() {
        stopSkillFlash()
        skillShotLive = true
        ballSaveBonus = 0
        skillPeakY = 0
        let lit = bankDown.indices.filter { !bankDown[$0] }
        skillTarget = lit.randomElement()
        if let i = skillTarget, i < bankTargets.count {
            let t = bankTargets[i]
            t.run(.repeatForever(.sequence([.run { t.fillColor = .white }, .wait(forDuration: 0.15),
                                            .run { t.fillColor = Self.bankLitColor }, .wait(forDuration: 0.15)])),
                  withKey: "skillFlash")
        }
        game.status = "SKILL SHOT: BUMPER · MINI LANE · FLASHING TARGET"
    }

    private func stopSkillFlash() {
        guard let i = skillTarget, i < bankTargets.count else { return }
        bankTargets[i].removeAction(forKey: "skillFlash")
        bankTargets[i].fillColor = bankDown[i] ? Self.bankDarkColor : Self.bankLitColor
    }

    /// The first switch after the launch decides the skill shot (called from labEvent, so every switch counts).
    private func skillShotSwitch(_ name: String) {
        guard skillShotLive, launchedAt != nil else { return }
        skillShotLive = false
        let flashing = skillTarget
        stopSkillFlash()
        skillTarget = nil
        game.status = nil
        switch name {
        case "bumper" where skillPeakY < ChompTableLayout.skillBumperMaxPeakY: awardSkillShot(1, ChompPoints.skillShot1)
        case "miniLane": awardSkillShot(2, ChompPoints.skillShot2)
        case "fishPhone" where bankHitIndex != nil && bankHitIndex == flashing: awardSkillShot(3, ChompPoints.skillShot3)
        default: break
        }
    }

    private func awardSkillShot(_ level: Int, _ points: Int) {
        game.add(points)
        ballSaveBonus += ChompTableLayout.skillShotSaveBonus
        if level >= 2 { game.beachJunkLit += 1 }
        showBanner("SKILL SHOT \(level) · \(points / 1_000_000)M" + (level >= 2 ? " · BEACH JUNK LIT" : ""), hold: true)
        sfx(.skillShot)
        bigHaptic.impactOccurred()
    }

    private func removeBall(_ ball: ChompBall) {
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
    }

    private func removeAllBalls() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        servedBall = nil
    }

    private func isOnPlunger(_ ball: ChompBall) -> Bool {
        ball.position.x > ChompTableLayout.laneWallX
            && ball.position.y < ChompTableLayout.plungerRestTop + ChompTableLayout.ballRadius * 3
    }

    private var plungerBall: ChompBall? {
        balls.first(where: { isOnPlunger($0) })
    }

    private var isBallOnPlunger: Bool { plungerBall != nil }

    func newGame() {
        fpsLow = 0
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game stops the Shot Lab
        if !playLabStarting { stopPlayLab(saving: true) }   // and the Play Lab, unless it's starting its next game
        #endif
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = ChompTableLayout.plungerRestPosition
        rollovers.forEach { $0.isLit = false }
        setKickbackLit(true)
        innerTubeArmedUntil = -1
        innerTubeReadyAt = 0
        buoyLastHit = -10
        upPostsArmed = false
        for i in upPosts.indices { upPostRaisePending[i] = false; setUpPost(i, up: false) }
        resetBank()
        resetSharkTower()
        boat?.reset()
        reel?.reset()
        fin?.reset()
        finHitPending = false
        ballSaveUsed = false
        cameos.newGame()                           // M5 v2
        beaches.newGame()                          // M5 v3
        kevin.newGame()                            // M5 v4
        flipLockUntil = -1                         // M5 v5
        flipLockUsed = false
        if leftFlipper != nil { updateFlippers() } // v5b: a lock from the last game doesn't hold the pier flipper up
        mbLaunchesPending = 0
        mbSaveUntil = -1
        sharkHitAt = [-1, -1, -1]
        game.reset()
        placeBallOnPlunger()
        refreshCamera()
    }

    private static let minorBanners: Set<String> = ["LEFT LOOP", "BOAT", "WAVE RAMP", "CENTER RAMP", "RIGHT RAMP", "FIN",
                                                    "FISH PHONE", "SHARK TOWER", "HARPOON LANE"]

    private func showBanner(_ text: String, hold: Bool = false) {
        #if DEBUG
        playLab?.banner(text)
        labObjective(forBanner: text)
        #endif
        // M5 v2c: the plain shot names wait while a skill shot / cameo banner holds the line.
        if gameTime < bannerHoldUntil,
           Self.minorBanners.contains(text) || text.hasPrefix("FISHING REEL") || text.hasPrefix("TOURIST AT") { return }
        if hold { bannerHoldUntil = gameTime + ChompTableLayout.bannerHoldSeconds }
        game.banner = text
        bannerClearAt = gameTime + ChompTableLayout.bannerSeconds
    }

    private func sfx(_ s: MonSound) {
        #if DEBUG
        if playLab != nil, playLab?.isWatching != true { return }   // the robot plays silently unless watched
        #endif
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView, !isAttractMode else { return }
        for touch in touches {
            let p = touch.location(in: view)   // screen points: the camera moves the table
            if isBallOnPlunger,
               !activeTouches.values.contains(.plunger),
               isInPlungerZone(p, of: view) {
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
        return p.x > b.width * ChompTableLayout.plungerZoneMinX && p.y > b.height * ChompTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView else { return }
        for touch in touches {
            let p = touch.location(in: view)
            switch activeTouches[touch] {
            case .plunger:
                let dragged = (p.y - plungerStartY) * cameraRig.node.yScale
                plungerPull = min(max(dragged, 0), ChompTableLayout.plungerMaxPull)
                plunger.position.y = ChompTableLayout.plungerRestPosition.y - plungerPull
            case .left, .right:
                // A quick flick of a flipper finger nudges the table.
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
        miniFlipper?.isPressed = right || (flipLocked && !nudge.tilted)   // shares the right button (v5: or flip-lock)
    }

    private func applyNudge(_ direction: Nudge.Direction) {
        guard !isAttractMode, !game.isGameOver else { return }
        let free = balls.filter { !isOnPlunger($0) }
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
            flipLockUntil = -1                               // M5 v5b: a tilt ends a flip-lock
            updateFlippers()                                 // the flippers drop
        }
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        padPullByA = false
        plungerPull = 0
        plunger?.position = ChompTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    /// Pausing (Table 06's fix, b6af018): like releaseAllControls, but a flipper finger still down stays held, so a
    /// ball cradled on a flipper is still cradled after resume. The plunger pull and the gamepad let go as before.
    private func releaseNonTouchControls() {
        for (touch, kind) in activeTouches where kind == .plunger { activeTouches.removeValue(forKey: touch) }
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        padPullByA = false
        plungerPull = 0
        plunger?.position = ChompTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    private func releasePlunger() {
        let maxPull = ChompTableLayout.plungerMaxPull
        let power = plungerPull < 4 ? ChompTableLayout.tapLaunchPower : plungerPull / maxPull
        if let body = plungerBall?.physicsBody {
            let speed = ChompTableLayout.minLaunchSpeed      // M4 v5: the soft end of the pull eased in
                + pow(power, ChompTableLayout.plungePowerExponent) * (ChompTableLayout.maxLaunchSpeed - ChompTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
        }
        plunger.run(.move(to: ChompTableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    /// Game controller, every frame of play: shoulders/triggers flip, A held or the right stick pulled down works the
    /// plunger (released = launch, with the furthest pull reached). Touches keep working alongside.
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
            plungerPull = pull * ChompTableLayout.plungerMaxPull
            plunger.position.y = ChompTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * ChompTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = ChompTableLayout.plungerRestPosition
                }
            }
        }
    }

    // MARK: - Game loop

    override func update(_ realTime: TimeInterval) {
        cpuStart = CACurrentMediaTime()
        var step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
        #if DEBUG
        if let lab = playLab { step *= Double(lab.physicsSpeed) }   // M4 v1: the Play Lab's pass (120 Hz steps)
        #endif
        lastRealTime = realTime
        gameTime += step
        let now = gameTime
        #if DEBUG
        if shotLab != nil {                        // Shot Lab: the robot's frame instead of a game frame
            updateShotLab(CGFloat(step))
            return
        }
        if fanProbe != nil {                       // M2 v8: the flipper fan probe
            updateFanProbe(CGFloat(step))
            return
        }
        if dropProbeT != nil {                     // M3 v13: the drop probe
            physicsWorld.speed = 0.5
            updateDropProbe(CGFloat(step) * 0.5)
            return
        }
        if pierProbeT != nil {                     // M2 v15: the pier probe
            physicsWorld.speed = 0.5               // 120 Hz steps, as on the phone
            updatePierProbe(CGFloat(step) * 0.5)
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
        miniFlipper.step(dt: dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        governInlanes()                          // the inlane speed limit (2026-11-02)
        updateGates()
        updateSaveGate()
        updateUpPosts(now)
        updateSpinner(dt, now)
        updateReel(dt, now)
        updateBoat(now)
        updateFin(dt, now)
        updateCameos(dt, now)                    // M5 v2
        if bankRelightPending { bankRelightPending = false; resetBank() }
        if sharkRelightPending { sharkRelightPending = false; resetSharkTower() }

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // Launch = the frame the served ball leaves the plunger area.
        var onPlunger = false
        if let served = servedBall { onPlunger = isOnPlunger(served) }
        if wasOnPlunger && !onPlunger && servedBall != nil {
            launchedAt = now
            sfx(.launch)
        }
        wasOnPlunger = onPlunger
        if skillShotLive, launchedAt != nil, let served = servedBall { skillPeakY = max(skillPeakY, served.position.y) }
        updateKickback()

        // Drain: remove every ball off the bottom; a ball is lost only when none are left.
        let drained = balls.filter { $0.position.y < -ChompTableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            // M5 v4: Kevin Multiball's ball save serves drained balls again (launched by themselves).
            let mbSaved = kevin.multiballActive && now < mbSaveUntil && !nudge.tilted
            if mbSaved {
                mbLaunchesPending += drained.count
                mbNextLaunchAt = max(mbNextLaunchAt, now + 0.5)
                showBanner("BALL SAVED"); sfx(.ballSave)
            }
            if balls.isEmpty, nextBallAt == nil, !mbSaved, mbLaunchesPending == 0 {   // v4b: not while a saved ball is owed
                if ballSaveNow, !nudge.tilted {
                    ballSaveUsed = true
                    game.ballSaved()
                    showBanner("BALL SAVED"); sfx(.ballSave)
                    bigHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else {
                    ballSaveUsed = false             // the next ball gets its own save
                    flipLockUsed = false             // M5 v5: and its own flip-lock
                    if flipLockUntil > 0 { flipLockUntil = -1; updateFlippers() }
                    cameraRig.shake(strength: 4, duration: 0.3)
                    sfx(.drain)
                    applyCameo(cameos.ballLost())    // M5 v2: a cameo ends with the ball
                    applyBeaches(beaches.ballLost()) // M5 v3: so does a Mayor Meltdown
                    game.ballDrained()
                    if !game.isGameOver {
                        nextBallAt = now + 1.0
                        setKickbackLit(true)         // M1 scaffolding: every ball starts with the inner tube lit
                        upPostsArmed = false
                    }
                }
            }
        }

        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            placeBallOnPlunger()
        }

        // M5 v4: Kevin Multiball — serve its balls one at a time, and end it when one (or none) is left.
        if kevin.multiballActive {
            if mbLaunchesPending > 0, now >= mbNextLaunchAt, !isBallOnPlunger, !game.isGameOver {
                mbLaunchesPending -= 1
                mbNextLaunchAt = now + 1.0
                launchExtraBall()
            }
            // v4b: an owed (saved) ball with none in play is served first; the end comes once it's out.
            if balls.count + mbLaunchesPending <= 1, !(balls.isEmpty && mbLaunchesPending > 0) {
                applyKevin(kevin.multiballEnded())
            }
        }

        #if DEBUG
        checkPlayLabGame(now)
        #endif
        let waiting = isBallOnPlunger
        if game.ballOnPlunger != waiting {
            game.ballOnPlunger = waiting
        }
    }

    /// T7 M2 v10: a floor ball within reach of a flipper swinging up this frame belongs to the flipper model for the
    /// physics step (ghosted from the flippers); ChompFlipper.solveSwing works out the frame afterwards.
    private func handBallsToSwingingFlippers() {
        guard ChompTableLayout.flipperModel else { return }
        let r = ChompTableLayout.ballRadius
        for ball in balls where ball.isOnFloor {
            for f in [leftFlipper!, rightFlipper!, miniFlipper!] where f.isSwingingUp && f.reaches(ball.position, ballRadius: r) {
                ball.flipperGhostSteps = max(ball.flipperGhostSteps, 1)
            }
        }
    }

    /// Hot inlane feeds: a ball rolling down an inlane is held to InlaneGovernor.maxSpeed (800 pt/s) so a held-up
    /// flipper can trap it.
    private func governInlanes() {
        for ball in balls {
            guard let body = ball.physicsBody,
                  let v = InlaneGovernor.limited(body.velocity, at: ball.position,
                                                 leftGuide: ChompTableLayout.leftLaneGuide,
                                                 mirrorSum: ChompTableLayout.mirrorSum) else { continue }
            body.velocity = v
        }
    }

    /// M3 v13: the solid plastics (closed outlines). The stuck test found balls INSIDE the pier block (after the pier
    /// flipper swung) and the reel's right block: a floor ball whose centre ends up inside one is put back just outside
    /// its nearest edge, with any velocity into that edge removed.
    private lazy var solidBlocks: [[CGPoint]] = [ChompTableLayout.pierPlastic, ChompTableLayout.reelLeftBlock,
                                                  ChompTableLayout.reelRightBlock, ChompTableLayout.rampIsland,
                                                  ChompTableLayout.bankWedge, ChompTableLayout.waveRightBlock]
                                                  + ChompTableLayout.sharkBacks + [ChompTableLayout.loopRight]

    private func keepOutOfSolids(_ ball: ChompBall) {
        let p = ball.position
        for poly in solidBlocks where poly.count > 2 {
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
            let r = ChompTableLayout.ballRadius + 0.5
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
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if ball.flipperGhostSteps > 0 { ball.flipperGhostSteps -= 1 }
            // The flip assist: a flip gives the ball its full speed on long steps too (off at 120 Hz steps).
            let r = ChompTableLayout.ballRadius
            // T7 M2 v9: the contact launch replaces the flip assist (at every step length): smooth aim along the flipper.
            // Off for now (ChompTableLayout.flipperCarry): smooth, but it narrowed the fan (Shot Lab run 4).
            if ChompTableLayout.flipperModel {
                if ball.isOnFloor {
                    leftFlipper.solveSwing(ball, ballRadius: r)
                    rightFlipper.solveSwing(ball, ballRadius: r)
                    miniFlipper.solveSwing(ball, ballRadius: r)
                }
                if ball.isOnFloor { keepOutOfSolids(ball) }          // M3 v13
            } else if ChompTableLayout.flipperCarry {
                if ball.isOnFloor {
                    leftFlipper.contactLaunch(ball, ballRadius: r)
                    rightFlipper.contactLaunch(ball, ballRadius: r)
                    miniFlipper.contactLaunch(ball, ballRadius: r)
                }
            } else {
                leftFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
                rightFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
                miniFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
            }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            if speed > ChompTableLayout.maxBallSpeed {
                let scale = ChompTableLayout.maxBallSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            // A plunge crossing the launch gate going up swings the flap (read before previousPosition moves on).
            // M3 v14: a plunge crossing into the turn through the gate (between the divider's end and the spiral's end).
            if ball.isOnFloor { keepInsideOuterWall(ball, body) }                 // M5 v4e
            let p0 = ball.previousPosition, p = ball.position
            if !isOnReelLaneSideOfGate(p0), isOnReelLaneSideOfGate(p),
               p.x > ChompTableLayout.gateHigh.x - 5, p.x < ChompTableLayout.gateLow.x + 5, p.y > ChompTableLayout.gateLow.y - 5 {
                swingLaunchGate()
            }
            leftSideSwitches(ball, from: p0, to: p)
            reelSwitch(ball, from: p0, to: p)
            // M2 v6: a ball through the quickshot gate into the harpoon lane (the pier flipper's shot), for the labs.
            let gate = ChompTableLayout.quickshotGate
            if ball.isOnFloor, p0.x >= gate.a.x, p.x < gate.a.x, p.y > gate.a.y, p.y < gate.b.y { labEvent("harpoonGate") }
            updateRampLayer(ball, from: p0, to: p)
            ball.rampHeight = ball.isOnFloor ? 0 : (ball.activeRamp?.height(at: p) ?? 0)
            ball.previousPosition = ball.position
            ball.previousVelocity = ball.physicsBody?.velocity ?? .zero
            ball.updateLook()
        }
    }

    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: lastStep)
        if cpuStart > 0 {
            let cpu = CACurrentMediaTime() - cpuStart
            cpuSum += cpu; cpuWorst = max(cpuWorst, cpu); cpuFrames += 1
        }
        placeBuildTag()
    }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        let ballish = ChompPhysicsCategory.ball | ChompPhysicsCategory.ghostBall   // M2 v9: a just-launched ball too
        if a.categoryBitMask & ballish != 0 {
            ballBody = a; other = b
        } else if b.categoryBitMask & ballish != 0 {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? ChompBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case ChompPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? ChompSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                labEvent("sling")
                game.add(ChompPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case ChompPhysicsCategory.bumper:
            if let b = node as? ChompBumper, b.hit(ball: ballBody, ballPosition: ballNode.position, at: gameTime) {
                game.add(ChompPoints.bumper)
                hitHaptic.impactOccurred(intensity: 0.7)
                sfx(.bumper)
                labEvent("bumper")                              // M4 v4e: so the plunge sweep can see skill shot L1
            }
        case ChompPhysicsCategory.target:
            // M2 v1: the Fish Phone bank (placeholder: all three → "FISH PHONE", then they relight).
            if let i = bankTargets.firstIndex(where: { $0 === node }) {
                bankHitIndex = i                              // M5 v1: the skill shot needs to know which one
                labEvent("fishPhone")
                bankHitIndex = nil
                if !bankDown[i] {
                    bankDown[i] = true
                    bankTargets[i].fillColor = Self.bankDarkColor
                    game.add(ChompPoints.bankTarget)
                    sfx(.standup)
                    if !bankDown.contains(false) {
                        game.add(ChompPoints.bankComplete)
                        showBanner("FISH PHONE")
                        bankRelightPending = true             // relit in update(), not in the contact callback
                    }
                }
                break
            }
            // M3 v17: the shark tower standups.
            if let i = sharkTargets.firstIndex(where: { $0 === node }) {
                labEvent("sharkTower")
                if gameTime - sharkHitAt[i] > 0.3 {                // M5 v3: a tourist at a beach beside it
                    sharkHitAt[i] = gameTime
                    if !kevin.multiballActive { applyBeaches(beaches.towerHit(i, modeRunning: cameos.isRunning)) }
                }
                if !sharkDown[i] {
                    sharkDown[i] = true
                    sharkTargets[i].fillColor = Self.bankDarkColor
                    game.add(ChompPoints.sharkTarget)
                    sfx(.standup)
                    if !sharkDown.contains(false) {
                        game.add(ChompPoints.sharkTowerComplete)
                        showBanner("SHARK TOWER")
                        sharkRelightPending = true             // relit in update(), not in the contact callback
                    }
                }
                break
            }
            // M3 v16: the chum bucket (placeholder scoring until the rules).
            if node === chumBucket {
                guard gameTime - chumLastHit > 0.15 else { break }
                chumLastHit = gameTime
                labEvent("chumBucket")
                game.add(ChompPoints.chumBucket)
                sfx(.standup)
                node.removeAction(forKey: "swing")
                node.run(.sequence([.scale(to: 1.12, duration: 0.05), .scale(to: 1.0, duration: 0.12)]), withKey: "swing")
                break
            }
            // M3 v15: the fin drops (in update, not here).
            if node === fin { finHitPending = true; break }
            // The buoy: two hits inside the window light the inner tube.
            if node === buoy {
                let since = gameTime - buoyLastHit
                guard since > 0.15 else { break }            // the same hit chattering on the target
                labEvent("buoy")
                game.add(ChompPoints.buoy)
                sfx(.standup)
                if since <= ChompTableLayout.buoyDoubleHitWindow, !kickbackLit {
                    setKickbackLit(true)
                    showBanner("INNER TUBE LIT")
                    buoyLastHit = -10
                } else {
                    buoyLastHit = gameTime
                }
            }
        case ChompPhysicsCategory.rollover:
            if let lane = node as? ChompRollover { rollOver(lane, at: gameTime) }
        default:
            break
        }
    }
}

extension ChompTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}

extension ChompTableScene {
    /// A shot event for the labs (a no-op in play and in Release builds). M5 v1: every switch passes here, so it also
    /// decides the skill shot (in every build).
    fileprivate func labEvent(_ name: String) {
        skillShotSwitch(name)
        cameoEvent(name)                                   // M5 v2
        #if DEBUG
        if let t = dropProbeT, !catchProbe { print(String(format: "DROPEV %d %.2f ", Int(t / 2), t.truncatingRemainder(dividingBy: 2)) + name) }
        shotLab?.event(name, at: shotLabTime)
        playLab?.shot(name, now: gameTime)                                    // M4 v1
        if Self.playLabShotObjectives.contains(name) { playLab?.objective(name, now: gameTime) }
        #endif
    }
}

#if DEBUG
// MARK: - M2 v6: the Shot Lab host (Table 06's pattern). The robot sweeps flip timings from the left, right and pier
// flippers and records the first shot each flip makes. Run in the Simulator: tools/shotlab_run.sh chomp
extension ChompTableScene: ShotLabHost {
    var shotLabTableName: String { "Chomp" }

    /// The shots a player aims for end a trial; slings, lanes, the spinner and the bumper are noted only.
    // M3 v23: "sharkTower" is minor (like the fin): a graze off Tgt1 no longer ends a trial before the ball reaches the loop.
    var shotLabMajorEvents: Set<String> { ["leftLoop", "waveRamp", "centerRamp", "rightRamp", "boat", "reel", "chumBucket", "harpoonGate", "fishPhone", "buoy"] }

    /// M2 v15: real gravity (v14) rolls the cradled ball down the flipper more slowly — the right flipper's shots moved
    /// to 0.51–0.58 s, the end of the shared 0.20–0.58 sweep — so CHOMP! sweeps to 0.85 s.
    var shotLabCradleDelays: ClosedRange<Double> { 0.20...0.85 }

    /// Left and right flippers cradled as on the other tables (40 pt out, above the raised flipper by the ball's
    /// radius + 5); the pier flipper's ball dropped onto its block with it held up (it settles at ~(490, 562),
    /// tools/chomp_pier_sim.py).
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = ChompTableLayout.flipperTravel - ChompTableLayout.flipperRestAngle
        let along: CGFloat = 40, above: CGFloat = ChompTableLayout.ballRadius + 5
        let l = ChompTableLayout.leftFlipperPivot
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: ChompTableLayout.mirrorSum - left.x, y: left.y)
        let ix = ChompTableLayout.laneGuideX + 25, iy = ChompTableLayout.laneGuideTop + 10     // the inlane's centre
        let r = ChompTableLayout.rightFlipperPivot
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left,
                                    starts: ShotLab.lowerStarts(pivot: l, pointsLeft: false, inlaneX: ix, inlaneTopY: iy)),
                ShotLab.FlipperSpec(name: "right", pivot: r, cradle: right,
                                    starts: ShotLab.lowerStarts(pivot: r, pointsLeft: true,
                                                                inlaneX: ChompTableLayout.mirrorSum - ix, inlaneTopY: iy)),
                ShotLab.FlipperSpec(name: "pier", pivot: ChompTableLayout.miniFlipperPivot, cradle: CGPoint(x: 500, y: 600))]
    }

    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        switch index {
        case 0: leftFlipper.isPressed = pressed
        case 1: rightFlipper.isPressed = pressed
        default: miniFlipper.isPressed = pressed
        }
    }

    func shotLabPlaceBall(at point: CGPoint) {
        let ball = ChompBall(at: point)
        addChild(ball)
        balls.append(ball)
    }

    func shotLabPlaceBall(at point: CGPoint, velocity: CGVector) {
        shotLabPlaceBall(at: point)
        balls.last?.physicsBody?.velocity = velocity
    }

    /// Every ball gone, the bank up, the up-posts down, nothing armed.
    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        resetBank()
        resetSharkTower()
        sharkRelightPending = false
        boat?.reset()
        fin?.reset()
        finHitPending = false
        bankRelightPending = false
        setUpPost(0, up: false)
        setUpPost(1, up: false)
        upPostsArmed = false
        upPostRaisePending = [false, false]
        buoyLastHit = -10
        innerTubeArmedUntil = -1
    }

    /// Where shots cross the mouths' height (the loop and the wave ramp at y ~885) and the lower shot line.
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "mouths", y: 860), ShotLab.Probe(name: "shotLine", y: 600)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }

    func debugStartShotLab() {
        stopPlayLab(saving: true)                  // M4 v1 review: a Shot Lab started mid Play Lab ends that run first
        isAttractMode = false
        removeAllBalls()
        shotLabTime = 0
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// The robot's frame: only what the physics and shot detection need (no serving, drains, saves or banners).
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
        miniFlipper.step(dt: dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        governInlanes()
        updateGates()
        updateSaveGate()
        updateSpinner(dt, now)
        updateReel(dt, now)
        updateBoat(now)
        updateFin(dt, now)
        if bankRelightPending { bankRelightPending = false; resetBank() }
        if sharkRelightPending { sharkRelightPending = false; resetSharkTower() }
        if lab.update(now: now) {
            game.banner = lab.progressText
        } else {
            let saved = lab.save(now: now)
            shotLab = nil
            physicsWorld.speed = 1
            shotLabResetTable()
            game.banner = "SHOT LAB DONE · \(lab.trials.count) TRIALS · \(saved)"
            ShotLab.quitIfLaunchedForLab()          // launched by tools/shotlab_run.sh chomp → quit
        }
    }
}
#endif

#if DEBUG
// MARK: - M2 v8: the flipper fan probe. Shot Lab's cradle sweep only sees the ball where it happens to be at each frame,
// and run 2 found a 101° → 106° jump between two neighbouring frames (ball 48.8 → 50.4 pt along the right flipper).
// This places the ball on the resting right flipper at fine steps along it (0.25 pt), rolling toward the tip, flips
// on the next frame and prints the launch: `FAN pass along speed degrees launchSpeed`. Then the app quits.
struct ChompFanProbe {
    var trials: [(along: CGFloat, roll: CGFloat)] = []
    var passes: [CGFloat] = [0.5, 1.0]            // physics speed at the Simulator's 60 fps: 120 Hz, then 60 Hz steps
    var pass = 0
    var i = 0
    var stage = 0
    var t: TimeInterval = 0
    var flipPoint = CGPoint.zero
}

extension ChompTableScene {
    func debugFanProbe() {
        isAttractMode = false
        removeAllBalls()
        var p = ChompFanProbe()
        for roll in [250, 400] as [CGFloat] {
            for k in 0...160 { p.trials.append((30 + CGFloat(k) * 0.25, roll)) }
        }
        fanProbe = p
        ChompFlipper.debugLog = true
        refreshCamera()
        print("FAN start \(p.trials.count) trials x \(p.passes.count) passes")
    }

    /// Where the ball sits on the resting right flipper `along` pt from the pivot (touching the top face).
    private func fanBallPoint(along: CGFloat) -> (point: CGPoint, down: CGVector) {
        let piv = ChompTableLayout.rightFlipperPivot
        let a = ChompTableLayout.flipperRestAngle
        let d = CGVector(dx: -cos(a), dy: -sin(a))                   // along the arm, toward the tip
        let n = CGVector(dx: d.dy, dy: -d.dx)                        // the top face's normal (up)
        let r0 = ChompTableLayout.flipperPivotRadius, r1 = ChompTableLayout.flipperTipRadius
        let half = r0 + (r1 - r0) * along / ChompTableLayout.flipperLength
        let off = half + ChompTableLayout.ballRadius + 0.5
        return (CGPoint(x: piv.x + along * d.dx + off * n.dx, y: piv.y + along * d.dy + off * n.dy), d)
    }

    fileprivate func updateFanProbe(_ realDt: CGFloat) {
        guard var p = fanProbe else { return }
        let speed = p.passes[p.pass]
        physicsWorld.speed = speed
        let dt = realDt * speed
        p.t += TimeInterval(dt)
        lastStep = dt
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        miniFlipper.step(dt: dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        switch p.stage {
        case 0:                                                      // flipper down and settled, then place the ball
            removeAllBalls()
            rightFlipper.isPressed = false
            if p.t >= 0.3 {
                let tr = p.trials[p.i]
                let (pt, d) = fanBallPoint(along: tr.along)
                let ball = ChompBall(at: pt)
                addChild(ball)
                balls.append(ball)
                ball.physicsBody?.velocity = CGVector(dx: d.dx * tr.roll, dy: d.dy * tr.roll)
                p.stage = 1; p.t = 0
            }
        case 1:                                                      // flip on the next frame
            rightFlipper.isPressed = true
            p.flipPoint = balls.first?.position ?? .zero
            p.stage = 2; p.t = 0
        default:                                                     // the launch: the first 60 pt off the flipper
            guard let b = balls.first else { p.stage = 0; p.t = 0; break }
            let piv0 = ChompTableLayout.rightFlipperPivot
            let reach = ChompTableLayout.flipperLength + ChompTableLayout.flipperPivotRadius + ChompTableLayout.ballRadius + 20
            // M2 v10: the launch is the ball's direction once it's out of the flipper's reach (it can ride the face).
            if hypot(b.position.x - piv0.x, b.position.y - piv0.y) >= reach || p.t > 0.6 {
                let v = b.physicsBody?.velocity ?? .zero
                let dx = v.dx, dy = v.dy
                let tr = p.trials[p.i]
                let piv = ChompTableLayout.rightFlipperPivot
                let a = ChompTableLayout.flipperRestAngle
                let along = (p.flipPoint.x - piv.x) * -cos(a) + (p.flipPoint.y - piv.y) * -sin(a)
                // M3 v23: + where the ball is as it leaves the flipper's reach (x y), to extend each shot to the loop.
                print(String(format: "FAN %.1f %.2f %.0f %.2f %.0f %.2f %.1f %.1f", Double(speed), Double(tr.along), Double(tr.roll),
                             Double(atan2(dy, dx) * 180 / .pi), Double(hypot(v.dx, v.dy)), Double(along),
                             Double(b.position.x), Double(b.position.y)))
                rightFlipper.isPressed = false
                p.stage = 0; p.t = 0; p.i += 1
                if p.i >= p.trials.count {
                    p.i = 0; p.pass += 1
                    if p.pass >= p.passes.count {
                        print("FAN done")
                        fanProbe = nil
                        physicsWorld.speed = 1
                        removeAllBalls()
                        ShotLab.quitIfLaunchedForLab()
                        return
                    }
                }
            }
        }
        fanProbe = p
    }
}
#endif

#if DEBUG
// MARK: - M2 v15: the pier probe (`-shotlab chomp -shotlab-scenario pierprobe`). Shot Lab run 11 (gravity −6.0) found the
// pier's dropped ball sitting at ~(503, 563), inside the plastic's outline, never reaching the flipper. This replays the
// sweep's set-up — the pier flipper raised, a ball dropped at (500, 600), held 1.2 s, the flipper let down — and prints
// `PIER t phase x y vx vy` every 50 ms, then quits.
extension ChompTableScene {
    func debugPierProbe() {
        isAttractMode = false
        removeAllBalls()
        pierProbeT = 0
        miniFlipper.isPressed = true
        print("PIER start gravity \(physicsWorld.gravity.dy)")
    }

    fileprivate func updatePierProbe(_ dt: CGFloat) {
        guard let t0 = pierProbeT else { return }
        let t = t0 + Double(dt)
        pierProbeT = t
        leftFlipper.step(dt: dt); rightFlipper.step(dt: dt); miniFlipper.step(dt: dt)
        handBallsToSwingingFlippers()
        if t0 < 0.3, t >= 0.3 { shotLabPlaceBall(at: CGPoint(x: 500, y: 600)) }
        if t0 < 1.5, t >= 1.5 { miniFlipper.isPressed = false }
        if Int(t0 / 0.05) != Int(t / 0.05), let b = balls.first {
            let v = b.physicsBody?.velocity ?? .zero
            print(String(format: "PIER %.2f %@ %.1f %.1f %.0f %.0f flip %.1f", t, t < 1.5 ? "held" : "down",
                         Double(b.position.x), Double(b.position.y), Double(v.dx), Double(v.dy),
                         Double(miniFlipper.zRotation * 180 / .pi)))
        }
        if t > 3.0 { print("PIER done"); pierProbeT = nil; ShotLab.quitIfLaunchedForLab() }
    }

    // MARK: M3 v13: the drop probe (`-shotlab chomp -shotlab-scenario dropprobe`): replays stuck-test drops that ended
    // at (505.7, 1150.5) and prints `DROP i t x y vx vy layer` every 0.1 s, 8 s each.
    private static let probeDrops: [(CGPoint, CGVector)] = [
        (CGPoint(x: 528, y: 983), CGVector(dx: 1022, dy: 2575)), (CGPoint(x: 533, y: 983), CGVector(dx: 1022, dy: 2575)),
        (CGPoint(x: 522, y: 983), CGVector(dx: 1022, dy: 2575)), (CGPoint(x: 528, y: 983), CGVector(dx: 700, dy: 2600)),
        (CGPoint(x: 567, y: 600), CGVector(dx: 0, dy: 1500)), (CGPoint(x: 567, y: 600), CGVector(dx: 0, dy: 1800)),
        (CGPoint(x: 567, y: 600), CGVector(dx: 0, dy: 2200)),
        // M3 v22: loop balls in the channel going up, round the U-turn and down the harpoon lane.
        (CGPoint(x: 88, y: 990), CGVector(dx: -150, dy: 900)), (CGPoint(x: 88, y: 990), CGVector(dx: -250, dy: 1400)),
        (CGPoint(x: 88, y: 990), CGVector(dx: -350, dy: 2000))]
        // M5 v1: plunges from the plunger's top at 1,040 → 2,300 pt/s in 30s (the whole pull), drops 10…, to see which
        // first switch each one makes (DROPEV lines) for the skill shot.
        + stride(from: 1040, through: 2300, by: 30).map { (CGPoint(x: 568, y: 140), CGVector(dx: 0, dy: CGFloat($0))) }
        // M5 wall probe (Play Lab 03-10-05Z: a ball left the table at (-33, 923)): the reconstructed right-flipper shot
        // ((264, 404) at 107.7°, 3,000 / 3,300 / 3,500 pt/s), then a fan from in front of Tgt1 at the harpoon lane's
        // outer wall (x 20) between the quickshot gate's ends, 2,500 and 3,500 pt/s.
        + [3000, 3300, 3500].map { (v: CGFloat) in
            let a = 107.7 * CGFloat.pi / 180
            return (CGPoint(x: 264, y: 404), CGVector(dx: v * cos(a), dy: v * sin(a))) }
        + stride(from: 140, through: 175, by: 5).flatMap { (deg: Int) in
            [2500, 3500].map { (v: CGFloat) in
                let a = CGFloat(deg) * CGFloat.pi / 180
                return (CGPoint(x: 150, y: 790), CGVector(dx: v * cos(a), dy: v * sin(a))) } }
        // M5 v5d: straight-up shots at the boat's left post / funnel (Play Lab 13-58-20Z stuck at (321, 1058)).
        + stride(from: 316, through: 330, by: 2).flatMap { (x: Int) in
            [2500, 3200].map { (v: CGFloat) in (CGPoint(x: CGFloat(x), y: 900), CGVector(dx: -20, dy: v)) } }

    func debugDropProbe() {
        isAttractMode = false
        removeAllBalls()
        dropProbeT = 0
        catchProbe = false
        print("DROP start")
    }

    // MARK: M4 v2: the catch probe (`-shotlab chomp -shotlab-scenario catchprobe`): the right flipper held up the whole
    // time (a Play Lab catch), balls dropped onto it from above and fed down the right inlane; prints `CATCH i t x y vx vy`
    // every 0.05 s, 2.5 s each — where a held flipper settles a 30 pt ball (the robot's cradle test is 26 pt).
    private static var catchDrops: [(CGPoint, CGVector)] {
        var d: [(CGPoint, CGVector)] = []
        for x in stride(from: CGFloat(300), through: 390, by: 15) {
            for vy in [-300, -800, -1400] as [CGFloat] { d.append((CGPoint(x: x, y: 330), CGVector(dx: 0, dy: vy))) }
        }
        let ix = ChompTableLayout.mirrorSum - (ChompTableLayout.laneGuideX + 25), iy = ChompTableLayout.laneGuideTop + 10
        for v in [300, 600, 900, 1200] as [CGFloat] {
            d.append((CGPoint(x: ix, y: iy), CGVector(dx: -v * 0.45, dy: -v * 0.89)))
        }
        return d
    }

    func debugCatchProbe() {
        isAttractMode = false
        removeAllBalls()
        dropProbeT = 0
        catchProbe = true
        print("CATCH start \(Self.catchDrops.count) drops")
    }

    fileprivate func updateDropProbe(_ dt: CGFloat) {
        guard let t0 = dropProbeT else { return }
        let t = t0 + Double(dt)
        dropProbeT = t
        let span = catchProbe ? 2.5 : 2.0
        let i = Int(t / span), i0 = Int(t0 / span)
        updateGates()                              // (the gate is per ball; update() is skipped while probing)
        let drops = catchProbe ? Self.catchDrops : Self.probeDrops
        if i >= drops.count { print(catchProbe ? "CATCH done" : "DROP done"); dropProbeT = nil; ShotLab.quitIfLaunchedForLab(); return }
        if catchProbe {                            // M4 v2: the right flipper held up, as the robot holds it to catch
            rightFlipper.isPressed = true
            leftFlipper.step(dt: dt); rightFlipper.step(dt: dt); miniFlipper.step(dt: dt)
            handBallsToSwingingFlippers()
            if Int(t0 / 0.05) != Int(t / 0.05) || i != i0, let b = balls.first {
                let v = b.physicsBody?.velocity ?? .zero
                print(String(format: "CATCH %d %.2f %.1f %.1f %.0f %.0f", i, t.truncatingRemainder(dividingBy: span),
                             Double(b.position.x), Double(b.position.y), Double(v.dx), Double(v.dy)))
            }
            if i != i0 || t0 == 0 {
                removeAllBalls()
                shotLabPlaceBall(at: drops[i].0, velocity: drops[i].1)
            }
            return
        }
        if i != i0 || t0 == 0 {
            removeAllBalls()
            shotLabPlaceBall(at: drops[i].0, velocity: drops[i].1)
        }
        if Int(t0 / 0.01) != Int(t / 0.01), let b = balls.first {
            let v = b.physicsBody?.velocity ?? .zero
            print(String(format: "DROP %d %.2f %.1f %.1f %.0f %.0f %@ cat %u mask %u", i, t.truncatingRemainder(dividingBy: 2),
                         Double(b.position.x), Double(b.position.y), Double(v.dx), Double(v.dy), "\(b.layer)",
                         b.physicsBody?.categoryBitMask ?? 0, b.physicsBody?.collisionBitMask ?? 0))
        }
    }
}
#endif

#if DEBUG
// MARK: - M4 v1: the Play Lab host (Table 06's pattern). Robot players at four skills play whole games on the grey box.
// No rules yet, so the objectives are the shots and the M2–M3 placeholder banners; the report's job here is drains,
// stuck balls and which shots get made before the layout is locked.
extension ChompTableScene: PlayLabHost {
    var playLabTableName: String { "Chomp" }
    var playLabBallRadius: CGFloat { ChompTableLayout.ballRadius }
    var playLabVariantCount: Int { 1 }

    /// Shot events that count as objectives the first time each game (labEvent reports them).
    static let playLabShotObjectives: Set<String> = ["leftLoop", "waveRamp", "centerRamp", "rightRamp", "boat", "reel",
                                                      "fin", "chumBucket", "harpoonGate", "buoy"]

    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "centerRamp", text: "Make the center ramp"),
         PlayObjective(name: "boat", text: "Hit the boat's captive ball"),
         PlayObjective(name: "chumBucket", text: "Hit the chum bucket"),
         PlayObjective(name: "waveRamp", text: "Make the wave ramp"),
         PlayObjective(name: "rightRamp", text: "Make the right ramp"),
         PlayObjective(name: "reel", text: "Spin the fishing reel"),
         PlayObjective(name: "leftLoop", text: "Make the left loop"),
         PlayObjective(name: "harpoonGate", text: "Shoot through the harpoon gate"),
         PlayObjective(name: "harpoonLane", text: "Come down the harpoon lane"),
         PlayObjective(name: "fin", text: "Drop the fin"),
         PlayObjective(name: "buoy", text: "Hit the buoy"),
         PlayObjective(name: "fishPhoneBank", text: "Complete the Fish Phone bank"),
         PlayObjective(name: "sharkTowerSet", text: "Complete the shark tower"),
         PlayObjective(name: "innerTubeLit", text: "Light the inner tube (buoy)"),
         PlayObjective(name: "innerTubeSave", text: "The inner tube saves a ball"),
         PlayObjective(name: "ballSaved", text: "The ball save saves a ball"),
         PlayObjective(name: "tilt", text: "Tilt"),
         PlayObjective(name: "skillShot1", text: "Skill shot 1: plunge onto the bumper"),
         PlayObjective(name: "skillShot2", text: "Skill shot 2: plunge into the lane above the mini flipper"),
         PlayObjective(name: "skillShot3", text: "Skill shot 3: the flashing Fish Phone target first"),
         PlayObjective(name: "cameoLit", text: "Light a cameo at the boat"),
         PlayObjective(name: "cameoStarted", text: "Start one of Kevin's cameos"),
         PlayObjective(name: "cameoJackpot", text: "Collect a cameo jackpot at the fin"),
         PlayObjective(name: "cameoBackup", text: "Collect a backup jackpot at the boat"),
         PlayObjective(name: "touristSaved", text: "Save a tourist"),
         PlayObjective(name: "meltdownStarted", text: "Start a Mayor Meltdown (3 tourists at a beach)"),
         PlayObjective(name: "beachClosed", text: "Collect a Mayor Meltdown (close a beach)"),
         PlayObjective(name: "extraBall", text: "Save 8 tourists: extra ball"),
         PlayObjective(name: "stinkLineFull", text: "Fill the Stink Line"),
         PlayObjective(name: "flamingo", text: "Harpoon a flamingo at the fin"),
         PlayObjective(name: "kmbStarted", text: "Start Kevin Multiball"),
         PlayObjective(name: "kmbJackpot", text: "Collect a Kevin jackpot"),
         PlayObjective(name: "flipLock", text: "Flip-lock a ball on the pier flipper"),
         PlayObjective(name: "addABall", text: "Refill the Stink Line in a multiball: add-a-ball")]
    }

    /// Flip delays = the middle of each Shot Lab window, 120 Hz (the default pass; the 60 Hz pass now only models the
    /// SKView fallback): left from shotlab-chomp-2026-11-20T23-19-22Z (v21; the left flipper's shots haven't moved
    /// since), right from 2026-11-21T15-13-32Z (v24). Bands of 3+ trials only (the right ramp, reel and loop are 1–2
    /// trial slivers from the cradle). Inlane feeds from shotlab-chomp-inlane-2026-11-21T15-38-42Z, 4 pt bins, 3+.
    var playLabFlippers: [PlayRobotFlipper] {
        let specs = shotLabFlippers
        let rest = ChompTableLayout.flipperRestAngle
        // M4 v2 (catch probe, build/t7_catchprobe_v2.txt): a 30 pt ball on the held-up flipper settles at (382, 252) —
        // 24–27 pt from the Shot Lab's drop point, on the edge of the robot's 26 pt "caught" test (run 1: ~0 catches).
        // The robot's cradle is where the ball really rests (the Shot Lab's trials also start from there: 1.2 s settle).
        let rightRest = CGPoint(x: 382, y: 252)
        let leftRest = CGPoint(x: ChompTableLayout.mirrorSum - rightRest.x, y: rightRest.y)
        return [PlayRobotFlipper(name: "left", pivot: specs[0].pivot, length: ChompTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: false, cradle: leftRest, rightButton: false, upper: false,
                                 shots: [("centerRamp", 0.226), ("fishPhone", 0.371), ("boat", 0.470), ("sharkTower", 0.537),
                                         ("buoy", 0.579), ("chumBucket", 0.633)],
                                 inlane: [("buoy", 36, 39), ("chumBucket", 40, 43)]),
                PlayRobotFlipper(name: "right", pivot: specs[1].pivot, length: ChompTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: rightRest, rightButton: true, upper: false,
                                 shots: [("centerRamp", 0.408), ("chumBucket", 0.477), ("harpoonGate", 0.540),
                                         ("fishPhone", 0.581)],
                                 inlane: [("chumBucket", 28, 39)])]
    }

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
        return ["fishPhoneDown": bankDown.filter { $0 }.count, "sharkDown": sharkDown.filter { $0 }.count]
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

    /// Everything the robot needs to know this frame, and its buttons and plunger applied.
    /// M5 v5c: the robot's ACTION button (Aaron: "add an action button logic to Play Lab"; in the CHOMP! host, so the
    /// shared PlayLab.swift is untouched). Beginners never press it; intermediates use the inner tube; advanced and
    /// experts also flip-lock in Kevin Multiball:
    /// - inner tube: lit and ready, a floor ball falling down the left outlane will reach the kicker's trigger within
    ///   the 0.6 s armed window → ACTION;
    /// - flip-lock: in the multiball, not used this ball, a floor ball rolling down onto the pier block → hold right
    ///   (up to 1.5 s) so the pier flipper catches it; once it rests at the held spot → ACTION.
    fileprivate func robotActions(_ now: TimeInterval, _ lab: PlayLab) {
        guard let skill = lab.robot?.skill, skill != .beginner, !nudge.tilted else { pierCatchUntil = -1; return }
        let floor = balls.filter { $0.isOnFloor && !isOnPlunger($0) }
        if kickbackLit, !flipLocked, gameTime >= innerTubeReadyAt, gameTime > innerTubeArmedUntil {   // (a press would end a lock)
            for b in floor {
                let p = b.position, vy = b.physicsBody?.velocity.dy ?? 0
                guard p.x < ChompTableLayout.kickbackMaxX, vy < -50 else { continue }
                let toTrigger = p.y - ChompTableLayout.kickbackTriggerY
                if toTrigger > 0, toTrigger < -vy * 0.4 {
                    print(String(format: "LAB: RACTION %.3f innerTube | %.0f %.0f %.0f", lab.elapsed(now: now), p.x, p.y, vy))
                    actionPressed()
                    break
                }
            }
        }
        guard skill == .advanced || skill == .expert, kevin.multiballActive, !flipLockUsed, !flipLocked else {
            pierCatchUntil = -1
            return
        }
        if pierCatchUntil < now, floor.contains(where: { b in
            let p = b.position, vy = b.physicsBody?.velocity.dy ?? 0
            return p.x > 470 && p.x < 548 && p.y > 570 && p.y < 720 && vy < 0
        }) {
            pierCatchUntil = now + 1.5
        }
        if pierCatchUntil >= now, miniFlipper?.isPressed == true, floor.contains(where: { b in
            let v = b.physicsBody?.velocity ?? .zero
            return hypot(b.position.x - Self.flipLockSpot.x, b.position.y - Self.flipLockSpot.y) < 24 && hypot(v.dx, v.dy) < 120
        }) {
            print(String(format: "LAB: RACTION %.3f flipLock", lab.elapsed(now: now)))
            if flipLockAction() { pierCatchUntil = -1 }
        }
    }

    fileprivate func updatePlayLab(_ now: TimeInterval) {
        guard let lab = playLab else { return }
        if game.isGameOver || playLabNextAt != nil {
            if robotLeft || robotRight { robotLeft = false; robotRight = false; updateFlippers() }
            return
        }
        let view = PlayRobotView(now: now, balls: balls.map { b in
            PlayRobotView.Ball(position: b.position, velocity: b.physicsBody?.velocity ?? .zero, isUpper: !b.isOnFloor,
                               isHeld: false, onPlunger: isOnPlunger(b), id: ObjectIdentifier(b).hashValue)
        }, wanted: robotWanted(),
           skillPlunge: skillShotLive ? ChompTableLayout.skillPlungePull : nil)      // M5 v1: L1, the bumper
        runWatchdog(now, lab)
        guard let cmd = lab.frame(view) else { return }
        if let direction = cmd.nudge { applyNudge(direction) }
        robotActions(now, lab)                                         // M5 v5c: the host's ACTION button
        let cmdRight = cmd.right || pierCatchUntil >= now              // a pier catch for a flip-lock holds right
        if cmd.left != robotLeft || cmdRight != robotRight {
            // M4 v6: log each robot press with the lower balls, to match against the report's drains.
            if (cmd.left && !robotLeft) || (cmdRight && !robotRight) {
                let side = cmd.left && !robotLeft ? (cmdRight && !robotRight ? "both" : "left") : "right"
                let lows = view.balls.filter { !$0.onPlunger && $0.position.y < 480 }.map {
                    String(format: "%.0f %.0f %.0f %.0f", $0.position.x, $0.position.y, $0.velocity.dx, $0.velocity.dy)
                }
                print(String(format: "LAB: RFLIP %.3f ", lab.elapsed(now: now)) + side + " | " + lows.joined(separator: " | "))
            }
            robotLeft = cmd.left
            robotRight = cmdRight
            updateFlippers()
        }
        if let power = cmd.plunge, isBallOnPlunger {
            plungerPull = power * ChompTableLayout.plungerMaxPull
            releasePlunger()
        }
    }

    /// A ball off the table, or one that hasn't moved 4 pt in 5 s while not on the plunger or cradled (incl. the pier
    /// flipper held up), is recorded as an incident and served again (no ball lost).
    private func runWatchdog(_ now: TimeInterval, _ lab: PlayLab) {
        let w = ChompTableLayout.worldSize
        for ball in balls {
            let id = ObjectIdentifier(ball)
            let p = ball.position
            if !p.x.isFinite || !p.y.isFinite || p.x < -30 || p.x > w.width + 30 || p.y > w.height + 30 {
                watchdogRescue("offTable", ball, now, lab)
                continue
            }
            if isOnPlunger(ball) || isCradled(ball) || p.y < 0 {
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

    /// A ball resting on a raised flipper (left, right or the pier) is being held on purpose.
    private func isCradled(_ ball: ChompBall) -> Bool {
        let specs = shotLabFlippers
        for (i, pressed) in [leftFlipper.isPressed, rightFlipper.isPressed, miniFlipper.isPressed].enumerated()
            where pressed && i < specs.count {
            // M4 v1 review: the pier's Shot Lab "cradle" (500, 600) is its drop point; a held ball rests at ~(490, 562).
            let c = i == 2 ? CGPoint(x: 490, y: 562) : specs[i].cradle
            if hypot(ball.position.x - c.x, ball.position.y - c.y) < 30 { return true }
        }
        return false
    }

    private func watchdogRescue(_ kind: String, _ ball: ChompBall, _ now: TimeInterval, _ lab: PlayLab) {
        let p = ball.position
        let x = p.x.isFinite ? Double(p.x) : -1, y = p.y.isFinite ? Double(p.y) : -1
        lab.incident(PlayIncident(kind: kind, x: x.rounded(), y: y.rounded(), upper: !ball.isOnFloor,
                                  time: lab.elapsed(now: now).rounded()))
        watchSpots[ObjectIdentifier(ball)] = nil
        removeBall(ball)
        if balls.isEmpty, nextBallAt == nil { nextBallAt = now + 0.5 }      // served again, no ball lost
        showBanner("WATCHDOG · \(kind == "stuck" ? "STUCK BALL" : "BALL OFF THE TABLE") AT \(Int(x)), \(Int(y))")
    }

    /// The shots the table wants, most wanted first (no lamps until the rules): unlit Fish Phone / shark tower
    /// targets, then the shots in the order a player learns them.
    private func robotWanted() -> [String] {
        var w: [String] = []
        // M5 v2: the cameos first — lit shots, then the boat (lights / boosts them).
        for lamp in [ChompCameos.Lamp.jackpot, .final, .blueFast, .blue, .white] {
            for s in ChompShot.allCases where cameos.lamp(s) == lamp && !w.contains(s.rawValue) { w.append(s.rawValue) }
        }
        // M5 v3: a Mayor Meltdown shot first of all, then beaches with tourists waiting.
        if let m = beaches.meltdownShot { w.insert(m.rawValue, at: 0) }
        for s in ChompShot.beach where (beaches.lit[s] ?? 0) > 0 && !w.contains(s.rawValue) { w.append(s.rawValue) }
        // M5 v4: Kevin's lit shots (jackpot, start, red, yellow), the fin for a flamingo, the bucket for the line.
        for lamp in [ChompKevin.Lamp.jackpot, .start, .red, .yellow] {
            for s in ChompShot.allCases where kevin.lamp(s) == lamp && !w.contains(s.rawValue) { w.append(s.rawValue) }
        }
        if kevin.stage == .finUp, !w.contains("fin") { w.insert("fin", at: 0) }
        if kevin.stage == .idle || kevin.stage == .line, !w.contains("chumBucket") { w.append("chumBucket") }
        if !cameos.isRunning, !w.contains("boat") { w.append("boat") }
        if bankDown.contains(false) { w.append("fishPhone") }
        if sharkDown.contains(false) { w.append("sharkTower") }
        w += ["centerRamp", "boat", "chumBucket", "harpoonGate", "buoy", "fishPhone", "sharkTower"]
        return w
    }

    /// Placeholder banners double as objectives: the first of each per game is what the report shows.
    fileprivate func labObjective(forBanner text: String) {
        guard let lab = playLab else { return }
        let name: String?
        switch text {
        case "FISH PHONE": name = "fishPhoneBank"
        case "SHARK TOWER": name = "sharkTowerSet"
        case "HARPOON LANE": name = "harpoonLane"
        case "INNER TUBE LIT": name = "innerTubeLit"
        case "INNER TUBE SAVE": name = "innerTubeSave"
        case "BALL SAVED": name = "ballSaved"
        case "TILT": name = "tilt"
        case _ where text.hasPrefix("SKILL SHOT 1"): name = "skillShot1"
        case _ where text.hasPrefix("SKILL SHOT 2"): name = "skillShot2"
        case _ where text.hasPrefix("SKILL SHOT 3"): name = "skillShot3"
        case "CAMEO LIT": name = "cameoLit"
        case _ where ChompCameos.Kind.allCases.contains(where: { $0.title == text }): name = "cameoStarted"
        case _ where text.hasPrefix("CAMEO JACKPOT"): name = "cameoJackpot"
        case _ where text.hasPrefix("BACKUP JACKPOT"): name = "cameoBackup"
        case _ where text.hasPrefix("TOURIST SAVED") || text.contains("TOURISTS SAVED"): name = "touristSaved"
        case _ where text.hasPrefix("MAYOR MELTDOWN ·"): name = "meltdownStarted"
        case _ where text.hasPrefix("BEACH CLOSED"): name = "beachClosed"
        case "EXTRA BALL": name = "extraBall"
        case _ where text.hasPrefix("FLIP-LOCK ·"): name = "flipLock"
        case "ADD-A-BALL": name = "addABall"
        case _ where text.hasPrefix("STINK LINE FULL"): name = "stinkLineFull"
        case _ where text.hasPrefix("FLAMINGO ") && text.contains("/"): name = "flamingo"
        case _ where ChompKevin.titles.contains(text): name = "kmbStarted"
        case _ where text.hasPrefix("KEVIN JACKPOT") || text.contains(" COMPLETE · "): name = "kmbJackpot"
        default: name = nil
        }
        if let name { lab.objective(name, now: gameTime) }
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
        lab.endGame(score: game.score, ballsPlayed: ChompGameState.ballsPerGame + game.extraBallsEarned - game.ballsLeft + (over ? 0 : 1),
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
