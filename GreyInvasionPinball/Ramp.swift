import SpriteKit
import CoreGraphics
import Foundation

/// A ramp centerline built from straight runs and arcs, sampled into points.
/// Each point keeps its heading (radians) and its distance along the path.
struct RampPath {
    private(set) var points: [CGPoint]
    private(set) var headings: [CGFloat]
    private(set) var distances: [CGFloat]
    private var heading: CGFloat

    init(start: CGPoint, heading: CGFloat) {
        points = [start]
        headings = [heading]
        distances = [0]
        self.heading = heading
    }

    var length: CGFloat { distances.last ?? 0 }

    /// A straight run in the current heading.
    mutating func line(_ length: CGFloat, step: CGFloat = 10) {
        let n = max(1, Int((length / step).rounded(.up)))
        let start = points[points.count - 1]
        let s0 = self.length
        for i in 1...n {
            let d = length * CGFloat(i) / CGFloat(n)
            points.append(CGPoint(x: start.x + d * cos(heading), y: start.y + d * sin(heading)))
            headings.append(heading)
            distances.append(s0 + d)
        }
    }

    /// An arc. `turn` > 0 bends left (counterclockwise), < 0 bends right.
    mutating func arc(radius: CGFloat, turn: CGFloat, step: CGFloat = 8) {
        let n = max(2, Int((abs(turn) * radius / step).rounded(.up)))
        let sign: CGFloat = turn > 0 ? 1 : -1
        let start = points[points.count - 1]
        let center = CGPoint(x: start.x - sign * radius * sin(heading),
                             y: start.y + sign * radius * cos(heading))
        let a0 = atan2(start.y - center.y, start.x - center.x)
        let s0 = self.length
        let h0 = heading
        for i in 1...n {
            let f = CGFloat(i) / CGFloat(n)
            let a = a0 + turn * f
            points.append(CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a)))
            headings.append(h0 + turn * f)
            distances.append(s0 + abs(turn) * radius * f)
        }
        heading = h0 + turn
    }

    /// The point and heading at distance `s` along the path.
    func sample(at s: CGFloat) -> (point: CGPoint, heading: CGFloat) {
        for i in 1..<points.count where distances[i] >= s {
            let t = (s - distances[i - 1]) / max(distances[i] - distances[i - 1], 0.001)
            let a = points[i - 1], b = points[i]
            return (CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), headings[i])
        }
        return (points[points.count - 1], headings[headings.count - 1])
    }
}

/// A line across the ramp channel. Each frame the scene asks whether the ball's
/// movement crossed it, and in which direction along the ramp.
struct RampSwitch {
    enum Crossing { case none, forward, backward }

    let a: CGPoint
    let b: CGPoint
    let forward: CGVector   // unit vector pointing along the ramp, away from the mouth

    func crossing(from p0: CGPoint, to p1: CGPoint) -> Crossing {
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let side0 = ab.dx * (p0.y - a.y) - ab.dy * (p0.x - a.x)
        let side1 = ab.dx * (p1.y - a.y) - ab.dy * (p1.x - a.x)
        guard (side0 > 0) != (side1 > 0) else { return .none }

        // Where the movement met the line; it must land on the switch, not its extension.
        let t = side0 / (side0 - side1)
        let q = CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
        let u = ((q.x - a.x) * ab.dx + (q.y - a.y) * ab.dy) / max(ab.dx * ab.dx + ab.dy * ab.dy, 0.001)
        guard u >= -0.25, u <= 1.25 else { return .none }

        let along = (p1.x - p0.x) * forward.dx + (p1.y - p0.y) * forward.dy
        return along >= 0 ? .forward : .backward
    }
}

/// A ramp on its own physics layer. Its rails only collide with a ball on the ramp layer,
/// so a ball on the floor rolls underneath it. Short posts at the mouth are floor walls,
/// so a ball that misses the entrance bounces off its edges.
/// The part up to the apex is drawn as plastic; the return after it as a wire.
final class Ramp: SKNode {
    let path: RampPath
    let entrySwitch: RampSwitch     // floor ↔ ramp at the mouth
    let madeSwitch: RampSwitch      // just past the apex: the shot is made
    let exitSwitch: RampSwitch      // end of the wire: back to the floor
    private let mouthHalfWidth: CGFloat
    private let halfWidth: CGFloat
    private let flareLength: CGFloat

