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
    /// M5 v4: parallax by height (TourParallax): raised parts slide against the floor as the camera moves.
    private let parallax = TourParallax()
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
    /// M6 v7: the rocket sprite's engine flame (shown during liftoff).
    private var rocketFlame: SKShapeNode?
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
    /// M4 v2: the R-O-C trap probe (`-shotlab-scenario roctrap`): shots at the bank and a ball dropped inside it.
    fileprivate var rocProbe: (cases: [(p: CGPoint, v: CGVector)], t: CGFloat, inside: Bool)?
    /// M4 v3: the ramp ride probe (`-shotlab-scenario rampride`): a ball released from each crater at set speeds.
    fileprivate var rideProbe: (cases: [(saturn: Bool, speed: CGFloat)], saturn: Bool, speed: CGFloat, t: CGFloat, topY: CGFloat)?
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
    /// M4 v1: the Play Lab (shared, PlayLab.swift): the run, when its next game starts.
    private var playLab: PlayLab?
    private var playLabNextAt: TimeInterval?
    private var playLabStarting = false
    /// M4 v4: the Play Lab's watchdog — where each ball was last seen moving, and when.
    private var watchSpots: [ObjectIdentifier: (CGPoint, TimeInterval)] = [:]
    #endif
    /// The Play Lab robot's buttons (always false outside it).
    private var robotLeft = false
    private var robotRight = false

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

    /// M4 v6: the view reports where its score panel ends (screen points from the top); the camera keeps clear of it.
    func setHUDReserve(_ points: CGFloat) {
        guard abs(points - cameraRig.hudReserve) > 0.5 else { return }
        cameraRig.hudReserve = points
        refreshCamera()
    }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addFloor()
        addFloorArt()
        addPlanetWindow()
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
            let sling = TourSlingshot(top: s.top, corner: s.corner, tip: s.tip, artBaked: hasLowerArt,
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
        // M4 v5: the bank is the solid alone (the outline is drawn, no edge chain). With both, a ball a hard shot put
        // halfway through the chain was pushed IN by the chain and OUT by the solid, and stuck there (Play Lab 19-56-14Z:
        // (47, 591), (52, 602)). The solid's faces are the outline's ('/' and roof; B is 0.1 pt off the line A–C).
        addWall(points: TourTableLayout.rocStructure, physics: false)
        addSolid(points: TourTableLayout.rocSolid)        // M4 v2: no ball can be trapped inside the bank
        blastDoor = TourDropTarget(at: TourTableLayout.blastDoor, normal: -.pi / 2, label: "",
                                   size: TourTableLayout.blastDoorSize,
                                   color: SKColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1), art: "tour_blastdoor")
        addChild(blastDoor)
        for (i, w) in TourTableLayout.rocketWings.enumerated() {
            let wing = TourDropTarget(at: w.center, normal: w.normal, label: "", size: TourTableLayout.rocketWingSize,
                                      color: SKColor(red: 0.60, green: 0.64, blue: 0.72, alpha: 1),
                                      art: i == 0 ? "tour_wing_l" : "tour_wing_r")
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
        // The rocket toy on the pad. It lifts off on the last countdown hit. M6 v7: a rendered sprite (tools/
        // tour_render_toys.py: in the table's oblique, its foot at the image centre, 6 px/pt, lit), with an engine
        // flame that burns during liftoff; the grey-box triangle if the art is missing.
        let rocket: SKNode
        if let image = UIImage(named: "tour_rocket") {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = CGSize(width: image.size.width * image.scale / 6, height: image.size.height * image.scale / 6)
            if let n = UIImage(named: "tour_rocket_n") {
                sprite.normalTexture = SKTexture(image: n)
                sprite.lightingBitMask = TourLighting.spriteMask
            }
            let flame = SKShapeNode(ellipseIn: CGRect(x: -6.5, y: -32, width: 13, height: 35))
            flame.fillColor = SKColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 1)
            flame.strokeColor = .clear
            flame.blendMode = .add
            flame.alpha = 0
            flame.zPosition = -0.1
            let core = SKShapeNode(ellipseIn: CGRect(x: -3.2, y: -18, width: 6.4, height: 19))
            core.fillColor = SKColor(red: 1.0, green: 0.95, blue: 0.75, alpha: 1)
            core.strokeColor = .clear
            core.blendMode = .add
            flame.addChild(core)
            sprite.addChild(flame)
            rocketFlame = flame
            rocket = sprite
        } else {
            let rocketPath = CGMutablePath()
            rocketPath.move(to: CGPoint(x: 0, y: 36)); rocketPath.addLine(to: CGPoint(x: 11, y: -8))
            rocketPath.addLine(to: CGPoint(x: -11, y: -8)); rocketPath.closeSubpath()
            let shape = SKShapeNode(path: rocketPath)
            shape.fillColor = SKColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1)
            shape.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1)
            shape.lineWidth = 1.5
            rocket = shape
        }
        rocket.position = TourTableLayout.rocketToy
        rocket.zPosition = 25
        let rocketArt = SKNode()                   // M5 v4: parallax holder (the liftoff still moves the rocket itself)
        addChild(rocketArt)
        parallax.add(rocketArt, anchor: TourTableLayout.rocketToy, height: 30)
        rocketArt.addChild(rocket)
        rocketToy = rocket
        showCountdown()
        for (i, c) in TourTableLayout.sampleCenters.enumerated() {
            let t = TourDropTarget(at: c, normal: TourTableLayout.sampleNormal, label: "\(i + 1)",
                                   color: SKColor(red: 0.90, green: 0.42, blue: 0.29, alpha: 1), art: "tour_drop_sample")
            addChild(t)
            sampleBank.append(t)
        }
        for (i, c) in TourTableLayout.rocketCenters.enumerated() {
            let s = TourStandup(at: c, normal: TourTableLayout.rocketNormal, label: TourTableLayout.rocketLabels[i],
                                art: "tour_standup_roc")
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
            parallax.add(b.art, anchor: c, height: 20)    // M5 v4: the cap slides; the body stays
        }
        #if DEBUG
        // M5 v6: launch with `-tourLights steady` (or off) to start in a lighting test mode (Simulator screenshots).
        switch UserDefaults.standard.string(forKey: "tourLights") {
        case "steady": TourLighting.mode = 1
        case "off": TourLighting.mode = 2
        default: break
        }
        applyLightingMode()
        if ProcessInfo.processInfo.arguments.contains("-tourLiftoff") {     // M6 v7c: watch the liftoff show
            run(.sequence([.wait(forDuration: 3), .repeatForever(.sequence([
                .run { [weak self] in self?.playLiftoff() }, .wait(forDuration: 9)]))]))
        }
        #endif
    }

    /// M3 v11: K-E-T, the second half of R-O-C-K-E-T (rocketStandups 3–5), on its backboard right of the rocket.
    private func addKET() {
        addWall(points: TourTableLayout.ketBackboard)
        for (i, c) in TourTableLayout.ketCenters.enumerated() {
            let s = TourStandup(at: c, normal: TourTableLayout.ketNormal, label: TourTableLayout.rocketLabels[3 + i],
                                art: "tour_standup_ket")
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
                            lowLength: TourTableLayout.moonLowLength, artBaked: hasRampArt("moon"))
        addChild(ramp)
        moonRamp = ramp
        addRampArt("moon")
        let lift = TourTableLayout.rampTopHeight * TourTableLayout.oblique
        let moon = SKShapeNode(circleOfRadius: TourTableLayout.moonRadius)
        moon.position = CGPoint(x: TourTableLayout.moonCenter.x, y: TourTableLayout.moonCenter.y + lift)
        // M5 v7 (the plan's fourth 3D trick, a tall see-through piece): the Moon is a raised CLEAR plastic playfield —
        // a faint printed lunar tint, a frosted edge, a gleam — so a floor ball rolling beneath it stays in view;
        // its shadow lies on the floor below and three chrome posts hold it up.
        moon.fillColor = SKColor(red: 0.66, green: 0.72, blue: 0.84, alpha: 0.26)
        moon.strokeColor = SKColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 0.85)
        moon.lineWidth = 2.6
        let gleam = SKShapeNode(circleOfRadius: TourTableLayout.moonRadius * 0.62)
        gleam.position = CGPoint(x: -TourTableLayout.moonRadius * 0.22, y: TourTableLayout.moonRadius * 0.22)
        gleam.fillColor = SKColor(white: 1, alpha: 0.07)
        gleam.strokeColor = .clear
        moon.addChild(gleam)
        let frost = SKShapeNode(circleOfRadius: TourTableLayout.moonRadius - 4)
        frost.fillColor = .clear
        frost.strokeColor = SKColor(white: 1, alpha: 0.16)
        frost.lineWidth = 6
        moon.addChild(frost)
        let moonShadow = SKShapeNode(circleOfRadius: TourTableLayout.moonRadius)   // on the floor: no parallax
        let sh = TourTableLayout.rampTopHeight
        moonShadow.position = CGPoint(x: TourTableLayout.moonCenter.x + sh * 0.30, y: TourTableLayout.moonCenter.y - sh * 0.22)
        moonShadow.fillColor = SKColor(white: 0, alpha: 0.24)
        moonShadow.strokeColor = .clear
        moonShadow.zPosition = -17.95
        addChild(moonShadow)
        let posts = CGMutablePath()                 // chrome posts, floor to platform, seen at the table's lean
        for a in [CGFloat(1.15), 2.95, 4.75] {
            let f = CGPoint(x: TourTableLayout.moonCenter.x + cos(a) * TourTableLayout.moonRadius * 0.78,
                            y: TourTableLayout.moonCenter.y + sin(a) * TourTableLayout.moonRadius * 0.78)
            posts.move(to: f); posts.addLine(to: CGPoint(x: f.x, y: f.y + lift))
        }
        let postArt = SKNode()                      // half the platform's height: the posts span floor to top
        addChild(postArt)
        parallax.add(postArt, anchor: TourTableLayout.moonCenter, height: TourTableLayout.rampTopHeight / 2)
        for (w, c, z) in [(CGFloat(4.4), SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.6), CGFloat(19.3)),
                          (2.4, SKColor(red: 0.80, green: 0.82, blue: 0.87, alpha: 1), 19.31)] {
            let p = SKShapeNode(path: posts)
            p.strokeColor = c; p.lineWidth = w; p.lineCap = .round; p.zPosition = z
            postArt.addChild(p)
        }
        moon.zPosition = 19.5                      // over floor balls (z 10), under the ramp's art (20+)
        let moonArt = SKNode()                     // M5 v4: the Moon and its crater slide together (parallax)
        addChild(moonArt)
        parallax.add(moonArt, anchor: TourTableLayout.moonCenter, height: TourTableLayout.rampTopHeight)
        // M6 v8: the painted Moon (clear plastic print, its crater cup painted in) replaces the grey-box disc,
        // label and crater ring.
        if let art = planetSprite("tour_moon") {
            art.position = moon.position
            art.zPosition = moon.zPosition
            moonArt.addChild(art)
            return
        }
        moonArt.addChild(moon)
        let label = SKLabelNode(text: "MOON")
        label.fontName = "Menlo-Bold"; label.fontSize = 11
        label.fontColor = SKColor(white: 1, alpha: 0.8)
        label.position = CGPoint(x: -8, y: -20)
        moon.addChild(label)
        let (c, _) = ramp.path.sample(at: TourTableLayout.moonApexDistance + TourTableLayout.rampMadeAfterApex)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-tourDumpWalls") { print("TOURCRATER moon \(c.x),\(c.y)") }
        #endif
        let crater = SKShapeNode(circleOfRadius: 13)
        crater.position = CGPoint(x: c.x, y: c.y + lift)
        crater.fillColor = SKColor(white: 0.18, alpha: 0.9)
        crater.strokeColor = SKColor(white: 0.75, alpha: 0.9)
        crater.lineWidth = 1.5
        crater.zPosition = 19.6
        moonArt.addChild(crater)
    }

    /// M6 v9: the ramps rendered in Blender (tools/tour_render_ramps.py, from the game's own ramp geometry via
    /// -tourDumpWalls): the ramp itself at z 20 (over floor balls, under a ball riding it at 30) and what lies on the
    /// floor (its shadow, the entrance flap, the posts' feet) at z −17.95. Both images cover the same world rect
    /// (the script's RECT lines), 3 px/pt. With them in, TourRamp builds only the physics (`artBaked`).
    private static let rampArtRects: [String: CGRect] = [
        "moon": CGRect(x: 43, y: 420, width: 211, height: 601),
        "saturn": CGRect(x: 383, y: 420, width: 188, height: 592),
    ]

    private func hasRampArt(_ name: String) -> Bool {
        UIImage(named: "tour_ramp_" + name) != nil && UIImage(named: "tour_ramp_" + name + "_lo") != nil
    }

    private func addRampArt(_ name: String) {
        guard hasRampArt(name), let rect = Self.rampArtRects[name] else { return }
        for (suffix, z) in [("", CGFloat(20)), ("_lo", CGFloat(-17.95))] {
            let texture = SKTexture(imageNamed: "tour_ramp_" + name + suffix)
            texture.preload { }
            let sprite = SKSpriteNode(texture: texture, size: rect.size)
            sprite.position = CGPoint(x: rect.midX, y: rect.midY)
            sprite.zPosition = z
            addChild(sprite)
        }
    }

    /// M6 v8: a painted platform (tools/tour_paint_planets.py: 6 px/pt, centred on the platform), lit by the table's
    /// lights, with its normal map if it has one (Saturn's sphere; the Moon is a flat print).
    private func planetSprite(_ name: String) -> SKSpriteNode? {
        guard let image = UIImage(named: name) else { return nil }
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.size = CGSize(width: image.size.width * image.scale / 6, height: image.size.height * image.scale / 6)
        if let n = UIImage(named: name + "_n") { sprite.normalTexture = SKTexture(image: n) }
        sprite.lightingBitMask = TourLighting.spriteMask
        return sprite
    }

    /// M3 v14: the Saturn ramp and the raised Saturn (grey box: a tan planet with a ring) round its crater turn.
    private func addSaturn() {
        let ramp = TourRamp(path: TourTableLayout.saturnRampPath, apexDistance: TourTableLayout.saturnApexDistance,
                            mouthHalfWidth: TourTableLayout.moonMouthHalfWidth, halfWidth: TourTableLayout.moonHalfWidth,
                            flareLength: TourTableLayout.moonFlareLength, postLength: 0,
                            lowLength: TourTableLayout.moonLowLength, artBaked: hasRampArt("saturn"))
        addChild(ramp)
        saturnRamp = ramp
        addRampArt("saturn")
        let lift = TourTableLayout.rampTopHeight * TourTableLayout.oblique
        let at = CGPoint(x: TourTableLayout.saturnCenter.x, y: TourTableLayout.saturnCenter.y + lift)
        let ring = SKShapeNode(ellipseOf: CGSize(width: TourTableLayout.saturnRadius * 2.7, height: TourTableLayout.saturnRadius * 0.9))
        ring.position = at
        ring.zRotation = -0.35
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 0.95, green: 0.85, blue: 0.62, alpha: 0.85)
        ring.lineWidth = 4
        ring.zPosition = 19.55
        let saturnArt = SKNode()                   // M5 v4: Saturn, its ring and crater slide together (parallax)
        addChild(saturnArt)
        parallax.add(saturnArt, anchor: TourTableLayout.saturnCenter, height: TourTableLayout.rampTopHeight)
        // M6 v8: the painted Saturn (banded planet, ring in front below / behind above, crater cup painted in).
        if let art = planetSprite("tour_saturn") {
            art.position = at
            art.zPosition = 19.5
            saturnArt.addChild(art)
            return
        }
        saturnArt.addChild(ring)
        let planet = SKShapeNode(circleOfRadius: TourTableLayout.saturnRadius)
        planet.position = at
        planet.fillColor = SKColor(red: 0.62, green: 0.50, blue: 0.30, alpha: 0.92)
        planet.strokeColor = SKColor(red: 0.95, green: 0.85, blue: 0.62, alpha: 0.9)
        planet.lineWidth = 2
        planet.zPosition = 19.5
        saturnArt.addChild(planet)
        let label = SKLabelNode(text: "SATURN")
        label.fontName = "Menlo-Bold"; label.fontSize = 10
        label.fontColor = SKColor(white: 1, alpha: 0.8)
        label.position = CGPoint(x: 6, y: -24)
        planet.addChild(label)
        let (c, _) = ramp.path.sample(at: TourTableLayout.saturnApexDistance + TourTableLayout.rampMadeAfterApex)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-tourDumpWalls") { print("TOURCRATER saturn \(c.x),\(c.y)") }
        #endif
        let crater = SKShapeNode(circleOfRadius: 13)
        crater.position = CGPoint(x: c.x, y: c.y + lift)
        crater.fillColor = SKColor(white: 0.18, alpha: 0.9)
        crater.strokeColor = SKColor(white: 0.75, alpha: 0.9)
        crater.lineWidth = 1.5
        crater.zPosition = 19.6
        saturnArt.addChild(crater)
    }

    /// M3 v3: the plunge flap, a shallow blade hanging from the arch at the top right. Its edge is in the `diverter`
    /// category, which only the served ball (`isPlunge`) has in its collision mask; drawn bright while a plunge is up.
    private func addPlungeFlap() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-tourDumpWalls") {
            print("TOURHOOK " + TourTableLayout.plungeHook.map { "\($0.x),\($0.y)" }.joined(separator: ";"))
        }
        #endif
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
    /// M6 v1: the printed playfield — the two approved floor paintings (tools/tour_floor_art.py: lower y −75…700, upper
    /// 640…1340, the upper fading into the lower over their overlap), trimmed to the outer wall, over the grey floor and
    /// under everything else (the planet window, lamps and parts draw above). The hardware stays grey box until its bake.
    private func addFloorArt() {
        // M6 v3: the lower table's Blender bake (tools/tour_bake_lower.py … game → tour_bake_art.py) — floor painting under
        // its clear coat, the cabinet, chrome walls, rails and posts, sling plastics, the R-O-C hull, the Mars bunker,
        // aprons — at z −19.4, over the grey wall lines (−19.5) it replaces; its top 30 pt fade onto the upper painting.
        // With it, the plain lower floor painting isn't drawn (it would only be overdraw underneath).
        hasLowerArt = UIImage(named: "tour_lower") != nil
        let lowerRect = CGRect(x: -40, y: -75, width: 680, height: 775)
        // M6 v4: the upper table's bake (tools/tour_bake_upper.py, from the game's own walls via -tourDumpWalls) at z −19.45,
        // under the lower bake's fading top edge and over the grey walls; the plain upper painting then isn't drawn.
        let hasUpperArt = UIImage(named: "tour_upper") != nil
        let upperRect = CGRect(x: -40, y: 640, width: 680, height: 700)
        for (name, rect, z) in [("tour_lower", lowerRect, CGFloat(-19.4)),
                                ("tour_upper", upperRect, CGFloat(-19.45)),
                                ("tour_floor_lower", lowerRect, CGFloat(-19.6)),
                                ("tour_floor_upper", upperRect, CGFloat(-19.55))] {
            if name == "tour_floor_lower" && hasLowerArt { continue }
            if name == "tour_floor_upper" && hasUpperArt { continue }
            guard UIImage(named: name) != nil else { continue }
            // M6 v2 (Aaron: iPhone low 104 with v1): the texture goes to the GPU now, not on first sight mid-play.
            let texture = SKTexture(imageNamed: name)
            texture.preload { }
            let art = SKSpriteNode(texture: texture)
            art.size = rect.size
            art.position = CGPoint(x: rect.midX, y: rect.midY)
            art.zPosition = z
            addChild(art)
            hasFloorArt = true
        }
        // M6 v2: the grey floor under the paintings only cost fill (every pixel drawn twice): gone once art is in.
        if hasFloorArt { greyFloor?.removeFromParent(); greyFloor = nil }
    }
    private var hasFloorArt = false
    /// M6 v3: the lower hardware is baked into the art (the slings then draw only their kick flash).
    private var hasLowerArt = false
    private var greyFloor: SKShapeNode?

    /// M5 v5: the planet window (TourPlanetWindow): stars and a planet deep under the glass, each its own parallax layer.
    private func addPlanetWindow() {
        let w = TourPlanetWindow(center: TourTableLayout.planetWindowCenter, radius: TourTableLayout.planetWindowRadius)
        addChild(w)
        parallax.add(w.deepLayer, anchor: w.center, height: TourTableLayout.planetWindowStarDepth)
        parallax.add(w.planetLayer, anchor: w.center, height: TourTableLayout.planetWindowPlanetDepth)
    }

    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: TourTableLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
        greyFloor = floor
    }

    /// M4 v2: an invisible solid (a static convex polygon, counter-clockwise) behind a wall outline: a ball that a hard
    /// shot puts through the outline's thin edge is pushed back out instead of being trapped inside.
    private func addSolid(points: [CGPoint]) {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        let node = SKNode()
        let body = SKPhysicsBody(polygonFrom: path)
        body.isDynamic = false
        body.friction = TourTableLayout.wallFriction
        body.restitution = TourTableLayout.wallRestitution
        body.categoryBitMask = TourPhysicsCategory.wall
        body.collisionBitMask = TourPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = TourTableLayout.wallFriction,
                         restitution: CGFloat = TourTableLayout.wallRestitution,
                         z: CGFloat = -19.5, physics: Bool = true) {
        let path = CGMutablePath()
        path.addLines(between: points)
        #if DEBUG
        // M6 v4: `-tourDumpWalls` prints every wall for the Blender bake (tools/tour_bake_upper.py reads the console).
        if ProcessInfo.processInfo.arguments.contains("-tourDumpWalls") {
            print("TOURWALL \(physics ? 1 : 0) " + points.map { "\($0.x),\($0.y)" }.joined(separator: ";"))
        }
        #endif

        let node = SKShapeNode(path: path)
        node.strokeColor = Self.wallColor
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z

        if physics {
            let body = SKPhysicsBody(edgeChainFrom: path)
            body.friction = friction
            body.restitution = restitution
            body.categoryBitMask = TourPhysicsCategory.wall
            body.collisionBitMask = TourPhysicsCategory.ball
            node.physicsBody = body
        }

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
        playLiftoff()
    }

    /// The liftoff show: sparks, flame, smoke and the climb (M6 v7–v7c). DEBUG: `-tourLiftoff` plays it 3 s after
    /// the table builds, and every 9 s after that.
    private func playLiftoff() {
        Effects.burst(in: self, at: TourTableLayout.rocketToy, color: SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1),
                      count: 30, speed: 260, lifetime: 0.7)
        rocketToy.removeAllActions()
        rocketToy.position = TourTableLayout.rocketToy
        if let flame = rocketFlame {
            flame.removeAllActions()
            flame.alpha = 0.95
            flame.run(.sequence([
                .repeat(.sequence([.scaleY(to: 1.25, duration: 0.05), .scaleY(to: 0.85, duration: 0.05)]), count: 30),
                .fadeOut(withDuration: 0.1), .scaleY(to: 1, duration: 0)]))
        }
        launchSmoke()
        // M6 v7b (Aaron: "the launch slower"): a slow, accelerating climb over 3 s, fading in its last second.
        let climb = SKAction.moveBy(x: 0, y: 300, duration: 3.0)
        climb.timingMode = .easeIn
        rocketToy.run(.sequence([
            .group([climb, .sequence([.wait(forDuration: 2.0), .fadeOut(withDuration: 1.0)])]),
            .wait(forDuration: 1.2),
            .run { [weak self] in self?.rocketToy.position = TourTableLayout.rocketToy },
            .fadeIn(withDuration: 0.4)]))
    }

    /// M6 v7c (Aaron: "smoke like a real launch … spilled out onto the table"): an exhaust trail left behind the
    /// climbing rocket, and a ground cloud that billows out of the pad and rolls down over the playfield (under the
    /// ball, z 8), growing and thinning over ~4 s.
    private func launchSmoke() {
        let texture = Self.smokeTexture
        let grey = SKColor(red: 0.80, green: 0.81, blue: 0.84, alpha: 1)
        // the trail: from the nozzle, particles stay in the scene where they were born
        if let rocket = rocketToy {
            let trail = SKEmitterNode()
            trail.particleTexture = texture
            trail.particleBirthRate = 50
            trail.particleLifetime = 1.8
            trail.particleLifetimeRange = 0.6
            trail.emissionAngle = -.pi / 2
            trail.emissionAngleRange = 0.7
            trail.particleSpeed = 35
            trail.particleSpeedRange = 20
            trail.particlePositionRange = CGVector(dx: 6, dy: 2)
            trail.particleSize = CGSize(width: 16, height: 16)
            trail.particleScale = 0.7
            trail.particleScaleSpeed = 1.1
            trail.particleRotationRange = .pi * 2
            trail.particleRotationSpeed = 0.4
            trail.particleColorBlendFactor = 1
            trail.particleColorSequence = SKKeyframeSequence(
                keyframeValues: [SKColor(red: 1.0, green: 0.78, blue: 0.48, alpha: 1), grey, grey],
                times: [0, 0.25, 1])
            trail.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.6, 0.3, 0] as [NSNumber],
                                                             times: [0, 0.1, 0.5, 1])
            trail.position = CGPoint(x: 0, y: -6)
            trail.targetNode = self
            trail.particleZPosition = 24
            rocket.addChild(trail)
            trail.run(.sequence([.wait(forDuration: 3.0), .run { trail.particleBirthRate = 0 },
                                 .wait(forDuration: 2.6), .removeFromParent()]))
        }
        // the ground cloud: out of the pad in every direction, most of it rolling down the table toward the flippers
        let cloud = SKEmitterNode()
        cloud.particleTexture = texture
        cloud.particleBirthRate = 80
        cloud.numParticlesToEmit = 130
        cloud.particleLifetime = 4.0
        cloud.particleLifetimeRange = 1.2
        cloud.emissionAngle = -.pi / 2
        cloud.emissionAngleRange = .pi * 1.1
        cloud.particleSpeed = 55
        cloud.particleSpeedRange = 35
        cloud.yAcceleration = -6                        // a little downhill drift
        cloud.particlePositionRange = CGVector(dx: 30, dy: 12)
        cloud.particleSize = CGSize(width: 26, height: 26)
        cloud.particleScale = 0.8
        cloud.particleScaleRange = 0.3
        cloud.particleScaleSpeed = 0.7
        cloud.particleRotationRange = .pi * 2
        cloud.particleRotationSpeed = 0.25
        cloud.particleColorBlendFactor = 1
        cloud.particleColor = grey
        cloud.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.42, 0.28, 0] as [NSNumber],
                                                         times: [0, 0.12, 0.55, 1])
        cloud.position = CGPoint(x: TourTableLayout.rocketToy.x, y: TourTableLayout.rocketToy.y - 6)
        cloud.zPosition = 8
        addChild(cloud)
        cloud.run(.sequence([.wait(forDuration: 7.5), .removeFromParent()]))
    }

    /// A soft round puff for the launch smoke (drawn once).
    private static let smokeTexture: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0.55).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
        return SKTexture(image: image)
    }()

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
        if shotLab != nil || plungeProbe != nil || rocProbe != nil || rideProbe != nil { return shotLabTime }
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
        ball.holdReleaseSpeed = saturn ? TourTableLayout.saturnReleaseSpeed : TourTableLayout.moonReleaseSpeed
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
            let v = ball.holdReleaseSpeed
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
        let label = SKLabelNode(text: "T6 M6 v9")
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
        var text = "\(fps)T6 M6 v9 \(effectiveCameraMode.tag) · \(speed)"
        #if DEBUG
        if let lab = playLab { text += "\n" + lab.progressText }
        #endif
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
        if !playLabStarting { stopPlayLab(saving: true) }   // and the Play Lab, unless it's starting its next game
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
        #if DEBUG
        playLab?.banner(text)
        labObjective(forBanner: text)
        #endif
        game.banner = text
        bannerClearAt = gameTime + TourTableLayout.bannerSeconds
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
        var left = activeTouches.values.contains(.left) || padLeft || robotLeft
        var right = activeTouches.values.contains(.right) || padRight || robotRight
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
        var step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
        #if DEBUG
        if let lab = playLab { step *= Double(lab.physicsSpeed) }   // the Play Lab's pass: 120 Hz or 60 Hz steps
        #endif
        lastRealTime = realTime
        gameTime += step
        let now = gameTime
        #if DEBUG
        if shotLab != nil {                        // Shot Lab: the robot's frame instead of a game frame
            updateShotLab(CGFloat(step))
            return
        }
        if rocProbe != nil {
            updateRocProbe(CGFloat(step))
            return
        }
        if rideProbe != nil {
            updateRideProbe(CGFloat(step))
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
        #if DEBUG
        updatePlayLab(now)
        #endif
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

        #if DEBUG
        checkPlayLabGame(now)
        #endif
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
        // M5 v4: parallax. Raised parts slide with the camera; a floor ball by its own height, a ball held in a crater by
        // the Moon's, a ball riding a ramp not at all (the ramps' outlines don't slide yet). Balls ease so nothing jumps.
        let cam = cameraRig.node.position
        parallax.update(camera: cam)
        for ball in balls {
            let h: CGFloat = ball.isOnFloor ? TourTableLayout.ballRadius
                : (ball.moonReleaseAt != nil ? TourTableLayout.ballRadius + TourTableLayout.rampTopHeight : 0)
            let goal = parallax.shift(at: ball.position, height: h, camera: cam)
            ball.parallaxShift = CGPoint(x: ball.parallaxShift.x + (goal.x - ball.parallaxShift.x) * 0.35,
                                         y: ball.parallaxShift.y + (goal.y - ball.parallaxShift.y) * 0.35)
        }
        placeBuildTag()
    }

    #if DEBUG
    /// M5 v6: the pause card's lighting button cycles flash → steady → off (look and frame-rate test).
    func debugCycleLighting() -> String {
        TourLighting.mode = (TourLighting.mode + 1) % 3
        applyLightingMode()
        return Self.lightingLabel
    }
    static var lightingLabel: String { ["Lights: flash", "Lights: steady", "Lights: off"][TourLighting.mode] }
    #endif

    /// M5 v6: applies TourLighting.mode to every bumper and ball.
    private func applyLightingMode() {
        for b in bumpers { b.applyLightingMode() }
        for ball in balls { ball.visual.lightingBitMask = TourLighting.spriteMask }
    }

    #if DEBUG
    /// M5 v4: the pause card's parallax button cycles off → ×1 → ×2, to judge the look and the frame rate.
    func debugCycleParallax() -> String {
        parallax.strength = parallax.strength >= 2 ? 0 : parallax.strength + 1
        return parallax.strength == 0 ? "Parallax: off" : "Parallax: ×\(Int(parallax.strength))"
    }
    #endif

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
        playLab?.shot(name, now: gameTime)
        #endif
    }
}

