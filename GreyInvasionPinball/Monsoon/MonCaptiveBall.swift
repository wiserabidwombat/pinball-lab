// Pinball Lab Table 04 (Monsoon), milestone 5: the captive ball. A second steel ball that never leaves its short
// channel on the left side. Its channel points at the right flipper; two posts at the mouth are closer together than a
// ball is wide, so the captive ball rests against them, just showing through the gap, and the player's ball can't get
// in. Hit it and it rolls up the channel; reaching the far end hits the target there. Physics: a dynamic body in the
// "toy" category (player balls already collide with toys), colliding with walls and player balls; the channel is
// ordinary wall, so it's solid for player balls from outside too.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class MonCaptiveBall: SKNode {
    /// The ball itself (a child node with the physics body; the scene reads its position).
    let ball: SKNode
    private let mouth: CGPoint
    private let axis: CGVector
    private let target: SKShapeNode
    private var targetLitUntil: TimeInterval = 0
    private var lastTopAt: TimeInterval = -1

    init(mouth: CGPoint, heading: CGFloat, length: CGFloat, halfWidth: CGFloat) {
        self.mouth = mouth
        axis = CGVector(dx: cos(heading), dy: sin(heading))
        let n = CGVector(dx: -axis.dy, dy: axis.dx)
        let end = CGPoint(x: mouth.x + axis.dx * length, y: mouth.y + axis.dy * length)
        func off(_ p: CGPoint, _ k: CGFloat) -> CGPoint { CGPoint(x: p.x + n.dx * k, y: p.y + n.dy * k) }

        let r = MonTableLayout.ballRadius
        let look = SKSpriteNode(imageNamed: "ball")
        look.size = CGSize(width: r * 2 * MonBall.lookScale, height: r * 2 * MonBall.lookScale)
        let node = SKNode()
        node.addChild(look)
        ball = node
        target = SKShapeNode(rectOf: CGSize(width: halfWidth * 2 - 4, height: 6), cornerRadius: 2)
        super.init()

        // The channel: two sides and the end cap (ordinary walls), drawn as a dark slot with a rim.
        let slot = CGMutablePath()
        slot.addLines(between: [off(mouth, halfWidth), off(end, halfWidth), off(end, -halfWidth), off(mouth, -halfWidth)])
        slot.closeSubpath()
        let floor = SKShapeNode(path: slot)
        floor.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 0.88)     // M9 v7: dusky violet slot
        floor.strokeColor = .clear
        floor.zPosition = -18.5
        addChild(floor)
        for side in [[off(mouth, halfWidth), off(end, halfWidth), off(end, -halfWidth), off(mouth, -halfWidth)]] {
            let p = CGMutablePath()
            p.addLines(between: side)
            // M9 v7: steel rails like the wires — an ink outline, steel, and a bright highlight
            for (color, width, z) in [(SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.6), CGFloat(5.2), CGFloat(1.9)),
                                      (SKColor(red: 0.50, green: 0.52, blue: 0.58, alpha: 1), CGFloat(3.2), CGFloat(1.95))] {
                let look = SKShapeNode(path: p)
                look.strokeColor = color
                look.lineWidth = width
                look.lineCap = .round
                look.lineJoin = .round
                look.zPosition = z
                addChild(look)
            }
            let wall = SKShapeNode(path: p)
            wall.strokeColor = SKColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1)
            wall.lineWidth = 1.1
            wall.lineCap = .round
            wall.lineJoin = .round
            wall.zPosition = 2
            let body = SKPhysicsBody(edgeChainFrom: p)
            body.friction = 0.05
            body.restitution = 0.2
            body.categoryBitMask = MonPhysicsCategory.wall
            body.collisionBitMask = MonPhysicsCategory.ball | MonPhysicsCategory.toy
            wall.physicsBody = body
            addChild(wall)
        }
        // The mouth posts: 4 pt posts on the side walls' ends (the gap between them is narrower than a ball).
        for k in [halfWidth, -halfWidth] {
            let post = SKShapeNode(circleOfRadius: 4)
            post.position = off(mouth, k)
            post.fillColor = SKColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)      // chrome post, brass cap
            post.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.7)
            post.lineWidth = 1.2
            post.zPosition = 3
            let cap = SKShapeNode(circleOfRadius: 1.8)
            cap.fillColor = SKColor(red: 0.86, green: 0.66, blue: 0.30, alpha: 1)
            cap.strokeColor = .clear
            post.addChild(cap)
            let body = SKPhysicsBody(circleOfRadius: 4)
            body.isDynamic = false
            body.restitution = 0.2
            body.categoryBitMask = MonPhysicsCategory.wall
            body.collisionBitMask = MonPhysicsCategory.ball | MonPhysicsCategory.toy
            post.physicsBody = body
            addChild(post)
        }
        // The target at the far end, lit when the captive ball reaches it.
        target.position = CGPoint(x: end.x - axis.dx * 3, y: end.y - axis.dy * 3)
        target.zRotation = heading + .pi / 2
        target.fillColor = SKColor(red: 0.42, green: 0.55, blue: 0.40, alpha: 1)
        target.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.6)
        target.lineWidth = 1
        target.zPosition = 1.5
        addChild(target)

        // The captive ball, resting against the mouth posts.
        node.position = CGPoint(x: mouth.x + axis.dx * 10, y: mouth.y + axis.dy * 10)
        node.zPosition = 9
        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = MonTableLayout.ballMass
        body.restitution = 0.5                 // passes most of a hit on up the channel
        body.friction = 0.1
        body.linearDamping = 0.05
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = MonPhysicsCategory.toy
        body.collisionBitMask = MonPhysicsCategory.wall | MonPhysicsCategory.ball
        body.contactTestBitMask = 0
        node.physicsBody = body
        addChild(node)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// How far up the channel the captive ball is (from the mouth, along the channel).
    var travel: CGFloat {
        let p = ball.position
        return (p.x - mouth.x) * axis.dx + (p.y - mouth.y) * axis.dy
    }

    /// Call every frame: true once when the captive ball reaches the far end (then not again for 0.5 s).
    func reachedTop(at time: TimeInterval, length: CGFloat) -> Bool {
        if time > targetLitUntil { target.fillColor = SKColor(red: 0.42, green: 0.55, blue: 0.40, alpha: 1) }
        guard travel > length - MonTableLayout.ballRadius - 4, time - lastTopAt > 0.5 else { return false }
        lastTopAt = time
        targetLitUntil = time + 0.4
        target.fillColor = SKColor(red: 0.72, green: 0.92, blue: 0.62, alpha: 1)
        return true
    }

    /// Back to rest (a new game).
    func reset() {
        ball.physicsBody?.velocity = .zero
        ball.position = CGPoint(x: mouth.x + axis.dx * 10, y: mouth.y + axis.dy * 10)
    }
}
