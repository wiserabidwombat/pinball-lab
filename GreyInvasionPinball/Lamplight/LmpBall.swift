// Pinball Lab Table 05 (The Lamplight): one ball in play. Monsoon's MonBall trimmed to the floor for milestone 1 (no
// ramps or wires yet; the loft and its ramp add them back in milestone 3). M2 adds holes and the right orbit's one-way
// deflector. Per-ball state lives here, so multiball works from the start.
import SpriteKit
import CoreGraphics
import Foundation

final class LmpBall: SKNode {
    /// The shaded steel ball (Grey Invasion's ball.png until the table's own art). Counter-rotated every frame so the
    /// highlight stays top-left while the body spins.
    let visual: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shadowOffset = CGVector(dx: 4, dy: -4)
    /// In the oblique view the ball's centre (9 pt above the floor) draws this far up the table.
    private static let lift = LmpTableLayout.ballRadius * LmpTableLayout.oblique
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// Drawn this much bigger than the physics body (Grey Invasion M8 v3: true size looked too small).
    static let lookScale: CGFloat = 1.2
    /// Where the ball was last frame (for line-crossing switches).
    var previousPosition: CGPoint
    /// Crossed the right-outlane line going down: this ball is draining via the right outlane.
    var inRightOutlane = false
    /// Whether the one-way launch gate is solid for this ball (while it's above the gate moving down).
    private(set) var launchGateSolid = false
    /// T5 M2: whether the one-way deflector across the right orbit's mouth is solid for this ball (same rule).
    private(set) var orbitDeflectorSolid = false
    /// T5 M2: the hole holding this ball, if any, and when it lets go. A ball in a hole sits sunk in it: no lift,
    /// no shadow (T3 M4 v2).
    var heldIn: LmpScoop? {
        didSet {
            guard (heldIn == nil) != (oldValue == nil) else { return }
            shadow.isHidden = heldIn != nil
            updateLook()
        }
    }
    var releaseAt: TimeInterval = 0
    var scoopIgnoreUntil: TimeInterval = 0
    /// Just plunged: its first trip over the top isn't a loop. Cleared once it comes back down the table.
    var launched = false

    init(at point: CGPoint) {
        let r = LmpTableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * Self.lookScale, height: r * 2 * Self.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * Self.lookScale, height: r * 2.7 * Self.lookScale)
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
        body.mass = LmpTableLayout.ballMass
        body.restitution = LmpTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = LmpPhysicsCategory.ball
        body.contactTestBitMask = LmpPhysicsCategory.slingshot | LmpPhysicsCategory.bumper
            | LmpPhysicsCategory.rollover | LmpPhysicsCategory.target | LmpPhysicsCategory.toy
        physicsBody = body
        updateCollisionMask()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Keeps the highlight and the shadow fixed in world space while the body rolls (after physics).
    func updateLook() {
        let a = -zRotation
        visual.zRotation = a
        let lift = heldIn == nil ? Self.lift : 0
        visual.position = CGPoint(x: -lift * sin(a), y: lift * cos(a))
        shadow.zRotation = a
        shadow.position = CGPoint(x: shadowOffset.dx * cos(a) - shadowOffset.dy * sin(a),
                                  y: shadowOffset.dx * sin(a) + shadowOffset.dy * cos(a))
        if trail.targetNode == nil { trail.targetNode = scene }
        trail.position = visual.position
        let v = physicsBody?.velocity ?? .zero
        let rate = hypot(v.dx, v.dy) > Self.trailMinSpeed ? Self.trailRate : 0
        if trail.particleBirthRate != rate { trail.particleBirthRate = rate }
    }

    func setLaunchGateSolid(_ solid: Bool) {
        guard solid != launchGateSolid else { return }
        launchGateSolid = solid
        updateCollisionMask()
    }

    func setOrbitDeflectorSolid(_ solid: Bool) {
        guard solid != orbitDeflectorSolid else { return }
        orbitDeflectorSolid = solid
        updateCollisionMask()
    }

    private func updateCollisionMask() {
        guard let body = physicsBody else { return }
        var mask = LmpPhysicsCategory.wall | LmpPhysicsCategory.flipper | LmpPhysicsCategory.slingshot
            | LmpPhysicsCategory.bumper | LmpPhysicsCategory.target | LmpPhysicsCategory.ball
            | LmpPhysicsCategory.toy
        if launchGateSolid { mask |= LmpPhysicsCategory.launchGate }
        if orbitDeflectorSolid { mask |= LmpPhysicsCategory.orbitDeflector }
        body.collisionBitMask = mask
    }
}
