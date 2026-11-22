// Pinball Lab Table 08 (Neon Labyrinth): copied from CHOMP!'s committed file (fa86dbb, real ball scale) with the "Nl" prefix.
import SpriteKit
import UIKit
import CoreGraphics

/// A flipper pinned at its pivot (physicsBody.pinned — no joint, no motor).
/// Each frame, `step(dt:)` sets the body's angular velocity so it swings toward
/// its target angle and lands exactly on it, so it stays still at rest and when
/// held up, while still giving the ball real momentum when it swings.
/// (From Orbit Pinball. The size can be set per flipper, so the same class makes the smaller
/// upper flipper; the angles and speeds come from NlTableLayout.)
final class NlFlipper: SKNode {
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
    /// T4 flip assist (from Lamplight's T5 M8 v12): how far it was raised when this frame's step() ran, and that
    /// frame's length.
    private var raisedAtStep: CGFloat = 0
    private var stepDt: CGFloat = 1.0 / 120
    /// T7 M2 v2: per-flipper rest angle and travel (the pier flipper hangs at 69° and swings 84°).
    private let travel: CGFloat

    init(side: Side, pivot: CGPoint,
         length: CGFloat = NlTableLayout.flipperLength,
         pivotRadius: CGFloat = NlTableLayout.flipperPivotRadius,
         tipRadius: CGFloat = NlTableLayout.flipperTipRadius,
         restAngle: CGFloat = NlTableLayout.flipperRestAngle,
         travel: CGFloat = NlTableLayout.flipperTravel) {
        self.side = side
        self.travel = travel
        self.length = length
        self.pivotRadius = pivotRadius
        self.tipRadius = tipRadius
        raiseSign = side == .left ? 1 : -1
        restRotation = -raiseSign * restAngle
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

        // Safety net: if anything ever knocks it outside its range, put it back.
        let slack: CGFloat = 0.05
        if raised < -slack || raised > travel + slack {
            zRotation = restRotation + raiseSign * min(max(raised, 0), travel)
        }
        raisedAtStep = raised                                  // after the safety net, so a snap-back isn't a swing
        stepDt = dt

        // T7 M2 v10: the flipper model's upswing — the coil builds up over flipperCoilRamp; the face's angle at every
        // 0.5 ms sub-step is kept for solveSwing. The physics body is turned to the same end angle.
        swingPath = []
        if !isPressed { pressedFor = 0; coilOmega = 0 }
        // Shot Lab run 5: a held-up flipper a hair under its stop kept re-entering the model every frame, ghosting the
        // cradled ball so it never settled; within 0.01 rad of the stop it's SpriteKit's (held).
        if NlTableLayout.flipperModel, isPressed, raised < travel - 0.01 {
            let n = max(1, Int((dt / 0.0005).rounded(.up)))
            let h = dt / CGFloat(n)
            var r = max(raised, 0), w = coilOmega
            var path: [CGFloat] = [r]
            for _ in 0..<n {
                pressedFor += h
                let pull = 1 - exp(-pressedFor / NlTableLayout.flipperCoilRamp)
                w = min(w + NlTableLayout.flipperCoilAccel * pull * h, NlTableLayout.flipperMaxSpeed)
                r += w * h
                if r >= travel { r = travel; w = 0 }
                path.append(r)
            }
            coilOmega = w
            swingPath = path
            swingStepH = h
            // The model owns the angle: put the body at the sub-steps' end angle now (turning it by angular velocity
            // left it short — at the Shot Lab's half physics speed it got half way). Balls it could sweep are ghosted.
            commandedSpeed = (r - raised) / dt
            body.angularVelocity = 0
            zRotation = restRotation + raiseSign * r
            return
        }
        if NlTableLayout.flipperModel { coilOmega = 0 }

        let target: CGFloat = isPressed ? travel : 0
        let wanted = (target - raised) / dt
        let speed = min(max(wanted, -NlTableLayout.flipperDownSpeed), NlTableLayout.flipperUpSpeed)
        body.isResting = false                        // a sleeping body ignores new velocities
        body.angularVelocity = raiseSign * speed
        commandedSpeed = speed
    }

    // MARK: T7 M2 v10: the flipper model (see NlTableLayout.flipperModel)

    private var coilOmega: CGFloat = 0
    private var pressedFor: CGFloat = 0
    /// This frame's upswing: how far raised at each sub-step (empty when not swinging up).
    private var swingPath: [CGFloat] = []
    private var swingStepH: CGFloat = 0
    var isSwingingUp: Bool { !swingPath.isEmpty }

    /// Is a ball here within reach of the face (the scene hands such balls to solveSwing while it swings up)?
    func reaches(_ p: CGPoint, ballRadius R: CGFloat) -> Bool {
        hypot(p.x - position.x, p.y - position.y) < length + pivotRadius + R + 14
    }

