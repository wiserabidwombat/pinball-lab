import SpriteKit

/// T9 M2 v7: SPRITE STACKING. A voxel model (tools/qf_stack.py) drawn as a stack of top-down slices, bottom first.
/// Each frame every slice is raised by its height times the table's lean, and tilted by the camera's parallax (the top
/// leans away from the middle of the screen), so a static prop reads as a solid object seen from above.
@MainActor
final class QfStack {
    /// Height drawn per pt of height (the lean towards the top of the screen).
    static let lean: CGFloat = 0.75
    /// Extra lean per pt of height at the edge of the view (half its height away from the camera).
    static let parallax: CGFloat = 0.35

    let node = SKNode()
    private(set) var slices: [SKSpriteNode] = []
    private let voxel: CGFloat

    /// `sheet`: one row of `count` slices, each `voxelsX` x `voxelsY` voxels; `voxel` pt per voxel.
    init(sheet name: String, count: Int, voxelsX: Int, voxelsY: Int, voxel: CGFloat = 2, at centre: CGPoint) {
        self.voxel = voxel
        let tex = SKTexture(imageNamed: name)
        tex.filteringMode = .nearest
        let size = CGSize(width: CGFloat(voxelsX) * voxel, height: CGFloat(voxelsY) * voxel)
        for k in 0..<count {
            let t = SKTexture(rect: CGRect(x: CGFloat(k) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1),
                              in: tex)
            t.filteringMode = .nearest
            let s = SKSpriteNode(texture: t, size: size)
            s.zPosition = CGFloat(k) * 0.001
            node.addChild(s)
            slices.append(s)
        }
        // a soft shadow on the floor, down and to the right of the base (moonlight from the top left)
        let shadow = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.15, height: size.height * 0.9))
        shadow.fillColor = SKColor(white: 0, alpha: 0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -4)
        shadow.zPosition = -0.01
        node.addChild(shadow)
        node.position = centre
        update(camera: centre, viewHalfHeight: 1)
    }

    /// Call once a frame after the camera moves. `camera` is the view's centre in world pt.
    func update(camera: CGPoint, viewHalfHeight: CGFloat) {
        var world = node.position
        if let parent = node.parent, let scene = node.scene { world = parent.convert(node.position, to: scene) }
        let rx = (world.x - camera.x) / max(viewHalfHeight, 1)
        let ry = (world.y - camera.y) / max(viewHalfHeight, 1)
        for (k, s) in slices.enumerated() {
            let z = CGFloat(k) * voxel
            s.position = CGPoint(x: Self.parallax * z * rx, y: Self.lean * z + Self.parallax * z * ry)
        }
    }
}
