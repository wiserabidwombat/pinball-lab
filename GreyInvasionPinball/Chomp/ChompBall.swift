// Pinball Lab Table 07 (CHOMP! The Terror of Calamity Island): copied from Table 06's milestone-1 file (e023ac3) with the "Chomp" prefix.
// the ramps and the Moon's upper layer come with milestones 3–4).
import SpriteKit
import CoreGraphics
import Foundation

/// T7 M2 v5: which level a ball is on (Table 06's TourBallLayer): the floor, or a ramp going up / coming down.
enum ChompBallLayer { case floor, rampUp, rampDown }

/// One ball in play. The node carries the physics body; `visual` is the look. Per-ball state lives here, so
/// multiball works from the start.
final class ChompBall: SKNode {
    /// The shaded steel ball (Grey Invasion's ball.png), counter-rotated every frame so the highlight stays top-left.
    let visual: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shadowOffset = CGVector(dx: 4, dy: -4)
    /// In the oblique view the ball's centre (9 pt above the floor) draws this far up the table.
    private static let lift = ChompTableLayout.ballRadius * ChompTableLayout.oblique
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// Drawn this much bigger than the physics body (Grey Invasion M8 v3: true size looked too small).
    /// T7 M2 v4: drawn at true size now that the ball is real scale (radius 15; was 1.2× a radius-9 ball).
    static let lookScale: CGFloat = 1.0
    /// Where the ball was last frame (for line-crossing switches).
    var previousPosition: CGPoint
    /// Whether the one-way launch gate is solid for this ball (while it's above the gate moving down).
    private(set) var launchGateSolid = false
    /// T7 M1: whether the right outlane's one-way save gate is solid for this ball (while it moves right, so a ball
    /// can roll from the outlane back into the inlane but never out).
    private(set) var saveGateSolid = false

    /// T7 M2 v5: the ramp layer (Table 06's TourBall pattern). On a ramp the ball takes the ramp's ball category and
    /// collides with that ramp's rails (and other ramp balls) only; floor parts, sensors and switches ignore it.
    private(set) var layer: ChompBallLayer = .floor
    var activeRamp: ChompRamp? {
        didSet { if activeRamp !== oldValue { applyLevel() } }
    }
    /// How high the ramp under this ball is (0 on the floor); the scene sets it each frame. The ball draws lifted by
    /// height × oblique so it rides on the drawn ramp.
    var rampHeight: CGFloat = 0
    private var drawnHeight: CGFloat = 0
    var isOnFloor: Bool { layer == .floor }

    func setLayer(_ newLayer: ChompBallLayer) {
        layer = newLayer
        if newLayer == .floor { activeRamp = nil }
        shadow.alpha = newLayer == .floor ? 1 : 0.6
        applyLevel()
        updateLook()
    }

    private func applyLevel() {
        zPosition = layer == .floor ? 10 : (activeRamp?.ballZ ?? 30)
        updateCollisionMask()
    }

    init(at point: CGPoint) {
        let r = ChompTableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * ChompBall.lookScale, height: r * 2 * ChompBall.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * ChompBall.lookScale, height: r * 2.7 * ChompBall.lookScale)
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
        body.mass = ChompTableLayout.ballMass
        body.restitution = ChompTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = ChompPhysicsCategory.ball
        body.contactTestBitMask = ChompPhysicsCategory.slingshot | ChompPhysicsCategory.bumper
            | ChompPhysicsCategory.rollover | ChompPhysicsCategory.target
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
        // M2 v5: ease toward the ramp's height so leaving the wire doesn't jump.
        drawnHeight += (rampHeight - drawnHeight) * 0.35
        if abs(rampHeight - drawnHeight) < 0.05 { drawnHeight = rampHeight }
        let lift = Self.lift + drawnHeight * ChompTableLayout.oblique
        visual.position = CGPoint(x: -lift * sin(a), y: lift * cos(a))
        visual.setScale(1 + 0.15 * drawnHeight / ChompTableLayout.rampTopHeight)
        shadow.zRotation = a
        let so = CGVector(dx: shadowOffset.dx, dy: shadowOffset.dy + drawnHeight * ChompTableLayout.oblique)
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
        if layer != .floor {                                   // M2 v5: its ramp's level only, and no floor contacts
            body.categoryBitMask = activeRamp?.ballCategory ?? ChompPhysicsCategory.rampBall
            body.collisionBitMask = (activeRamp?.wallCategory ?? ChompPhysicsCategory.rampWall)
                | (activeRamp?.ballCategory ?? ChompPhysicsCategory.rampBall)
            body.contactTestBitMask = 0
            return
        }
        body.categoryBitMask = ChompPhysicsCategory.ball
        body.contactTestBitMask = ChompPhysicsCategory.slingshot | ChompPhysicsCategory.bumper
            | ChompPhysicsCategory.rollover | ChompPhysicsCategory.target
        var mask = ChompPhysicsCategory.wall | ChompPhysicsCategory.flipper | ChompPhysicsCategory.slingshot
            | ChompPhysicsCategory.bumper | ChompPhysicsCategory.target | ChompPhysicsCategory.ball
        if launchGateSolid { mask |= ChompPhysicsCategory.launchGate }
        if saveGateSolid { mask |= ChompPhysicsCategory.diverter }
        body.collisionBitMask = mask
    }
}