#if DEBUG
extension TourTableScene {
    /// Starts the robot: it takes over the flippers and sweeps flip timings from a cradled ball on each flipper at
    /// 120 Hz and 60 Hz physics steps (~25 min in the Simulator). Menu or a new game stops it.
    func debugStartShotLab() {
        stopPlayLab(saving: true)
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

    /// DEBUG (M4 v2): fires balls at the R-O-C bank like the Play Lab's trapping flips (from (200, 370), 2,000–3,000
    /// pt/s at 115–135°) and drops one inside its outline; prints `ROC i x y IN/out trapped?` after 2 s each, then quits.
    func debugRocProbe() {
        isAttractMode = false
        removeAllBalls()
        var cases: [(p: CGPoint, v: CGVector)] = [(CGPoint(x: 30, y: 575), .zero), (CGPoint(x: 40, y: 640), .zero)]
        for speed in stride(from: 2000.0, through: 3400.0, by: 350.0) {
            for deg in stride(from: 110.0, through: 140.0, by: 2.0) {
                let a = CGFloat(deg) * .pi / 180
                cases.append((CGPoint(x: 200, y: 370), CGVector(dx: cos(a) * CGFloat(speed), dy: sin(a) * CGFloat(speed))))
            }
        }
        rocProbe = (cases: cases, t: 99, inside: false)
    }

    /// DEBUG (M4 v3): releases a ball from the Moon's and Saturn's craters (on the way down, as after the hold) at 240…640
    /// pt/s and prints `RIDE moon|saturn speed EXIT|BACK x y t` — EXIT = left the wire at its end (the inlane), BACK = fell
    /// back down the climb to the mouth. Then quits.
    func debugRideProbe() {
        isAttractMode = false
        removeAllBalls()
        var cases: [(saturn: Bool, speed: CGFloat)] = []
        for saturn in [false, true] { for v in stride(from: 240.0, through: 640.0, by: 40.0) { cases.append((saturn, CGFloat(v))) } }
        rideProbe = (cases: cases, saturn: false, speed: 0, t: 99, topY: 0)
    }

    fileprivate func updateRideProbe(_ realDt: CGFloat) {
        guard var probe = rideProbe else { return }
        physicsWorld.speed = 0.5
        let dt = realDt * 0.5
        shotLabTime += TimeInterval(dt)
        lastStep = dt
        leftFlipper.step(dt: dt); rightFlipper.step(dt: dt)
        updateGates(); updateLanes(shotLabTime)
        probe.t += dt
        let ball = balls.first
        if let b = ball { probe.topY = max(probe.topY, b.position.y) }
        if let b = ball, b.isOnFloor || probe.t > 5 {
            let exit = b.position.y < 520
            print(String(format: "RIDE %@ %.0f %@ %.0f %.0f %.2f top %.0f", probe.saturn ? "saturn" : "moon", probe.speed,
                         exit ? "EXIT" : (b.isOnFloor ? "BACK" : "STUCK"), b.position.x, b.position.y, probe.t, probe.topY))
            removeAllBalls()
        }
        if balls.isEmpty {
            guard !probe.cases.isEmpty else { print("RIDE done"); exit(0) }
            let c = probe.cases.removeFirst()
            guard let ramp = c.saturn ? saturnRamp : moonRamp else { return }
            let d = (c.saturn ? TourTableLayout.saturnApexDistance : TourTableLayout.moonApexDistance) + TourTableLayout.rampMadeAfterApex
            let (p, _) = ramp.path.sample(at: d)
            let h = c.saturn ? TourTableLayout.saturnReleaseHeading : TourTableLayout.moonReleaseHeading
            shotLabPlaceBall(at: p, velocity: CGVector(dx: cos(h) * c.speed, dy: sin(h) * c.speed))
            if let b = balls.last { b.activeRamp = ramp; b.setLayer(.rampDown) }
            probe.saturn = c.saturn; probe.speed = c.speed; probe.t = 0; probe.topY = p.y
        }
        rideProbe = probe
    }

    private static func inRocOutline(_ p: CGPoint) -> Bool {
        let a = CGPoint(x: 20, y: 530), c = CGPoint(x: 86.3, y: 672.3), d = CGPoint(x: 20, y: 714.3)
        func side(_ u: CGPoint, _ v: CGPoint) -> CGFloat { (v.x - u.x) * (p.y - u.y) - (v.y - u.y) * (p.x - u.x) }
        return p.x > 20 && side(a, c) > 0 && side(c, d) > 0
    }

    fileprivate func updateRocProbe(_ realDt: CGFloat) {
        guard var probe = rocProbe else { return }
        physicsWorld.speed = 0.5
        let dt = realDt * 0.5
        shotLabTime += TimeInterval(dt)
        lastStep = dt
        leftFlipper.step(dt: dt); rightFlipper.step(dt: dt)
        updateGates(); updateLanes(shotLabTime); updateTargets(shotLabTime)
        probe.t += dt
        if let b = balls.first, Self.inRocOutline(b.position) { probe.inside = true }
        if probe.t > 2 {
            if let b = balls.first {
                let n = 81 - probe.cases.count
                let v = b.physicsBody?.velocity ?? .zero
                let still = hypot(v.dx, v.dy) < 5 && b.position.y > 100
                print(String(format: "ROC %d %.0f %.0f %@ %@", n, b.position.x, b.position.y,
                             probe.inside ? "wentIN" : "out",
                             Self.inRocOutline(b.position) ? "TRAPPED" : (still ? "STILL" : "free")))
            }
            removeAllBalls()
            guard !probe.cases.isEmpty else { print("ROC done"); exit(0) }
            let c = probe.cases.removeFirst()
            shotLabPlaceBall(at: c.p, velocity: c.v)
            probe.t = 0; probe.inside = false
        }
        rocProbe = probe
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

#if DEBUG
// MARK: - M4 v1: the Play Lab host (Monsoon's pattern). Robot players at four skills, 120 Hz and 60 Hz passes; the
// report says what a player meets and which shots get made. No rules yet, so the objectives are the M1–M3 banners.
extension TourTableScene: PlayLabHost {
    var playLabTableName: String { "Grand Tour" }
    var playLabBallRadius: CGFloat { TourTableLayout.ballRadius }
    var playLabVariantCount: Int { 1 }

    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "orbt", text: "Light O-R-B-T in the lanes (rocket post up, +1X)"),
         PlayObjective(name: "multiplier", text: "Reach 2X or more"),
         PlayObjective(name: "star", text: "Light S-T-A-R in the top lanes"),
         PlayObjective(name: "countdown", text: "Hit the rocket's blast door (T-minus)"),
         PlayObjective(name: "liftoff", text: "Count down to liftoff (Mission Control opens)"),
         PlayObjective(name: "missionControl", text: "Shoot Mission Control after liftoff"),
         PlayObjective(name: "rocketWord", text: "Light R-O-C-K-E-T (both banks)"),
         PlayObjective(name: "moon", text: "Make the Moon ramp"),
         PlayObjective(name: "saturn", text: "Make the Saturn ramp"),
         PlayObjective(name: "leftOrbit", text: "Make the left orbit"),
         PlayObjective(name: "rightOrbit", text: "Make the right orbit"),
         PlayObjective(name: "samples", text: "Collect the three Mars samples (rover opens)"),
         PlayObjective(name: "rover", text: "Shoot the rover"),
         PlayObjective(name: "kickback", text: "Use the kickback"),
         PlayObjective(name: "rocketPostSave", text: "The rocket post saves a ball"),
         PlayObjective(name: "ballSaved", text: "The ball save saves a ball")]
    }

