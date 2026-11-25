// Pinball Lab Table 08 (Neon Labyrinth): the neon look (T8 M3 v1). No SKEffectNodes (they broke under SKRenderer):
// every neon line is a thin bright CORE (an SKShapeNode drawn with additive blending) plus a soft HALO.
//  - The halos of a floor's fixed parts are baked ONCE into one small texture (NlHaloBaker: CoreGraphics strokes with a
//    shadow blur), drawn as one additive sprite under the cores.
//  - Parts that move or change colour (flippers, the turntable, the bridge, rails, lamps, portals) get a live halo: a
//    wide, faint copy of the core path as a child node (`NlNeon.addHalo`), recoloured with the core (`NlNeon.setColor`).
// Preview and recipe: tools/nl_render_neon.py (core 2 pt; halo 7 pt, blurred 6 pt). Colour language (Notion):
// cyan = route / neutral, orange = hazards and locked exits, magenta = rewards and unlocked exits, white = active.
// A table opts in with `NlColumn.neon` (Neon does; 9 to Alive keeps its own look).
import SpriteKit
import UIKit
import CoreGraphics

enum NlNeon {
    static let cyan = SKColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 1)
    static let orange = SKColor(red: 1.0, green: 0.48, blue: 0.08, alpha: 1)
    static let magenta = SKColor(red: 1.0, green: 0.18, blue: 0.86, alpha: 1)
    static let white = SKColor(white: 1, alpha: 1)
    /// The void under the grid.
    static let void = SKColor(red: 0.0, green: 0.0, blue: 0.015, alpha: 1)

    /// Core line width (world points) and the baked halo's width and blur.
    static let coreWidth: CGFloat = 2.0
    static let haloWidth: CGFloat = 7.0
    static let haloBlur: CGFloat = 6.0

    /// Makes a shape a neon core: its stroke in `color`, additive.
    static func core(_ shape: SKShapeNode, _ color: SKColor, width: CGFloat = coreWidth, alpha: CGFloat = 1) {
        shape.strokeColor = color.withAlphaComponent(alpha)
        shape.lineWidth = width
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.blendMode = .add
    }

    /// A live halo under `shape`: two wide, faint copies of its path (additive), named "halo" so `setColor` finds them.
    /// For parts that move or change colour; fixed parts use the baked halo instead.
    static func addHalo(to shape: SKShapeNode, _ color: SKColor, width: CGFloat = 9, alpha: CGFloat = 0.28) {
        guard let path = shape.path else { return }
        for (w, a) in [(width, alpha), (width * 0.55, alpha * 1.4)] {
            let h = SKShapeNode(path: path)
            h.name = "halo"
            h.strokeColor = color.withAlphaComponent(min(1, a))
            h.fillColor = .clear
            h.lineWidth = w
            h.lineCap = .round
            h.lineJoin = .round
            h.blendMode = .add
            h.zPosition = -0.01
            h.userData = ["alpha": min(1, a)]
            shape.addChild(h)
        }
    }

    /// Recolours a core and its live halo.
    static func setColor(_ shape: SKShapeNode, _ color: SKColor, alpha: CGFloat = 1) {
        shape.strokeColor = color.withAlphaComponent(alpha)
        for case let h as SKShapeNode in shape.children where h.name == "halo" {
            let a = (h.userData?["alpha"] as? CGFloat) ?? 0.28
            h.strokeColor = color.withAlphaComponent(a * alpha)
        }
    }

    /// Makes the halo of a live part bigger and brighter (a bloom) or back to normal.
    static func setBloom(_ shape: SKShapeNode, _ on: Bool, base: CGFloat = 9) {
        var i = 0
        for case let h as SKShapeNode in shape.children where h.name == "halo" {
            h.lineWidth = (i == 0 ? base : base * 0.55) * (on ? 2.2 : 1)
            i += 1
        }
    }
}

/// Collects the halos of a floor's fixed parts and bakes them into one additive sprite.
final class NlHaloBaker {
    private var items: [(path: CGPath, color: SKColor, width: CGFloat, alpha: CGFloat)] = []

    /// A halo along `path` (world points, the floor's coordinates).
    func add(_ path: CGPath, _ color: SKColor, width: CGFloat = NlNeon.haloWidth, alpha: CGFloat = 0.7) {
        items.append((path, color, width, alpha))
    }

    func add(points: [CGPoint], closed: Bool = false, _ color: SKColor, width: CGFloat = NlNeon.haloWidth,
             alpha: CGFloat = 0.7) {
        guard points.count >= 2 else { return }
        let p = CGMutablePath()
        p.addLines(between: points)
        if closed { p.closeSubpath() }
        add(p, color, width: width, alpha: alpha)
    }

    func addCircle(_ centre: CGPoint, _ r: CGFloat, _ color: SKColor, width: CGFloat = 6, alpha: CGFloat = 0.6) {
        add(CGPath(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r), transform: nil),
            color, width: width, alpha: alpha)
    }

    /// One sprite (anchor at the floor's origin, `size` world points) holding every halo, blurred. `pixelsPerPoint`
    /// 0.75 keeps it small (a 600 × 1060 floor is 450 × 795 px, ~1.4 MB); halos are soft, so the low resolution
    /// doesn't show.
    /// T8 M4 v3: `cores` bakes the same paths as thin sharp lines instead (no blur): the cell's stand-in on the grid
    /// overview, where drawing every cell's live nodes was too much (sprite "neonCores").
    func makeSprite(size: CGSize, pixelsPerPoint k: CGFloat = 0.75, cores: Bool = false) -> SKSpriteNode? {
        guard !items.isEmpty else { return nil }
        let px = CGSize(width: ceil(size.width * k), height: ceil(size.height * k))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: px.height)      // world (y up) → image (y down)
            cg.scaleBy(x: k, y: -k)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for it in items {
                cg.saveGState()
                if cores {
                    cg.setStrokeColor(it.color.withAlphaComponent(min(1, it.alpha * 1.4)).cgColor)
                    cg.setLineWidth(max(2.4, 1.2 / k))      // at least ~1 px
                    cg.addPath(it.path)
                    cg.strokePath()
                    cg.restoreGState()
                    continue
                }
                // The shadow's blur is in pixels (not scaled by the transform).
                cg.setShadow(offset: .zero, blur: NlNeon.haloBlur * k * 2,
                             color: it.color.withAlphaComponent(it.alpha).cgColor)
                cg.setStrokeColor(it.color.withAlphaComponent(it.alpha * 0.55).cgColor)
                cg.setLineWidth(it.width)
                cg.addPath(it.path)
                cg.strokePath()
                cg.restoreGState()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.anchorPoint = .zero
        sprite.position = .zero
        sprite.blendMode = .add
        sprite.name = cores ? "neonCores" : "neonHalos"
        return sprite
    }
}
