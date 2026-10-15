// Pinball Lab Table 03 (Cthulhu Rising): the table scene. Milestone 1 = grey box: Grey Invasion's proven
// lower table (outer wall with both bulges, apron and centre drain, lane guides, outlane walls, slingshots
// with dead posts), the flippers, plunger and one-way launch gate, the three camera modes, 3 balls.
// Milestone 2: the lower table is a baked Blender render. Milestone 3: the grey-box top of the table (orbit,
// Candle lanes, pop bumpers, diverter, right ramp, Library and Lagoon holes, Sigil bank, upper flipper),
// mostly Grey Invasion's proven top. Built from TableScene.swift's code, trimmed.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class CthTableScene: SKScene {
    private enum Control { case left, right, plunger }

    private let game: CthGameState
    private let settings: GameSettings
    private let cameraRig = CthCameraRig()
    private let sound = CthSoundPlayer()         // Table 03's own sounds (juice round 1)
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
    #if DEBUG
    /// Shot Lab robot (milestone 5, debug builds): measures shot timing windows with the real physics.
    private var shotLab: ShotLab?
    /// The lab's own clock: table time, at the pass's physics speed.
    private var shotLabTime: TimeInterval = 0
    /// This run keeps Cthulhu up and swaying (the Lagoon is then a moving target, not a hole).
    private var shotLabCthulhuUp = false
    /// The slingshot test (milestone 5 round 2): throws the same balls at each sling design.
    private var slingLab: CthSlingLab?
    private var slingLabTime: TimeInterval = 0
    #endif
    private var lastStep: CGFloat = 0

    private var balls: [CthBall] = []
    private var servedBall: CthBall?
    private var slingshots: [CthSlingshot] = []
    private var leftFlipper: CthFlipper!
    private var rightFlipper: CthFlipper!
    private var plunger: SKShapeNode!
    /// T3 M8 v3: the launch gate's flap (drawn; its physics is the per-ball one-way launchGate edge).
    private var launchGateFlap: SKNode?
    private var launchGateClosedAngle: CGFloat = 0
    private var isBuilt = false
    /// Milestone 2: the lower table is a baked Blender render (cth_lower.png); false if it's missing.
    private var hasLowerArt = false
    /// Milestone 8: the upper table is baked too (cth_upper.png); then the top walls hide under it.
    private var hasUpperArt = false
    private let hitHaptic = Haptic(style: .medium)
    private let rampHaptic = Haptic(style: .medium)

    // Top of the table (milestone 3)
    private var upperFlipper: CthFlipper!
    private var ramps: [CthRamp] = []
    private var scoops: [CthScoop] = []
    private var libraryScoop: CthScoop?
    private var lagoonScoop: CthScoop?
    private var bumpers: [CthBumper] = []
    private var rollovers: [CthRollover] = []
    private var lanesResetAt: TimeInterval?
    private var orbitDiverter: SKShapeNode?
    /// T3 M8 v2: the one-way gate's flap (drawn; it swings open when a plunge goes through).
    private var topGateFlap: SKNode?
    private var topGateClosedAngle: CGFloat = 0
    private var dropTargets: [CthDropTarget] = []
    private var pendingDrops: [CthDropTarget] = []
    private var bankResetAt: TimeInterval?

    // The toys (milestone 4)
    private var spinner: CthSpinner?
    private var libraryWire: CthRamp?            // the up-kicker's wire (round 2)
    private var magnet: CthMagnet?               // round 3
    private var magnetBall: CthBall?
    private var magnetReleaseAt: TimeInterval = 0
    private var magnetArmAt: TimeInterval = 0
    private var cthulhu: CthCthulhu?             // round 4

    // Lights (milestone 6)
    private let lamps = CthLampController()
    /// General illumination (M6 v2): a black sprite on the camera that dips the whole table on a drain.
    private let dimmer = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
    /// The Ritual multiball (M7 v3): balls still to fire up out of the Library, when, and the ball save.
    private var multiballOn = false
    private var pendingReleases = 0
    private var nextReleaseAt: TimeInterval = 0
    private var multiballSaveUntil: TimeInterval = 0
    /// The acts (M7 v2: Research). The scene reports shots; the campaign returns events.
    private let campaign = CthCampaign()

    // Carried-over rules (milestone 7 round 1)
    private var launchedAt: TimeInterval?        // when the served ball left the plunger
    private var elderSignUsed = false            // the ball save is used up for this player ball
    private var kickbackLit = false              // lit by a full Sigil bank, one save
    private var outlaneSaveLit = false           // lit by finishing a tome (round 2), one save
    private var skillLane: Int?                  // the Candle lane with the skill-shot ring
    private var shotsThisBall = 0                // for the bonus
    private var spinsThisBall = 0
    private var bonusStart: TimeInterval?        // the bonus is counting; the next ball waits for it
    private var bonusBase = 0
    private var bonusMultiplier = 1
    private var lastSpinTickAt: TimeInterval = 0

    // Input
    private var activeTouches: [UITouch: Control] = [:]
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
            if isAttractMode { shotLab = nil; stopSlingLab() }   // Menu stops the Shot Lab and the Sling Lab
            #endif
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode { releaseAllControls(); sound.stopLoop() }
            if isAttractMode { lamps.play(.attract, at: gameTime) } else { lamps.stopShow() }
            refreshCamera()
        }
    }

    var isGamePaused = false {
        didSet {
            if isGamePaused { releaseAllControls() } else { padAArmed = false }
            sound.holdLoop(isGamePaused)                 // the Awakening drone pauses with the game
            isPaused = isGamePaused
            lastRealTime = nil
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    // Grey-box colour: sea-green walls on near-black.
    static let wallColor = SKColor(red: 0.30, green: 0.85, blue: 0.75, alpha: 1)

    init(game: CthGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: CthTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.03, green: 0.05, blue: 0.06, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: CthTableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        dimmer.alpha = 0
        dimmer.zPosition = 40                      // over the table, under the debug tag
        cameraRig.node.addChild(dimmer)
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
        if shotLab != nil || slingLab != nil { return .topDown }
        #endif
        if isAttractMode { return .topDown }
        return multiballOn && settings.multiballFullTable ? .topDown : settings.cameraMode
    }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        dimmer.size = size
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addFloor()
        addLowerArt()
        addUpperArt()
        addWall(points: CthTableLayout.outerWall,
                friction: CthTableLayout.railFriction, restitution: CthTableLayout.railRestitution)
        addWall(points: CthTableLayout.leftLaneGuide)
        addWall(points: CthTableLayout.leftOutlaneWall)
        addWall(points: CthTableLayout.rightOutlaneWall)
        addWall(points: CthTableLayout.rightApron)
        addWall(points: CthTableLayout.rightLaneGuide)

        buildSlings([CthTableLayout.leftSling, CthTableLayout.rightSling], artBaked: hasLowerArt)
        hitHaptic.prepare()

        leftFlipper = CthFlipper(side: .left, pivot: CthTableLayout.leftFlipperPivot)
        rightFlipper = CthFlipper(side: .right, pivot: CthTableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)
        upperFlipper = CthFlipper(side: .right, pivot: CthTableLayout.upperFlipperPivot,
                                  length: CthTableLayout.upperFlipperLength,
                                  pivotRadius: CthTableLayout.upperFlipperPivotRadius,
                                  tipRadius: CthTableLayout.upperFlipperTipRadius)
        upperFlipper.attach(to: self)
        addWall(points: CthTableLayout.upperFlipperGuide, z: 0)

        addPlunger()
        addGate()
        addTopOfTable()
        addLamps()
    }

    /// A dark playfield inside the outer wall, so the table reads against the background.
    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: CthTableLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = SKColor(red: 0.06, green: 0.10, blue: 0.11, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
    }

    /// Milestone 2 (look development): the lower table rendered in Blender (tools/cth_render_lower.py):
    /// printed playfield, apron, cabinet, rails, wire lane guides, posts, slingshot rubbers and plastics,
    /// lit from the top left and seen at the 22° oblique angle, with the floor matching the physics exactly.
    /// It sits over the grey-box floor and wall lines (z -19), which still show on the unbuilt top half.
    private func addLowerArt() {
        guard UIImage(named: "cth_lower") != nil else { return }
        let rect = CthTableLayout.lowerArtRect
        let art = SKSpriteNode(imageNamed: "cth_lower")
        art.size = rect.size
        art.position = CGPoint(x: rect.midX, y: rect.midY)
        art.zPosition = -19
        addChild(art)
        hasLowerArt = true
    }

    private func addUpperArt() {
        guard UIImage(named: "cth_upper") != nil else { return }
        let rect = CthTableLayout.upperArtRect
        let art = SKSpriteNode(imageNamed: "cth_upper")
        art.size = rect.size
        art.position = CGPoint(x: rect.midX, y: rect.midY)
        art.zPosition = -19
        addChild(art)
        hasUpperArt = true
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = CthTableLayout.wallFriction,
                         restitution: CGFloat = CthTableLayout.wallRestitution,
                         z: CGFloat = -19.5, overArt: Bool = false) {
        let path = CGMutablePath()
        path.addLines(between: points)

        let node = SKShapeNode(path: path)
        node.strokeColor = Self.wallColor
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        // -19.5: under the baked table art, over the grey-box floor. M8: with the upper art baked, the top
        // walls (z 0 in the grey box) hide under it too.
        // overArt: a part that isn't in the baked art yet stays visible (z as given).
        node.zPosition = hasUpperArt && !overArt ? min(z, -19.5) : z
        if overArt {
            node.strokeColor = SKColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1)   // steel, until it's rendered
            node.lineWidth = 4
        }

        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = CthPhysicsCategory.wall
        body.collisionBitMask = CthPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
    }

    private func addPlunger() {
        let size = CthTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = CthTableLayout.plungerRestPosition
        // Milestone 2: the rendered plunger (chrome rod, black rubber tip). Its image spans x -14…14,
        // y -27…35 points around the plunger's centre (the extra height is the tip's lean).
        if UIImage(named: "cth_plunger") != nil {
            node.fillColor = .clear
            let sprite = SKSpriteNode(imageNamed: "cth_plunger")
            sprite.size = CGSize(width: 28, height: 62)
            sprite.position = CGPoint(x: 0, y: 4)
            node.addChild(sprite)
        }

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = CthPhysicsCategory.wall
        body.collisionBitMask = CthPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    // MARK: - Lights (milestone 6)

    /// Lamp inserts: shot arrows, the three tomes, the five ritual candles, Cthulhu's three hits, and lamps
    /// over the inserts painted into the lower art (inlane and flipper arrows, kickback, save, Elder Sign).
    private func addLamps() {
        let seaGreen = SKColor(red: 0.30, green: 0.92, blue: 0.80, alpha: 1)
        let parchment = SKColor(red: 0.98, green: 0.80, blue: 0.40, alpha: 1)
        let flame = SKColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 1)
        let eldritch = SKColor(red: 0.72, green: 0.42, blue: 1.0, alpha: 1)
        let brass = SKColor(red: 0.91, green: 0.76, blue: 0.35, alpha: 1)

        let upperPainted = hasUpperArt                 // M8: these inserts are painted into the art
        func add(_ lamp: CthLamp, _ name: String) {
            addChild(lamp)
            lamps.add(lamp, named: name)
        }
        for (name, spot) in CthTableLayout.shotArrows {
            add(CthLamp(.arrow(length: 24, width: 18), color: seaGreen, at: spot.0, angle: spot.1, painted: upperPainted), "arrow.\(name)")
        }
        for (i, p) in CthTableLayout.tomeLamps.enumerated() {
            add(CthLamp(.round(radius: CthTableLayout.tomeLampRadius), color: parchment, at: p, painted: upperPainted), "tome.\(i)")
        }
        for (i, p) in CthTableLayout.candleLamps.enumerated() {
            add(CthLamp(.round(radius: CthTableLayout.candleLampRadius), color: flame, at: p, painted: upperPainted), "candle.\(i)")
        }
        for (i, p) in CthTableLayout.cthulhuLamps.enumerated() {
            add(CthLamp(.round(radius: CthTableLayout.cthulhuLampRadius), color: eldritch, at: p, painted: upperPainted), "cthulhu.\(i)")
        }
        let tentacleGreen = SKColor(red: 0.40, green: 0.95, blue: 0.45, alpha: 1)
        for (i, p) in CthTableLayout.tentacleLamps.enumerated() {
            add(CthLamp(.round(radius: CthTableLayout.tentacleLampRadius), color: tentacleGreen, at: p, painted: upperPainted), "tentacle.\(i)")
        }

        // Over the painted inserts (left side; the right side mirrors). Only the light is drawn.
        let painted = hasLowerArt
        let inlane = CthTableLayout.inlaneArrowLeft, flipperArrow = CthTableLayout.flipperArrowLeft
        add(CthLamp(.arrow(length: 26, width: 16), color: brass, at: inlane, angle: .pi / 2, painted: painted),
            "inlane.left")
        add(CthLamp(.arrow(length: 26, width: 16), color: brass, at: CthTableLayout.mirrored(inlane),
                    angle: .pi / 2, painted: painted), "inlane.right")
        add(CthLamp(.arrow(length: 18, width: 11), color: brass, at: flipperArrow,
                    angle: -36 * .pi / 180, painted: painted), "flipperArrow.left")
        add(CthLamp(.arrow(length: 18, width: 11), color: brass, at: CthTableLayout.mirrored(flipperArrow),
                    angle: -.pi + 36 * .pi / 180, painted: painted), "flipperArrow.right")
        add(CthLamp(.round(radius: 9), color: SKColor(red: 1.0, green: 0.54, blue: 0.24, alpha: 1),
                    at: CthTableLayout.kickbackLamp, painted: painted), "kickback")
        add(CthLamp(.round(radius: 9), color: SKColor(red: 0.28, green: 0.88, blue: 0.78, alpha: 1),
                    at: CthTableLayout.mirrored(CthTableLayout.kickbackLamp), painted: painted), "outlaneSave")
        add(CthLamp(.star(outer: 20, inner: 8.5), color: SKColor(red: 0.49, green: 0.94, blue: 0.66, alpha: 1),
                    at: CthTableLayout.elderSign, painted: painted), "elderSign")
    }

    // MARK: - Rules (milestone 7 round 1: carried over from Grey Invasion)

    /// Every award goes through here: it's multiplied (CthGameState.add), and scoring anything before the
    /// skill-shot lane cancels the skill shot (the spinner doesn't: a plunge can spin it on the way up).
    private func award(_ points: Int, cancelsSkillShot: Bool = true) {
        if cancelsSkillShot, skillLane != nil, ballLaunched { setSkillLane(nil) }
        game.add(points)
    }

    /// Whether a ball that drains now is saved by the Elder Sign: once per player ball, while the ball
    /// waits on the plunger and for the first seconds after launch.
    private var elderSignNow: Bool {
        guard !elderSignUsed else { return false }
        if let t = launchedAt { return gameTime - t <= CthTableLayout.elderSignSeconds }
        return true
    }

    /// Puts the skill-shot ring on one Candle lane (nil = none).
    private func setSkillLane(_ index: Int?) {
        skillLane = index
        for (i, lane) in rollovers.enumerated() {
            lane.isSkillTarget = (i == index)
        }
    }

    /// A lit kickback fires a ball draining down the left outlane straight back up it. One save, then a
    /// full Sigil bank must relight it.
    private func updateKickback() {
        guard kickbackLit else { return }
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody else { continue }
            let p = ball.position
            if p.x < CthTableLayout.kickbackMaxX, p.y < CthTableLayout.kickbackTriggerY, p.y > 0, body.velocity.dy < 0 {
                body.velocity = CGVector(dx: 0, dy: CthTableLayout.kickbackSpeed)
                kickbackLit = false
                rampHaptic.impactOccurred()
                CthEffects.burst(in: self, at: p, color: CthEffects.bone, count: 18, speed: 240, lifetime: 0.4)
                cameraRig.shake(strength: 3, duration: 0.25)
                sfx(.kickback)
                showBanner("KICKBACK")
                return
            }
        }
    }

    private func startBonus(at now: TimeInterval) {
        bonusBase = shotsThisBall * CthTableLayout.bonusPerShot + spinsThisBall * CthTableLayout.bonusPerSpin
        bonusMultiplier = game.multiplier
        bonusStart = now
    }

    /// Counts the bonus up in the LED strip, shows the multiplier, adds it, then loses the ball.
    private func updateBonus(_ now: TimeInterval) {
        guard let start = bonusStart else { return }
        let t = now - start
        let counting = settings.bonusCountOn         // off in Settings: added straight away
        let countTime = counting ? CthTableLayout.bonusCountSeconds : 0
        let holdTime = counting ? CthTableLayout.bonusHoldSeconds : 0
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
        if !game.isGameOver { nextBallAt = now + 0.5 }
    }

    // MARK: - The acts (milestone 7 round 2: Research)

    /// Turns campaign events into points, banners, lamp shows and sounds.
    private func handle(_ events: [CthCampaign.Event]) {
        #if DEBUG
        if shotLab != nil || slingLab != nil { return }   // the robots ignore the story
        #endif
        for event in events {
            switch event {
            case .clue(let n):
                showBanner("CLUE \(n) OF \(CthCampaign.cluesNeeded)")
                sfx(.clue)
            case .libraryLit:
                showBanner("LIBRARY LIT")
                sfx(.libraryLit)
            case .tomeStarted(let i):
                showBanner("TOME \(CthCampaign.roman[i]): \(CthCampaign.tomeNames[i])")
                lamps.play(.sweep, at: gameTime)
                cameraRig.shake(strength: 3, duration: 0.3)
                sfx(.tomeStarted)
            case .progress(let points, let banner):
                if points > 0 { award(points) }
                if let banner { showBanner(banner) }
                sfx(.page)
            case .tomeFinished(let i, let points):
                award(points)
                outlaneSaveLit = true                // a finished tome lights the outlane save
                let mystery = mysteryAward()
                showBanner("\(CthCampaign.tomeShortNames[i]) READ · \(mystery)")
                lamps.play(.flash, at: gameTime)
                cameraRig.shake(strength: 6, duration: 0.4)
                rampHaptic.impactOccurred()
                sfx(.tomeFinished)
            case .tomeFailed:
                showBanner("THE PAGES CLOSE · LIBRARY TO GO ON")
                sfx(.failed)
            case .ritualLit:
                showBanner("RITUAL LIT!")
                lamps.play(.sweep, at: gameTime)
                sfx(.ritualLit)
            case .ritualStarted:
                // The caught ball goes up the wire as usual; a second follows it out of the Library.
                multiballOn = true
                pendingReleases += 1
                nextReleaseAt = gameTime + CthTableLayout.ritualReleaseDelay
                multiballSaveUntil = gameTime + CthTableLayout.ritualBallSaveSeconds
                showBanner("THE RITUAL BEGINS")
                lamps.play(.sweep, at: gameTime)
                cameraRig.shake(strength: 6, duration: 0.5)
                rampHaptic.impactOccurred()
                sfx(.ritualStarted)
            case .candleLit(let i, let points):
                award(points)
                showBanner("CANDLE \(min(campaign.candles.count, 5)) OF 5")
                if i < CthTableLayout.candleLamps.count {
                    CthEffects.burst(in: self, at: CthTableLayout.candleLamps[i], color: CthEffects.candle,
                                     count: 16, speed: 160, lifetime: 0.5)
                    CthEffects.embers(in: self, at: CthTableLayout.candleLamps[i], count: 16)
                }
                sfx(.candle)
            case .summoning(let points):
                award(points)
                showBanner("THE SUMMONING! · \(points.formatted())")
                lamps.play(.flash, at: gameTime)
                cameraRig.shake(strength: 10, duration: 0.8)
                rampHaptic.impactOccurred()
                sfx(.summoning)
            case .ritualFaltered:
                showBanner("THE RITUAL FALTERS · RELIT")
                sfx(.failed)
            case .awakeningStarted:
                // Cthulhu rises; balls fire up out of the Library until three are in play.
                cthulhu?.regrowTentacles()
                cthulhu?.rise(at: gameTime)
                multiballOn = true
                let missing = CthTableLayout.awakeningBalls - balls.count - pendingReleases
                if missing > 0 {
                    if pendingReleases == 0 { nextReleaseAt = gameTime + CthTableLayout.ritualReleaseDelay }
                    pendingReleases += missing
                }
                multiballSaveUntil = gameTime + CthTableLayout.awakeningBallSaveSeconds
                magnetArmAt = gameTime + CthTableLayout.magnetFirstArm
                showBanner("THE AWAKENING! CTHULHU RISES")
                lamps.play(.sweep, at: gameTime)
                cameraRig.shake(strength: 8, duration: 1.0)
                rampHaptic.impactOccurred()
                sfx(.awakening)
            case .tentacleHit(let i, let cut, let points):
                award(points)
                if cut {
                    cthulhu?.setTentacle(i, cut: true)
                    if let c = cthulhu {
                        CthEffects.splash(in: self, at: c.tentacleBase(i), radius: 22, rings: 2, drops: 16)
                        CthEffects.burst(in: self, at: c.tentacleBase(i), color: CthEffects.eldritch, count: 14, speed: 180, lifetime: 0.4)
                    }
                    showBanner("TENTACLE CUT · \(campaign.tentaclesLeft) LEFT")
                    sfx(.tentacleCut)
                } else {
                    showBanner("TENTACLE HIT")
                    sfx(.tentacleHit)
                }
            case .eyeOpen:
                showBanner("THE EYE OPENS · STRIKE IT!")
                lamps.play(.sweep, at: gameTime)
                sfx(.eyeOpen)
            case .eyeStruck(let n, let points):
                award(points)
                showBanner("EYE STRUCK \(n) OF \(CthCampaign.eyeHitsNeeded)")
                if let c = cthulhu {
                    CthEffects.burst(in: self, at: CGPoint(x: c.position.x, y: c.position.y - 8), color: CthEffects.candle,
                                     count: 24, speed: 260, lifetime: 0.5)
                }
                lamps.play(.flash, at: gameTime)
                cameraRig.shake(strength: 8, duration: 0.4)
                rampHaptic.impactOccurred()
                sfx(.eyeStruck)
            case .banished(let points):
                award(points)
                cthulhu?.sink(at: gameTime)
                magnet?.setState(.off)
                showBanner("CTHULHU BANISHED! · CYCLE \(campaign.cycle)")
                if let c = cthulhu {
                    CthEffects.splash(in: self, at: c.position, radius: 70, rings: 5, drops: 50)
                    CthEffects.burst(in: self, at: c.position, color: CthEffects.bone, count: 40, speed: 320, lifetime: 0.8, size: 0.4)
                }
                lamps.play(.flash, at: gameTime)
                cameraRig.shake(strength: 12, duration: 1.0)
                rampHaptic.impactOccurred()
                sfx(.banished)
            case .cthulhuEscaped:
                cthulhu?.sink(at: gameTime)
                magnet?.setState(.off)
                showBanner("HE SINKS BACK · SUMMON HIM AT THE LIBRARY")
                sfx(.escaped)
            }
        }
    }

    /// Fires pending Ritual balls up out of the Library onto its wire (one at a time, 1 s apart, only while the
    /// hole is empty), and ends the multiball when one ball is left.
    private func updateMultiball(_ now: TimeInterval) {
        if pendingReleases > 0, now >= nextReleaseAt, let scoop = libraryScoop, !isHolding(scoop), let wire = libraryWire {
            let ball = CthBall(at: CthTableLayout.libraryCenter)
            addChild(ball)
            balls.append(ball)
            upKick(ball, onto: wire)
            pendingReleases -= 1
            nextReleaseAt = now + CthTableLayout.ritualReleaseDelay
        }
        if multiballOn, pendingReleases == 0, balls.count <= 1 {
            multiballOn = false
            handle(campaign.multiballEnded())
        }
    }

    /// A finished tome's mystery award: the kickback, +1 multiplier or 50,000 × cycle. Returns its name.
    private func mysteryAward() -> String {
        switch Int.random(in: 0..<3) {
        case 0 where !kickbackLit:
            kickbackLit = true
            return "KICKBACK LIT"
        case 1 where game.multiplier < CthGameState.maxMultiplier:
            game.raiseMultiplier()
            return "\(game.multiplier)X"
        default:
            let points = 50_000 * campaign.cycle
            award(points)
            return "\(points.formatted())"
        }
    }

    #if DEBUG
    /// Pause-card shortcuts (debug builds): skip ahead through the tomes, or light the Ritual.
    func debugSkipTome() { handle(campaign.debugSkip()) }
    func debugLightRitual() { handle(campaign.debugLightRitual()) }
    func debugAwaken() { handle(campaign.debugAwaken()) }
    #endif

    /// The lights dip for a moment (a lost ball): fade to half in 0.08 s, hold 0.35 s, back in 0.45 s.
    private func dimTable() {
        dimmer.removeAllActions()
        dimmer.run(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.08),
            .wait(forDuration: 0.35),
            .fadeAlpha(to: 0, duration: 0.45),
        ]))
    }

    /// Lamp states from the table's state, every frame. PLACEHOLDER until the rules milestone (7), which
    /// replaces it with the three acts: tomes = Library catches, candles = Candle-lane completions, Cthulhu
    /// lamps = hits while he's up. Lower-table lamps stay dark until kickback / ball save exist.
    private func updateLampStates() {
        // Tomes (M7 v2): read = on, open = fast blink, ready to open at the Library = blink.
        let running = campaign.runningTome
        for i in CthTableLayout.tomeLamps.indices {
            var state = CthLampState.off
            if i < campaign.tomesDone { state = .on }
            else if running == i { state = .fastBlink }
            else if i == campaign.tomesDone, campaign.phase == .libraryLit { state = .blink }
            lamps.set("tome.\(i)", state)
        }

        // Ritual candles (M7 v3): lit = on; during the Ritual the unlit ones blink.
        let ritualOn = campaign.phase == .ritual
        for (i, shot) in CthCampaign.ritualShots.enumerated() where i < CthTableLayout.candleLamps.count {
            lamps.set("candle.\(i)", campaign.candles.contains(shot) ? .on : (ritualOn ? .blink : .off))
        }

        // Carried-over rules (round 1)
        lamps.set("kickback", kickbackLit ? .on : .off)
        lamps.set("outlaneSave", outlaneSaveLit ? .on : .off)
        var elder = CthLampState.off
        if !elderSignUsed {
            if let t = launchedAt {
                let left = CthTableLayout.elderSignSeconds - (gameTime - t)
                if left > CthTableLayout.elderSignWarning { elder = .on } else if left > 0 { elder = .fastBlink }
            } else if servedBall != nil {
                elder = .on                                  // waiting on the plunger
            }
        }
        lamps.set("elderSign", elder)

        // The Awakening (M7 v4): eye lamps = eye hits (kept if he escapes), the next one blinks once the
        // tentacles are cut; tentacle lamps = 2 hits left on, 1 left blink, cut off.
        let awakening = campaign.phase == .awakening
        let eyeOpen = awakening && campaign.tentaclesLeft == 0
        for i in CthTableLayout.cthulhuLamps.indices {
            var state = CthLampState.off
            if i < campaign.eyeHits { state = .on } else if eyeOpen, i == campaign.eyeHits { state = .fastBlink }
            lamps.set("cthulhu.\(i)", state)
        }
        for (i, left) in campaign.tentacles.enumerated() where i < CthTableLayout.tentacleLamps.count {
            lamps.set("tentacle.\(i)", !awakening || left == 0 ? .off : (left >= CthCampaign.tentacleHits ? .on : .blink))
        }
        lamps.set("arrow.lagoon", eyeOpen ? .fastBlink : (awakening ? .blink : .off))

        // Sigil arrow: blinks while the kickback is out (a full bank relights it).
        lamps.set("arrow.sigil", kickbackLit ? .off : .blink)
        lamps.set("arrow.rightRamp", .off)
        lamps.set("arrow.orbit", .off)
        lamps.set("arrow.library", campaign.phase == .libraryLit || campaign.phase == .ritualLit ? .blink : .off)

        // During a tome only its goals blink (the ambient Sigil blink goes quiet).
        if let tome = running {
            lamps.set("arrow.sigil", .off)
            switch tome {
            case 0:                                   // pages: the spinner (orbit) and the ramp
                lamps.set("arrow.orbit", .blink)
                lamps.set("arrow.rightRamp", .blink)
            case 1:                                   // glyphs: the lit shots
                for shot in campaign.litShots { lamps.set("arrow.\(shot.rawValue)", .blink) }
            default:                                  // seals: the Sigil bank, then the ramp
                lamps.set(campaign.sealsBroken ? "arrow.rightRamp" : "arrow.sigil", .fastBlink)
            }
        }
        // During the Awakening's tentacles the ramp and orbit also cut (Cthulhu himself is the Lagoon arrow).
        if awakening {
            for shot in CthShot.allCases where shot != .lagoon { lamps.set("arrow.\(shot.rawValue)", .off) }
            if !eyeOpen {
                lamps.set("arrow.rightRamp", .blink)
                lamps.set("arrow.orbit", .blink)
            }
        }
        // During the Ritual only the unlit candles' shots blink.
        if ritualOn {
            for shot in CthShot.allCases { lamps.set("arrow.\(shot.rawValue)", .off) }
            for shot in CthCampaign.ritualShots where !campaign.candles.contains(shot) {
                lamps.set("arrow.\(shot.rawValue)", .blink)
            }
        }
    }

    // MARK: - Top of the table (milestone 3)

    /// Orbit (rails, funnel, diverter), Candle lanes, pop bumpers, the right ramp, the Library and Lagoon
    /// holes, the Sigil bank, and markers for the spinner and the ritual circle (they work in milestone 4).
    /// Grey box: these walls draw over the lower-table art (z 0).
    private func addTopOfTable() {
        addWall(points: CthTableLayout.orbitInnerWall,
                friction: CthTableLayout.railFriction, restitution: CthTableLayout.railRestitution, z: 0)

        for x in CthTableLayout.lanePostXs {
            addWall(points: [CGPoint(x: x, y: CthTableLayout.lanePostBottom),
                             CGPoint(x: x, y: CthTableLayout.lanePostTop)], z: 0)
        }
        for x in CthTableLayout.laneCenterXs {
            let lane = CthRollover(laneCenterX: x, painted: hasUpperArt)
            addChild(lane)
            rollovers.append(lane)
        }

        for center in CthTableLayout.bumperCenters {
            let bumper = CthBumper(at: center)
            addChild(bumper)
            bumpers.append(bumper)
        }

        // T3 M8 v2: the top-right lane (a curved wall inside the arch) and its one-way gate. The gate's physics is
        // the per-ball diverter edge (solid only for a ball moving right, round the orbit); the flap is drawn.
        addWall(points: CthTableLayout.topLaneWall, friction: CthTableLayout.railFriction,
                restitution: CthTableLayout.railRestitution, z: 0)          // M8 v4: baked into the art
        let a = CthTableLayout.topGateHinge, b = CthTableLayout.topGateEnd
        let dpath = CGMutablePath()
        dpath.addLines(between: [a, b])
        let diverter = SKShapeNode(path: dpath)
        diverter.strokeColor = .clear
        let dbody = SKPhysicsBody(edgeFrom: a, to: b)
        dbody.friction = CthTableLayout.railFriction
        dbody.restitution = CthTableLayout.railRestitution
        dbody.categoryBitMask = CthPhysicsCategory.diverter
        dbody.collisionBitMask = CthPhysicsCategory.ball
        diverter.physicsBody = dbody
        addChild(diverter)
        orbitDiverter = diverter
        // The flap: a brass blade hanging from a hinge pin on the arch, swinging left (clockwise) only.
        let (flap, closed) = makeGateFlap(hinge: a, end: b, art: "cth_gate_top", box: CthTableLayout.topGateArtBox)
        topGateFlap = flap
        topGateClosedAngle = closed

        // Art round 3 (T3 M8 v9): the rendered right ramp and Library wire, one sprite over the floor balls (z 10)
        // and under the ramp balls (z 30). With it, the ramps below build only their physics.
        var rampsBaked = false
        if let art = CthTableLayout.artSprite("cth_ramps", box: CthTableLayout.rampArtRect) {
            art.position = .zero
            art.zPosition = 20
            addChild(art)
            rampsBaked = true
        }

        // The right ramp
        let (rpath, apex) = CthTableLayout.rightRampPath()
        let ramp = CthRamp(path: rpath, apexDistance: apex,
                           mouthHalfWidth: CthTableLayout.rampMouthHalfWidth,
                           halfWidth: CthTableLayout.rampHalfWidth,
                           flareLength: CthTableLayout.rampFlareLength,
                           postLength: CthTableLayout.rampPostLength,
                           lowLength: CthTableLayout.rampLowLength, artBaked: rampsBaked)
        addChild(ramp)
        ramps.append(ramp)

        // The up-kicker's brass wire from the Library to the left inlane (milestone 4 round 2)
        let (wpath, wapex) = CthTableLayout.libraryWirePath()
        let wire = CthRamp(path: wpath, apexDistance: wapex,
                           mouthHalfWidth: CthTableLayout.rampHalfWidth,
                           halfWidth: CthTableLayout.rampHalfWidth,
                           flareLength: CthTableLayout.rampFlareLength,
                           postLength: 0, wireOnly: true,
                           endHeight: CthTableLayout.wireEndHeight, artBaked: rampsBaked)
        addChild(wire)
        ramps.append(wire)
        libraryWire = wire

        // The Library and the Lagoon
        let library = CthScoop(at: CthTableLayout.libraryCenter, ejectVelocity: CthTableLayout.libraryEject,
                               points: CthPoints.library, artBaked: hasUpperArt)
        let lagoon = CthScoop(at: CthTableLayout.lagoonCenter, ejectVelocity: CthTableLayout.lagoonEject,
                              points: CthPoints.lagoon, captureRadius: CthTableLayout.lagoonCaptureRadius,
                              artBaked: hasUpperArt)
        scoops = [library, lagoon]
        scoops.forEach { addChild($0) }
        libraryScoop = library
        lagoonScoop = lagoon

        // The Sigil bank: four drop targets, a wall behind them and a sloped cap on top
        for y in CthTableLayout.dropTargetYs {
            let target = CthDropTarget(at: CGPoint(x: CthTableLayout.dropTargetX, y: y))
            addChild(target)
            dropTargets.append(target)
        }
        addWall(points: CthTableLayout.sigilBankBackWall, z: 0)
        addWall(points: CthTableLayout.sigilBankCap, z: 0)

        // The spinner across the orbit lane (milestone 4 round 1)
        let spin = CthSpinner(from: CthTableLayout.spinnerLine.a, to: CthTableLayout.spinnerLine.b)
        addChild(spin)
        spinner = spin
        // Marker only, until a later round of milestone 4: the ritual circle + magnet.
        let ritual = SKShapeNode(circleOfRadius: CthTableLayout.ritualRadius)
        ritual.position = CthTableLayout.ritualCenter
        ritual.strokeColor = SKColor(red: 0.85, green: 0.71, blue: 0.35, alpha: 0.45)
        ritual.fillColor = .clear
        ritual.lineWidth = 1.5
        ritual.zPosition = -18
        if !hasUpperArt { addChild(ritual) }       // M8: the ritual circle is painted
        // Cthulhu, asleep under the Lagoon (milestone 4 round 4)
        let cth = CthCthulhu(at: CthTableLayout.lagoonCenter)
        addChild(cth)
        cthulhu = cth

        // The magnet under the ritual circle (milestone 4 round 3)
        let mag = CthMagnet(at: CthTableLayout.ritualCenter, radius: CthTableLayout.magnetPullRadius)
        addChild(mag)
        magnet = mag
        rampHaptic.prepare()
    }

    /// The magnet (milestone 4 round 3): pulls a passing floor ball toward the centre, grabs a slow one,
    /// holds it with a shiver, then flings it upward. Re-arms itself after a cooldown until the rules milestone.
    private func updateMagnet(_ dt: CGFloat, now: TimeInterval) {
        guard let magnet else { return }
        let c = CthTableLayout.ritualCenter
        if let held = magnetBall {
            guard let body = held.physicsBody, balls.contains(where: { $0 === held }) else {
                magnetBall = nil
                magnet.setState(.off)
                magnetArmAt = now + CthTableLayout.magnetCooldown
                return
            }
            body.velocity = .zero
            if now >= magnetReleaseAt {
                held.position = c
                body.affectedByGravity = true
                let angle = CGFloat.random(in: 40...140) * .pi / 180
                body.velocity = CGVector(dx: cos(angle) * CthTableLayout.magnetFlingSpeed,
                                         dy: sin(angle) * CthTableLayout.magnetFlingSpeed)
                magnetBall = nil
                magnet.setState(.off)
                magnetArmAt = now + CthTableLayout.magnetCooldown
                CthEffects.burst(in: self, at: c, color: CthEffects.eldritch, count: 22, speed: 260, lifetime: 0.5)
                cameraRig.shake(strength: 4, duration: 0.25)
                rampHaptic.impactOccurred()
                sfx(.magnetFling)
            } else {
                held.position = CGPoint(x: c.x + .random(in: -1.2...1.2), y: c.y + .random(in: -1.2...1.2))  // shiver
            }
            return
        }
        // The magnet works only while Cthulhu is awake in the Awakening ("his dream pulls at you").
        let dreaming = campaign.phase == .awakening
        if magnet.state == .off {
            if dreaming, now >= magnetArmAt { magnet.setState(.armed) }
            return
        }
        if !dreaming {
            magnet.setState(.off)
            return
        }
        for ball in balls where ball.isOnFloor && ball.heldIn == nil {
            guard let body = ball.physicsBody else { continue }
            let dx = c.x - ball.position.x, dy = c.y - ball.position.y
            let d = hypot(dx, dy)
            guard d < CthTableLayout.magnetPullRadius, d > 0.5 else { continue }
            let v = body.velocity
            if d < CthTableLayout.magnetGrabRadius, hypot(v.dx, v.dy) < CthTableLayout.magnetGrabMaxSpeed {
                magnetBall = ball
                magnetReleaseAt = now + CthTableLayout.magnetHold
                body.affectedByGravity = false
                body.velocity = .zero
                ball.position = c
                magnet.setState(.holding)
                award(CthPoints.magnet)
                showBanner("THE DREAMER STIRS")
                hitHaptic.impactOccurred()
                sfx(.magnetGrab)
                return
            }
            let a = CthTableLayout.magnetPull * (1 - d / CthTableLayout.magnetPullRadius) * dt
            body.velocity = CGVector(dx: v.dx + dx / d * a, dy: v.dy + dy / d * a)
        }
    }

    /// The one-way gates, per ball: the top gate (the diverter edge) is solid for a floor ball moving right (coming
    /// round the orbit); the launch gate for a floor ball above it moving down (T3 M8 v3).
    private func updateDiverter() {
        let low = CthTableLayout.gateLow, high = CthTableLayout.gateHigh
        let gx = high.x - low.x, gy = high.y - low.y
        for ball in balls {
            let v = ball.physicsBody?.velocity ?? .zero
            ball.setDiverterSolid(ball.isOnFloor && v.dx > 0)
            let p = ball.position
            let above = gx * (p.y - low.y) - gy * (p.x - low.x) > 0          // left of low → high = above the gate
            ball.setLaunchGateSolid(ball.isOnFloor && above && v.dy < 0)
        }
    }

    /// A drawn gate flap (T3 M8 v2/v3): a brass blade from `hinge` to `end` with a hinge pin. Returns the node and
    /// its closed angle (the blade points down its local −y).
    private func makeGateFlap(hinge: CGPoint, end: CGPoint, art: String, box: CGRect) -> (SKNode, CGFloat) {
        let flap = SKNode()
        flap.position = hinge
        flap.zPosition = 2
        let closed = atan2(end.y - hinge.y, end.x - hinge.x) + .pi / 2
        // Art round 5a: the rendered gate (brass blade + chrome hinge barrel), drawn at its closed angle with the
        // lean; it's counter-rotated inside the flap so it only turns by the swing.
        if let sprite = CthTableLayout.artSprite(art, box: box) {
            sprite.zRotation = -closed
            flap.addChild(sprite)
            flap.zRotation = closed
            addChild(flap)
            return (flap, closed)
        }
        let length = hypot(end.x - hinge.x, end.y - hinge.y)
        let blade = SKShapeNode(rect: CGRect(x: -2.5, y: -length, width: 5, height: length), cornerRadius: 2)
        blade.fillColor = SKColor(red: 0.86, green: 0.66, blue: 0.30, alpha: 1)
        blade.strokeColor = SKColor(red: 0.35, green: 0.25, blue: 0.08, alpha: 1)
        blade.lineWidth = 1
        flap.addChild(blade)
        let pin = SKShapeNode(circleOfRadius: 4)
        pin.fillColor = SKColor(red: 0.85, green: 0.86, blue: 0.89, alpha: 1)
        pin.strokeColor = SKColor(red: 0.25, green: 0.26, blue: 0.30, alpha: 1)
        pin.lineWidth = 1
        flap.addChild(pin)
        flap.zRotation = closed
        addChild(flap)
        return (flap, closed)
    }

    /// A ball went through a one-way gate: the flap swings open by `by` radians (clockwise for both gates) and
    /// falls back with a little wobble.
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

    /// Ramp switches and orbit switches, checked against how the ball moved this frame (after physics).
    private func updateRampLayer(_ ball: CthBall) {
        let p = ball.position
        let p0 = ball.previousPosition
        ball.previousPosition = p

        if ball.layer == .floor {
            if let ramp = ramps.first(where: { $0.acceptsFloorEntry && $0.entrySwitch.crossing(from: p0, to: p) == .forward }) {
                ball.activeRamp = ramp
                ball.setLayer(.rampUp)
            } else {
                if CthTableLayout.spinnerSwitch.crossing(from: p0, to: p) != .none, let body = ball.physicsBody {
                    let v = body.velocity
                    spinner?.kick(ballSpeed: hypot(v.dx, v.dy))
                    labEvent("spinner")
                    body.velocity = CGVector(dx: v.dx * CthSpinner.ballSpeedKept, dy: v.dy * CthSpinner.ballSpeedKept)
                }
                if CthTableLayout.topGateSwitch.crossing(from: p0, to: p) == .forward {
                    swing(topGateFlap, closedAngle: topGateClosedAngle, by: -1.75)        // a plunge through the top gate
                }
                if CthTableLayout.launchGateSwitch.crossing(from: p0, to: p) == .forward {
                    swing(launchGateFlap, closedAngle: launchGateClosedAngle, by: -1.4)   // a plunge up the shooter lane
                }
                if CthTableLayout.rightOutlaneSwitch.crossing(from: p0, to: p) == .forward {
                    ball.inRightOutlane = true       // on its way down the right outlane (outlane save)
                }
                switch CthTableLayout.orbitArmSwitch.crossing(from: p0, to: p) {
                case .forward: ball.orbitArmed = true
                case .backward: ball.orbitArmed = false
                case .none: break
                }
                if ball.orbitArmed, CthTableLayout.orbitMadeSwitch.crossing(from: p0, to: p) == .forward {
                    ball.orbitArmed = false
                    award(CthPoints.orbit)
                    shotsThisBall += 1
                    labEvent("orbit")
                    rampHaptic.impactOccurred(intensity: 0.7)
                    sfx(.orbit)
                    showBanner("ORBIT")
                    handle(campaign.shotMade(.orbit))
                }
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
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.rampDown)
                if ramp === libraryWire { break }       // the up-kicker scored at the Library
                award(CthPoints.rampShot)
                shotsThisBall += 1
                labEvent("rightRamp")
                rampHaptic.impactOccurred()
                CthEffects.burst(in: self, at: p, color: CthEffects.eldritch, count: 14, speed: 200, lifetime: 0.4)
                sfx(.ramp)
                showBanner("RAMP")
                handle(campaign.shotMade(.rightRamp))
            }
        case .rampDown:
            if ramp.exitSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.floor)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.rampUp)
            }
        }

        // Safety net: a ramp ball nowhere near the channel goes back to the floor.
        if ball.layer != .floor,
           ramp.distanceToCenterline(p) > ramp.maxHalfWidth + CthTableLayout.ballRadius + 12 {
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
                    ball.scoopIgnoreUntil = now + CthTableLayout.scoopRecapture
                    body.affectedByGravity = true
                    if scoop === libraryScoop, let wire = libraryWire {
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
                candidate.catches(from: from, to: ball.position) && !isHolding(candidate)
                    && !(candidate === lagoonScoop && (cthulhu?.isUp ?? false))
            }) else { continue }
            ball.heldIn = scoop
            ball.releaseAt = now + (scoop === libraryScoop ? CthTableLayout.upKickerHold : CthTableLayout.scoopHold)
            body.affectedByGravity = false
            body.velocity = .zero
            award(scoop.points)
            shotsThisBall += 1
            labEvent(scoop === lagoonScoop ? "lagoon" : "library")
            if scoop === lagoonScoop { CthEffects.splash(in: self, at: scoop.position, radius: 24, rings: 2, drops: 14) }
            CthEffects.burst(in: self, at: scoop.position, color: scoop === lagoonScoop ? CthEffects.sea : CthEffects.brass,
                          count: 20, speed: 180, lifetime: 0.5)
            sfx(.scoopIn)
            showBanner(scoop === lagoonScoop ? "LAGOON" : "LIBRARY")
            handle(scoop === lagoonScoop ? campaign.shotMade(.lagoon) : campaign.libraryCaught())
            scoop.flash()
            rampHaptic.impactOccurred(intensity: 0.8)
        }
    }

    /// The up-kicker (milestone 4 round 2): fires a ball held in the Library straight up onto its wire, which
    /// carries it over the top and down into the left inlane.
    private func upKick(_ ball: CthBall, onto wire: CthRamp) {
        guard let body = ball.physicsBody else { return }
        let (p, h) = wire.path.sample(at: CthTableLayout.upKickerStart)
        ball.setLayer(.rampUp)
        ball.activeRamp = wire
        ball.position = p
        ball.previousPosition = p
        body.velocity = CGVector(dx: cos(h) * CthTableLayout.upKickerSpeed, dy: sin(h) * CthTableLayout.upKickerSpeed)
        CthEffects.burst(in: self, at: CthTableLayout.libraryCenter, color: CthEffects.brass, count: 18, speed: 220, lifetime: 0.4)
        cameraRig.shake(strength: 3, duration: 0.2)
        rampHaptic.impactOccurred()
        sfx(.upKick)
    }

    /// Moves Cthulhu (sway) before physics. The rules raise and sink him (the Awakening, M7 v4).
    private func updateCthulhu(_ dt: CGFloat, now: TimeInterval) {
        cthulhu?.step(dt: dt, now: now)
    }

    private func isHolding(_ scoop: CthScoop) -> Bool {
        balls.contains(where: { $0.heldIn === scoop })
    }

    /// Drops targets hit this frame; when the whole bank is down, score it and raise it after a moment.
    private func updateDropTargets(_ now: TimeInterval) {
        if !pendingDrops.isEmpty {
            pendingDrops.forEach { $0.drop() }
            pendingDrops.removeAll()
            if bankResetAt == nil, dropTargets.allSatisfy({ $0.isDown }) {
                award(CthPoints.sigilBank)
                shotsThisBall += 1
                kickbackLit = true                   // a full Sigil bank lights the kickback
                handle(campaign.sigilBankCompleted())
                showBanner("SIGILS BROKEN")
                lamps.play(.flash, at: now)
                rampHaptic.impactOccurred()
                cameraRig.shake(strength: 5, duration: 0.35)
                sfx(.sigilBank)
                bankResetAt = now + CthTableLayout.dropTargetResetDelay
            }
        }
        if let due = bankResetAt, now >= due {
            bankResetAt = nil
            dropTargets.forEach { $0.raise() }
        }
    }

    /// Candle lanes: light each one; all three lit blink, clear, and score a banner.
    private func rollOver(_ lane: CthRollover, at now: TimeInterval) {
        // Skill shot: the first lane after launch decides it, hit or miss.
        if let skill = skillLane, ballLaunched {
            let hit = rollovers.indices.contains(skill) && rollovers[skill] === lane
            setSkillLane(nil)
            if hit {
                game.add(CthPoints.skillShot)
                rampHaptic.impactOccurred()
                CthEffects.burst(in: self, at: lane.position, color: CthEffects.candle, count: 30, speed: 260, lifetime: 0.7)
                sfx(.skillShot)
                cameraRig.shake(strength: 4, duration: 0.3)
                showBanner("SKILL SHOT")
            }
        }
        guard lanesResetAt == nil else { return }
        if lane.isLit {
            award(CthPoints.laneRepeat)
            return
        }
        lane.isLit = true
        award(CthPoints.laneLit)
        CthEffects.embers(in: self, at: CGPoint(x: lane.position.x, y: CthTableLayout.candleFlameY), count: 8)
        sfx(.candleLane)
        if rollovers.allSatisfy({ $0.isLit }) {
            rampHaptic.impactOccurred()
            lanesResetAt = now + 0.6
            // All three Candle lanes: the multiplier goes up (max 5x). (The ritual candles are lit by
            // shots during the Ritual, round 3, not by these lanes.)
            if game.raiseMultiplier() {
                showBanner("\(game.multiplier)X")
                sfx(.lanesComplete)
            } else {
                showBanner("CANDLES LIT")
            }
            handle(campaign.lanesCompleted())
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

    /// Scores each spin with a soft tick (at most 20 ticks a second) and shows the total when it stops.
    private func updateSpinner(_ dt: CGFloat, now: TimeInterval) {
        guard let spinner, spinner.isSpinning else { return }
        let spins = spinner.update(dt: dt)
        if spins > 0 {
            award(campaign.spinnerPoints * spins, cancelsSkillShot: false)   // a plunge can spin it on the way to the lanes
            handle(campaign.spins(spins))
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

    /// One-way gate across the top of the launch lane (T3 M8 v3, Aaron: make it "a one way spinny gate too to match"):
    /// a flap hanging from the outer wall. A plunge going up swings it open; a ball coming back down onto it (a
    /// plunge that couldn't make it round the top lane) is stopped and rolls off its low end into play. Physics: an
    /// edge solid per ball only while that ball is above it and moving down (updateDiverter); the flap is drawn.
    private func addGate() {
        let low = CthTableLayout.gateLow, high = CthTableLayout.gateHigh
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: low, to: high)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = CthPhysicsCategory.launchGate
        body.collisionBitMask = CthPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        let (flap, closed) = makeGateFlap(hinge: high, end: low, art: "cth_gate_launch", box: CthTableLayout.launchGateArtBox)
        launchGateFlap = flap
        launchGateClosedAngle = closed
    }


    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: "T3 M11 v1")
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
        let layer: String
        switch focusBall?.layer ?? .floor {
        case .floor: layer = "floor"
        case .rampUp: layer = "ramp up"
        case .rampDown: layer = "wire"
        }
        let text = "\(fps)T3 M11 v1 \(effectiveCameraMode.tag) · \(layer) · \(speed)"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: CthBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    /// Builds (or rebuilds) the two slingshots, left then right. The Sling Lab rebuilds them per design.
    private func buildSlings(_ slings: [(top: CGPoint, corner: CGPoint, tip: CGPoint)], artBaked: Bool,
                             kickFrom: CGFloat = CthTableLayout.slingKickFrom,
                             kickTo: CGFloat = CthTableLayout.slingKickTo) {
        slingshots.forEach { $0.removeFromParent() }
        slingshots.removeAll()
        for s in slings {
            let sling = CthSlingshot(top: s.top, corner: s.corner, tip: s.tip, artBaked: artBaked,
                                     kickFrom: kickFrom, kickTo: kickTo)
            addChild(sling)
            slingshots.append(sling)
        }
    }

    private func placeBallOnPlunger() {
        ballLaunched = false
        wasOnPlunger = false
        let r = CthTableLayout.ballRadius
        let ball = CthBall(at: CGPoint(x: CthTableLayout.laneCenterX, y: CthTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        servedBall = ball
        launchedAt = nil
        setSkillLane(rollovers.isEmpty ? nil : Int.random(in: 0..<rollovers.count))
    }

    private func removeBall(_ ball: CthBall) {
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
    }

    private func removeAllBalls() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        servedBall = nil
    }

    private func isOnPlunger(_ ball: CthBall) -> Bool {
        ball.position.x > CthTableLayout.laneWallX
            && ball.position.y < CthTableLayout.plungerRestTop + CthTableLayout.ballRadius * 3
    }

    private var plungerBall: CthBall? {
        balls.first(where: { isOnPlunger($0) })
    }

    private var isBallOnPlunger: Bool { plungerBall != nil }

    func newGame() {
        fpsLow = 0
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game (or Menu) stops the Shot Lab
        stopSlingLab()
        #endif
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        sound.stopLoop()                           // no Awakening drone carried into a new game
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = CthTableLayout.plungerRestPosition
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        pendingDrops.removeAll()
        bankResetAt = nil
        dropTargets.forEach { $0.raise() }
        magnetBall = nil
        magnet?.setState(.off)
        magnetArmAt = 0
        cthulhu?.reset()
        cthulhu?.regrowTentacles()
        campaign.reset()
        multiballOn = false
        pendingReleases = 0
        multiballSaveUntil = 0
        launchedAt = nil
        elderSignUsed = false
        kickbackLit = false
        outlaneSaveLit = false
        shotsThisBall = 0
        spinsThisBall = 0
        bonusStart = nil
        game.reset()
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + CthTableLayout.bannerSeconds
    }

    private func sfx(_ s: CthSound) {
        #if DEBUG
        if shotLab != nil || slingLab != nil { return }   // the robots play silently
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
            }
        }
        updateFlippers()
    }

    private func isInPlungerZone(_ p: CGPoint, of view: UIView) -> Bool {
        let b = view.bounds
        return p.x > b.width * CthTableLayout.plungerZoneMinX && p.y > b.height * CthTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches where activeTouches[touch] == .plunger {
            let dragged = (touch.location(in: view).y - plungerStartY) * cameraRig.node.yScale
            plungerPull = min(max(dragged, 0), CthTableLayout.plungerMaxPull)
            plunger.position.y = CthTableLayout.plungerRestPosition.y - plungerPull
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
            if activeTouches.removeValue(forKey: touch) == .plunger {
                releasePlunger()
            }
        }
        updateFlippers()
    }

    private func updateFlippers() {
        #if DEBUG
        if shotLab != nil || slingLab != nil { return }   // a lab robot has the flippers
        #endif
        let left = activeTouches.values.contains(.left) || padLeft
        let right = activeTouches.values.contains(.right) || padRight
        if left && !leftFlipper.isPressed { rotateLanes(by: -1); sfx(.flipper) }
        if right && !rightFlipper.isPressed { rotateLanes(by: 1); sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
        upperFlipper?.isPressed = right
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        padPullByA = false
        plungerPull = 0
        plunger?.position = CthTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    private func releasePlunger() {
        let maxPull = CthTableLayout.plungerMaxPull
        let power = plungerPull < 4 ? CthTableLayout.tapLaunchPower : plungerPull / maxPull
        if let body = plungerBall?.physicsBody {
            let speed = CthTableLayout.minLaunchSpeed
                + power * (CthTableLayout.maxLaunchSpeed - CthTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
        }
        plunger.run(.move(to: CthTableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    /// Game controller, every frame of play: shoulders/triggers flip, A held or the right stick pulled down works the
    /// plunger (released = launch, with the furthest pull reached). Touches keep working alongside.
    private func updateGamepad() {
        let pad = LabGamepad.shared.state
        if !pad.aDown { padAArmed = true }
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
            plungerPull = pull * CthTableLayout.plungerMaxPull
            plunger.position.y = CthTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * CthTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = CthTableLayout.plungerRestPosition
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
        if shotLab != nil {                     // Shot Lab: the robot's frame instead of a game frame
            updateShotLab(CGFloat(step))
            return
        }
        if slingLab != nil {
            updateSlingLab(CGFloat(step))
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
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        upperFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        updateLanes(now)
        updateDiverter()
        updateScoops(now)
        updateDropTargets(now)
        updateSpinner(dt, now: now)
        updateMagnet(dt, now: now)
        updateCthulhu(dt, now: now)
        // Juice round 2: the Awakening drone plays under the whole fight and fades out when it ends.
        sound.setLoop(target: campaign.phase == .awakening ? Float(settings.soundVolume) * CthTableLayout.awakeningDroneGain : 0)
        sound.stepLoop(dt: Float(dt))
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
        let ballInPlay = ballLaunched && bonusStart == nil && !balls.isEmpty
        handle(campaign.tick(TimeInterval(dt), active: ballInPlay))
        let status = campaign.statusText
        if game.status != status { game.status = status }
        if let t = launchedAt, skillLane != nil, now - t > CthTableLayout.skillShotWindow {
            setSkillLane(nil)
        }
        wasOnPlunger = onPlunger

        // Drain: remove every ball off the bottom; a ball is lost only when none are left.
        let drained = balls.filter { $0.position.y < -CthTableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            let rightOutlane = drained.contains { $0.inRightOutlane }
            drained.forEach { removeBall($0) }
            if multiballOn, now < multiballSaveUntil {
                // Ritual ball save: each drained ball is fired back up out of the Library.
                if pendingReleases == 0 { nextReleaseAt = now + 0.5 }
                pendingReleases += drained.count
                showBanner("BALL SAVED"); sfx(.ballSave)
            }
            if balls.isEmpty, pendingReleases == 0 {
                setSkillLane(nil)
                if !elderSignNow, outlaneSaveLit, rightOutlane {
                    // Outlane save: used up; the ball comes back, nothing lost.
                    outlaneSaveLit = false
                    game.ballSaved()
                    showBanner("OUTLANE SAVE"); sfx(.ballSave)
                    rampHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else if elderSignNow {
                    // The Elder Sign protects this ball once.
                    elderSignUsed = true
                    game.ballSaved()
                    showBanner("ELDER SIGN · BALL SAVED"); sfx(.ballSave)
                    rampHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else {
                    elderSignUsed = false            // the next ball gets its own save
                    outlaneSaveLit = false           // the outlane save lasts for the ball it was earned on
                    dimTable()
                    cameraRig.shake(strength: 4, duration: 0.3)
                    sfx(.drain)
                    startBonus(at: now)              // the ball is lost once the bonus has counted
                }
            }
        }

        updateMultiball(now)

        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            placeBallOnPlunger()
        }

        let waiting = isBallOnPlunger
        if game.ballOnPlunger != waiting {
            game.ballOnPlunger = waiting
        }
    }

    override func didSimulatePhysics() {
        for ball in balls {
            updateRampLayer(ball)
            guard let body = ball.physicsBody else { continue }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            let maxSpeed = ball.layer == .rampDown ? CthTableLayout.rampReturnMaxSpeed : CthTableLayout.maxBallSpeed
            if speed > maxSpeed {
                let scale = maxSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            ball.rampHeight = ball.layer == .floor ? 0 : (ball.activeRamp?.height(at: ball.position) ?? 0)
            ball.updateLook()
        }
    }

    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: lastStep)
        dimmer.size = size
        placeBuildTag()
    }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        if a.categoryBitMask == CthPhysicsCategory.ball {
            ballBody = a; other = b
        } else if b.categoryBitMask == CthPhysicsCategory.ball {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? CthBall, ballNode.isOnFloor,
              let node = other.node else { return }

        switch other.categoryBitMask {
        case CthPhysicsCategory.bumper:
            if let bumper = node as? CthBumper,
               bumper.hit(ball: ballBody, ballPosition: ballNode.position, at: gameTime) {
                award(CthPoints.bumper)
                labEvent("bumper")
                hitHaptic.impactOccurred()
                let mid = CGPoint(x: (ballNode.position.x + bumper.position.x) / 2,
                                  y: (ballNode.position.y + bumper.position.y) / 2)
                CthEffects.burst(in: self, at: mid, color: CthEffects.eldritch, count: 12, speed: 200, lifetime: 0.3)
                cameraRig.shake(strength: 2, duration: 0.15)
                sfx(.bumper)
            }

        case CthPhysicsCategory.rollover:
            if let lane = node as? CthRollover {
                rollOver(lane, at: gameTime)
                labEvent("lane")
            }

        case CthPhysicsCategory.target:
            if let target = node as? CthDropTarget, target.registerHit() {
                award(CthPoints.sigilTarget)
                labEvent("sigil")
                handle(campaign.shotMade(.sigil))
                CthEffects.burst(in: self, at: target.position, color: CthEffects.bone, count: 16, speed: 220, lifetime: 0.4)
                cameraRig.shake(strength: 2.5, duration: 0.2)
                sfx(.sigilTarget)
                pendingDrops.append(target)
                hitHaptic.impactOccurred(intensity: 0.7)
            }

        case CthPhysicsCategory.toy:
            if let toy = node as? CthCthulhu, toy.hit(at: gameTime) {
                labEvent("cthulhu")
                hitHaptic.impactOccurred()
                CthEffects.burst(in: self, at: ballNode.position, color: CthEffects.eldritch, count: 20, speed: 240, lifetime: 0.45)
                cameraRig.shake(strength: 5, duration: 0.3)
                sfx(.cthulhuHit)
                handle(campaign.cthulhuHit())          // a tentacle, or the eye (the robots ignore it)
            }

        case CthPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? CthSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                award(CthPoints.slingshot)
                labEvent("sling")
                #if DEBUG
                if let lab = slingLab, let i = slingshots.firstIndex(where: { $0 === sling }) {
                    lab.kick(sling: i, ballAt: ballNode.position, now: slingLabTime)
                }
                #endif
                hitHaptic.impactOccurred(intensity: 0.6)
                CthEffects.burst(in: self, at: ballNode.position, color: CthEffects.bone, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        default:
            break
        }
    }
}

// MARK: - Shot Lab (milestone 5, debug builds)

extension CthTableScene {
    /// A shot event for the Shot Lab; does nothing in normal play.
    fileprivate func labEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        #endif
    }

    #if DEBUG
    /// Starts the robot: it takes over the flippers and sweeps flip timings from a cradled ball on the left,
    /// right and upper flippers, at 120 Hz and 60 Hz physics steps. `cthulhuUp` keeps Cthulhu awake and
    /// swaying for the whole run (the Lagoon is then a moving target). Menu or a new game stops it.
    func debugStartShotLab(cthulhuUp: Bool) {
        isAttractMode = false
        shotLabTime = 0
        shotLabCthulhuUp = cthulhuUp
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// The robot's frame: only what the physics and shot detection need (no serving, drains or magnet).
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
        slingshots.forEach { $0.settle() }
        updateDiverter()
        updateScoops(now)
        updateDropTargets(now)
        updateLanes(now)
        _ = spinner?.update(dt: dt)
        cthulhu?.step(dt: dt, now: now)
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
// MARK: - Sling Lab (milestone 5 round 2)

extension CthTableScene: CthSlingLabHost {
    /// Starts the slingshot test: the same 160 balls thrown at each sling design (~30 min in the Simulator).
    func debugStartSlingLab() {
        isAttractMode = false
        shotLab = nil
        slingLabTime = 0
        slingLab = CthSlingLab(host: self)
        refreshCamera()
    }

    /// Stops the Sling Lab (if running) and puts the table's own slings back.
    fileprivate func stopSlingLab() {
        guard slingLab != nil else { return }
        slingLab = nil
        physicsWorld.speed = isAttractMode ? 0 : 1
        buildSlings([CthTableLayout.leftSling, CthTableLayout.rightSling], artBaked: hasLowerArt)
    }

    fileprivate func updateSlingLab(_ realDt: CGFloat) {
        guard let lab = slingLab else { return }
        let speed = CGFloat(CthSlingLab.physicsSpeed)
        physicsWorld.speed = speed
        let dt = realDt * speed
        slingLabTime += TimeInterval(dt)
        let now = slingLabTime
        lastStep = dt
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        upperFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        updateDiverter()
        updateScoops(now)
        updateDropTargets(now)
        if lab.update(now: now) {
            game.banner = lab.progressText
        } else {
            let saved = lab.save()
            let count = lab.trials.count
            stopSlingLab()
            slingLabResetTable()
            game.banner = "SLING LAB DONE · \(count) TRIALS · \(saved)"
        }
    }

    func slingLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        pendingDrops.removeAll()
        bankResetAt = nil
        dropTargets.forEach { $0.raise() }
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        magnetBall = nil
        magnet?.setState(.off)
        cthulhu?.reset()
        leftFlipper.isPressed = false
        rightFlipper.isPressed = false
        upperFlipper.isPressed = false
    }

    /// The design's slings, drawn in grey-box plastic over the art so you can see which one is running.
    func slingLabSetSlings(_ variant: CthSlingLab.Variant) {
        buildSlings([variant.leftSling, variant.rightSling], artBaked: false,
                    kickFrom: CGFloat(variant.kickFrom), kickTo: CGFloat(variant.kickTo))
    }

    func slingLabLaunch(at point: CGPoint, velocity: CGVector) {
        let ball = CthBall(at: point)
        addChild(ball)
        balls.append(ball)
        ball.physicsBody?.velocity = velocity
    }

    var slingLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }
}

extension CthTableScene: ShotLabHost {
    var shotLabTableName: String { shotLabCthulhuUp ? "Cthulhu Rising (Cthulhu up)" : "Cthulhu Rising" }

    var shotLabMajorEvents: Set<String> {
        ["rightRamp", "orbit", "library", "lagoon", "sigil", "lane", "cthulhu"]
    }

    /// Cthulhu's sway phase at the flip (0–1), when he's up.
    var shotLabContext: Double? { cthulhu?.swayPhase(at: shotLabTime) }

    /// Left, right and upper flippers. The cradle is just above each flipper held up (30° above
    /// horizontal): 40 pt out from the pivot on the main flippers (as in Grey Invasion), 32 on the 64-long
    /// upper flipper; the ball rolls back into the crook and settles.
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = CthTableLayout.flipperTravel - CthTableLayout.flipperRestAngle      // 30° above horizontal
        let along: CGFloat = 40, above: CGFloat = 14
        let l = CthTableLayout.leftFlipperPivot
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: CthTableLayout.mirrorSum - left.x, y: left.y)
        // The upper flipper points left: raised, its arm heads up-left at 150°; "above" is 90° clockwise of that.
        let u = CthTableLayout.upperFlipperPivot
        let arm = CGFloat.pi - up
        let ua: CGFloat = 32, uh: CGFloat = 17
        let upper = CGPoint(x: u.x + ua * cos(arm) + uh * sin(arm), y: u.y + ua * sin(arm) - uh * cos(arm))
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left),
                ShotLab.FlipperSpec(name: "right", pivot: CthTableLayout.rightFlipperPivot, cradle: right),
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
        let ball = CthBall(at: point)
        addChild(ball)
        balls.append(ball)
    }

    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        pendingDrops.removeAll()
        bankResetAt = nil
        dropTargets.forEach { $0.raise() }
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        magnetBall = nil
        magnet?.setState(.off)
        if shotLabCthulhuUp {
            if cthulhu?.isAwake != true { cthulhu?.forceAwake(at: shotLabTime) }
        } else {
            cthulhu?.reset()
        }
    }

    /// T3 M5 v2: where shots cross just below the Lagoon's catch, and lower down, to place it by measurement.
    var shotLabProbes: [ShotLab.Probe] {
        let y = CthTableLayout.lagoonCenter.y - CthTableLayout.lagoonCaptureRadius - 2
        return [ShotLab.Probe(name: "lagoon", y: y), ShotLab.Probe(name: "lagoonLow", y: 960)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }
}
#endif

extension CthTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated {
            handleContact(contact)
        }
    }
}
