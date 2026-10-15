import SpriteKit
import CoreGraphics
import Foundation

/// A fighter drop target (grey box; from Orbit Pinball's asteroid target). Hit it once and it
/// drops (the ball passes through); the scene raises the whole bank once all of them are down.
/// The fighter-ship art arrives in the art pass (milestone 8).
final class DropTarget: SKNode {
    private(set) var isDown = false
    /// Set the moment a hit is seen, so repeat contacts that frame don't count twice.
    private(set) var isHit = false
    private let plate: SKSpriteNode               // M8 art round 3: a little fighter (fighter.png)

    init(at center: CGPoint) {
        let size = TableLayout.dropTargetSize
        plate = SKSpriteNode(imageNamed: "fighter")
        plate.size = size
        super.init()
        position = center

        addChild(plate)

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.2
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
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
        physicsBody?.categoryBitMask = up ? PhysicsCategory.target : PhysicsCategory.none
        plate.alpha = up ? 1 : 0.15
        plate.setScale(up ? 1 : 0.7)
    }
}