    /// The upswing against one ball, re-run from where the ball was before the physics step: gravity, the moving
    /// tapered face (nearest point on the arm, so the caps too), a bounce of elasticity / (1 + fall-off × impact
    /// speed) off the face's own velocity at the contact, and friction up to 2/7 of the slip (a rolling ball). Only if
    /// the face touched the ball this frame does the result replace the physics step's.
    func solveSwing(_ ball: NlBall, ballRadius R: CGFloat) {
        guard swingPath.count > 1, let body = ball.physicsBody else { return }
        let p0 = ball.previousPosition
        guard reaches(p0, ballRadius: R) else { return }
        let g = (scene?.physicsWorld.gravity.dy ?? -9.2) * 150          // pt/s² (SpriteKit: 150 pt per metre)
        var px = p0.x, py = p0.y
        var vx = ball.previousVelocity.dx, vy = ball.previousVelocity.dy
        let h = swingStepH
        var touched = false
        for i in 1..<swingPath.count {
            let theta = restRotation + raiseSign * swingPath[i]
            let omega = raiseSign * (swingPath[i] - swingPath[i - 1]) / h
            vy += g * h
            px += vx * h
            py += vy * h
            let arm = armDirection(theta)
            let dx = px - position.x, dy = py - position.y
            let along = min(max(dx * arm.dx + dy * arm.dy, 0), length)
            let qx = position.x + along * arm.dx, qy = position.y + along * arm.dy
            var nx = px - qx, ny = py - qy
            let dist = hypot(nx, ny)
            let half = halfThickness(along)
            guard dist < half + R, dist > 0.001 else { continue }
            nx /= dist; ny /= dist
            touched = true
            px = qx + nx * (half + R)
            py = qy + ny * (half + R)
            let cx = qx + nx * half - position.x, cy = qy + ny * half - position.y
            let rvx = vx + omega * cy, rvy = vy - omega * cx               // ball minus the face's velocity there
            let vn = rvx * nx + rvy * ny
            guard vn < 0 else { continue }
            // Resting contact (slower than the threshold) doesn't bounce: a ball lying on the face is carried while
            // the coil builds up, as on a real flipper, instead of hopping off and being caught again.
            let e = -vn < NlTableLayout.flipperBounceThreshold ? 0
                : NlTableLayout.flipperElasticity / (1 + NlTableLayout.flipperElasticityFalloff * -vn / 1000)
            let jn = -(1 + e) * vn
            var tx = rvx - vn * nx, ty = rvy - vn * ny
            let vt = hypot(tx, ty)
            var dvt: CGFloat = 0
            if vt > 0.001 {
                tx /= vt; ty /= vt
                dvt = min(NlTableLayout.flipperRubberFriction * jn, 2.0 / 7.0 * vt)
            }
            vx += jn * nx - dvt * tx
            vy += jn * ny - dvt * ty
        }
        guard touched else { return }
        ball.position = CGPoint(x: px, y: py)
        body.velocity = CGVector(dx: vx, dy: vy)
        #if DEBUG
        if Self.debugLog {
            let a0 = (p0.x - position.x) * armDirection(restRotation + raiseSign * swingPath[0]).dx
                + (p0.y - position.y) * armDirection(restRotation + raiseSign * swingPath[0]).dy
            print(String(format: "FLIPSOLVE along %.2f raised %.3f -> %.3f v %.1f deg %.0f", Double(a0), Double(swingPath[0]),
                         Double(swingPath[swingPath.count - 1]), Double(atan2(vy, vx) * 180 / .pi), Double(hypot(vx, vy))))
        }
        #endif
    }

    /// T7 M2 v9: balls this flip has already launched (cleared when the button is let go).
    private var launched = Set<ObjectIdentifier>()
    /// The swing speed step() asked for this frame (rad/s, + = raising). The step a ball is hit, the physics slows the
    /// flipper (the probe saw 0.13 rad instead of 0.29), so the launch uses the coil's speed, as a real flipper's would.
    private var commandedSpeed: CGFloat = 0

