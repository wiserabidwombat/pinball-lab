// Pinball Lab Table 05 (The Lamplight): the shop cat on her shelf at the top right (milestone 4, grey box).
// She walks the shelf, stops for naps in different spots, and when she's awake and a ball comes within reach she
// swats it back down the table. A ball that hits her pets her (or wakes her from a nap). The scene moves her and
// reports the events; she is a toy (category `toy`), so the ball bounces off her and the contact is reported.
import SpriteKit
import CoreGraphics
import Foundation

final class LmpCat: SKNode {
    enum Mode { case walk, nap, swat }
    enum HitResult { case petted, woke, none }

    private(set) var mode: Mode = .walk
    private var targetX: CGFloat
    private var napUntil: TimeInterval = 0
    private var swatUntil: TimeInterval = 0
    private var lastSwat: TimeInterval = -10
    private var lastHit: TimeInterval = -10
    private var rng = SystemRandomNumberGenerator()

    private let bodyShape: SKShapeNode
    private let head: SKShapeNode
    private let paw: SKShapeNode
    private let tail: SKShapeNode
    private let zzz: SKLabelNode
    /// Everything drawn: flipped and squashed on its own, so the physics body is never scaled.
    private let art = SKNode()

    static let fur = SKColor(red: 0.93, green: 0.62, blue: 0.32, alpha: 1)        // a ginger cat
    static let furDark = SKColor(red: 0.62, green: 0.36, blue: 0.16, alpha: 1)

    init(at x: CGFloat) {
        let r = LmpTableLayout.catRadius
        bodyShape = SKShapeNode(ellipseOf: CGSize(width: r * 2.4, height: r * 1.5))
        head = SKShapeNode(circleOfRadius: r * 0.62)
        paw = SKShapeNode(ellipseOf: CGSize(width: r * 0.7, height: r * 0.45))
        tail = SKShapeNode()
        zzz = SKLabelNode(text: "z z")
        targetX = x
        super.init()
        position = CGPoint(x: x, y: LmpTableLayout.catShelfY)
        zPosition = 12

        for s in [bodyShape, head, paw] {
            s.fillColor = Self.fur
            s.strokeColor = Self.furDark
            s.lineWidth = 1.5
        }
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -r * 1.1, y: 0))
        tailPath.addQuadCurve(to: CGPoint(x: -r * 1.6, y: r * 1.0), control: CGPoint(x: -r * 1.9, y: 0))
        tail.path = tailPath
        tail.strokeColor = Self.furDark
        tail.lineWidth = 4
        tail.lineCap = .round
        addChild(art)
        art.addChild(tail)
        art.addChild(bodyShape)
        head.position = CGPoint(x: r * 1.05, y: r * 0.35)
        art.addChild(head)
        for dx in [-0.35, 0.35] as [CGFloat] {
            let ear = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: dx * r - r * 0.2, y: r * 0.35))
            p.addLine(to: CGPoint(x: dx * r, y: r * 0.85))
            p.addLine(to: CGPoint(x: dx * r + r * 0.2, y: r * 0.35))
            p.closeSubpath()
            ear.path = p
            ear.fillColor = Self.fur
            ear.strokeColor = Self.furDark
            ear.lineWidth = 1.2
            head.addChild(ear)
        }
        paw.position = CGPoint(x: r * 0.9, y: -r * 0.55)
        art.addChild(paw)
        zzz.fontName = "Menlo-Bold"
        zzz.fontSize = 11
        zzz.fontColor = SKColor(white: 1, alpha: 0.85)
        zzz.position = CGPoint(x: r * 1.3, y: r * 1.0)
        zzz.isHidden = true
        addChild(zzz)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0.4
        body.categoryBitMask = LmpPhysicsCategory.toy
        body.collisionBitMask = LmpPhysicsCategory.ball
        body.contactTestBitMask = LmpPhysicsCategory.ball
        physicsBody = body
        pickTarget()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Walks toward her next spot; on arriving, naps there about half the time.
    func update(dt: CGFloat, now: TimeInterval) {
        switch mode {
        case .nap:
            if now >= napUntil { wake() }
        case .swat:
            if now >= swatUntil { mode = .walk }
        case .walk:
            let dx = targetX - position.x
            let step = LmpTableLayout.catWalkSpeed * dt
            if abs(dx) <= step {
                position.x = targetX
                if Double.random(in: 0..<1, using: &rng) < 0.5 {
                    mode = .nap
                    napUntil = now + Double.random(in: LmpTableLayout.catNapSeconds, using: &rng)
                    zzz.isHidden = false
                    zzz.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.8),
                                                      .fadeAlpha(to: 1, duration: 0.8)])), withKey: "zzz")
                    head.run(.moveBy(x: 0, y: -LmpTableLayout.catRadius * 0.3, duration: 0.4))
                } else {
                    pickTarget()
                }
            } else {
                position.x += dx > 0 ? step : -step
                face(dx > 0 ? 1 : -1)
            }
        }
    }

    /// A ball in reach while she's awake: she swats it (at most once every catSwatCooldown). Returns true if she did.
    func trySwat(ballAt p: CGPoint, now: TimeInterval) -> Bool {
        guard mode != .nap, now - lastSwat >= LmpTableLayout.catSwatCooldown,
              hypot(p.x - position.x, p.y - position.y) <= LmpTableLayout.catReach else { return false }
        lastSwat = now
        mode = .swat
        swatUntil = now + 0.35
        face(p.x >= position.x ? 1 : -1)
        paw.removeAllActions()
        let r = LmpTableLayout.catRadius
        paw.run(.sequence([.move(to: CGPoint(x: r * 1.6, y: -r * 0.2), duration: 0.06),
                           .move(to: CGPoint(x: r * 0.9, y: -r * 0.55), duration: 0.2)]))
        return true
    }

    /// The ball bumped her: a nap ends with a start; otherwise she's petted (not more than every 0.3 s).
    func ballHit(now: TimeInterval) -> HitResult {
        guard now - lastHit > 0.3 else { return .none }
        lastHit = now
        if mode == .nap {
            wake()
            run(.sequence([.moveBy(x: 0, y: 8, duration: 0.08), .moveBy(x: 0, y: -8, duration: 0.15)]))
            return .woke
        }
        art.run(.sequence([.scaleY(to: 0.85, duration: 0.06), .scaleY(to: 1, duration: 0.12)]))
        return .petted
    }

    func reset() {
        position = CGPoint(x: LmpTableLayout.catHomeX, y: LmpTableLayout.catShelfY)
        if mode == .nap { wake() }
        mode = .walk
        pickTarget()
    }

    /// Turns her to face right (+1) or left (-1); the z's stay above her head.
    private func face(_ dir: CGFloat) {
        art.xScale = dir
        zzz.position.x = dir * LmpTableLayout.catRadius * 1.3
    }

    private func wake() {
        mode = .walk
        zzz.removeAction(forKey: "zzz")
        zzz.isHidden = true
        head.position = CGPoint(x: LmpTableLayout.catRadius * 1.05, y: LmpTableLayout.catRadius * 0.35)
        pickTarget()
    }

    private func pickTarget() {
        let range = LmpTableLayout.catMinX...LmpTableLayout.catMaxX
        var x = CGFloat.random(in: range, using: &rng)
        if abs(x - position.x) < 40 { x = position.x < (range.lowerBound + range.upperBound) / 2 ? range.upperBound : range.lowerBound }
        targetX = x
    }
}
