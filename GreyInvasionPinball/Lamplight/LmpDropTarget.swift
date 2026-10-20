// Pinball Lab Table 05 (The Lamplight): Table 03's drop target with the "Lmp" prefix. T5 M2: the size comes from LmpTableLayout.dropTargetSize (wide and short: the bookshelf bank faces down the table).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// A Sigil drop target (from Orbit Pinball's asteroid target). Hit it once and it drops (the ball passes
/// through); the scene raises the whole bank once all of them are down. Art round 2b: a rendered sprite.
final class LmpDropTarget: SKNode {
    private(set) var isDown = false
    /// Set the moment a hit is seen, so repeat contacts that frame don't count twice.
    private(set) var isHit = false
    private let plate: SKShapeNode                // grey box: an orange plate (used when the art is missing)
    /// Art round 2b: the rendered Sigil target, standing or dropped flush.
    private let art: SKSpriteNode?
    private let upTexture: SKTexture?
    private let downTexture: SKTexture?

    /// T5 M9 v8: `book` picks that book's own render (lmp_target_<book> / lmp_target_<book>_down, the four coloured
    /// books of the bookshelf bank); without it, or if those images are missing, the shared lmp_target art is used.
    init(at center: CGPoint, book: Int? = nil) {
        let size = LmpTableLayout.dropTargetSize
        plate = SKShapeNode(rectOf: size, cornerRadius: 2)
        plate.fillColor = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        plate.strokeColor = .clear
        var name = "lmp_target"
        if let book, UIImage(named: "lmp_target_\(book)") != nil { name = "lmp_target_\(book)" }
        let sprite = LmpTableLayout.artSprite(name, box: LmpTableLayout.targetArtBox)
        art = sprite
        upTexture = sprite?.texture
        downTexture = UIImage(named: name + "_down") != nil ? SKTexture(imageNamed: name + "_down") : nil
        super.init()
        position = center
        // T3 M8 v6: targets lower down the bank (nearer the player) draw in front of the ones above them.
        zPosition = 1 + (2000 - center.y) * 0.0005

        if let art { addChild(art) } else { addChild(plate) }

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.2
        body.collisionBitMask = LmpPhysicsCategory.ball
        body.contactTestBitMask = LmpPhysicsCategory.ball
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
        physicsBody?.categoryBitMask = up ? LmpPhysicsCategory.target : LmpPhysicsCategory.none
        if let art {
            if let t = up ? upTexture : downTexture { art.texture = t; art.alpha = 1 } else { art.alpha = up ? 1 : 0.15 }
            return
        }
        plate.alpha = up ? 1 : 0.15
        plate.setScale(up ? 1 : 0.7)
    }
}
