// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was TableScene.swift.
import SpriteKit
import UIKit

/// The table: walls, flippers, plunger, drain, the scoring elements —
/// planet bumpers, slingshots, top lanes, asteroid drop targets and the wormhole.
final class OrbitTableScene: SKScene {
    private enum Control { case left, right, plunger }

    private let game: OrbitGameState
    private var ball: SKSpriteNode?
    private var leftFlipper: OrbitFlipper!
    private var rightFlipper: OrbitFlipper!
    private var plunger: SKShapeNode!
    private var isBuilt = false

    // Scoring elements
    private var slingshots: [OrbitSlingshot] = []
    private var rollovers: [OrbitRollover] = []
    private var dropTargets: [OrbitDropTarget] = []
    private var wormhole: OrbitWormhole!

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

    // Timing and deferred work (structural changes happen in update, not in contact callbacks)
    private var lastUpdateTime: TimeInterval?
    private var lastRealTime: TimeInterval?
    private var gameTime: TimeInterval = 0

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
    private var nextBallAt: TimeInterval?
    private var pendingNextBall = false
    private var pendingDrops: [OrbitDropTarget] = []
    private var dropBankResetAt: TimeInterval?
    private var lanesResetAt: TimeInterval?
    private var pendingCapture = false
    private var wormholeReleaseAt: TimeInterval?
    private var wormholeCooldownUntil: TimeInterval = 0

    // Rules (milestone 4)
    private var wasOnPlunger = false
    private var gate: SKShapeNode!
    private var gateClosed = false
    private var ballLaunchedAt: TimeInterval?
    private var ballSaveUsed = false          // once per ball
    private var skillLane: Int?               // index into rollovers while the skill shot is live
    private var bannerClearAt: TimeInterval?

    private let hitHaptic = Haptic(style: .medium)
    private let bigHaptic = Haptic(style: .heavy)
    private let shaker = OrbitCameraShake()
    private let sound = OrbitSoundPlayer()

