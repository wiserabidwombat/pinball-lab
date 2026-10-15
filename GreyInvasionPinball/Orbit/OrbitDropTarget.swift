// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was DropTarget.swift.
import SpriteKit

/// An asteroid drop target. Hit it once and it drops (the ball passes through);
/// the scene raises the whole bank again once all of them are down.
final class OrbitDropTarget: SKNode {
    private(set) var isDown = false
    /// Set the moment a hit is seen, so repeat contacts that frame don't count twice.
    private(set) var isHit = false
    private let rock: SKSpriteNode

    /// `imageName` is an asteroid sprite in Assets.xcassets/Art.
    init(at center: CGPoint, imageName: String) {
        let size = OrbitTableLayout.dropTargetSize
        rock = SKSpriteNode(imageNamed: imageName)
        super.init()
        position = center

        // The sprite is a bit bigger than the physics box so the rock reads clearly.
        rock.size = OrbitTableLayout.dropTargetSpriteSize
        rock.zRotation = .pi / 2
        addChild(rock)

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.2
        body.collisionBitMask = OrbitPhysicsCategory.ball
        body.contactTestBitMask = OrbitPhysicsCategory.ball
        physicsBody = body
        setUp(true)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Marks the hit. Returns false if it was already hit or down.
    func registerHit() -> Bool {
        guard !isHit, !isDown else { return false }
        isHit = true
        return true
    }

    /// Drops the target. Call from update(), not from inside a contact callback.
    func drop() {
        isDown = true
        setUp(false)
    }

    func raise() {
        isDown = false
        isHit = false
        setUp(true)
    }

    private func setUp(_ up: Bool) {
        physicsBody?.categoryBitMask = up ? OrbitPhysicsCategory.target : OrbitPhysicsCategory.none
        rock.alpha = up ? 1 : 0.12
        rock.setScale(up ? 1 : 0.7)
    }
}
