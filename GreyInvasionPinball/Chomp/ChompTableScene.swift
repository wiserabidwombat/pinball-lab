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
    #if DEBUG
    /// M2 v6: the Shot Lab robot (shared ShotLab, Table 06's host pattern) and its own clock.
    fileprivate var shotLab: ShotLab?
    fileprivate var shotLabTime: TimeInterval = 0
    /// M2 v8: the flipper fan probe (`-shotlab chomp -shotlab-scenario fanprobe`).
    fileprivate var fanProbe: ChompFanProbe?
    /// M2 v15: the pier probe's clock (nil when it isn't running).
    fileprivate var pierProbeT: Double?
    fileprivate var dropProbeT: Double?          // M3 v13: the drop probe
    #endif
    private var lastSpinSound: TimeInterval = 0
    private var quickshotLanes: [ChompRollover] = []
    private var bankTargets: [SKShapeNode] = []
    private var bankDown = [false, false, false]
    private var bankRelightPending = false
    // The ball save: once per player ball, on the plunger and for 10 s after launch.
    private var ballSaveUsed = false
    private var launchedAt: TimeInterval?
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
    /// Orange = anything one-way (the skill's grey-box colours).
    static let oneWayColor = SKColor(red: 1.0, green: 0.62, blue: 0.24, alpha: 1)
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
        addLaunchGate()
    }

    /// The playfield floor inside the outer wall.
    private func addFloor() {
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
            labEvent("leftLoop")
            game.add(ChompPoints.loop)
            sfx(.orbit)
            showBanner("LEFT LOOP")
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
        addWall(points: ChompTableLayout.rampIsland)       // M3 v8: the real plastics that close the stuck-ball traps
        addWall(points: ChompTableLayout.bankWedge)
        addReel()
        let b = ChompCaptiveBall(mouth: ChompTableLayout.boatMouth, heading: .pi / 2,
                                 length: ChompTableLayout.boatChannelLength, halfWidth: ChompTableLayout.boatHalfWidth,
                                 postRadius: ChompTableLayout.boatPostRadius, lip: ChompTableLayout.boatLip)
        addChild(b)
        boat = b
    }

    /// M3 v9: the fishing reel — the keyhole's blue blocks and the disc over its round end.
    private func addReel() {
        addWall(points: ChompTableLayout.reelLeftBlock)
        addWall(points: ChompTableLayout.reelRightBlock)
        let r = ChompReel(centre: ChompTableLayout.reelCentre, radius: ChompTableLayout.reelDiscRadius)
        addChild(r)
        reel = r
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
        labEvent("boat")
        game.add(ChompPoints.boat)
        hitHaptic.impactOccurred()
        showBanner("BOAT")
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
        labEvent(event)
        game.add(points)
        hitHaptic.impactOccurred()
        sfx(.ramp)
        showBanner(banner)
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
                showBanner("UP-POSTS ARMED · TEST")
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
        if let t = launchedAt { return gameTime - t <= ChompTableLayout.ballSaveSeconds }
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
        guard isBuilt, !isAttractMode, !isGamePaused, !game.isGameOver, kickbackLit, gameTime >= innerTubeReadyAt else { return }
        innerTubeArmedUntil = gameTime + ChompTableLayout.innerTubeArmSeconds
        innerTubeReadyAt = gameTime + ChompTableLayout.innerTubeCooldown
        hitHaptic.impactOccurred(intensity: 0.5)
    }

    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: "T7 M3 v14d")
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
        let text = "\(fps)T7 M2 v15 \(effectiveCameraMode.tag) · \(speed)"
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
        boat?.reset()
        reel?.reset()
        ballSaveUsed = false
        game.reset()
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + ChompTableLayout.bannerSeconds
    }

    private func sfx(_ s: MonSound) {
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
        var left = activeTouches.values.contains(.left) || padLeft
        var right = activeTouches.values.contains(.right) || padRight
        if nudge.tilted { left = false; right = false }      // tilted: dead flippers until the next ball
        if left && !leftFlipper.isPressed { sfx(.flipper) }
        if right && !rightFlipper.isPressed { sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
        miniFlipper?.isPressed = right                       // the pier mini-flipper shares the right button
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
            let speed = ChompTableLayout.minLaunchSpeed
                + power * (ChompTableLayout.maxLaunchSpeed - ChompTableLayout.minLaunchSpeed)
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
        let step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
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
        if bankRelightPending { bankRelightPending = false; resetBank() }

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
        updateKickback()

        // Drain: remove every ball off the bottom; a ball is lost only when none are left.
        let drained = balls.filter { $0.position.y < -ChompTableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            if balls.isEmpty, nextBallAt == nil {
                if ballSaveNow, !nudge.tilted {
                    ballSaveUsed = true
                    game.ballSaved()
                    showBanner("BALL SAVED"); sfx(.ballSave)
                    bigHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else {
                    ballSaveUsed = false             // the next ball gets its own save
                    cameraRig.shake(strength: 4, duration: 0.3)
                    sfx(.drain)
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
            }
        case ChompPhysicsCategory.target:
            // M2 v1: the Fish Phone bank (placeholder: all three → "FISH PHONE", then they relight).
            if let i = bankTargets.firstIndex(where: { $0 === node }) {
                labEvent("fishPhone")
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
    /// A shot event for the labs (a no-op in play and in Release builds).
    fileprivate func labEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        #endif
    }
}

#if DEBUG
// MARK: - M2 v6: the Shot Lab host (Table 06's pattern). The robot sweeps flip timings from the left, right and pier
// flippers and records the first shot each flip makes. Run in the Simulator: tools/shotlab_run.sh chomp
extension ChompTableScene: ShotLabHost {
    var shotLabTableName: String { "Chomp" }

    /// The shots a player aims for end a trial; slings, lanes, the spinner and the bumper are noted only.
    var shotLabMajorEvents: Set<String> { ["leftLoop", "waveRamp", "centerRamp", "rightRamp", "boat", "reel", "harpoonGate", "fishPhone", "buoy"] }

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
        boat?.reset()
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
        if bankRelightPending { bankRelightPending = false; resetBank() }
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
                print(String(format: "FAN %.1f %.2f %.0f %.2f %.0f %.2f", Double(speed), Double(tr.along), Double(tr.roll),
                             Double(atan2(dy, dx) * 180 / .pi), Double(hypot(v.dx, v.dy)), Double(along)))
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
        (CGPoint(x: 567, y: 600), CGVector(dx: 0, dy: 2200))]

    func debugDropProbe() {
        isAttractMode = false
        removeAllBalls()
        dropProbeT = 0
        print("DROP start")
    }

    fileprivate func updateDropProbe(_ dt: CGFloat) {
        guard let t0 = dropProbeT else { return }
        let t = t0 + Double(dt)
        dropProbeT = t
        let i = Int(t / 2), i0 = Int(t0 / 2)
        updateGates()                              // (the gate is per ball; update() is skipped while probing)
        if i >= Self.probeDrops.count { print("DROP done"); dropProbeT = nil; ShotLab.quitIfLaunchedForLab(); return }
        if i != i0 || t0 == 0 {
            removeAllBalls()
            shotLabPlaceBall(at: Self.probeDrops[i].0, velocity: Self.probeDrops[i].1)
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
