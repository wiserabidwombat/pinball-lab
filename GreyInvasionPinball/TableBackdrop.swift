import SpriteKit
import UIKit

/// iPad polish (2026-10-26): a soft, darkened, blurred copy of a table's own art behind everything, so the space
/// beside the table (iPad landscape, the full-table view on wide screens) isn't flat black. A child of the camera,
/// sized to the view like the drain dimmer, so it stays put while the camera follows the ball. Rasterized once:
/// the blur only re-renders when the view's size changes.
@MainActor
final class TableBackdrop: SKEffectNode {
    private let art: SKSpriteNode
    private let shade: SKSpriteNode
    private let aspect: CGFloat

    /// Nil when the image isn't in the bundle (the table then keeps its black surround).
    init?(imageNamed name: String, blur: CGFloat = 26, darkness: CGFloat = 0.55) {
        guard UIImage(named: name) != nil else { return nil }
        let texture = SKTexture(imageNamed: name)
        let size = texture.size()
        aspect = size.height > 0 ? size.width / size.height : 1
        art = SKSpriteNode(texture: texture)
        shade = SKSpriteNode(color: .black, size: .zero)
        shade.alpha = darkness
        shade.zPosition = 1
        super.init()
        filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
        shouldEnableEffects = true
        shouldRasterize = true
        zPosition = -100                          // behind the floor (−20) and every part
        isUserInteractionEnabled = false
        addChild(art)
        addChild(shade)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Cover a view of this size (in the camera's units, like the dimmer): aspect-fill, 15 % over so the blur's
    /// soft edges stay off screen.
    func fit(_ viewSize: CGSize) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let width = max(viewSize.width, viewSize.height * aspect) * 1.15
        art.size = CGSize(width: width, height: width / aspect)
        shade.size = CGSize(width: viewSize.width * 1.3, height: viewSize.height * 1.3)
    }
}