    /// T7 M2 v9, the flipper carry (the fan probe, M2 v8: the flipper turns ~17° per physics step, so the physics
    /// caught the ball on whichever step first reached it and the aim came in steps — flat stretches with 2–5° jumps,
    /// and 120 Hz and 60 Hz aimed 5–10° apart). Call after each physics step, for every floor ball. When this frame's
    /// swing passes the angle where the face first touches the ball (found from where the ball was before the step),
    /// the flipper takes the ball and carries it: the ball rides the face, rolling out along it (a ball on a turning
    /// arm is flung outward: along'' = 5/7 (ω² along + gravity along the arm), 5/7 for a rolling ball), and is let go
    /// when it rolls off the tip, the flipper reaches its stop, or the button is let go — moving with the face
    /// (ω × along, along the face's normal) plus how fast it was rolling out. Worked out in 0.5 ms sub-steps, so the
    /// aim varies smoothly with where the ball was and is the same at 120 Hz and 60 Hz. The physics doesn't touch the
    /// ball while it's carried (NlBall.flipperGhostSteps).
    private struct Carry {
        var along: CGFloat
        var rate: CGFloat
        var omega: CGFloat
        /// The face's angle under the ball (its own clock: the physics slows the real flipper on the step it meets
        /// the ball, so zRotation lags).
        var theta: CGFloat
    }
    private var carries: [ObjectIdentifier: Carry] = [:]

    func contactLaunch(_ ball: NlBall, ballRadius R: CGFloat) {
        guard let body = ball.physicsBody else { return }
        let id = ObjectIdentifier(ball)
        if var c = carries[id] {                                  // carrying: on along the face
            let letGo = !isPressed
            let r = advance(&c, dt: letGo ? 0 : stepDt)
            place(ball, body, c, R: R, release: letGo || r.off, at: r)
            carries[id] = (letGo || r.off) ? nil : c
            return
        }
        guard isPressed else { launched.removeAll(); return }
        let swing = raised - raisedAtStep
        guard swing > 0.005, !launched.contains(id) else { return }
        let theta0 = restRotation + raiseSign * raisedAtStep
        let p0 = ball.previousPosition
        let dx = p0.x - position.x, dy = p0.y - position.y
        let rho = hypot(dx, dy), phi = atan2(dy, dx)
        guard sin(phi - theta0) * rho > -2 else { return }      // it was over the top face before the swing
        var along = rho, k: CGFloat = 0
        for _ in 0..<3 {
            k = (halfThickness(along) + R) / rho
            guard k < 1 else { return }
            along = rho * (1 - k * k).squareRoot()
        }
        guard along > 0, along <= length else { return }
        var thetaC = phi - (side == .left ? asin(k) : .pi - asin(k))
        thetaC += 2 * .pi * ((theta0 - thetaC) / (2 * .pi)).rounded()
        let into = (thetaC - theta0) * raiseSign
        guard into >= -0.03, into <= swing else { return }     // the face reached the ball during this step
        launched.insert(id)
        let thetaHit = theta0 + raiseSign * max(into, 0)
        let arm = armDirection(thetaHit)
        let v0 = ball.previousVelocity
        var c = Carry(along: along, rate: v0.dx * arm.dx + v0.dy * arm.dy,
                      omega: raiseSign * NlTableLayout.flipperUpSpeed, theta: thetaHit)
        let r = advance(&c, dt: stepDt * (1 - max(into, 0) / max(swing, 0.0001)))
        place(ball, body, c, R: R, release: r.off, at: r)
        if !r.off { carries[id] = c }
        #if DEBUG
        if Self.debugLog {
            print(String(format: "FLIPCARRY along %.2f into %.3f swing %.3f hit %.1f deg slide %.0f",
                         Double(along), Double(into), Double(swing), Double(thetaHit * 180 / .pi), Double(c.rate)))
        }
        #endif
    }

    private func halfThickness(_ along: CGFloat) -> CGFloat {
        pivotRadius + (tipRadius - pivotRadius) * min(max(along / length, 0), 1)
    }

    private func armDirection(_ theta: CGFloat) -> CGVector {
        side == .left ? CGVector(dx: cos(theta), dy: sin(theta)) : CGVector(dx: -cos(theta), dy: -sin(theta))
    }

    /// Rolls the carried ball out along the face for `dt`. `off`: it rolled past the tip or the flipper reached its
    /// stop, at `theta`, with `remaining` of dt left to fly free (so the release isn't rounded to the frame).
    private func advance(_ c: inout Carry, dt: CGFloat) -> (off: Bool, theta: CGFloat, remaining: CGFloat) {
        guard dt > 0 else { return (c.along > length, c.theta, 0) }
        let thetaStop = restRotation + raiseSign * travel
        let g = (scene?.physicsWorld.gravity.dy ?? -9.2) * 150          // pt/s² (SpriteKit: 150 pt per metre)
        let n = max(1, Int((dt / 0.0005).rounded(.up)))
        let h = dt / CGFloat(n)
        var theta = c.theta
        for i in 0..<n {
            let arm = armDirection(theta)
            let acc = 5.0 / 7.0 * (c.omega * c.omega * c.along + g * arm.dy)
            c.rate += acc * h
            c.along += c.rate * h
            theta += c.omega * h
            c.theta = theta
            let atStop = (theta - thetaStop) * raiseSign >= 0
            if atStop { c.theta = thetaStop }
            if c.along > length || atStop { return (true, c.theta, dt - CGFloat(i + 1) * h) }
        }
        return (false, c.theta, 0)
    }

