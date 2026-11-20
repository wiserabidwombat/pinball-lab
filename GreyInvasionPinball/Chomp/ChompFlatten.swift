// Pinball Lab Table 07 (CHOMP!), M3 v19c: paints the table's static vector shapes into textures once at load.
// Aaron (11-20, iPhone 17 Pro Max): "the ball doesn't move super smooth … very subtle steps" — the frame readout showed
// jitter up to 6 ms and 38–41 of ~60 frames per half second over 10.8 ms while our CPU work stayed at 0.2–1.2 ms, in
// every camera: the frames were lost drawing hundreds of SKShapeNodes (walls, ramp plastics, wires, ties, shadows).
// Until the table has baked art, the shapes that never change are drawn with Core Graphics into a few sprites (grouped
// by depth so the layering stays the same) and the shape nodes are hidden; their physics bodies stay as they are.
import SpriteKit
import UIKit

@MainActor
enum ChompFlatten {
    /// One shape to paint: its path in scene coordinates comes from `transform`; `z` and `alpha` include its parents'.
    private struct Item {
        let node: SKShapeNode
        let transform: CGAffineTransform
        let z: CGFloat
        let alpha: CGFloat
        let order: Int
    }

    /// The transform from a node's space to the scene's, its depth (zPosition summed up the tree) and its alpha.
    private static func placement(of node: SKNode, in scene: SKScene) -> (CGAffineTransform, CGFloat, CGFloat)? {
        var t = CGAffineTransform.identity
        var z: CGFloat = 0
        var alpha: CGFloat = 1
        var n: SKNode? = node
        while let cur = n, cur !== scene {
            let local = CGAffineTransform(scaleX: cur.xScale, y: cur.yScale)
                .concatenating(CGAffineTransform(rotationAngle: cur.zRotation))
                .concatenating(CGAffineTransform(translationX: cur.position.x, y: cur.position.y))
            t = t.concatenating(local)
            z += cur.zPosition
            alpha *= cur.alpha
            n = cur.parent
        }
        return n === scene ? (t, z, alpha) : nil
    }

    /// Paints `shapes` (painter's order: depth, then the order given) into one sprite at depth `spriteZ`, hides them,
    /// and adds the sprite to the scene. `pixelsPerPoint` sets the texture's sharpness. Returns the sprite.
    @discardableResult
    static func flatten(_ shapes: [SKShapeNode], in scene: SKScene, spriteZ: CGFloat,
                        pixelsPerPoint: CGFloat) -> SKSpriteNode? {
        var items: [Item] = []
        var box = CGRect.null
        for (i, node) in shapes.enumerated() {
            guard let path = node.path, let (t, z, a) = placement(of: node, in: scene), a > 0 else { continue }
            items.append(Item(node: node, transform: t, z: z, alpha: a, order: i))
            let pad = max(node.lineWidth, 0) + 2
            box = box.union(path.boundingBoxOfPath.insetBy(dx: -pad, dy: -pad).applying(t))
        }
        guard !items.isEmpty, !box.isNull, box.width > 0, box.height > 0 else { return nil }
        box = box.integral
        var s = pixelsPerPoint
        let maxSide: CGFloat = 8192
        s = min(s, maxSide / box.width, maxSide / box.height)
        let size = CGSize(width: (box.width * s).rounded(.up), height: (box.height * s).rounded(.up))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: size.height)               // the scene's y points up
            cg.scaleBy(x: s, y: -s)
            cg.translateBy(x: -box.minX, y: -box.minY)
            for item in items.sorted(by: { $0.z != $1.z ? $0.z < $1.z : $0.order < $1.order }) {
                let node = item.node
                guard let path = node.path else { continue }
                cg.saveGState()
                cg.concatenate(item.transform)
                let fill = node.fillColor
                var fa: CGFloat = 0
                fill.getRed(nil, green: nil, blue: nil, alpha: &fa)
                if fa > 0 {
                    cg.addPath(path)
                    cg.setFillColor(fill.withAlphaComponent(fa * item.alpha).cgColor)
                    cg.fillPath(using: .winding)
                }
                let stroke = node.strokeColor
                var sa: CGFloat = 0
                stroke.getRed(nil, green: nil, blue: nil, alpha: &sa)
                if sa > 0, node.lineWidth > 0 {
                    cg.addPath(path)
                    cg.setStrokeColor(stroke.withAlphaComponent(sa * item.alpha).cgColor)
                    cg.setLineWidth(node.lineWidth)
                    cg.setLineCap(node.lineCap)
                    cg.setLineJoin(node.lineJoin)
                    cg.strokePath()
                }
                cg.restoreGState()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture, size: box.size)
        sprite.position = CGPoint(x: box.midX, y: box.midY)
        sprite.zPosition = spriteZ
        sprite.name = "chompFlattened"
        scene.addChild(sprite)
        for item in items { item.node.isHidden = true }
        return sprite
    }
}
