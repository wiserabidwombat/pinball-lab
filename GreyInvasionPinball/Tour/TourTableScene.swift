// Pinball Lab Table 06 (Orbit: Grand Tour): the table scene. Milestone 1 = grey box of the new lower table: the
// proven walls, flippers and slings of Tables 02–04, an O-R-B-T rollover in each inlane and outlane (lane change
// with the flippers; all four light the rocket post and raise the multiplier), the kickback in the left outlane, the
// pop-up rocket post between the flippers, the plunger and one-way launch gate, the three camera modes, 3 balls and
// the ball save. The upper table is open floor until milestone 3.
// Built from the Lamplight's milestone-1 scene, with Monsoon's current drawing host, nudge, flip assist and inlane
// speed limit. Monsoon's sounds stand in until the table's own (juice milestone).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class TourTableScene: SKScene, RendererHostedScene {
    private enum Control { case left, right, plunger }

    private let game: TourGameState
    private let settings: GameSettings
    private let cameraRig = TourCameraRig()
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

    private var balls: [TourBall] = []
    private var servedBall: TourBall?
    private var slingshots: [TourSlingshot] = []
    private var leftFlipper: TourFlipper!
    private var rightFlipper: TourFlipper!
    private var plunger: SKShapeNode!
    private var launchGateFlap: SKNode?
    private var launchGateClosedAngle: CGFloat = 0
    private var isBuilt = false
    private let hitHaptic = Haptic(style: .medium)
    private let bigHaptic = Haptic(style: .heavy)

    // The O-R-B-T lanes, the kickback and the rocket post (milestone 1).
    private var rollovers: [TourRollover] = []
    private var lanesResetAt: TimeInterval?
    private var kickbackLit = true
    private var kickbackLamp: SKShapeNode?
    private var rocketPost: SKShapeNode?
    private var rocketPostUp = false
    private var rocketPostDropAt: TimeInterval?
    private var rocketPostRaisePending = false     // raised in update(), never inside a contact callback
    // Milestone 2: the lower half's targets and scoops (placeholder scoring).
    /// The rocket pad's blast door (the bash target), the countdown lamps and the rocket toy (v10).
    private var blastDoor: TourDropTarget!
    private var blastWings: [TourDropTarget] = []
    private var countdownLeft = TourTableLayout.countdownHits
    private var countdownLampNodes: [SKShapeNode] = []
    private var rocketToy: SKNode!
    private var lastRocketHit: TimeInterval = -1
    private var sampleBank: [TourDropTarget] = []
    private var rocketStandups: [TourStandup] = []
    private var pendingDrops: [TourDropTarget] = []
    private var missionScoop: TourScoop!
    private var roverScoop: TourScoop!
    private var roverLit = false
    private var countdownResetAt: TimeInterval?
    private var sampleResetAt: TimeInterval?
    private var rocketClearAt: TimeInterval?
    // Milestone 3 v1: the orbits' spinners (left, right) and the last spinner tick (one sound per 50 ms).
    private var spinners: [TourSpinner] = []
    private var lastSpinSound: TimeInterval = -1
    // Milestone 3 v2: the S-T-A-R top lanes (their own lane change and completion blink) and the bumper nest.
    private var starLanes: [TourRollover] = []
    private var starResetAt: TimeInterval?
    private var bumpers: [TourBumper] = []
    /// M3 v3: the plunge flap's drawn blade (solid per ball, for the served ball only).
    private var plungeFlap: SKShapeNode?
    #if DEBUG
    /// DEBUG plunge probe (`-shotlab grandtour -shotlab-scenario plungeprobe`): powers left, current power, trial time.
    fileprivate var plungeProbe: (powers: [CGFloat], power: CGFloat, t: CGFloat, logT: CGFloat, fired: Bool)?
    #endif
    /// M3 v7: the Moon ramp (climbs to the raised Moon's crater, wire back down to the left inlane).
    private var moonRamp: TourRamp?
    /// M3 v14: the Saturn ramp (the Moon's mirror on the left flipper's ~72° band).
    private var saturnRamp: TourRamp?
    private var ramps: [TourRamp] { [moonRamp, saturnRamp].compactMap { $0 } }
    /// M3 v3: the top orbit gate's drawn flap (swings when a ball passes it going left).
    private var orbitGateFlap: SKShapeNode?
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

    #if DEBUG
    /// M2 v19: the Shot Lab robot (ShotLab.swift), as on Tables 02–05. Its own clock runs at the pass's physics speed.
    private var shotLab: ShotLab?
    private var shotLabTime: TimeInterval = 0
    #endif

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
            if isGamePaused { releaseAllControls() } else { padAArmed = false }
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
    static let rocketColor = SKColor(red: 1.0, green: 0.32, blue: 0.28, alpha: 1)
    static let lampOnColor = SKColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1)
    static let lampOffColor = SKColor(red: 0.14, green: 0.28, blue: 0.18, alpha: 0.9)

    init(game: TourGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: TourTableLayout.worldSize)
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
        physicsWorld.gravity = CGVector(dx: 0, dy: TourTableLayout.gravity)
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
        addWall(points: TourTableLayout.outerWall,
                friction: TourTableLayout.railFriction, restitution: TourTableLayout.railRestitution)
        addWall(points: TourTableLayout.leftLaneGuide)
        addWall(points: TourTableLayout.leftOutlaneWall)
        addWall(points: TourTableLayout.leftOutlanePostRail)
        addWall(points: TourTableLayout.rightOutlanePostRail)
        addWall(points: TourTableLayout.rightOutlaneWall)
        addWall(points: TourTableLayout.rightApron)
        addWall(points: TourTableLayout.rightLaneGuide)

        for s in [TourTableLayout.leftSling, TourTableLayout.rightSling] {
            let sling = TourSlingshot(top: s.top, corner: s.corner, tip: s.tip, artBaked: false,
                                      kickFrom: TourTableLayout.slingKickFrom, kickTo: TourTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = TourFlipper(side: .left, pivot: TourTableLayout.leftFlipperPivot)
        rightFlipper = TourFlipper(side: .right, pivot: TourTableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)

        for (i, x) in TourTableLayout.laneRolloverXs.enumerated() {
            let lane = TourRollover(letter: TourTableLayout.laneLetters[i], x: x)
            addChild(lane)
            rollovers.append(lane)
        }
        addLowerHalf()
        addOrbits()
        addTopLanes()
        addMoon()
        addSaturn()
        addKET()
        addPlungeFlap()
        addOrbitGate()
        addKickbackLamp()
        addRocketPost()
        addPlunger()
        addLaunchGate()
    }

    /// Milestone 2 (Concept C, v10): the rocket pad (blast door + Mission Control) at the back of the open centre, the ROCKET standups up the
    /// right wall, and the Mars bunker (sample bank in front of the rover scoop) on the left wall.
    private func addLowerHalf() {
        addWall(points: TourTableLayout.rocketPad)
        addWall(points: TourTableLayout.bunkerRoof)
        addWall(points: TourTableLayout.bunkerFloor)
        addWall(points: TourTableLayout.rocStructure)
        blastDoor = TourDropTarget(at: TourTableLayout.blastDoor, normal: -.pi / 2, label: "",
                                   size: TourTableLayout.blastDoorSize,
                                   color: SKColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1))
        addChild(blastDoor)
        for w in TourTableLayout.rocketWings {
            let wing = TourDropTarget(at: w.center, normal: w.normal, label: "", size: TourTableLayout.rocketWingSize,
                                      color: SKColor(red: 0.60, green: 0.64, blue: 0.72, alpha: 1))
            addChild(wing)
            blastWings.append(wing)
        }
        for (i, c) in TourTableLayout.countdownLamps.enumerated() {
            let lamp = SKShapeNode(circleOfRadius: 6)
            lamp.position = c
            lamp.fillColor = SKColor(red: 1.0, green: 0.70, blue: 0.28, alpha: 1)
            lamp.strokeColor = SKColor(white: 1, alpha: 0.5)
            lamp.lineWidth = 1
            lamp.zPosition = -17
            let n = SKLabelNode(text: "\(TourTableLayout.countdownHits - i)")
            n.fontName = "AvenirNext-Bold"; n.fontSize = 8; n.verticalAlignmentMode = .center
            n.fontColor = SKColor(white: 0.1, alpha: 1)
            lamp.addChild(n)
            addChild(lamp)
            countdownLampNodes.append(lamp)
        }
        // The rocket toy: a tall triangle on the pad (grey box). It lifts off on the last countdown hit.
        let rocketPath = CGMutablePath()
        rocketPath.move(to: CGPoint(x: 0, y: 36)); rocketPath.addLine(to: CGPoint(x: 11, y: -8))
        rocketPath.addLine(to: CGPoint(x: -11, y: -8)); rocketPath.closeSubpath()
        let rocket = SKShapeNode(path: rocketPath)
        rocket.fillColor = SKColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1)
        rocket.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1)
        rocket.lineWidth = 1.5
        rocket.position = TourTableLayout.rocketToy
        rocket.zPosition = 25
        addChild(rocket)
        rocketToy = rocket
        showCountdown()
        for (i, c) in TourTableLayout.sampleCenters.enumerated() {
            let t = TourDropTarget(at: c, normal: TourTableLayout.sampleNormal, label: "\(i + 1)",
                                   color: SKColor(red: 0.90, green: 0.42, blue: 0.29, alpha: 1))
            addChild(t)
            sampleBank.append(t)
        }
        for (i, c) in TourTableLayout.rocketCenters.enumerated() {
            let s = TourStandup(at: c, normal: TourTableLayout.rocketNormal, label: TourTableLayout.rocketLabels[i])
            addChild(s)
            rocketStandups.append(s)
        }
        missionScoop = TourScoop(at: TourTableLayout.missionScoop, ejectVelocity: TourTableLayout.missionEject,
                                 points: TourPoints.missionControl)
        roverScoop = TourScoop(at: TourTableLayout.roverScoop, ejectVelocity: TourTableLayout.roverEject,
                               points: TourPoints.rover)
        addChild(missionScoop)
        addChild(roverScoop)
    }

    /// Milestone 3 v1: the two orbit lanes' inner walls (smooth rails, like the outer wall, so a ball keeps its speed
    /// round the top) and a spinner across each lane above its mouth.
    private func addOrbits() {
        for inner in [TourTableLayout.leftOrbitInner, TourTableLayout.rightOrbitInner] {
            addWall(points: inner, friction: TourTableLayout.railFriction, restitution: TourTableLayout.railRestitution)
        }
        for line in [TourTableLayout.leftSpinnerLine, TourTableLayout.rightSpinnerLine] {
            let s = TourSpinner(from: line.a, to: line.b)
            addChild(s)
            spinners.append(s)
        }
    }

    /// Milestone 3 v2: the S-T-A-R lanes (five short posts, a rollover with its lamp in each lane) and the bumper nest.
    private func addTopLanes() {
        for x in TourTableLayout.starPostXs {
            addWall(points: [CGPoint(x: x, y: TourTableLayout.starPostBottom), CGPoint(x: x, y: TourTableLayout.starPostTop)])
        }
        for (i, x) in TourTableLayout.starLaneXs.enumerated() {
            let lane = TourRollover(letter: TourTableLayout.starLetters[i], x: x, y: TourTableLayout.starRolloverY,
                                    lampDy: TourTableLayout.starLampY - TourTableLayout.starRolloverY)
            addChild(lane)
            starLanes.append(lane)
        }
        for c in TourTableLayout.bumperCenters {
            let b = TourBumper(at: c)
            addChild(b)
            bumpers.append(b)
        }
    }

    /// M3 v11: K-E-T, the second half of R-O-C-K-E-T (rocketStandups 3–5), on its backboard right of the rocket.
    private func addKET() {
        addWall(points: TourTableLayout.ketBackboard)
        for (i, c) in TourTableLayout.ketCenters.enumerated() {
            let s = TourStandup(at: c, normal: TourTableLayout.ketNormal, label: TourTableLayout.rocketLabels[3 + i])
            addChild(s)
            rocketStandups.append(s)
        }
    }

    /// M3 v7: the Moon ramp (TourRamp, Monsoon's) and the raised Moon round its crater turn (grey box: a disc at the ramp's
    /// top height, drawn over the floor so floor balls pass under it, and the crater ring where the ball pauses).
    private func addMoon() {
        let ramp = TourRamp(path: TourTableLayout.moonRampPath, apexDistance: TourTableLayout.moonApexDistance,
                            mouthHalfWidth: TourTableLayout.moonMouthHalfWidth, halfWidth: TourTableLayout.moonHalfWidth,
                            flareLength: TourTableLayout.moonFlareLength, postLength: 0,
                            lowLength: TourTableLayout.moonLowLength)
        addChild(ramp)
        moonRamp = ramp
        let lift = TourTableLayout.rampTopHeight * TourTableLayout.oblique
        let moon = SKShapeNode(circleOfRadius: TourTableLayout.moonRadius)
        moon.position = CGPoint(x: TourTableLayout.moonCenter.x, y: TourTableLayout.moonCenter.y + lift)
        moon.fillColor = SKColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 0.92)
        moon.strokeColor = SKColor(white: 0.9, alpha: 0.9)
        moon.lineWidth = 2
        moon.zPosition = 19.5                      // over floor balls (z 10), under the ramp's art (20+)
        addChild(moon)
        let label = SKLabelNode(text: "MOON")
        label.fontName = "Menlo-Bold"; label.fontSize = 11
        label.fontColor = SKColor(white: 1, alpha: 0.8)
        label.position = CGPoint(x: -8, y: -20)
        moon.addChild(label)
        let (c, _) = ramp.path.sample(at: TourTableLayout.moonApexDistance + TourTableLayout.rampMadeAfterApex)
        let crater = SKShapeNode(circleOfRadius: 13)
        crater.position = CGPoint(x: c.x, y: c.y + lift)
        crater.fillColor = SKColor(white: 0.18, alpha: 0.9)
        crater.strokeColor = SKColor(white: 0.75, alpha: 0.9)
        crater.lineWidth = 1.5
        crater.zPosition = 19.6
        addChild(crater)
    }

    /// M3 v14: the Saturn ramp and the raised Saturn (grey box: a tan planet with a ring) round its crater turn.
    private func addSaturn() {
        let ramp = TourRamp(path: TourTableLayout.saturnRampPath, apexDistance: TourTableLayout.saturnApexDistance,
                            mouthHalfWidth: TourTableLayout.moonMouthHalfWidth, halfWidth: TourTableLayout.moonHalfWidth,
                            flareLength: TourTableLayout.moonFlareLength, postLength: 0,
                            lowLength: TourTableLayout.moonLowLength)
        addChild(ramp)
        saturnRamp = ramp
        let lift = TourTableLayout.rampTopHeight * TourTableLayout.oblique
        let at = CGPoint(x: TourTableLayout.saturnCenter.x, y: TourTableLayout.saturnCenter.y + lift)
        let ring = SKShapeNode(ellipseOf: CGSize(width: TourTableLayout.saturnRadius * 2.7, height: TourTableLayout.saturnRadius * 0.9))
        ring.position = at
        ring.zRotation = -0.35
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 0.95, green: 0.85, blue: 0.62, alpha: 0.85)
        ring.lineWidth = 4
        ring.zPosition = 19.55
        addChild(ring)
        let planet = SKShapeNode(circleOfRadius: TourTableLayout.saturnRadius)
        planet.position = at
        planet.fillColor = SKColor(red: 0.62, green: 0.50, blue: 0.30, alpha: 0.92)
        planet.strokeColor = SKColor(red: 0.95, green: 0.85, blue: 0.62, alpha: 0.9)
        planet.lineWidth = 2
        planet.zPosition = 19.5
        addChild(planet)
        let label = SKLabelNode(text: "SATURN")
        label.fontName = "Menlo-Bold"; label.fontSize = 10
        label.fontColor = SKColor(white: 1, alpha: 0.8)
        label.position = CGPoint(x: 6, y: -24)
        planet.addChild(label)
        let (c, _) = ramp.path.sample(at: TourTableLayout.saturnApexDistance + TourTableLayout.rampMadeAfterApex)
        let crater = SKShapeNode(circleOfRadius: 13)
        crater.position = CGPoint(x: c.x, y: c.y + lift)
        crater.fillColor = SKColor(white: 0.18, alpha: 0.9)
        crater.strokeColor = SKColor(white: 0.75, alpha: 0.9)
        crater.lineWidth = 1.5
        crater.zPosition = 19.6
        addChild(crater)
    }

    /// M3 v3: the plunge flap, a shallow blade hanging from the arch at the top right. Its edge is in the `diverter`
    /// category, which only the served ball (`isPlunge`) has in its collision mask; drawn bright while a plunge is up.
    private func addPlungeFlap() {
        let path = CGMutablePath()
        path.addLines(between: TourTableLayout.plungeHook)
        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = TourPhysicsCategory.diverter
        body.collisionBitMask = TourPhysicsCategory.ball
        let holder = SKNode()
        holder.physicsBody = body
        addChild(holder)
        let blade = SKShapeNode(path: path)
        blade.strokeColor = SKColor(white: 0.85, alpha: 1)
        blade.lineWidth = 4
        blade.lineCap = .round
        blade.zPosition = 2
        blade.alpha = 0.3
        addChild(blade)
        plungeFlap = blade
    }

    /// M3 v3: the top orbit gate (one-way: solid per ball, only for a ball moving right that isn't the plunge).
    private func addOrbitGate() {
        let a = TourTableLayout.orbitGateTop, b = TourTableLayout.orbitGateBottom
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = 0.1
        body.restitution = 0.1
        body.categoryBitMask = TourPhysicsCategory.orbitGate
        body.collisionBitMask = TourPhysicsCategory.ball
        let holder = SKNode()
        holder.physicsBody = body
        addChild(holder)
        // The drawn flap hangs from its hinge on the arch.
        let flap = SKShapeNode(rect: CGRect(x: -2.5, y: -(a.y - b.y), width: 5, height: a.y - b.y), cornerRadius: 2)
        flap.position = a
        flap.fillColor = SKColor(white: 0.82, alpha: 1)
        flap.strokeColor = SKColor(white: 0.25, alpha: 1)
        flap.lineWidth = 1
        flap.zPosition = 2
        addChild(flap)
        orbitGateFlap = flap
    }

    /// The playfield floor inside the outer wall.
    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: TourTableLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = TourTableLayout.wallFriction,
                         restitution: CGFloat = TourTableLayout.wallRestitution,
                         z: CGFloat = -19.5) {
        let path = CGMutablePath()
        path.addLines(between: points)

        let node = SKShapeNode(path: path)
        node.strokeColor = Self.wallColor
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z

        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = TourPhysicsCategory.wall
        body.collisionBitMask = TourPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
    }

    /// The kickback lamp over the left outlane: lit = the next ball down that outlane is fired back up.
    private func addKickbackLamp() {
        let lamp = SKShapeNode(circleOfRadius: 7)
        lamp.position = TourTableLayout.kickbackLamp
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

    /// The pop-up rocket post between the flipper tips. Down: a dim cap flush with the floor and no body. Up: a red
    /// post with a rubber bounce (category `bumper`, so the ball reports the hit).
    private func addRocketPost() {
        let r = TourTableLayout.rocketPostRadius
        let post = SKShapeNode(circleOfRadius: r)
        post.position = TourTableLayout.rocketPost
        post.zPosition = 1
        post.lineWidth = 2
        post.name = "rocketPost"
        addChild(post)
        rocketPost = post
        setRocketPost(up: false)
    }

    private func setRocketPost(up: Bool) {
        guard let post = rocketPost else { return }
        rocketPostUp = up
        rocketPostDropAt = nil
        post.removeAllActions()
        if up {
            let r = TourTableLayout.rocketPostRadius
            let body = SKPhysicsBody(circleOfRadius: r)
            body.isDynamic = false
            body.restitution = TourTableLayout.rocketPostRestitution
            body.friction = 0.2
            body.categoryBitMask = TourPhysicsCategory.bumper
            body.collisionBitMask = TourPhysicsCategory.ball
            post.physicsBody = body
            post.fillColor = Self.rocketColor
            post.strokeColor = SKColor(white: 1, alpha: 0.85)
            post.setScale(0.4)
            post.run(.scale(to: 1, duration: 0.12))
        } else {
            post.physicsBody = nil
            post.fillColor = SKColor(red: 0.30, green: 0.10, blue: 0.10, alpha: 1)
            post.strokeColor = SKColor(white: 1, alpha: 0.2)
            post.setScale(1)
        }
    }

    private func addPlunger() {
        let size = TourTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = TourTableLayout.plungerRestPosition

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = TourPhysicsCategory.wall
        body.collisionBitMask = TourPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    /// The launch gate across the top of the shooter lane: solid per ball, only for a ball above it moving down
    /// (a plunge going up swings the flap and passes; a ball coming back rolls off it into play).
    private func addLaunchGate() {
        let low = TourTableLayout.gateLow, high = TourTableLayout.gateHigh
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: low, to: high)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = TourPhysicsCategory.launchGate
        body.collisionBitMask = TourPhysicsCategory.ball
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
        let low = TourTableLayout.gateLow, high = TourTableLayout.gateHigh
        let gx = high.x - low.x, gy = high.y - low.y
        var plungeUp = false
        for ball in balls {
            let v = ball.physicsBody?.velocity ?? .zero
            let p = ball.position
            let above = gx * (p.y - low.y) - gy * (p.x - low.x) > 0
            ball.setLaunchGateSolid(above && v.dy < 0)
            // M3 v3: the plunge flap is closed for the served ball until it is in play below the top.
            if ball.isPlunge, p.y < TourTableLayout.plungeClearsBelowY, p.x < TourTableLayout.laneWallX { ball.isPlunge = false }
            ball.setPlungeFlapSolid(ball.isPlunge)
            ball.setOrbitGateSolid(v.dx > 0 && !ball.isPlunge)
            if ball.isPlunge && !isOnPlunger(ball) { plungeUp = true }
        }
        plungeFlap?.alpha = plungeUp ? 1 : 0.3
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

    // MARK: - The O-R-B-T lanes

    /// A lane rolled over: it lights; all four light the rocket post and raise the multiplier, then blink and clear.
    private func rollOver(_ lane: TourRollover, at now: TimeInterval) {
        guard lanesResetAt == nil else { return }
        if lane.isLit {
            game.add(TourPoints.laneRepeat)
            return
        }
        lane.isLit = true
        game.add(TourPoints.laneLit)
        sfx(.lane)
        guard rollovers.allSatisfy({ $0.isLit }) else { return }
        game.add(TourPoints.lanesComplete)
        bigHaptic.impactOccurred()
        lanesResetAt = now + 0.6
        sfx(.lanesComplete)
        let raised = game.raiseMultiplier()
        if !rocketPostUp {
            rocketPostUp = true
            rocketPostRaisePending = true
            showBanner(raised ? "ORBT · ROCKET POST UP · \(game.multiplier)X" : "ORBT · ROCKET POST UP")
        } else {
            showBanner(raised ? "ORBT · \(game.multiplier)X" : "ORBT")
        }
    }

    private func updateLanes(_ now: TimeInterval) {
        if let due = lanesResetAt {
            let blinkOn = Int((due - now) * 10) % 2 == 0
            rollovers.forEach { $0.isLit = blinkOn }
            if now >= due {
                lanesResetAt = nil
                rollovers.forEach { $0.isLit = false }
            }
        }
        if let due = starResetAt {
            let blinkOn = Int((due - now) * 10) % 2 == 0
            starLanes.forEach { $0.isLit = blinkOn }
            if now >= due {
                starResetAt = nil
                starLanes.forEach { $0.isLit = false }
            }
        }
    }

    /// M3 v2: a S-T-A-R lane rolled over: it lights; all four score and blink, then clear (placeholder rules).
    private func starOver(_ lane: TourRollover, at now: TimeInterval) {
        guard starResetAt == nil else { return }
        if lane.isLit {
            game.add(TourPoints.starRepeat)
            return
        }
        lane.isLit = true
        game.add(TourPoints.starLit)
        sfx(.lane)
        guard starLanes.allSatisfy({ $0.isLit }) else { return }
        game.add(TourPoints.starComplete)
        bigHaptic.impactOccurred()
        sfx(.lanesComplete)
        starResetAt = now + 0.6
        showBanner("S-T-A-R")
    }

    /// Lane change: each new flipper press shifts the lit lanes that way.
    private func rotateLanes(by step: Int) {
        if lanesResetAt == nil { Self.rotate(rollovers, by: step) }
        if starResetAt == nil { Self.rotate(starLanes, by: step) }     // M3 v2: the top lanes change too
    }

    private static func rotate(_ lanes: [TourRollover], by step: Int) {
        guard !lanes.isEmpty else { return }
        let lit = lanes.map { $0.isLit }
        let n = lit.count
        for (i, lane) in lanes.enumerated() {
            lane.isLit = lit[((i - step) % n + n) % n]
        }
    }

    // MARK: - Targets and scoops (milestone 2, placeholder rules)

    /// Drops hit this frame (marked in the contact callback), then whether a bank is complete.
    private func updateTargets(_ now: TimeInterval) {
        if !pendingDrops.isEmpty {
            // Only the bank that was hit this frame can complete (a full bank waiting for its scoop doesn't re-award).
            let hitSample = pendingDrops.contains { d in sampleBank.contains { $0 === d } }
            for t in pendingDrops {
                if t === blastDoor || blastWings.contains(where: { $0 === t }) {
                    rocketHit(now, on: t)
                    continue
                }
                t.drop()
                labEvent("sample")
                game.add(TourPoints.sampleDrop)
                hitHaptic.impactOccurred(intensity: 0.7)
                sfx(.standup)
            }
            pendingDrops.removeAll()
            if hitSample, sampleBank.allSatisfy({ $0.isDown }), !roverLit, sampleResetAt == nil {
                roverLit = true
                game.add(TourPoints.samplesComplete)
                bigHaptic.impactOccurred()
                showBanner("SAMPLES COLLECTED · ROVER OPEN")
            }
        }
        if let due = countdownResetAt, now >= due {
            countdownResetAt = nil
            blastDoor.raise()
            countdownLeft = TourTableLayout.countdownHits
            showCountdown()
        }
        if let due = sampleResetAt, now >= due {
            sampleResetAt = nil
            sampleBank.forEach { $0.raise() }
        }
        if let due = rocketClearAt, now >= due {
            rocketClearAt = nil
            rocketStandups.forEach { $0.isLit = false }
        }
    }

    /// A ball hit the rocket pad's blast door: one count off the countdown (the door stays up). On the last hit the
    /// rocket lifts off, the door drops and Mission Control behind it is open until the kick-out.
    private func rocketHit(_ now: TimeInterval, on target: TourDropTarget) {
        target.clearHit()                          // a bash target: ready for the next hit (the wings never drop)
        guard now - lastRocketHit > 0.25, countdownResetAt == nil, !blastDoor.isDown else { return }
        lastRocketHit = now
        labEvent("rocket")
        hitHaptic.impactOccurred(intensity: 0.7)
        sfx(.standup)
        countdownLeft = max(0, countdownLeft - 1)
        showCountdown()
        if countdownLeft > 0 {
            game.add(TourPoints.countdownDrop)
            showBanner("T-MINUS \(countdownLeft)")
            return
        }
        game.add(TourPoints.countdownComplete)
        bigHaptic.impactOccurred()
        showBanner("LIFTOFF · MISSION CONTROL OPEN")
        blastDoor.drop()
        Effects.burst(in: self, at: TourTableLayout.rocketToy, color: SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1),
                      count: 30, speed: 260, lifetime: 0.7)
        rocketToy.removeAllActions()
        rocketToy.position = TourTableLayout.rocketToy
        rocketToy.run(.sequence([
            .group([.moveBy(x: 0, y: 160, duration: 0.9), .fadeOut(withDuration: 0.9)]),
            .wait(forDuration: 1.2),
            .run { [weak self] in self?.rocketToy.position = TourTableLayout.rocketToy },
            .fadeIn(withDuration: 0.4)]))
    }

    private func showCountdown() {
        for (i, lamp) in countdownLampNodes.enumerated() {
            // Lamp i reads (5 − i); it's lit while that count is still to come.
            lamp.alpha = (TourTableLayout.countdownHits - i) <= countdownLeft ? 1 : 0.2
        }
    }

    private func hitStandup(_ s: TourStandup) {
        guard s.hit(at: gameTime) else { return }
        let index = rocketStandups.firstIndex(where: { $0 === s }) ?? 0
        // M3 v11: K-E-T or R-O-C; v12: K-E-T by letter in the Shot Lab (Aaron: "still not able to hit the K")
        labEvent(index >= 3 ? "ket" + TourTableLayout.rocketLabels[index] : "roc")
        sfx(.standup)
        hitHaptic.impactOccurred(intensity: 0.5)
        guard rocketClearAt == nil else { return }
        if s.isLit {
            game.add(TourPoints.rocketRepeat)
            return
        }
        s.isLit = true
        game.add(TourPoints.rocketLetter)
        guard rocketStandups.allSatisfy({ $0.isLit }) else { return }
        game.add(TourPoints.rocketComplete)
        bigHaptic.impactOccurred()
        showBanner(TourTableLayout.rocketLabels.prefix(rocketStandups.count).joined(separator: "-"))
        rocketClearAt = gameTime + 1.0
    }

    /// Catches a ball that rolls into an empty hole, holds it, then kicks it out (Table 04's pattern).
    private func updateScoops(_ now: TimeInterval) {
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if let scoop = ball.heldIn {
                ball.position = scoop.position
                body.velocity = .zero
                body.angularVelocity = 0
                if now >= ball.releaseAt {
                    ball.heldIn = nil
                    ball.scoopIgnoreUntil = now + TourTableLayout.scoopRecapture
                    body.affectedByGravity = true
                    body.velocity = scoop.ejectVelocity
                    sfx(.scoopOut)
                    // The kick-out clears the bank in front (no score), and the bank comes back up once the ball is
                    // through it: the eject would otherwise hit the standing drops from behind.
                    if scoop === missionScoop {
                        // Out through the subway at the top of the left inlane; the countdown resets behind it.
                        ball.position = TourTableLayout.missionSubwayExit
                        ball.previousPosition = ball.position
                        countdownResetAt = now + TourTableLayout.bankResetDelay
                    } else if scoop === roverScoop {
                        sampleBank.filter { !$0.isDown }.forEach { $0.drop() }
                        sampleResetAt = now + TourTableLayout.bankResetDelay
                    }
                }
                continue
            }
            guard ball.isOnFloor, now >= ball.scoopIgnoreUntil else { continue }
            let v = body.velocity
            let from = CGPoint(x: ball.position.x - v.dx * lastStep, y: ball.position.y - v.dy * lastStep)
            // Caught by its path past the hole, or anywhere inside the bay / bunker (so no ball can rest in there).
            let p = ball.position
            guard let scoop = [missionScoop!, roverScoop!].first(where: { candidate in
                let inside = candidate === missionScoop ? TourTableLayout.inMissionBay(p) : TourTableLayout.inBunker(p)
                return (candidate.catches(from: from, to: p) || inside)
                    && !balls.contains(where: { $0.heldIn === candidate })
            }) else { continue }
            ball.heldIn = scoop
            ball.releaseAt = now + TourTableLayout.scoopHold
            body.affectedByGravity = false
            body.velocity = .zero
            scoop.flash()
            sfx(.scoopIn)
            hitHaptic.impactOccurred(intensity: 0.8)
            Effects.burst(in: self, at: scoop.position, color: Self.wallColor, count: 20, speed: 180, lifetime: 0.5)
            labEvent(scoop === missionScoop ? "missionControl" : "rover")
            if scoop === missionScoop {
                game.add(TourPoints.missionControl)
                showBanner("MISSION CONTROL")
            } else if roverLit {
                roverLit = false
                game.add(TourPoints.roverHome)
                showBanner("ROVER HOME · SAMPLES SAFE")
            } else {
                game.add(TourPoints.rover)
                showBanner("ROVER")
            }
        }
    }

    // MARK: - Orbits and spinners (milestone 3 v1, placeholder scoring)

    /// The orbits' arm and made switches and the spinners, from the ball's move this frame (after physics; velocities and
    /// score only, as in a contact callback).
    private func orbitSwitches(_ ball: TourBall, from p0: CGPoint, to p: CGPoint) {
        guard let body = ball.physicsBody else { return }
        // The switches reach ~10 pt past their ends (TourSwitch's slack): count only a ball inside that lane, so a plunge
        // beside the lane wall or a ball grazing an inner wall's outside never arms or spins anything.
        let inLeftLane = p.x < 60
        let inRightLane = p.x > 504 && p.x < TourTableLayout.laneWallX
        for (i, sw) in [TourTableLayout.leftSpinnerSwitch, TourTableLayout.rightSpinnerSwitch].enumerated()
            where i < spinners.count && (i == 0 ? inLeftLane : inRightLane) && sw.crossing(from: p0, to: p) != .none {
            let v = body.velocity
            spinners[i].kick(ballSpeed: hypot(v.dx, v.dy))
            body.velocity = CGVector(dx: v.dx * TourSpinner.ballSpeedKept, dy: v.dy * TourSpinner.ballSpeedKept)
            labEvent("spinner")
        }
        // Table time: the Shot Lab runs physics at its pass's speed, so it keeps its own clock.
        var now = gameTime
        #if DEBUG
        if shotLab != nil { now = shotLabTime }
        #endif
        switch inLeftLane ? TourTableLayout.leftOrbitArm.crossing(from: p0, to: p) : .none {
        case .forward: ball.leftOrbitArmed = true; ball.leftOrbitArmedAt = now
        case .backward: ball.leftOrbitArmed = false
        case .none: break
        }
        switch inRightLane ? TourTableLayout.rightOrbitArm.crossing(from: p0, to: p) : .none {
        case .forward: ball.rightOrbitArmed = true; ball.rightOrbitArmedAt = now
        case .backward: ball.rightOrbitArmed = false
        case .none: break
        }
        let within = TourTableLayout.orbitMadeWithin
        switch TourTableLayout.orbitMade.crossing(from: p0, to: p) {
        case .forward where ball.leftOrbitArmed && now - ball.leftOrbitArmedAt < within:
            ball.leftOrbitArmed = false
            orbitMade("leftOrbit", banner: "LEFT ORBIT")
        case .backward where ball.rightOrbitArmed && now - ball.rightOrbitArmedAt < within:
            ball.rightOrbitArmed = false
            orbitMade("rightOrbit", banner: "RIGHT ORBIT")
        default:
            break
        }
    }

    /// M3 v7: the Moon ramp's switches, from the ball's move this frame (Monsoon's updateRampLayer, one ramp): the entry
    /// puts a floor ball on the ramp (backward = it fell back out), the made switch just past the crater scores the Moon
    /// and pauses the ball there, the exit puts it back on the floor above the left inlane. A ramp ball found far from the
    /// channel drops to the floor (the safety net).
    private func updateRampLayer(_ ball: TourBall, from p0: CGPoint, to p: CGPoint) {
        if ball.isOnFloor {
            // Review fix: the switch line's slack reaches past the mouth; only a ball inside the mouth goes up.
            if let ramp = ramps.first(where: { $0.entrySwitch.crossing(from: p0, to: p) == .forward
                                               && $0.distanceToCenterline(p) < TourTableLayout.moonMouthHalfWidth }) {
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
        if !ball.isOnFloor, ramp.distanceToCenterline(p) > ramp.maxHalfWidth + TourTableLayout.ballRadius + 12 {
            ball.setLayer(.floor)
        }
    }

    /// Table time (the Shot Lab keeps its own clock).
    private var tableNow: TimeInterval {
        #if DEBUG
        if shotLab != nil || plungeProbe != nil { return shotLabTime }
        #endif
        return gameTime
    }

    /// M3 v7 / v14: the Moon or Saturn is made: score, then the ball pauses in its crater (placeholder for the locks).
    private func rampMade(_ ball: TourBall, _ ramp: TourRamp) {
        let saturn = ramp === saturnRamp
        labEvent(saturn ? "saturn" : "moon")
        game.add(saturn ? TourPoints.saturn : TourPoints.moon)
        hitHaptic.impactOccurred()
        sfx(.ramp)
        showBanner(saturn ? "SATURN" : "MOON")
        ball.holdReleaseHeading = saturn ? TourTableLayout.saturnReleaseHeading : TourTableLayout.moonReleaseHeading
        ball.moonReleaseAt = tableNow + TourTableLayout.moonHold
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.velocity = .zero
    }

    /// Holds paused balls still in the crater; on time, rolls each on down the wire (along the path past the crater).
    private func updateMoonHolds(_ now: TimeInterval) {
        guard !ramps.isEmpty else { return }
        for ball in balls {
            guard let due = ball.moonReleaseAt, let body = ball.physicsBody else { continue }
            if now < due {
                body.velocity = .zero
                continue
            }
            ball.moonReleaseAt = nil
            body.affectedByGravity = true
            // The exact tangent at the crater (the path's sample gives the next point's heading, ~7° into the turn).
            let h = ball.holdReleaseHeading
            let v = TourTableLayout.moonReleaseSpeed
            body.velocity = CGVector(dx: cos(h) * v, dy: sin(h) * v)
        }
    }

    private func orbitMade(_ event: String, banner: String) {
        labEvent(event)
        game.add(TourPoints.orbit)
        hitHaptic.impactOccurred(intensity: 0.7)
        sfx(.orbit)
        showBanner(banner)
    }

    /// Turns the spinners; each half-turn scores, with one tick sound per 50 ms.
    private func updateSpinners(_ dt: CGFloat, _ now: TimeInterval) {
        for s in spinners where s.isSpinning {
            let spins = s.update(dt: dt)
            guard spins > 0 else { continue }
            game.add(TourPoints.spin * spins)
            if now - lastSpinSound >= 0.05 {
                lastSpinSound = now
                sfx(.spinner)
            }
        }
    }

    // MARK: - Saves

    /// Whether a ball that drains now is saved: once per player ball, while it waits on the plunger and for the first
    /// 10 s after launch.
    private var ballSaveNow: Bool {
        guard !ballSaveUsed else { return false }
        if let t = launchedAt { return gameTime - t <= TourTableLayout.ballSaveSeconds }
        return true
    }

    /// A lit kickback fires a ball draining down the left outlane straight back up it. Lit at the start of every ball.
    private func updateKickback() {
        guard kickbackLit, !nudge.tilted else { return }
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            let p = ball.position
            if p.x < TourTableLayout.kickbackMaxX, p.y < TourTableLayout.kickbackTriggerY, p.y > 0, body.velocity.dy < 0 {
                // From the lane centre, so it meets the R-O-C '/' where the sim says it turns into the table.
                ball.position.x = TourTableLayout.kickbackLaneX
                body.velocity = CGVector(dx: 0, dy: TourTableLayout.kickbackSpeed)
                setKickbackLit(false)
                bigHaptic.impactOccurred()
                Effects.burst(in: self, at: p, color: Self.wallColor, count: 18, speed: 240, lifetime: 0.4)
                cameraRig.shake(strength: 3, duration: 0.25)
                sfx(.kickback)
                showBanner("KICKBACK")
                return
            }
        }
    }

    /// The raised rocket post drops a moment after it saves a ball.
    private func updateRocketPost(_ now: TimeInterval) {
        if rocketPostRaisePending { rocketPostRaisePending = false; setRocketPost(up: true) }
        if let due = rocketPostDropAt, now >= due { setRocketPost(up: false) }
    }

    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: "T6 M3 v14")
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
        let text = "\(fps)T6 M3 v14 \(effectiveCameraMode.tag) · \(speed)"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: TourBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func placeBallOnPlunger() {
        wasOnPlunger = false
        launchedAt = nil
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // a tilt ends here
        let r = TourTableLayout.ballRadius
        let ball = TourBall(at: CGPoint(x: TourTableLayout.laneCenterX, y: TourTableLayout.plungerRestTop + r + 2))
        ball.isPlunge = true                       // M3 v3: the plunge flap is closed for it
        addChild(ball)
        balls.append(ball)
        servedBall = ball
    }

    private func removeBall(_ ball: TourBall) {
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
    }

    private func removeAllBalls() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        servedBall = nil
    }

    private func isOnPlunger(_ ball: TourBall) -> Bool {
        ball.position.x > TourTableLayout.laneWallX
            && ball.position.y < TourTableLayout.plungerRestTop + TourTableLayout.ballRadius * 3
    }

    private var plungerBall: TourBall? {
        balls.first(where: { isOnPlunger($0) })
    }

    private var isBallOnPlunger: Bool { plungerBall != nil }

    func newGame() {
        fpsLow = 0
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game stops the Shot Lab
        #endif
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = TourTableLayout.plungerRestPosition
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        starResetAt = nil
        starLanes.forEach { $0.isLit = false }
        setKickbackLit(true)
        pendingDrops.removeAll()
        blastDoor.raise()
        countdownLeft = TourTableLayout.countdownHits
        showCountdown()
        lastRocketHit = -1
        sampleBank.forEach { $0.raise() }
        rocketStandups.forEach { $0.isLit = false }
        roverLit = false
        countdownResetAt = nil
        sampleResetAt = nil
        rocketClearAt = nil
        rocketPostRaisePending = false
        setRocketPost(up: false)
        ballSaveUsed = false
        game.reset()
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + TourTableLayout.bannerSeconds
    }

    private func sfx(_ s: MonSound) {
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView, !isAttractMode else { return }
        #if DEBUG
        if shotLab != nil { return }               // the robot has the flippers
        #endif
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
        return p.x > b.width * TourTableLayout.plungerZoneMinX && p.y > b.height * TourTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView else { return }
        for touch in touches {
            let p = touch.location(in: view)
            switch activeTouches[touch] {
            case .plunger:
                let dragged = (p.y - plungerStartY) * cameraRig.node.yScale
                plungerPull = min(max(dragged, 0), TourTableLayout.plungerMaxPull)
                plunger.position.y = TourTableLayout.plungerRestPosition.y - plungerPull
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
        var left = activeTouches.values.contains(.left) || padLeft
        var right = activeTouches.values.contains(.right) || padRight
        if nudge.tilted { left = false; right = false }      // tilted: dead flippers until the next ball
        if left && !leftFlipper.isPressed { rotateLanes(by: -1); sfx(.flipper) }
        if right && !rightFlipper.isPressed { rotateLanes(by: 1); sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
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
        plunger?.position = TourTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    private func releasePlunger() {
        let maxPull = TourTableLayout.plungerMaxPull
        let power = plungerPull < 4 ? TourTableLayout.tapLaunchPower : plungerPull / maxPull
        if let body = plungerBall?.physicsBody {
            let speed = TourTableLayout.minLaunchSpeed
                + power * (TourTableLayout.maxLaunchSpeed - TourTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
        }
        plunger.run(.move(to: TourTableLayout.plungerRestPosition, duration: 0.04))
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
            plungerPull = pull * TourTableLayout.plungerMaxPull
            plunger.position.y = TourTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * TourTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = TourTableLayout.plungerRestPosition
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
        if plungeProbe != nil {                    // plunge probe: fires plunges at set powers and logs the ball
            updatePlungeProbe(CGFloat(step))
            return
        }
        #endif
        if isAttractMode { return }

        let dt = CGFloat(step)
        lastStep = dt
        updateGamepad()
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        governInlanes()                          // the inlane speed limit (2026-11-02)
        updateGates()
        updateLanes(now)
        updateRocketPost(now)
        updateTargets(now)
        updateScoops(now)
        updateSpinners(dt, now)
        updateMoonHolds(now)

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
        let drained = balls.filter { $0.position.y < -TourTableLayout.ballRadius * 3 }
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
                        setKickbackLit(true)         // every ball starts with the kickback lit
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

    /// Hot inlane feeds: a ball rolling down an inlane is held to InlaneGovernor.maxSpeed (800 pt/s) so a held-up
    /// flipper can trap it.
    private func governInlanes() {
        for ball in balls {
            guard let body = ball.physicsBody,
                  let v = InlaneGovernor.limited(body.velocity, at: ball.position,
                                                 leftGuide: TourTableLayout.leftLaneGuide,
                                                 mirrorSum: TourTableLayout.mirrorSum) else { continue }
            body.velocity = v
        }
    }

    override func didSimulatePhysics() {
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            // The flip assist: a flip gives the ball its full speed on long steps too (off at 120 Hz steps).
            let r = TourTableLayout.ballRadius
            leftFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
            rightFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            if speed > TourTableLayout.maxBallSpeed {
                let scale = TourTableLayout.maxBallSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            // A plunge crossing the launch gate going up swings the flap (read before previousPosition moves on).
            let low = TourTableLayout.gateLow, high = TourTableLayout.gateHigh
            let gx = high.x - low.x, gy = high.y - low.y
            let p0 = ball.previousPosition, p = ball.position
            let wasAbove = gx * (p0.y - low.y) - gy * (p0.x - low.x) > 0
            let above = gx * (p.y - low.y) - gy * (p.x - low.x) > 0
            updateRampLayer(ball, from: p0, to: p)       // M3 v7: the Moon ramp
            ball.rampHeight = ball.isOnFloor ? 0 : (ball.activeRamp?.height(at: p) ?? 0)
            if ball.isOnFloor, !wasAbove, above, body.velocity.dy > 0, p.x > low.x, p.x < high.x { swingLaunchGate() }
            // Floor switches count floor balls only (the Moon's wire runs over the left orbit lane).
            if ball.isOnFloor { orbitSwitches(ball, from: p0, to: p) }
            // M3 v3: a ball passing the top orbit gate going left (a right-orbit loop, a plunge) swings its flap.
            let gx0 = TourTableLayout.orbitGateTop.x
            if ball.isOnFloor, p0.x >= gx0, p.x < gx0, p.y > TourTableLayout.orbitGateBottom.y, let flap = orbitGateFlap,
               flap.action(forKey: "swing") == nil {
                flap.run(.sequence([.rotate(toAngle: -1.3, duration: 0.07, shortestUnitArc: true),
                                    .rotate(toAngle: 0, duration: 0.5, shortestUnitArc: true)]), withKey: "swing")
            }
            ball.previousPosition = ball.position
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
        if a.categoryBitMask == TourPhysicsCategory.ball {
            ballBody = a; other = b
        } else if b.categoryBitMask == TourPhysicsCategory.ball {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? TourBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case TourPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? TourSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                labEvent("sling")
                game.add(TourPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case TourPhysicsCategory.bumper:
            // The raised rocket post saved a ball: it scores, flashes and drops a moment later.
            if let bumper = node as? TourBumper,
               bumper.hit(ball: ballBody, ballPosition: ballNode.position, at: gameTime) {
                labEvent("bumper")
                game.add(TourPoints.bumper)
                hitHaptic.impactOccurred(intensity: 0.8)
                sfx(.bumper)
            } else if node === rocketPost, rocketPostUp, rocketPostDropAt == nil {
                rocketPostDropAt = gameTime + TourTableLayout.rocketPostDropDelay
                game.add(TourPoints.rocketPost)
                bigHaptic.impactOccurred()
                Effects.burst(in: self, at: TourTableLayout.rocketPost, color: Self.rocketColor, count: 16,
                              speed: 200, lifetime: 0.35)
                sfx(.ballSave)
                showBanner("ROCKET POST SAVE")
            }
        case TourPhysicsCategory.target:
            // The plate carrying the body is a child of the target node.
            if let drop = node.parent as? TourDropTarget {
                if drop.registerHit() { pendingDrops.append(drop) }
            } else if let standup = node.parent as? TourStandup {
                hitStandup(standup)
            }
        case TourPhysicsCategory.rollover:
            if let lane = node as? TourRollover {
                if starLanes.contains(where: { $0 === lane }) {
                    labEvent("star")
                    starOver(lane, at: gameTime)
                } else {
                    labEvent("lane")
                    rollOver(lane, at: gameTime)
                }
            }
        default:
            break
        }
    }
}

extension TourTableScene {
    /// A shot event for the labs (a no-op in play and in Release builds).
    fileprivate func labEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        #endif
    }
}

#if DEBUG
extension TourTableScene {
    /// Starts the robot: it takes over the flippers and sweeps flip timings from a cradled ball on each flipper at
    /// 120 Hz and 60 Hz physics steps (~25 min in the Simulator). Menu or a new game stops it.
    func debugStartShotLab() {
        isAttractMode = false
        removeAllBalls()                           // M3 v7 review: no ball left mid Moon hold on the game clock
        shotLabTime = 0
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// DEBUG: fires a plunge at each power (0.40 … 1.00) at 120 Hz steps (physics speed 0.5 at the Simulator's 60 fps)
    /// and prints the ball every 1/30 s as `PROBE power t x y vx vy`, 4 s a plunge; then quits. Read with
    /// `xcrun simctl launch --console-pty`.
    func debugPlungeProbe() {
        isAttractMode = false
        removeAllBalls()
        placeBallOnPlunger()
        plungeProbe = (powers: stride(from: 0.4, through: 1.0001, by: 0.1).map { CGFloat($0) }, power: 0, t: 0, logT: 0, fired: false)
    }

    fileprivate func updatePlungeProbe(_ realDt: CGFloat) {
        guard var probe = plungeProbe else { return }
        physicsWorld.speed = 0.5
        let dt = realDt * 0.5
        shotLabTime += TimeInterval(dt)
        let now = shotLabTime
        lastStep = dt
        leftFlipper.step(dt: dt); rightFlipper.step(dt: dt)
        updateGates(); updateLanes(now); updateSpinners(dt, now); updateMoonHolds(now)
        probe.t += dt
        if !probe.fired, probe.t > 0.5 {
            guard !probe.powers.isEmpty else { print("PROBE done"); exit(0) }
            probe.power = probe.powers.removeFirst()
            plungerPull = probe.power * TourTableLayout.plungerMaxPull
            releasePlunger()
            probe.fired = true; probe.t = 0; probe.logT = 0
            print("PROBE fire \(probe.power)")
        } else if probe.fired {
            if probe.t >= probe.logT, let b = servedBall, let v = b.physicsBody?.velocity {
                print(String(format: "PROBE %.1f %.3f %.0f %.0f %.0f %.0f %@", probe.power, probe.t, b.position.x, b.position.y,
                             v.dx, v.dy, b.isPlunge ? "P" : "-"))
                probe.logT += 1.0 / 30
            }
            if probe.t > 4 {
                removeAllBalls(); placeBallOnPlunger()
                probe.fired = false; probe.t = 0
            }
        }
        plungeProbe = probe
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
        slingshots.forEach { $0.settle() }
        governInlanes()
        updateGates()
        updateLanes(now)
        updateTargets(now)
        updateScoops(now)
        updateSpinners(dt, now)
        updateMoonHolds(now)
        if lab.update(now: now) {
            game.banner = lab.progressText
        } else {
            let saved = lab.save(now: now)
            shotLab = nil
            physicsWorld.speed = 1
            shotLabResetTable()
            game.banner = "SHOT LAB DONE · \(lab.trials.count) TRIALS · \(saved)"
            ShotLab.quitIfLaunchedForLab()          // launched by tools/shotlab_run.sh grandtour → quit
        }
    }
}

extension TourTableScene: ShotLabHost {
    var shotLabTableName: String { "Grand Tour" }

    /// The shots a player aims for end a trial; slings and lanes are noted only.
    var shotLabMajorEvents: Set<String> { ["rocket", "missionControl", "rover", "sample", "roc", "leftOrbit", "rightOrbit", "moon", "saturn", "ketK", "ketE", "ketT"] }

    /// Left and right flippers, cradled as on the other tables: 40 pt out and 14 above the raised flipper.
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = TourTableLayout.flipperTravel - TourTableLayout.flipperRestAngle      // 30° above horizontal
        let along: CGFloat = 40, above: CGFloat = 14
        let l = TourTableLayout.leftFlipperPivot
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: TourTableLayout.mirrorSum - left.x, y: left.y)
        let ix = TourTableLayout.laneGuideX + 17, iy = TourTableLayout.laneGuideTop + 10
        let r = TourTableLayout.rightFlipperPivot
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left,
                                    starts: ShotLab.lowerStarts(pivot: l, pointsLeft: false, inlaneX: ix, inlaneTopY: iy)),
                ShotLab.FlipperSpec(name: "right", pivot: r, cradle: right,
                                    starts: ShotLab.lowerStarts(pivot: r, pointsLeft: true, inlaneX: TourTableLayout.mirrorSum - ix, inlaneTopY: iy))]
    }

    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        if index == 0 { leftFlipper.isPressed = pressed } else { rightFlipper.isPressed = pressed }
    }

    func shotLabPlaceBall(at point: CGPoint) {
        let ball = TourBall(at: point)
        addChild(ball)
        balls.append(ball)
    }

    func shotLabPlaceBall(at point: CGPoint, velocity: CGVector) {
        shotLabPlaceBall(at: point)
        balls.last?.physicsBody?.velocity = velocity
    }

    /// Every ball gone, targets up, the countdown back to 5, no saves lit, scoops empty.
    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        starResetAt = nil
        starLanes.forEach { $0.isLit = false }
        pendingDrops.removeAll()
        blastDoor.raise()
        countdownLeft = TourTableLayout.countdownHits
        showCountdown()
        lastRocketHit = -1
        sampleBank.forEach { $0.raise() }
        rocketStandups.forEach { $0.isLit = false }
        roverLit = false
        countdownResetAt = nil
        sampleResetAt = nil
        rocketClearAt = nil
        rocketPostRaisePending = false
        setRocketPost(up: false)
        setKickbackLit(false)
    }

    /// Where shots cross just below the rocket's hull and at the shot line (the ramp mouths' height).
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "hull", y: TourTableLayout.blastDoor.y - 30),
         ShotLab.Probe(name: "shotLine", y: 600)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }
}
#endif

extension TourTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}
