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
        isAttractMode ? .topDown : settings.cameraMode
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
        addKickbackLamp()
        addRocketPost()
        addPlunger()
        addLaunchGate()
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
        for ball in balls {
            let v = ball.physicsBody?.velocity ?? .zero
            let p = ball.position
            let above = gx * (p.y - low.y) - gy * (p.x - low.x) > 0
            ball.setLaunchGateSolid(above && v.dy < 0)
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
        let label = SKLabelNode(text: "T6 M1 v1")
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
        let text = "\(fps)T6 M1 v1 \(effectiveCameraMode.tag) · \(speed)"
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
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = TourTableLayout.plungerRestPosition
        lanesResetAt = nil
        rollovers.forEach { $0.isLit = false }
        setKickbackLit(true)
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
            if !wasAbove, above, body.velocity.dy > 0, p.x > low.x, p.x < high.x { swingLaunchGate() }
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
                game.add(TourPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case TourPhysicsCategory.bumper:
            // The raised rocket post saved a ball: it scores, flashes and drops a moment later.
            if node === rocketPost, rocketPostUp, rocketPostDropAt == nil {
                rocketPostDropAt = gameTime + TourTableLayout.rocketPostDropDelay
                game.add(TourPoints.rocketPost)
                bigHaptic.impactOccurred()
                Effects.burst(in: self, at: TourTableLayout.rocketPost, color: Self.rocketColor, count: 16,
                              speed: 200, lifetime: 0.35)
                sfx(.ballSave)
                showBanner("ROCKET POST SAVE")
            }
        case TourPhysicsCategory.rollover:
            if let lane = node as? TourRollover { rollOver(lane, at: gameTime) }
        default:
            break
        }
    }
}

extension TourTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}
