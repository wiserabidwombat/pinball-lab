// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was Bumper.swift.
import SpriteKit

/// A planet bumper: kicks the ball straight away from its centre on every hit.
final class OrbitBumper: SKNode {
    let glow: SKColor
    private let planet: SKSpriteNode
    private let flashDisc: SKShapeNode
    private var lastHit: TimeInterval = -1

    /// `imageName` is a planet sprite in Assets.xcassets/Art; `glow` tints the rim and hit flash.
    init(at center: CGPoint, imageName: String, glow: SKColor) {
        let r = OrbitTableLayout.bumperRadius
        self.glow = glow
        planet = SKSpriteNode(imageNamed: imageName)
        flashDisc = SKShapeNode(circleOfRadius: r + 3)
        super.init()
        position = center

        // Soft halo behind the planet
        let halo = SKShapeNode(circleOfRadius: r + 3)
        halo.fillColor = glow.withAlphaComponent(0.18)
        halo.strokeColor = glow.withAlphaComponent(0.8)
        halo.lineWidth = 2
        addChild(halo)

        planet.size = CGSize(width: r * 2, height: r * 2)
        addChild(planet)
        // Slow spin so the table feels alive
        planet.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 40)))

        flashDisc.fillColor = .white
        flashDisc.strokeColor = .clear
        flashDisc.blendMode = .add
        flashDisc.alpha = 0
        addChild(flashDisc)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = OrbitPhysicsCategory.bumper
        body.collisionBitMask = OrbitPhysicsCategory.ball
        body.contactTestBitMask = OrbitPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Kicks the ball away. Returns false for a repeat contact within 50 ms (no points).
    func hit(ball: SKPhysicsBody, ballPosition: CGPoint, at time: TimeInterval) -> Bool {
        guard time - lastHit > 0.05 else { return false }
        lastHit = time

        let dx = ballPosition.x - position.x
        let dy = ballPosition.y - position.y
        let len = max(hypot(dx, dy), 0.001)
        let kick = OrbitTableLayout.bumperKickSpeed
        ball.velocity = CGVector(dx: dx / len * kick, dy: dy / len * kick)

        flashDisc.removeAllActions()
        flashDisc.alpha = 0.6
        flashDisc.run(.fadeOut(withDuration: 0.18))
        planet.removeAction(forKey: "pop")
        planet.setScale(1.12)
        planet.run(.scale(to: 1, duration: 0.12), withKey: "pop")
        return true
    }
}
