// Pinball Lab Table 06 (Orbit: Grand Tour), M5 v4: parallax by height (the plan's first 3D trick).
// Raised parts are drawn in holders that slide against the floor as the follow camera moves, the way tall things shift
// when you move your head: a part `h` points up, `d` points from the camera's centre, draws h × d / depth further out.
// Pictures only — every physics body stays where it is. Grey-box test: the Moon, Saturn, the rocket, the bumper caps and
// a ball held in a crater; the ramps' shape outlines can't bend per point, so they wait for the baked art (a warp grid).
import SpriteKit
import CoreGraphics

@MainActor
final class TourParallax {
    private struct Item {
        let node: SKNode
        let anchor: CGPoint
        let height: CGFloat
    }
    private var items: [Item] = []
    /// 0 = off, 1 = the planned amount, 2 = doubled (DEBUG pause button cycles it to judge the look).
    var strength: CGFloat = 1

    /// `node` is a holder at (0, 0) whose children sit at their own positions; it moves as one piece of height `height`
    /// standing at `anchor` (world points, on the floor).
    func add(_ node: SKNode, anchor: CGPoint, height: CGFloat) {
        items.append(Item(node: node, anchor: anchor, height: height))
    }

    /// The offset of something `height` points up at world point `p`, seen from a camera centred on `camera`.
    func shift(at p: CGPoint, height: CGFloat, camera: CGPoint) -> CGPoint {
        let k = strength * height / TourTableLayout.parallaxDepth
        return CGPoint(x: (p.x - camera.x) * k, y: (p.y - camera.y) * k)
    }

    /// Once per frame, after the camera has moved.
    func update(camera: CGPoint) {
        for item in items {
            item.node.position = shift(at: item.anchor, height: item.height, camera: camera)
        }
    }
}
