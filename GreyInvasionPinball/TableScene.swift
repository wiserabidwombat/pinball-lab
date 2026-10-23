import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// The full grey-box table (milestone 4): walls, flippers (two main + the upper one), plunger
/// and one-way launch gate, both ramps, the lower table (inlanes, outlanes, slingshots,
/// kickback), the top (orbit, diverter, U-F-O lanes, saucer bumpers), both scoops and the
/// fighter bank, seen through a Flying, Wide or Top-Down camera.
///
/// Milestone 5: any number of balls can be in play. Each `Ball` carries its own state (layer,
/// ramp, scoop hold); every system below loops over `balls`. A ball is only lost when the
/// last one in play drains.
///
/// The scene uses .resizeFill, so `size` is the view in points and the camera
/// decides which part of the world is on screen.
final class TableScene: SKScene {
    private enum Control { case left, right, plunger }

    private let game: GameState
    private let settings: GameSettings
    private let cameraRig = CameraRig()
    /// Table text that grows with the camera zoom (M10 v5).
    private let tableLabels = TableLabels()
    private var buildTag: SKLabelNode?
    /// M10 v9 (Aaron: the tag was hard to read over the GREY INVASION art): a dark box behind it.
    private var buildTagBack: SKShapeNode?
    /// M10 v3: the tag's text is redrawn at most 4 times a second (a label re-renders on every text change).
    private var buildTagAt: TimeInterval = 0
    /// Frame-rate counter for the debug tag (M10 round 3): real frames counted between tag updates,
    /// the longest single frame in that window, and the lowest frame rate seen this game.
    private var fpsWindowStart: CFTimeInterval = 0
    private var fpsLastFrame: CFTimeInterval = 0
    private var fpsFrames = 0
    private var fpsWorstGap: CFTimeInterval = 0
    private var fpsShown = 0
    private var fpsWorstShown = 0
    private var fpsLow = 0
    #if DEBUG
    /// Shot Lab robot (M10 v12, debug builds): measures shot timing windows with the real physics.
    private var shotLab: ShotLab?
    /// The lab's own clock: table time, which runs at the pass speed (lab.physicsSpeed) while it aims (M10 v13–v14).
    private var shotLabTime: TimeInterval = 0
    /// Play Lab (shared, PlayLab.swift): the run, when its next game starts, and the robot's buttons.
    private var playLab: PlayLab?
    private var playLabNextAt: TimeInterval?
    private var playLabStarting = false
    private var robotLeft = false
    private var robotRight = false
    #endif
    private var lastStep: CGFloat = 0
    /// Every ball in play (milestone 5). Per-ball state lives on `Ball`.
    private var balls: [Ball] = []
    /// The ball most recently put on the plunger; the launch gate follows this one.
    private var servedBall: Ball?

    private var ramps: [Ramp] = []               // Tractor Beam (right), Defense Cannon (left)
    private var scoops: [Scoop] = []             // Hangar, Abduction
    private var abductionScoop: Scoop?
    private var tractorBeam: Ramp?

