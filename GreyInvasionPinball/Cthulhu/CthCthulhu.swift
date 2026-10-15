// Pinball Lab Table 03 (Cthulhu Rising), milestone 4 round 4: Cthulhu himself, the moving toy in the Lagoon.
import SpriteKit
import CoreGraphics
import Foundation

/// Cthulhu rises out of the Lagoon, sways side to side as a moving target, and sinks again.
/// The head is a heavy dynamic body (like the pinned flippers, but sliding): each frame the scene calls
/// `step`, which sets its velocity so it lands exactly on the sway position, so a ball that meets it is
/// batted with the head's real speed. It collides only with balls (category `toy`), and only while awake.
/// The look is drawn a little up the table (its height, at the 22° oblique angle); the body stays on the floor.
final class CthCthulhu: SKNode {
    enum State { case asleep, rising, awake, sinking }

    private(set) var state: State = .asleep
    private let home: CGPoint
    private let look = SKNode()
    private let flash: SKNode
    private let ripple: SKShapeNode
    private var tentacles: [SKNode] = []
    /// Art round 4: the rendered head and tentacles (cth_cthulhu, cth_tentacle0…4) when they're in the app;
    /// otherwise the grey-box shapes.
    private let hasArt: Bool
    private var eyeGlows: [SKShapeNode] = []
    private var phaseStart: TimeInterval = 0
    private var lastHit: TimeInterval = -1

    // T3 M5 v2 (Shot Lab run 2: hit 88% from the upper flipper, and where he was in his sway barely mattered):
    // a smaller head and a wider, quicker sway, so hitting him is about timing.
    static let headRadius: CGFloat = 18           // was 22
    static let swayAmplitude: CGFloat = 40        // ± points (was 30): from x 452 his left edge reaches 394, 28 pt (1.5 balls) from the right bumper
    static let swayPeriod: TimeInterval = 3       // seconds per full sway (was 4; peak speed ~84 pt/s)
    static let riseTime: TimeInterval = 1.2
    static let sinkTime: TimeInterval = 1.0
    /// How far up the table the look is drawn: his head is ~20 pt tall, × tan 22°.
    static let lookLift: CGFloat = 20 * CthTableLayout.oblique

    var isAwake: Bool { state == .awake }
    /// True from the moment he starts rising until he's fully under again (the Lagoon is covered).
    var isUp: Bool { state != .asleep }