    /// Flip delays = the middle of each Shot Lab window (cradle): 120 Hz from shotlab-grand-tour-2026-11-09T14-12-00Z
    /// (left, v14) and 13-15-52Z (right, v12; nothing on the right moved since), 60 Hz from the same runs. At 60 Hz the
    /// left flipper's K-E-T band lands on T and Saturn has no window.
    /// M4 v7: inlane feeds from shotlab-grand-tour-inlane-2026-11-10T00-46-43Z (604 trials): the shot a flip makes with the
    /// ball this far (pt) from the pivot, bands of 3+ trials in 4 pt bins. From the inlane the right flipper's Moon band is
    /// wide (24–51 pt at 120 Hz — why the Moon is made ~2.4× as often as Saturn); Saturn has only a 2-trial band at 120 Hz.
    var playLabFlippers: [PlayRobotFlipper] {
        let specs = shotLabFlippers
        let rest = TourTableLayout.flipperRestAngle
        return [PlayRobotFlipper(name: "left", pivot: specs[0].pivot, length: TourTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: false, cradle: specs[0].cradle, rightButton: false, upper: false,
                                 shots: [("rocket", 0.330), ("ketK", 0.385), ("ketE", 0.444), ("saturn", 0.500),
                                         ("rightOrbit", 0.530)],
                                 shots60: [("rocket", 0.366), ("ketT", 0.450), ("rightOrbit", 0.525)],
                                 inlane: [("ketT", 36, 51), ("rocket", 80, 91)],
                                 inlane60: [("rocket", 24, 35), ("saturn", 44, 47)]),
                PlayRobotFlipper(name: "right", pivot: specs[1].pivot, length: TourTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: specs[1].cradle, rightButton: true, upper: false,
                                 shots: [("rocket", 0.330), ("moon", 0.458), ("leftOrbit", 0.508), ("roc", 0.534)],
                                 shots60: [("rocket", 0.350), ("moon", 0.450), ("leftOrbit", 0.492), ("roc", 0.525)],
                                 inlane: [("moon", 24, 51), ("leftOrbit", 56, 63), ("roc", 64, 79)],
                                 inlane60: [("rocket", 24, 35), ("leftOrbit", 44, 55), ("roc", 60, 63), ("ketE", 72, 75)])]
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
        return ["countdownLeft": countdownLeft, "rocketLit": rocketStandups.filter { $0.isLit }.count]
    }

