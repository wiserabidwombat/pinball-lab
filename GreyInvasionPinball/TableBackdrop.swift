import SpriteKit
import UIKit
import CoreImage

/// iPad polish (2026-10-26): a soft, darkened, blurred copy of a table's own art behind everything, so the space
/// beside the table (iPad landscape, the full-table view on wide screens) isn't flat black. A child of the camera,
/// sized to the view like the drain dimmer, so it stays put while the camera follows the ball.
///
/// 2026-11-06 (Aaron's iPad Air, Cthulhu → Play: the app stopped in SKRenderer.render with Metal's "Set Scissor Rect
/// Validation: rect.y(708) + rect.height(3068) must be <= render pass height(3068)"): this was an SKEffectNode with a
/// CIGaussianBlur, and its shade was 1.3 × the view (3068 = 1.3 × the iPad's 2360 px, 708 = the 30 % overhang). Under
/// SKRenderer the effect node's offscreen pass got a scissor rect shifted by that overhang. Now the blur is done ONCE,
/// at init, with Core Image on a small copy of the art, and the backdrop is two plain sprites: no effect node, no
/// offscreen pass, and nothing to re-render when the view changes size.
@MainActor
final class TableBackdrop: SKNode {
    private let art: SKSpriteNode
    private let shade: SKSpriteNode
    private let aspect: CGFloat

    /// The art is shrunk to this width before blurring (it's drawn soft and dark, so detail is wasted).
    private static let workWidth: CGFloat = 360

    /// Nil when the image isn't in the bundle (the table then keeps its black surround). `blur` is the Gaussian
    /// sigma as a fraction of the art's width (0.016 ≈ the old 26 px radius at an iPad's drawn size).
    init?(imageNamed name: String, blur: CGFloat = 0.016, darkness: CGFloat = 0.55) {
        guard let image = UIImage(named: name), let blurred = Self.blurred(image, sigma: blur) else { return nil }
        aspect = blurred.height > 0 ? CGFloat(blurred.width) / CGFloat(blurred.height) : 1
        art = SKSpriteNode(texture: SKTexture(cgImage: blurred))
        shade = SKSpriteNode(color: .black, size: .zero)
        shade.alpha = darkness
        shade.zPosition = 1
        super.init()
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

    /// A small, blurred copy of the image (edges clamped first, so the blur doesn't darken them).
    private static func blurred(_ image: UIImage, sigma: CGFloat) -> CGImage? {
        guard let cg = image.cgImage, cg.width > 0 else { return nil }
        let scale = min(1, workWidth / CGFloat(cg.width))
        let small = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = small.extent.integral
        let soft = small.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(sigma * extent.width))
            .cropped(to: extent)
        return CIContext(options: nil).createCGImage(soft, from: extent)
    }
}
