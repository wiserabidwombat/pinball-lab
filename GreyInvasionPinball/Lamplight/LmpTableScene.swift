// Pinball Lab Table 05 (The Lamplight): the table scene. Milestone 1 = grey box of the NEW lower table (Aaron chose
// "center post + one outlane"): flippers 11 pt farther apart with a rubber center post between their tips, the left
// side closed (a deflector off the left wall feeds the left inlane), one outlane on the right; slingshots, plunger,
// the one-way launch gate flap, the three camera modes, 3 balls.
// Milestone 2: the upper table in grey box: the loop pair (with combos), the upper flipper low on the left (removed in M6 v6), the
// bookshelf bank and the fireplace hole behind it, the kettle scoop and its spinner, the mail slot (soft shots only),
// three teacup bumpers. Placeholder points and banners until the rules milestone.
// Milestone 3 round 1: the loft (a raised mini-playfield with its own flipper on the right button and the window
// seat), the ramp up to it from the left flipper, and the chute that drops a drained loft ball into the left lane.
// Round 2: the dumbwaiter from the kettle and the full plunge through the hatch.
// Milestone 4: the cat on her shelf at the top right: walks, naps, swats balls back down, purrs when hit.
// Milestone 5: the Shot Lab robot (debug builds) from the left, right, upper and loft flippers.
// Milestone 6 round 1: finds. Knocking down the whole bookshelf, the fireplace, the window seat and waking the cat each
// find a book (LmpShop: rarity, pity, saved at once); a loop combo or a full plunge makes it a lucky evening.
// Round 3: the cat roams between the perches you own; each perch changes its shot a little (LmpPerch.effect).
// Milestone 7 round 1: lamps. Arrows light the shots that are worth something right now (the open fireplace, the
// kettle when the dumbwaiter is lit, the other loop during a combo, the ramp on a lucky evening, the window seat when
// the cat's there); the lucky star; six shop lamps that come on through the evening as the table warms and dims.
// Milestone 8 round 1: requests. A regular comes in (LmpRegulars) and asks for a book, a cup of tea, a favor or a chat;
// the arrows fast-blink on the shots it needs, in order. Finishing pays points, a tip and friendship (saved).
// Built from MonTableScene.swift's code, trimmed. Monsoon's sounds stand in until the table's own (juice milestone).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class LmpTableScene: SKScene {
    private enum Control { case left, right, plunger }

    private let game: LmpGameState
    private let settings: GameSettings
    private let cameraRig = LmpCameraRig()
    private let sound = MonSoundPlayer()
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

    private var balls: [LmpBall] = []
    private var servedBall: LmpBall?
    private var slingshots: [LmpSlingshot] = []
    private var leftFlipper: LmpFlipper!
    private var rightFlipper: LmpFlipper!
    private var plunger: SKShapeNode!
    private var centerPost: SKShapeNode?
    private var centerPostHitAt: TimeInterval = -1
    private var bumpers: [LmpBumper] = []
    private var bookTargets: [LmpDropTarget] = []
    private var pendingDrops: [LmpDropTarget] = []
    private var bankResetAt: TimeInterval?
    private var scoops: [LmpScoop] = []
    private var fireplace: LmpScoop!
    private var kettle: LmpScoop!
    private var mailSlot: LmpScoop!
    private var spinner: LmpSpinner?
    private var lastSpinTickAt: TimeInterval = 0
    private var loftFlipper: LmpFlipper!
    private var cat: LmpCat!
    private var catRoamAt: TimeInterval = 0
    private let lamps = LmpLampController()
    /// When tonight's first ball was served (for the evening's lamps and dimming).
    private var eveningStart: TimeInterval = 0
    private var eveningDim: SKSpriteNode?
    /// M8: the request in progress, and when the next regular comes in.
    private var request: LmpRequest?
    private var lastRegular: LmpRegular?
    private var nextRequestAt: TimeInterval?
    private var visitorClearAt: TimeInterval?
    /// M8 round 2: the Evening Rush. Balls still to be plunged in for you, when the next goes, and the ball save
    /// (infinite until the first Rush ball is in).
    private var rushActive = false
    private var rushBallsToServe = 0
    private var rushLaunchAt: TimeInterval = 0
    private var rushSaveUntil: TimeInterval = 0
    #if DEBUG
    /// Milestone 5: the Shot Lab robot (debug builds) and its clock.
    private var shotLab: ShotLab?
    private var shotLabTime: TimeInterval = 0
    #endif
    private var windowSeat: LmpScoop!
    /// M3 round 2: the kettle sends every other ball up the dumbwaiter (the rules milestone will decide when it's lit).
    private var dumbwaiterLit = true
    private var lastLoopAt: TimeInterval = -100
    private var loopCombo = 0
    private var launchGateFlap: SKNode?
    private var launchGateClosedAngle: CGFloat = 0
    private var isBuilt = false
    private let hitHaptic = Haptic(style: .medium)

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
    private var bannerClearAt: TimeInterval?
    private var findToastClearAt: TimeInterval?

    /// The menu: physics stopped, whole-table camera, touches ignored.
    var isAttractMode = false {
        didSet {
            guard isAttractMode != oldValue else { return }
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode {
                releaseAllControls()
                lamps.play(.attract, at: gameTime)     // M7: the menu's light chase
                eveningDim?.alpha = 0
            }
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

    // Grey-box colours: warm lamp-brass lines on dark wood.
    static let wallColor = SKColor(red: 0.90, green: 0.76, blue: 0.52, alpha: 1)
    static let floorColor = SKColor(red: 0.14, green: 0.11, blue: 0.09, alpha: 1)
    static let closedColor = SKColor(red: 0.09, green: 0.07, blue: 0.06, alpha: 1)
    static let rubberColor = SKColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)

    init(game: LmpGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: LmpTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: LmpTableLayout.gravity)
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

    private var isLabRunning: Bool {
        #if DEBUG
        return shotLab != nil
        #else
        return false
        #endif
    }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        addFloor()
        addWall(points: LmpTableLayout.outerWall,
                friction: LmpTableLayout.railFriction, restitution: LmpTableLayout.railRestitution)
        addWall(points: LmpTableLayout.leftInlaneWall)
        addWall(points: LmpTableLayout.rightLaneGuide)
        addWall(points: LmpTableLayout.rightOutlaneWall)
        addWall(points: LmpTableLayout.rightApron)

        for s in [LmpTableLayout.leftSling, LmpTableLayout.rightSling] {
            let sling = LmpSlingshot(top: s.top, corner: s.corner, tip: s.tip, artBaked: false,
                                     kickFrom: LmpTableLayout.slingKickFrom, kickTo: LmpTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = LmpFlipper(side: .left, pivot: LmpTableLayout.leftFlipperPivot)
        rightFlipper = LmpFlipper(side: .right, pivot: LmpTableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)

        addCenterPost()
        addPlunger()
        addLaunchGate()
        addUpperTable()
        addLoft()
        addCat()
        addLamps()
    }

    /// Milestone 7: shot arrows, the lucky star, the shop lamps, and the warm dim over the whole table.
    private func addLamps() {
        let warm = SKColor(red: 1.0, green: 0.78, blue: 0.42, alpha: 1)
        for (name, spot) in LmpTableLayout.shotArrows {
            let lamp = LmpLamp(.arrow(length: LmpTableLayout.arrowLength, width: LmpTableLayout.arrowWidth),
                               color: warm, at: spot.0, angle: spot.1)
            if name == "windowSeat" { lamp.zPosition = 18 }          // over the loft's floor
            addChild(lamp)
            lamps.add(lamp, named: name)
        }
        let mail = LmpLamp(.round(radius: LmpTableLayout.mailLampRadius), color: warm,
                           at: LmpTableLayout.mailSlotCenter)
        mail.zPosition = -2                                        // a ring of light round the slot
        addChild(mail)
        lamps.add(mail, named: "mail")
        let lucky = LmpLamp(.star(outer: 11, inner: 5), color: SKColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1),
                            at: LmpTableLayout.luckyLamp)
        addChild(lucky)
        lamps.add(lucky, named: "lucky")
        for (i, p) in LmpTableLayout.shopLamps.enumerated() {
            let lamp = LmpLamp(.round(radius: 7), color: warm, at: p)
            addChild(lamp)
            lamps.add(lamp, named: "shop\(i)")
        }
        let dim = SKSpriteNode(color: SKColor(red: 0.20, green: 0.09, blue: 0.02, alpha: 1),
                               size: CGSize(width: LmpTableLayout.worldSize.width + 400,
                                            height: LmpTableLayout.worldSize.height + 400))
        dim.anchorPoint = .zero
        dim.position = CGPoint(x: -200, y: -200)
        dim.zPosition = 40
        dim.alpha = 0
        addChild(dim)
        eveningDim = dim
        lamps.play(.attract, at: gameTime)
    }

    /// Which lamps are lit, from the table's state (no rules yet: just what's worth shooting right now).
    private func updateLamps(_ now: TimeInterval) {
        let bankDown = bookTargets.allSatisfy { $0.isDown }
        lamps.set("fireplace", bankDown ? .fastBlink : .off)
        lamps.set("kettle", dumbwaiterLit ? .blink : .off)
        let comboOpen = now - lastLoopAt <= LmpTableLayout.loopComboWindow
        lamps.set("leftLoop", comboOpen ? .fastBlink : .off)
        lamps.set("rightLoop", comboOpen ? .fastBlink : .off)
        lamps.set("ramp", game.lucky ? .blink : .off)
        lamps.set("windowSeat", cat.perch == .windowSeat ? .blink : (balls.contains { $0.isUpper } ? .on : .off))
        lamps.set("lucky", game.lucky ? .on : .off)
        lamps.set("mail", .off)
        // M8: the request's next shot fast-blinks.
        if let step = request?.step {
            for name in Self.requestLamps(for: step) { lamps.set(name, .fastBlink) }
        }
        // The evening: one more shop lamp every sixth of an evening, and the warm dim deepening toward closing.
        let evening = max(0, now - eveningStart) / LmpTableLayout.eveningSeconds
        let lit = min(LmpTableLayout.shopLamps.count, 1 + Int(evening * Double(LmpTableLayout.shopLamps.count)))
        for i in 0..<LmpTableLayout.shopLamps.count { lamps.set("shop\(i)", rushActive ? .fastBlink : (i < lit ? .on : .off)) }
        eveningDim?.alpha = LmpTableLayout.eveningDimMax * CGFloat(min(evening, 1))
        lamps.update(time: now)
    }

    /// Milestone 4: the cat and her shelf (the shelf is only drawn; she is the solid part).
    private func addCat() {
        let r = LmpTableLayout.catRadius
        let shelf = SKShapeNode(rect: CGRect(x: LmpTableLayout.catMinX - r * 1.8, y: LmpTableLayout.catShelfY - r - 6,
                                             width: LmpTableLayout.catMaxX - LmpTableLayout.catMinX + r * 3.6,
                                             height: 5), cornerRadius: 2)
        shelf.fillColor = SKColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)
        shelf.strokeColor = .clear
        shelf.zPosition = 11
        addChild(shelf)
        let c = LmpCat(at: LmpTableLayout.catHomeX)
        addChild(c)
        cat = c
    }

    /// Moves the cat, and lets her swat any floor ball that comes within reach while she's awake.
    private func updateCat(_ dt: CGFloat, now: TimeInterval) {
        cat.update(dt: dt, now: now)
        // M6 round 3: now and then she wanders to another perch you own.
        if !isLabRunning, now >= catRoamAt {
            catRoamAt = now + Double.random(in: LmpTableLayout.catRoamSeconds)
            let others = LmpShop.shared.ownedPerches.filter { $0 != cat.perch }
            if let next = others.randomElement() {
                cat.move(to: next)
                game.catPerch = next
                showBanner("THE CAT MOVES \(next.spot.uppercased())")
            }
        }
        for ball in balls where !ball.isUpper && ball.ride == nil && ball.heldIn == nil {
            guard let body = ball.physicsBody, cat.trySwat(ballAt: ball.position, now: now) else { continue }
            let dir: CGFloat = ball.position.x >= cat.position.x ? 1 : -1
            body.velocity = CGVector(dx: dir * LmpTableLayout.catSwatSpeedX, dy: LmpTableLayout.catSwatSpeedY)
            game.add(LmpTableLayout.catSwatPoints)
            showBanner("SWAT!")
            shotEvent("catSwat")
            sfx(.kickback)
            hitHaptic.impactOccurred(intensity: 0.6)
            break
        }
    }

    /// Milestone 3: the loft, its ramp, the chute and the block under it.
    private func addLoft() {
        // The block under the loft (floor layer).
        addWall(points: LmpTableLayout.loftBlock)
        for post in LmpTableLayout.rampMouthPosts { addWall(points: post) }

        // The loft's floor, drawn over the floor layer.
        let floorPath = CGMutablePath()
        floorPath.addLines(between: LmpTableLayout.loftFloor)
        floorPath.closeSubpath()
        let loftFloor = SKShapeNode(path: floorPath)
        loftFloor.fillColor = SKColor(red: 0.30, green: 0.21, blue: 0.14, alpha: 1)
        loftFloor.strokeColor = .clear
        loftFloor.zPosition = 15
        addChild(loftFloor)

        // The ramp: a translucent strip between its rails (floor balls show through underneath).
        let left = LmpTableLayout.rampRail(side: LmpTableLayout.rampHalfWidth)
        let right = LmpTableLayout.rampRail(side: -LmpTableLayout.rampHalfWidth)
        let stripPath = CGMutablePath()
        stripPath.addLines(between: left + right.reversed())
        stripPath.closeSubpath()
        let strip = SKShapeNode(path: stripPath)
        strip.fillColor = SKColor(red: 0.55, green: 0.80, blue: 0.85, alpha: 0.22)
        strip.strokeColor = .clear
        strip.zPosition = 16
        addChild(strip)

        // T5 M5 v6 (Shot Lab run 4: 60 Hz ramp shots got onto the ramp but ran out of speed in the turn, ~590 pt/s
        // at y 1000): the ramp's rails are low-friction rails like the outer wall, so the ball loses less speed
        // pressing the outside rail round the turn.
        for rail in [left, right] {
            addWall(points: rail, friction: LmpTableLayout.railFriction, restitution: LmpTableLayout.railRestitution,
                    category: LmpPhysicsCategory.rampWall, z: 17)
        }
        for wall in LmpTableLayout.loftWalls {
            addWall(points: wall, category: LmpPhysicsCategory.rampWall, z: 17)
        }

        loftFlipper = LmpFlipper(side: .right, pivot: LmpTableLayout.loftFlipperPivot,
                                 length: LmpTableLayout.loftFlipperLength,
                                 pivotRadius: LmpTableLayout.loftFlipperPivotRadius,
                                 tipRadius: LmpTableLayout.loftFlipperTipRadius)
        loftFlipper.zPosition = 20
        loftFlipper.attach(to: self)
        loftFlipper.physicsBody?.categoryBitMask = LmpPhysicsCategory.loftFlipper
        loftFlipper.physicsBody?.collisionBitMask = LmpPhysicsCategory.rampBall

        windowSeat = LmpScoop(at: LmpTableLayout.windowSeatCenter, ejectVelocity: LmpTableLayout.windowSeatEject,
                              points: LmpTableLayout.windowSeatPoints, captureRadius: LmpTableLayout.windowSeatCapture)
        windowSeat.zPosition = 18
        addChild(windowSeat)
        scoops.append(windowSeat)
    }

    /// Milestone 2: the loop pair, the upper flipper, the bookshelf bank and fireplace, the kettle and its spinner,
    /// the mail slot and the bumpers.
    private func addUpperTable() {
        // T5 M5 v4: the orbit lanes' inner walls are rails too (low friction, like the outer wall), so a loop
        // loses less speed rubbing them (Shot Lab: 60 Hz left loops reached y 1000 just short of the speed to go over).
        addWall(points: LmpTableLayout.leftOrbitWall,
                friction: LmpTableLayout.railFriction, restitution: LmpTableLayout.railRestitution)
        addWall(points: LmpTableLayout.rightOrbitWall,
                friction: LmpTableLayout.railFriction, restitution: LmpTableLayout.railRestitution)
        addWall(points: LmpTableLayout.alcoveWall)
        addWall(points: LmpTableLayout.kettleLaneWall)
        addOrbitDeflector()

        for c in LmpTableLayout.bookTargetCenters {
            let t = LmpDropTarget(at: c)
            addChild(t)
            bookTargets.append(t)
        }

        fireplace = LmpScoop(at: LmpTableLayout.fireplaceCenter, ejectVelocity: LmpTableLayout.fireplaceEject,
                             points: LmpTableLayout.fireplacePoints)
        kettle = LmpScoop(at: LmpTableLayout.kettleCenter, ejectVelocity: LmpTableLayout.kettleEject,
                          points: LmpTableLayout.kettlePoints)
        mailSlot = LmpScoop(at: LmpTableLayout.mailSlotCenter, ejectVelocity: LmpTableLayout.mailEject,
                            points: LmpTableLayout.mailPoints, captureRadius: LmpTableLayout.mailCaptureRadius)
        mailSlot.setScale(0.8)
        scoops = [fireplace, kettle, mailSlot]
        scoops.forEach { addChild($0) }

        let line = LmpTableLayout.kettleSpinnerLine
        let sp = LmpSpinner(from: line.a, to: line.b)
        addChild(sp)
        spinner = sp

        for c in LmpTableLayout.bumperCenters {
            let b = LmpBumper(at: c)
            addChild(b)
            bumpers.append(b)
        }
    }

    /// The one-way deflector across the right orbit's mouth: solid per ball (see updateGates), drawn as a thin rail.
    private func addOrbitDeflector() {
        let low = LmpTableLayout.rightDeflectorLow, high = LmpTableLayout.rightDeflectorHigh
        let path = CGMutablePath()
        path.move(to: low)
        path.addLine(to: high)
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.wallColor.withAlphaComponent(0.55)
        node.lineWidth = 2
        node.lineCap = .round
        node.zPosition = -19.5
        let body = SKPhysicsBody(edgeFrom: low, to: high)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = LmpPhysicsCategory.orbitDeflector
        body.collisionBitMask = LmpPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    /// The playfield floor inside the outer wall, and the closed pocket on the left drawn darker.
    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: LmpTableLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)

        let pocketPath = CGMutablePath()
        pocketPath.addLines(between: LmpTableLayout.leftClosedPocket)
        pocketPath.closeSubpath()
        let pocket = SKShapeNode(path: pocketPath)
        pocket.fillColor = Self.closedColor
        pocket.strokeColor = .clear
        pocket.zPosition = -19.8
        addChild(pocket)
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = LmpTableLayout.wallFriction,
                         restitution: CGFloat = LmpTableLayout.wallRestitution,
                         category: UInt32 = LmpPhysicsCategory.wall,
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
        body.categoryBitMask = category
        body.collisionBitMask = category == LmpPhysicsCategory.rampWall ? LmpPhysicsCategory.rampBall
            : LmpPhysicsCategory.ball
        node.physicsBody = body
        if category == LmpPhysicsCategory.rampWall {
            node.strokeColor = SKColor(red: 0.62, green: 0.86, blue: 0.92, alpha: 1)   // grey box: loft and ramp rails
            node.lineWidth = 2.5
        }

        addChild(node)
    }

    /// The rubber center post between the flipper tips. Its own category (`bumper`, so the ball reports a contact)
    /// with a lively rubber bounce; it scores a little and gives a soft knock.
    private func addCenterPost() {
        let r = LmpTableLayout.centerPostRadius
        let post = SKShapeNode(circleOfRadius: r)
        post.fillColor = Self.rubberColor
        post.strokeColor = Self.wallColor
        post.lineWidth = 2
        post.position = LmpTableLayout.centerPost
        post.zPosition = 1
        post.name = "centerPost"
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = LmpTableLayout.centerPostRestitution
        body.friction = 0.2
        body.categoryBitMask = LmpPhysicsCategory.bumper
        body.collisionBitMask = LmpPhysicsCategory.ball
        post.physicsBody = body
        addChild(post)
        centerPost = post
    }

    private func addPlunger() {
        let size = LmpTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = LmpTableLayout.plungerRestPosition

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = LmpPhysicsCategory.wall
        body.collisionBitMask = LmpPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    /// The launch gate across the top of the shooter lane: solid per ball, only for a ball above it moving down
    /// (a plunge going up swings the flap and passes; a ball coming back rolls off it into play).
    private func addLaunchGate() {
        let low = LmpTableLayout.gateLow, high = LmpTableLayout.gateHigh
        let node = SKNode()
        let body = SKPhysicsBody(edgeFrom: low, to: high)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = LmpPhysicsCategory.launchGate
        body.collisionBitMask = LmpPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)

        let flap = SKNode()
        flap.position = high
        flap.zPosition = 2
        let closed = atan2(low.y - high.y, low.x - high.x) + .pi / 2
        let length = hypot(low.x - high.x, low.y - high.y)
        let blade = SKShapeNode(rect: CGRect(x: -2.5, y: -length, width: 5, height: length), cornerRadius: 2)
        blade.fillColor = SKColor(red: 0.85, green: 0.70, blue: 0.42, alpha: 1)
        blade.strokeColor = SKColor(white: 0.25, alpha: 1)
        blade.lineWidth = 1
        flap.addChild(blade)
        let pin = SKShapeNode(circleOfRadius: 4)
        pin.fillColor = SKColor(white: 0.88, alpha: 1)
        pin.strokeColor = SKColor(white: 0.25, alpha: 1)
        pin.lineWidth = 1
        flap.addChild(pin)
        flap.zRotation = closed
        addChild(flap)
        launchGateFlap = flap
        launchGateClosedAngle = closed
    }

    /// The launch gate, per ball: solid for a floor ball above it moving down; a ball crossing it going up swings it.
    private func updateGates() {
        let low = LmpTableLayout.gateLow, high = LmpTableLayout.gateHigh
        let gx = high.x - low.x, gy = high.y - low.y
        for ball in balls {
            let v = ball.physicsBody?.velocity ?? .zero
            let p = ball.position
            let above = gx * (p.y - low.y) - gy * (p.x - low.x) > 0
            ball.setLaunchGateSolid(above && v.dy < 0)
            let wasAbove = gx * (ball.previousPosition.y - low.y) - gy * (ball.previousPosition.x - low.x) > 0
            if !wasAbove, above, v.dy > 0, p.x > low.x, p.x < high.x { swingLaunchGate() }
            // The right orbit's deflector: the same rule.
            let dl = LmpTableLayout.rightDeflectorLow, dh = LmpTableLayout.rightDeflectorHigh
            let dAbove = (dh.x - dl.x) * (p.y - dl.y) - (dh.y - dl.y) * (p.x - dl.x) > 0
            ball.setOrbitDeflectorSolid(dAbove && v.dy < LmpTableLayout.deflectorClimbSpeed)
        }
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

    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: "T5 M8 v3")
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
        let text = "\(fps)T5 M8 v3 \(effectiveCameraMode.tag) · \(speed)"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: LmpBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    @discardableResult
    private func placeBallOnPlunger() -> LmpBall {
        let r = LmpTableLayout.ballRadius
        let ball = LmpBall(at: CGPoint(x: LmpTableLayout.laneCenterX, y: LmpTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        servedBall = ball
        return ball
    }

    private func removeBall(_ ball: LmpBall) {
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
        if servedBall === ball { servedBall = nil }
    }

    private func removeAllBalls() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        servedBall = nil
    }

    private func isOnPlunger(_ ball: LmpBall) -> Bool {
        ball.position.x > LmpTableLayout.laneWallX
            && ball.position.y < LmpTableLayout.plungerRestTop + LmpTableLayout.ballRadius * 3
    }

    private var plungerBall: LmpBall? {
        balls.first(where: { isOnPlunger($0) })
    }

    private var isBallOnPlunger: Bool { plungerBall != nil }

    func newGame() {
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game stops the Shot Lab
        #endif
        fpsLow = 0
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = LmpTableLayout.plungerRestPosition
        bookTargets.forEach { $0.raise() }
        pendingDrops.removeAll()
        bankResetAt = nil
        loopCombo = 0
        lastLoopAt = -100
        cat.reset()
        game.reset()
        // M6 round 3: she starts the evening on any perch you own.
        let start = LmpShop.shared.ownedPerches.randomElement() ?? .shelf
        cat.move(to: start, animated: false)
        game.catPerch = start
        catRoamAt = gameTime + Double.random(in: LmpTableLayout.catRoamSeconds)
        lamps.stopShow()
        eveningStart = gameTime
        request = nil
        nextRequestAt = gameTime + LmpTableLayout.firstRequestDelay
        rushActive = false
        rushBallsToServe = 0
        rushSaveUntil = 0
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + LmpTableLayout.bannerSeconds
    }

    private func sfx(_ s: MonSound) {
        if isLabRunning { return }                 // the robot plays silently
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, !isAttractMode, !isLabRunning else { return }
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
        return p.x > b.width * LmpTableLayout.plungerZoneMinX && p.y > b.height * LmpTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches where activeTouches[touch] == .plunger {
            let dragged = (touch.location(in: view).y - plungerStartY) * cameraRig.node.yScale
            plungerPull = min(max(dragged, 0), LmpTableLayout.plungerMaxPull)
            plunger.position.y = LmpTableLayout.plungerRestPosition.y - plungerPull
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
        let left = activeTouches.values.contains(.left) || padLeft
        let right = activeTouches.values.contains(.right) || padRight
        if left && !leftFlipper.isPressed { sfx(.flipper) }
        if right && !rightFlipper.isPressed { sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
        loftFlipper?.isPressed = right
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        padPullByA = false
        plungerPull = 0
        plunger?.position = LmpTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    private func releasePlunger() {
        let maxPull = LmpTableLayout.plungerMaxPull
        let power = plungerPull < 4 ? LmpTableLayout.tapLaunchPower : plungerPull / maxPull
        if let ball = plungerBall, let body = ball.physicsBody {
            ball.launched = true
            let speed = LmpTableLayout.minLaunchSpeed
                + power * (LmpTableLayout.maxLaunchSpeed - LmpTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
            sfx(.launch)
        }
        plunger.run(.move(to: LmpTableLayout.plungerRestPosition, duration: 0.04))
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
            plungerPull = pull * LmpTableLayout.plungerMaxPull
            plunger.position.y = LmpTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * LmpTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = LmpTableLayout.plungerRestPosition
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
        loftFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        updateGates()
        updateBank(now)
        updateScoops(now)
        updateRides(now)
        updateCat(dt, now: now)
        updateSpinner(dt, now: now)
        updateLamps(now)

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }
        updateRequests(now)
        updateRush(now)
        if let due = visitorClearAt, now >= due {
            visitorClearAt = nil
            game.visitor = nil
        }
        if let due = findToastClearAt, now >= due {
            findToastClearAt = nil
            game.findToast = nil
        }

        // Drain: remove every ball off the bottom; a ball is lost only when none are left.
        let drained = balls.filter { $0.position.y < -LmpTableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            if rushActive, now < rushSaveUntil {
                // M8 round 2: the Rush's ball save puts them straight back in.
                rushBallsToServe += drained.count
                showBanner("SAVED · BALL BACK IN")
            } else if rushActive, balls.count + rushBallsToServe <= 1 {
                endRush()
            }
            if balls.isEmpty, rushBallsToServe == 0, nextBallAt == nil {
                cameraRig.shake(strength: 4, duration: 0.3)
                sfx(.drain)
                game.ballDrained()
                if !game.isGameOver { nextBallAt = now + 1.0 } else { LmpShop.shared.endEvening(score: game.score) }
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

    override func didSimulatePhysics() {
        let line = LmpTableLayout.rightOutlaneLine
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            if speed > LmpTableLayout.maxBallSpeed {
                let scale = LmpTableLayout.maxBallSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            // The right outlane: crossing its line going down marks the ball (the cat-flap save comes with the rules).
            let p0 = ball.previousPosition, p = ball.position
            if ball.ride != nil {
                // carried by the scene: no switches
            } else if ball.isUpper {
                updateUpperBall(ball, from: p0, to: p)
            } else {
                if p0.y >= line.a.y, p.y < line.a.y, p.x > line.a.x, p.x < line.b.x { ball.inRightOutlane = true }
                if ball.launched, p.y < LmpTableLayout.launchedClearY, p.x < LmpTableLayout.laneWallX { ball.launched = false }
                let loop = LmpTableLayout.loopSwitch.crossing(from: p0, to: p)
                if loop != .none { madeLoop(ball, rightToLeft: loop == .forward) }
                if LmpTableLayout.kettleSpinnerSwitch.crossing(from: p0, to: p) != .none, let sp = spinner {
                    let v = body.velocity
                    sp.kick(ballSpeed: hypot(v.dx, v.dy))
                    shotEvent("spinner")
                    body.velocity = CGVector(dx: v.dx * LmpSpinner.ballSpeedKept, dy: v.dy * LmpSpinner.ballSpeedKept)
                }
                // Into the ramp's mouth: up onto the upper layer.
                if ball.heldIn == nil, LmpTableLayout.rampEntrySwitch.crossing(from: p0, to: p) == .forward {
                    ball.setUpper(true)
                }
            }
            ball.previousPosition = p
            ball.updateLook()
        }
    }

    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: lastStep)
        placeBuildTag()
    }

    // MARK: - Finds (milestone 6)

    /// Finds a book (saved at once) and shows it under the score. The robot never finds anything.
    private func awardFind(from source: LmpFindSource) {
        if isLabRunning { return }
        let find = LmpShop.shared.find(from: source, lucky: game.lucky)
        game.findsTonight += 1
        if find.isNew { game.newTonight += 1 }
        game.findToast = find
        findToastClearAt = gameTime + LmpTableLayout.findToastSeconds
        sfx(find.book.rarity >= .rare ? .jackpot : .lane)
    }

    // MARK: - Requests (milestone 8)

    /// The arrows that show a request step.
    private static func requestLamps(for step: LmpRequestStep) -> [String] {
        switch step {
        case .bookshelf: return ["fireplace"]
        case .loop: return ["leftLoop", "rightLoop"]
        case .ramp, .loft: return ["ramp"]
        case .kettle: return ["kettle"]
        case .mail: return ["mail"]
        }
    }

    /// A regular comes in when it's time (one at a time).
    private func updateRequests(_ now: TimeInterval) {
        guard request == nil, !game.isGameOver, let due = nextRequestAt, now >= due else { return }
        nextRequestAt = nil
        let r = LmpRegulars.next(after: lastRegular)
        request = r
        lastRegular = r.regular
        showBanner("\(r.regular.name.uppercased()) COMES IN")
        game.status = statusText(r)
        game.visitor = r                                   // their card under the score
        visitorClearAt = now + LmpTableLayout.visitorCardSeconds
        sfx(.lane)
    }

    /// A shot was made: if it's the request's next step, move on; the last step finishes it.
    private func requestEvent(_ step: LmpRequestStep) {
        guard !isLabRunning, var r = request, r.step == step else { return }
        r.stepIndex += 1
        if r.isDone {
            request = nil
            game.requestsTonight += 1
            game.add(LmpTableLayout.requestPoints * (rushActive ? 2 : 1))
            let level = LmpShop.shared.finishRequest(for: r.regular)
            showBanner("THANK YOU! · \(r.regular.name.uppercased()) · FRIENDSHIP \(level)" + (rushActive ? " · ×2" : ""))
            sfx(.lanesComplete)
            if !rushActive, game.requestsTonight % LmpTableLayout.rushEvery == 0 { startRush() }
            game.status = statusText(nil)
            nextRequestAt = gameTime + (rushActive ? LmpTableLayout.rushRequestDelay : LmpTableLayout.nextRequestDelay)
        } else {
            request = r
            game.status = statusText(r)
            sfx(.lane)
        }
    }

    /// The LED strip's bottom row: the request in progress, with the Rush in front while it lasts.
    private func statusText(_ r: LmpRequest?) -> String? {
        guard rushActive else { return r?.status }
        return "RUSH ×2 · " + (r?.status ?? "the next regular's on the way")
    }

    // MARK: - The Evening Rush (milestone 8 round 2)

    /// Enough requests done: the door opens, a second ball is plunged in for you and requests pay double.
    private func startRush() {
        rushActive = true
        game.rushesTonight += 1
        rushBallsToServe = 1
        rushLaunchAt = gameTime + LmpTableLayout.rushLaunchDelay
        rushSaveUntil = .infinity                      // the save starts when the Rush ball goes in
        showBanner("THE EVENING RUSH · REQUESTS PAY DOUBLE")
        lamps.play(.sweep, at: gameTime)
        sfx(.jackpot)
    }

    /// Plunges the Rush's balls in one at a time (waiting while a ball sits on the plunger).
    private func updateRush(_ now: TimeInterval) {
        guard rushBallsToServe > 0, now >= rushLaunchAt, !isBallOnPlunger else { return }
        rushBallsToServe -= 1
        rushLaunchAt = now + 0.8
        if rushSaveUntil == .infinity { rushSaveUntil = now + LmpTableLayout.rushSaveSeconds }
        let ball = placeBallOnPlunger()
        ball.launched = true
        let speed = LmpTableLayout.minLaunchSpeed
            + LmpTableLayout.rushLaunchPower * (LmpTableLayout.maxLaunchSpeed - LmpTableLayout.minLaunchSpeed)
        ball.physicsBody?.velocity = CGVector(dx: 0, dy: speed)
        plunger.run(.sequence([.moveBy(x: 0, y: -14, duration: 0.05), .move(to: LmpTableLayout.plungerRestPosition, duration: 0.04)]))
        sfx(.launch)
    }

    /// Back to one ball: the Rush is over (requests pay as usual again).
    private func endRush() {
        rushActive = false
        rushSaveUntil = 0
        showBanner("THE RUSH IS OVER")
        game.status = statusText(request)
    }

    /// A loop combo or a full plunge: better odds on rare books for the rest of the evening.
    private func makeLucky() {
        guard !game.lucky, !isLabRunning else { return }
        game.lucky = true
        showBanner("LUCKY EVENING")
    }

    // MARK: - The loft (milestone 3)

    /// Carries a ball along a straight line onto the loft (no collisions on the way), then lets it go.
    private func startRide(_ ball: LmpBall, to end: CGPoint, seconds: TimeInterval, exit: CGVector) {
        ball.setUpper(true)
        ball.ride = (from: ball.position, to: end, start: gameTime, duration: seconds, exit: exit)
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.velocity = .zero
    }

    private func updateRides(_ now: TimeInterval) {
        for ball in balls {
            guard let ride = ball.ride, let body = ball.physicsBody else { continue }
            let t = CGFloat(min(max((now - ride.start) / ride.duration, 0), 1))
            let e = t * t * (3 - 2 * t)                       // ease in and out
            ball.position = CGPoint(x: ride.from.x + (ride.to.x - ride.from.x) * e,
                                    y: ride.from.y + (ride.to.y - ride.from.y) * e)
            body.velocity = .zero
            if t >= 1 {
                ball.ride = nil
                ball.previousPosition = ball.position
                body.affectedByGravity = true
                body.velocity = ride.exit
            }
        }
    }

    /// A ball on the ramp or the loft: made the ramp, rolled back out of its mouth, or drained off the loft down the
    /// chute into the left lane. Safety net: an upper ball that ends up below the ramp's mouth goes back to the floor.
    private func updateUpperBall(_ ball: LmpBall, from p0: CGPoint, to p: CGPoint) {
        if LmpTableLayout.rampMadeSwitch.crossing(from: p0, to: p) == .forward {
            game.add(LmpTableLayout.rampPoints)
            shotEvent("ramp")
            requestEvent(.ramp)
            requestEvent(.loft)
            showBanner("UP TO THE LOFT")
            sfx(.ramp)
            hitHaptic.impactOccurred(intensity: 0.7)
        }
        // Safety nets (T5 M6 v2): below the ramp's mouth, right of the ramp, or above the ramp's turn right of the
        // loft are all places no ramp or loft ball can be; put such a ball back on the floor.
        let outside = p.y < LmpTableLayout.rampMouth.y - 40
            || p.x > LmpTableLayout.rampMouthRightX + 30
            || (p.x > LmpTableLayout.loftRightX + 5 && p.y > LmpTableLayout.loftDoorTop + 25)
        if LmpTableLayout.rampEntrySwitch.crossing(from: p0, to: p) == .backward
            || LmpTableLayout.loftExitSwitch.crossing(from: p0, to: p) == .forward
            || outside {
            ball.setUpper(false)
        }
    }

    // MARK: - Upper table (milestone 2)

    /// Over the top of the arch. A plunged ball's first trip doesn't count; a loop within a few seconds of the last
    /// one is a combo.
    private func madeLoop(_ ball: LmpBall, rightToLeft: Bool) {
        if ball.launched {
            // M3 round 2: a full plunge drops through the hatch into the loft.
            let v = ball.physicsBody?.velocity ?? .zero
            if rightToLeft, hypot(v.dx, v.dy) >= LmpTableLayout.plungeToLoftSpeed {
                ball.launched = false
                startRide(ball, to: LmpTableLayout.loftHatch, seconds: LmpTableLayout.loftHatchSeconds,
                          exit: LmpTableLayout.loftHatchExitVelocity)
                game.add(LmpTableLayout.fullPlungePoints)
                showBanner("FULL PLUNGE · THE LOFT")
                requestEvent(.loft)
                sfx(.skillShot)
                makeLucky()
            }
            return
        }
        if gameTime - lastLoopAt <= LmpTableLayout.loopComboWindow {
            loopCombo += 1
            game.add(LmpTableLayout.loopPoints + LmpTableLayout.loopComboPoints * loopCombo)
            showBanner("LOOP COMBO × \(loopCombo + 1)")
            makeLucky()
        } else {
            loopCombo = 0
            game.add(LmpTableLayout.loopPoints)
            showBanner(rightToLeft ? "LEFT LOOP" : "RIGHT LOOP")
        }
        lastLoopAt = gameTime
        shotEvent(rightToLeft ? "rightLoop" : "leftLoop")   // named for the lane the ball went up
        requestEvent(.loop)
        sfx(.orbit)
        hitHaptic.impactOccurred(intensity: 0.5)
    }

    /// Drops the book targets hit this frame; once all four are down the fireplace is open. After a ball has been
    /// in the fireplace, the bank comes back up as soon as no ball is inside the alcove.
    private func updateBank(_ now: TimeInterval) {
        if !pendingDrops.isEmpty {
            pendingDrops.forEach { $0.drop() }
            pendingDrops.removeAll()
            if bookTargets.allSatisfy({ $0.isDown }) {
                game.add(LmpTableLayout.bankCompletePoints)
                showBanner("FIREPLACE OPEN")
                sfx(.lanesComplete)
                awardFind(from: .shelf)
                requestEvent(.bookshelf)
            }
        }
        if let due = bankResetAt, now >= due, !balls.contains(where: { isInAlcove($0.position) }) {
            bankResetAt = nil
            bookTargets.forEach { $0.raise() }
        }
    }

    private func isInAlcove(_ p: CGPoint) -> Bool {
        let r = LmpTableLayout.ballRadius
        return p.x > LmpTableLayout.alcoveLeftX - r && p.x < LmpTableLayout.alcoveRightX + r
            && p.y > LmpTableLayout.alcoveBottomY - r * 2 && p.y < LmpTableLayout.alcoveTopY
    }

    /// Catches a ball that rolls into an empty hole, holds it, then kicks it out (Table 04's pattern). The mail slot
    /// only takes a soft shot.
    private func updateScoops(_ now: TimeInterval) {
        for ball in balls {
            guard let body = ball.physicsBody, ball.ride == nil else { continue }
            if let scoop = ball.heldIn {
                ball.position = scoop.position
                body.velocity = .zero
                body.angularVelocity = 0
                if now >= ball.releaseAt {
                    ball.heldIn = nil
                    ball.scoopIgnoreUntil = now + LmpTableLayout.scoopRecapture
                    if scoop === kettle, dumbwaiterLit {
                        dumbwaiterLit = false
                        startRide(ball, to: LmpTableLayout.dumbwaiterExit, seconds: LmpTableLayout.dumbwaiterSeconds,
                                  exit: LmpTableLayout.dumbwaiterExitVelocity)
                        game.add(LmpTableLayout.dumbwaiterPoints)
                        showBanner("DUMBWAITER")
                        requestEvent(.loft)
                        sfx(.upKick)
                        continue
                    }
                    if scoop === kettle { dumbwaiterLit = true }
                    body.affectedByGravity = true
                    body.velocity = scoop.ejectVelocity
                    sfx(.scoopOut)
                    if scoop === fireplace { bankResetAt = now + LmpTableLayout.bankResetDelay }
                }
                continue
            }
            guard now >= ball.scoopIgnoreUntil else { continue }
            let onLoft = ball.isUpper
            let v = body.velocity
            let from = CGPoint(x: ball.position.x - v.dx * lastStep, y: ball.position.y - v.dy * lastStep)
            guard let scoop = scoops.first(where: { candidate in
                (candidate === windowSeat) == onLoft
                    && candidate.catches(from: from, to: ball.position) && !balls.contains(where: { $0.heldIn === candidate })
            }) else { continue }
            if scoop === mailSlot, hypot(v.dx, v.dy) > LmpTableLayout.mailMaxSpeed { continue }
            ball.heldIn = scoop
            ball.releaseAt = now + LmpTableLayout.scoopHold
            body.affectedByGravity = false
            body.velocity = .zero
            game.add(scoop.points)
            if scoop === kettle, cat.perch == .kettle, !isLabRunning {
                game.add(scoop.points)                 // her perch: the kettle scores double
            }
            shotEvent(scoop === fireplace ? "fireplace" : scoop === kettle ? "kettle"
                      : scoop === windowSeat ? "windowSeat" : "mail")
            Effects.burst(in: self, at: scoop.position, color: Self.wallColor, count: 20, speed: 180, lifetime: 0.5)
            sfx(scoop === fireplace ? .jackpot : .scoopIn)
            showBanner(scoop === fireplace ? "FIREPLACE" : scoop === kettle ? "KETTLE"
                       : scoop === windowSeat ? "WINDOW SEAT" : "MAIL POSTED")
            scoop.flash()
            hitHaptic.impactOccurred(intensity: 0.8)
            if scoop === fireplace { awardFind(from: .shelf) } else if scoop === windowSeat { awardFind(from: .loft) }
            if scoop === kettle { requestEvent(.kettle) } else if scoop === mailSlot { requestEvent(.mail) }
            if scoop === windowSeat, cat.perch == .windowSeat {
                awardFind(from: .loft)                 // her perch: an extra book
                showBanner("THE CAT FOUND ONE TOO")
            } else if scoop === kettle, cat.perch == .kettle {
                showBanner("KETTLE × 2 · THE CAT'S BASKET")
            }
        }
    }

    /// Scores each spin with a soft tick (at most 20 ticks a second) and shows the total when it stops.
    private func updateSpinner(_ dt: CGFloat, now: TimeInterval) {
        guard let spinner, spinner.isSpinning else { return }
        let spins = spinner.update(dt: dt)
        if spins > 0 {
            game.add(LmpTableLayout.spinnerPoints * spins)
            if now - lastSpinTickAt >= 0.05 {
                lastSpinTickAt = now
                sound.play(.spinner, volume: Float(settings.soundVolume) * 0.6)
            }
        }
        if !spinner.isSpinning, spinner.spinsThisRun > 0 {
            showBanner("TEAPOT × \(spinner.spinsThisRun)")
        }
    }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        if a.categoryBitMask == LmpPhysicsCategory.ball {
            ballBody = a; other = b
        } else if b.categoryBitMask == LmpPhysicsCategory.ball {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? LmpBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case LmpPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? LmpSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                game.add(LmpTableLayout.slingPoints)
                shotEvent("sling")
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case LmpPhysicsCategory.toy:
            if node === cat {
                switch cat.ballHit(now: gameTime) {
                case .woke:
                    game.add(LmpTableLayout.catWakePoints)
                    shotEvent("cat")
                    showBanner("MRRP?!")
                    awardFind(from: .cat)
                    sfx(.captiveKnock)
                case .petted:
                    game.add(LmpTableLayout.catPetPoints)
                    shotEvent("cat")
                    showBanner("PURR")
                    sfx(.captiveKnock)
                case .none:
                    break
                }
            }
        case LmpPhysicsCategory.target:
            if let t = node as? LmpDropTarget, t.registerHit() {
                pendingDrops.append(t)
                game.add(LmpTableLayout.bookTargetPoints)
                shotEvent("bookTarget")
                hitHaptic.impactOccurred(intensity: 0.6)
                sfx(.standup)
            }
        case LmpPhysicsCategory.bumper:
            if let bumper = node as? LmpBumper {
                if bumper.hit(ball: ballBody, ballPosition: ballNode.position, at: gameTime) {
                    game.add(LmpTableLayout.bumperPoints)
                    shotEvent("bumper")
                    hitHaptic.impactOccurred(intensity: 0.7)
                    sfx(.bumper)
                }
            } else if node === centerPost, gameTime - centerPostHitAt > 0.15 {
                centerPostHitAt = gameTime
                game.add(LmpTableLayout.centerPostPoints)
                shotEvent("post")
                hitHaptic.impactOccurred(intensity: 0.5)
                sfx(.standup)
                centerPost?.run(.sequence([.scale(to: 1.25, duration: 0.04), .scale(to: 1, duration: 0.12)]))
            }
        default:
            break
        }
    }
}

// MARK: - Shot Lab (milestone 5, debug builds)

extension LmpTableScene {
    /// A shot event for the Shot Lab; does nothing in normal play.
    fileprivate func shotEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        #endif
    }

    #if DEBUG
    /// Starts the robot: it takes over the flippers and sweeps flip timings from a cradled ball on the left, right,
    /// upper and loft flippers, at 120 Hz and 60 Hz physics steps (768 trials, ~40 min in the Simulator). Results go to
    /// ShotLab/ on the Mac. Menu or a new game stops it.
    func debugStartShotLab() {
        isAttractMode = false
        shotLabTime = 0
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
        loftFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        updateGates()
        updateBank(now)
        updateScoops(now)
        updateRides(now)
        updateCat(dt, now: now)
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
extension LmpTableScene: ShotLabHost {
    var shotLabTableName: String { "The Lamplight" }

    /// The shots a player aims for end a trial; bumpers, slings, the post, the spinner and the cat's swats are
    /// noted only.
    var shotLabMajorEvents: Set<String> {
        ["leftLoop", "rightLoop", "ramp", "kettle", "mail", "fireplace", "bookTarget", "windowSeat", "cat"]
    }

    /// Cradles as on Tables 02–04: 40 pt out and 14 above the raised main flippers; on the shorter upper (64) and
    /// loft (56) flippers, half their length out and 17 above. (M6 v6: no upper flipper.) The
    /// loft flipper right-handed (points left).
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = LmpTableLayout.flipperTravel - LmpTableLayout.flipperRestAngle      // 30° above horizontal
        func cradle(_ pivot: CGPoint, along: CGFloat, above: CGFloat, pointsLeft: Bool) -> CGPoint {
            let s: CGFloat = pointsLeft ? -1 : 1                 // the raised flipper's direction, mirrored
            let d = CGVector(dx: s * cos(up), dy: sin(up))       // along the flipper
            let n = CGVector(dx: -s * sin(up), dy: cos(up))      // up off its top face
            return CGPoint(x: pivot.x + along * d.dx + above * n.dx, y: pivot.y + along * d.dy + above * n.dy)
        }
        let l = LmpTableLayout.leftFlipperPivot, r = LmpTableLayout.rightFlipperPivot
        let lf = LmpTableLayout.loftFlipperPivot
        // T5 M6 v6: no upper flipper any more.
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: cradle(l, along: 40, above: 14, pointsLeft: false)),
                ShotLab.FlipperSpec(name: "right", pivot: r, cradle: cradle(r, along: 40, above: 14, pointsLeft: true)),
                ShotLab.FlipperSpec(name: "loft", pivot: lf,
                                    cradle: cradle(lf, along: LmpTableLayout.loftFlipperLength / 2, above: 17,
                                                   pointsLeft: true))]
    }

    /// Each flipper on its own (in play the loft one shares the right button).
    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        switch index {
        case 0: leftFlipper.isPressed = pressed
        case 1: rightFlipper.isPressed = pressed
        default: loftFlipper.isPressed = pressed
        }
    }

    /// The loft flipper's cradle is up on the loft: that ball starts on the upper layer.
    func shotLabPlaceBall(at point: CGPoint) {
        let ball = LmpBall(at: point)
        addChild(ball)
        balls.append(ball)
        if point.y > LmpTableLayout.loftBottomY, point.x < LmpTableLayout.loftRightX { ball.setUpper(true) }
    }

    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        bookTargets.forEach { $0.raise() }
        pendingDrops.removeAll()
        bankResetAt = nil
        cat.reset()
    }

    /// T5 M5 v3: where every flip's ball first crosses these heights going up (x, heading, speed), to map the
    /// misses: the slings' tops, the mail slot, the orbit / ramp / kettle mouths, and the top of the bumpers.
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "y450", y: 450), ShotLab.Probe(name: "y625", y: 625),
         ShotLab.Probe(name: "y800", y: 800), ShotLab.Probe(name: "y1000", y: 1000)]
    }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }
}
#endif

extension LmpTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}