    func playLabStop() {
        game.isRobot = false
    }

    /// Starts the Play Lab (robot players at four skills, 120 Hz and 60 Hz passes, or as the launch arguments say).
    /// Menu or a new game stops it, saving the games played so far.
    func debugStartPlayLab() {
        shotLab = nil
        stopPlayLab(saving: true)
        isAttractMode = false
        let lab = PlayLab(host: self)
        playLab = lab
        lab.beginGame(now: gameTime)
    }

    /// Everything the robot needs to know this frame, and its buttons and plunger applied.
    fileprivate func updatePlayLab(_ now: TimeInterval) {
        guard let lab = playLab else { return }
        if game.isGameOver || playLabNextAt != nil {
            if robotLeft || robotRight { robotLeft = false; robotRight = false; updateFlippers() }
            return
        }
        let view = PlayRobotView(now: now, balls: balls.map { b in
            PlayRobotView.Ball(position: b.position, velocity: b.physicsBody?.velocity ?? .zero, isUpper: !b.isOnFloor,
                               isHeld: b.heldIn != nil || b.moonReleaseAt != nil, onPlunger: isOnPlunger(b),
                               id: ObjectIdentifier(b).hashValue)
        }, wanted: robotWanted(), lanes: starResetAt == nil && !starLanes.isEmpty
            ? PlayRobotView.Lanes(xs: starLanes.map { $0.position.x }, y: starLanes[0].position.y, lit: starLanes.map { $0.isLit })
            : nil)
        runWatchdog(now, lab)
        guard let cmd = lab.frame(view) else { return }
        if let direction = cmd.nudge { applyNudge(direction) }
        if cmd.left != robotLeft || cmd.right != robotRight {
            robotLeft = cmd.left
            robotRight = cmd.right
            updateFlippers()
        }
        if let power = cmd.plunge, isBallOnPlunger {
            plungerPull = power * TourTableLayout.plungerMaxPull
            releasePlunger()
        }
    }

