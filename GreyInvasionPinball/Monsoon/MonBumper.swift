// Pinball Lab Table 04 (Monsoon): copied from Table 03 (Cthulhu Rising) with the "Mon" prefix; behaviour unchanged.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// A saucer bumper (grey box): kicks the ball straight away from its centre on every hit.
/// From Orbit Pinball's planet bumper; the saucer art arrives in the art pass (milestone 8).
final class MonBumper: SKNode {
    private let disc: SKShapeNode                 // grey box: a salmon disc (used when the rendered art is missing)
    private let flashDisc: SKShapeNode
    /// Art round 2b: the rendered bumper and its lit cap, cross-faded on a hit.
    private let art: SKSpriteNode?
    private let litArt: SKSpriteNode?
    /// M9 v3: the storm cloud in pencil, under the color one; the color fades in as the sky is painted.
    private let sketchArt: SKSpriteNode?
    private let shieldRing: SKShapeNode           // Mothership shield generator (M7 round 4)
    private var shieldShown = 0
    private var lastHit: TimeInterval = -1

    static let rimColor = SKColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1)

    init(at center: CGPoint) {
        let r = MonTableLayout.bumperRadius
        disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = SKColor(red: 0.88, green: 0.48, blue: 0.42, alpha: 1)
        disc.strokeColor = SKColor(red: 1.0, green: 0.75, blue: 0.65, alpha: 1)
        disc.lineWidth = 2
        flashDisc = SKShapeNode(circleOfRadius: r + 3)
        shieldRing = SKShapeNode(circleOfRadius: r + 8)
        art = MonTableLayout.artSprite("mon_bumper", box: MonTableLayout.bumperArtBox)
        litArt = MonTableLayout.artSprite("mon_bumper_lit", box: MonTableLayout.bumperArtBox)
        sketchArt = MonTableLayout.artSprite("mon_bumper_sketch", box: MonTableLayout.bumperArtBox)
        super.init()
        position = center

        if let art {
            if let sketchArt {
                addChild(sketchArt)
                art.alpha = 0
            }
            addChild(art)
            if let litArt {
                litArt.alpha = 0
                addChild(litArt)
            }
        } else {
            addChild(disc)
        }

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
        body.categoryBitMask = MonPhysicsCategory.bumper
        body.collisionBitMask = MonPhysicsCategory.ball
        body.contactTestBitMask = MonPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// How much of the color art shows over the pencil one (0 = sketch, 1 = color). Only touches the node on change.
    func setColorAmount(_ amount: CGFloat) {
        guard sketchArt != nil, let art, abs(art.alpha - amount) > 0.004 else { return }
        art.alpha = amount
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
        let kick = MonTableLayout.bumperKickSpeed
        ball.velocity = CGVector(dx: dx / len * kick, dy: dy / len * kick)

        if let litArt {
            // The cap lights up and fades back.
            litArt.removeAllActions()
            litArt.alpha = 1
            litArt.run(.sequence([.wait(forDuration: 0.06), .fadeOut(withDuration: 0.22)]))
            return true
        }
        flashDisc.removeAllActions()
        flashDisc.alpha = 0.6
        flashDisc.run(.fadeOut(withDuration: 0.18))
        disc.removeAction(forKey: "pop")
        disc.setScale(1.1)
        disc.run(.scale(to: 1, duration: 0.12), withKey: "pop")
        return true
    }
}
