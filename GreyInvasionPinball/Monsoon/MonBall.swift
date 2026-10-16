// Pinball Lab Table 04 (Monsoon): copied from Table 03 (Cthulhu Rising) with the "Mon" prefix; behaviour unchanged.
// Milestone 4 gives each wire its own collision category (the habitrail network).
import SpriteKit
import CoreGraphics
import Foundation

/// Which level a ball is on: the playfield floor, climbing a ramp, or on a wire return.
enum MonBallLayer { case floor, rampUp, rampDown }

/// One ball in play. The node carries the physics body; `visual` is the look, so it can grow on a
/// ramp without resizing the body. Per-ball state lives here, so multiball works from the start.
final class MonBall: SKNode {
    /// The shaded steel ball (Grey Invasion's ball.png for now; Table 03's own comes with the art).
    /// Counter-rotated every frame so the highlight stays top-left while the body spins.
    let visual: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shadowOffset = CGVector(dx: 4, dy: -4)
    /// Milestone 2: in the oblique view the ball's centre (9 pt above the floor) draws this far up the table.
    private static let lift = MonTableLayout.ballRadius * MonTableLayout.oblique
    private let trail = Effects.ballTrail()
    private static let trailMinSpeed: CGFloat = 450
    private static let trailRate: CGFloat = 90
    /// Drawn this much bigger than the physics body (Grey Invasion M8 v3: true size looked too small).
    static let lookScale: CGFloat = 1.2
    private(set) var layer: MonBallLayer = .floor
    /// Art round 3: how high the ramp under this ball is (0 on the floor); the scene sets it each frame. The ball is
    /// drawn lifted by height × oblique (so it rides on the rendered ramp) and up to 15% bigger at the top.
    var rampHeight: CGFloat = 0
    private var drawnHeight: CGFloat = 0
    /// Where the ball was last frame (for line-crossing switches).
    var previousPosition: CGPoint
    /// The ramp this ball is on (nil on the floor). Table 04 M4: its wire level sets the ball's categories and depth.
    var activeRamp: MonRamp? {
        didSet { if activeRamp !== oldValue { applyLevel() } }
    }
    /// The hole holding this ball, if any, and when it lets go.
    var heldIn: MonScoop? {
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
    /// M4 round 2: riding the helix on rails — how far along it, and how fast. nil = normal physics.
    var ride: (s: CGFloat, speed: CGFloat)?
    /// M5: inside the dust devil (scored once per visit).
    var inDustDevil = false
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
        let r = MonTableLayout.ballRadius
        visual = SKSpriteNode(imageNamed: "ball")
        visual.size = CGSize(width: r * 2 * MonBall.lookScale, height: r * 2 * MonBall.lookScale)
        shadow = SKSpriteNode(imageNamed: "ballshadow")
        shadow.size = CGSize(width: r * 2.7 * MonBall.lookScale, height: r * 2.7 * MonBall.lookScale)
        shadow.zPosition = -5
        previousPosition = point
        super.init()
        position = point
        name = "ball"

        addChild(shadow)
        addChild(trail)
        addChild(visual)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = MonTableLayout.ballMass
        body.restitution = MonTableLayout.ballRestitution
        body.friction = 0.1
        body.linearDamping = 0.05
        body.angularDamping = 0.1
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = MonPhysicsCategory.ball
        body.contactTestBitMask = MonPhysicsCategory.slingshot | MonPhysicsCategory.bumper
            | MonPhysicsCategory.rollover | MonPhysicsCategory.target | MonPhysicsCategory.toy
        physicsBody = body
        setLayer(.floor)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setLayer(_ newLayer: MonBallLayer) {
        layer = newLayer
        if newLayer == .floor { activeRamp = nil }
        shadow.alpha = newLayer == .floor ? 1 : 0.6
        updateLook()
        applyLevel()
    }

    /// Depth and collision categories for the level the ball is on (the floor, or its ramp's wire level).
    private func applyLevel() {
        zPosition = layer == .floor ? 10 : (activeRamp?.ballZ ?? 30)
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
        let lift = heldIn == nil ? Self.lift + h * MonTableLayout.oblique : 0
        visual.position = CGPoint(x: -lift * sin(a), y: lift * cos(a))
        visual.setScale(heldIn != nil ? 0.9 : 1 + 0.15 * h / MonTableLayout.rampTopHeight)   // higher wires: bigger
        // The shadow falls on the surface the ball rides on (the ramp's plastic, or the floor).
        shadow.zRotation = a
        let so = CGVector(dx: shadowOffset.dx, dy: shadowOffset.dy + h * MonTableLayout.oblique)
        shadow.position = CGPoint(x: so.dx * cos(a) - so.dy * sin(a),
                                  y: so.dx * sin(a) + so.dy * cos(a))
        if trail.targetNode == nil { trail.targetNode = scene }
        // T4 M7 v1b (Aaron: on the arroyo's wire "the trail is actually sitting lower than the ball"): the trail
        // comes from the drawn ball, lifted with it, not from the body down on the floor.
        trail.position = visual.position
        // A ball riding the helix has no physics speed (the scene moves it), so use its ride speed there.
        let v = physicsBody?.velocity ?? .zero
        let speed = ride?.speed ?? hypot(v.dx, v.dy)
        let fast = speed > Self.trailMinSpeed
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
        let rampBall = activeRamp?.ballCategory ?? MonPhysicsCategory.rampBall
        let rampWall = activeRamp?.wallCategory ?? MonPhysicsCategory.rampWall
        body.categoryBitMask = layer == .floor ? MonPhysicsCategory.ball : rampBall
        if layer == .floor {
            var mask = MonPhysicsCategory.wall | MonPhysicsCategory.flipper | MonPhysicsCategory.slingshot
                | MonPhysicsCategory.bumper | MonPhysicsCategory.target | MonPhysicsCategory.ball
                | MonPhysicsCategory.toy
            if diverterSolid { mask |= MonPhysicsCategory.diverter }
            if launchGateSolid { mask |= MonPhysicsCategory.launchGate }
            body.collisionBitMask = mask
        } else {
            body.collisionBitMask = rampWall | rampBall        // its own wire level only
        }
    }
}