    /// M4 v4 (the R-O-C trap went unreported: Table 06 had no watchdog): a ball off the table, or one that hasn't moved 4 pt
    /// in 5 s while not held (scoop, crater), on the plunger or cradled, is recorded as an incident and served again
    /// (no ball lost), as on the Lamplight.
    private func runWatchdog(_ now: TimeInterval, _ lab: PlayLab) {
        let w = TourTableLayout.worldSize
        for ball in balls {
            let id = ObjectIdentifier(ball)
            let p = ball.position
            if !p.x.isFinite || !p.y.isFinite || p.x < -30 || p.x > w.width + 30 || p.y > w.height + 30 {
                watchdogRescue("offTable", ball, now, lab)
                continue
            }
            if ball.heldIn != nil || ball.moonReleaseAt != nil || isOnPlunger(ball) || isCradled(ball) || p.y < 0 {
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
    private func isCradled(_ ball: TourBall) -> Bool {
        let specs = shotLabFlippers
        for (i, pressed) in [leftFlipper.isPressed, rightFlipper.isPressed].enumerated() where pressed {
            if hypot(ball.position.x - specs[i].cradle.x, ball.position.y - specs[i].cradle.y) < 30 { return true }
        }
        return false
    }

    private func watchdogRescue(_ kind: String, _ ball: TourBall, _ now: TimeInterval, _ lab: PlayLab) {
        let p = ball.position
        let x = p.x.isFinite ? Double(p.x) : -1, y = p.y.isFinite ? Double(p.y) : -1
        lab.incident(PlayIncident(kind: kind, x: x.rounded(), y: y.rounded(), upper: !ball.isOnFloor,
                                  time: lab.elapsed(now: now).rounded()))
        watchSpots[ObjectIdentifier(ball)] = nil
        removeBall(ball)
        if balls.isEmpty, nextBallAt == nil { nextBallAt = now + 0.5 }      // served again, no ball lost
        showBanner("WATCHDOG · \(kind == "stuck" ? "STUCK BALL" : "BALL OFF THE TABLE") AT \(Int(x)), \(Int(y))")
    }

    /// The shots the table wants, most wanted first (no arrows until the rules): unlit R-O-C-K-E-T letters, the two
    /// ramps, the rocket (the countdown / Mission Control), then the orbits.
    private func robotWanted() -> [String] {
        var w: [String] = []
        let lit = rocketStandups.map { $0.isLit }
        if lit.count >= 6 {
            if lit[0..<3].contains(false) { w.append("roc") }
            for (i, name) in ["ketK", "ketE", "ketT"].enumerated() where !lit[3 + i] { w.append(name) }
        }
        w += ["moon", "saturn", "rocket", "leftOrbit", "rightOrbit", "roc", "ketK", "ketE", "ketT"]
        return w
    }

    /// Banners double as the objective record: the first of each per game is what the report shows.
    fileprivate func labObjective(forBanner text: String) {
        guard let lab = playLab else { return }
        let name: String?
        switch text {
        case "S-T-A-R": name = "star"
        case "LIFTOFF · MISSION CONTROL OPEN": name = "liftoff"
        case "MISSION CONTROL": name = "missionControl"
        case "R-O-C-K-E-T": name = "rocketWord"
        case "MOON": name = "moon"
        case "SATURN": name = "saturn"
        case "LEFT ORBIT": name = "leftOrbit"
        case "RIGHT ORBIT": name = "rightOrbit"
        case "SAMPLES COLLECTED · ROVER OPEN": name = "samples"
        case "ROVER", "ROVER HOME · SAMPLES SAFE": name = "rover"
        case "KICKBACK": name = "kickback"
        case "ROCKET POST SAVE": name = "rocketPostSave"
        case "BALL SAVED": name = "ballSaved"
        default:
            if text.hasPrefix("T-MINUS") { name = "countdown" }
            else if text.hasPrefix("ORBT") { name = "orbt" }
            else { name = nil }
        }
        if let name { lab.objective(name, now: gameTime) }
        if text.hasPrefix("ORBT"), game.multiplier >= 2 { lab.objective("multiplier", now: gameTime) }
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
        lab.endGame(score: game.score, ballsPlayed: TourGameState.ballsPerGame - game.ballsLeft + (over ? 0 : 1),
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
