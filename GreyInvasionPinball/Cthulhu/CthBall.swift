// Pinball Lab Table 03: copied from Grey Invasion's Ball (milestone 1) with the "Cth" prefix. Ramp, scoop
// and orbit state come back as those parts are built (milestones 3–4).
import SpriteKit
import CoreGraphics
import Foundation

/// Which level a ball is on: the playfield floor, climbing a ramp, or on a wire return.
enum CthBallLayer { case floor, rampUp, rampDown }

/// One ball in play. The node carries the physics body; `visual` is the look, so it can grow on a
/// ramp without resizing the body. Per-ball state lives here, so multiball works from the start.
final class CthBall: SKNode {
    /// The shaded steel ball (Grey Invasion's ball.png for now; Table 03's own comes with the art).
    /// Counter-rotated every frame so the highlight stays top-left while the body spins.
    let visual: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shadowOffset = CGVector(dx: 4, dy: -4)
    /// Milestone 2: in the oblique view the ball's centre (9 pt above the floor) draws this far up the table.
    private static let lift = CthTableLayout.ballRadius * CthTableLayout.oblique
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// Drawn this much bigger than the physics body (Grey Invasion M8 v3: true size looked too small).
    static let lookScale: CGFloat = 1.2
    private(set) var layer: CthBallLayer = .floor
    /// Art round 3: how high the ramp under this ball is (0 on the floor); the scene sets it each frame. The ball is
    /// drawn lifted by height × oblique (so it rides on the rendered ramp) and up to 15% bigger at the top.
    var rampHeight: CGFloat = 0
    private var drawnHeight: CGFloat = 0
    /// Where the ball was last frame (for line-crossing switches).
    var previousPosition: CGPoint
    /// The ramp this ball is on (nil on the floor).
    var activeRamp: CthRamp?
    /// The hole holding this ball, if any, and when it lets go.
    var heldIn: CthScoop? {
        // T3 M4 v2 (Aaron: a ball in the Library or Lagoon sat against the top of the ring): a ball resting in a
        // hole sits lower than one on the floor, so it gets no oblique lift, draws a little smaller and drops its
        // shadow, and so sits centred, sunk into the ring.
        didSet {
            guard (heldIn == nil) != (oldValue == nil) else { return }
            let inHole = heldIn != nil
            shadow.isHidden = inHole
            updateLook()
        }
    }
    var releaseAt: TimeInterval = 0
    var scoopIgnoreUntil: TimeInterval = 0
    /// Went up the orbit lane and hasn't come round the top or fallen back yet.
    var orbitArmed = false
    /// Crossed the right-outlane switch going down: this ball is draining via the right outlane (M7 v1).
    var inRightOutlane = false
    /// Whether the one-way orbit diverter is solid for this ball (true while it moves right).
    private(set) var diverterSolid = false
    /// Whether the one-way launch gate is solid for this ball (T3 M8 v3: while it's above the gate moving down).
    private(set) var launchGateSolid = false

    var isOnFloor: Bool { layer == .floor }

    init(at point: CGPoint) {
        let r = CthTableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * CthBall.lookScale, height: r * 2 * CthBall.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * CthBall.lookScale, height: r * 2.7 * CthBall.lookScale)
        shadow.zPosition = -5
        previousPosition = point
        super.init()
        position = point
        name = "ball"

        addChild(shadow)
        addChild(trail)
        addChild(visual)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = CthTableLayout.ballMass
        body.restitution = CthTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = CthPhysicsCategory.ball
        body.contactTestBitMask = CthPhysicsCategory.slingshot | CthPhysicsCategory.bumper
            | CthPhysicsCategory.rollover | CthPhysicsCategory.target | CthPhysicsCategory.toy
        physicsBody = body
        setLayer(.floor)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setLayer(_ newLayer: CthBallLayer) {
        layer = newLayer
        if newLayer == .floor { activeRamp = nil }
        zPosition = newLayer == .floor ? 10 : 30
        shadow.alpha = newLayer == .floor ? 1 : 0.6
        updateLook()
        updateCollisionMask()
    }

    /// Keeps the highlight and the shadow fixed in world space while the body rolls (after physics).
    func updateLook() {
        let a = -zRotation
        visual.zRotation = a
        // Ease toward the ramp's height so leaving a wire (or the Library's up-kick) doesn't jump.
        drawnHeight += (rampHeight - drawnHeight) * 0.35
        if abs(rampHeight - drawnHeight) < 0.05 { drawnHeight = rampHeight }
        let h = heldIn == nil ? drawnHeight : 0
        let lift = heldIn == nil ? Self.lift + h * CthTableLayout.oblique : 0
        visual.position = CGPoint(x: -lift * sin(a), y: lift * cos(a))
        visual.setScale(heldIn != nil ? 0.9 : 1 + 0.15 * h / CthTableLayout.rampTopHeight)
        // The shadow falls on the surface the ball rides on (the ramp's plastic, or the floor).
        shadow.zRotation = a
        let so = CGVector(dx: shadowOffset.dx, dy: shadowOffset.dy + h * CthTableLayout.oblique)
        shadow.position = CGPoint(x: so.dx * cos(a) - so.dy * sin(a),
                                  y: so.dx * sin(a) + so.dy * cos(a))
        if trail.targetNode == nil { trail.targetNode = scene }
        let v = physicsBody?.velocity ?? .zero
        let fast = hypot(v.dx, v.dy) > Self.trailMinSpeed
        let rate = fast ? Self.trailRate : 0
        if trail.particleBirthRate != rate { trail.particleBirthRate = rate }
    }

    func setDiverterSolid(_ solid: Bool) {
        guard solid != diverterSolid else { return }
        diverterSolid = solid
        updateCollisionMask()
    }

    func setLaunchGateSolid(_ solid: Bool) {
        guard solid != launchGateSolid else { return }
        launchGateSolid = solid
        updateCollisionMask()
    }

    private func updateCollisionMask() {
        guard let body = physicsBody else { return }
        body.categoryBitMask = layer == .floor ? CthPhysicsCategory.ball : CthPhysicsCategory.rampBall
        if layer == .floor {
            var mask = CthPhysicsCategory.wall | CthPhysicsCategory.flipper | CthPhysicsCategory.slingshot
                | CthPhysicsCategory.bumper | CthPhysicsCategory.target | CthPhysicsCategory.ball
                | CthPhysicsCategory.toy
            if diverterSolid { mask |= CthPhysicsCategory.diverter }
            if launchGateSolid { mask |= CthPhysicsCategory.launchGate }
            body.collisionBitMask = mask
        } else {
            body.collisionBitMask = CthPhysicsCategory.rampWall | CthPhysicsCategory.rampBall
        }
    }
}
