import SpriteKit
import CoreGraphics
import Foundation

/// A triangular slingshot. Two sides are plain floor walls. The third side (tip → top)
/// is the rubber: only its middle kicks the ball away along its normal; the ends near
/// the round posts at the top and tip corners are dead, as on real tables (M4 v5).
final class Slingshot: SKNode {
    /// Unit vector pointing out of the kicking face, away from the triangle.
    let kickNormal: CGVector
    private let face: SKShapeNode
    private var lastHit: TimeInterval = -1

    /// Points are in world coordinates; the node itself sits at the origin.
    init(top: CGPoint, corner: CGPoint, tip: CGPoint) {
        // Normal to the face (tip - top), flipped if it points into the triangle.
        let d = CGVector(dx: tip.x - top.x, dy: tip.y - top.y)
        let len = max(hypot(d.dx, d.dy), 0.001)
        var n = CGVector(dx: d.dy / len, dy: -d.dx / len)
        if n.dx * (corner.x - top.x) + n.dy * (corner.y - top.y) > 0 {
            n = CGVector(dx: -n.dx, dy: -n.dy)
        }
        kickNormal = n

        // The kicking part of the face, as fractions along it from the tip to the top.
        func along(_ f: CGFloat) -> CGPoint {
            CGPoint(x: tip.x + (top.x - tip.x) * f, y: tip.y + (top.y - tip.y) * f)
        }
        let kickStart = along(TableLayout.slingKickFrom)
        let kickEnd = along(TableLayout.slingKickTo)

        let facePath = CGMutablePath()
        facePath.addLines(between: [kickStart, kickEnd])
        face = SKShapeNode(path: facePath)
        super.init()

        let green = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)

        // Fill
        let tri = CGMutablePath()
        tri.addLines(between: [top, corner, tip])
        tri.closeSubpath()
        // M8 art round 3 (concept): white plastic with a green inner panel and a dark edge
        let fill = SKShapeNode(path: tri)
        fill.fillColor = SKColor(red: 0.953, green: 0.945, blue: 0.984, alpha: 0.92)
        fill.strokeColor = SKColor(white: 0.17, alpha: 1)
        fill.lineWidth = 2.5
        fill.lineJoin = .round
        addChild(fill)
        let mid = CGPoint(x: (top.x + corner.x + tip.x) / 3, y: (top.y + corner.y + tip.y) / 3)
        let inset = CGMutablePath()
        inset.addLines(between: [top, corner, tip].map {
            CGPoint(x: mid.x + ($0.x - mid.x) * 0.62, y: mid.y + ($0.y - mid.y) * 0.62)
        })
        inset.closeSubpath()
        let panel = SKShapeNode(path: inset)
        panel.fillColor = green.withAlphaComponent(0.35)
        panel.strokeColor = .clear
        panel.zPosition = 0.1
        addChild(panel)

        // Passive sides plus the dead lower end of the face: one ordinary floor wall
        // (top → corner → tip → kick start).
        let sides = CGMutablePath()
        sides.addLines(between: [top, corner, tip, kickStart])
        let sideBody = SKPhysicsBody(edgeChainFrom: sides)
        sideBody.friction = TableLayout.wallFriction
        sideBody.restitution = TableLayout.slingPostRestitution
        sideBody.categoryBitMask = PhysicsCategory.wall
        sideBody.collisionBitMask = PhysicsCategory.ball
        physicsBody = sideBody

        // The dead upper end of the face (kick end → top), as its own wall.
        let upperDead = SKNode()
        let upperBody = SKPhysicsBody(edgeFrom: kickEnd, to: top)
        upperBody.friction = TableLayout.wallFriction
        upperBody.restitution = TableLayout.slingPostRestitution
        upperBody.categoryBitMask = PhysicsCategory.wall
        upperBody.collisionBitMask = PhysicsCategory.ball
        upperDead.physicsBody = upperBody
        addChild(upperDead)

        // Round posts at the top and tip corners: dead, so a ball glancing off them doesn't fly.
        for (center, r) in [(top, TableLayout.slingTopPostRadius), (tip, TableLayout.slingTipPostRadius)] {
            let post = SKShapeNode(circleOfRadius: r)
            post.position = center
            post.fillColor = SKColor(red: 0.85, green: 0.86, blue: 0.89, alpha: 1)   // chrome post
            post.strokeColor = SKColor(red: 0.25, green: 0.26, blue: 0.30, alpha: 1)
            post.lineWidth = 1.5
            post.zPosition = 2
            let body = SKPhysicsBody(circleOfRadius: r)
            body.isDynamic = false
            body.friction = TableLayout.wallFriction
            body.restitution = TableLayout.slingPostRestitution
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.ball
            post.physicsBody = body
            addChild(post)
        }

        // Kicking face: its own body so contacts can tell it apart
        face.strokeColor = SKColor(red: 1.0, green: 0.48, blue: 0.18, alpha: 1)   // orange rubber
        face.lineWidth = 5
        face.lineCap = .round
        let faceBody = SKPhysicsBody(edgeFrom: kickStart, to: kickEnd)
        faceBody.friction = 0
        faceBody.restitution = 0
        faceBody.categoryBitMask = PhysicsCategory.slingshot
        faceBody.collisionBitMask = PhysicsCategory.ball
        faceBody.contactTestBitMask = PhysicsCategory.ball
        face.physicsBody = faceBody
        face.zPosition = 1
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
        let kick = TableLayout.slingKickSpeed
        ball.velocity = CGVector(dx: v.dx - n.dx * along + n.dx * kick,
                                 dy: v.dy - n.dy * along + n.dy * kick)

        face.lineWidth = 9   // settle() eases it back to 5
        return true
    }

    /// Called every frame by the scene to settle the face highlight back to normal.
    func settle() {
        if face.lineWidth > 5 { face.lineWidth = max(5, face.lineWidth - 0.5) }
    }
}
