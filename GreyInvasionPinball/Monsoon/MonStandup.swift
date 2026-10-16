// Pinball Lab Table 04 (Monsoon), milestone 3: a standup target (the saguaro bank). Unlike a drop target it never
// goes down: a hit lights it (and flashes), and the scene clears the bank once all of them are lit.
// M9 v3: rendered saguaro standups (tools/mon_render_parts.py) — pencil and color versions cross-faded as the saguaros
// are painted, and a lit version (the cactus flower glows) shown while it's lit. The grey-box plate stays as the
// fallback when the art is missing.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class MonStandup: SKNode {
    /// Lit by a hit; the scene clears the whole bank once every one is lit.
    var isLit = false {
        didSet {
            plate.fillColor = isLit ? Self.litColor : Self.offColor
            litArt?.alpha = isLit ? 1 : 0
        }
    }
    private let plate: SKShapeNode
    private let look = SKNode()
    private let art: SKSpriteNode?
    private let litArt: SKSpriteNode?
    private let sketchArt: SKSpriteNode?
    private var lastHit: TimeInterval = -1
    private static let offColor = SKColor(red: 0.42, green: 0.55, blue: 0.40, alpha: 1)    // saguaro green, dim
    private static let litColor = SKColor(red: 0.72, green: 0.92, blue: 0.62, alpha: 1)
    /// One hit per 0.15 s, so a rattling ball doesn't count twice.
    private static let cooldown: TimeInterval = 0.15
    /// Where the rendered sprite sits round the target's centre (tools/mon_render_parts.py STANDUP_BOX).
    static let artBox = CGRect(x: -14, y: -18, width: 30, height: 42)

    init(at center: CGPoint) {
        let size = MonTableLayout.standupSize
        plate = SKShapeNode(rectOf: size, cornerRadius: 3)
        plate.fillColor = Self.offColor
        plate.strokeColor = SKColor(white: 0.9, alpha: 0.8)
        plate.lineWidth = 1
        art = MonTableLayout.artSprite("mon_standup", box: Self.artBox)
        litArt = MonTableLayout.artSprite("mon_standup_lit", box: Self.artBox)
        sketchArt = MonTableLayout.artSprite("mon_standup_sketch", box: Self.artBox)
        super.init()
        position = center
        zPosition = 1
        addChild(look)
        if let art {
            if let sketchArt {
                look.addChild(sketchArt)
                art.alpha = 0
            }
            look.addChild(art)
            if let litArt {
                litArt.alpha = 0
                look.addChild(litArt)
            }
        } else {
            look.addChild(plate)
        }

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.3
        body.categoryBitMask = MonPhysicsCategory.target
        body.collisionBitMask = MonPhysicsCategory.ball
        body.contactTestBitMask = MonPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// How much of the color art shows over the pencil one (0 = sketch, 1 = color). A lit target always glows in color.
    func setColorAmount(_ amount: CGFloat) {
        guard sketchArt != nil, let art, abs(art.alpha - amount) > 0.004 else { return }
        art.alpha = amount
    }

    /// A ball hit it. Returns false inside the cooldown.
    func hit(at time: TimeInterval) -> Bool {
        guard time - lastHit > Self.cooldown else { return false }
        lastHit = time
        look.removeAllActions()
        look.run(.sequence([.scale(to: 0.85, duration: 0.04), .scale(to: 1, duration: 0.1)]))
        return true
    }
}
