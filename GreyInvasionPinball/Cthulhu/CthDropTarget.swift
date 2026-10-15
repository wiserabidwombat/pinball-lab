// Pinball Lab Table 03: copied from Grey Invasion (milestone 3) with the "Cth" prefix.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// A Sigil drop target (from Orbit Pinball's asteroid target). Hit it once and it drops (the ball passes
/// through); the scene raises the whole bank once all of them are down. Art round 2b: a rendered sprite.
final class CthDropTarget: SKNode {
    private(set) var isDown = false
    /// Set the moment a hit is seen, so repeat contacts that frame don't count twice.
    private(set) var isHit = false
    private let plate: SKShapeNode                // grey box: an orange plate (used when the art is missing)
    /// Art round 2b: the rendered Sigil target, standing or dropped flush.
    private let art: SKSpriteNode?
    private let upTexture: SKTexture?
    private let downTexture: SKTexture?

    init(at center: CGPoint) {
        let size = CthTableLayout.dropTargetSize
        plate = SKShapeNode(rectOf: size, cornerRadius: 2)
        plate.fillColor = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        plate.strokeColor = .clear
        let sprite = CthTableLayout.artSprite("cth_target", box: CthTableLayout.targetArtBox)
        art = sprite
        upTexture = sprite?.texture
        downTexture = UIImage(named: "cth_target_down") != nil ? SKTexture(imageNamed: "cth_target_down") : nil
        super.init()
        position = center
        // T3 M8 v6: targets lower down the bank (nearer the player) draw in front of the ones above them.
        zPosition = 1 + (2000 - center.y) * 0.0005

        if let art { addChild(art) } else { addChild(plate) }

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.2
        body.collisionBitMask = CthPhysicsCategory.ball
        body.contactTestBitMask = CthPhysicsCategory.ball
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
        physicsBody?.categoryBitMask = up ? CthPhysicsCategory.target : CthPhysicsCategory.none
        if let art {
            if let t = up ? upTexture : downTexture { art.texture = t; art.alpha = 1 } else { art.alpha = up ? 1 : 0.15 }
            return
        }
        plate.alpha = up ? 1 : 0.15
        plate.setScale(up ? 1 : 0.7)
    }
}