    // Lamps (milestone 6)
    private let lamps = LampController()
    /// Darkens the whole screen for a moment on a drain ("general illumination" dip).
    private let dimmer = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))

    /// The menu's attract mode (M6 round 2): physics stopped, whole-table camera, lamp chase.
    /// The scene keeps running (unlike a pause) so the lamps can animate behind the menu.
    var isAttractMode = false {
        didSet {
            guard isAttractMode != oldValue else { return }
            #if DEBUG
            if isAttractMode { shotLab = nil }        // Menu stops the Shot Lab
            if isAttractMode { stopPlayLab(saving: true) }   // and the Play Lab (saving the games so far)
            #endif
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode {
                releaseAllControls()
                lamps.play(.attract, at: gameTime)
            } else {
                lamps.stopShow()
            }
            refreshCamera()
        }
    }
    private var shipsDown = 0                    // drop targets hit this ball, for the Ships Down ladder
    // End-of-ball bonus (M7 round 5): ships × 1,000 + ramps × 500, × the multiplier
    private var shipsThisBall = 0                // uncapped (the ladder shows 10)
    private var rampsThisBall = 0
    private var bonusStart: TimeInterval?        // counting while set; the next ball waits for it
    private var bonusBase = 0
    private var bonusMultiplier = 1

    // Rules (milestone 7 round 1)
    private var launchedAt: TimeInterval?        // when the served ball left the plunger
    private var shieldsUsed = false              // Shields Up saves once per player ball
    private var skillLane: Int?                  // index into rollovers with the pulsing ring
    private var lastShotAt: TimeInterval?        // last ramp or orbit made, for combos
    private var bannerClearAt: TimeInterval?
    private let campaign = Campaign()            // waves (M7 round 2)
    private let invaders = InvaderLayer()        // M8 art round 4: scouts, abductor, Mothership (visual only)
    private let sound = SoundPlayer()            // M9 round 2: sound effects
    private var outlaneSaveLit = false           // right outlane save, lit by clearing a wave (M7 v5)

    // Ball lock + multiball (milestone 5 round 2)
    private var lockedBalls = 0                  // balls abducted so far toward multiball
    private var multiballActive = false
    private var mothershipMultiball = false       // M7 round 4: this multiball is the Mothership finale
    private var releaseScoop: Scoop?              // where multiball balls come out (Abduction or Hangar)
    private var multiballSaveUntil: TimeInterval = 0   // drained balls come back until then
    private var bumpers: [Bumper] = []            // the Mothership's shield generators, by index
    /// Abduction multiball (locks + Tractor Beam jackpot), as opposed to the Mothership's.
    private var abductionMultiball: Bool { multiballActive && !mothershipMultiball }
    private var pendingReleases = 0              // locked balls still to come out of the scoop
    private var nextReleaseAt: TimeInterval = 0
    private let bigHaptic = Haptic(style: .heavy)

    // Fighter bank (milestone 4 round 4a)
    private var dropTargets: [DropTarget] = []
    private var pendingDrops: [DropTarget] = []   // hit in a contact callback, dropped in update
    private var bankResetAt: TimeInterval?
    private let rampHaptic = Haptic(style: .medium)

    // Lower table (milestone 4 round 1)
    private var slingshots: [Slingshot] = []
    private var kickbackLit = false
    private let hitHaptic = Haptic(style: .medium)

    // Top of the table (milestone 4 round 2)
    private var rollovers: [Rollover] = []
    private var lanesResetAt: TimeInterval?       // set while the completed lanes blink
    private var orbitDiverter: SKShapeNode!
    private var leftFlipper: Flipper!
    private var rightFlipper: Flipper!
    private var upperFlipper: Flipper!            // right side, on the right button
    private var plunger: SKShapeNode!
    private var gate: SKShapeNode!
    private var gateClosed = false
    private var isBuilt = false

    // Input
    private var activeTouches: [UITouch: Control] = [:]
    private var plungerStartY: CGFloat = 0     // screen points (UIKit, y grows downward)
    private var plungerPull: CGFloat = 0
    // Game controller (LabGamepad): the flippers it holds, whether it's pulling the plunger and how far at most,
    // and whether A has been let go since the last Play / Resume (so that press doesn't also pull the plunger).
    private var padLeft = false
    private var padRight = false
    private var padPulling = false
    private var padPeakPull: CGFloat = 0
    private var padPullByA = false
    private var padAArmed = false

    // Game clock: advances by the clamped frame time only, so pauses and hitches
    // never eat into timers.
    private var lastRealTime: TimeInterval?
    private var gameTime: TimeInterval = 0
    private var nextBallAt: TimeInterval?
    private var wasOnPlunger = false
    private var ballLaunched = false

    // Pause. SpriteKit un-pauses a scene by itself when the app returns to the
    // foreground, so isPaused is pinned to true while the game is paused.
    var isGamePaused = false {
        didSet {
            if isGamePaused { releaseAllControls() } else { padAArmed = false }
            isPaused = isGamePaused
            lastRealTime = nil   // don't count the paused gap as a frame
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    private static let wallColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)

    init(game: GameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: TableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1)   // night sky round the cabinet art
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: TableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        dimmer.alpha = 0
        dimmer.zPosition = 40                     // over the table, under the debug tag
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

    /// The camera mode in use right now: the player's choice, except during multiball with the
    /// full-table setting on, when it's Top-Down. The rig eases between framings by itself
    /// (follow rate 6), so switching in and out of multiball is a smooth zoom, not a cut.
    private var effectiveCameraMode: CameraMode {
        if isAttractMode { return .topDown }
        #if DEBUG
        if shotLab != nil { return .topDown }
        #endif
        if multiballActive && settings.multiballFullTable { return .topDown }
        return settings.cameraMode
    }

    /// Jumps the camera straight to its framing (start of a game, a mode change while paused,
    /// a size change). Safe to call before the table is built.
    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        dimmer.size = size
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addPlayfieldArt()
        addChild(tableLabels)
        addChild(invaders)
        addWall(points: TableLayout.outerWall,
                friction: TableLayout.railFriction, restitution: TableLayout.railRestitution)
        addWall(points: TableLayout.leftLaneGuide)
        addWall(points: TableLayout.kickbackLaneWall)   // M7 v4: keeps the left outlane narrow down to the kickback
        addWall(points: TableLayout.rightOutlaneWall)   // M7 v6: the same on the right
        addWall(points: TableLayout.rightApron)         // M7 v6: apron slope + right side of the drain chute
        addWall(points: TableLayout.rightLaneGuide)
        addLowerTable()
        addTopOfTable()

        leftFlipper = Flipper(side: .left, pivot: TableLayout.leftFlipperPivot)
        rightFlipper = Flipper(side: .right, pivot: TableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)
        upperFlipper = Flipper(side: .right, pivot: TableLayout.upperFlipperPivot,
                               length: TableLayout.upperFlipperLength,
                               pivotRadius: TableLayout.upperFlipperPivotRadius,
                               tipRadius: TableLayout.upperFlipperTipRadius)
        upperFlipper.attach(to: self)
        addWall(points: TableLayout.upperFlipperGuide)

        addPlunger()
        addGate()

        for (path, apex) in [TableLayout.tractorBeamPath(), TableLayout.defenseCannonPath()] {
            let ramp = Ramp(path: path, apexDistance: apex,
                            mouthHalfWidth: TableLayout.rampMouthHalfWidth,
                            halfWidth: TableLayout.rampHalfWidth,
                            flareLength: TableLayout.rampFlareLength,
                            postLength: TableLayout.rampPostLength)
            addChild(ramp)
            ramps.append(ramp)
        }
        tractorBeam = ramps.first
        // M8 art round 2: the ramps' names on their plastic (as in the concept)
        // (M10 v5: live labels that grow with the camera zoom, so they read in Top-Down)
        if let first = ramps.first {
            tableLabels.addRampLabel("TRACTOR BEAM", to: first, at: CGPoint(x: 420, y: 760), degrees: 70.9)
        }
        if let last = ramps.last {
            tableLabels.addRampLabel("DEFENSE CANNON", to: last, at: CGPoint(x: 172, y: 770), degrees: -70.9)
        }
        rampHaptic.prepare()

        scoops = [
            Scoop(at: TableLayout.hangarCenter, ejectVelocity: TableLayout.hangarEject, points: Points.hangar),
            Scoop(at: TableLayout.abductionCenter, ejectVelocity: TableLayout.abductionEject, points: Points.abduction),
        ]
        scoops.forEach { addChild($0) }
        abductionScoop = scoops.last

        bigHaptic.prepare()

        // Fighter bank: four drop targets with a wall behind and a sloped cap on top
        for y in TableLayout.dropTargetYs {
            let target = DropTarget(at: CGPoint(x: TableLayout.dropTargetX, y: y))
            addChild(target)
            dropTargets.append(target)
        }
        addWall(points: TableLayout.fighterBankBackWall)
        addWall(points: TableLayout.fighterBankCap)

        addLamps()
    }

    /// Milestone 8 art round 1: the baked playfield (scenery, apron, cabinet, labels and every
    /// fixed rail), drawn by tools/art_playfield.py from the same coordinates as TableLayout.
    /// It sits under everything; lamps (z -1) and all moving parts are drawn on top in code.
    private func addPlayfieldArt() {
        let art = SKSpriteNode(imageNamed: "playfield")
        art.size = TableLayout.playfieldArtRect.size
        art.position = CGPoint(x: TableLayout.playfieldArtRect.midX, y: TableLayout.playfieldArtRect.midY)
        art.zPosition = -20
        addChild(art)
    }

    // MARK: - Lamps

    private func addLamp(_ lamp: Lamp, _ name: String) {
        addChild(lamp)
        lamps.add(lamp, named: name)
    }

    /// Every lamp insert on the table (positions in TableLayout "Lamp inserts").
    private func addLamps() {
        let green = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
        let teal = SKColor(red: 0.25, green: 0.90, blue: 0.85, alpha: 1)
        let orange = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        let red = SKColor(red: 1.0, green: 0.35, blue: 0.30, alpha: 1)
        let blue = SKColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
        let yellow = SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        let purple = SKColor(red: 0.70, green: 0.45, blue: 1.0, alpha: 1)
        let arrowColors: [String: SKColor] = [
            "rightRamp": green, "leftRamp": green, "orbit": teal,
            "hangar": orange, "abduction": orange, "bank": red,
        ]
        let arrowShape = Lamp.Shape.arrow(length: TableLayout.arrowLength, width: TableLayout.arrowWidth)
        for a in TableLayout.shotArrows {
            addLamp(Lamp(arrowShape, color: arrowColors[a.name] ?? green, at: a.at, angle: a.degrees * .pi / 180),
                    "arrow.\(a.name)")
        }
        for (i, p) in TableLayout.earthDefenseLamps.enumerated() {
            addLamp(Lamp(.round(radius: TableLayout.earthDefenseRadius), color: blue, at: p), "defense.\(i)")
        }
        for (i, p) in TableLayout.shipsDownLamps.enumerated() {
            addLamp(Lamp(.round(radius: TableLayout.shipsDownRadius), color: yellow, at: p), "ships.\(i)")
        }
        for (i, p) in TableLayout.lockLampCenters.enumerated() {
            addLamp(Lamp(.round(radius: TableLayout.lockLampRadius), color: green, at: p), "lock.\(i)")
        }
        addLamp(Lamp(.bar(size: TableLayout.shieldsUpSize), color: purple, at: TableLayout.shieldsUpCenter), "shieldsUp")
        addLamp(Lamp(.bar(size: TableLayout.kickbackLampSize), color: orange, at: TableLayout.kickbackLampCenter), "kickback")
        addLamp(Lamp(.bar(size: TableLayout.kickbackLampSize), color: teal, at: TableLayout.outlaneSaveLampCenter), "outlaneSave")
        addLamp(Lamp(.round(radius: TableLayout.extraBallRadius), color: red, at: TableLayout.extraBallCenter), "extraBall")
    }

    /// Lamp states from what the rules know so far. The waves (milestone 7) will drive the
    /// left ramp, orbit and Hangar arrows, the Earth Defense meter, Shields Up and Extra Ball;
    /// until then those stay dark.
    private func updateLampStates() {
        lamps.set("arrow.rightRamp", abductionMultiball ? .fastBlink : .off)   // jackpot during multiball
        // M7 v10: while a wave runs, only its targets blink (playtest: the last scout was hard to
        // find among the lock / kickback / combo blinks).
        let waveOn = campaign.phase == .running
        lamps.set("arrow.abduction", multiballActive || waveOn ? .off : .blink)   // a lock is lit
        lamps.set("arrow.bank", kickbackLit || waveOn ? .off : .blink)            // the bank relights the kickback
        lamps.set("kickback", kickbackLit ? .on : .off)
        lamps.set("outlaneSave", outlaneSaveLit ? .on : .off)
        for i in 0..<TableLayout.locksForMultiball {
            let state: LampState
            if abductionMultiball {
                state = .fastBlink
            } else if i < lockedBalls {
                state = .on
            } else if i == lockedBalls {
                state = .blink                                              // the next lock
            } else {
                state = .off
            }
            lamps.set("lock.\(i)", state)
        }
        for i in 0..<TableLayout.shipsDownLamps.count {
            lamps.set("ships.\(i)", i < shipsDown ? .on : .off)
        }

        // M7 v1: during a combo window the ramps and the orbit fast-blink (shoot one now = double).
        let comboOn = !waveOn && (lastShotAt.map { gameTime - $0 <= TableLayout.comboWindow } ?? false)
        lamps.set("arrow.leftRamp", comboOn ? .fastBlink : .off)
        lamps.set("arrow.orbit", comboOn ? .fastBlink : .off)
        if comboOn { lamps.set("arrow.rightRamp", .fastBlink) }

        // M7 round 2: the campaign. Hangar blinks while it's lit to start a wave; each scout
        // still up blinks its shot's arrow (the Tractor Beam jackpot in multiball wins).
        lamps.set("arrow.hangar", campaign.phase == .ready || campaign.extraBallLit ? .blink : .off)
        lamps.set("extraBall", campaign.extraBallLit ? .blink : .off)
        for (i, bumper) in bumpers.enumerated() {          // Mothership shield rings (nil = hidden)
            bumper.setShield(hitsLeft: campaign.shieldHits.indices.contains(i) ? campaign.shieldHits[i] : nil)
        }
        if campaign.wantsFighterBank { lamps.set("arrow.bank", .fastBlink) }   // Wave 2 goal
        for shot in campaign.litShots {
            if shot == .rightRamp && abductionMultiball { continue }
            lamps.set("arrow.\(shot.rawValue)", .blink)
        }
        // Earth Defense meter: cleared waves on; the current wave blinks when lit, fast while on.
        for i in 0..<TableLayout.earthDefenseLamps.count {
            var state = LampState.off
            if i < campaign.wavesCleared {
                state = .on
            } else if i == campaign.wavesCleared {
                if campaign.phase == .running {
                    state = .fastBlink
                } else if campaign.phase == .ready {
                    state = .blink
                }
            }
            lamps.set("defense.\(i)", state)
        }

        // Shields Up: on while armed, fast-blinks for the last seconds, off once used or over.
        var shields = LampState.off
        if !shieldsUsed {
            if let t = launchedAt {
                let left = TableLayout.shieldsUpSeconds - (gameTime - t)
                if left > TableLayout.shieldsUpWarning {
                    shields = .on
                } else if left > 0 {
                    shields = .fastBlink
                }
            } else if servedBall != nil {
                shields = .on                                               // waiting on the plunger
            }
        }
        lamps.set("shieldsUp", shields)
    }

    // MARK: - Rules (milestone 7 round 1)

    /// Every award goes through here: it's multiplied (GameState.add), and scoring anything
    /// before the skill-shot lane cancels the skill shot.
    private func award(_ points: Int) {
        if skillLane != nil { setSkillLane(nil) }
        game.add(points)
    }

    /// A short message in the HUD.
    private func showBanner(_ text: String) {
        #if DEBUG
        playLab?.banner(text)
        labObjective(forBanner: text)
        #endif
        game.banner = text
        bannerClearAt = gameTime + TableLayout.bannerSeconds
    }

    /// Whether a ball that drains now is saved: once per player ball, while the ball waits on
    /// the plunger and for the first seconds after launch.
    private var shieldsUpNow: Bool {
        guard !shieldsUsed else { return false }
        if let t = launchedAt { return gameTime - t <= TableLayout.shieldsUpSeconds }
        return true
    }

    /// Puts the skill-shot ring on one lane (nil = none).
    private func setSkillLane(_ index: Int?) {
        skillLane = index
        for (i, lane) in rollovers.enumerated() {
            lane.isSkillTarget = (i == index)
        }
    }

    /// A ramp or orbit was made: base points, doubled when it comes within the combo window
    /// of the last one.
    private func shotMade(_ points: Int, at now: TimeInterval) -> Bool {
        let combo = lastShotAt.map { now - $0 <= TableLayout.comboWindow } ?? false
        lastShotAt = now
        award(combo ? points * 2 : points)
        return combo
    }

    /// Orbit shot (the ball crossed the orbit switch going up).
    private func orbitMade(at now: TimeInterval) {
        let combo = shotMade(Points.orbit, at: now)
        rampHaptic.impactOccurred(intensity: 0.7)
        sfx(.orbit)
        if combo { showBanner("COMBO") }
        handle(campaign.shotMade(.orbit, canStart: false))
    }

    // MARK: - End-of-ball bonus (M7 round 5)

    /// A ship shot down: the Ships Down ladder (max 10 lamps) and the bonus count (uncapped).
    private func addShipDown() {
        shipsDown = min(shipsDown + 1, TableLayout.shipsDownLamps.count)
        shipsThisBall += 1
    }

    private func startBonus(at now: TimeInterval) {
        bonusBase = shipsThisBall * TableLayout.bonusPerShip + rampsThisBall * TableLayout.bonusPerRamp
        bonusMultiplier = game.multiplier
        bonusStart = now
        setSkillLane(nil)
    }

    /// Counts the bonus up in the LED strip, shows the multiplier, adds it, then loses the ball.
    private func updateBonus(_ now: TimeInterval) {
        guard let start = bonusStart else { return }
        let t = now - start
        // M10: with the bonus count turned off in Settings, the bonus is added straight away.
        let counting = settings.bonusCountOn
        let countTime = counting ? TableLayout.bonusCountSeconds : 0
        let holdTime = counting ? TableLayout.bonusHoldSeconds : 0
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

        game.add(bonusBase)                          // × the multiplier, which the drain then resets
        game.bonusText = nil
        bonusStart = nil
        shipsDown = 0
        shipsThisBall = 0
        rampsThisBall = 0
        game.ballDrained()
        if !game.isGameOver {
            nextBallAt = now + 0.5
        }
    }

    #if DEBUG
    /// Pause-menu shortcuts for testing the campaign (debug builds only).
    func debugSkipWave() {
        campaign.debugSkipWave()
        showBanner("DEBUG: HANGAR LIT")
    }

    func debugLightMothership() {
        campaign.debugLightMothership()
        showBanner("DEBUG: MOTHERSHIP LIT")
    }

    /// Shot Lab: the robot takes over the flippers and sweeps flip timings from a cradled ball on
    /// each flipper. Progress shows on the status line; Menu or a new game stops it.
    func debugStartShotLab() {
        isAttractMode = false
        shotLabTime = 0
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// The robot's frame: only what the physics and shot detection need (no rules, drains or serving).
    private func updateShotLab(_ realDt: CGFloat, now realNow: TimeInterval) {
        guard let lab = shotLab else { return }
        // Slow motion while aiming (M10 v13): the physics, the flippers and the lab clock all run at
        // the same fraction of real time, so a 60 fps frame is ~4 ms of table time.
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
        lamps.update(time: now)
        if lab.update(now: now) {
            game.status = lab.progressText
        } else {
            let saved = lab.save(now: now)
            shotLab = nil
            physicsWorld.speed = 1
            shotLabResetTable()
            game.status = "SHOT LAB DONE · \(lab.trials.count) TRIALS · \(saved)"
        }
    }
    #endif

    /// A shot event for the Shot Lab (debug builds); does nothing in normal play.
    private func labEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        playLab?.shot(name, now: gameTime)
        #endif
    }

    // MARK: - Juice (milestone 9)

    /// A spark burst in the scene (Effects.burst) at a world point.
    private func fx(_ at: CGPoint, _ color: SKColor, count: Int = 14, speed: CGFloat = 220,
                    life: CGFloat = 0.35, size: CGFloat = 0.3) {
        Effects.burst(in: self, at: at, color: color, count: count, speed: speed, lifetime: life, size: size)
    }

    /// Plays a sound effect (missing files are skipped).
    private func sfx(_ s: Sound) {
        #if DEBUG
        if shotLab != nil || playLab != nil { return }   // the robots play silently
        #endif
        sound.play(s, volume: Float(settings.soundVolume))   // M10: the settings volume
    }

    /// Where a burst with no natural spot goes: the ball the camera follows, else mid-table.
    private var fxFocus: CGPoint { focusBall?.position ?? CGPoint(x: 284, y: 600) }

    /// Awards, banners and lamp shows for whatever the campaign reports.
    private func handle(_ event: Campaign.Event) {
        switch event {
        case .none:
            break
        case .waveLit:
            showBanner("HANGAR LIT")
            bigHaptic.impactOccurred()
        case .waveStarted(let wave):
            sfx(wave == 4 ? .mothership : .waveStart)
            if wave == 4 {
                showBanner("MOTHERSHIP!")
                dimTable()                               // the lights dip as it arrives
                startMothership(at: gameTime)
            } else {
                showBanner("WAVE \(wave): \(Campaign.name(of: wave))")
            }
            lamps.play(.sweep, at: gameTime)
            bigHaptic.impactOccurred()
        case .progress(let points, let banner, let shipDown):
            award(points)
            if shipDown { addShipDown() }
            if !banner.isEmpty { showBanner(banner) }
            switch banner {
            case "SCOUT DOWN": sfx(.scoutDown)
            case "COW SAVED": sfx(.cowSaved)
            case "": break
            default: sfx(.multiplier)                     // CORE OPEN, SHOOT THE DEFENSE CANNON…
            }
            hitHaptic.impactOccurred()
        case .waveCleared(let wave, let points):
            award(points)                                // includes the clear / destroy bonus
            sfx(wave == 4 ? .mothershipBoom : .waveCleared)
            addShipDown()
            showBanner(wave == 4 ? "MOTHERSHIP DESTROYED! INVASION \(campaign.invasion)" : "WAVE \(wave) CLEARED")
            if wave == 4 {
                invaders.mothershipBlowsUp()
                fx(CGPoint(x: 284, y: 1238), Effects.alienGreen, count: 80, speed: 420, life: 1.0, size: 0.5)
                fx(CGPoint(x: 284, y: 1238), Effects.gold, count: 40, speed: 300, life: 0.9, size: 0.4)
                cameraRig.shake(strength: 12, duration: 0.7)
            } else {
                fx(fxFocus, Effects.gold, count: 40, speed: 320, life: 0.8, size: 0.4)
                cameraRig.shake(strength: 6, duration: 0.4)
            }
            outlaneSaveLit = true                    // reward: the right outlane saves one drain
            lamps.play(.flash, at: gameTime)
            bigHaptic.impactOccurred()
        case .waveFailed(let wave):
            showBanner(wave == 4 ? "MOTHERSHIP ESCAPED" : "SCOUTS ESCAPED")
            if wave == 1 { invaders.scoutsEscape() }     // the scouts fly off instead of being shot down
        case .coreHit(let points, let hitsLeft):
            award(points)
            invaders.mothershipHit()
            sfx(.coreHit)
            fx(CGPoint(x: 284, y: 1226), Effects.alienGreen, count: 40, speed: 300, life: 0.7, size: 0.4)
            cameraRig.shake(strength: 8, duration: 0.45)
            showBanner("CORE HIT! \(hitsLeft) TO GO")
            lamps.play(.flash, at: gameTime)
            bigHaptic.impactOccurred()
        case .cowAbducted:
            showBanner("COW ABDUCTED!")                // goofy, not fatal: the next abductor comes
            invaders.cowTaken()
            sfx(.cowTaken)
            hitHaptic.impactOccurred(intensity: 0.5)
        case .extraBall:
            game.awardExtraBall()
            sfx(.extraBall)
            fx(TableLayout.hangarCenter, Effects.gold, count: 40, speed: 300, life: 0.8, size: 0.4)
            cameraRig.shake(strength: 5, duration: 0.35)
            showBanner("EXTRA BALL")
            lamps.play(.flash, at: gameTime)
            bigHaptic.impactOccurred()
        }
    }

    private func updateRules(_ now: TimeInterval) {
        if let t = launchedAt, skillLane != nil, now - t > TableLayout.skillShotWindow {
            setSkillLane(nil)
        }
        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }
        let status = campaign.statusText             // changes about once a second at most
        if game.status != status { game.status = status }
    }

    /// Slingshots above each flipper and the kickback lamp in the left outlane.
    private func addLowerTable() {
        for s in [TableLayout.leftSling, TableLayout.rightSling] {
            let sling = Slingshot(top: s.top, corner: s.corner, tip: s.tip)
            addChild(sling)
            slingshots.append(sling)
        }

        setKickback(lit: false)
        hitHaptic.prepare()
    }

    /// Orbit inner wall, U-F-O lane posts and sensors, and the saucer bumpers.
    private func addTopOfTable() {
        addWall(points: TableLayout.orbitInnerWall,
                friction: TableLayout.railFriction, restitution: TableLayout.railRestitution)

        for x in TableLayout.lanePostXs {
            addWall(points: [CGPoint(x: x, y: TableLayout.lanePostBottom),
                             CGPoint(x: x, y: TableLayout.lanePostTop)])
        }
        for x in TableLayout.laneCenterXs {
            let lane = Rollover(laneCenterX: x)
            addChild(lane)
            rollovers.append(lane)
        }

        for center in TableLayout.bumperCenters {
            let bumper = Bumper(at: center)
            addChild(bumper)
            bumpers.append(bumper)
        }

        // One-way orbit diverter (solid only while the ball moves right)
        let a = TableLayout.orbitDiverterTop, b = TableLayout.orbitDiverterBottom
        let path = CGMutablePath()
        path.addLines(between: [a, b])
        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        node.lineWidth = 4
        node.lineCap = .round
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = TableLayout.railFriction
        body.restitution = TableLayout.railRestitution
        body.categoryBitMask = PhysicsCategory.diverter
        body.collisionBitMask = PhysicsCategory.ball
        node.physicsBody = body
        node.alpha = 0.35
        addChild(node)
        orbitDiverter = node
    }

    /// The diverter is solid for each floor ball moving right (coming round the orbit) and
    /// open for a ball moving left (a plunge along the top), per ball, through that ball's
    /// collision mask. Drawn bright while it's solid for any ball. Runs in update.
    private func updateDiverter() {
        var anySolid = false
        for ball in balls {
            let movingRight = ball.isOnFloor && (ball.physicsBody?.velocity.dx ?? 0) > 0
            ball.setDiverterSolid(movingRight)
            if movingRight { anySolid = true }
        }
        orbitDiverter?.alpha = anySolid ? 1 : 0.35
    }

    /// The kickback lamp follows kickbackLit (updateLampStates).
    private func setKickback(lit: Bool) {
        kickbackLit = lit
    }

    /// A lit kickback fires a ball that is draining down the left outlane straight back up it.
    /// One save, then it must be relit, even in multiball.
    private func updateKickback() {
        guard kickbackLit else { return }
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody else { continue }
            let p = ball.position
            if p.x < TableLayout.kickbackMaxX, p.y < TableLayout.kickbackTriggerY, p.y > 0, body.velocity.dy < 0 {
                body.velocity = CGVector(dx: 0, dy: TableLayout.kickbackSpeed)
                setKickback(lit: false)              // used up until it's lit again
                rampHaptic.impactOccurred()
                fx(p, Effects.orange, count: 18, speed: 240)
                cameraRig.shake(strength: 3, duration: 0.25)
                sfx(.kickback)
                return
            }
        }
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = TableLayout.wallFriction,
                         restitution: CGFloat = TableLayout.wallRestitution) {
        let path = CGMutablePath()
        path.addLines(between: points)

        let node = SKShapeNode(path: path)
        // M8 art round 1: the rails are painted into the playfield art; this node keeps only the
        // physics (a clear stroke draws nothing).
        node.strokeColor = .clear
        node.lineWidth = 4
        node.lineCap = .round
        node.lineJoin = .round
        node.glowWidth = 0

        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
    }

    private func addPlunger() {
        let size = TableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = TableLayout.plungerRestPosition

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    /// One-way gate across the top of the launch lane.
    private func addGate() {
        let path = CGMutablePath()
        path.addLines(between: [TableLayout.gateLow, TableLayout.gateHigh])
        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        node.lineWidth = 4
        node.lineCap = .round
        node.glowWidth = 2
        let body = SKPhysicsBody(edgeFrom: TableLayout.gateLow, to: TableLayout.gateHigh)
        body.friction = 0.05
        body.restitution = 0.2
        body.collisionBitMask = PhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        gate = node
        setGate(closed: false)
    }

    private func setGate(closed: Bool) {
        gateClosed = closed
        gate?.physicsBody?.categoryBitMask = closed ? PhysicsCategory.wall : PhysicsCategory.none
        gate?.alpha = closed ? 1 : 0.2
    }

    /// Close the gate once the launched ball is fully past it (above it, or out in the playfield).
    private func updateGate() {
        guard !gateClosed, ballLaunched, let ball = servedBall else { return }
        let r = TableLayout.ballRadius
        let p = ball.position
        if p.y > TableLayout.gateHigh.y + r + 2 || p.x < TableLayout.laneWallX - r {
            setGate(closed: true)
        }
    }

    /// Debug-only build tag, so it's clear the phone runs the newest build.
    /// It rides on the camera, so it stays in the bottom-left corner of the screen.
    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: "Lab v5")
        label.fontName = "Menlo-Bold"
        label.fontSize = 12
        label.fontColor = SKColor(white: 1, alpha: 0.85)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        label.numberOfLines = 0                    // M10 v8: the frame-rate line sits above the tag
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

    /// Camera children use screen points, centred on the screen.
    private func placeBuildTag() {
        guard let buildTag else { return }
        buildTag.position = CGPoint(x: -size.width / 2 + 10, y: -size.height / 2 + 10)
        // Frame-rate counter (real time, not game time)
        let t = CACurrentMediaTime()
        let gap = t - fpsLastFrame
        fpsLastFrame = t
        if gap > 0.5 {                             // first frame, or back from pause: start a fresh window
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
        let shown = focusBall
        let layer: String
        switch shown?.layer ?? .floor {
        case .floor: layer = "floor"
        case .rampUp: layer = "ramp up"
        case .rampDown: layer = "wire"
        }
        var speed = 0                              // ball speed, to tune flipper power
        if let v = shown?.physicsBody?.velocity {
            speed = Int(hypot(v.dx, v.dy) / 10) * 10
        }
        let count = balls.count > 1 ? " · \(balls.count) balls" : ""
        let mb = multiballActive ? " · MULTIBALL" : " · locks \(lockedBalls)"
        // Two lines: the frame rate on top, the build tag underneath.
        let fps = fpsShown > 0 ? "\(fpsShown) fps · low \(fpsLow) · worst \(fpsWorstShown) ms\n" : ""
        var text = "\(fps)Lab v8 \(effectiveCameraMode.tag) · \(layer) · \(speed)\(count)\(mb)"
        #if DEBUG
        if let lab = playLab { text += "\n" + lab.progressText }
        #endif
        if buildTag.text != text {
            buildTag.text = text
            // Box behind the text, 4 pt of padding (label frames are in the camera's screen points)
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows and the debug tag describes: the lowest one in play,
    /// since that's the one about to need the flippers. (The multiball camera comes in round 3.)
    private var focusBall: Ball? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    /// Checks one ball's ramp switches against how it moved this frame.
    /// Runs after physics (not in a contact callback), so changing the mask is safe.
    private func updateRampLayer(_ ball: Ball) {
        let p = ball.position
        let p0 = ball.previousPosition
        ball.previousPosition = p

        if ball.layer == .floor {
            // On the floor: did the ball just go in at either ramp's mouth?
            if let ramp = ramps.first(where: { $0.entrySwitch.crossing(from: p0, to: p) == .forward }) {
                ball.activeRamp = ramp
                ball.setLayer(.rampUp)
            } else {
                // Orbit: armed going up the lane, made coming round the top (M7 v2).
                switch TableLayout.orbitArmSwitch.crossing(from: p0, to: p) {
                case .forward: ball.orbitArmed = true
                case .backward: ball.orbitArmed = false      // fell back down the lane
                case .none: break
                }
                if ball.orbitArmed, TableLayout.orbitMadeSwitch.crossing(from: p0, to: p) == .forward {
                    ball.orbitArmed = false
                    orbitMade(at: gameTime)
                    labEvent("orbit")
                }
                // Right outlane (M7 v6): this ball is on its way down the right outlane to the drain.
                if TableLayout.rightOutlaneSwitch.crossing(from: p0, to: p) == .forward {
                    ball.inRightOutlane = true
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
                ball.setLayer(.floor)                  // didn't make it: rolled back out the mouth
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.rampDown)
                labEvent(ramp === tractorBeam ? "rightRamp" : "leftRamp")
                let combo = shotMade(Points.rampShot, at: gameTime)
                rampsThisBall += 1
                rampHaptic.impactOccurred()
                fx(p, Effects.alienGreen, count: 14, speed: 200, life: 0.4)
                sfx(.ramp)
                if abductionMultiball, ramp === tractorBeam {
                    award(Points.abductionJackpot)       // the Tractor Beam is the jackpot during multiball
                    bigHaptic.impactOccurred()
                    fx(p, Effects.gold, count: 40, speed: 340, life: 0.8, size: 0.4)
                    cameraRig.shake(strength: 8, duration: 0.45)
                    sfx(.jackpot)
                    lamps.play(.flash, at: gameTime)
                    showBanner("JACKPOT")
                } else if combo {
                    showBanner("COMBO")
                }
                handle(campaign.shotMade(ramp === tractorBeam ? .rightRamp : .leftRamp, canStart: false))
            }
        case .rampDown:
            if ramp.exitSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.floor)                  // off the wire into an inlane
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.rampUp)                 // slid back over the top turn
            }
        }

        // Safety net: a ramp ball that is nowhere near the channel goes back to the floor.
        if ball.layer != .floor,
           ramp.distanceToCenterline(p) > ramp.maxHalfWidth + TableLayout.ballRadius + 12 {
            ball.setLayer(.floor)
        }
    }

    /// Catches a floor ball that rolls into an empty scoop, holds it, then kicks it out.
    /// Runs in update (moving and freezing a ball is structural, never done in a contact).
    private func updateScoops(_ now: TimeInterval) {
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if let scoop = ball.heldIn {
                ball.position = scoop.position
                body.velocity = .zero
                body.angularVelocity = 0
                if now >= ball.releaseAt {
                    ball.heldIn = nil
                    ball.scoopIgnoreUntil = now + TableLayout.scoopRecapture
                    body.affectedByGravity = true
                    // M7 round 3: a ball caught while Wave 3 was on saves a cow and never locks.
                    let canLock = scoop === abductionScoop && !multiballActive && !ball.lockBlocked
                    ball.lockBlocked = false
                    if canLock, lockedBalls < TableLayout.locksForMultiball - 1 {
                        lockBall(ball, at: now)          // abducted: locked, and a new ball is served
                    } else {
                        if canLock {
                            startMultiball(at: now)      // the third abduction releases the others
                        }
                        body.velocity = scoop.ejectVelocity
                        sfx(.scoopOut)
                    }
                }
                continue
            }
            guard ball.isOnFloor, now >= ball.scoopIgnoreUntil else { continue }
            // Where the ball was a step ago (its velocity × the last step), so a fast ball can't
            // jump over the hole between frames (M10 v4).
            let v = body.velocity
            let from = CGPoint(x: ball.position.x - v.dx * lastStep, y: ball.position.y - v.dy * lastStep)
            guard let scoop = scoops.first(where: { candidate in
                candidate.catches(from: from, to: ball.position) && !isHolding(candidate)
            }) else { continue }
            ball.heldIn = scoop
            ball.releaseAt = now + TableLayout.scoopHold
            labEvent(scoop === abductionScoop ? "abduction" : "hangar")
            body.affectedByGravity = false
            body.velocity = .zero
            award(scoop.points)
            fx(scoop.position, scoop === abductionScoop ? Effects.alienGreen : Effects.orange, count: 20, speed: 180, life: 0.5)
            sfx(.scoopIn)
            if scoop === abductionScoop { ball.lockBlocked = campaign.abductorsActive }
            handle(campaign.shotMade(scoop === abductionScoop ? .abduction : .hangar,
                                     canStart: !multiballActive))
            scoop.flash()
            rampHaptic.impactOccurred(intensity: 0.8)
        }
    }

    // MARK: - Ball lock + multiball

    /// The Abduction scoop takes the ball away: it floats up and fades, a lock lamp lights,
    /// and (since it was the only ball) a new one is served to the plunger.
    private func lockBall(_ ball: Ball, at now: TimeInterval) {
        lockedBalls += 1
        award(Points.ballLocked)
        fx(TableLayout.abductionCenter, Effects.beamWhite, count: 24, speed: 160, life: 0.6)
        sfx(.lock)
        showBanner("BALL LOCKED")
        bigHaptic.impactOccurred()
        abductionScoop?.flash()

        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
        ball.physicsBody = nil
        ball.run(.sequence([
            .group([
                .moveBy(x: 0, y: 40, duration: 0.5),
                .scale(to: 0.3, duration: 0.5),
                .fadeOut(withDuration: 0.5),
            ]),
            .removeFromParent(),
        ]))
        if balls.isEmpty {
            nextBallAt = now + TableLayout.lockServeDelay
        }
    }

    /// Third abduction: this ball kicks out and the locked balls follow it out of the scoop.
    private func startMultiball(at now: TimeInterval) {
        multiballActive = true
        releaseScoop = abductionScoop
        pendingReleases = lockedBalls
        lockedBalls = 0
        nextReleaseAt = now + TableLayout.multiballReleaseInterval
        award(Points.multiballStart)
        cameraRig.shake(strength: 6, duration: 0.4)
        sfx(.multiball)
        showBanner("MULTIBALL")
        lamps.play(.sweep, at: now)
        bigHaptic.impactOccurred()
    }

    /// The Mothership finale (M7 round 4): a second ball comes out of the Hangar, and for the
    /// first seconds any drained ball comes back out of it too.
    private func startMothership(at now: TimeInterval) {
        multiballActive = true
        mothershipMultiball = true
        releaseScoop = scoops.first                       // the Hangar
        pendingReleases += TableLayout.mothershipExtraBalls
        nextReleaseAt = now + TableLayout.multiballReleaseInterval
        multiballSaveUntil = now + TableLayout.mothershipBallSaveSeconds
    }

    /// Releases balls one at a time from the release scoop, and ends multiball when one ball
    /// is left. A Mothership that isn't destroyed by then escapes.
    private func updateMultiball(_ now: TimeInterval) {
        guard multiballActive else { return }
        if pendingReleases > 0, now >= nextReleaseAt, let scoop = releaseScoop ?? abductionScoop, !isHolding(scoop) {
            let ball = Ball(at: scoop.position)
            ball.scoopIgnoreUntil = now + TableLayout.scoopRecapture
            addChild(ball)
            balls.append(ball)
            ball.physicsBody?.velocity = scoop.ejectVelocity
            scoop.flash()
            pendingReleases -= 1
            nextReleaseAt = now + TableLayout.multiballReleaseInterval
        }
        if pendingReleases == 0, balls.count <= 1 {
            multiballActive = false
            multiballSaveUntil = 0
            if mothershipMultiball {
                mothershipMultiball = false
                handle(campaign.mothershipEscaped())     // .none if it was destroyed
            }
        }
    }

    /// A short dip in the table's lighting when a ball is lost.
    private func dimTable() {
        dimmer.removeAllActions()
        dimmer.run(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.08),
            .wait(forDuration: 0.35),
            .fadeAlpha(to: 0, duration: 0.45),
        ]))
    }

    /// Whether some ball is already sitting in this scoop.
    private func isHolding(_ scoop: Scoop) -> Bool {
        balls.contains(where: { $0.heldIn === scoop })
    }

    /// Drops targets that were hit this frame; when the whole bank is down, award the bonus,
    /// light the kickback and raise the bank again after a moment.
    private func updateDropTargets(_ now: TimeInterval) {
        if !pendingDrops.isEmpty {
            pendingDrops.forEach { $0.drop() }
            pendingDrops.removeAll()
            if bankResetAt == nil, dropTargets.allSatisfy({ $0.isDown }) {
                award(Points.fighterBank)
                setKickback(lit: true)
                showBanner("KICKBACK LIT")
                handle(campaign.fighterBankCompleted())   // Wave 2: on to the Defense Cannon
                rampHaptic.impactOccurred()
                for t in dropTargets { fx(t.position, Effects.fighterRed, count: 24, speed: 260, life: 0.6) }
                cameraRig.shake(strength: 6, duration: 0.4)
                sfx(.bank)
                bankResetAt = now + TableLayout.dropTargetResetDelay
            }
        }
        if let due = bankResetAt, now >= due {
            bankResetAt = nil
            dropTargets.forEach { $0.raise() }
        }
    }

    /// Puts a new ball on the plunger and opens the launch gate for it.
    private func placeBallOnPlunger() {
        setGate(closed: false)
        ballLaunched = false
        wasOnPlunger = false
        launchedAt = nil
        if !rollovers.isEmpty {
            setSkillLane(Int.random(in: 0..<rollovers.count))   // skill shot: plunge into the ringed lane
        }
        let r = TableLayout.ballRadius
        let ball = Ball(at: CGPoint(x: TableLayout.laneCenterX, y: TableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        servedBall = ball
    }

    private func removeBall(_ ball: Ball) {
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
    }

    private func removeAllBalls() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        servedBall = nil
    }

    /// True while this ball is sitting in the plunger lane waiting to launch.
    private func isOnPlunger(_ ball: Ball) -> Bool {
        ball.position.x > TableLayout.laneWallX
            && ball.position.y < TableLayout.plungerRestTop + TableLayout.ballRadius * 3
    }

    /// The ball waiting on the plunger, if any.
    private var plungerBall: Ball? {
        balls.first(where: { isOnPlunger($0) })
    }

    private var isBallOnPlunger: Bool { plungerBall != nil }

    func newGame() {
        fpsLow = 0                                 // the frame-rate counter's "low" is per game
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game (or Menu) stops the Shot Lab
        if !playLabStarting { stopPlayLab(saving: true) }   // and the Play Lab, unless it's starting its next game
        #endif
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        removeAllBalls()
        nextBallAt = nil
        plunger.position = TableLayout.plungerRestPosition
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        pendingDrops.removeAll()
        bankResetAt = nil
        dropTargets.forEach { $0.raise() }
        setKickback(lit: false)                  // a new game earns its kickback from the fighter bank
        lockedBalls = 0
        multiballActive = false
        mothershipMultiball = false
        multiballSaveUntil = 0
        releaseScoop = nil
        pendingReleases = 0
        shipsDown = 0
        shipsThisBall = 0
        rampsThisBall = 0
        bonusStart = nil
        shieldsUsed = false
        lastShotAt = nil
        bannerClearAt = nil
        outlaneSaveLit = false
        campaign.reset()                        // the campaign restarts at Wave 1 every game
        invaders.reset()
        game.reset()
        placeBallOnPlunger()
        refreshCamera()
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

    /// Bottom-right of the screen, where the plunger sits in both camera modes.
    private func isInPlungerZone(_ p: CGPoint, of view: UIView) -> Bool {
        let b = view.bounds
        return p.x > b.width * TableLayout.plungerZoneMinX && p.y > b.height * TableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches where activeTouches[touch] == .plunger {
            // Screen points dragged down → world points at the current zoom, so the plunger tracks the finger.
            let dragged = (touch.location(in: view).y - plungerStartY) * cameraRig.node.yScale
            plungerPull = min(max(dragged, 0), TableLayout.plungerMaxPull)
            plunger.position.y = TableLayout.plungerRestPosition.y - plungerPull
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
        if shotLab != nil { return }               // the Shot Lab robot is flipping
        #endif
        var left = activeTouches.values.contains(.left) || padLeft
        var right = activeTouches.values.contains(.right) || padRight
        #if DEBUG
        left = left || robotLeft
        right = right || robotRight
        #endif
        // Lane change: each new flipper press shifts the lit U-F-O lanes that way.
        if left && !leftFlipper.isPressed { rotateLanes(by: -1); sfx(.flipper) }
        if right && !rightFlipper.isPressed { rotateLanes(by: 1); sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
        upperFlipper?.isPressed = right
    }

    /// Shifts which lanes are lit: -1 = one lane left, +1 = one lane right (wrapping).
    private func rotateLanes(by step: Int) {
        guard lanesResetAt == nil, !rollovers.isEmpty else { return }
        let lit = rollovers.map { $0.isLit }
        let n = lit.count
        for (i, lane) in rollovers.enumerated() {
            lane.isLit = lit[((i - step) % n + n) % n]
        }
    }

    private func rollOver(_ lane: Rollover, at now: TimeInterval) {
        // Skill shot: the first lane after launch decides it, hit or miss.
        if let skill = skillLane, ballLaunched {
            let hit = rollovers.indices.contains(skill) && rollovers[skill] === lane
            setSkillLane(nil)
            if hit {
                game.add(Points.skillShot)
                bigHaptic.impactOccurred()
                fx(lane.position, Effects.gold, count: 30, speed: 260, life: 0.7, size: 0.35)
                sfx(.skillShot)
                cameraRig.shake(strength: 4, duration: 0.3)
                showBanner("SKILL SHOT")
            }
        }
        guard lanesResetAt == nil else { return }   // lanes are blinking "complete"
        if lane.isLit {
            award(Points.laneRepeat)
            return
        }
        lane.isLit = true
        award(Points.laneLit)
        sfx(.rollover)
        if rollovers.allSatisfy({ $0.isLit }) {
            // All three lit: blink, clear, and raise the multiplier (max 5x).
            rampHaptic.impactOccurred()
            lanesResetAt = now + 0.6
            if game.raiseMultiplier() {
                showBanner("\(game.multiplier)X")
                sfx(.multiplier)
            }
            handle(campaign.lanesCompleted())        // also lights the Hangar for the next wave
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

    /// Drops every held touch: flippers fall, the plunger returns without firing.
    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        padPullByA = false
        plungerPull = 0
        plunger?.position = TableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    private func releasePlunger() {
        let maxPull = TableLayout.plungerMaxPull
        let power = plungerPull < 4 ? TableLayout.tapLaunchPower : plungerPull / maxPull

        if let body = plungerBall?.physicsBody {
            let speed = TableLayout.minLaunchSpeed
                + power * (TableLayout.maxLaunchSpeed - TableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
        }
        plunger.run(.move(to: TableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    /// Game controller, every frame of play (Pinball Lab, as on Table 03): shoulders/triggers flip, A held or the
    /// right stick pulled down works the plunger (released = launch, with the furthest pull reached). Touches keep working.
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
            plungerPull = pull * TableLayout.plungerMaxPull
            plunger.position.y = TableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * TableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = TableLayout.plungerRestPosition
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
        if shotLab != nil {                     // Shot Lab: the robot's frame instead of a game frame
            updateShotLab(CGFloat(step), now: now)
            return
        }
        #endif
        if isAttractMode {                      // menu: only the lamps run
            lamps.update(time: now)
            return
        }

        // Drive the flippers
        let dt = CGFloat(step)
        lastStep = dt
        updateGamepad()
        #if DEBUG
        updatePlayLab(now)
        #endif
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        upperFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        updateKickback()
        updateLanes(gameTime)
        updateDiverter()
        updateScoops(gameTime)
        updateMultiball(gameTime)
        updateDropTargets(gameTime)
        updateRules(gameTime)
        updateBonus(gameTime)
        handle(campaign.tick(step, active: ballLaunched && launchedAt != nil && !balls.isEmpty))
        invaders.sync(with: campaign)
        updateLampStates()
        lamps.update(time: gameTime)

        // Launch = the frame the served ball leaves the plunger area. Starts the Shields Up
        // and skill-shot clocks.
        var onPlunger = false
        if let served = servedBall { onPlunger = isOnPlunger(served) }
        if wasOnPlunger && !onPlunger && servedBall != nil {
            ballLaunched = true
            launchedAt = now
            sfx(.launch)
        }
        wasOnPlunger = onPlunger
        updateGate()

        // Drain check: remove every ball that has gone off the bottom. The player only loses
        // a ball when the last one in play is gone.
        let drained = balls.filter { $0.position.y < -TableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            let rightOutlane = drained.contains { $0.inRightOutlane }
            drained.forEach { removeBall($0) }
            if multiballActive, now < multiballSaveUntil {
                // Mothership ball save: each drained ball comes back out of the Hangar.
                if pendingReleases == 0 { nextReleaseAt = now + 0.5 }
                pendingReleases += drained.count
                showBanner("BALL SAVED"); sfx(.ballSave)
            }
            if balls.isEmpty, pendingReleases == 0 {
                setSkillLane(nil)
                lastShotAt = nil
                if !shieldsUpNow, outlaneSaveLit, rightOutlane {
                    // Right outlane save (M7 v5): used up; the ball comes back, nothing lost.
                    outlaneSaveLit = false
                    game.ballSaved()
                    showBanner("OUTLANE SAVE"); sfx(.ballSave)
                    bigHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else if shieldsUpNow {
                    // Shields Up: this ball comes back once, nothing lost.
                    shieldsUsed = true
                    game.ballSaved()
                    showBanner("BALL SAVED"); sfx(.ballSave)
                    bigHaptic.impactOccurred()
                    nextBallAt = now + 0.8
                } else {
                    shieldsUsed = false              // the next ball gets its own save
                    outlaneSaveLit = false           // the outlane save lasts for the ball it was earned on
                    dimTable()
                    startBonus(at: now)              // the ball is lost once the bonus has counted
                    cameraRig.shake(strength: 4, duration: 0.3)
                    sfx(.drain)
                }
            }
        }

        // Short pause, then serve the next ball
        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            placeBallOnPlunger()
        }

        #if DEBUG
        checkPlayLabGame(now)
        #endif

        // Keep the HUD hint in sync (only write when it changes)
        let waiting = isBallOnPlunger
        if game.ballOnPlunger != waiting {
            game.ballOnPlunger = waiting
        }
    }

    override func didSimulatePhysics() {
        for ball in balls {
            updateRampLayer(ball)
            guard let body = ball.physicsBody else { continue }
            // Lab v7: the flip assist (as on Monsoon and Lamplight), so a flip gives a floor ball its full speed at 60 Hz too.
            if ball.isOnFloor, ball.heldIn == nil {
                let r = TableLayout.ballRadius
                leftFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
                rightFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
                upperFlipper.flipAssist(body, ballAt: ball.position, ballRadius: r)
            }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            let maxSpeed = ball.layer == .rampDown ? TableLayout.rampReturnMaxSpeed : TableLayout.maxBallSpeed
            if speed > maxSpeed {
                let scale = maxSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            ball.updateLook()                            // M8: highlight + shadow stay put as it rolls
        }
    }

    /// The camera moves last, after physics, so it frames where the ball is this frame.
    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: lastStep)
        tableLabels.fit(cameraScale: cameraRig.node.xScale)
        dimmer.size = size
        placeBuildTag()
    }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        if a.categoryBitMask == PhysicsCategory.ball {
            ballBody = a; other = b
        } else if b.categoryBitMask == PhysicsCategory.ball {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? Ball, ballNode.isOnFloor,
              let node = other.node else { return }

        switch other.categoryBitMask {
        case PhysicsCategory.bumper:
            if let bumper = node as? Bumper,
               bumper.hit(ball: ballBody, ballPosition: ballNode.position, at: gameTime) {
                award(Points.bumper)
                hitHaptic.impactOccurred()
                let mid = CGPoint(x: (ballNode.position.x + bumper.position.x) / 2, y: (ballNode.position.y + bumper.position.y) / 2)
                fx(mid, Effects.gold, count: 12, speed: 200, life: 0.3)
                cameraRig.shake(strength: 2, duration: 0.15)
                sfx(.bumper)
                if let index = bumpers.firstIndex(where: { $0 === bumper }) {
                    handle(campaign.bumperHit(index))     // Mothership shields (M7 round 4)
                }
                labEvent("bumper")
            }

        case PhysicsCategory.rollover:
            if let lane = node as? Rollover {
                rollOver(lane, at: gameTime)
                labEvent("lane")
            }

        case PhysicsCategory.target:
            if let target = node as? DropTarget, target.registerHit() {
                award(Points.dropTarget)
                addShipDown()
                fx(target.position, Effects.fighterRed, count: 16, speed: 220, life: 0.4)
                cameraRig.shake(strength: 2.5, duration: 0.2)
                sfx(.dropTarget)
                pendingDrops.append(target)
                labEvent("fighter")
                hitHaptic.impactOccurred(intensity: 0.7)
            }

        case PhysicsCategory.slingshot:
            // The kicking face is a child of the Slingshot node.
            if let sling = node.parent as? Slingshot, sling.hit(ball: ballBody, at: gameTime) {
                award(Points.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                fx(ballNode.position, Effects.orange, count: 8, speed: 160, life: 0.25, size: 0.22)
                sfx(.sling)
                labEvent("sling")
            }
        default:
            break
        }
    }
}

extension TableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        // SpriteKit calls this on the main thread during the frame.
        MainActor.assumeIsolated {
            handleContact(contact)
        }
    }
}

#if DEBUG
// MARK: - Shot Lab host (M10 v12)

extension TableScene: ShotLabHost {
    var shotLabTableName: String { "Grey Invasion" }

    /// Left and right flippers. The cradle point is just above each flipper held up (30° above
    /// horizontal), 40 pt out from the pivot; the ball rolls back into the crook and settles.
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = TableLayout.flipperTravel - TableLayout.flipperRestAngle      // 30° above horizontal
        let along: CGFloat = 40, above: CGFloat = 14
        let l = TableLayout.leftFlipperPivot
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: TableLayout.mirrorSum - left.x, y: left.y)
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left),
                ShotLab.FlipperSpec(name: "right", pivot: TableLayout.rightFlipperPivot, cradle: right)]
    }

    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        if index == 0 {
            leftFlipper.isPressed = pressed
        } else {
            rightFlipper.isPressed = pressed
            upperFlipper?.isPressed = pressed                  // the upper flipper is on the right button
        }
    }

    func shotLabPlaceBall(at point: CGPoint) {
        let ball = Ball(at: point)
        addChild(ball)
        balls.append(ball)
    }

    func shotLabResetTable() {
        removeAllBalls()
        pendingReleases = 0
        multiballActive = false
        mothershipMultiball = false
        nextBallAt = nil
        pendingDrops.removeAll()
        bankResetAt = nil
        dropTargets.forEach { $0.raise() }
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        setKickback(lit: false)
    }

    /// Just below the Hangar's catch circle (v4: where do near misses pass?).
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "hangar", y: TableLayout.hangarCenter.y - TableLayout.scoopCaptureRadius - 2)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }
}
#endif

