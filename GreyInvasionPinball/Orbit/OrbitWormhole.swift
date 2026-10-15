// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was Wormhole.swift.
import SpriteKit

/// The wormhole: a sensor that captures the ball. The scene holds the ball
/// here for OrbitTableLayout.wormholeHold seconds, then ejects it.
final class OrbitWormhole: SKNode {
    override init() {
        let r = OrbitTableLayout.wormholeRadius
        let purple = SKColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 1)
        super.init()
        position = OrbitTableLayout.wormholeCenter

        // Dark core
        let core = SKShapeNode(circleOfRadius: r)
        core.fillColor = SKColor(red: 0.02, green: 0.0, blue: 0.06, alpha: 1)
        core.strokeColor = .clear
        addChild(core)

        // Two counter-rotating rings, tinted purple
        for (scale, seconds, direction) in [(1.25, 3.0, 1.0), (0.85, 2.0, -1.0)] {
            let ring = SKSpriteNode(imageNamed: "orbit_wormholeRing")
            ring.size = CGSize(width: r * 2 * scale, height: r * 2 * scale)
            ring.color = purple
            ring.colorBlendFactor = 1
            ring.blendMode = .add
            ring.alpha = scale > 1 ? 0.9 : 0.6
            addChild(ring)
            ring.run(.repeatForever(.rotate(byAngle: direction * .pi * 2, duration: seconds)))
        }

        let body = SKPhysicsBody(circleOfRadius: OrbitTableLayout.wormholeSensorRadius)
        body.isDynamic = false
        body.categoryBitMask = OrbitPhysicsCategory.wormhole
        body.collisionBitMask = OrbitPhysicsCategory.none   // sensor
        body.contactTestBitMask = OrbitPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
