// Pinball Lab Table 03 (Cthulhu Rising), milestone 4 round 3: the magnet under the ritual circle.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// The magnet's look and its armed/holding state. The pull, grab and fling are done by the scene each frame
/// (velocity changes in update, never in a contact callback): a floor ball within `pullRadius` is pulled
/// toward the centre (harder the closer it gets); a ball that reaches `grabRadius` slower than
/// `grabMaxSpeed` is caught, held with a shiver for `holdTime`, then flung upward. Fast balls only bend.
final class CthMagnet: SKNode {
    enum State { case off, armed, holding }

    private(set) var state: State = .off
    private let core: SKShapeNode
    private let ring: SKShapeNode
    private let glow: SKShapeNode

    init(at center: CGPoint, radius: CGFloat) {
        core = SKShapeNode(circleOfRadius: 12)
        ring = SKShapeNode(circleOfRadius: radius * 0.55)
        glow = SKShapeNode(circleOfRadius: radius)
        super.init()
        position = center
        zPosition = -17                         // on the floor, over the art, under balls and parts

        glow.fillColor = SKColor(red: 0.30, green: 0.85, blue: 0.75, alpha: 1)
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.alpha = 0
        addChild(glow)

        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 0.30, green: 0.85, blue: 0.75, alpha: 1)
        ring.lineWidth = 2
        addChild(ring)

        // A dark steel pole piece with a copper winding round it (art round 2b: the rendered one when present).
        if let art = CthTableLayout.artSprite("cth_magnet", box: CthTableLayout.magnetArtBox) {
            art.zPosition = 0.1
            addChild(art)
        } else {
            core.fillColor = SKColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1)
            core.strokeColor = SKColor(red: 0.78, green: 0.45, blue: 0.22, alpha: 1)
            core.lineWidth = 3
            addChild(core)
        }
        setState(.off)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setState(_ newState: State) {
        state = newState
        ring.removeAllActions()
        glow.removeAllActions()
        switch newState {
        case .off:
            ring.alpha = 0.25
            glow.alpha = 0
        case .armed:
            ring.alpha = 1
            ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
            glow.alpha = 0.08
        case .holding:
            ring.alpha = 1
            glow.alpha = 0.28
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.12, duration: 0.08), .fadeAlpha(to: 0.3, duration: 0.08)])))
        }
    }
}