    init(at center: CGPoint) {
        home = center
        let headArt = CthTableLayout.artSprite("cth_cthulhu", box: CthTableLayout.cthulhuArtBox)
        let tentacleArt = CthTableLayout.tentacleArtBoxes.indices.compactMap {
            CthTableLayout.artSprite("cth_tentacle\($0)", box: CthTableLayout.tentacleArtBoxes[$0])
        }
        let art = headArt != nil && tentacleArt.count == CthTableLayout.tentacleArtBoxes.count
        hasArt = art                                 // (a local: self can't be read before super.init)
        if art, let headArt {
            // the hit flash: a copy of the head, added on top
            let f = SKSpriteNode(texture: headArt.texture, size: headArt.size)
            f.anchorPoint = headArt.anchorPoint
            f.position = CGPoint(x: 0, y: -Self.lookLift)
            f.blendMode = .add
            flash = f
        } else {
            let f = SKShapeNode(circleOfRadius: Self.headRadius + 4)
            f.fillColor = .white
            f.strokeColor = .clear
            f.blendMode = .add
            flash = f
        }
        ripple = SKShapeNode(circleOfRadius: Self.headRadius + 18)
        super.init()
        position = center
        zPosition = 3

        ripple.fillColor = .clear
        ripple.strokeColor = SKColor(red: 0.30, green: 0.85, blue: 0.75, alpha: 0.6)
        ripple.lineWidth = 2
        ripple.zPosition = -1
        addChild(ripple)

        look.position = CGPoint(x: 0, y: Self.lookLift)
        addChild(look)
        if hasArt, let headArt {
            // The rendered sprites are already drawn in the lean, so they sit at the physics centre, not lifted.
            let down = CGPoint(x: 0, y: -Self.lookLift)
            for (i, t) in tentacleArt.enumerated() {
                let base = CthTableLayout.tentacleBases[i]
                let a = base.degrees * .pi / 180
                t.position = CGPoint(x: down.x + base.distance * sin(a), y: down.y - base.distance * cos(a))
                t.zPosition = i == 2 ? -0.6 : -0.5          // the raised one behind his head
                look.addChild(t)
                tentacles.append(t)
            }
            headArt.position = down
            look.addChild(headArt)
            // a soft amber glow on each eye, breathing
            for e in CthTableLayout.cthulhuEyes {
                let g = SKShapeNode(circleOfRadius: 3.6)
                g.position = CGPoint(x: e.x, y: e.y + down.y)
                g.fillColor = SKColor(red: 1.0, green: 0.62, blue: 0.15, alpha: 1)
                g.strokeColor = .clear
                g.blendMode = .add
                g.zPosition = 0.5
                look.addChild(g)
                eyeGlows.append(g)
            }
        } else {
            // Grey box: curling strokes below the head, waving in update (drawn under it).
            for i in 0..<5 {
                let t = SKShapeNode()
                t.strokeColor = SKColor(red: 0.20, green: 0.42, blue: 0.36, alpha: 1)
                t.lineWidth = i == 2 ? 6 : 5
                t.lineCap = .round
                t.zPosition = -0.5
                look.addChild(t)
                tentacles.append(t)
            }
            let head = SKShapeNode(circleOfRadius: Self.headRadius)
            head.fillColor = SKColor(red: 0.16, green: 0.34, blue: 0.29, alpha: 1)
            head.strokeColor = SKColor(red: 0.42, green: 0.70, blue: 0.58, alpha: 1)
            head.lineWidth = 2
            look.addChild(head)
            for dx in [-8.0, 8.0] {                      // glowing eyes
                let eye = SKShapeNode(ellipseOf: CGSize(width: 7, height: 4))
                eye.position = CGPoint(x: dx, y: 5)
                eye.fillColor = SKColor(red: 1.0, green: 0.86, blue: 0.35, alpha: 1)
                eye.strokeColor = .clear
                eye.glowWidth = 2
                head.addChild(eye)
            }
        }
        flash.alpha = 0
        flash.zPosition = 1
        look.addChild(flash)

        let body = SKPhysicsBody(circleOfRadius: Self.headRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.mass = 500                              // the ball (0.08) barely moves him; step() resets him anyway
        body.linearDamping = 0
        body.friction = 0.2
        body.restitution = 0.5
        body.usesPreciseCollisionDetection = true
        // Solid only while awake (setSolid). Both masks are cleared when he's down: a collision happens if
        // EITHER body's mask includes the other, so a sleeping Cthulhu with a ball mask would block the Lagoon.
        body.categoryBitMask = CthPhysicsCategory.none
        body.collisionBitMask = CthPhysicsCategory.none
        body.contactTestBitMask = CthPhysicsCategory.ball
        physicsBody = body
        setVisible(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func rise(at now: TimeInterval) {
        guard state == .asleep else { return }
        state = .rising
        phaseStart = now
        if let parent { CthEffects.splash(in: parent, at: position, radius: 46, rings: 4, drops: 36) }   // juice round 3
    }

    func sink(at now: TimeInterval) {
        guard state == .awake || state == .rising else { return }
        state = .sinking
        phaseStart = now
        setSolid(false)
        if let parent { CthEffects.splash(in: parent, at: position, radius: 38, rings: 3, drops: 24) }
    }

    /// Where Awakening tentacle `i` (0…3) leaves the water, in the parent's coordinates (for the cut splash).
    func tentacleBase(_ i: Int) -> CGPoint {
        guard Self.cuttable.indices.contains(i) else { return position }
        let base = CthTableLayout.tentacleBases[Self.cuttable[i]]
        let a = base.degrees * .pi / 180
        return CGPoint(x: position.x + base.distance * sin(a), y: position.y - base.distance * cos(a))
    }

    /// Shot Lab: straight to awake (no rise), swaying from the centre.
    func forceAwake(at now: TimeInterval) {
        state = .awake
        phaseStart = now
        position = home
        setSolid(true)
        setVisible(1)
    }

    /// Where he is in his sway, 0–1 (0 = centre moving right, 0.25 = far right, 0.75 = far left), or nil
    /// when he isn't awake. Needs the same clock as step().
    func swayPhase(at now: TimeInterval) -> Double? {
        guard state == .awake else { return nil }
        let t = (now - phaseStart) / Self.swayPeriod
        return t - t.rounded(.down)
    }

    func reset() {
        state = .asleep
        setSolid(false)
        physicsBody?.velocity = .zero
        position = home
        setVisible(0)
    }

    /// Call every frame before physics.
    func step(dt: CGFloat, now: TimeInterval) {
        guard let body = physicsBody else { return }
        let t = now - phaseStart
        switch state {
        case .asleep:
            body.velocity = .zero
            position = home
            return
        case .rising:
            let f = CGFloat(min(t / Self.riseTime, 1))
            setVisible(f)
            body.velocity = .zero
            position = home
            if f >= 1 {
                state = .awake
                phaseStart = now
                setSolid(true)
            }
        case .sinking:
            let f = CGFloat(min(t / Self.sinkTime, 1))
            setVisible(1 - f)
            body.velocity = .zero
            if f >= 1 {
                state = .asleep
                position = home
            }
        case .awake:
            // Sway: x = home + A sin(2π t / P). Velocity set so the head lands exactly on the next position.
            let next = t + TimeInterval(dt)
            let targetX = home.x + Self.swayAmplitude * CGFloat(sin(2 * .pi * next / Self.swayPeriod))
            if dt > 0 {
                body.velocity = CGVector(dx: (targetX - position.x) / dt, dy: (home.y - position.y) / dt)
            }
            body.isResting = false
        }
        waveTentacles(now)
    }

    /// A ball hit him. Returns false for a repeat contact within 150 ms.
    func hit(at time: TimeInterval) -> Bool {
        guard isAwake, time - lastHit > 0.15 else { return false }
        lastHit = time
        flash.removeAllActions()
        flash.alpha = hasArt ? 0.55 : 0.7
        flash.run(.fadeOut(withDuration: 0.25))
        look.removeAction(forKey: "recoil")
        look.setScale(1.12)
        look.run(.scale(to: 1, duration: 0.18), withKey: "recoil")
        return true
    }

    /// The Awakening's four tentacles (M7 v4) are the drawn ones left and right of the middle one; a cut one
    /// withers to a faint stub. The middle tentacle always stays.
    private static let cuttable = [0, 1, 3, 4]

    func setTentacle(_ i: Int, cut: Bool) {
        guard Self.cuttable.indices.contains(i) else { return }
        let t = tentacles[Self.cuttable[i]]
        t.removeAllActions()
        t.run(.fadeAlpha(to: cut ? 0.12 : 1, duration: cut ? 0.25 : 0.6))
    }

    func regrowTentacles() {
        for i in Self.cuttable.indices { setTentacle(i, cut: false) }
    }

    private func setSolid(_ solid: Bool) {
        physicsBody?.categoryBitMask = solid ? CthPhysicsCategory.toy : CthPhysicsCategory.none
        physicsBody?.collisionBitMask = solid ? CthPhysicsCategory.ball : CthPhysicsCategory.none
    }

    /// 0 = under the water, 1 = fully risen.
    private func setVisible(_ f: CGFloat) {
        look.alpha = f
        look.setScale(0.35 + 0.65 * f)
        ripple.alpha = 0.8 * f
        ripple.isHidden = f <= 0
    }

    private func waveTentacles(_ now: TimeInterval) {
        if hasArt {
            // each rendered tentacle sways about its base; the eyes breathe
            for (i, t) in tentacles.enumerated() {
                t.zRotation = 0.10 * CGFloat(sin(now * 3 + Double(i) * 1.3))
            }
            let glow = 0.45 + 0.25 * CGFloat(sin(now * 2.2))
            for g in eyeGlows { g.alpha = glow }
            return
        }
        for (i, t) in tentacles.enumerated() {
            guard let t = t as? SKShapeNode else { continue }
            let base = CGFloat(i - 2) * 9
            let w = CGFloat(sin(now * 3 + Double(i) * 1.3))
            let p = CGMutablePath()
            p.move(to: CGPoint(x: base * 0.6, y: -8))
            p.addQuadCurve(to: CGPoint(x: base * 1.6 + w * 8, y: -38),
                           control: CGPoint(x: base * 1.2 - w * 10, y: -24))
            t.path = p
        }
    }
}
