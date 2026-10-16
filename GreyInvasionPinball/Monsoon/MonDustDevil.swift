// Pinball Lab Table 04 (Monsoon), milestone 5: the dust devil, a spinning disc set in the playfield. Any floor ball
// crossing it is pushed sideways along the spin (anticlockwise), each frame in update. Gentle normally; much
// stronger while it's "raging" (the rules light it; until then the pause card's debug button does). No physics body:
// the scene applies the push, so it can't trap a ball or tunnel.
import SpriteKit
import CoreGraphics
import Foundation

final class MonDustDevil: SKNode {
    let radius: CGFloat
    /// Raging = the strong push and a faster spin.
    var isRaging = false {
        didSet { guard isRaging != oldValue else { return }; setSpin() }
    }
    private let swirl = SKNode()
    private let rim: SKShapeNode
    /// Push along the spin, pt/s², at the disc's middle ring (it fades to nothing at the centre and the edge). This
    /// is what makes slow balls curl.
    static let calmPush: CGFloat = 600
    static let ragingPush: CGFloat = 1600
    /// T4 M5 v3 (Aaron: on fast shots "it's hard to tell it wobbles the ball at all"): the ball's path also bends by
    /// this many radians per point it travels on the middle ring, so fast balls bend as much as slow ones. Straight
    /// through the middle that's about 1.5° calm and 8° raging.
    /// T4 M6 v2: calm halved (was 0.0009). The Shot Lab found 3° bent left-flipper shots off the mesa ramp's left
    /// post and into the arroyo (ramp 20% vs 47% on Table 03, arroyo 88%); Aaron chose a weaker calm devil.
    static let calmBend: CGFloat = 0.00045
    static let ragingBend: CGFloat = 0.0025

    init(at center: CGPoint, radius: CGFloat) {
        self.radius = radius
        rim = SKShapeNode(circleOfRadius: radius)
        super.init()
        position = center
        zPosition = -18.6                       // a disc in the floor: under the balls and the parts

        // M9 v7: a disc of blown sand — layered rings fading to the middle, a faint dark edge so it reads on the
        // pencil sketch too, and five tapered spiral arms (a soft wide stroke under a bright thin one).
        rim.fillColor = SKColor(red: 0.62, green: 0.52, blue: 0.40, alpha: 0.16)   // sand
        rim.strokeColor = SKColor(red: 0.85, green: 0.78, blue: 0.66, alpha: 0.7)
        rim.lineWidth = 2
        addChild(rim)
        let edge = SKShapeNode(circleOfRadius: radius + 1.5)
        edge.fillColor = .clear
        edge.strokeColor = SKColor(red: 0.12, green: 0.09, blue: 0.08, alpha: 0.35)
        edge.lineWidth = 1.5
        addChild(edge)
        for (k, f) in [0.68, 0.38].enumerated() {
            let ring = SKShapeNode(circleOfRadius: radius * CGFloat(f))
            ring.fillColor = SKColor(red: 0.80, green: 0.68, blue: 0.50, alpha: k == 0 ? 0.10 : 0.14)
            ring.strokeColor = .clear
            addChild(ring)
        }
        for k in 0..<5 {
            let arm = CGMutablePath()
            let a0 = CGFloat(k) * 2 * .pi / 5
            for i in 0...24 {
                let f = CGFloat(i) / 24
                let a = a0 + f * 2.6
                let r = radius * (0.10 + 0.86 * f)
                let p = CGPoint(x: r * cos(a), y: r * sin(a))
                if i == 0 { arm.move(to: p) } else { arm.addLine(to: p) }
            }
            for (color, width) in [(SKColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 0.30), CGFloat(5.5)),
                                   (SKColor(red: 0.95, green: 0.87, blue: 0.72, alpha: 0.75), CGFloat(1.8))] {
                let node = SKShapeNode(path: arm)
                node.strokeColor = color
                node.lineWidth = width
                node.lineCap = .round
                swirl.addChild(node)
            }
        }
        addChild(swirl)
        setSpin()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setSpin() {
        swirl.removeAllActions()
        swirl.run(.repeatForever(.rotate(byAngle: 2 * .pi, duration: isRaging ? 0.45 : 1.6)))
        rim.strokeColor = isRaging ? SKColor(red: 1.0, green: 0.78, blue: 0.45, alpha: 0.95)
                                   : SKColor(red: 0.85, green: 0.78, blue: 0.66, alpha: 0.7)
    }

    /// The ball's new velocity after a frame on the disc, or nil when it's outside it: its path bends anticlockwise
    /// (by distance travelled) and it's pushed along the spin (by time), both strongest on a ring halfway out and
    /// fading to the centre and the edge (no sudden kick on entry).
    func stir(ballAt p: CGPoint, velocity v: CGVector, dt: CGFloat) -> CGVector? {
        let dx = p.x - position.x, dy = p.y - position.y
        let d = hypot(dx, dy)
        guard d < radius, d > 0.5 else { return nil }
        let ring = sin(.pi * d / radius)
        let angle = (isRaging ? Self.ragingBend : Self.calmBend) * ring * hypot(v.dx, v.dy) * dt
        let c = cos(angle), s = sin(angle)
        let bent = CGVector(dx: v.dx * c - v.dy * s, dy: v.dx * s + v.dy * c)
        let push = (isRaging ? Self.ragingPush : Self.calmPush) * ring * dt
        return CGVector(dx: bent.dx - dy / d * push, dy: bent.dy + dx / d * push)
    }
}
