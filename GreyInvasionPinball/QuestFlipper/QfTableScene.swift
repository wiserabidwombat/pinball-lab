// Pinball Lab Table 09 (Quest & Flipper): the Haunted Forest region table. Milestone 1 v1 = the whole layout in grey
// box, playable:
//   - the lower table (Neon Labyrinth's cell kit: CHOMP!'s real-scale flippers and flipper model, slings, inlanes,
//     outlanes, the inlane speed limit), the shooter lane with CHOMP!'s plunger and a one-way launch gate;
//   - the Old Well (a catch goes by subway to the left inlane), the Graveyard orbit with its spinner, the Hollow Log
//     scoop, the Treant's clearing (three bark drops in front of the trunk), the Old Road ramp's solid low end, the
//     East lantern and the forest island's solid block;
//   - drains cost HP from the run (QfRunState), not balls: zero HP ends the game. Hits on the trunk and the lantern
//     show their damage (impact speed × the run's ball strength); the trunk only takes damage once all the bark is down.
// M1 v2: the Old Road is a real ramp (QfRamp, CHOMP!'s ramp layer): up through the island, over the hook, down its wire
// into the right inlane. Felling the Treant lights the exit: then a made Old Road rides into the Forest Gate and the visit
// ends ("You Escaped"). Drawn only (they work later): the wisps in the glade.
// Geometry: QfForestLayout.swift (generated from tools/qf_layout.py, checked by qf_checks.py / qf_sim.py).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class QfTableScene: SKScene, RendererHostedScene {
    private enum Control { case left, right, plunger }

    /// A ball moved along a path by the scene (collisions and gravity off), then let go with a set velocity.
    private struct Ride {
        let ball: QfBall
        let path: [CGPoint]
        let cumulative: [CGFloat]
        var s: CGFloat = 0
        let speed: CGFloat
        let release: CGVector
        /// Hidden while riding (a subway under the table).
        let hidden: Bool
        /// Into the Forest Gate: the ball leaves the table at the end and the visit ends.
        var exits = false
        var total: CGFloat { cumulative.last ?? 0 }
    }

    /// A scoop: catches a floor ball whose path passes within `radius` of `center`, holds it, then lets it go.
    private struct Scoop {
        enum Kind { case well, log }
        let kind: Kind
        let center: CGPoint
        let radius: CGFloat
        var held: QfBall? = nil
        var releaseAt: TimeInterval = 0
        var ignored: QfBall? = nil
        var ignoreUntil: TimeInterval = 0
    }

    /// One drop target of the Treant's bark.
    private struct Bark {
        let node: SKShapeNode
        let center: CGPoint
        var isDown = false
        var hitPending = false
    }

    private let game: QfGameState
    private let settings: GameSettings
    private let cameraRig = QfCameraRig()
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

    private var balls: [QfBall] = []
    private var rides: [Ride] = []
    private var slingshots: [QfSlingshot] = []
    private var leftFlipper: QfFlipper!
    private var rightFlipper: QfFlipper!
    private var plunger: SKShapeNode!
    private var isBuilt = false
    private let hitHaptic = Haptic(style: .medium)

    // Targets (placeholders until the fights): the trunk and the East lantern, a short cooldown and a flash each.
    private var targets: [(node: SKShapeNode, name: String)] = []
    private var targetLastHit: [String: TimeInterval] = [:]
    private var targetFlashUntil: [String: TimeInterval] = [:]
    private var bark: [Bark] = []
    private var barkDownAt: TimeInterval?
    private var treantHP = QfMonsterHP.treant
    private var scoops: [Scoop] = []
    private var spinnerFlash: SKShapeNode?
    private var digSpins: CGFloat = 0
    private var lastSpinAt: TimeInterval = 0
    private var hpLostLast = 0
    private var ramps: [QfRamp] = []
    private var oldRoad: QfRamp!
    /// Monsters defeated this visit, and whether the exit (the Forest Gate on the Old Road) is lit.
    private var defeats = 0
    private var exitLit = false
    private var forestGate: SKShapeNode!
    #if DEBUG
    /// DEBUG `-questRampProbe`: balls fired up the Old Road's mouth at rising speeds; prints what each one does.
    private var probeSpeeds: [CGFloat] = []
    private var probeNextAt: TimeInterval = 0
    private var probeSpeed: CGFloat = 0
    #endif

    // Plunger and input
    private var plungerStartY: CGFloat = 0
    private var plungerPull: CGFloat = 0
    private var activeTouches: [UITouch: Control] = [:]
    private let nudge = Nudge()
    private var padLeft = false
    private var padRight = false
    private var padAArmed = false
    private var padPulling = false
    private var padPeakPull: CGFloat = 0
    private var padPullByA = false

    // Game clock: advances by the clamped frame time only, so pauses and hitches never eat timers.
    private var lastRealTime: TimeInterval?
    private var gameTime: TimeInterval = 0
    private var nextBallAt: TimeInterval?
    private var bannerClearAt: TimeInterval?

    /// The menu: physics stopped, touches ignored.
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
            if isGamePaused { releaseNonTouchControls() }
            isPaused = isGamePaused
            lastRealTime = nil
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    // Grey-box colours (the skill's): green walls on near-black, orange for anything that kicks or is one-way,
    // silver for wires, gold for targets, a translucent green band for ramp plastic.
    static let wallColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
    static let floorColor = SKColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
    static let islandColor = SKColor(red: 0.07, green: 0.14, blue: 0.10, alpha: 1)
    static let kickColor = SKColor(red: 1.0, green: 0.60, blue: 0.24, alpha: 1)
    static let wireColor = SKColor(white: 0.78, alpha: 0.75)
    static let targetColor = SKColor(red: 1.0, green: 0.82, blue: 0.42, alpha: 1)
    static let barkColor = SKColor(red: 0.79, green: 0.54, blue: 0.29, alpha: 1)
    static let wispColor = SKColor(red: 0.50, green: 0.89, blue: 1.0, alpha: 1)
    static let labelColor = SKColor(white: 1, alpha: 0.35)
    static let buildTagText = "T9 M1 v2"

    init(game: QfGameState, settings: GameSettings) {
        self.game = game
        self.settings = settings
        super.init(size: QfTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: QfTableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        buildTable()
        addBuildTag()
        refreshCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        refreshCamera()
    }

    /// The table menu is shown Top-Down; play uses the saved camera (Flying, Wide or Top-Down).
    private var effectiveCameraMode: CameraMode { isAttractMode ? .topDown : settings.cameraMode }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        placeBuildTag()
    }

    // MARK: - Table

    private func buildTable() {
        typealias F = QfForestLayout
        addFloor()
        addWall(points: F.outerWall, friction: QfTableLayout.railFriction, restitution: QfTableLayout.railRestitution)
        addWall(points: F.rightWall)
        addWall(points: F.shooterLaneWall)
        for pts in [F.laneGuideLeft, F.laneGuideRight, F.outlaneWallLeft, F.outlaneWallRight,
                    F.outlanePostRailLeft, F.outlanePostRailRight, F.wellLowerRim, F.wellRoof, F.lanternBlock] {
            addWall(points: pts)
        }
        addWall(points: F.island, fill: Self.islandColor)
        for p in [F.laneGuidePostLeft, F.laneGuidePostRight, F.outlanePostLeft, F.outlanePostRight] {
            addPost(at: p, radius: F.laneGuidePostRadius)
        }
        for p in F.wellPosts { addPost(at: p, radius: F.wellPostRadius) }
        for p in F.laneMouthPosts + [F.orbitPost] { addPost(at: p, radius: F.postRadius) }

        for s in [F.slingLeft, F.slingRight] {
            let sling = QfSlingshot(top: s[0], corner: s[1], tip: s[2], artBaked: false,
                                    kickFrom: QfTableLayout.slingKickFrom, kickTo: QfTableLayout.slingKickTo)
            addChild(sling)
            slingshots.append(sling)
        }
        hitHaptic.prepare()

        leftFlipper = QfFlipper(side: .left, pivot: F.pivotLeft)
        rightFlipper = QfFlipper(side: .right, pivot: F.pivotRight)
        leftFlipper.attach(to: self)
        rightFlipper.attach(to: self)

        addPlunger()
        addLaunchGate()
        addTarget(name: "TRUNK", face: F.trunkFace)
        addTarget(name: "EAST LANTERN", face: F.lanternFace)
        addBark()
        scoops = [Scoop(kind: .well, center: F.wellHole, radius: F.wellCaptureRadius),
                  Scoop(kind: .log, center: F.logHole, radius: F.logCaptureRadius)]
        for s in scoops { addHole(at: s.center) }
        addSpinner()
        addOldRoad()
        addForestGate()
        addDrawnGlade()
        addAreaLabels()
    }

    private func addFloor() {
        let path = CGMutablePath()
        path.addLines(between: QfForestLayout.outerWall)
        path.closeSubpath()
        let floor = SKShapeNode(path: path)
        floor.fillColor = Self.floorColor
        floor.strokeColor = .clear
        floor.zPosition = -20
        addChild(floor)
    }

    private func addWall(points: [CGPoint],
                         friction: CGFloat = QfTableLayout.wallFriction,
                         restitution: CGFloat = QfTableLayout.wallRestitution,
                         fill: SKColor? = nil,
                         z: CGFloat = -19.5) {
        // A closed outline (last point = first) is an edge LOOP (CHOMP! M3 v13b: an edge chain lost its closing edge).
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
        node.fillColor = fill ?? .clear
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        let body = closed ? SKPhysicsBody(edgeLoopFrom: path) : SKPhysicsBody(edgeChainFrom: path)
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = QfPhysicsCategory.wall
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    private func addPost(at p: CGPoint, radius r: CGFloat) {
        let post = SKShapeNode(circleOfRadius: r)
        post.position = p
        post.fillColor = SKColor(white: 0.85, alpha: 1)
        post.strokeColor = Self.wallColor
        post.lineWidth = 1.5
        post.zPosition = -19
        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = QfTableLayout.postRestitution
        body.friction = 0.2
        body.categoryBitMask = QfPhysicsCategory.wall
        body.collisionBitMask = QfPhysicsCategory.ball
        post.physicsBody = body
        addChild(post)
    }

    private func addPlunger() {
        let size = QfTableLayout.plungerSize
        let node = SKShapeNode(rectOf: size, cornerRadius: 4)
        node.fillColor = SKColor(white: 0.65, alpha: 1)
        node.strokeColor = .clear
        node.position = QfTableLayout.plungerRestPosition
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = QfPhysicsCategory.wall
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        plunger = node
    }

    /// The one-way flap at the top of the shooter lane: solid only for a ball above it (QfBall.launchGateSolid).
    private func addLaunchGate() {
        let (a, b) = QfForestLayout.launchGate
        let path = CGMutablePath()
        path.addLines(between: [a, b])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.kickColor
        node.lineWidth = 4
        node.lineCap = .round
        node.zPosition = -18.5
        let body = SKPhysicsBody(edgeFrom: a, to: b)
        body.friction = 0.05
        body.restitution = 0.2
        body.categoryBitMask = QfPhysicsCategory.launchGate
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
    }

    /// A standup: a thick drawn face with an edge body (category target).
    private func addTarget(name: String, face: (CGPoint, CGPoint)) {
        let path = CGMutablePath()
        path.addLines(between: [face.0, face.1])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.targetColor
        node.lineWidth = 7
        node.lineCap = .round
        node.zPosition = -18
        let body = SKPhysicsBody(edgeFrom: face.0, to: face.1)
        body.restitution = QfTableLayout.wallRestitution
        body.friction = QfTableLayout.wallFriction
        body.categoryBitMask = QfPhysicsCategory.target
        body.collisionBitMask = QfPhysicsCategory.ball
        node.physicsBody = body
        addChild(node)
        targets.append((node: node, name: name))
    }

    private func addBark() {
        for c in QfForestLayout.barkCenters {
            let node = SKShapeNode(rectOf: QfForestLayout.barkSize, cornerRadius: 2)
            node.position = c
            node.fillColor = Self.barkColor
            node.strokeColor = .clear
            node.zPosition = -18
            node.physicsBody = Self.barkBody()
            addChild(node)
            bark.append(Bark(node: node, center: c))
        }
    }

    private static func barkBody() -> SKPhysicsBody {
        let body = SKPhysicsBody(rectangleOf: QfForestLayout.barkSize)
        body.isDynamic = false
        body.restitution = QfTableLayout.wallRestitution
        body.friction = QfTableLayout.wallFriction
        body.categoryBitMask = QfPhysicsCategory.target
        body.collisionBitMask = QfPhysicsCategory.ball
        return body
    }

    private func addHole(at p: CGPoint) {
        let hole = SKShapeNode(circleOfRadius: 15)
        hole.position = p
        hole.fillColor = .black
        hole.strokeColor = Self.targetColor
        hole.lineWidth = 2
        hole.zPosition = -18.8
        addChild(hole)
    }

    private func addSpinner() {
        let (a, b) = QfForestLayout.spinnerLine
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: a.x + 3, y: a.y), CGPoint(x: b.x - 3, y: b.y)])
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.kickColor
        node.lineWidth = 4
        node.zPosition = -18
        addChild(node)
        spinnerFlash = node
    }

    /// The Old Road (CHOMP!'s ramp class): its plastic climbs from the mouth up through the island (whose solid U is
    /// the low end for floor balls, so no U of its own here), hooks right over the glade, and its wire runs down the
    /// right lane into the right inlane.
    private func addOldRoad() {
        let ramp = QfRamp(path: QfTableLayout.oldRoadPath, apexDistance: QfForestLayout.rampApexDistance,
                          mouthHalfWidth: QfForestLayout.rampMouthHalfWidth,
                          halfWidth: QfForestLayout.rampChannelHalfWidth,
                          flareLength: 60, postLength: 0, lowLength: 0)
        addChild(ramp)
        ramps.append(ramp)
        oldRoad = ramp
    }

    /// The Forest Gate beside the Old Road's hook: dark until the exit lights, then a blinking gold ring.
    private func addForestGate() {
        let gate = SKShapeNode(circleOfRadius: 16)
        gate.position = QfForestLayout.forestGate
        gate.strokeColor = Self.targetColor.withAlphaComponent(0.35)
        gate.fillColor = SKColor(white: 0.05, alpha: 1)
        gate.lineWidth = 2
        gate.zPosition = 19                                     // under the Old Road's art (z 20–21), which crosses it
        addChild(gate)
        forestGate = gate
    }

    /// The wisps' home in the glade (drawn only until the wisps move, next rounds).
    private func addDrawnGlade() {
        for w in QfForestLayout.wisps {
            let dot = SKShapeNode(circleOfRadius: QfForestLayout.wispRadius)
            dot.position = w.0
            dot.fillColor = Self.wispColor.withAlphaComponent(0.18)
            dot.strokeColor = Self.wispColor.withAlphaComponent(0.5)
            dot.lineWidth = 1
            dot.zPosition = -18.5
            addChild(dot)
        }
    }

    private func addAreaLabels() {
        typealias F = QfForestLayout
        let items: [(String, CGPoint)] = [
            ("OLD WELL", CGPoint(x: 78, y: 690)), ("GRAVEYARD", CGPoint(x: 46, y: 1000)),
            ("HOLLOW LOG", CGPoint(x: F.logHole.x, y: 960)), ("TREANT", CGPoint(x: F.centerX, y: 1052)),
            ("OLD ROAD", CGPoint(x: F.rampCenterX, y: 940)), ("WITCH'S GLADE", CGPoint(x: 318, y: 1290)),
            ("FOREST GATE", CGPoint(x: F.forestGate.x - 4, y: F.forestGate.y + 26)),
        ]
        for (text, p) in items {
            let label = SKLabelNode(text: text)
            label.fontName = "Menlo-Bold"
            label.fontSize = text == "GRAVEYARD" ? 8 : 11
            label.fontColor = Self.labelColor
            label.verticalAlignmentMode = .center
            label.position = p
            label.zPosition = 17
            if text == "GRAVEYARD" { label.zRotation = .pi / 2 }
            addChild(label)
        }
    }

    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: Self.buildTagText)
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
        let text = "\(fps)\(Self.buildTagText) · \(speed) · treant \(treantHP) · dig \(Int(digSpins))"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: QfBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func removeBall(_ ball: QfBall) {
        rides.removeAll(where: { $0.ball === ball })
        for i in scoops.indices where scoops[i].held === ball { scoops[i].held = nil }
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
    }

    private func removeAllBalls() {
        rides.removeAll()
        for i in scoops.indices { scoops[i].held = nil; scoops[i].ignored = nil }
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
    }

    private func placeBallOnPlunger() {
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // a tilt ends here
        let r = QfTableLayout.ballRadius
        let ball = QfBall(at: CGPoint(x: QfTableLayout.laneCenterX, y: QfTableLayout.plungerRestTop + r + 2))
        addChild(ball)
        balls.append(ball)
    }

    private func isOnPlunger(_ ball: QfBall) -> Bool {
        ball.isOnFloor && ball.position.x > QfForestLayout.laneWallX
            && ball.position.y < QfTableLayout.plungerRestTop + QfTableLayout.ballRadius * 3
    }

    private var plungerBall: QfBall? { balls.first(where: { isOnPlunger($0) }) }
    private var isBallOnPlunger: Bool { plungerBall != nil }

    /// Snaps the plunger back without a launch; a ball resting on the pulled plunger goes back on top of it (review:
    /// it would otherwise end up inside the plunger's body and be pushed through the lane floor).
    private func resetPlungerKeepingBall() {
        if plungerPull > 0, let b = plungerBall {
            b.position.y = QfTableLayout.plungerRestTop + QfTableLayout.ballRadius + 2
            b.physicsBody?.velocity = .zero
        }
        plungerPull = 0
        plunger?.position = QfTableLayout.plungerRestPosition
    }

    private func releasePlunger() {
        let power = plungerPull < 4 ? QfTableLayout.tapLaunchPower : plungerPull / QfTableLayout.plungerMaxPull
        if let body = plungerBall?.physicsBody {
            let speed = QfTableLayout.minLaunchSpeed
                + pow(power, QfTableLayout.plungePowerExponent) * (QfTableLayout.maxLaunchSpeed - QfTableLayout.minLaunchSpeed)
            body.velocity = CGVector(dx: 0, dy: speed)
            sfx(.launch)
        }
        plunger.run(.move(to: QfTableLayout.plungerRestPosition, duration: 0.04))
        plungerPull = 0
    }

    /// Puts a ball on a scripted ride (collisions and gravity off) from where it is along `path`.
    private func startRide(_ ball: QfBall, path: [CGPoint], speed: CGFloat, release: CGVector, hidden: Bool,
                           exits: Bool = false) {
        ball.setLayer(.ride)
        ball.physicsBody?.velocity = .zero
        if hidden { ball.alpha = 0 }
        var cumulative: [CGFloat] = [0]
        for i in 1..<max(path.count, 1) {
            cumulative.append(cumulative[i - 1] + hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y))
        }
        rides.append(Ride(ball: ball, path: path, cumulative: cumulative, speed: speed, release: release, hidden: hidden,
                          exits: exits))
    }

    private func updateRides(_ dt: CGFloat) {
        var finished: [Int] = []
        for i in rides.indices {
            rides[i].s += rides[i].speed * dt
            let ride = rides[i]
            let s = min(ride.s, ride.total)
            var k = 1
            while k < ride.cumulative.count - 1 && ride.cumulative[k] < s { k += 1 }
            let a = ride.path[k - 1], b = ride.path[min(k, ride.path.count - 1)]
            let seg = max(ride.cumulative[min(k, ride.cumulative.count - 1)] - ride.cumulative[k - 1], 0.001)
            let f = min(max((s - ride.cumulative[k - 1]) / seg, 0), 1)
            ride.ball.position = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            ride.ball.physicsBody?.velocity = .zero
            if ride.s >= ride.total { finished.append(i) }
        }
        for i in finished.reversed() {
            let ride = rides.remove(at: i)
            if ride.exits {
                leaveForest(ride.ball)
                continue
            }
            ride.ball.alpha = 1
            ride.ball.rampHeight = 0
            ride.ball.setLayer(.floor)
            ride.ball.physicsBody?.velocity = ride.release
            ride.ball.previousPosition = ride.ball.position
        }
    }

    func newGame() {
        fpsLow = 0
        isAttractMode = false
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        targetLastHit = [:]
        treantHP = QfMonsterHP.treant
        digSpins = 0
        defeats = 0
        setExitLit(false)
        raiseBark()
        game.reset()
        updateStatus()
        padAArmed = false                          // the A press that started the game isn't a plunger pull
        plungerPull = 0
        plunger.position = QfTableLayout.plungerRestPosition
        placeBallOnPlunger()
        refreshCamera()
    }

    private func showBanner(_ text: String) {
        game.banner = text
        bannerClearAt = gameTime + QfTableLayout.bannerSeconds
    }

    private func updateStatus() {
        if exitLit {
            game.status = "EXIT LIT · THE OLD ROAD LEAVES THE FOREST"
        } else {
            game.status = "TREANT \(treantHP)/\(QfMonsterHP.treant) · BREAK THE BARK"
        }
    }

    private func sfx(_ s: MonSound) {
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView, !isAttractMode else { return }
        for touch in touches {
            let p = touch.location(in: view)   // screen points: the camera moves the table
            if isBallOnPlunger, !activeTouches.values.contains(.plunger), isInPlungerZone(p, of: view) {
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
        return p.x > b.width * QfTableLayout.plungerZoneMinX && p.y > b.height * QfTableLayout.plungerZoneMinY
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView else { return }
        for touch in touches {
            let p = touch.location(in: view)
            switch activeTouches[touch] {
            case .plunger:
                let dragged = (p.y - plungerStartY) * cameraRig.node.yScale
                plungerPull = min(max(dragged, 0), QfTableLayout.plungerMaxPull)
                plunger.position.y = QfTableLayout.plungerRestPosition.y - plungerPull
            case .left, .right:
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
        if left && !leftFlipper.isPressed { sfx(.flipper) }
        if right && !rightFlipper.isPressed { sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
    }

    private func applyNudge(_ direction: Nudge.Direction) {
        guard !isAttractMode, !game.isGameOver else { return }
        let free = balls.filter { $0.isOnFloor && !isOnPlunger($0) }
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
            updateFlippers()
        }
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        resetPlungerKeepingBall()
        if leftFlipper != nil { updateFlippers() }
    }

    /// Pausing (Table 06's fix): a flipper finger still down stays held, so a cradled ball is still cradled after
    /// resume. The plunger pull and the gamepad let go.
    private func releaseNonTouchControls() {
        for (touch, kind) in activeTouches where kind == .plunger { activeTouches.removeValue(forKey: touch) }
        padLeft = false
        padRight = false
        padPulling = false
        padPeakPull = 0
        resetPlungerKeepingBall()
        if leftFlipper != nil { updateFlippers() }
    }

    /// Game controller (CHOMP!'s): shoulders/triggers flip, A held or the right stick pulled down works the plunger.
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
            plungerPull = pull * QfTableLayout.plungerMaxPull
            plunger.position.y = QfTableLayout.plungerRestPosition.y - plungerPull
        } else if padPulling {
            padPulling = false
            let peak = padPeakPull * QfTableLayout.plungerMaxPull
            let byA = padPullByA
            padPeakPull = 0
            padPullByA = false
            if isBallOnPlunger, !touchPlunger {
                if byA || peak >= 4 {
                    plungerPull = peak
                    releasePlunger()
                } else {
                    plungerPull = 0
                    plunger.position = QfTableLayout.plungerRestPosition
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
        #if DEBUG
        updateRampProbe(now)
        #endif
        updateGamepad()
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        updateRides(dt)
        handBallsToSwingingFlippers()
        slingshots.forEach { $0.settle() }
        governInlanes()
        updateScoops(now)
        updateBark(now)
        let onPlunger = isBallOnPlunger
        if game.ballOnPlunger != onPlunger { game.ballOnPlunger = onPlunger }

        for t in targets {
            if let until = targetFlashUntil[t.name], now >= until {
                targetFlashUntil[t.name] = nil
                t.node.strokeColor = Self.targetColor
            }
        }
        if now - lastSpinAt > 0.15 { spinnerFlash?.strokeColor = Self.kickColor }

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // A drain costs HP (the run's drain damage less armour); zero HP ends the game.
        let drained = balls.filter { $0.isOnFloor && $0.position.y < QfForestLayout.drainLineY }
        if !drained.isEmpty {
            drained.forEach { removeBall($0) }
            cameraRig.shake(strength: 3, duration: 0.25)
            sfx(.drain)
            if balls.isEmpty, nextBallAt == nil, !game.isGameOver {
                let lost = game.ballDrained()
                showBanner(game.isGameOver ? "THE FOREST TAKES YOU" : "−\(lost) HP · \(game.hp) LEFT")
                if !game.isGameOver { nextBallAt = now + 0.8 }
            }
        }

        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            placeBallOnPlunger()
        }
    }

    /// A floor ball within reach of a flipper swinging up this frame belongs to the flipper model for the physics step.
    private func handBallsToSwingingFlippers() {
        guard QfTableLayout.flipperModel else { return }
        let r = QfTableLayout.ballRadius
        for ball in balls where ball.isOnFloor {
            for f in [leftFlipper!, rightFlipper!] where f.isSwingingUp && f.reaches(ball.position, ballRadius: r) {
                ball.flipperGhostSteps = max(ball.flipperGhostSteps, 1)
            }
        }
    }

    /// Hot inlane feeds: a ball rolling down an inlane is held to InlaneGovernor.maxSpeed so a held flipper can trap it.
    private func governInlanes() {
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody,
                  let v = InlaneGovernor.limited(body.velocity, at: ball.position,
                                                 leftGuide: QfTableLayout.governorGuide,
                                                 mirrorSum: QfTableLayout.mirrorSum) else { continue }
            body.velocity = v
        }
    }

    // MARK: - Scoops

    /// Catches by path (the scoop rule): a floor ball whose path this frame passed within the radius. The Old Well's
    /// cavity is a catch zone too (no ball rests behind its rim).
    private func catchInScoops(_ ball: QfBall, from p0: CGPoint, to p: CGPoint) {
        guard ball.isOnFloor else { return }
        for i in scoops.indices where scoops[i].held == nil {
            if scoops[i].ignored === ball, gameTime < scoops[i].ignoreUntil { continue }
            let c = scoops[i].center
            let dx = p.x - p0.x, dy = p.y - p0.y
            let t = max(0, min(1, ((c.x - p0.x) * dx + (c.y - p0.y) * dy) / max(dx * dx + dy * dy, 0.001)))
            let q = CGPoint(x: p0.x + dx * t, y: p0.y + dy * t)
            let inWell = scoops[i].kind == .well && Self.inside(p, QfForestLayout.wellCavity)
            guard hypot(q.x - c.x, q.y - c.y) < scoops[i].radius || inWell else { continue }
            scoops[i].held = ball
            scoops[i].releaseAt = gameTime + QfTableLayout.scoopHold
            ball.setLayer(.ride)
            ball.position = c
            ball.physicsBody?.velocity = .zero
            game.add(QfPoints.scoop)
            sfx(.scoopIn)
            hitHaptic.impactOccurred(intensity: 0.8)
            switch scoops[i].kind {
            case .well: showBanner("OLD WELL · SEARCHED")
            case .log: showBanner("HOLLOW LOG · SEARCHED")
            }
            return
        }
    }

    private func updateScoops(_ now: TimeInterval) {
        for i in scoops.indices {
            guard let ball = scoops[i].held else { continue }
            ball.position = scoops[i].center
            ball.physicsBody?.velocity = .zero
            guard now >= scoops[i].releaseAt else { continue }
            scoops[i].held = nil
            scoops[i].ignored = ball
            scoops[i].ignoreUntil = now + QfTableLayout.scoopRecapture
            sfx(.scoopOut)
            switch scoops[i].kind {
            case .log:
                ball.setLayer(.floor)
                ball.physicsBody?.velocity = QfForestLayout.logEject
                ball.previousPosition = ball.position
            case .well:
                // The subway under the table to the left inlane; it comes out heading straight down.
                let release = QfForestLayout.inlaneReleaseLeft
                startRide(ball, path: [scoops[i].center, release], speed: QfTableLayout.subwaySpeed,
                          release: CGVector(dx: 0, dy: -QfTableLayout.inlaneReleaseSpeed), hidden: true)
            }
        }
    }

    // MARK: - The Treant's bark

    private func updateBark(_ now: TimeInterval) {
        var dropped = false
        for i in bark.indices where bark[i].hitPending {
            bark[i].hitPending = false
            guard !bark[i].isDown else { continue }
            bark[i].isDown = true
            bark[i].node.physicsBody = nil
            bark[i].node.alpha = 0.18
            dropped = true
        }
        if dropped, bark.allSatisfy({ $0.isDown }) {
            barkDownAt = now
            showBanner("BARK BROKEN · HIT THE TRUNK")
            game.add(QfPoints.bark)
        }
        if let down = barkDownAt, now - down >= QfTableLayout.barkRegrow {
            if raiseBark() { showBanner("THE BARK GROWS BACK") }
        }
    }

    /// Raises every fallen bark drop unless a ball sits where it would rise (then it tries again next frame).
    @discardableResult
    private func raiseBark() -> Bool {
        let r = QfTableLayout.ballRadius + 2
        let half = CGSize(width: QfForestLayout.barkSize.width / 2 + r, height: QfForestLayout.barkSize.height / 2 + r)
        for b in bark where b.isDown {
            if balls.contains(where: { abs($0.position.x - b.center.x) < half.width && abs($0.position.y - b.center.y) < half.height }) {
                return false
            }
        }
        for i in bark.indices {
            bark[i].hitPending = false
            if bark[i].isDown {
                bark[i].isDown = false
                bark[i].node.physicsBody = Self.barkBody()
                bark[i].node.alpha = 1
            }
        }
        barkDownAt = nil
        return true
    }

    // MARK: - The Old Road and the Forest Gate

    /// The ramps' switches, from the ball's move this frame (CHOMP!'s updateRampLayer): the entry puts a floor ball on
    /// the ramp (backward = it fell back out), the made switch just past the top scores it, the exit at the end of the
    /// wire puts it back on the floor. A ramp ball found far from its channel drops to the floor (the safety net).
    private func updateRampLayer(_ ball: QfBall, from p0: CGPoint, to p: CGPoint) {
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
        case .floor, .ride:
            return
        case .rampUp:
            if ramp.entrySwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.floor)
                probeLog("BACK", p)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.rampDown)
                rampMade(ball, ramp)
                if ball.layer == .ride { return }              // into the Forest Gate
            }
        case .rampDown:
            if ramp.exitSwitch.crossing(from: p0, to: p) == .forward {
                ball.setLayer(.floor)
                probeLog("EXIT", p, ball.physicsBody?.velocity)
            } else if ramp.madeSwitch.crossing(from: p0, to: p) == .backward {
                ball.setLayer(.rampUp)
            }
        }
        if !ball.isOnFloor, ramp.distanceToCenterline(p) > ramp.maxHalfWidth + QfTableLayout.ballRadius + 12 {
            ball.setLayer(.floor)
        }
    }

    /// The Old Road made: with the exit lit the ball turns into the Forest Gate (the visit ends); otherwise it scores
    /// and rides the wire back to the right inlane.
    private func rampMade(_ ball: QfBall, _ ramp: QfRamp) {
        probeLog("MADE", ball.position, ball.physicsBody?.velocity)
        if exitLit, !game.isGameOver {
            ball.rampHeight = QfTableLayout.rampTopHeight
            startRide(ball, path: [ball.position, QfForestLayout.forestGate], speed: QfTableLayout.gateRideSpeed,
                      release: .zero, hidden: false, exits: true)
            showBanner("THE FOREST GATE")
            sfx(.scoopIn)
            hitHaptic.impactOccurred()
            return
        }
        game.add(QfPoints.ramp)
        showBanner("OLD ROAD")
        sfx(.ramp)
        hitHaptic.impactOccurred()
    }

    /// A monster beaten (the Treant, for now). Enough of them light the exit.
    private func monsterDefeated() {
        defeats += 1
        if !exitLit, defeats >= QfTableLayout.exitAfterDefeats {
            setExitLit(true)
            // after the defeat's own banner (review: TREANT FELLED was overwritten at once)
            run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.showBanner("THE FOREST GATE OPENS") }]))
        }
        updateStatus()
    }

    private func setExitLit(_ lit: Bool) {
        exitLit = lit
        guard let gate = forestGate else { return }
        gate.removeAction(forKey: "blink")
        if lit {
            gate.strokeColor = Self.targetColor
            gate.fillColor = Self.targetColor.withAlphaComponent(0.25)
            gate.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])),
                     withKey: "blink")
        } else {
            gate.strokeColor = Self.targetColor.withAlphaComponent(0.35)
            gate.fillColor = SKColor(white: 0.05, alpha: 1)
            gate.alpha = 1
        }
    }

    /// The ball reached the Forest Gate: it leaves the table and the visit ends with the HP the player still has.
    private func leaveForest(_ ball: QfBall) {
        probeLog("GATE", ball.position)
        removeBall(ball)
        nextBallAt = nil
        game.leaveForest()
        showBanner("YOU LEAVE THE FOREST")
        cameraRig.shake(strength: 2, duration: 0.2)
    }

    // MARK: - DEBUG ramp probe

    func debugStartRampProbe() {
        #if DEBUG
        newGame()
        game.isRobot = true                                     // a probe never records a high score
        if ProcessInfo.processInfo.arguments.contains("-questExitLit") { setExitLit(true) }   // test the Forest Gate
        removeAllBalls()
        probeSpeeds = stride(from: CGFloat(600), through: 2000, by: 100).map { $0 }
        probeNextAt = gameTime + 0.5
        #endif
    }

    private func probeLog(_ what: String, _ p: CGPoint, _ v: CGVector? = nil) {
        #if DEBUG
        guard probeSpeed > 0 else { return }
        let sp = v.map { Int(hypot($0.dx, $0.dy)) } ?? 0
        print("RAMPPROBE \(Int(probeSpeed)) \(what) x \(Int(p.x)) y \(Int(p.y)) v \(sp) t \(String(format: "%.2f", gameTime - (probeNextAt - 3)))")
        #endif
    }

    #if DEBUG
    private func updateRampProbe(_ now: TimeInterval) {
        guard probeSpeed > 0 || !probeSpeeds.isEmpty, now >= probeNextAt else { return }
        removeAllBalls()
        guard !probeSpeeds.isEmpty else { probeSpeed = 0; print("RAMPPROBE DONE"); return }
        probeSpeed = probeSpeeds.removeFirst()
        let ball = QfBall(at: CGPoint(x: QfForestLayout.rampCenterX, y: QfForestLayout.rampMouthY - 20))
        addChild(ball)
        balls.append(ball)
        ball.physicsBody?.velocity = CGVector(dx: 0, dy: probeSpeed)
        probeNextAt = now + 3
    }
    #endif

    // MARK: - Physics frame

    /// The solid blocks (closed outlines): a floor ball whose centre ends up inside one is put back just outside its
    /// nearest edge, with any velocity into that edge removed (CHOMP! M3 v13).
    private let solidBlocks: [[CGPoint]] = [QfForestLayout.island]

    private static func inside(_ p: CGPoint, _ closed: [CGPoint]) -> Bool {
        let poly = closed.first == closed.last ? Array(closed.dropLast()) : closed
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    private func keepOutOfSolids(_ ball: QfBall) {
        let p = ball.position
        for closed in solidBlocks where closed.count > 3 && Self.inside(p, closed) {
            let poly = Array(closed.dropLast())
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
            let r = QfTableLayout.ballRadius + 0.5
            ball.position = CGPoint(x: q.x + n.dx * r, y: q.y + n.dy * r)
            if let body = ball.physicsBody {
                let v = body.velocity
                let vn = v.dx * n.dx + v.dy * n.dy
                if vn < 0 { body.velocity = CGVector(dx: v.dx - vn * n.dx, dy: v.dy - vn * n.dy) }
            }
            return
        }
    }

    /// Which side of the launch gate's line a point is on (> 0 = above it, the playfield side).
    private static func aboveLaunchGate(_ p: CGPoint) -> Bool {
        let (a, b) = QfForestLayout.launchGate
        return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) > 0
    }

    override func didSimulatePhysics() {
        typealias F = QfForestLayout
        let r = QfTableLayout.ballRadius
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if ball.flipperGhostSteps > 0 { ball.flipperGhostSteps -= 1 }
            let p0 = ball.previousPosition
            if ball.layer != .ride {
                updateRampLayer(ball, from: p0, to: ball.position)
                if ball.layer != .ride {                       // (the Forest Gate ride keeps the ramp's height)
                    ball.rampHeight = ball.isOnFloor ? 0 : (ball.activeRamp?.height(at: ball.position) ?? 0)
                }
                if !ball.isOnFloor, ball.layer != .ride {
                    let v = body.velocity
                    let speed = hypot(v.dx, v.dy)
                    if speed > QfTableLayout.maxBallSpeed {
                        body.velocity = CGVector(dx: v.dx * QfTableLayout.maxBallSpeed / speed,
                                                 dy: v.dy * QfTableLayout.maxBallSpeed / speed)
                    }
                }
            }
            if ball.isOnFloor {
                leftFlipper.solveSwing(ball, ballRadius: r)
                rightFlipper.solveSwing(ball, ballRadius: r)
                keepOutOfSolids(ball)
                let v = body.velocity
                let speed = hypot(v.dx, v.dy)
                if speed > QfTableLayout.maxBallSpeed {
                    let scale = QfTableLayout.maxBallSpeed / speed
                    body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
                }
                let p = ball.position
                // The launch gate is solid only for a ball on its playfield side (a plunge passes up through it).
                ball.setLaunchGateSolid(p.x > F.laneWallX - 40 && Self.aboveLaunchGate(p))
                // The Graveyard spinner: every crossing digs (spins from the ball's speed).
                let (sa, sb) = F.spinnerLine
                if (p0.y - sa.y) * (p.y - sa.y) < 0, p.x > sa.x, p.x < sb.x {
                    let spins = max(1, hypot(v.dx, v.dy) / 250)
                    digSpins += spins
                    lastSpinAt = gameTime
                    spinnerFlash?.strokeColor = .white
                    game.add(QfPoints.spin * Int(spins.rounded()))
                    sfx(.spinner)
                    showBanner("GRAVEYARD · DIG \(Int(digSpins))")
                }
                // The Graveyard orbit made: crossing the line along the top of the arch going right.
                let (oa, ob) = F.orbitMadeLine
                if p0.x < oa.x, p.x >= oa.x, p.y > oa.y, p.y < ob.y, p.y > 1270 {
                    game.add(QfPoints.orbit)
                    sfx(.orbit)
                    showBanner("GRAVEYARD ORBIT")
                }
                catchInScoops(ball, from: p0, to: p)
            }
            ball.previousPosition = ball.position
            ball.previousVelocity = body.velocity
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
        let ballish = QfPhysicsCategory.ball | QfPhysicsCategory.ghostBall
        if a.categoryBitMask & ballish != 0 {
            ballBody = a; other = b
        } else if b.categoryBitMask & ballish != 0 {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? QfBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case QfPhysicsCategory.slingshot:
            if let sling = node.parent as? QfSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                game.add(QfPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                Effects.burst(in: self, at: ballNode.position, color: Self.wallColor, count: 8,
                              speed: 160, lifetime: 0.25, size: 0.22)
                sfx(.sling)
            }
        case QfPhysicsCategory.target:
            let impact = hypot(ballNode.previousVelocity.dx, ballNode.previousVelocity.dy)
            let damage = QfDamage.of(impactSpeed: impact, strength: game.run.ballStrength)
            if let i = bark.firstIndex(where: { $0.node === node }) {
                guard !bark[i].isDown, !bark[i].hitPending else { break }
                bark[i].hitPending = true                     // drops in update()
                game.add(QfPoints.target)
                sfx(.standup)
                hitHaptic.impactOccurred(intensity: 0.7)
                break
            }
            guard let t = targets.first(where: { $0.node === node }) else { break }
            if let last = targetLastHit[t.name], gameTime - last < 0.15 { break }
            targetLastHit[t.name] = gameTime
            sfx(.standup)
            hitHaptic.impactOccurred(intensity: 0.7)
            t.node.strokeColor = .white                     // back to its colour in update()
            targetFlashUntil[t.name] = gameTime + 0.12
            if t.name == "TRUNK" {
                guard bark.allSatisfy({ $0.isDown }) else {
                    showBanner("THE BARK HOLDS")
                    break
                }
                treantHP = max(0, treantHP - damage)
                game.add(QfPoints.target)
                if treantHP == 0 {
                    showBanner("TREANT FELLED")
                    game.add(QfPoints.treantFelled)
                    monsterDefeated()
                    cameraRig.shake(strength: 6, duration: 0.5)
                    treantHP = QfMonsterHP.treant              // M1 placeholder: a new Treant takes its place
                    barkDownAt = gameTime - QfTableLayout.barkRegrow + 1.5     // the bark rises again in 1.5 s
                } else {
                    showBanner("TRUNK −\(damage) · \(treantHP) HP LEFT")
                }
                updateStatus()
            } else {
                game.add(QfPoints.target)
                showBanner("\(t.name) · HIT \(damage)")
            }
        default:
            break
        }
    }
}

extension QfTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}
