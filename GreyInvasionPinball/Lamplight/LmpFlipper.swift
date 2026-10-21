// Pinball Lab Table 05 (The Lamplight): copied from Table 03 (Cthulhu Rising) with the "Lmp" prefix; behaviour unchanged.
import SpriteKit
import UIKit
import CoreGraphics

/// A flipper pinned at its pivot (physicsBody.pinned — no joint, no motor).
/// Each frame, `step(dt:)` sets the body's angular velocity so it swings toward
/// its target angle and lands exactly on it, so it stays still at rest and when
/// held up, while still giving the ball real momentum when it swings.
/// (From Orbit Pinball. The size can be set per flipper, so the same class makes the smaller
/// upper flipper; the angles and speeds come from LmpTableLayout.)
final class LmpFlipper: SKNode {
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
    /// T5 M8 v12: how far it was raised when this frame's step() ran, and that frame's length (for flipAssist).
    private var raisedAtStep: CGFloat = 0
    private var stepDt: CGFloat = 1.0 / 120

    init(side: Side, pivot: CGPoint,
         length: CGFloat = LmpTableLayout.flipperLength,
         pivotRadius: CGFloat = LmpTableLayout.flipperPivotRadius,
         tipRadius: CGFloat = LmpTableLayout.flipperTipRadius) {
        self.side = side
        self.length = length
        self.pivotRadius = pivotRadius
        self.tipRadius = tipRadius
        raiseSign = side == .left ? 1 : -1
        restRotation = -raiseSign * LmpTableLayout.flipperRestAngle
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
        let travel = LmpTableLayout.flipperTravel

        // Safety net: if anything ever knocks it outside its range, put it back.
        let slack: CGFloat = 0.05
        if raised < -slack || raised > travel + slack {
            zRotation = restRotation + raiseSign * min(max(raised, 0), travel)
        }
        raisedAtStep = raised                                  // after the safety net, so a snap-back isn't a swing
        stepDt = dt

        let target: CGFloat = isPressed ? travel : 0
        let wanted = (target - raised) / dt
        let speed = min(max(wanted, -LmpTableLayout.flipperDownSpeed), LmpTableLayout.flipperUpSpeed)
        body.isResting = false                        // a sleeping body ignores new velocities
        body.angularVelocity = raiseSign * speed
    }

    /// T5 M8 v12 (Play Lab / Shot Lab: at 60 Hz the same flip sent the ball ~15% slower than at 120 Hz, so the left loop
    /// stalled short of the top and the ramp had no window): at 60 Hz the flipper swings a quarter of its travel per
    /// physics step and part of the hit is lost untangling the overlap. Call after the physics step: if this flipper
    /// swung up this frame and the ball is touching its top face, the ball leaves at least as fast (along the face's
    /// normal) as that point of the face was moving. It never slows a ball, and does nothing at rest or when held up.
    func flipAssist(_ body: SKPhysicsBody, ballAt p: CGPoint, ballRadius: CGFloat) {
        let swung = raised - raisedAtStep
        guard isPressed, swung > 0.02, stepDt > 0 else { return }   // a real flip step is 0.2–0.4 rad
        let omega = min(swung / stepDt, LmpTableLayout.flipperUpSpeed)   // this frame's angular speed (rad/s)
        // The ball in the flipper's own frame (arm along +x for the left flipper, −x for the right).
        let dx = p.x - position.x, dy = p.y - position.y
        let c = cos(zRotation), s = sin(zRotation)
        let lx = dx * c + dy * s
        let ly = -dx * s + dy * c
        let along = side == .left ? lx : -lx                      // distance out along the arm
        guard along > -pivotRadius, along < length, ly > 0 else { return }
        let t = min(max(along / length, 0), 1)
        let half = pivotRadius + (tipRadius - pivotRadius) * t
        guard ly - half - ballRadius < 3 else { return }          // touching the top face (3 pt of slack)
        let surface = omega * max(along, 0)                       // the face's speed at that point
        let n = CGVector(dx: -s, dy: c)                           // the top face's normal in the scene
        let v = body.velocity
        let vn = v.dx * n.dx + v.dy * n.dy
        guard vn < surface else { return }
        body.velocity = CGVector(dx: v.dx + (surface - vn) * n.dx, dy: v.dy + (surface - vn) * n.dy)
    }

    /// T5 M9 v3: the loft flipper stands on the raised loft, so its picture draws this much higher than its physics
    /// (straight up the screen whatever its angle). The scene calls liftDrawing() after each physics step.
    var drawnLift: CGFloat = 0 { didSet { liftDrawing() } }
    func liftDrawing() {
        guard drawnLift != 0 else { return }
        let a = -zRotation
        let offset = CGPoint(x: -drawnLift * sin(a), y: drawnLift * cos(a))
        for child in children { child.position = offset }
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

        // Milestone 2: the rendered flipper (tools/lmp_render_parts.py, bone with a sea-green rubber),
        // pinned at the pivot. Its image spans x -18…114, y -18…18 points around the pivot (mirrored
        // for the right flipper). Falls back to the grey-box shape if the image is missing.
        let imageName = side == .left ? "lmp_flipper_left" : "lmp_flipper_right"
        let isUpper = len != LmpTableLayout.flipperLength
        // Art round 5a: the upper flipper has its own render at its real size (lmp_flipper_upper, right-hand).
        if isUpper, side == .right,
           let sprite = LmpTableLayout.artSprite("lmp_flipper_upper", box: LmpTableLayout.upperFlipperArtBox) {
            addChild(sprite)
        } else if UIImage(named: imageName) != nil {
            let sprite = SKSpriteNode(imageNamed: imageName)
            // T3 M3 v2 (Aaron: the ball passed through the upper flipper near its end): the image is drawn
            // for the 96-long main flipper, so scale it to THIS flipper's length and thickness. Drawn at full
            // size, the 64-long upper flipper's picture ran 32 pt past its physics tip.
            sprite.size = CGSize(width: 132 * len / LmpTableLayout.flipperLength,
                                 height: 36 * r0 / LmpTableLayout.flipperPivotRadius)
            sprite.anchorPoint = CGPoint(x: side == .left ? 18.0 / 132 : 114.0 / 132, y: 0.5)
            addChild(sprite)
        } else {
            let shape = SKShapeNode(path: path)
            shape.fillColor = SKColor(red: 0.965, green: 0.965, blue: 0.98, alpha: 1)
            shape.strokeColor = SKColor(red: 0.886, green: 0.204, blue: 0.169, alpha: 1)
            shape.lineWidth = 2.6
            shape.lineJoin = .round
            addChild(shape)
        }

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
        body.mass = LmpTableLayout.flipperMass
        body.angularDamping = 0
        body.linearDamping = 0
        body.friction = LmpTableLayout.flipperFriction
        body.restitution = 0                         // dead rubber: no extra bounce
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = LmpPhysicsCategory.flipper
        body.collisionBitMask = LmpPhysicsCategory.ball
        body.contactTestBitMask = LmpPhysicsCategory.none
        physicsBody = body
    }
}
