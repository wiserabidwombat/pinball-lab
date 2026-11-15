// Pinball Lab Table 07 (CHOMP!), M1: the beach-ball pop bumper, grey box. Table 06's TourBumper without the art and
// lights: on every hit it kicks the ball straight away from its centre at ChompTableLayout.bumperKickSpeed.
import SpriteKit
import CoreGraphics
import Foundation

final class ChompBumper: SKNode {
    private let flashDisc: SKShapeNode
    private var lastHit: TimeInterval = -1

    init(at center: CGPoint) {
        let r = ChompTableLayout.bumperRadius
        flashDisc = SKShapeNode(circleOfRadius: r - 1)
        super.init()
        position = center
        zPosition = 3
        // Grey-box colours that read on device (the skill): a salmon disc with a white ring.
        let disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = SKColor(red: 0.98, green: 0.52, blue: 0.45, alpha: 1)
        disc.strokeColor = SKColor(white: 1, alpha: 0.85)
        disc.lineWidth = 3
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
        body.categoryBitMask = ChompPhysicsCategory.bumper
        body.collisionBitMask = ChompPhysicsCategory.ball
        body.contactTestBitMask = ChompPhysicsCategory.ball
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
        let kick = ChompTableLayout.bumperKickSpeed
        ball.velocity = CGVector(dx: dx / len * kick, dy: dy / len * kick)
        flashDisc.removeAllActions()
        flashDisc.alpha = 0.6
        flashDisc.run(.fadeOut(withDuration: 0.18))
        return true
    }
}
