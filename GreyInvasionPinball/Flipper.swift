import SpriteKit
import UIKit
import CoreGraphics

/// A flipper pinned at its pivot (physicsBody.pinned — no joint, no motor).
/// Each frame, `step(dt:)` sets the body's angular velocity so it swings toward
/// its target angle and lands exactly on it, so it stays still at rest and when
/// held up, while still giving the ball real momentum when it swings.
/// (From Orbit Pinball. The size can be set per flipper, so the same class makes the smaller
/// upper flipper; the angles and speeds come from TableLayout.)
final class Flipper: SKNode {
    enum Side { case left, right }

    let side: Side

    var isPressed = false {
        didSet {
            guard isPressed != oldValue else { return }
            if isPressed { haptic.impactOccurred() }
        }
    }

    private let raiseSign: CGFloat   // +1 = counterclockwise raises (left), -1 = clockwise (right)
    private let restRotation: CGFloat
    private let haptic = Haptic(style: .light)
    private let length: CGFloat
    private let pivotRadius: CGFloat
    private let tipRadius: CGFloat

    init(side: Side, pivot: CGPoint,
         length: CGFloat = TableLayout.flipperLength,
         pivotRadius: CGFloat = TableLayout.flipperPivotRadius,
         tipRadius: CGFloat = TableLayout.flipperTipRadius) {
        self.side = side
        self.length = length
        self.pivotRadius = pivotRadius
        self.tipRadius = tipRadius
        raiseSign = side == .left ? 1 : -1
        restRotation = -raiseSign * TableLayout.flipperRestAngle
        super.init()
        position = pivot
        zRotation = restRotation   // start in the rest pose
        buildShape()
        haptic.prepare()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Adds the flipper to the scene. `pinned` fixes its position at the pivot
    /// while still letting it rotate — no separate anchor body or joint needed.
    func attach(to scene: SKScene) {
        scene.addChild(self)
        physicsBody?.pinned = true
    }

    /// How far the flipper is raised: 0 at rest, flipperTravel when fully up.
    private var raised: CGFloat { (zRotation - restRotation) * raiseSign }

    /// Call once per frame, before physics runs.
    /// Swings toward the up angle while pressed and the rest angle otherwise,
    /// capped at the up/down speeds, slowing just enough to stop exactly on target.
    func step(dt: CGFloat) {
        guard let body = physicsBody, dt > 0 else { return }
        let travel = TableLayout.flipperTravel

        // Safety net: if anything ever knocks it outside its range, put it back.
        let slack: CGFloat = 0.05
        if raised < -slack || raised > travel + slack {
            zRotation = restRotation + raiseSign * min(max(raised, 0), travel)
        }

        let target: CGFloat = isPressed ? travel : 0
        let wanted = (target - raised) / dt
        let speed = min(max(wanted, -TableLayout.flipperDownSpeed), TableLayout.flipperUpSpeed)
        body.isResting = false                        // a sleeping body ignores new velocities
        body.angularVelocity = raiseSign * speed
    }

    private func buildShape() {
        let len = length
        let r0 = pivotRadius
        let r1 = tipRadius
        let dir: CGFloat = side == .left ? 1 : -1   // the arm points right (left flipper) or left
        let tip = CGPoint(x: dir * len, y: 0)

        // Visual: a tapered capsule, drawn pointing right, then mirrored for the right flipper.
        let outline = CGMutablePath()
        outline.addArc(center: .zero, radius: r0,
                       startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: false)
        outline.addLine(to: CGPoint(x: len, y: -r1))
        outline.addArc(center: CGPoint(x: len, y: 0), radius: r1,
                       startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        outline.closeSubpath()
        var mirror = CGAffineTransform(scaleX: dir, y: 1)
        let path = outline.copy(using: &mirror) ?? outline

        let shape = SKShapeNode(path: path)
        // M8 art round 3 (concept): white flipper with red rubber and a chrome pivot cap
        shape.fillColor = SKColor(red: 0.965, green: 0.965, blue: 0.98, alpha: 1)
        shape.strokeColor = SKColor(red: 0.886, green: 0.204, blue: 0.169, alpha: 1)
        shape.lineWidth = 2.6
        shape.lineJoin = .round
        addChild(shape)
        let cap = SKShapeNode(circleOfRadius: r0 * 0.34)
        cap.fillColor = SKColor(red: 0.60, green: 0.63, blue: 0.68, alpha: 1)
        cap.strokeColor = SKColor(white: 1, alpha: 0.6)
        cap.lineWidth = 0.8
        cap.zPosition = 0.1
        addChild(cap)

        // Physics: pivot circle + tip circle + the quad between them (counterclockwise).
        let quadPoints: [CGPoint] = side == .left
            ? [CGPoint(x: 0, y: -r0), CGPoint(x: len, y: -r1), CGPoint(x: len, y: r1), CGPoint(x: 0, y: r0)]
            : [CGPoint(x: 0, y: r0), CGPoint(x: -len, y: r1), CGPoint(x: -len, y: -r1), CGPoint(x: 0, y: -r0)]
        let quad = CGMutablePath()
        quad.addLines(between: quadPoints)
        quad.closeSubpath()

        let body = SKPhysicsBody(bodies: [
            SKPhysicsBody(circleOfRadius: r0),
            SKPhysicsBody(circleOfRadius: r1, center: tip),
            SKPhysicsBody(polygonFrom: quad),
        ])
        body.isDynamic = true
        body.allowsRotation = true
        body.affectedByGravity = false
        body.mass = TableLayout.flipperMass
        body.angularDamping = 0
        body.linearDamping = 0
        body.friction = TableLayout.flipperFriction
        body.restitution = 0                         // dead rubber: no extra bounce
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.flipper
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.none
        physicsBody = body
    }
}