    init(path: RampPath, apexDistance: CGFloat,
         mouthHalfWidth: CGFloat, halfWidth: CGFloat, flareLength: CGFloat, postLength: CGFloat) {
        self.path = path
        self.mouthHalfWidth = mouthHalfWidth
        self.halfWidth = halfWidth
        self.flareLength = flareLength

        func width(_ s: CGFloat) -> CGFloat {
            mouthHalfWidth + (halfWidth - mouthHalfWidth) * min(s / flareLength, 1)
        }
        func across(_ s: CGFloat) -> RampSwitch {
            let (p, h) = path.sample(at: s)
            let w = width(s) + 2
            let n = CGVector(dx: -sin(h), dy: cos(h))
            return RampSwitch(a: CGPoint(x: p.x + w * n.dx, y: p.y + w * n.dy),
                              b: CGPoint(x: p.x - w * n.dx, y: p.y - w * n.dy),
                              forward: CGVector(dx: cos(h), dy: sin(h)))
        }
        entrySwitch = across(TableLayout.rampEntryDistance)
        madeSwitch = across(apexDistance + TableLayout.rampMadeAfterApex)
        exitSwitch = across(path.length - TableLayout.rampExitBeforeEnd)
        super.init()

        // Rails: the centerline offset to each side.
        var leftRail: [CGPoint] = []
        var rightRail: [CGPoint] = []
        for (i, p) in path.points.enumerated() {
            let h = path.headings[i]
            let w = width(path.distances[i])
            leftRail.append(CGPoint(x: p.x - w * sin(h), y: p.y + w * cos(h)))
            rightRail.append(CGPoint(x: p.x + w * sin(h), y: p.y - w * cos(h)))
        }
        let plastic = path.distances.indices.filter { path.distances[$0] <= apexDistance }
        let wire = path.distances.indices.filter { path.distances[$0] >= apexDistance }
        let posts = path.distances.indices.filter { path.distances[$0] <= postLength }

        // Plastic band (translucent so a ball underneath still shows)
        let band = CGMutablePath()
        band.addLines(between: plastic.map { leftRail[$0] } + plastic.reversed().map { rightRail[$0] })
        band.closeSubpath()
        let bandNode = SKShapeNode(path: band)
        bandNode.fillColor = SKColor(red: 0.24, green: 1.0, blue: 0.48, alpha: 0.20)   // M8: concept plastic
        bandNode.strokeColor = .clear
        bandNode.zPosition = 20
        addChild(bandNode)

        // M8 art round 2 (from the concept): ribs across the plastic, pale green plastic edges with a
        // white highlight, two-tone silver wire rails, and chrome posts at the mouth.
        for i in stride(from: 0, to: plastic.count, by: 6) {
            let k = plastic[i]
            addLine([leftRail[k], rightRail[k]], color: SKColor(red: 0.75, green: 1.0, blue: 0.82, alpha: 0.18), width: 1, z: 20.5)
        }
        let plasticEdge = SKColor(red: 0.75, green: 1.0, blue: 0.82, alpha: 0.85)
        let plasticShine = SKColor(white: 1, alpha: 0.5)
        let wireDark = SKColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
        let wireLight = SKColor(red: 0.91, green: 0.92, blue: 0.95, alpha: 1)
        let chromeDark = SKColor(red: 0.23, green: 0.25, blue: 0.32, alpha: 1)
        let chrome = SKColor(red: 0.79, green: 0.81, blue: 0.85, alpha: 1)
        for rail in [leftRail, rightRail] {
            addLine(plastic.map { rail[$0] }, color: plasticEdge, width: 2.4)
            addLine(plastic.map { rail[$0] }, color: plasticShine, width: 0.8, z: 21.1)
            addLine(wire.map { rail[$0] }, color: wireDark, width: 2.6)
            addLine(wire.map { rail[$0] }, color: wireLight, width: 1.2, z: 21.1)
            addBody(rail, category: PhysicsCategory.rampWall)           // ramp layer
            addBody(posts.map { rail[$0] }, category: PhysicsCategory.wall)  // floor: entrance posts
            let post = posts.map { rail[$0] }
            addLine(post, color: chromeDark, width: 6.5, z: 1)
            addLine(post, color: chrome, width: 4, z: 1.1)
            addLine(post, color: SKColor(white: 1, alpha: 0.7), width: 1.4, z: 1.2)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// How far a point is from the centerline (used to catch a ball that somehow left the channel).
    func distanceToCenterline(_ q: CGPoint) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        let pts = path.points
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let dx = b.x - a.x, dy = b.y - a.y
            let t = max(0, min(1, ((q.x - a.x) * dx + (q.y - a.y) * dy) / max(dx * dx + dy * dy, 0.001)))
            best = min(best, hypot(q.x - a.x - t * dx, q.y - a.y - t * dy))
        }
        return best
    }

    /// The widest the channel gets (at the mouth), for the escape check.
    var maxHalfWidth: CGFloat { max(mouthHalfWidth, halfWidth) }

    /// The ramp's name printed along its plastic (M8), in Orbitron when it's bundled.
    func addLabel(_ text: String, at point: CGPoint, angle: CGFloat) {
        let label = SKLabelNode(text: text)
        label.fontName = "Orbitron-Bold"
        label.fontSize = 6.5
        label.fontColor = SKColor(red: 0.85, green: 1.0, blue: 0.89, alpha: 0.95)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.zRotation = angle
        label.zPosition = 21.2
        addChild(label)
    }

    private func addLine(_ points: [CGPoint], color: SKColor, width: CGFloat, z: CGFloat = 21) {
        guard points.count > 1 else { return }
        let p = CGMutablePath()
        p.addLines(between: points)
        let node = SKShapeNode(path: p)
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        addChild(node)
    }

    private func addBody(_ points: [CGPoint], category: UInt32) {
        guard points.count > 1 else { return }
        let p = CGMutablePath()
        p.addLines(between: points)
        let body = SKPhysicsBody(edgeChainFrom: p)
        body.friction = TableLayout.rampFriction
        body.restitution = TableLayout.rampRestitution
        body.categoryBitMask = category
        body.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.rampBall
        let holder = SKNode()
        holder.physicsBody = body
        addChild(holder)
    }
}
