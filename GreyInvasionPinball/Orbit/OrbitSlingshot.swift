// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was Slingshot.swift.
import SpriteKit

/// A triangular slingshot. Two sides are plain walls; the third (tip → top)
/// is the kicking face, which fires the ball away along its normal.
final class OrbitSlingshot: SKNode {
    /// Unit vector pointing out of the kicking face, away from the triangle.
    let kickNormal: CGVector
    private let face: SKShapeNode
    private var lastHit: TimeInterval = -1

    /// OrbitPoints are in scene coordinates; the node itself sits at the origin.
    init(top: CGPoint, corner: CGPoint, tip: CGPoint) {
        // Normal to the face (tip - top), flipped if it points into the triangle.
        let d = CGVector(dx: tip.x - top.x, dy: tip.y - top.y)
        let len = max(hypot(d.dx, d.dy), 0.001)
        var n = CGVector(dx: d.dy / len, dy: -d.dx / len)
        if n.dx * (corner.x - top.x) + n.dy * (corner.y - top.y) > 0 {
            n = CGVector(dx: -n.dx, dy: -n.dy)
        }
        kickNormal = n

        let facePath = CGMutablePath()
        facePath.addLines(between: [tip, top])
        face = SKShapeNode(path: facePath)
        super.init()

        // Fill
        let tri = CGMutablePath()
        tri.addLines(between: [top, corner, tip])
        tri.closeSubpath()
        let fill = SKShapeNode(path: tri)
        fill.fillColor = SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.12)
        fill.strokeColor = SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1)
        fill.lineWidth = 3
        fill.lineJoin = .round
        addChild(fill)

        // Passive sides: ordinary wall
        let sides = CGMutablePath()
        sides.addLines(between: [top, corner, tip])
        let sideBody = SKPhysicsBody(edgeChainFrom: sides)
        sideBody.friction = 0.1
        sideBody.restitution = 0.3
        sideBody.categoryBitMask = OrbitPhysicsCategory.wall
        sideBody.collisionBitMask = OrbitPhysicsCategory.ball
        physicsBody = sideBody

        // Kicking face: its own body so contacts can tell it apart
        face.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        face.lineWidth = 4
        face.lineCap = .round
        let faceBody = SKPhysicsBody(edgeFrom: tip, to: top)
        faceBody.friction = 0
        faceBody.restitution = 0
        faceBody.categoryBitMask = OrbitPhysicsCategory.slingshot
        faceBody.collisionBitMask = OrbitPhysicsCategory.ball
        faceBody.contactTestBitMask = OrbitPhysicsCategory.ball
        face.physicsBody = faceBody
        addChild(face)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Fires the ball off the face. Returns false for a repeat contact within 80 ms.
    func hit(ball: SKPhysicsBody, at time: TimeInterval) -> Bool {
        guard time - lastHit > 0.08 else { return false }
        lastHit = time

        // Keep the ball's speed along the face, replace its speed into/out of it with the kick.
        let v = ball.velocity
        let n = kickNormal
        let along = v.dx * n.dx + v.dy * n.dy
        let kick = OrbitTableLayout.slingKickSpeed
        ball.velocity = CGVector(dx: v.dx - n.dx * along + n.dx * kick,
                                 dy: v.dy - n.dy * along + n.dy * kick)

        face.lineWidth = 8   // settle() eases it back to 4
        return true
    }

    /// Called every frame by the scene to settle the face highlight back to normal.
    func settle() {
        if face.lineWidth > 4 { face.lineWidth = max(4, face.lineWidth - 0.5) }
    }
}
