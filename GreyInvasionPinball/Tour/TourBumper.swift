// Pinball Lab Table 06 (Orbit: Grand Tour), M3 v2: a pop bumper (grey box), Table 03/04's proven bumper trimmed of
// their art and shields: on every hit it kicks the ball straight away from its centre at TourTableLayout.bumperKickSpeed.
import SpriteKit
import CoreGraphics
import Foundation

final class TourBumper: SKNode {
    private let disc: SKShapeNode
    private let flashDisc: SKShapeNode
    private var lastHit: TimeInterval = -1

    init(at center: CGPoint) {
        let r = TourTableLayout.bumperRadius
        disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = SKColor(red: 0.88, green: 0.48, blue: 0.38, alpha: 1)
        disc.strokeColor = SKColor(red: 1.0, green: 0.82, blue: 0.72, alpha: 1)
        disc.lineWidth = 2
        flashDisc = SKShapeNode(circleOfRadius: r + 3)
        super.init()
        position = center
        zPosition = 3
        addChild(disc)
        flashDisc.fillColor = .white
        flashDisc.strokeColor = .clear
        flashDisc.blendMode = .add
        flashDisc.alpha = 0
        addChild(flashDisc)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = TourPhysicsCategory.bumper
        body.collisionBitMask = TourPhysicsCategory.ball
        body.contactTestBitMask = TourPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Kicks the ball away from the centre (velocities only: safe in a contact callback). False inside the 50 ms cooldown.
    func hit(ball: SKPhysicsBody, ballPosition: CGPoint, at time: TimeInterval) -> Bool {
        guard time - lastHit > 0.05 else { return false }
        lastHit = time
        let dx = ballPosition.x - position.x, dy = ballPosition.y - position.y
        let len = max(hypot(dx, dy), 0.001)
        let kick = TourTableLayout.bumperKickSpeed
        ball.velocity = CGVector(dx: dx / len * kick, dy: dy / len * kick)
        flashDisc.removeAllActions()
        flashDisc.alpha = 0.6
        flashDisc.run(.fadeOut(withDuration: 0.18))
        disc.removeAction(forKey: "pop")
        disc.setScale(1.1)
        disc.run(.scale(to: 1, duration: 0.12), withKey: "pop")
        return true
    }
}
