// Pinball Lab Table 08 (Neon Labyrinth): copied from CHOMP!'s committed file (fa86dbb, real ball scale) with the "Nl" prefix.
// T8 M1 v1: no ramps yet; the second layer is a scripted ride (return wires, the rise up through the drain).
import SpriteKit
import CoreGraphics
import Foundation

/// Which level a ball is on: the floor, or a scripted ride (the scene moves it along a path; nothing collides with it).
enum NlBallLayer { case floor, ride }

/// One ball in play. The node carries the physics body; `visual` is the look. Per-ball state lives here, so
/// multiball works from the start.
final class NlBall: SKNode {
    /// The shaded steel ball (Grey Invasion's ball.png), counter-rotated every frame so the highlight stays top-left.
    let visual: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shadowOffset = CGVector(dx: 4, dy: -4)
    /// In the oblique view the ball's centre (9 pt above the floor) draws this far up the table.
    private static let lift = NlTableLayout.ballRadius * NlTableLayout.oblique
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// Drawn this much bigger than the physics body (Grey Invasion M8 v3: true size looked too small).
    /// T7 M2 v4: drawn at true size now that the ball is real scale (radius 15; was 1.2× a radius-9 ball).
    static let lookScale: CGFloat = 1.0
    /// Where the ball was last frame (for line-crossing switches).
    var previousPosition: CGPoint
    /// T7 M2 v9: and its velocity then (for the flipper's contact launch).
    var previousVelocity = CGVector.zero
    /// T7 M2 v9: after a contact launch the flippers let this ball go for a few physics steps, so the still-rising face
    /// doesn't catch it a second time (which brought the stepped aim back).
    var flipperGhostSteps = 0 {
        didSet { if (flipperGhostSteps > 0) != (oldValue > 0) { updateCollisionMask() } }
    }
    /// Whether the one-way launch gate is solid for this ball (while it's above the gate moving down).
    private(set) var launchGateSolid = false
    /// T7 M1: whether the right outlane's one-way save gate is solid for this ball (while it moves right, so a ball
    /// can roll from the outlane back into the inlane but never out).
    private(set) var saveGateSolid = false

    /// T7 M2 v5: the ramp layer (Table 06's TourBall pattern). On a ramp the ball takes the ramp's ball category and
    /// collides with that ramp's rails (and other ramp balls) only; floor parts, sensors and switches ignore it.
    private(set) var layer: NlBallLayer = .floor
    /// How high the ramp under this ball is (0 on the floor); the scene sets it each frame. The ball draws lifted by
    /// height × oblique so it rides on the drawn ramp.
    var rampHeight: CGFloat = 0
    private var drawnHeight: CGFloat = 0
    var isOnFloor: Bool { layer == .floor }

    func setLayer(_ newLayer: NlBallLayer) {
        layer = newLayer
        physicsBody?.affectedByGravity = newLayer == .floor
        shadow.alpha = newLayer == .floor ? 1 : 0.6
        applyLevel()
        updateLook()
    }

    private func applyLevel() {
        zPosition = layer == .floor ? 10 : 30
        updateCollisionMask()
    }

    init(at point: CGPoint) {
        let r = NlTableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * NlBall.lookScale, height: r * 2 * NlBall.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * NlBall.lookScale, height: r * 2.7 * NlBall.lookScale)
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
        body.mass = NlTableLayout.ballMass
        body.restitution = NlTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = NlPhysicsCategory.ball
        body.contactTestBitMask = NlPhysicsCategory.slingshot | NlPhysicsCategory.bumper
            | NlPhysicsCategory.rollover | NlPhysicsCategory.target
        physicsBody = body
        updateCollisionMask()
        updateLook()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// T8 M3 v1, the neon look: a white data packet with a cyan halo and a cyan light trail; no shadow.
    func applyNeon() {
        visual.color = NlNeon.white
        visual.colorBlendFactor = 1
        shadow.isHidden = true
        let r = NlTableLayout.ballRadius * NlBall.lookScale
        let halo = SKShapeNode(circleOfRadius: r + 2)
        halo.strokeColor = NlNeon.cyan.withAlphaComponent(0.4)
        halo.lineWidth = 7
        halo.blendMode = .add
        halo.zPosition = -0.1
        visual.addChild(halo)
        trail.particleColor = NlNeon.cyan
        trail.particleAlpha = 0.7
        trail.particleScale = 0.6
    }

    /// Keeps the highlight and the shadow fixed in world space while the body rolls (after physics).
    func updateLook() {
        let a = -zRotation
        visual.zRotation = a
        // M2 v5: ease toward the ramp's height so leaving the wire doesn't jump.
        drawnHeight += (rampHeight - drawnHeight) * 0.35
        if abs(rampHeight - drawnHeight) < 0.05 { drawnHeight = rampHeight }
        let lift = Self.lift + drawnHeight * NlTableLayout.oblique
        visual.position = CGPoint(x: -lift * sin(a), y: lift * cos(a))
        visual.setScale(1 + 0.15 * drawnHeight / NlTableLayout.rampTopHeight)
        shadow.zRotation = a
        let so = CGVector(dx: shadowOffset.dx, dy: shadowOffset.dy + drawnHeight * NlTableLayout.oblique)
        shadow.position = CGPoint(x: so.dx * cos(a) - so.dy * sin(a),
                                  y: so.dx * sin(a) + so.dy * cos(a))
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

    func setSaveGateSolid(_ solid: Bool) {
        guard solid != saveGateSolid else { return }
        saveGateSolid = solid
        updateCollisionMask()
    }

    private func updateCollisionMask() {
        guard let body = physicsBody else { return }
        if layer != .floor {                                   // T8: riding — nothing touches it
            body.categoryBitMask = NlPhysicsCategory.rideBall
            body.collisionBitMask = 0
            body.contactTestBitMask = 0
            return
        }
        body.categoryBitMask = flipperGhostSteps > 0 ? NlPhysicsCategory.ghostBall : NlPhysicsCategory.ball
        body.contactTestBitMask = NlPhysicsCategory.slingshot | NlPhysicsCategory.bumper
            | NlPhysicsCategory.rollover | NlPhysicsCategory.target
        var mask = NlPhysicsCategory.wall | NlPhysicsCategory.flipper | NlPhysicsCategory.slingshot
            | NlPhysicsCategory.bumper | NlPhysicsCategory.target | NlPhysicsCategory.ball
            | NlPhysicsCategory.toy                         // M3 v4: the boat's captive ball
        if launchGateSolid { mask |= NlPhysicsCategory.launchGate }
        if saveGateSolid { mask |= NlPhysicsCategory.diverter }
        if flipperGhostSteps > 0 { mask &= ~NlPhysicsCategory.flipper }
        body.collisionBitMask = mask
    }
}