// MARK: - Play Lab host (debug builds)

#if DEBUG
extension TableScene: PlayLabHost {
    var playLabTableName: String { shotLabTableName }
    var playLabBallRadius: CGFloat { TableLayout.ballRadius }
    var playLabVariantCount: Int { 1 }

    /// The invasion as the How to Play tells it: light the Hangar, three waves, the Mothership; plus the side goals.
    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "hangarLit", text: "Light the Hangar (all three U-F-O lanes, or 3 ramps)"),
         PlayObjective(name: "wave1", text: "Start Wave 1 (shoot the lit Hangar)"),
         PlayObjective(name: "wave1Cleared", text: "Clear Wave 1 · Scout Saucers (2 lit shots in 30 s)"),
         PlayObjective(name: "wave2Cleared", text: "Clear Wave 2 · Fighter Squadron (the bank, then the Defense Cannon)"),
         PlayObjective(name: "wave3Cleared", text: "Clear Wave 3 · Abductors (save 3 cows: the Abduction scoop or the right ramp)"),
         PlayObjective(name: "mothership", text: "Start the Mothership finale"),
         PlayObjective(name: "coreOpen", text: "Knock out all three shield generators"),
         PlayObjective(name: "coreHit", text: "Hit the core (a ramp while it's open)"),
         PlayObjective(name: "mothershipDestroyed", text: "Destroy the Mothership (3 core hits)"),
         PlayObjective(name: "extraBall", text: "Collect the Extra Ball at the Hangar"),
         PlayObjective(name: "lock", text: "Lock a ball in the Abduction scoop"),
         PlayObjective(name: "multiball", text: "Start Abduction multiball (3 locks)"),
         PlayObjective(name: "jackpot", text: "Tractor Beam jackpot in multiball"),
         PlayObjective(name: "kickbackLit", text: "Light the kickback (the whole fighter bank)"),
         PlayObjective(name: "skillShot", text: "Plunge into the ringed U-F-O lane"),
         PlayObjective(name: "combo", text: "Two ramps or orbits within 3 s")]
    }

    /// Flip delays = the middle of each shot's window in the Shot Lab. Lab v8: the flip assist is 60 Hz only, so the
    /// 120 Hz delays are back to the pre-assist run (Shot Lab run 5, 2026-10-11 16-07, Hangar at y 650) and the 60 Hz ones
    /// are from the post-assist run (shotlab-grey-invasion-2026-10-22T23-38-45Z). The right flipper's abduction stays out
    /// at both rates (a 2-trial band on a same-side shot: 7/75 and 5/49 in Play Lab runs).
    var playLabFlippers: [PlayRobotFlipper] {
        let specs = shotLabFlippers
        let rest = TableLayout.flipperRestAngle
        // shots60: the 60 Hz pass's windows (16.7 ms steps, same run).
        return [PlayRobotFlipper(name: "left", pivot: specs[0].pivot, length: TableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: false, cradle: specs[0].cradle, rightButton: false, upper: false,
                                 shots: [("hangar", 0.301), ("rightRamp", 0.447), ("abduction", 0.503), ("fighter", 0.528)],
                                 shots60: [("hangar", 0.376), ("rightRamp", 0.432), ("abduction", 0.458), ("fighter", 0.502)]),
                PlayRobotFlipper(name: "right", pivot: specs[1].pivot, length: TableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: specs[1].cradle, rightButton: true, upper: false,
                                 shots: [("hangar", 0.300), ("leftRamp", 0.446), ("orbit", 0.490)],
                                 shots60: [("hangar", 0.369), ("leftRamp", 0.416), ("orbit", 0.484)])]
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
            multiballActive = false
            mothershipMultiball = false
        }
        return ["wavesCleared": campaign.wavesCleared, "invasion": campaign.invasion, "locks": lockedBalls]
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
            PlayRobotView.Ball(position: b.position, velocity: b.physicsBody?.velocity ?? .zero, isUpper: b.layer != .floor,
                               isHeld: b.heldIn != nil, onPlunger: isOnPlunger(b), id: ObjectIdentifier(b).hashValue)
        }, wanted: robotWanted(), lanes: lanesResetAt == nil && !rollovers.isEmpty
            ? PlayRobotView.Lanes(xs: rollovers.map { $0.position.x }, y: rollovers[0].position.y, lit: rollovers.map { $0.isLit })
            : nil)
        guard let cmd = lab.frame(view) else { return }
        if cmd.left != robotLeft || cmd.right != robotRight {
            robotLeft = cmd.left
            robotRight = cmd.right
            updateFlippers()
        }
        if let power = cmd.plunge, isBallOnPlunger {
            plungerPull = power * TableLayout.plungerMaxPull
            releasePlunger()
        }
    }

    /// The shots the table wants, most wanted first: what the arrows say (fast-blink before blink), then the
    /// shots worth taking anyway.
    private func robotWanted() -> [String] {
        let arrows: [(lamp: String, shot: String)] = [("arrow.hangar", "hangar"), ("arrow.rightRamp", "rightRamp"),
                                                      ("arrow.leftRamp", "leftRamp"), ("arrow.orbit", "orbit"),
                                                      ("arrow.abduction", "abduction"), ("arrow.bank", "fighter")]
        var w: [String] = []
        w += arrows.filter { lamps.state(of: $0.lamp) == .fastBlink }.map(\.shot)
        w += arrows.filter { lamps.state(of: $0.lamp) == .blink }.map(\.shot)
        w += ["hangar", "rightRamp", "leftRamp", "orbit", "abduction", "fighter"]
        return w
    }

    /// Banners double as the objective record: the first of each per game is what the report shows.
    fileprivate func labObjective(forBanner text: String) {
        guard let lab = playLab else { return }
        let name: String?
        switch text {
        case "HANGAR LIT": name = "hangarLit"
        case "WAVE 1: SCOUT SAUCERS": name = "wave1"
        case "WAVE 1 CLEARED": name = "wave1Cleared"
        case "WAVE 2 CLEARED": name = "wave2Cleared"
        case "WAVE 3 CLEARED": name = "wave3Cleared"
        case "MOTHERSHIP!": name = "mothership"
        case "CORE OPEN! SHOOT A RAMP": name = "coreOpen"
        case "EXTRA BALL": name = "extraBall"
        case "BALL LOCKED": name = "lock"
        case "MULTIBALL": name = "multiball"
        case "JACKPOT": name = "jackpot"
        case "KICKBACK LIT": name = "kickbackLit"
        case "SKILL SHOT": name = "skillShot"
        case "COMBO": name = "combo"
        default:
            if text.hasPrefix("CORE HIT!") { name = "coreHit" }
            else if text.hasPrefix("MOTHERSHIP DESTROYED!") { name = "mothershipDestroyed" }
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
        lab.endGame(score: game.score, ballsPlayed: GameState.ballsPerGame - game.ballsLeft + (over ? 0 : 1),
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
