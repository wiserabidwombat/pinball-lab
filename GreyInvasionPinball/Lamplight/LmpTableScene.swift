// Pinball Lab Table 05 (The Lamplight): the table scene. Milestone 1 = grey box of the NEW lower table (Aaron chose
// "center post + one outlane"): flippers 11 pt farther apart with a rubber center post between their tips, the left
// side closed (a deflector off the left wall feeds the left inlane), one outlane on the right; slingshots, plunger,
// the one-way launch gate flap, the three camera modes, 3 balls. The upper table is open floor until milestone 2.
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
        body.categoryBitMask = LmpPhysicsCategory.wall
        body.collisionBitMask = LmpPhysicsCategory.ball
        node.physicsBody = body

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
        let label = SKLabelNode(text: "T5 M1 v1")
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
        let text = "\(fps)T5 M1 v1 \(effectiveCameraMode.tag) · \(speed)"
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

    private func placeBallOnPlunger() {
        let r = LmpTableLayout.ballRadius
        let ball = LmpBall(at: CGPoint(x: LmpTableLayout.laneCenterX, y: LmpTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
        servedBall = ball
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
        fpsLow = 0
        isAttractMode = false
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        plunger.position = LmpTableLayout.plungerRestPosition
        game.reset()
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + LmpTableLayout.bannerSeconds
    }

    private func sfx(_ s: MonSound) {
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
        if let body = plungerBall?.physicsBody {
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
        if isAttractMode { return }

        let dt = CGFloat(step)
        lastStep = dt
        updateGamepad()
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        slingshots.forEach { $0.settle() }
        updateGates()

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // Drain: remove every ball off the bottom; a ball is lost only when none are left.
        let drained = balls.filter { $0.position.y < -LmpTableLayout.ballRadius * 3 }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            if balls.isEmpty, nextBallAt == nil {
                cameraRig.shake(strength: 4, duration: 0.3)
                sfx(.drain)
                game.ballDrained()
                if !game.isGameOver { nextBallAt = now + 1.0 }
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
            if p0.y >= line.a.y, p.y < line.a.y, p.x > line.a.x, p.x < line.b.x { ball.inRightOutlane = true }
            ball.previousPosition = p
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
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case LmpPhysicsCategory.bumper:
            if node === centerPost, gameTime - centerPostHitAt > 0.15 {
                centerPostHitAt = gameTime
                game.add(LmpTableLayout.centerPostPoints)
                hitHaptic.impactOccurred(intensity: 0.5)
                sfx(.standup)
                centerPost?.run(.sequence([.scale(to: 1.25, duration: 0.04), .scale(to: 1, duration: 0.12)]))
            }
        default:
            break
        }
    }
}

extension LmpTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}
