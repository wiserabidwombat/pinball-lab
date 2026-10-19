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
    /// T5 M8 v7: window-seat catches on this loft visit (the first scores and finds a book; after that the seat sends
    /// the ball down the chute). Cleared when the ball leaves the upper layer.
    var windowSeatCatches = 0
    /// T5 M8 v16 (economy): this ball has had its window-seat find (one per ball; later window seats score only).
    var windowSeatFound = false
    /// T5 M8 v22: how far the plunger was pulled for this ball (0–1; 0 for the Rush's automatic plunges).
    var launchPower: CGFloat = 0
    var scoopIgnoreUntil: TimeInterval = 0
    /// Just plunged: its first trip over the top isn't a loop. Cleared once it comes back down the table.
    var launched = false
    /// T5 M3 round 2: carried by the scene along a straight line (the dumbwaiter, the hatch from a full plunge):
    /// no collisions while it rides; it leaves with `exit` velocity.
    var ride: (from: CGPoint, to: CGPoint, start: TimeInterval, duration: TimeInterval, exit: CGVector)? {
        didSet { if (ride == nil) != (oldValue == nil) { updateCollisionMask() } }
    }
    /// T5 M3: up on the loft or its ramp (the upper layer): it touches only rampWall walls and the loft flipper,
    /// draws above the loft and a little bigger.
    private(set) var isUpper = false

    func setUpper(_ up: Bool) {
        guard up != isUpper else { return }
        isUpper = up
        if !up { windowSeatCatches = 0 }
        zPosition = up ? 30 : 10
        visual.setScale(up ? 1.1 : 1)
        physicsBody?.categoryBitMask = up ? LmpPhysicsCategory.rampBall : LmpPhysicsCategory.ball
        updateCollisionMask()
    }

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
        var mask: UInt32
        if ride != nil {
            mask = 0
        } else if isUpper {
            mask = LmpPhysicsCategory.rampWall | LmpPhysicsCategory.loftFlipper
        } else {
            mask = LmpPhysicsCategory.wall | LmpPhysicsCategory.flipper | LmpPhysicsCategory.slingshot
                | LmpPhysicsCategory.bumper | LmpPhysicsCategory.target | LmpPhysicsCategory.ball
                | LmpPhysicsCategory.toy
            if launchGateSolid { mask |= LmpPhysicsCategory.launchGate }
            if orbitDeflectorSolid { mask |= LmpPhysicsCategory.orbitDeflector }
        }
        let old = body.collisionBitMask
        guard old != mask else { return }
        body.collisionBitMask = mask
        // Only a change of layer or the start / end of a ride needs it (the gates flip often; they stay as they were).
        let layerOf = { (m: UInt32) in m == 0 ? 0 : (m & LmpPhysicsCategory.rampWall != 0 ? 1 : 2) }
        if layerOf(old) != layerOf(mask) { refreshContacts(body) }
    }

    /// T5 M8 v14 (Play Lab: a ball flew straight through the left wall at (-31, 836) just after leaving the loft):
    /// the physics engine only checks the masks when a ball first comes near a wall. A ball rolling down the loft's
    /// chute on the upper layer is already "near" the left wall (x 20) when the exit switch at x 46 puts it on the
    /// floor, so the wall was still being ignored and the ball could pass through it before the pair was checked again.
    /// Taking the body out of the world and putting it back makes every pair be checked with the new masks at once.
    private func refreshContacts(_ body: SKPhysicsBody) {
        guard parent != nil else { return }
        let v = body.velocity, spin = body.angularVelocity
        physicsBody = nil
        physicsBody = body
        body.velocity = v
        body.angularVelocity = spin
    }
}
