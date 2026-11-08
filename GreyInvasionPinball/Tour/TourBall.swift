// Pinball Lab Table 06 (Orbit: Grand Tour): the ball, from Table 04's MonBall, trimmed for milestone 1 (floor only:
// the ramps and the Moon's upper layer come with milestones 3–4).
import SpriteKit
import CoreGraphics
import Foundation

/// One ball in play. The node carries the physics body; `visual` is the look. Per-ball state lives here, so
/// multiball works from the start.
final class TourBall: SKNode {
    /// The shaded steel ball (Grey Invasion's ball.png), counter-rotated every frame so the highlight stays top-left.
    let visual: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shadowOffset = CGVector(dx: 4, dy: -4)
    /// In the oblique view the ball's centre (9 pt above the floor) draws this far up the table.
    private static let lift = TourTableLayout.ballRadius * TourTableLayout.oblique
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// Drawn this much bigger than the physics body (Grey Invasion M8 v3: true size looked too small).
    static let lookScale: CGFloat = 1.2
    /// Where the ball was last frame (for line-crossing switches).
    var previousPosition: CGPoint
    /// Whether the one-way launch gate is solid for this ball (while it's above the gate moving down).
    private(set) var launchGateSolid = false
    /// M3 v3: the ball just served, until it is in play below the top (the plunge flap is closed for it alone).
    var isPlunge = false
    private(set) var plungeFlapSolid = false
    private(set) var orbitGateSolid = false
    /// The scoop holding this ball, when it's caught in one; and when it's kicked out.
    var heldIn: TourScoop?
    var releaseAt: TimeInterval = 0
    /// After a kick-out, the scoops leave this ball alone until then.
    var scoopIgnoreUntil: TimeInterval = 0
    /// M3 v1: armed by crossing an orbit's arm switch going up; the made switch at the top centre then scores it.
    var leftOrbitArmed = false
    var rightOrbitArmed = false
    /// When each was armed (game time): an orbit counts only if it's made within TourTableLayout.orbitMadeWithin.
    var leftOrbitArmedAt: TimeInterval = -1_000
    var rightOrbitArmedAt: TimeInterval = -1_000

    /// Milestone 1 has only the floor; the ramps add layers later.
    var isOnFloor: Bool { true }

    init(at point: CGPoint) {
        let r = TourTableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * TourBall.lookScale, height: r * 2 * TourBall.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * TourBall.lookScale, height: r * 2.7 * TourBall.lookScale)
        shadow.zPosition = -5
        previousPosition = point
        super.init()
        position = point
        name = "ball"
        zPosition = 10

        addChild(shadow)
        addChild(trail)
        addChild(visual)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = TourTableLayout.ballMass
        body.restitution = TourTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = TourPhysicsCategory.ball
        body.contactTestBitMask = TourPhysicsCategory.slingshot | TourPhysicsCategory.bumper
            | TourPhysicsCategory.rollover | TourPhysicsCategory.target
        physicsBody = body
        updateCollisionMask()
        updateLook()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Keeps the highlight and the shadow fixed in world space while the body rolls (after physics).
    func updateLook() {
        let a = -zRotation
        visual.zRotation = a
        visual.position = CGPoint(x: -Self.lift * sin(a), y: Self.lift * cos(a))
        shadow.zRotation = a
        shadow.position = CGPoint(x: shadowOffset.dx * cos(a) - shadowOffset.dy * sin(a),
                                  y: shadowOffset.dx * sin(a) + shadowOffset.dy * cos(a))
        if trail.targetNode == nil { trail.targetNode = scene }
        trail.position = visual.position
        let v = physicsBody?.velocity ?? .zero
        let rate = hypot(v.dx, v.dy) > Self.trailMinSpeed ? Self.trailRate : 0
        if trail.particleBirthRate != rate { trail.particleBirthRate = rate }
    }

    func setPlungeFlapSolid(_ solid: Bool) {
        guard solid != plungeFlapSolid else { return }
        plungeFlapSolid = solid
        updateCollisionMask()
    }

    func setOrbitGateSolid(_ solid: Bool) {
        guard solid != orbitGateSolid else { return }
        orbitGateSolid = solid
        updateCollisionMask()
    }

    func setLaunchGateSolid(_ solid: Bool) {
        guard solid != launchGateSolid else { return }
        launchGateSolid = solid
        updateCollisionMask()
    }

    private func updateCollisionMask() {
        guard let body = physicsBody else { return }
        var mask = TourPhysicsCategory.wall | TourPhysicsCategory.flipper | TourPhysicsCategory.slingshot
            | TourPhysicsCategory.bumper | TourPhysicsCategory.target | TourPhysicsCategory.ball
        if launchGateSolid { mask |= TourPhysicsCategory.launchGate }
        if plungeFlapSolid { mask |= TourPhysicsCategory.diverter }
        if orbitGateSolid { mask |= TourPhysicsCategory.orbitGate }
        body.collisionBitMask = mask
    }
}
