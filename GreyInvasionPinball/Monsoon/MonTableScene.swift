// Pinball Lab Table 04 (Monsoon): the table scene. Milestone 1 = grey box: Table 03's proven lower table (outer
// wall with both bulges, apron and centre drain, lane guides, outlane walls, slingshots with dead posts), the
// flippers, plunger, the one-way launch gate flap and the top-right lane with its gate flap, the three camera
// modes, 3 balls. Built from CthTableScene.swift's code, trimmed.
// Milestone 2 (look development): the lower table is rendered art in two layers, a pencil sketch and the watercolor,
// mixed by MonPaint's shader: washes of color bloom from where they're laid. For now a slingshot kick lays a small
// wash, and the pause card has debug buttons (Wash / Fill / Sketch); the rules lay the real washes in milestone 8.
// Milestone 3: the upper table in grey box, Table 03's proven top (orbit with the spinner, top lanes, three bumpers,
// the top-right lane and gate, the mesa ramp, the arroyo scoop, the saguaro standups, the upper flipper), with
// markers where the helix, the captive ball and the dust devil go (milestones 4–5). Placeholder points, no rules yet.
// Milestone 4 round 1: the habitrails. The mesa ramp climbs onto a HIGH wire (90 pt) that runs back across the table to
// the left inlane; the arroyo's up-kicker fires the ball onto a LOW wire (40 pt) that runs the other way to the right
// inlane, under the high wire. Each wire has its own collision categories and draws at its own depth.
// Milestone 4 round 2: the diverter at the top of the mesa ramp and the helix. Thrown, the diverter sends the ball on
// up into the helix, which it rides on rails (moved by the scene, no physics walls) 1.5 turns down into the bumpers.
// Until the rules milestone the diverter flips after every mesa ramp shot, so both routes get played.
// Milestone 5: the captive ball (left side) and the dust devil (a spinning disc above the flippers).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class MonTableScene: SKScene {
    private enum Control { case left, right, plunger }

    private let game: MonGameState
    private let settings: GameSettings
    private let cameraRig = MonCameraRig()
    /// Table 03's sounds until Table 04's own set (juice milestone).
    private let sound = MonSoundPlayer()          // M10 v1: Monsoon's own sounds (mon_sfx_*)
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
    #if DEBUG
    /// Milestone 6: the Shot Lab robot (debug builds), its clock, and whether it runs with the dust devil raging.
    private var shotLab: ShotLab?
    private var shotLabTime: TimeInterval = 0
    private var shotLabDevilRaging = false
    /// Play Lab (shared, PlayLab.swift): the run, when its next game starts, and the robot's buttons.
    private var playLab: PlayLab?
    private var playLabNextAt: TimeInterval?
    private var playLabStarting = false
    private var robotLeft = false
    private var robotRight = false
    #endif

    private var balls: [MonBall] = []
    private var servedBall: MonBall?
    private var slingshots: [MonSlingshot] = []
    private var leftFlipper: MonFlipper!
    private var rightFlipper: MonFlipper!
    private var plunger: SKShapeNode!
    /// The one-way gates' flaps (drawn; their physics is per ball: the launch gate and the top gate edges).
    private var launchGateFlap: SKNode?
    private var launchGateClosedAngle: CGFloat = 0
    private var topGateFlap: SKNode?
    private var topGateClosedAngle: CGFloat = 0
    private var isBuilt = false
    // The upper table (milestone 3)
    private var upperFlipper: MonFlipper!
    /// Improve mode (2026-10-26): the flip-spot coach marks on the resting flippers (Settings.improveOn).
    private var coach: FlipCoach?
    private var coachSixty = false
    private var coachRateStreak = 0
    private var ramps: [MonRamp] = []
    private var scoops: [MonScoop] = []
    private var arroyoScoop: MonScoop?
    private var arroyoWire: MonRamp?
    private var mesaRamp: MonRamp?
    /// M4 round 2: the helix (ridden on rails) and the diverter that feeds it.
    private var helixRamp: MonRamp?
    private var diverterToHelix = false
    private var diverterArrow: SKShapeNode?
    private var diverterSwitch: MonRampSwitch?
    // Milestone 5: the two new toys
    private var captive: MonCaptiveBall?
    private var captiveKnockAt: TimeInterval = -1
    // Act 1 (milestone 8 round 2): washes laid per region this game, which regions are painted, bumper hits.
    private var regionUnits = [CGFloat](repeating: 0, count: 5)
    private var paintedRegions = Set<MonRegion>()
    private var bumperHits = 0
    private var monsoonLit = false
    // Act 2, Monsoon (M8 v3): the 2-ball multiball, its ball save, balls waiting to come out of the arroyo,
    // how many regions light it next, and the wildflowers its jackpots have bloomed.
    private var monsoonOn = false
    private var multiballSaveUntil: TimeInterval = 0
    private var pendingReleases = 0
    private var nextReleaseAt: TimeInterval = 0
    private var monsoonNextAt = 3
    private var wildflowers = 0
    private let rain = SKEmitterNode()
    // Act 3, Superbloom (M8 v4): lit, running, the cycle (awards × it), and when the held painting gives way to a
    // new sketch.
    private var superbloomLit = false
    private var superbloomOn = false
    private var cycle = 1
    private var newCycleAt: TimeInterval?
    private let petals = SKEmitterNode()
    // M10 v4: the live storm over the painted sky (cropped to the sky's shape): a darkening, glows of lightning inside
    // the clouds, and now and then a bolt.
    private var stormLayer: SKCropNode?
    private let stormDark = SKSpriteNode(color: SKColor(red: 0.09, green: 0.06, blue: 0.16, alpha: 1), size: .zero)
    private var stormDarkness: CGFloat = 0
    private var nextLightningAt: TimeInterval?
    private static let glowTexture: SKTexture = {
        let size = CGSize(width: 128, height: 128)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0.35).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
                                             endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }
        return SKTexture(image: image)
    }()
    // Carried over (M8 v5): kickback (lit by the full saguaro bank), outlane save (lit by painting a region), the
    // ball save, the skill-shot lane, and the end-of-ball bonus.
    private var kickbackLit = false
    private var outlaneSaveLit = false
    private var ballSaveUsed = false
    private var launchedAt: TimeInterval?
    private var skillLane: Int?
    private var shotsThisBall = 0
    private var spinsThisBall = 0
    private var bonusStart: TimeInterval?
    private var bonusBase = 0
    private var bonusMultiplier = 1
    private var dustDevil: MonDustDevil?
    private var bumpers: [MonBumper] = []
    private var rollovers: [MonRollover] = []
    private var lanesResetAt: TimeInterval?
    private var standups: [MonStandup] = []
    private var standupsResetAt: TimeInterval?
    private var spinner: MonSpinner?
    private var lastSpinTickAt: TimeInterval = 0
    private let rampHaptic = Haptic(style: .medium)
    /// Milestone 2: the lower table's art (mon_lower + sketch + regions); false if it's missing (grey box then).
    private var hasLowerArt = false
    /// Milestone 9: the upper table's art (mon_upper + sketch + regions): sky, mesas and saguaros paint up there.
    private var hasUpperArt = false
    /// Color as progress: the sketch/watercolor shader and its washes.
    private let paint = MonPaint()
    /// Milestone 7: every lamp, by name; states are set each frame by updateLampStates.
    private let lamps = MonLampController()
    /// M7 v2: general illumination — a black veil over the table that dips on a lost ball.
    private let dimmer = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
    private let hitHaptic = Haptic(style: .medium)

    // Input
    private var activeTouches: [UITouch: Control] = [:]
    /// Round 8: the nudge and the tilt (shared rule in Nudge.swift); input from a flick of a flipper finger or the pad.
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
    private var wasOnPlunger = false
    private var ballLaunched = false
    private var bannerClearAt: TimeInterval?

    /// The menu: physics stopped, whole-table camera, touches ignored.
    var isAttractMode = false {
        didSet {
            guard isAttractMode != oldValue else { return }
            #if DEBUG
            if isAttractMode { shotLab = nil }         // Menu stops the Shot Lab
            if isAttractMode { stopPlayLab(saving: true) }      // and the Play Lab (saving the games so far)
            #endif
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode { releaseAllControls(); sound.stopLoops() }
            if isAttractMode { lamps.play(.attract, at: gameTime) } else { lamps.stopShow() }
            refreshCamera()
        }
    }

    var isGamePaused = false {
        didSet {
            if isGamePaused { releaseAllControls() } else { padAArmed = false }
            sound.holdLoops(isGamePaused)                // the storm bed pauses with the game
            isPaused = isGamePaused
            lastRealTime = nil
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    // Grey-box colours: pencil-grey lines on dark paper (the table starts as a sketch).
    static let wallColor = SKColor(red: 0.80, green: 0.78, blue: 0.74, alpha: 1)
    static let floorColor = SKColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)

    init(game: MonGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: MonTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: MonTableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        dimmer.alpha = 0
        dimmer.zPosition = 48                      // over the table and the wires (helix ≤ 46, diverter 47), under the tag
        cameraRig.node.addChild(dimmer)
        setUpRain()
        setUpPetals()
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
        if isAttractMode { return .topDown }
        return (monsoonOn || superbloomOn) && settings.multiballFullTable ? .topDown : settings.cameraMode
    }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        dimmer.size = size
        placeRain()
        placePetals()
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addFloor()
        addLowerArt()
        addUpperArt()
        addWall(points: MonTableLayout.outerWall,
                friction: MonTableLayout.railFriction, restitution: MonTableLayout.railRestitution)
        addWall(points: MonTableLayout.leftLaneGuide)
        addWall(points: MonTableLayout.leftOutlaneWall)
        addWall(points: MonTableLayout.leftOutlanePostRail)      // its rail and post are baked into mon_lower
        addWall(points: MonTableLayout.rightOutlanePostRail)     // (the right one too)
        addWall(points: MonTableLayout.rightOutlaneWall)
        addWall(points: MonTableLayout.rightApron)
        addWall(points: MonTableLayout.rightLaneGuide)

        for s in [MonTableLayout.leftSling, MonTableLayout.rightSling] {
            let sling = MonSlingshot(top: s.top, corner: s.corner, tip: s.tip, artBaked: hasLowerArt,
                                     kickFrom: MonTableLayout.slingKickFrom, kickTo: MonTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = MonFlipper(side: .left, pivot: MonTableLayout.leftFlipperPivot)
        rightFlipper = MonFlipper(side: .right, pivot: MonTableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)
        upperFlipper = MonFlipper(side: .right, pivot: MonTableLayout.upperFlipperPivot,
                                  length: MonTableLayout.upperFlipperLength,
                                  pivotRadius: MonTableLayout.upperFlipperPivotRadius,
                                  tipRadius: MonTableLayout.upperFlipperTipRadius)
        upperFlipper.attach(to: self)
        buildCoach()
        addWall(points: MonTableLayout.upperFlipperGuide)

        addPlunger()
        addLaunchGate()
        addTopGate()
        addUpperTable()
        addLamps()
    }

    /// A dark playfield inside the outer wall, so the table reads against the background.
    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: MonTableLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
    }

    /// Milestone 2: the lower table rendered in Blender (tools/mon_render_lower.py) and given its watercolor and pencil
    /// layers (tools/mon_watercolor.py). It sits over the grey-box floor and wall lines (z -19), which still show
    /// on the unbuilt top half. MonPaint's shader shows the sketch until washes of color are laid.
    private func addLowerArt() {
        guard UIImage(named: "mon_lower") != nil else { return }
        let rect = MonTableLayout.lowerArtRect
        let art = SKSpriteNode(imageNamed: "mon_lower")
        art.size = rect.size
        art.position = CGPoint(x: rect.midX, y: rect.midY)
        art.zPosition = -19
        paint.attach(art, rect: rect, sketch: "mon_lower_sketch", regions: "mon_lower_regions")
        addChild(art)
        hasLowerArt = true
    }

    /// The upper table (M9 v1): the painting's sky, mesas and saguaros with the fixed parts (arch, orbit rail, lane
    /// guides, saguaro bank wall, upper flipper guide, the arroyo hole) rendered in Blender, as color, sketch and
    /// region map (tools/mon_render_table.py → mon_upper_art.py). Same shader as the lower table.
    private func addUpperArt() {
        guard UIImage(named: "mon_upper") != nil else { return }
        let rect = MonTableLayout.upperArtRect
        let art = SKSpriteNode(imageNamed: "mon_upper")
        art.size = rect.size
        art.position = CGPoint(x: rect.midX, y: rect.midY)
        art.zPosition = -19
        paint.attach(art, rect: rect, sketch: "mon_upper_sketch", regions: "mon_upper_regions")
        addChild(art)
        hasUpperArt = true
        addStormLayer(rect: rect)
    }

    /// The live storm's layer: everything in it is cropped to the sky (mon_sky_mask, tools/mon_sky_mask.py), at
    /// z -18.6 — over the painting, under the lamps, walls and parts.
    private func addStormLayer(rect: CGRect) {
        guard UIImage(named: "mon_sky_mask") != nil else { return }
        let crop = SKCropNode()
        let mask = SKSpriteNode(imageNamed: "mon_sky_mask")
        mask.size = rect.size
        mask.position = CGPoint(x: rect.midX, y: rect.midY)
        crop.maskNode = mask
        crop.zPosition = -18.6
        stormDark.size = rect.size
        stormDark.position = mask.position
        stormDark.alpha = 0
        crop.addChild(stormDark)
        addChild(crop)
        stormLayer = crop
    }

    /// Every frame: the sky darkens toward the storm's level and lightning flickers inside the clouds, often in
    /// Monsoon (with bolts and thunder), now and then when Monsoon is lit, never otherwise.
    private func updateStorm(_ dt: CGFloat, now: TimeInterval) {
        guard stormLayer != nil else { return }
        let target: CGFloat = monsoonOn ? MonTableLayout.stormDarkMonsoon
            : (monsoonLit && !superbloomOn ? MonTableLayout.stormDarkLit : 0)
        stormDarkness += (target - stormDarkness) * min(1, dt * 0.8)
        stormDark.alpha = stormDarkness
        let gap: ClosedRange<Double>? = monsoonOn ? MonTableLayout.lightningGapMonsoon
            : (target > 0 ? MonTableLayout.lightningGapLit : nil)
        guard let gap else { nextLightningAt = nil; return }
        guard let due = nextLightningAt else { nextLightningAt = now + .random(in: gap); return }
        guard now >= due else { return }
        nextLightningAt = now + .random(in: gap)
        lightning(bolt: monsoonOn && Bool.random(), strength: monsoonOn ? 1 : 0.6)
    }

    /// One lightning flash in the sky: a glow lighting a cloud from inside (a quick double flicker), maybe a bolt,
    /// and a roll of thunder a moment later.
    private func lightning(bolt: Bool, strength: CGFloat) {
        guard let crop = stormLayer, let p = paint.randomSkyPoint() else { return }
        let glow = SKSpriteNode(texture: Self.glowTexture)
        glow.size = CGSize(width: .random(in: 380...560), height: .random(in: 300...440))
        glow.position = p
        glow.color = SKColor(red: 0.86, green: 0.84, blue: 1.0, alpha: 1)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0
        crop.addChild(glow)
        let a = 0.75 * strength
        glow.run(.sequence([
            .fadeAlpha(to: a, duration: 0.03), .fadeAlpha(to: a * 0.25, duration: 0.07),
            .fadeAlpha(to: a * 0.9, duration: 0.03), .fadeAlpha(to: 0, duration: 0.45), .removeFromParent(),
        ]))
        if bolt { addBolt(from: p, in: crop) }
        let thunderDelay = Double.random(in: 0.35...1.1)
        run(.sequence([.wait(forDuration: thunderDelay), .run { [weak self] in
            guard let self, !self.isAttractMode, !self.isLabRunning else { return }
            self.sound.play(.monsoonLit, volume: Float(self.settings.soundVolume) * Float(0.35 + 0.3 * strength))
        }]))
    }

    /// A jagged bolt from `start` along `heading` (radians; default straight down the table), with one fork. Sky bolts
    /// are additive white-violet (they show on the darkened sky); bumper bolts (`inked`) are gold over a dark ink line
    /// so they read on the light paper too. `scale` sizes the strokes.
    private func addBolt(from start: CGPoint, in parent: SKNode, heading: CGFloat = -.pi / 2,
                         steps: ClosedRange<Int> = 6...9, step: ClosedRange<CGFloat> = 22...42,
                         jitter: CGFloat = 26, scale: CGFloat = 1, inked: Bool = false, z: CGFloat = 0) {
        let dir = CGVector(dx: cos(heading), dy: sin(heading))
        let perp = CGVector(dx: -dir.dy, dy: dir.dx)
        func next(_ p: CGPoint, along: CGFloat, side: CGFloat) -> CGPoint {
            CGPoint(x: p.x + dir.dx * along + perp.dx * side, y: p.y + dir.dy * along + perp.dy * side)
        }
        let path = CGMutablePath()
        var p = start
        path.move(to: p)
        var fork: CGPoint?
        let count = Int.random(in: steps)
        for i in 0..<count {
            p = next(p, along: CGFloat.random(in: step), side: CGFloat.random(in: -jitter...jitter))
            path.addLine(to: p)
            if i == count / 3 { fork = p }
        }
        if var q = fork {
            path.move(to: q)
            let side: CGFloat = Bool.random() ? 1 : -1
            for _ in 0..<max(2, count / 3) {
                q = next(q, along: CGFloat.random(in: step) * 0.75, side: side * CGFloat.random(in: (jitter * 0.4)...(jitter * 1.2)))
                path.addLine(to: q)
            }
        }
        let node = SKNode()
        node.zPosition = z
        let layers: [(CGFloat, SKColor, SKBlendMode)] = inked
            ? [(4.6, SKColor(red: 0.10, green: 0.07, blue: 0.18, alpha: 0.6), .alpha),
               (2.4, SKColor(red: 1.0, green: 0.84, blue: 0.36, alpha: 1), .alpha),
               (0.9, SKColor(red: 1.0, green: 0.98, blue: 0.88, alpha: 1), .alpha)]
            : [(9, SKColor(red: 0.92, green: 0.92, blue: 1.0, alpha: 0.28), .add),
               (3, SKColor(red: 0.92, green: 0.92, blue: 1.0, alpha: 0.6), .add),
               (1.4, SKColor(red: 0.92, green: 0.92, blue: 1.0, alpha: 1), .add)]
        for (width, color, blend) in layers {
            let shape = SKShapeNode(path: path)
            shape.strokeColor = color
            shape.lineWidth = width * scale
            shape.lineJoin = .round
            shape.lineCap = .round
            shape.blendMode = blend
            node.addChild(shape)
        }
        node.alpha = 0
        parent.addChild(node)
        node.run(.sequence([
            .fadeIn(withDuration: 0.02), .fadeAlpha(to: 0.2, duration: 0.06), .fadeIn(withDuration: 0.02),
            .wait(forDuration: 0.06), .fadeOut(withDuration: 0.3), .removeFromParent(),
        ]))
    }

    /// M10 v5: a storm-cloud bumper throws a little gold bolt away from the ball (bigger and forked in Monsoon).
    private func bumperLightning(_ bumper: MonBumper, ball: CGPoint) {
        let away = atan2(bumper.position.y - ball.y, bumper.position.x - ball.x) + CGFloat.random(in: -0.6...0.6)
        let r = MonTableLayout.bumperRadius + 2
        let start = CGPoint(x: bumper.position.x + cos(away) * r, y: bumper.position.y + sin(away) * r)
        if monsoonOn {
            addBolt(from: start, in: self, heading: away, steps: 5...7, step: 14...24, jitter: 13, scale: 1.1,
                    inked: true, z: 34)
        } else {
            addBolt(from: start, in: self, heading: away, steps: 3...4, step: 9...15, jitter: 8, scale: 0.75,
                    inked: true, z: 34)
        }
    }

    /// The pigment a region's washes splash in (darker than the lamp colors, so it reads on the paper).
    private static func pigment(_ region: MonRegion) -> SKColor {
        switch region {
        case .sky: return SKColor(red: 0.40, green: 0.26, blue: 0.62, alpha: 1)       // storm violet
        case .mesas: return SKColor(red: 0.74, green: 0.33, blue: 0.18, alpha: 1)     // mesa rust
        case .saguaros: return SKColor(red: 0.26, green: 0.52, blue: 0.24, alpha: 1)  // saguaro green
        case .arroyo: return SKColor(red: 0.80, green: 0.54, blue: 0.16, alpha: 1)    // ochre
        case .desert, .frame: return SKColor(red: 0.78, green: 0.60, blue: 0.34, alpha: 1)   // sand
        }
    }

    /// M10 v5: a splash of the region's paint where a wash was earned: a blot that spreads and fades, and droplets
    /// thrown up that fall back. Normal blend (not additive), so pigment shows on the light paper. `size` 1 = a full
    /// wash (a dust-devil quarter wash is smaller); `big` for a finished region.
    private func paintSplash(_ region: MonRegion, at p: CGPoint, size: CGFloat, big: Bool = false) {
        let color = Self.pigment(region)
        let k = big ? 1.8 : 0.55 + 0.45 * min(1, size)
        let blot = SKShapeNode(circleOfRadius: 24 * k)
        blot.fillColor = color.withAlphaComponent(0.34)
        blot.strokeColor = color.withAlphaComponent(0.55)
        blot.lineWidth = 1.5
        blot.position = p
        blot.zPosition = 33
        blot.setScale(0.25)
        addChild(blot)
        let grow = SKAction.scale(to: 1, duration: 0.35)
        grow.timingMode = .easeOut
        blot.run(.sequence([.group([grow, .sequence([.wait(forDuration: 0.15), .fadeOut(withDuration: 0.55)])]),
                            .removeFromParent()]))
        let count = Int(big ? 44 : 10 + 14 * min(1, size))
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(imageNamed: "spark")
        e.position = p
        e.zPosition = 34
        e.particleBirthRate = CGFloat(count) * 40
        e.numParticlesToEmit = count
        e.particleLifetime = 0.6
        e.particleLifetimeRange = 0.25
        e.particleSpeed = 240 * k
        e.particleSpeedRange = 140 * k
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi * 1.4
        e.yAcceleration = -900
        e.particleScale = 0.24
        e.particleScaleRange = 0.12
        e.particleScaleSpeed = -0.2
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -1.2
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .alpha
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    /// Wall lines sit at z -19.5: under the baked art, over the grey-box floor (so they show where there's no art yet).
    private func addWall(points: [CGPoint],
                         friction: CGFloat = MonTableLayout.wallFriction,
                         restitution: CGFloat = MonTableLayout.wallRestitution,
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
        body.categoryBitMask = MonPhysicsCategory.wall
        body.collisionBitMask = MonPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
    }

    private func addPlunger() {
        let size = MonTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = MonTableLayout.plungerRestPosition

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = MonPhysicsCategory.wall
        body.collisionBitMask = MonPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    /// The launch gate across the top of the shooter lane: solid per ball, only for a ball above it moving down
    /// (a plunge going up swings the flap and passes; a ball coming back rolls off it into play).
    private func addLaunchGate() {
        let low = MonTableLayout.gateLow, high = MonTableLayout.gateHigh
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: low, to: high)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = MonPhysicsCategory.launchGate
        body.collisionBitMask = MonPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        let (flap, closed) = makeGateFlap(hinge: high, end: low, art: "mon_gate_launch",
                                          box: MonTableLayout.launchGateArtBox)
        launchGateFlap = flap
        launchGateClosedAngle = closed
    }

    /// The top-right lane (a curved wall inside the arch) and its one-way gate: solid per ball, only for a floor
    /// ball moving right (coming round the top), so a plunge rides the arch and an orbit-style ball drops back.
    private func addTopGate() {
        addWall(points: MonTableLayout.topLaneWall,
                friction: MonTableLayout.railFriction, restitution: MonTableLayout.railRestitution)
        let a = MonTableLayout.topGateHinge, b = MonTableLayout.topGateEnd
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = MonTableLayout.railFriction
        body.restitution = MonTableLayout.railRestitution
        body.categoryBitMask = MonPhysicsCategory.diverter
        body.collisionBitMask = MonPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        let (flap, closed) = makeGateFlap(hinge: a, end: b, art: "mon_gate_top", box: MonTableLayout.topGateArtBox)
        topGateFlap = flap
        topGateClosedAngle = closed
    }

    /// The one-way gates, per ball: the top gate is solid for a floor ball moving right; the launch gate for a floor
    /// ball above it moving down.
    private func updateGates() {
        let low = MonTableLayout.gateLow, high = MonTableLayout.gateHigh
        let gx = high.x - low.x, gy = high.y - low.y
        for ball in balls {
            let v = ball.physicsBody?.velocity ?? .zero
            ball.setDiverterSolid(ball.isOnFloor && v.dx > 0)
            let p = ball.position
            let above = gx * (p.y - low.y) - gy * (p.x - low.x) > 0          // left of low → high = above the gate
            ball.setLaunchGateSolid(ball.isOnFloor && above && v.dy < 0)
        }
    }

    /// A drawn gate flap: a blade from `hinge` to `end` with a hinge pin (a rendered sprite when there is one).
    /// Returns the node and its closed angle (the blade points down its local −y).
    private func makeGateFlap(hinge: CGPoint, end: CGPoint, art: String, box: CGRect) -> (SKNode, CGFloat) {
        let flap = SKNode()
        flap.position = hinge
        flap.zPosition = 2
        let closed = atan2(end.y - hinge.y, end.x - hinge.x) + .pi / 2
        if let sprite = MonTableLayout.artSprite(art, box: box) {
            sprite.zRotation = -closed
            flap.addChild(sprite)
            flap.zRotation = closed
            addChild(flap)
            return (flap, closed)
        }
        let length = hypot(end.x - hinge.x, end.y - hinge.y)
        let blade = SKShapeNode(rect: CGRect(x: -2.5, y: -length, width: 5, height: length), cornerRadius: 2)
        blade.fillColor = SKColor(white: 0.72, alpha: 1)
        blade.strokeColor = SKColor(white: 0.30, alpha: 1)
        blade.lineWidth = 1
        flap.addChild(blade)
        let pin = SKShapeNode(circleOfRadius: 4)
        pin.fillColor = SKColor(white: 0.88, alpha: 1)
        pin.strokeColor = SKColor(white: 0.25, alpha: 1)
        pin.lineWidth = 1
        flap.addChild(pin)
        flap.zRotation = closed
        addChild(flap)
        return (flap, closed)
    }

    /// A ball went through a one-way gate: the flap swings open by `by` radians and falls back with a little wobble.
    private func swing(_ flap: SKNode?, closedAngle: CGFloat, by angle: CGFloat) {
        guard let flap else { return }
        sfx(.gate)
        flap.removeAction(forKey: "swing")
        let open = SKAction.rotate(toAngle: closedAngle + angle, duration: 0.07, shortestUnitArc: true)
        let back = SKAction.rotate(toAngle: closedAngle, duration: 0.55, shortestUnitArc: true)
        back.timingMode = .easeIn
        let wobble = SKAction.sequence([.rotate(toAngle: closedAngle + angle * 0.07, duration: 0.08, shortestUnitArc: true),
                                        .rotate(toAngle: closedAngle, duration: 0.1, shortestUnitArc: true)])
        flap.run(.sequence([open, back, wobble]), withKey: "swing")
    }

    // MARK: - Upper table (milestone 3)

    /// Orbit wall with the spinner, top lanes and their posts, the three bumpers, the mesa ramp, the arroyo scoop,
    /// the saguaro standups (wall behind, cap on top), and markers for the parts still to come.
    private func addUpperTable() {
        addWall(points: MonTableLayout.orbitInnerWall,
                friction: MonTableLayout.railFriction, restitution: MonTableLayout.railRestitution)
        let spin = MonSpinner(from: MonTableLayout.spinnerLine.a, to: MonTableLayout.spinnerLine.b)
        addChild(spin)
        spinner = spin

        for x in MonTableLayout.lanePostXs {
            addWall(points: [CGPoint(x: x, y: MonTableLayout.lanePostBottom), CGPoint(x: x, y: MonTableLayout.lanePostTop)])
        }
        for x in MonTableLayout.laneCenterXs {
            let lane = MonRollover(laneCenterX: x)
            addChild(lane)
            rollovers.append(lane)
        }
        for center in MonTableLayout.bumperCenters {
            let bumper = MonBumper(at: center)
            addChild(bumper)
            bumpers.append(bumper)
        }

        // The mesa ramp and its high wire: the top level (rampWall / rampBall), drawn over everything else.
        let (rpath, apex) = MonTableLayout.mesaRampPath()
        let ramp = MonRamp(path: rpath, apexDistance: apex,
                           mouthHalfWidth: MonTableLayout.rampMouthHalfWidth,
                           halfWidth: MonTableLayout.rampHalfWidth,
                           flareLength: MonTableLayout.rampFlareLength,
                           postLength: MonTableLayout.rampPostLength,
                           lowLength: MonTableLayout.rampLowLength,
                           topHeight: MonTableLayout.highWireTopHeight,
                           riseLength: MonTableLayout.highWireRiseLength,
                           zShift: 20)
        addChild(ramp)
        ramps.append(ramp)
        mesaRamp = ramp
        addDiverterAndHelix(on: rpath)

        // The arroyo's low wire: wire only (the up-kicker puts balls on it), its own level, under the high wire.
        let (wpath, wapex) = MonTableLayout.arroyoWirePath()
        let wire = MonRamp(path: wpath, apexDistance: wapex,
                           mouthHalfWidth: MonTableLayout.rampHalfWidth,
                           halfWidth: MonTableLayout.rampHalfWidth,
                           flareLength: MonTableLayout.rampFlareLength,
                           postLength: 0, wireOnly: true,
                           endHeight: MonTableLayout.wireEndHeight,
                           wallCategory: MonPhysicsCategory.lowWireWall,
                           ballCategory: MonPhysicsCategory.lowWireBall)
        addChild(wire)
        ramps.append(wire)
        arroyoWire = wire

        let arroyo = MonScoop(at: MonTableLayout.arroyoCenter, ejectVelocity: MonTableLayout.arroyoEject,
                              points: MonPoints.arroyo, artBaked: hasUpperArt)   // M9: the hole is in the art
        addChild(arroyo)
        scoops = [arroyo]
        arroyoScoop = arroyo

        for y in MonTableLayout.standupYs {
            let target = MonStandup(at: CGPoint(x: MonTableLayout.standupX, y: y))
            addChild(target)
            standups.append(target)
        }
        addWall(points: MonTableLayout.standupBankBackWall)
        addWall(points: MonTableLayout.standupBankCap)

        // Markers for what's still to come: dashed outlines with a name.
        let devil = MonDustDevil(at: MonTableLayout.dustDevilCenter, radius: MonTableLayout.dustDevilRadius)
        addChild(devil)
        dustDevil = devil
        let cap = MonCaptiveBall(mouth: MonTableLayout.captiveMouth, heading: MonTableLayout.captiveHeading,
                                 length: MonTableLayout.captiveLength, halfWidth: MonTableLayout.captiveHalfWidth)
        addChild(cap)
        captive = cap
        addWall(points: MonTableLayout.captiveTopGuard)
        rampHaptic.prepare()
    }

    /// The diverter (an arrow at the top of the mesa ramp's climb showing which way it sends the ball) and the helix.
    private func addDiverterAndHelix(on mesaPath: MonRampPath) {
        let (hpath, hapex) = MonTableLayout.helixPath()
        let helix = MonRamp(path: hpath, apexDistance: hapex,
                            mouthHalfWidth: MonTableLayout.rampHalfWidth,
                            halfWidth: MonTableLayout.rampHalfWidth,
                            flareLength: MonTableLayout.rampFlareLength,
                            postLength: 0, wireOnly: true,
                            endHeight: 0,
                            topHeight: MonTableLayout.helixTopHeight,
                            riseLength: hapex,
                            wallCategory: MonPhysicsCategory.rideWall,
                            ballCategory: MonPhysicsCategory.rideBall,
                            startHeight: MonTableLayout.helixStartHeight,
                            ridden: true)
        addChild(helix)
        helixRamp = helix

        // A line across the mesa channel where the routes split.
        let d = MonTableLayout.diverterDistance
        let (p, h) = mesaPath.sample(at: d)
        let w = MonTableLayout.rampHalfWidth + 2
        let n = CGVector(dx: -sin(h), dy: cos(h))
        diverterSwitch = MonRampSwitch(a: CGPoint(x: p.x + w * n.dx, y: p.y + w * n.dy),
                                       b: CGPoint(x: p.x - w * n.dx, y: p.y - w * n.dy),
                                       forward: CGVector(dx: cos(h), dy: sin(h)))
        // The arrow, drawn up at the wire's height (90 pt × the oblique).
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 14, y: 0))
        arrow.addLine(to: CGPoint(x: -8, y: 8))
        arrow.addLine(to: CGPoint(x: -3, y: 0))
        arrow.addLine(to: CGPoint(x: -8, y: -8))
        arrow.closeSubpath()
        let node = SKShapeNode(path: arrow)
        node.fillColor = SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 0.95)
        node.strokeColor = SKColor(white: 1, alpha: 0.9)
        node.lineWidth = 1
        node.position = CGPoint(x: p.x, y: p.y + MonTableLayout.helixStartHeight * MonTableLayout.oblique)
        node.zPosition = 47
        addChild(node)
        diverterArrow = node
        setDiverter(toHelix: false)
    }

    /// Throws the diverter: true = up into the helix, false = left along the high wire. The arrow points the way.
    private func setDiverter(toHelix: Bool) {
        if toHelix != diverterToHelix, !isAttractMode { sfx(.diverter) }
        diverterToHelix = toHelix
        diverterArrow?.removeAllActions()
        diverterArrow?.run(.rotate(toAngle: toHelix ? 80 * .pi / 180 : 160 * .pi / 180, duration: 0.15, shortestUnitArc: true))
    }

    /// A ball on the mesa ramp went through the thrown diverter: it scores the ramp and starts riding the helix.
    private func startHelixRide(_ ball: MonBall, helix: MonRamp) {
        guard let body = ball.physicsBody else { return }
        let v = body.velocity
        award(MonPoints.rampShot)
        rampHaptic.impactOccurred()
        sfx(.helix)
        showBanner("HELIX")
        lamps.play(.sweep, at: gameTime)            // placeholder trigger (M8: Monsoon / Superbloom start)
        shotEvent("helix")
        ball.setLayer(.rampDown)
        ball.activeRamp = helix
        body.velocity = .zero
        body.isDynamic = false                      // moved by updateRides until it drops off the end
        ball.ride = (s: 0, speed: max(hypot(v.dx, v.dy), MonTableLayout.helixMinSpeed))
        ball.zPosition = helix.rideZ(at: 0)
        paintWash(.mesas, units: 1, at: ball.position)
        if monsoonOn { jackpot(at: ball.position, name: "HELIX") }
        if superbloomOn { superJackpot(at: ball.position) }
    }

    /// Moves every ball riding the helix along it (speeding up as it corkscrews down); at the end it drops onto the
    /// floor heading into the bumpers.
    private func updateRides(_ dt: CGFloat) {
        guard let helix = helixRamp else { return }
        for ball in balls {
            guard var ride = ball.ride, let body = ball.physicsBody else { continue }
            ride.speed = min(MonTableLayout.helixMaxSpeed, ride.speed + MonTableLayout.helixAcceleration * dt)
            ride.s += ride.speed * dt
            let (p, h) = helix.path.sample(at: min(ride.s, helix.path.length))
            ball.position = p
            if ride.s >= helix.path.length {
                ball.ride = nil
                body.isDynamic = true
                ball.setLayer(.floor)
                ball.previousPosition = p
                let speed = min(ride.speed, MonTableLayout.rampReturnMaxSpeed)
                body.velocity = CGVector(dx: cos(h) * speed, dy: sin(h) * speed)
                sfx(.scoopOut)
            } else {
                ball.ride = ride
                ball.zPosition = helix.rideZ(at: ride.s)
            }
        }
    }

    /// Milestone 5: the dust devil pushes floor balls crossing it along its spin (and scores as a ball enters it);
    /// the captive ball scores when it reaches the top of its channel.
    private func updateToys(_ dt: CGFloat, now: TimeInterval) {
        if let devil = dustDevil {
            for ball in balls where ball.isOnFloor && ball.heldIn == nil {
                guard let body = ball.physicsBody else { continue }
                if let v = devil.stir(ballAt: ball.position, velocity: body.velocity, dt: dt) {
                    body.velocity = v
                    if !ball.inDustDevil {
                        ball.inDustDevil = true
                        award(MonPoints.dustDevil)
                        sound.play(.dustDevil, volume: Float(settings.soundVolume) * (devil.isRaging ? 0.9 : 0.5))
                        shotEvent("dustDevil")
                        paintWash(.desert, units: 0.25, at: ball.position)
                        // a puff of sand where the ball enters, so you can see it caught the ball
                        Effects.burst(in: self, at: ball.position, color: SKColor(red: 0.92, green: 0.80, blue: 0.60, alpha: 1),
                                      count: devil.isRaging ? 18 : 10, speed: 140, lifetime: 0.45, size: 0.25)
                    }
                } else {
                    ball.inDustDevil = false
                }
            }
        }
        if let cap = captive, cap.reachedTop(at: now, length: MonTableLayout.captiveLength) {
            award(MonPoints.captiveTop)
            shotEvent("captiveTop")
            if superbloomOn { bloomShot(at: cap.ball.convert(.zero, to: self)) }
            paintWash(.saguaros, units: 1, at: cap.ball.convert(.zero, to: self))
            showBanner("CAPTIVE BALL")
            lamps.play(.flash, at: now)             // placeholder trigger (M8: jackpots)
            rampHaptic.impactOccurred()
            cameraRig.shake(strength: 3, duration: 0.25)
            sfx(.captiveTop)
        }
    }

    /// A faint dashed outline and a small label for a part that isn't built yet.
    private func addMarker(_ shape: SKShapeNode, _ name: String, at labelPoint: CGPoint? = nil) {
        shape.strokeColor = SKColor(white: 0.85, alpha: 0.35)
        shape.fillColor = .clear
        shape.lineWidth = 1.5
        if let path = shape.path {
            shape.path = path.copy(dashingWithPhase: 0, lengths: [6, 5])
        }
        shape.zPosition = -19.4
        addChild(shape)
        let label = SKLabelNode(text: name)
        label.fontName = "Menlo-Bold"
        label.fontSize = 9
        label.fontColor = SKColor(white: 0.9, alpha: 0.5)
        label.verticalAlignmentMode = .center
        label.position = labelPoint ?? shape.position
        label.zPosition = -19.4
        addChild(label)
    }

    /// Every award goes through here (× the multiplier in MonGameState.add). Scoring anything before the skill-shot
    /// lane cancels the skill shot (the spinner doesn't: a plunge can spin it on the way up).
    private func award(_ points: Int, cancelsSkillShot: Bool = true) {
        if cancelsSkillShot, skillLane != nil, ballLaunched { setSkillLane(nil) }
        game.add(points)
    }

    /// Ramp, orbit, spinner and gate switches, checked against how the ball moved this frame (after physics).
    private func updateRampLayer(_ ball: MonBall) {
        let p = ball.position
        let p0 = ball.previousPosition
        ball.previousPosition = p
        if ball.ride != nil { return }                 // riding the helix: the scene moves it

        if ball.layer == .floor {
            if let ramp = ramps.first(where: { $0.acceptsFloorEntry && $0.entrySwitch.crossing(from: p0, to: p) == .forward }) {
                ball.activeRamp = ramp
                ball.setLayer(.rampUp)
                return
            }
            if MonTableLayout.topGateSwitch.crossing(from: p0, to: p) == .forward {
                swing(topGateFlap, closedAngle: topGateClosedAngle, by: -1.75)        // a plunge through the top gate
            }
            if MonTableLayout.rightOutlaneSwitch.crossing(from: p0, to: p) == .forward {
                ball.inRightOutlane = true           // on its way down the right outlane (outlane save)
            }
            if MonTableLayout.launchGateSwitch.crossing(from: p0, to: p) == .forward {
                swing(launchGateFlap, closedAngle: launchGateClosedAngle, by: -1.4)   // a plunge up the shooter lane
            }
            if MonTableLayout.spinnerSwitch.crossing(from: p0, to: p) != .none, let body = ball.physicsBody {
                let v = body.velocity
                spinner?.kick(ballSpeed: hypot(v.dx, v.dy))
                shotEvent("spinner")
                body.velocity = CGVector(dx: v.dx * MonSpinner.ballSpeedKept, dy: v.dy * MonSpinner.ballSpeedKept)
            }
            switch MonTableLayout.orbitArmSwitch.crossing(from: p0, to: p) {
            case .forward: ball.orbitArmed = true
            case .backward: ball.orbitArmed = false
            case .none: break
            }
            if ball.orbitArmed, MonTableLayout.orbitMadeSwitch.crossing(from: p0, to: p) == .forward {
                ball.orbitArmed = false
                award(MonPoints.orbit)
                rampHaptic.impactOccurred(intensity: 0.7)
                sfx(.orbit)
                showBanner("ORBIT")
                shotEvent("orbit")
                if superbloomOn { bloomShot(at: p) }
                paintWash(.sky, units: 1, at: p)
            }
            return
        }
        guard let ramp = ball.activeRamp else { ball.setLayer(.floor); return }

        switch ball.layer {
        case .floor:
            break
        case .rampUp:
            if ramp.entrySwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.floor)
            } else if ramp === mesaRamp, diverterToHelix, let helix = helixRamp,
                      diverterSwitch?.crossing(from: p0, to: p) == .forward {
                startHelixRide(ball, helix: helix)
                return
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.rampDown)
                if ramp === arroyoWire { break }       // the up-kicker scored at the arroyo
                award(MonPoints.rampShot)
                rampHaptic.impactOccurred()
                Effects.burst(in: self, at: p, color: Self.wallColor, count: 14, speed: 200, lifetime: 0.4)
                sfx(.ramp)
                showBanner("MESA RAMP")
                shotEvent("mesaRamp")
                paintWash(.mesas, units: 1, at: p)
                if monsoonOn { jackpot(at: p, name: "MESA RAMP") }
                if superbloomOn { bloomShot(at: p) }
            }
        case .rampDown:
            if ramp.exitSwitch.crossing(from: p0, to: p) == .forward {
                if ramp === mesaRamp || ramp === arroyoWire { paintWash(.arroyo, units: 0.5, at: p) }   // a wire ride
                ball.setLayer(.floor)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.rampUp)
            }
        }

        // Safety net: a ramp ball nowhere near the channel goes back to the floor.
        if ball.layer != .floor,
           ramp.distanceToCenterline(p) > ramp.maxHalfWidth + MonTableLayout.ballRadius + 12 {
            ball.setLayer(.floor)
        }
    }

    /// Catches a floor ball that rolls into an empty hole, holds it, then kicks it out.
    private func updateScoops(_ now: TimeInterval) {
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if let scoop = ball.heldIn {
                ball.position = scoop.position
                body.velocity = .zero
                body.angularVelocity = 0
                if now >= ball.releaseAt {
                    ball.heldIn = nil
                    ball.scoopIgnoreUntil = now + MonTableLayout.scoopRecapture
                    body.affectedByGravity = true
                    if scoop === arroyoScoop, let wire = arroyoWire {
                        upKick(ball, onto: wire)
                    } else {
                        body.velocity = scoop.ejectVelocity
                        sfx(.scoopOut)
                    }
                }
                continue
            }
            guard ball.isOnFloor, now >= ball.scoopIgnoreUntil else { continue }
            let v = body.velocity
            let from = CGPoint(x: ball.position.x - v.dx * lastStep, y: ball.position.y - v.dy * lastStep)
            guard let scoop = scoops.first(where: { candidate in
                candidate.catches(from: from, to: ball.position) && !balls.contains(where: { $0.heldIn === candidate })
            }) else { continue }
            ball.heldIn = scoop
            ball.releaseAt = now + (scoop === arroyoScoop ? MonTableLayout.upKickerHold : MonTableLayout.scoopHold)
            body.affectedByGravity = false
            body.velocity = .zero
            award(scoop.points)
            Effects.burst(in: self, at: scoop.position, color: Self.wallColor, count: 20, speed: 180, lifetime: 0.5)
            sfx(.scoopIn)
            showBanner("ARROYO")
            shotEvent("arroyo")
            paintWash(.arroyo, units: 1, at: scoop.position)
            if scoop === arroyoScoop, !isLabRunning, !monsoonOn, !superbloomOn {
                if superbloomLit { startSuperbloom() } else if monsoonLit { startMonsoon() }
            } else if superbloomOn, scoop === arroyoScoop {
                bloomShot(at: scoop.position)
            }
            scoop.flash()
            rampHaptic.impactOccurred(intensity: 0.8)
        }
    }

    /// The arroyo's up-kicker: fires a ball held in the scoop up onto the low wire, which carries it over the top,
    /// under the high wire, and down into the right inlane.
    private func upKick(_ ball: MonBall, onto wire: MonRamp) {
        guard let body = ball.physicsBody else { return }
        let (p, h) = wire.path.sample(at: MonTableLayout.upKickerStart)
        ball.setLayer(.rampUp)
        ball.activeRamp = wire
        ball.position = p
        ball.previousPosition = p
        body.velocity = CGVector(dx: cos(h) * MonTableLayout.upKickerSpeed, dy: sin(h) * MonTableLayout.upKickerSpeed)
        Effects.burst(in: self, at: MonTableLayout.arroyoCenter, color: Self.wallColor, count: 18, speed: 220, lifetime: 0.4)
        cameraRig.shake(strength: 3, duration: 0.2)
        rampHaptic.impactOccurred()
        sfx(.upKick)
    }

    /// Top lanes: light each one; all three lit blink, clear, and raise the multiplier.
    private func rollOver(_ lane: MonRollover, at now: TimeInterval) {
        shotEvent("lane")
        // Skill shot: the first lane after launch decides it, hit or miss.
        if let skill = skillLane, ballLaunched {
            let hit = rollovers.indices.contains(skill) && rollovers[skill] === lane
            setSkillLane(nil)
            if hit {
                game.add(MonPoints.skillShot)
                rampHaptic.impactOccurred()
                Effects.burst(in: self, at: lane.position, color: SKColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 1),
                              count: 30, speed: 260, lifetime: 0.7)
                sfx(.skillShot)
                cameraRig.shake(strength: 4, duration: 0.3)
                showBanner("SKILL SHOT")
            }
        }
        guard lanesResetAt == nil else { return }
        if lane.isLit {
            award(MonPoints.laneRepeat)
            return
        }
        lane.isLit = true
        award(MonPoints.laneLit)
        sfx(.lane)
        // M11 v2: each lane lit is a quarter wash of sky; the set of three adds another quarter (was one wash at the end)
        let complete = rollovers.allSatisfy({ $0.isLit })
        paintWash(.sky, units: complete ? 0.5 : 0.25, at: lane.position)
        if complete {
            rampHaptic.impactOccurred()
            lanesResetAt = now + 0.6
            if game.raiseMultiplier() {
                showBanner("\(game.multiplier)X")
                sfx(.lanesComplete)
            } else {
                showBanner("LANES COMPLETE")
            }
        }
    }

    private func updateLanes(_ now: TimeInterval) {
        guard let due = lanesResetAt else { return }
        let blinkOn = Int((due - now) * 10) % 2 == 0
        rollovers.forEach { $0.isLit = blinkOn }
        if now >= due {
            lanesResetAt = nil
            rollovers.forEach { $0.isLit = false }
        }
    }

    /// Lane change: each new flipper press shifts the lit lanes that way.
    private func rotateLanes(by step: Int) {
        guard lanesResetAt == nil, !rollovers.isEmpty else { return }
        let lit = rollovers.map { $0.isLit }
        let n = lit.count
        for (i, lane) in rollovers.enumerated() {
            lane.isLit = lit[((i - step) % n + n) % n]
        }
    }

    /// A saguaro standup was hit: it lights; all three lit score the bank, then clear after a moment.
    private func hitStandup(_ target: MonStandup, at now: TimeInterval) {
        award(MonPoints.standup)
        shotEvent("standup")
        if superbloomOn { bloomShot(at: target.position) }
        sfx(.standup)
        hitHaptic.impactOccurred(intensity: 0.7)
        guard standupsResetAt == nil, !target.isLit else { return }
        target.isLit = true
        paintWash(.saguaros, units: 0.5, at: target.position)
        if standups.allSatisfy({ $0.isLit }) {
            award(MonPoints.standupBank)
            kickbackLit = true                       // a full saguaro bank lights the kickback
            showBanner("SAGUAROS")
            paintWash(.saguaros, units: 1, at: target.position)
            lamps.play(.flash, at: now)             // placeholder trigger (M8: jackpots)
            rampHaptic.impactOccurred()
            cameraRig.shake(strength: 4, duration: 0.3)
            sfx(.saguaros)
            standupsResetAt = now + MonTableLayout.standupResetDelay
        }
    }

    private func updateStandups(_ now: TimeInterval) {
        guard let due = standupsResetAt, now >= due else { return }
        standupsResetAt = nil
        standups.forEach { $0.isLit = false }
    }

    /// Scores each spin with a soft tick (at most 20 ticks a second) and shows the total when it stops.
    private func updateSpinner(_ dt: CGFloat, now: TimeInterval) {
        guard let spinner, spinner.isSpinning else { return }
        let spins = spinner.update(dt: dt)
        if spins > 0 {
            award(MonTableLayout.spinnerPoints * spins, cancelsSkillShot: false)
            spinsThisBall += spins
            if now - lastSpinTickAt >= 0.05 {
                lastSpinTickAt = now
                sound.play(.spinner, volume: Float(settings.soundVolume) * 0.6)
            }
        }
        if !spinner.isSpinning, spinner.spinsThisRun > 0 {
            showBanner("SPINNER × \(spinner.spinsThisRun)")
        }
    }

    // MARK: - Lights (milestone 7)

    /// Lamp inserts: an arrow in front of each shot, five paint drops round the dust devil (one per region), the
    /// diverter lamp beside the mesa ramp arrow, shoot again, and the Superbloom star. Plain inserts on the floor
    /// (dim when off) until the art milestone paints them into the playfield.
    private func addLamps() {
        let gold = SKColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 1)        // the painting's breaking light
        func add(_ lamp: MonLamp, _ name: String) {
            addChild(lamp)
            lamps.add(lamp, named: name)
        }
        for (name, spot) in MonTableLayout.shotArrows {
            add(MonLamp(.arrow(length: 24, width: 18), color: gold, at: spot.0, angle: spot.1), "arrow.\(name)")
        }
        for (i, p) in MonTableLayout.paintDropLamps.enumerated() {
            let region = MonRegion(rawValue: i) ?? .desert
            add(MonLamp(.round(radius: MonTableLayout.paintDropRadius), color: Self.lampColor(region), at: p),
                "drop.\(i)")
        }
        add(MonLamp(.round(radius: 6), color: SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1),
                    at: MonTableLayout.helixLamp), "helix")
        add(MonLamp(.round(radius: 9), color: SKColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 1),
                    at: MonTableLayout.shootAgainLamp), "shootAgain")
        add(MonLamp(.star(outer: 20, inner: 8.5), color: SKColor(red: 1.0, green: 0.52, blue: 0.76, alpha: 1),
                    at: MonTableLayout.superbloomLamp), "superbloom")
        add(MonLamp(.round(radius: 9), color: SKColor(red: 1.0, green: 0.54, blue: 0.24, alpha: 1),
                    at: MonTableLayout.kickbackLamp), "kickback")
        add(MonLamp(.round(radius: 9), color: SKColor(red: 0.28, green: 0.88, blue: 0.78, alpha: 1),
                    at: MonTableLayout.outlaneSaveLamp), "outlaneSave")
    }

    /// The lights dip for a moment (a lost ball): fade to half in 0.08 s, hold 0.35 s, back in 0.45 s.
    private func dimTable() {
        dimmer.removeAllActions()
        dimmer.run(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.08),
            .wait(forDuration: 0.35),
            .fadeAlpha(to: 0, duration: 0.45),
        ]))
    }

    /// M9 v3: painted parts follow their region — the storm-cloud bumpers the sky, the standups the saguaros — fading
    /// from pencil to color as washes land (eased, so a wash blooms on the part too).
    private var partColor: [MonRegion: CGFloat] = [:]
    private func updatePartColors(_ dt: CGFloat) {
        for region in [MonRegion.sky, .saguaros] {
            let need = Self.regionNeed[region] ?? 4
            let target = paintedRegions.contains(region) ? 1 : min(1, regionUnits[region.rawValue] / need)
            let now = partColor[region] ?? 0
            let next = abs(target - now) < 0.002 ? target : now + (target - now) * min(1, dt * 1.5)
            partColor[region] = next
            if region == .sky { bumpers.forEach { $0.setColorAmount(next) } }
            else { standups.forEach { $0.setColorAmount(next) } }
        }
    }

    /// Each region's lamp color, from the painting.
    private static func lampColor(_ region: MonRegion) -> SKColor {
        switch region {
        case .sky: return SKColor(red: 0.66, green: 0.48, blue: 1.0, alpha: 1)       // monsoon violet
        case .mesas: return SKColor(red: 0.96, green: 0.50, blue: 0.32, alpha: 1)     // mesa rust
        case .saguaros: return SKColor(red: 0.52, green: 0.90, blue: 0.46, alpha: 1)  // saguaro green
        case .arroyo: return SKColor(red: 0.98, green: 0.74, blue: 0.30, alpha: 1)    // ochre
        case .desert, .frame: return SKColor(red: 1.0, green: 0.90, blue: 0.62, alpha: 1)   // sand
        }
    }

    /// Lamp states from Act 1 (M8 v2): each region's paint drop is lit when painted, blinks part-way, dark when
    /// untouched; a shot's arrow blinks while its region still needs color (orbit → sky, mesa ramp → mesas, saguaros
    /// and captive ball → saguaros, arroyo → arroyo); the arroyo arrow fast-blinks once Monsoon is lit. The helix lamp
    /// shows the diverter. Shoot again and Superbloom stay dark until those rules exist.
    private func updateLampStates() {
        for (i, region) in MonRegion.allCases.prefix(5).enumerated() {
            let units = regionUnits[i]
            lamps.set("drop.\(i)", paintedRegions.contains(region) ? .on : (units > 0 ? .blink : .off))
        }
        func needs(_ r: MonRegion) -> MonLampState { paintedRegions.contains(r) ? .off : .blink }
        lamps.set("helix", diverterToHelix ? .on : .off)
        let all: MonLampState? = superbloomOn ? .fastBlink : nil      // Superbloom: every shot lit
        lamps.set("arrow.orbit", all ?? needs(.sky))
        lamps.set("arrow.mesaRamp", all ?? (monsoonOn ? .fastBlink : needs(.mesas)))   // Monsoon: the jackpot
        lamps.set("arrow.saguaros", all ?? needs(.saguaros))
        lamps.set("arrow.captive", all ?? needs(.saguaros))
        lamps.set("arrow.arroyo", all ?? (monsoonLit || superbloomLit ? .fastBlink : needs(.arroyo)))
        // Shoot again: the multiball save, or this ball's own save (on while waiting on the plunger).
        var saveLeft = monsoonOn || superbloomOn ? multiballSaveUntil - gameTime : 0
        if !ballSaveUsed {
            if let t = launchedAt { saveLeft = max(saveLeft, MonTableLayout.ballSaveSeconds - (gameTime - t)) }
            else if servedBall != nil { saveLeft = .infinity }
        }
        lamps.set("shootAgain", saveLeft <= 0 ? .off : (saveLeft < MonTableLayout.ballSaveWarning ? .fastBlink : .on))
        lamps.set("kickback", kickbackLit ? .on : .off)
        lamps.set("outlaneSave", outlaneSaveLit ? .on : .off)
        lamps.set("superbloom", superbloomOn ? .on : (superbloomLit ? .blink : .off))
    }

    // MARK: - Rules: Act 1 (milestone 8 round 2)

    /// Washes needed to paint each region all the way (the arroyo is the easy shot, so it needs more).
    /// M8 v6 (simulator, tools/mon_simulate.py): saguaros 4 → 5, arroyo 5 → 6, desert 4 → 6, so an average player
    /// finishes the painting in about half their games (it was two in three at 120 Hz).
    static let regionNeed: [MonRegion: CGFloat] = [.sky: 5, .mesas: 3, .saguaros: 5, .arroyo: 6, .desert: 6]

    /// One step of Act 1: lays a wash of `region`'s color near `point` (`units` = how much of a wash: a standup is
    /// half, a dust-devil pass a quarter). When the region has all its washes it fills in completely; three regions
    /// painted lights Monsoon at the arroyo (the multiball itself is the next round).
    private func paintWash(_ region: MonRegion, units: CGFloat, at point: CGPoint, touch: Bool = false) {
        #if DEBUG
        if shotLab != nil { return }                // the robots don't play the rules
        #endif
        guard region.rawValue < regionUnits.count, !paintedRegions.contains(region) else { return }
        let need = Self.regionNeed[region] ?? 4
        regionUnits[region.rawValue] += units
        // M9 v4 (Aaron: "it's pretty easy to fill in the table with color without ever getting to monsoon"): each wash
        // colors its share of the region. M10 v2: measured on the real picture now (MonPaint keeps a CPU copy), so the
        // washes before the last really show ~75% of their share and the last one only finishes the rest.
        // M11 v2: 0.92 (was 0.75) — the washes show nearly all their share, so finishing a region only fills the gaps
        // (Aaron: the sky filled "a big chunk instead of a little at a time"). A touch (a bumper's bit of sky) just
        // grows the nearest patch, with no splash.
        if touch {
            paint.addTouch(at: point, region: region, amount: 0.92 * units / need)
        } else {
            paint.addWash(at: point, region: region, amount: 0.92 * units / need)
            paintSplash(region, at: point, size: units)
            hitHaptic.impactOccurred(intensity: 0.4)
        }
        if units >= 0.5 { award(MonPoints.wash * cycle); sfx(.wash) }
        guard regionUnits[region.rawValue] >= need - 0.001 else { return }
        paintedRegions.insert(region)
        paint.fill(region, to: 1)
        paintSplash(region, at: point, size: 1, big: true)
        award(MonPoints.regionPainted * cycle)
        outlaneSaveLit = true                        // each painted region lights the outlane save
        showBanner("\(Self.regionName(region)) PAINTED")
        sfx(.regionPainted)
        lamps.play(.flash, at: gameTime)
        rampHaptic.impactOccurred(intensity: 1)
        cameraRig.shake(strength: 3, duration: 0.25)
        if paintedRegions.count >= monsoonNextAt, !monsoonLit, !monsoonOn, !superbloomLit,
           paintedRegions.count < 5 || wildflowers < MonTableLayout.wildflowersNeeded {
            monsoonLit = true
            showBanner("MONSOON IS LIT · SHOOT THE ARROYO")
            sfx(.monsoonLit)
            lamps.play(.sweep, at: gameTime)
        }
        if paintedRegions.count == 5, !checkSuperbloomLit() {
            showBanner(wildflowers < MonTableLayout.wildflowersNeeded
                       ? "THE DESERT IS PAINTED · BLOOM THE WILDFLOWERS IN MONSOON" : "THE DESERT IS PAINTED")
            lamps.play(.sweep, at: gameTime)
        }
    }

    // MARK: - Rules: Act 2, Monsoon (milestone 8 round 3)

    /// The arroyo caught a ball with Monsoon lit: the caught ball goes up the low wire as usual and a second follows it
    /// out of the arroyo a second later. 10 s ball save; rain over the table; the diverter throws to the helix, and the
    /// helix (or the mesa ramp) is a jackpot that blooms wildflowers. It ends when one ball is left, and lights again
    /// two painted regions later.
    private func startMonsoon() {
        monsoonLit = false
        monsoonOn = true
        monsoonNextAt = paintedRegions.count + 2
        pendingReleases += 1
        nextReleaseAt = gameTime + MonTableLayout.monsoonReleaseDelay
        multiballSaveUntil = gameTime + MonTableLayout.monsoonBallSaveSeconds
        setDiverter(toHelix: true)
        rain.particleBirthRate = MonTableLayout.monsoonRainRate     // M10 v4: heavier (was 140)
        showBanner("MONSOON!")
        sfx(.monsoonStart)
        lamps.play(.sweep, at: gameTime)
        cameraRig.shake(strength: 6, duration: 0.5)
        rampHaptic.impactOccurred(intensity: 1)
        refreshCamera()
    }

    /// Fires waiting Monsoon balls up out of the arroyo onto the low wire (one at a time, only while the hole is
    /// empty), and ends Monsoon when one ball is left.
    private func updateMonsoon(_ now: TimeInterval) {
        if pendingReleases > 0, now >= nextReleaseAt, let scoop = arroyoScoop, let wire = arroyoWire,
           !balls.contains(where: { $0.heldIn === scoop }) {
            let ball = MonBall(at: MonTableLayout.arroyoCenter)
            addChild(ball)
            balls.append(ball)
            upKick(ball, onto: wire)
            pendingReleases -= 1
            nextReleaseAt = now + MonTableLayout.monsoonReleaseDelay
        }
        if monsoonOn, pendingReleases == 0, balls.count <= 1 {
            monsoonOn = false
            multiballSaveUntil = 0
            setDiverter(toHelix: false)
            rain.particleBirthRate = 0
            sfx(.stormPasses)
            showBanner(paintedRegions.count >= monsoonNextAt ? "THE STORM PASSES" :
                        "THE STORM PASSES · PAINT \(monsoonNextAt - paintedRegions.count) MORE")
            if paintedRegions.count == 5 {
                // Everything painted: Monsoon again until the wildflowers are out, then the finale.
                if wildflowers < MonTableLayout.wildflowersNeeded { monsoonLit = true }
            } else if paintedRegions.count >= monsoonNextAt {
                monsoonLit = true                   // already painted enough to light it again
            }
            checkSuperbloomLit()
            refreshCamera()
        }
        if superbloomOn, pendingReleases == 0, balls.count <= 1 { endSuperbloom(now) }
        if let due = newCycleAt, now >= due {
            newCycleAt = nil
            startNewCycle()
        }
    }

    /// A Monsoon jackpot: points, a flash, and a patch of wildflowers (a wash; their own art comes in milestone 9).
    private func jackpot(at point: CGPoint, name: String) {
        award(MonPoints.jackpot * cycle)
        wildflowers += 1
        let spot = paint.randomPoint(in: .desert) ?? point
        paint.addWash(at: spot, region: .desert, amount: 0.08)
        sfx(.jackpot)
        showBanner("\(name) JACKPOT · WILDFLOWERS \(min(wildflowers, MonTableLayout.wildflowersNeeded))/\(MonTableLayout.wildflowersNeeded)")
        lamps.play(.flash, at: gameTime)
        cameraRig.shake(strength: 5, duration: 0.35)
        rampHaptic.impactOccurred(intensity: 1)
        Effects.burst(in: self, at: point, color: SKColor(red: 1.0, green: 0.55, blue: 0.80, alpha: 1),
                      count: 24, speed: 220, lifetime: 0.6)
    }

    // MARK: - Carried over from Table 03 (milestone 8 round 5)

    /// The shots that count toward the end-of-ball bonus (the same events the Shot Lab sees).
    private static let bonusShots: Set<String> = ["mesaRamp", "helix", "orbit", "arroyo", "standup", "lane", "captiveTop"]

    /// Whether a ball that drains now is saved: once per player ball, while it waits on the plunger and for the first
    /// 10 s after launch.
    private var ballSaveNow: Bool {
        guard !ballSaveUsed else { return false }
        if let t = launchedAt { return gameTime - t <= MonTableLayout.ballSaveSeconds }
        return true
    }

    /// Puts the skill-shot ring on one top lane (nil = none).
    private func setSkillLane(_ index: Int?) {
        skillLane = index
        for (i, lane) in rollovers.enumerated() {
            lane.isSkillTarget = (i == index)
        }
    }

    /// A lit kickback fires a ball draining down the left outlane straight back up it. Lit at the start of every
    /// ball; one save, then a full saguaro bank must relight it.
    private func updateKickback() {
        guard kickbackLit, !nudge.tilted else { return }      // round 8b′: no kickback while tilted
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody else { continue }
            let p = ball.position
            if p.x < MonTableLayout.kickbackMaxX, p.y < MonTableLayout.kickbackTriggerY, p.y > 0, body.velocity.dy < 0 {
                body.velocity = CGVector(dx: 0, dy: MonTableLayout.kickbackSpeed)
                kickbackLit = false
                rampHaptic.impactOccurred()
                Effects.burst(in: self, at: p, color: Self.wallColor, count: 18, speed: 240, lifetime: 0.4)
                cameraRig.shake(strength: 3, duration: 0.25)
                sfx(.kickback)
                showBanner("KICKBACK")
                return
            }
        }
    }

    private func startBonus(at now: TimeInterval) {
        bonusBase = shotsThisBall * MonTableLayout.bonusPerShot + spinsThisBall * MonTableLayout.bonusPerSpin
        bonusMultiplier = game.multiplier
        bonusStart = now
    }

    /// Counts the bonus up in the HUD, shows the multiplier, adds it, then loses the ball.
    private func updateBonus(_ now: TimeInterval) {
        guard let start = bonusStart else { return }
        let t = now - start
        let counting = settings.bonusCountOn         // off in Settings: added straight away
        let countTime = counting ? MonTableLayout.bonusCountSeconds : 0
        let holdTime = counting ? MonTableLayout.bonusHoldSeconds : 0
        var text: String
        if t < countTime {
            let shown = Int(Double(bonusBase) * min(t / countTime, 1) / 10) * 10
            text = "BONUS \(shown.formatted())"
        } else {
            text = "BONUS \(bonusBase.formatted())"
            if bonusMultiplier > 1 {
                text += " × \(bonusMultiplier) = \((bonusBase * bonusMultiplier).formatted())"
            }
        }
        if counting, game.bonusText != text { game.bonusText = text }
        guard t >= countTime + holdTime else { return }

        game.add(bonusBase)                          // × the multiplier, which ballDrained then resets
        game.bonusText = nil
        bonusStart = nil
        shotsThisBall = 0
        spinsThisBall = 0
        game.ballDrained()
        if !game.isGameOver {
            nextBallAt = now + 0.5
            // Play Lab run 1: 7 of 16 drains went down the unprotected left outlane, so each new ball starts with
            // the kickback lit (one save); a full saguaro bank relights it.
            kickbackLit = true
        }
    }

    // MARK: - Rules: Act 3, Superbloom (milestone 8 round 4)

    /// All five regions painted and the wildflowers bloomed (outside a multiball): Superbloom lights at the arroyo.
    /// Returns true if it just lit.
    @discardableResult
    private func checkSuperbloomLit() -> Bool {
        guard !superbloomLit, !superbloomOn, !monsoonOn, newCycleAt == nil, paintedRegions.count == 5,
              wildflowers >= MonTableLayout.wildflowersNeeded else { return false }
        superbloomLit = true
        monsoonLit = false
        showBanner("SUPERBLOOM IS LIT · SHOOT THE ARROYO")
        sfx(.superbloomLit)
        lamps.play(.sweep, at: gameTime)
        rampHaptic.impactOccurred(intensity: 1)
        return true
    }

    /// The finale: the caught ball goes up the low wire and two more follow it out of the arroyo. 25 s ball save,
    /// petals drift over the table, every major shot is lit, and the helix is a super jackpot.
    private func startSuperbloom() {
        superbloomLit = false
        superbloomOn = true
        pendingReleases += 2
        nextReleaseAt = gameTime + MonTableLayout.monsoonReleaseDelay
        multiballSaveUntil = gameTime + MonTableLayout.superbloomBallSaveSeconds
        setDiverter(toHelix: true)
        petals.particleBirthRate = 45
        showBanner("SUPERBLOOM!")
        sfx(.superbloomStart)
        lamps.play(.sweep, at: gameTime)
        cameraRig.shake(strength: 8, duration: 0.7)
        rampHaptic.impactOccurred(intensity: 1)
        refreshCamera()
    }

    /// A lit shot during Superbloom.
    private func bloomShot(at point: CGPoint) {
        award(MonPoints.bloomShot * cycle)
        showBanner("BLOOM \((MonPoints.bloomShot * cycle).formatted())")
        sfx(.bloom)
        Effects.burst(in: self, at: point, color: SKColor(red: 1.0, green: 0.55, blue: 0.80, alpha: 1),
                      count: 16, speed: 180, lifetime: 0.5)
    }

    /// The helix during Superbloom.
    private func superJackpot(at point: CGPoint) {
        award(MonPoints.superJackpot * cycle)
        showBanner("SUPER JACKPOT \((MonPoints.superJackpot * cycle).formatted())")
        sfx(.superJackpot)
        lamps.play(.flash, at: gameTime)
        cameraRig.shake(strength: 8, duration: 0.5)
        rampHaptic.impactOccurred(intensity: 1)
        Effects.burst(in: self, at: point, color: SKColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 1),
                      count: 32, speed: 260, lifetime: 0.7)
    }

    /// One ball left: the finale is over. The finished painting is held for a moment, then a new sketch begins.
    private func endSuperbloom(_ now: TimeInterval) {
        superbloomOn = false
        multiballSaveUntil = 0
        setDiverter(toHelix: false)
        petals.particleBirthRate = 0
        for region in MonRegion.allCases { paint.fill(region, to: 1) }   // every last corner in color
        showBanner("THE PAINTING IS FINISHED")
        sfx(.paintingFinished)
        lamps.play(.flash, at: now)
        newCycleAt = now + MonTableLayout.paintingHoldSeconds
        refreshCamera()
    }

    /// The next cycle: back to the sketch, everything to paint again, awards × the new cycle.
    private func startNewCycle() {
        cycle += 1
        paint.reset()
        regionUnits = regionUnits.map { _ in 0 }
        paintedRegions.removeAll()
        wildflowers = 0
        monsoonNextAt = 3
        monsoonLit = false
        showBanner("A NEW SKETCH · AWARDS × \(cycle)")
        sfx(.newSketch)
        lamps.play(.sweep, at: gameTime)
    }

    /// Petals drifting down the screen during Superbloom (on the camera, like the rain).
    private func setUpPetals() {
        petals.particleBirthRate = 0
        petals.particleLifetime = 3.5
        petals.particleSize = CGSize(width: 6, height: 4)
        petals.particleColor = SKColor(red: 1.0, green: 0.62, blue: 0.82, alpha: 1)
        petals.particleColorBlendFactor = 1
        petals.particleColorRedRange = 0.1
        petals.particleColorGreenRange = 0.3
        petals.particleAlpha = 0.8
        petals.particleAlphaRange = 0.2
        petals.particleSpeed = 160
        petals.particleSpeedRange = 60
        petals.emissionAngle = -.pi / 2
        petals.emissionAngleRange = 0.6
        petals.particleRotationRange = .pi * 2
        petals.particleRotationSpeed = 2.5
        petals.zPosition = 46.4
        cameraRig.node.addChild(petals)
        placePetals()
    }

    private func placePetals() {
        petals.position = CGPoint(x: 0, y: size.height / 2 + 20)
        petals.particlePositionRange = CGVector(dx: size.width * 1.2, dy: 0)
    }

    /// Rain streaks falling across the screen (on the camera, under the dim and the tag), off until Monsoon.
    private func setUpRain() {
        rain.particleBirthRate = 0
        rain.particleLifetime = 0.9
        rain.particleSize = CGSize(width: 1.5, height: 16)
        rain.particleColor = SKColor(red: 0.80, green: 0.88, blue: 1.0, alpha: 1)
        rain.particleColorBlendFactor = 1
        rain.particleAlpha = 0.42
        rain.particleAlphaRange = 0.18
        rain.particleSpeed = 1100
        rain.particleSpeedRange = 200
        rain.emissionAngle = -.pi / 2 - 0.18          // falling, slanted a little by the wind
        rain.particleRotation = -0.18
        rain.zPosition = 46.5
        cameraRig.node.addChild(rain)
        placeRain()
    }

    private func placeRain() {
        rain.position = CGPoint(x: 0, y: size.height / 2 + 30)
        rain.particlePositionRange = CGVector(dx: size.width * 1.3, dy: 0)
    }

    private static func regionName(_ region: MonRegion) -> String {
        switch region {
        case .sky: return "SKY"
        case .mesas: return "MESAS"
        case .saguaros: return "SAGUAROS"
        case .arroyo: return "ARROYO"
        case .desert: return "DESERT"
        case .frame: return "FRAME"
        }
    }

    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: "T4 M11 v7")
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
        var level = "floor"
        if let ball = focusBall, ball.layer != .floor {
            let which = ball.ride != nil ? "helix" : (ball.activeRamp === arroyoWire ? "low wire" : "high wire")
            level = ball.layer == .rampUp ? "\(which) up" : which
        }
        var text = "\(fps)T4 M5 v3 \(effectiveCameraMode.tag) · \(level) · \(speed)"
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
    private var focusBall: MonBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func placeBallOnPlunger() {
        ballLaunched = false
        wasOnPlunger = false
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // round 8: a tilt ends here
        let r = MonTableLayout.ballRadius
        let ball = MonBall(at: CGPoint(x: MonTableLayout.laneCenterX, y: MonTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        servedBall = ball
        launchedAt = nil
        setSkillLane(rollovers.isEmpty ? nil : Int.random(in: 0..<rollovers.count))
    }

    private func removeBall(_ ball: MonBall) {
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
    }

    private func removeAllBalls() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        servedBall = nil
    }

    private func isOnPlunger(_ ball: MonBall) -> Bool {
        ball.position.x > MonTableLayout.laneWallX
            && ball.position.y < MonTableLayout.plungerRestTop + MonTableLayout.ballRadius * 3
    }

    private var plungerBall: MonBall? {
        balls.first(where: { isOnPlunger($0) })
    }

    private var isBallOnPlunger: Bool { plungerBall != nil }

    func newGame() {
        fpsLow = 0
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game (or Menu) stops the Shot Lab
        if !playLabStarting { stopPlayLab(saving: true) }   // and the Play Lab, unless it's starting its next game
        #endif
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        sound.stopLoops()                          // a new game starts in the dry desert
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = MonTableLayout.plungerRestPosition
        paint.reset()                              // every game starts from the sketch
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        standupsResetAt = nil
        standups.forEach { $0.isLit = false }
        setDiverter(toHelix: false)
        captive?.reset()
        dustDevil?.isRaging = false
        monsoonOn = false
        superbloomLit = false
        superbloomOn = false
        kickbackLit = true                         // every ball starts with the kickback lit
        outlaneSaveLit = false
        ballSaveUsed = false
        launchedAt = nil
        shotsThisBall = 0
        spinsThisBall = 0
        bonusStart = nil
        game.bonusText = nil
        cycle = 1
        newCycleAt = nil
        petals.particleBirthRate = 0
        multiballSaveUntil = 0
        pendingReleases = 0
        monsoonNextAt = 3
        wildflowers = 0
        rain.particleBirthRate = 0
        regionUnits = regionUnits.map { _ in 0 }
        paintedRegions.removeAll()
        bumperHits = 0
        monsoonLit = false
        lamps.stopShow()
        stormDarkness = 0
        stormDark.alpha = 0
        nextLightningAt = nil
        dimmer.removeAllActions()
        dimmer.alpha = 0
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
        bannerClearAt = gameTime + MonTableLayout.bannerSeconds
    }

    /// M10 v3: the storm bed follows the game. Act 1 starts in a dry desert (wind, cicadas); each painted region brings
    /// the thunder closer and the desert fades; Monsoon lit brings the first drops; Monsoon is full rain and thunder;
    /// Superbloom eases the rain and the birds come out; the finished painting is birds and a breeze. Silent at game over.
    private func updateStormBed(_ dt: CGFloat) {
        var v = Float(settings.soundVolume) * Float(MonTableLayout.stormBedGain)
        #if DEBUG
        if playLab != nil { v = 0 }                // the robot plays silently
        #endif
        let p = Float(paintedRegions.count) / 5
        var mix: [MonLoop: Float]
        if game.isGameOver {
            mix = [:]
        } else if superbloomOn {
            mix = [.desert: 0.2, .thunder: 0.1, .rain: 0.45, .birds: 1]
        } else if newCycleAt != nil {
            mix = [.desert: 0.3, .birds: 1]                      // the painting is finished
        } else if monsoonOn {
            mix = [.desert: 0.1, .thunder: 1, .rain: 1]
        } else {
            mix = [.desert: 1 - 0.55 * p, .thunder: 0.12 + 0.7 * p]
            // (the desert layer is scaled down below: M10 v4, the wind sits in the background)
            if monsoonLit || superbloomLit { mix[.thunder] = max(mix[.thunder] ?? 0, 0.8); mix[.rain] = 0.18 }
        }
        mix[.desert] = (mix[.desert] ?? 0) * Float(MonTableLayout.desertWindGain)
        for loop in MonLoop.allCases { sound.setLoop(loop, target: (mix[loop] ?? 0) * v) }
        sound.stepLoops(dt: Float(dt))
    }

    private func sfx(_ s: MonSound) {
        #if DEBUG
        if shotLab != nil || playLab != nil { return }   // the robots play silently
        #endif
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, !isAttractMode else { return }
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
        return p.x > b.width * MonTableLayout.plungerZoneMinX && p.y > b.height * MonTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches {
            let p = touch.location(in: view)
            switch activeTouches[touch] {
            case .plunger:
                let dragged = (p.y - plungerStartY) * cameraRig.node.yScale
                plungerPull = min(max(dragged, 0), MonTableLayout.plungerMaxPull)
                plunger.position.y = MonTableLayout.plungerRestPosition.y - plungerPull
            case .left, .right:
                // Round 8: a quick flick of a flipper finger nudges the table.
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
        #if DEBUG
        left = left || robotLeft
        right = right || robotRight
        #endif
        if nudge.tilted { left = false; right = false }      // round 8: tilted — dead flippers until the next ball
        if left && !leftFlipper.isPressed { rotateLanes(by: -1); sfx(.flipper) }
        if right && !rightFlipper.isPressed { rotateLanes(by: 1); sfx(.flipper) }
        if left && !leftFlipper.isPressed { coachFlip(0) }
        if right && !rightFlipper.isPressed { coachFlip(1); coachFlip(2) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
        upperFlipper?.isPressed = right
    }

    // MARK: Improve mode (2026-10-26)

    /// The flip-spot coach: the three flippers at rest with Monsoon's Shot Lab bands (MonCoachBands).
    private func buildCoach() {
        let rest = MonTableLayout.flipperRestAngle
        let lower = { (pivot: CGPoint, pointsLeft: Bool, b120: [FlipCoach.Band], b60: [FlipCoach.Band]) in
            FlipCoach.Flipper(pivot: pivot, pointsLeft: pointsLeft, restAngle: rest,
                              length: MonTableLayout.flipperLength, pivotRadius: MonTableLayout.flipperPivotRadius,
                              tipRadius: MonTableLayout.flipperTipRadius, bands120: b120, bands60: b60)
        }
        let upper = FlipCoach.Flipper(pivot: MonTableLayout.upperFlipperPivot, pointsLeft: true, restAngle: rest,
                                      length: MonTableLayout.upperFlipperLength,
                                      pivotRadius: MonTableLayout.upperFlipperPivotRadius,
                                      tipRadius: MonTableLayout.upperFlipperTipRadius,
                                      bands120: MonCoachBands.upper120, bands60: MonCoachBands.upper60)
        let c = FlipCoach(flippers: [lower(MonTableLayout.leftFlipperPivot, false, MonCoachBands.left120, MonCoachBands.left60),
                                     lower(MonTableLayout.rightFlipperPivot, true, MonCoachBands.right120, MonCoachBands.right60),
                                     upper],
                          ballRadius: MonTableLayout.ballRadius)
        c.isHidden = true
        addChild(c)
        coach = c
    }

    /// Shown while Improve is on in a real game (not on the menu, not for the lab robots).
    private func updateCoachVisibility() {
        guard let coach else { return }
        var show = settings.improveOn && !isAttractMode
        #if DEBUG
        if playLab != nil || shotLab != nil { show = false }
        #endif
        coach.isHidden = !show
    }

    /// 60 Hz or 120 Hz bands: switches only after 30 frames in a row on the other side of 1/90 s, so one
    /// hitch (or the clamped first frame after a pause) doesn't redraw every band and wipe a flash.
    private func coachRateIsSixty(_ dt: CGFloat) -> Bool {
        if (dt > 1.0 / 90) == coachSixty { coachRateStreak = 0; return coachSixty }
        coachRateStreak += 1
        if coachRateStreak >= 30 { coachSixty.toggle(); coachRateStreak = 0 }
        return coachSixty
    }

    /// The lit arrows (by lamp name), plus "lane" while a raindrop lane is still dark (the upper flipper's shot).
    private func litShots() -> Set<String> {
        var lit = Set(["orbit", "mesaRamp", "saguaros", "captive", "arroyo"].filter { name in
            switch lamps.state(of: "arrow." + name) {
            case .on?, .blink?, .fastBlink?: return true
            default: return false
            }
        })
        if lanesResetAt == nil, rollovers.contains(where: { !$0.isLit }) { lit.insert("lane") }
        return lit
    }

    /// A flipper went up: the coach flashes the band the ball was in (0 left, 1 right, 2 upper).
    private func coachFlip(_ index: Int) {
        guard let coach, !coach.isHidden else { return }
        coach.flipped(flipper: index, balls: balls.filter { $0.isOnFloor && $0.heldIn == nil }.map { $0.position })
    }

    /// Round 8: a nudge, from a flick of a flipper finger or the pad. Every free floor ball gets the kick; the rule in
    /// Nudge decides the warning and the tilt (the flippers are dead until the next ball is served).
    private func applyNudge(_ direction: Nudge.Direction) {
        guard !isAttractMode, !game.isGameOver else { return }
        let free = balls.filter { $0.isOnFloor && $0.heldIn == nil && $0.ride == nil && !isOnPlunger($0) }
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
        plunger?.position = MonTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    private func releasePlunger() {
        let maxPull = MonTableLayout.plungerMaxPull
        let power = plungerPull < 4 ? MonTableLayout.tapLaunchPower : plungerPull / maxPull
        if let body = plungerBall?.physicsBody {
            let speed = MonTableLayout.minLaunchSpeed
                + power * (MonTableLayout.maxLaunchSpeed - MonTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
        }
        plunger.run(.move(to: MonTableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    /// Game controller, every frame of play: shoulders/triggers flip, A held or the right stick pulled down works the
    /// plunger (released = launch, with the furthest pull reached). Touches keep working alongside.
    private func updateGamepad() {
        let pad = LabGamepad.shared.state
        if !pad.aDown { padAArmed = true }
        if let direction = pad.nudge { applyNudge(direction) }    // round 8
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
            plungerPull = pull * MonTableLayout.plungerMaxPull
            plunger.position.y = MonTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * MonTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = MonTableLayout.plungerRestPosition
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
        updateCoachVisibility()
        #if DEBUG
        if shotLab != nil {                        // Shot Lab: the robot's frame instead of a game frame
            MonLoop.allCases.forEach { sound.setLoop($0, target: 0) }
            sound.stepLoops(dt: Float(step))
            updateShotLab(CGFloat(step))
            return
        }
        #endif
        if isAttractMode {
            lamps.update(time: now)                // the attract chase runs on the menu
            return
        }

        let dt = CGFloat(step)
        lastStep = dt
        updateGamepad()
        if let coach, !coach.isHidden { coach.update(lit: litShots(), sixty: coachRateIsSixty(dt)) }
        #if DEBUG
        updatePlayLab(now)
        #endif
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        upperFlipper.step(dt: dt)
        updateRides(dt)
        updateToys(dt, now: now)
        slingshots.forEach { $0.settle() }
        updateGates()
        updateLanes(now)
        updateScoops(now)
        updateMonsoon(now)
        updateStandups(now)
        updateSpinner(dt, now: now)
        paint.step(dt: dt)
        updateStormBed(dt)
        updateStorm(dt, now: now)
        updatePartColors(dt)
        updateLampStates()
        lamps.update(time: now)

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // Launch = the frame the served ball leaves the plunger area.
        var onPlunger = false
        if let served = servedBall { onPlunger = isOnPlunger(served) }
        if wasOnPlunger && !onPlunger && servedBall != nil {
            ballLaunched = true
            launchedAt = now
            sfx(.launch)
        }
        updateKickback()
        updateBonus(now)
        if let t = launchedAt, skillLane != nil, now - t > MonTableLayout.skillShotWindow {
            setSkillLane(nil)
        }
        wasOnPlunger = onPlunger

        // Drain: remove every ball off the bottom; a ball is lost only when none are left.
        let drained = balls.filter { $0.position.y < -MonTableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            if !nudge.tilted, monsoonOn || superbloomOn, now < multiballSaveUntil {   // round 8b′: a tilt ends the saves
                // Monsoon's ball save: each lost ball comes back up out of the arroyo.
                if pendingReleases == 0 { nextReleaseAt = now + 0.5 }
                pendingReleases += drained.count
                showBanner("BALL SAVED"); sfx(.ballSave)
            }
            let rightOutlane = drained.contains { $0.inRightOutlane }
            if balls.isEmpty, nextBallAt == nil, pendingReleases == 0, bonusStart == nil {
                setSkillLane(nil)
                if ballSaveNow, !nudge.tilted {
                    // The ball save: once per player ball, on the plunger and for 10 s after launch.
                    ballSaveUsed = true
                    game.ballSaved()
                    showBanner("BALL SAVED"); sfx(.ballSave)
                    rampHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else if outlaneSaveLit, rightOutlane, !nudge.tilted {
                    // Outlane save: used up; the ball comes back, nothing lost.
                    outlaneSaveLit = false
                    game.ballSaved()
                    showBanner("OUTLANE SAVE"); sfx(.ballSave)
                    rampHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else {
                    ballSaveUsed = false             // the next ball gets its own save
                    cameraRig.shake(strength: 4, duration: 0.3)
                    sfx(.drain)
                    dimTable()
                    startBonus(at: now)              // the ball is lost once the bonus has counted
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

    override func didSimulatePhysics() {
        for ball in balls {
            updateRampLayer(ball)
            guard let body = ball.physicsBody else { continue }
            // The flip assist (Lamplight's T5 M8 v12): a flip gives a floor ball its full speed at 60 Hz too.
            if ball.isOnFloor, ball.ride == nil, ball.heldIn == nil {
                let r = MonTableLayout.ballRadius
                leftFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
                rightFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
                upperFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
            }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            let maxSpeed = ball.layer == .rampDown ? MonTableLayout.rampReturnMaxSpeed : MonTableLayout.maxBallSpeed
            if speed > maxSpeed {
                let scale = maxSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            if let ride = ball.ride, let helix = helixRamp {
                ball.rampHeight = helix.heightAlong(ride.s)    // the helix overlaps itself: use the ride's own distance
            } else {
                ball.rampHeight = ball.layer == .floor ? 0 : (ball.activeRamp?.height(at: ball.position) ?? 0)
            }
            ball.updateLook()
        }
    }

    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: lastStep)
        dimmer.size = size
        placeBuildTag()
    }

    // MARK: - Debug (look development)

    /// A wash from a random spot on the lower playfield.
    func debugWash() {
        let p = CGPoint(x: CGFloat.random(in: 70...500), y: CGFloat.random(in: 230...500))
        let style = paint.addWash(at: p, region: .desert, amount: 0.15)
        showBanner("WASH · \(style.rawValue.uppercased())")   // M8 v1: which of the random styles it picked
    }

    /// The whole lower table in color.
    func debugFill() {
        paint.fill(.desert, to: 1)
        paint.fill(.frame, to: 1)
    }

    /// Back to the sketch.
    func debugSketch() { paint.reset() }

    private var isLabRunning: Bool {
        #if DEBUG
        return shotLab != nil
        #else
        return false
        #endif
    }

    /// Paints everything and blooms the wildflowers, so Superbloom lights (debug builds' pause card).
    func debugLightSuperbloom() {
        guard !monsoonOn, !superbloomOn else { return }
        for region in MonRegion.allCases.prefix(5) {
            paintedRegions.insert(region)
            regionUnits[region.rawValue] = Self.regionNeed[region] ?? 4
            paint.fill(region, to: 1)
        }
        wildflowers = MonTableLayout.wildflowersNeeded
        newCycleAt = nil
        monsoonLit = false
        checkSuperbloomLit()
    }

    /// Lights Monsoon at the arroyo straight away (debug builds' pause card).
    func debugLightMonsoon() {
        guard !monsoonOn else { return }
        monsoonLit = true
        showBanner("MONSOON IS LIT · SHOOT THE ARROYO")
    }

    /// Flips the diverter (until the rules throw it).
    func debugToggleDiverter() { setDiverter(toHelix: !diverterToHelix) }

    /// Makes the dust devil rage (strong push, fast spin) or calm down (until the rules light it).
    func debugToggleDustDevil() { dustDevil?.isRaging.toggle() }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        if a.categoryBitMask == MonPhysicsCategory.ball {
            ballBody = a; other = b
        } else if b.categoryBitMask == MonPhysicsCategory.ball {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? MonBall, ballNode.isOnFloor,
              let node = other.node else { return }

        switch other.categoryBitMask {
        case MonPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? MonSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                game.add(MonPoints.slingshot)
                shotEvent("sling")
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case MonPhysicsCategory.bumper:
            if let bumper = node as? MonBumper,
               bumper.hit(ball: ballBody, ballPosition: ballNode.position, at: gameTime) {
                award(MonPoints.bumper)
                shotEvent("bumper")
                bumperHits += 1
                if bumperHits % 10 == 0 { paintWash(.desert, units: 1, at: bumper.position) }
                paintWash(.sky, units: MonTableLayout.bumperSkyUnits, at: bumper.position, touch: true)  // M11 v2: storm clouds
                hitHaptic.impactOccurred()
                let mid = CGPoint(x: (ballNode.position.x + bumper.position.x) / 2,
                                  y: (ballNode.position.y + bumper.position.y) / 2)
                Effects.burst(in: self, at: mid, color: Self.wallColor, count: 12, speed: 200, lifetime: 0.3)
                bumperLightning(bumper, ball: ballNode.position)
                cameraRig.shake(strength: 2, duration: 0.15)
                sfx(.bumper)
            }
        case MonPhysicsCategory.rollover:
            if let lane = node as? MonRollover { rollOver(lane, at: gameTime) }
        case MonPhysicsCategory.toy:
            // The player's ball knocked the captive ball (a light thud; the score is for reaching the top).
            if node.parent is MonCaptiveBall, gameTime - captiveKnockAt > 0.1 {
                captiveKnockAt = gameTime
                award(MonPoints.captiveKnock)
                shotEvent("captive")
                hitHaptic.impactOccurred(intensity: 0.6)
                sfx(.captiveKnock)
            }
        case MonPhysicsCategory.target:
            if let target = node as? MonStandup, target.hit(at: gameTime) { hitStandup(target, at: gameTime) }
        default:
            break
        }
    }
}

// MARK: - Shot Lab (milestone 6, debug builds)

extension MonTableScene {
    /// A shot event for the Shot Lab; does nothing in normal play.
    fileprivate func shotEvent(_ name: String) {
        if Self.bonusShots.contains(name) { shotsThisBall += 1 }
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        playLab?.shot(name, now: gameTime)
        #endif
    }

    #if DEBUG
    /// Starts the robot: it takes over the flippers and sweeps flip timings from a cradled ball on the left, right
    /// and upper flippers, at 120 Hz and 60 Hz physics steps (~25 min in the Simulator). `devilRaging` keeps the dust
    /// devil raging for the whole run, to check it doesn't throw balls down the middle. Menu or a new game stops it.
    func debugStartShotLab(devilRaging: Bool) {
        isAttractMode = false
        shotLabTime = 0
        shotLabDevilRaging = devilRaging
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// The robot's frame: only what the physics and shot detection need (no serving, drains or banners).
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
        upperFlipper.step(dt: dt)
        updateRides(dt)
        updateToys(dt, now: now)
        slingshots.forEach { $0.settle() }
        updateGates()
        updateLanes(now)
        updateScoops(now)
        updateStandups(now)
        updateSpinner(dt, now: now)
        if lab.update(now: now) {
            game.banner = lab.progressText
        } else {
            let saved = lab.save(now: now)
            shotLab = nil
            physicsWorld.speed = 1
            shotLabResetTable()
            game.banner = "SHOT LAB DONE · \(lab.trials.count) TRIALS · \(saved)"
        }
    }
    #endif
}

#if DEBUG
extension MonTableScene: ShotLabHost {
    var shotLabTableName: String { shotLabDevilRaging ? "Monsoon (dust devil raging)" : "Monsoon" }

    /// The shots a player aims for end a trial; bumpers, slings, the spinner, the captive knock and the dust devil
    /// are noted only (so a trial that crosses the dust devil and then drains shows up as one that drained).
    var shotLabMajorEvents: Set<String> {
        ["mesaRamp", "helix", "orbit", "arroyo", "standup", "lane", "captiveTop"]
    }

    /// Left, right and upper flippers, cradled as on Table 03: 40 pt out and 14 above the raised main flippers,
    /// 32 out and 17 above the upper one (which points left).
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = MonTableLayout.flipperTravel - MonTableLayout.flipperRestAngle      // 30° above horizontal
        let along: CGFloat = 40, above: CGFloat = 14
        let l = MonTableLayout.leftFlipperPivot
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: MonTableLayout.mirrorSum - left.x, y: left.y)
        let u = MonTableLayout.upperFlipperPivot
        let arm = CGFloat.pi - up
        let ua: CGFloat = 32, uh: CGFloat = 17
        let upper = CGPoint(x: u.x + ua * cos(arm) + uh * sin(arm), y: u.y + ua * sin(arm) - uh * cos(arm))
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left),
                ShotLab.FlipperSpec(name: "right", pivot: MonTableLayout.rightFlipperPivot, cradle: right),
                ShotLab.FlipperSpec(name: "upper", pivot: u, cradle: upper)]
    }

    /// Each flipper on its own (in play the upper one shares the right button; the robot aims one at a time).
    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        switch index {
        case 0: leftFlipper.isPressed = pressed
        case 1: rightFlipper.isPressed = pressed
        default: upperFlipper.isPressed = pressed
        }
    }

    func shotLabPlaceBall(at point: CGPoint) {
        let ball = MonBall(at: point)
        addChild(ball)
        balls.append(ball)
    }

    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        standupsResetAt = nil
        standups.forEach { $0.isLit = false }
        setDiverter(toHelix: false)
        captive?.reset()
        dustDevil?.isRaging = shotLabDevilRaging
    }

    /// Where shots cross the bottom edge of the dust devil and just below the arroyo's catch.
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "dustDevil", y: MonTableLayout.dustDevilCenter.y - MonTableLayout.dustDevilRadius),
         ShotLab.Probe(name: "arroyo", y: MonTableLayout.arroyoCenter.y - 30)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }
}
#endif

extension MonTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}

#if DEBUG
extension MonTableScene: PlayLabHost {
    var playLabTableName: String { "Monsoon" }
    var playLabBallRadius: CGFloat { MonTableLayout.ballRadius }
    var playLabVariantCount: Int { 1 }

    /// The three acts as the How to Play tells them, plus the saves and the side goals.
    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "skyPainted", text: "Paint the sky (the orbit, the raindrop lanes, bumper touches)"),
         PlayObjective(name: "mesasPainted", text: "Paint the mesas (the mesa ramp and the helix)"),
         PlayObjective(name: "saguarosPainted", text: "Paint the saguaros (the standups and the captive ball)"),
         PlayObjective(name: "arroyoPainted", text: "Paint the arroyo (the arroyo hole, wire rides)"),
         PlayObjective(name: "desertPainted", text: "Paint the desert (every 10th bumper hit, the dust devil)"),
         PlayObjective(name: "monsoonLit", text: "Three regions painted: Monsoon lights at the arroyo"),
         PlayObjective(name: "monsoon", text: "Start Monsoon (2-ball multiball)"),
         PlayObjective(name: "wildflower", text: "A Monsoon jackpot blooms wildflowers (helix ride or mesa ramp)"),
         PlayObjective(name: "superbloomLit", text: "All five regions painted and four wildflowers: Superbloom lights"),
         PlayObjective(name: "superbloom", text: "Start Superbloom (3-ball multiball)"),
         PlayObjective(name: "bloom", text: "A Superbloom shot blooms (15,000)"),
         PlayObjective(name: "superJackpot", text: "Superbloom's super jackpot (the helix, 75,000)"),
         PlayObjective(name: "paintingFinished", text: "The painting is finished (Superbloom down to one ball)"),
         PlayObjective(name: "newSketch", text: "A new sketch: the next cycle, awards multiplied"),
         PlayObjective(name: "lanesComplete", text: "Finish the three raindrop lanes (+1X)"),
         PlayObjective(name: "multiplier", text: "Reach 2X or more"),
         PlayObjective(name: "helix", text: "Ride the helix (mesa ramp with the diverter set)"),
         PlayObjective(name: "captiveTop", text: "Knock the captive ball to the top of its channel"),
         PlayObjective(name: "kickback", text: "Light the kickback (the three saguaro standups)"),
         PlayObjective(name: "outlaneSave", text: "Use the outlane save (lit by painting a region)"),
         PlayObjective(name: "skillShot", text: "Plunge through the ringed raindrop lane")]
    }

    /// Flip delays = the middle of each shot's window in the Shot Lab. T4 M11 v6: the flip assist is 60 Hz only, so the
    /// 120 Hz lower-flipper delays are back to the pre-assist lists (Shot Lab 2026-10-16 00-02, after rounds 4h′/4h″:
    /// Play Lab run 4) and the 60 Hz ones stay from the post-assist run of 2026-10-21 21-32 (dust devil at rest — its
    /// raging windows differ by ~40 ms, see the 10-15 22-38 run). T4 M11 v7: the upper flipper's 120 Hz lane is 0.450,
    /// from the pre-assist run of 2026-10-16 00-02 (lane 0.445–0.465, 6 trials; the 10-15 21-55 run has lanes at
    /// 0.385–0.447); 21-32's 0.317 was measured with the assist and went 1/43 once it was 60 Hz only. The notes below describe the 21-32 run. The assist moved
    /// the arroyo to a later, wider window (left 0.353–0.416, 17 trials) and gave the right flipper a real arroyo
    /// window (0.330–0.423, 24 trials); captiveTop shrank to a 2-trial band (0.509–0.516), so it's gone at both rates. The helix is the mesa ramp with the diverter set,
    /// so the robot aims "mesaRamp" either way (the ride takes longer than the aim window; the HELIX banner records it).
    /// Runs 1–2: the right flipper's arroyo (a 2-trial band, 0/8) and the upper flipper's shots (1–3 trial bands,
    /// 2/22) aren't real windows, so they're gone; the upper flipper isn't modelled, as on Grey Invasion.
    var playLabFlippers: [PlayRobotFlipper] {
        let specs = shotLabFlippers
        let rest = MonTableLayout.flipperRestAngle
        return [PlayRobotFlipper(name: "left", pivot: specs[0].pivot, length: MonTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: false, cradle: specs[0].cradle, rightButton: false, upper: false,
                                 shots: [("arroyo", 0.312), ("mesaRamp", 0.450), ("standup", 0.522)],
                                 shots60: [("arroyo", 0.407), ("mesaRamp", 0.432), ("standup", 0.501)]),
                PlayRobotFlipper(name: "right", pivot: specs[1].pivot, length: MonTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: specs[1].cradle, rightButton: true, upper: false,
                                 shots: [("orbit", 0.492), ("captiveTop", 0.517)],
                                 shots60: [("arroyo", 0.373), ("orbit", 0.467)]),
                // Round 6a (Aaron: the robot never used the upper flipper): back in, with the post-assist Shot Lab
                // (21-32): from its cradle the one solid window is the raindrop LANES (0.302–0.331 at 120 Hz,
                // 0.370–0.427 at 60 Hz). Its arroyo/standup bands are 3–5 trials and went 0/38 in run 8 (6b: gone), so
                // the lanes are its only shot. Listed, it also makes reactive flips and catches.
                PlayRobotFlipper(name: "upper", pivot: specs[2].pivot, length: MonTableLayout.upperFlipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: specs[2].cradle, rightButton: true, upper: false,
                                 shots: [("lane", 0.450)],
                                 shots60: [("lane", 0.398)])]
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
            pendingReleases = 0
            bonusStart = nil
            game.bonusText = nil
        }
        return ["painted": paintedRegions.count, "wildflowers": wildflowers, "cycle": cycle]
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
                               isHeld: b.heldIn != nil, onPlunger: isOnPlunger(b),
                               id: ObjectIdentifier(b).hashValue)
        }, wanted: robotWanted(), lanes: lanesResetAt == nil && !rollovers.isEmpty
            ? PlayRobotView.Lanes(xs: rollovers.map { $0.position.x }, y: rollovers[0].position.y, lit: rollovers.map { $0.isLit })
            : nil,
           // Round 7b: the plunge sweep of 2026-10-24 (both rates): lane 2 at 0.63, lane 1 at 0.65, lane 0 unreachable.
           skillPlunge: skillLane.flatMap { [1: 0.65, 2: 0.63][$0] })
        guard let cmd = lab.frame(view) else { return }
        if let direction = cmd.nudge { applyNudge(direction) }       // round 8b: the robot nudges
        if cmd.left != robotLeft || cmd.right != robotRight {
            robotLeft = cmd.left
            robotRight = cmd.right
            updateFlippers()
        }
        if let power = cmd.plunge, isBallOnPlunger {
            plungerPull = power * MonTableLayout.plungerMaxPull
            releasePlunger()
        }
    }

    /// The shots the table wants, most wanted first: what the arrows say (fast-blink before blink), then the shots
    /// worth taking anyway. (The mesa ramp arrow fast-blinks in Monsoon: that flip is the helix jackpot.)
    private func robotWanted() -> [String] {
        let arrows: [(lamp: String, shot: String)] = [("orbit", "orbit"), ("mesaRamp", "mesaRamp"),
                                                      ("saguaros", "standup"), ("captive", "captiveTop"),
                                                      ("arroyo", "arroyo")]
        var w: [String] = []
        w += arrows.filter { lamps.state(of: "arrow." + $0.lamp) == .fastBlink }.map { $0.shot }
        w += arrows.filter { lamps.state(of: "arrow." + $0.lamp) == .blink }.map { $0.shot }
        w += arrows.map { $0.shot }
        // The raindrop lanes (the upper flipper's shot) while a lane is still dark: +1X and a quarter of the sky each.
        if lanesResetAt == nil, rollovers.contains(where: { !$0.isLit }) { w.append("lane") }
        return w
    }

    /// Banners double as the objective record: the first of each per game is what the report shows.
    fileprivate func labObjective(forBanner text: String) {
        guard let lab = playLab else { return }
        let name: String?
        switch text {
        case "SKY PAINTED": name = "skyPainted"
        case "MESAS PAINTED": name = "mesasPainted"
        case "SAGUAROS PAINTED": name = "saguarosPainted"
        case "ARROYO PAINTED": name = "arroyoPainted"
        case "DESERT PAINTED": name = "desertPainted"
        case "MONSOON IS LIT · SHOOT THE ARROYO": name = "monsoonLit"
        case "MONSOON!": name = "monsoon"
        case "SUPERBLOOM IS LIT · SHOOT THE ARROYO": name = "superbloomLit"
        case "SUPERBLOOM!": name = "superbloom"
        case "THE PAINTING IS FINISHED": name = "paintingFinished"
        case "LANES COMPLETE": name = "lanesComplete"
        case "KICKBACK": name = "kickback"
        case "OUTLANE SAVE": name = "outlaneSave"
        case "SKILL SHOT": name = "skillShot"
        case "CAPTIVE BALL": name = "captiveTop"
        case "HELIX": name = "helix"
        default:
            if text.contains("JACKPOT · WILDFLOWERS") { name = "wildflower" }
            else if text.hasPrefix("SUPER JACKPOT") { name = "superJackpot" }
            else if text.hasPrefix("BLOOM ") { name = "bloom" }
            else if text.hasPrefix("A NEW SKETCH") { name = "newSketch" }
            else if text.hasSuffix("X"), Int(text.dropLast()) != nil { name = "multiplier" }
            else { name = nil }
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
        lab.endGame(score: game.score, ballsPlayed: MonGameState.ballsPerGame - game.ballsLeft + (over ? 0 : 1),
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
        robotLeft = false
        robotRight = false
        if leftFlipper != nil { updateFlippers() }
        physicsWorld.speed = isAttractMode ? 0 : 1
    }
}
#endif