    init(game: OrbitGameState) {
        self.game = game
        super.init(size: OrbitTableLayout.sceneSize)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: OrbitTableLayout.gravity)
        physicsWorld.contactDelegate = self
        shaker.install(in: self)
        addBackground()
        buildTable()
        hitHaptic.prepare()
        bigHaptic.prepare()
        placeBallOnPlunger()
    }

    // MARK: - Background

    /// Drifting nebula plus a field of twinkling stars, all behind the table.
    private func addBackground() {
        let nebula = SKSpriteNode(imageNamed: "orbit_nebula")
        nebula.size = CGSize(width: size.width * 1.15, height: size.height * 1.15)
        nebula.position = CGPoint(x: size.width / 2, y: size.height / 2)
        nebula.zPosition = -20
        addChild(nebula)
        nebula.run(.repeatForever(.sequence([
            .moveBy(x: 18, y: 30, duration: 14),
            .moveBy(x: -18, y: -30, duration: 14),
        ])))

        for i in 0..<70 {
            let bright = i % 9 == 0
            let star = SKSpriteNode(imageNamed: bright ? "orbit_starBright" : "orbit_star")
            let side = bright ? CGFloat.random(in: 5...8) : CGFloat.random(in: 1.5...3.5)
            star.size = CGSize(width: side, height: side)
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            star.alpha = .random(in: 0.3...0.9)
            star.zPosition = -10
            addChild(star)
            let low = CGFloat.random(in: 0.1...0.4)
            let t = Double.random(in: 1.2...3.5)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: low, duration: t),
                .fadeAlpha(to: 0.95, duration: t),
            ])))
        }
    }

    // MARK: - Table

    private func buildTable() {
        addWall(points: OrbitTableLayout.outerWall)
        addWall(points: OrbitTableLayout.rightGuide)

        leftFlipper = OrbitFlipper(side: .left, pivot: OrbitTableLayout.leftFlipperPivot)
        rightFlipper = OrbitFlipper(side: .right, pivot: OrbitTableLayout.rightFlipperPivot)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)

        addPlunger()
        addGate()
        addScoringElements()
    }

    private func addScoringElements() {
        // Planet bumpers (Kenney Planets, CC0)
        let planets: [(image: String, glow: SKColor)] = [
            ("orbit_planetGreen", SKColor(red: 0.35, green: 0.85, blue: 0.75, alpha: 1)),
            ("orbit_planetRed", SKColor(red: 1.00, green: 0.45, blue: 0.35, alpha: 1)),
            ("orbit_planetPurple", SKColor(red: 0.70, green: 0.45, blue: 1.00, alpha: 1)),
        ]
        for (i, center) in OrbitTableLayout.bumperCenters.enumerated() {
            let p = planets[i % planets.count]
            addChild(OrbitBumper(at: center, imageName: p.image, glow: p.glow))
        }

        // Slingshots
        for s in [OrbitTableLayout.leftSling, OrbitTableLayout.rightSling] {
            let sling = OrbitSlingshot(top: s.top, corner: s.corner, tip: s.tip)
            addChild(sling)
            slingshots.append(sling)
        }

        // Top lanes: short posts with rollover sensors between them
        for x in OrbitTableLayout.lanePostXs {
            addWall(points: [CGPoint(x: x, y: OrbitTableLayout.lanePostBottom),
                             CGPoint(x: x, y: OrbitTableLayout.lanePostTop)])
        }
        for x in OrbitTableLayout.laneCenterXs {
            let lane = OrbitRollover(laneCenterX: x)
            addChild(lane)
            rollovers.append(lane)
        }

        // Asteroid drop targets
        for (i, y) in OrbitTableLayout.dropTargetYs.enumerated() {
            let target = OrbitDropTarget(at: CGPoint(x: OrbitTableLayout.dropTargetX, y: y),
                                    imageName: "orbit_asteroid\(i % 4 + 1)")
            addChild(target)
            dropTargets.append(target)
        }

        for guardLine in OrbitTableLayout.dropTargetGuards {
            addWall(points: guardLine)
        }

        // OrbitWormhole
        wormhole = OrbitWormhole()
        addChild(wormhole)
    }

    private func addWall(points: [CGPoint]) {
        let path = CGMutablePath()
        path.addLines(between: points)

        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1)
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.glowWidth = 2

        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = 0.1
        body.restitution = 0.3
        body.categoryBitMask = OrbitPhysicsCategory.wall
        body.collisionBitMask = OrbitPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
    }

    private func addPlunger() {
        let size = OrbitTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = OrbitTableLayout.plungerRestPosition

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = OrbitPhysicsCategory.wall
        body.collisionBitMask = OrbitPhysicsCategory.ball
        node.physicsBody = body

        addChild(node)
        plunger = node
    }

    /// One-way gate across the top of the launch lane.
    private func addGate() {
        let path = CGMutablePath()
        path.addLines(between: [OrbitTableLayout.gateLow, OrbitTableLayout.gateHigh])
        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        node.lineWidth = 3
        node.lineCap = .round
        node.glowWidth = 2
        let body = SKPhysicsBody(edgeFrom: OrbitTableLayout.gateLow, to: OrbitTableLayout.gateHigh)
        body.friction = 0.05
        body.restitution = 0.2
        body.collisionBitMask = OrbitPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        gate = node
        setGate(closed: false)
    }

    private func setGate(closed: Bool) {
        gateClosed = closed
        gate?.physicsBody?.categoryBitMask = closed ? OrbitPhysicsCategory.wall : OrbitPhysicsCategory.none
        gate?.alpha = closed ? 1 : 0.2
    }

    /// Close the gate once the launched ball is fully past it (above it, or out in the playfield).
    private func updateGate() {
        guard !gateClosed, let ball, ballLaunchedAt != nil else { return }
        let r = OrbitTableLayout.ballRadius
        let p = ball.position
        if p.y > OrbitTableLayout.gateHigh.y + r + 2 || p.x < OrbitTableLayout.laneWallX - r {
            setGate(closed: true)
        }
    }

    // MARK: - Ball

    private func spawnBall(at point: CGPoint) {
        let r = OrbitTableLayout.ballRadius
        let node = SKSpriteNode(imageNamed: "orbit_ball")
        node.size = CGSize(width: r * 2, height: r * 2)
        node.position = point
        node.name = "orbit_ball"
        node.zPosition = 10

        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = 0.08
        body.restitution = OrbitTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true   // stops tunneling at speed
        body.categoryBitMask = OrbitPhysicsCategory.ball
        body.collisionBitMask = OrbitPhysicsCategory.wall | OrbitPhysicsCategory.flipper
            | OrbitPhysicsCategory.bumper | OrbitPhysicsCategory.target | OrbitPhysicsCategory.slingshot
        body.contactTestBitMask = OrbitPhysicsCategory.bumper | OrbitPhysicsCategory.target
            | OrbitPhysicsCategory.slingshot | OrbitPhysicsCategory.rollover | OrbitPhysicsCategory.wormhole
        node.physicsBody = body

        addChild(node)
        let trail = OrbitEffects.ballTrail()
        node.addChild(trail)
        trail.targetNode = self
        ball = node
        game.ballPlaced()
    }

    private func placeBallOnPlunger() {
        setGate(closed: false)
        let r = OrbitTableLayout.ballRadius
        spawnBall(at: CGPoint(x: OrbitTableLayout.laneCenterX,
                              y: OrbitTableLayout.plungerRestTop + r + 2))
        // New skill-shot target for this launch
        let pick = Int.random(in: 0..<rollovers.count)
        setSkillLane(pick)
    }

    private func setSkillLane(_ index: Int?) {
        skillLane = index
        for (i, lane) in rollovers.enumerated() {
            lane.isSkillTarget = (i == index)
        }
    }

    private func removeBall() {
        ball?.removeFromParent()
        ball = nil
        pendingCapture = false
        wormholeReleaseAt = nil
    }

    /// True while the ball is sitting in the plunger lane waiting to launch.
    private var isBallOnPlunger: Bool {
        guard let ball else { return false }
        return ball.position.x > OrbitTableLayout.laneWallX
            && ball.position.y < OrbitTableLayout.plungerRestTop + OrbitTableLayout.ballRadius * 3
    }

    func newGame() {
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        removeBall()
        nextBallAt = nil
        pendingNextBall = false
        plunger.position = OrbitTableLayout.plungerRestPosition
        pendingDrops.removeAll()
        dropBankResetAt = nil
        dropTargets.forEach { $0.raise() }
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        wormholeCooldownUntil = 0
        wasOnPlunger = false
        ballLaunchedAt = nil
        ballSaveUsed = false
        bannerClearAt = nil
        game.reset()
        placeBallOnPlunger()
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if isBallOnPlunger,
               !activeTouches.values.contains(.plunger),
               OrbitTableLayout.plungerZone.contains(p) {
                activeTouches[touch] = .plunger
                plungerStartY = p.y
                plungerPull = 0
            } else {
                activeTouches[touch] = p.x < size.width / 2 ? .left : .right
            }
        }
        updateFlippers()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where activeTouches[touch] == .plunger {
            let y = touch.location(in: self).y
            plungerPull = min(max(plungerStartY - y, 0), OrbitTableLayout.plungerMaxPull)
            plunger.position.y = OrbitTableLayout.plungerRestPosition.y - plungerPull
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
        // Lane change: each new flipper press shifts the lit top lanes that way.
        if left && !leftFlipper.isPressed { rotateLanes(by: -1); sound.play(.flipper, on: self) }
        if right && !rightFlipper.isPressed { rotateLanes(by: 1); sound.play(.flipper, on: self) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
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
        plunger?.position = OrbitTableLayout.plungerRestPosition
        if leftFlipper != nil { updateFlippers() }
    }

    /// Shifts which top lanes are lit: -1 = one lane left, +1 = one lane right (wrapping).
    private func rotateLanes(by step: Int) {
        guard lanesResetAt == nil, !rollovers.isEmpty else { return }
        let lit = rollovers.map { $0.isLit }
        let n = lit.count
        for (i, lane) in rollovers.enumerated() {
            lane.isLit = lit[((i - step) % n + n) % n]
        }
    }

    private func releasePlunger() {
        let maxPull = OrbitTableLayout.plungerMaxPull
        let power = plungerPull < 4 ? OrbitTableLayout.tapLaunchPower : plungerPull / maxPull

        if isBallOnPlunger, let body = ball?.physicsBody {
            let speed = OrbitTableLayout.minLaunchSpeed
                + power * (OrbitTableLayout.maxLaunchSpeed - OrbitTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
            sound.play(.launch, on: self)
        }
        plunger.run(.move(to: OrbitTableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    // MARK: - Contacts

    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        if a.categoryBitMask == OrbitPhysicsCategory.ball {
            ballBody = a; other = b
        } else if b.categoryBitMask == OrbitPhysicsCategory.ball {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node, ballNode === ball, let node = other.node else { return }
        let now = lastUpdateTime ?? 0

        // Hitting anything that scores (other than a top lane) ends the skill shot.
        let category = other.categoryBitMask
        if category != OrbitPhysicsCategory.rollover, category != OrbitPhysicsCategory.wall {
            setSkillLane(nil)
        }

        switch category {
        case OrbitPhysicsCategory.bumper:
            if let bumper = node as? OrbitBumper,
               bumper.hit(ball: ballBody, ballPosition: ballNode.position, at: now) {
                game.add(OrbitPoints.bumper)
                hitHaptic.impactOccurred()
                sound.play(.bumper, on: self)
                OrbitEffects.burst(in: self, at: contactPoint(contact, ball: ballNode), color: bumper.glow)
                shaker.shake(strength: 2.5, duration: 0.15)
            }

        case OrbitPhysicsCategory.slingshot:
            // The kicking face is a child of the OrbitSlingshot node.
            if let sling = node.parent as? OrbitSlingshot, sling.hit(ball: ballBody, at: now) {
                game.add(OrbitPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                sound.play(.sling, on: self)
                OrbitEffects.burst(in: self, at: contactPoint(contact, ball: ballNode),
                              color: OrbitEffects.sparkOrange, count: 8, speed: 160)
            }

        case OrbitPhysicsCategory.target:
            if let target = node as? OrbitDropTarget, target.registerHit() {
                game.add(OrbitPoints.dropTarget)
                pendingDrops.append(target)
                sound.play(.dropTarget, on: self)
                OrbitEffects.burst(in: self, at: target.position, color: OrbitEffects.rockBrown,
                              count: 12, speed: 140, lifetime: 0.45, size: 0.3)
            }

        case OrbitPhysicsCategory.rollover:
            if let lane = node as? OrbitRollover {
                rollOver(lane, at: now)
            }

        case OrbitPhysicsCategory.wormhole:
            if wormholeReleaseAt == nil, !pendingCapture, now >= wormholeCooldownUntil {
                pendingCapture = true
            }

        default:
            break
        }
    }

    /// Where the ball touched: the physics contact point, or the ball's centre as a fallback.
    private func contactPoint(_ contact: SKPhysicsContact, ball: SKNode) -> CGPoint {
        let p = contact.contactPoint
        return p.x.isFinite && p.y.isFinite ? p : ball.position
    }

    private func rollOver(_ lane: OrbitRollover, at now: TimeInterval) {
        // Skill shot: the first lane the launched ball rolls through decides it.
        if let s = skillLane {
            setSkillLane(nil)
            if rollovers[s] === lane,
               let launched = ballLaunchedAt, now - launched <= OrbitTableLayout.skillShotWindow {
                game.add(OrbitPoints.skillShot)
                showBanner("SKILL SHOT", at: now)
                bigHaptic.impactOccurred()
                sound.play(.skillShot, on: self)
                OrbitEffects.burst(in: self, at: lane.position, color: OrbitEffects.gold,
                              count: 30, speed: 260, lifetime: 0.6, size: 0.3)
                shaker.shake(strength: 8)
            }
        }

        guard lanesResetAt == nil else { return }   // lanes are flashing "complete"
        if lane.isLit {
            game.add(OrbitPoints.laneRepeat)
            return
        }
        lane.isLit = true
        game.add(OrbitPoints.laneLit)
        sound.play(.rollover, on: self)
        OrbitEffects.burst(in: self, at: lane.position, color: OrbitEffects.gold, count: 8, speed: 100)
        if rollovers.allSatisfy({ $0.isLit }) {
            if game.raiseMultiplier() {
                showBanner("\(game.multiplier)X", at: now)
                bigHaptic.impactOccurred()
                sound.play(.multiplier, on: self)
                shaker.shake(strength: 6)
            }
            lanesResetAt = now + 0.6
        }
    }

    private func showBanner(_ text: String, at now: TimeInterval) {
        game.banner = text
        bannerClearAt = now + OrbitTableLayout.bannerSeconds
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
            plungerPull = pull * OrbitTableLayout.plungerMaxPull
            plunger.position.y = OrbitTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            // A quick press of A (under 4 pt of pull) is a medium launch; a stick barely nudged does nothing.
            let peak = padPeakPull * OrbitTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = OrbitTableLayout.plungerRestPosition
                }
            }
        }
    }

    // MARK: - Game loop

    override func update(_ realTime: TimeInterval) {
        // Game clock: advances by the clamped frame time only, so time spent paused
        // (or a long hitch) never eats into ball save, the wormhole hold or other timers.
        let step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
        lastRealTime = realTime
        gameTime += step
        let currentTime = gameTime
        lastUpdateTime = gameTime   // contact handlers read this as "now"

        // Drive the flippers (and read the game controller first)
        let dt = CGFloat(step)
        updateGamepad()
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }

        updateDropTargets(currentTime)
        updateLanes(currentTime)
        updateWormhole(currentTime)

        updateRules(currentTime)
        updateGate()

        // Drain check
        if let ball, ball.position.y < -OrbitTableLayout.ballRadius * 3 {
            let drainX = ball.position.x
            removeBall()
            if let launched = ballLaunchedAt, !ballSaveUsed,
               currentTime - launched <= OrbitTableLayout.ballSaveSeconds {
                // Ball save: give it back once, no ball lost
                ballSaveUsed = true
                game.ballSaved()
                showBanner("BALL SAVED", at: currentTime)
                sound.play(.ballSave, on: self)
                pendingNextBall = true
            } else {
                ballSaveUsed = false          // next ball gets its own save
                game.ballDrained()
                pendingNextBall = !game.isGameOver
                sound.play(.drain, on: self)
                hitHaptic.impactOccurred(intensity: 0.5)
                shaker.shake(strength: 4, duration: 0.25)
                OrbitEffects.burst(in: self, at: CGPoint(x: drainX, y: 8),
                              color: SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 1),
                              count: 18, speed: 180, lifetime: 0.5)
            }
            ballLaunchedAt = nil
            setSkillLane(nil)
        }

        // Short pause, then serve the next ball
        if pendingNextBall {
            pendingNextBall = false
            nextBallAt = currentTime + 0.8
        }
        if let due = nextBallAt, currentTime >= due {
            nextBallAt = nil
            placeBallOnPlunger()
        }

        // Keep the HUD hint in sync (only write when it changes)
        let onPlunger = isBallOnPlunger
        if game.ballOnPlunger != onPlunger {
            game.ballOnPlunger = onPlunger
        }
    }

    private func updateRules(_ now: TimeInterval) {
        // Launch = the ball leaves the plunger. Starts the ball-save and skill-shot clocks.
        let onPlunger = isBallOnPlunger
        if wasOnPlunger && !onPlunger && ball != nil {
            ballLaunchedAt = now
        }
        wasOnPlunger = onPlunger

        let elapsed = ballLaunchedAt.map { now - $0 }
        if let elapsed, skillLane != nil, elapsed > OrbitTableLayout.skillShotWindow {
            setSkillLane(nil)
        }

        // HUD "SAVE" light: on while waiting to launch and for the first seconds after,
        // until this ball's one save is used.
        let inSaveWindow = onPlunger || (elapsed.map { $0 <= OrbitTableLayout.ballSaveSeconds } ?? false)
        let saveOn = ball != nil && !ballSaveUsed && inSaveWindow
        if game.ballSaveActive != saveOn { game.ballSaveActive = saveOn }

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }
    }

    private func updateDropTargets(_ now: TimeInterval) {
        if !pendingDrops.isEmpty {
            pendingDrops.forEach { $0.drop() }
            pendingDrops.removeAll()
            if dropBankResetAt == nil, dropTargets.allSatisfy({ $0.isDown }) {
                game.add(OrbitPoints.dropTargetBank)
                bigHaptic.impactOccurred()
                sound.play(.bank, on: self)
                shaker.shake(strength: 10, duration: 0.4)
                for t in dropTargets {
                    OrbitEffects.burst(in: self, at: t.position, color: OrbitEffects.rockBrown,
                                  count: 24, speed: 240, lifetime: 0.7, size: 0.35)
                }
                dropBankResetAt = now + OrbitTableLayout.dropTargetResetDelay
            }
        }
        if let due = dropBankResetAt, now >= due {
            dropBankResetAt = nil
            dropTargets.forEach { $0.raise() }
        }
    }

    private func updateLanes(_ now: TimeInterval) {
        guard let due = lanesResetAt else { return }
        // Blink while complete, then clear.
        let blinkOn = Int((due - now) * 10) % 2 == 0
        rollovers.forEach { $0.isLit = blinkOn }
        if now >= due {
            lanesResetAt = nil
            rollovers.forEach { $0.isLit = false }
        }
    }

    private func updateWormhole(_ now: TimeInterval) {
        guard let ball, let body = ball.physicsBody else { return }

        if pendingCapture {
            pendingCapture = false
            wormholeReleaseAt = now + OrbitTableLayout.wormholeHold
            game.add(OrbitPoints.wormhole)
            hitHaptic.impactOccurred(intensity: 0.8)
            sound.play(.wormholeIn, on: self)
            OrbitEffects.burst(in: self, at: OrbitTableLayout.wormholeCenter, color: OrbitEffects.wormholePurple,
                          count: 16, speed: 70, lifetime: 0.5, size: 0.3)
            body.affectedByGravity = false
        }

        if let release = wormholeReleaseAt {
            // Hold the ball in the middle of the wormhole
            ball.position = OrbitTableLayout.wormholeCenter
            body.velocity = .zero
            body.angularVelocity = 0
            if now >= release {
                wormholeReleaseAt = nil
                wormholeCooldownUntil = now + 0.6   // don't recapture on the way out
                body.affectedByGravity = true
                body.velocity = OrbitTableLayout.wormholeEject
                sound.play(.wormholeOut, on: self)
                OrbitEffects.burst(in: self, at: OrbitTableLayout.wormholeCenter, color: OrbitEffects.wormholePurple,
                              count: 24, speed: 220, lifetime: 0.45)
                shaker.shake(strength: 5)
            }
        }
    }

    override func didSimulatePhysics() {
        guard let body = ball?.physicsBody else { return }
        let v = body.velocity
        let speed = hypot(v.dx, v.dy)
        let maxSpeed = OrbitTableLayout.maxBallSpeed
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
        }
    }
}

extension OrbitTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        // SpriteKit calls this on the main thread during the frame.
        MainActor.assumeIsolated {
            handleContact(contact)
        }
    }
}
