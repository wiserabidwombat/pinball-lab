import SpriteKit
import CoreGraphics
import Foundation

/// A saucer bumper (grey box): kicks the ball straight away from its centre on every hit.
/// From Orbit Pinball's planet bumper; the saucer art arrives in the art pass (milestone 8).
final class Bumper: SKNode {
    private let disc: SKSpriteNode                // M8 art round 3: the saucer sprite (bumper.png)
    private let flashDisc: SKShapeNode
    private let shieldRing: SKShapeNode           // Mothership shield generator (M7 round 4)
    private var shieldShown = 0
    private var lastHit: TimeInterval = -1

    static let rimColor = SKColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1)

    init(at center: CGPoint) {
        let r = TableLayout.bumperRadius
        disc = SKSpriteNode(imageNamed: "bumper")
        disc.size = CGSize(width: (r + 2) * 2, height: (r + 2) * 2)   // 60 pt: the rim sits on the body's edge
        flashDisc = SKShapeNode(circleOfRadius: r + 3)
        shieldRing = SKShapeNode(circleOfRadius: r + 8)
        super.init()
        position = center

        addChild(disc)

        flashDisc.fillColor = .white
        flashDisc.strokeColor = .clear
        flashDisc.blendMode = .add
        flashDisc.alpha = 0
        addChild(flashDisc)

        shieldRing.fillColor = .clear
        shieldRing.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        shieldRing.glowWidth = 3
        shieldRing.isHidden = true
        addChild(shieldRing)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = PhysicsCategory.bumper
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Mothership finale: a cyan shield ring, thicker the more hits it has left; nil or 0 hides it.
    func setShield(hitsLeft: Int?) {
        let shown = max(hitsLeft ?? 0, 0)
        guard shown != shieldShown else { return }      // called every frame: only redraw on change
        shieldShown = shown
        guard let hits = hitsLeft, hits > 0 else {
            shieldRing.isHidden = true
            return
        }
        shieldRing.isHidden = false
        shieldRing.lineWidth = CGFloat(hits) * 2
    }

    /// Kicks the ball away. Returns false for a repeat contact within 50 ms (no points).
    func hit(ball: SKPhysicsBody, ballPosition: CGPoint, at time: TimeInterval) -> Bool {
        guard time - lastHit > 0.05 else { return false }
        lastHit = time

        let dx = ballPosition.x - position.x
        let dy = ballPosition.y - position.y
        let len = max(hypot(dx, dy), 0.001)
        let kick = TableLayout.bumperKickSpeed
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