    /// Puts the carried ball on the face at its current angle, moving with it; on release, lets it fly.
    private func place(_ ball: NlBall, _ body: SKPhysicsBody, _ c: Carry, R: CGFloat, release: Bool,
                       at r: (off: Bool, theta: CGFloat, remaining: CGFloat)) {
        let theta = r.theta
        let arm = armDirection(theta)
        let n = CGVector(dx: -sin(theta), dy: cos(theta))
        let a = min(max(c.along, 0), length)
        let off = halfThickness(a) + R + 0.3
        ball.position = CGPoint(x: position.x + a * arm.dx + off * n.dx, y: position.y + a * arm.dy + off * n.dy)
        let w = abs(c.omega)
        body.velocity = CGVector(dx: c.rate * arm.dx + w * a * n.dx, dy: c.rate * arm.dy + w * a * n.dy)
        if r.off, r.remaining > 0 {                                   // off the tip mid-step: fly the rest of it
            ball.position = CGPoint(x: ball.position.x + body.velocity.dx * r.remaining,
                                    y: ball.position.y + body.velocity.dy * r.remaining)
        }
        ball.flipperGhostSteps = release ? 3 : 2
        #if DEBUG
        if release, Self.debugLog {
            let v = body.velocity
            print(String(format: "FLIPRELEASE along %.2f deg %.1f speed %.0f", Double(c.along),
                         Double(atan2(v.dy, v.dx) * 180 / .pi), Double(hypot(v.dx, v.dy))))
        }
        #endif
    }

    #if DEBUG
    static var debugLog = false
    #endif

    /// The flip assist (Lamplight T5 M8 v12; Monsoon Play Lab runs 3–4: the 60 Hz robots were the weak rows). At 60 Hz
    /// the flipper swings a quarter of its travel per physics step and part of the hit is lost untangling the overlap,
    /// so the same flip sends the ball ~15% slower than at 120 Hz. Call after the physics step: if this flipper swung up
    /// this frame and the ball is touching its top face, the ball leaves at least as fast (along the face's normal) as
    /// that point of the face was moving. It never slows a ball, and does nothing at rest or when held up.
    func flipAssist(_ body: SKPhysicsBody, ballAt p: CGPoint, ballRadius: CGFloat) {
        let swung = raised - raisedAtStep
        // 2026-10-23 (Aaron: "60 Hz only"): at 120 Hz the physics already gives the ball the face's speed, and the
        // assist changed shots that were designed and tuned there (GI Hangar 67 → 90 %, Cthulhu upper Lagoon 97 → 40 %),
        // so it only acts on long steps (60 Hz phones, Low Power Mode, a hitch). 1/90 s sits between the two rates.
        guard isPressed, swung > 0.02, stepDt > 1.0 / 90 else { return }   // a real flip step is 0.2–0.4 rad
        let omega = min(swung / stepDt, NlTableLayout.flipperUpSpeed)   // this frame's angular speed (rad/s)
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

        // Milestone 2: the rendered flipper (tools/mon_render_parts.py, bone with a sea-green rubber),
        // pinned at the pivot. Its image spans x -18…114, y -18…18 points around the pivot (mirrored
        // for the right flipper). Falls back to the grey-box shape if the image is missing.
        let imageName = side == .left ? "nl_flipper_left" : "nl_flipper_right"
        let isUpper = len != NlTableLayout.flipperLength
        // Art round 5a: the upper flipper has its own render at its real size (tour_flipper_upper, right-hand).
        if isUpper, side == .right,
           let sprite = NlTableLayout.artSprite("nl_flipper_upper", box: NlTableLayout.upperFlipperArtBox) {
            addChild(sprite)
        } else if UIImage(named: imageName) != nil {
            let sprite = SKSpriteNode(imageNamed: imageName)
            // T3 M3 v2 (Aaron: the ball passed through the upper flipper near its end): the image is drawn
            // for the 96-long main flipper, so scale it to THIS flipper's length and thickness. Drawn at full
            // size, the 64-long upper flipper's picture ran 32 pt past its physics tip.
            sprite.size = CGSize(width: 132 * len / NlTableLayout.flipperLength,
                                 height: 36 * r0 / NlTableLayout.flipperPivotRadius)
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
        body.mass = NlTableLayout.flipperMass
        body.angularDamping = 0
        body.linearDamping = 0
        body.friction = NlTableLayout.flipperFriction
        body.restitution = NlTableLayout.flipperRestitution   // Table 06 M2's real-table rubber
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = NlPhysicsCategory.flipper
        body.collisionBitMask = NlPhysicsCategory.ball
        body.contactTestBitMask = NlPhysicsCategory.none
        physicsBody = body
    }
}
