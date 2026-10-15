import SpriteKit
import CoreGraphics
import Foundation

/// Which level a ball is on: the playfield floor, climbing a ramp, or on a ramp's wire return.
enum BallLayer { case floor, rampUp, rampDown }

/// One ball in play (milestone 5: multiball). The node itself carries the physics body;
/// `visual` is the look, so it can grow on a ramp without resizing the body. Everything
/// that used to be a single scene-wide "the ball" value lives here, per ball.
final class Ball: SKNode {
    /// The shaded steel ball (M8 art round 2: ball.png). Counter-rotated every frame (updateLook)
    /// so the highlight stays top-left while the physics body spins.
    let visual: SKSpriteNode
    /// Soft shadow, offset down-right; farther (and fainter) while the ball is up on a ramp.
    private let shadow: SKSpriteNode
    private var shadowOffset = CGVector(dx: 4, dy: -4)
    /// Glowing trail (M9 round 3), only while the ball moves fast.
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// The sprite is drawn this much bigger than the physics body (M8 v3, Aaron: "the ball looks
    /// very small now"). Collisions are unchanged.
    static let lookScale: CGFloat = 1.2
    private(set) var layer: BallLayer = .floor
    /// The ramp this ball is on (nil on the floor).
    var activeRamp: Ramp?
    /// Where the ball was last frame, for the ramp switch crossings.
    var previousPosition: CGPoint
    /// The scoop holding this ball, if any, and when it lets go.
    var heldIn: Scoop?
    var releaseAt: TimeInterval = 0
    var scoopIgnoreUntil: TimeInterval = 0
    /// Went up the orbit lane and hasn't come round the top or fallen back yet (M7 v2).
    var orbitArmed = false
    /// Went down the right outlane (M7 v6): when it drains, the outlane save can bring it back.
    var inRightOutlane = false
    /// Caught by the Abduction scoop during Wave 3 (M7 round 3): a saved cow, so no ball lock.
    var lockBlocked = false
    /// Whether the one-way orbit diverter is solid for this ball (true while it moves right).
    private(set) var diverterSolid = false

    var isOnFloor: Bool { layer == .floor }

    init(at point: CGPoint) {
        let r = TableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * Ball.lookScale, height: r * 2 * Ball.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * Ball.lookScale, height: r * 2.7 * Ball.lookScale)
        shadow.zPosition = -5                       // under the ball, over the playfield art and lamps
        previousPosition = point
        super.init()
        position = point
        name = "ball"

        addChild(shadow)
        addChild(trail)
        addChild(visual)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = TableLayout.ballMass
        body.restitution = TableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true   // stops tunneling at speed
        body.categoryBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.slingshot | PhysicsCategory.bumper
            | PhysicsCategory.rollover | PhysicsCategory.target
        physicsBody = body
        setLayer(.floor)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Moves the ball between the floor and a ramp: which walls it hits, whether it draws
    /// above the ramp art, and a slightly bigger look while it's up on a ramp.
    func setLayer(_ newLayer: BallLayer) {
        layer = newLayer
        if newLayer == .floor { activeRamp = nil }
        zPosition = newLayer == .floor ? 10 : 30          // the ramp art sits at 20
        visual.setScale(newLayer == .floor ? 1 : 1.08)
        shadowOffset = newLayer == .floor ? CGVector(dx: 4, dy: -4) : CGVector(dx: 9, dy: -9)
        shadow.alpha = newLayer == .floor ? 1 : 0.7
        updateLook()
        updateCollisionMask()
    }

    /// Keeps the highlight and the shadow fixed in world space while the body rolls.
    /// Called after physics each frame.
    func updateLook() {
        let a = -zRotation
        visual.zRotation = a
        shadow.zRotation = a
        shadow.position = CGPoint(x: shadowOffset.dx * cos(a) - shadowOffset.dy * sin(a),
                                  y: shadowOffset.dx * sin(a) + shadowOffset.dy * cos(a))
        // Trail: particles live in the scene so they stay behind; on only while moving fast.
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

    private func updateCollisionMask() {
        guard let body = physicsBody else { return }
        // On a ramp the ball is a different category, so floor parts (the flippers above all)
        // don't react to it either.
        body.categoryBitMask = layer == .floor ? PhysicsCategory.ball : PhysicsCategory.rampBall
        // Balls bump each other on the same level (M5 v5, playtest: in multiball three balls
        // stacked on one flipper and looked like one). A floor ball and a ramp ball never touch.
        if layer == .floor {
            var mask = PhysicsCategory.wall | PhysicsCategory.flipper | PhysicsCategory.slingshot
                | PhysicsCategory.bumper | PhysicsCategory.target | PhysicsCategory.ball
            if diverterSolid { mask |= PhysicsCategory.diverter }
            body.collisionBitMask = mask
        } else {
            body.collisionBitMask = PhysicsCategory.rampWall | PhysicsCategory.rampBall
        }
    }
}
