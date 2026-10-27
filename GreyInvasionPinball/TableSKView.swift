// iPad 60 Hz pacing (2026-10-26). On the iPad Air M3 (60 Hz, iOS 27.2) SpriteKit's own frame loop (SKView, and so
// SwiftUI's SpriteView) presented only 40 frames a second while the game updated 60 times: a known iOS 26/27 SpriteKit
// regression (Apple forums 800952, 815783, 821590), not load (Metal HUD: GPU 2.7 ms). Tested on the iPad: a bare scene
// with 400 shapes ran at exactly 40 through SKView and at a flat 60 through SKRenderer on our own timer. So on devices
// the tables are drawn by SKRenderer in a Metal view (SceneHostView); the Simulator keeps SKView, because the labs'
// screenshots go through SKView.texture(from:).
//
// What a scene needs from the host (RendererHostedScene): `hostView` stands in for `view` in the touch handlers,
// didMove(to:) is called once with a throwaway SKView so the table builds as before, and a `.resizeFill` scene is
// sized to the view in points (didChangeSize → refreshCamera, as SKView does).
import SwiftUI
import SpriteKit
import MetalKit
import QuartzCore

/// A table scene that can be drawn by the SKRenderer host: `hostView` is the touch surface when `view` is nil.
@MainActor
protocol RendererHostedScene: SKScene {
    var hostView: UIView? { get set }
}

struct TableSKView: UIViewRepresentable {
    let scene: SKScene
    var preferredFramesPerSecond: Int

    /// Devices draw with SKRenderer (the iPad fix); the Simulator keeps SKView for the labs. "skUseSKView" = true
    /// forces SKView on a device (the pause card's debug "Loop" button; takes effect the next time a table opens).
    static var usesRenderer: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return !UserDefaults.standard.bool(forKey: "skUseSKView")
        #endif
    }

    func makeUIView(context: Context) -> UIView {
        if Self.usesRenderer {
            return SceneHostView(scene: scene, preferredFramesPerSecond: preferredFramesPerSecond)
        }
        let view = SKView(frame: .zero)
        view.preferredFramesPerSecond = preferredFramesPerSecond
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        if let host = view as? SceneHostView {
            if host.preferredFramesPerSecond != preferredFramesPerSecond {
                host.preferredFramesPerSecond = preferredFramesPerSecond
            }
        } else if let skView = view as? SKView {
            if skView.preferredFramesPerSecond != preferredFramesPerSecond {
                skView.preferredFramesPerSecond = preferredFramesPerSecond
            }
            if skView.scene !== scene { skView.presentScene(scene) }
        }
    }
}

/// Draws an SKScene with SKRenderer into a Metal view on MTKView's display link, bypassing SKView's frame loop.
/// Touches are forwarded to the scene, which reads them against `hostView`.
final class SceneHostView: MTKView, MTKViewDelegate {
    private let renderer: SKRenderer
    private let queue: MTLCommandQueue
    private let skScene: SKScene

    init(scene: SKScene, preferredFramesPerSecond fps: Int) {
        let dev = MTLCreateSystemDefaultDevice()!
        renderer = SKRenderer(device: dev)
        queue = dev.makeCommandQueue()!
        skScene = scene
        super.init(frame: .zero, device: dev)
        colorPixelFormat = .bgra8Unorm
        depthStencilPixelFormat = .depth32Float_stencil8   // SKRenderer draws with a stencil (masks, crop nodes)
        framebufferOnly = true
        preferredFramesPerSecond = fps
        isPaused = false
        enableSetNeedsDisplay = false
        isMultipleTouchEnabled = true
        let bg = scene.backgroundColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        bg.getRed(&r, green: &g, blue: &b, alpha: &a)
        clearColor = MTLClearColor(red: Double(r), green: Double(g), blue: Double(b), alpha: 1)
        delegate = self

        (scene as? RendererHostedScene)?.hostView = self
        renderer.scene = scene
        scene.didMove(to: SKView(frame: .zero))      // builds the table once (the scenes guard on isBuilt)
    }

    required init(coder: NSCoder) { fatalError() }

    private func fitScene() {
        guard skScene.scaleMode == .resizeFill, bounds.width > 0, skScene.size != bounds.size else { return }
        skScene.size = bounds.size          // points, like SKView's .resizeFill (fires didChangeSize)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        fitScene()
    }

    func draw(in view: MTKView) {
        guard bounds.width > 0, let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
              let cb = queue.makeCommandBuffer() else { return }
        fitScene()
        renderer.update(atTime: CACurrentMediaTime())        // update, actions, physics, didFinishUpdate
        renderer.render(withViewport: CGRect(origin: .zero, size: drawableSize),
                        commandBuffer: cb, renderPassDescriptor: pass)
        cb.present(drawable)
        cb.commit()
    }

    // MARK: Touches → the scene

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        skScene.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        skScene.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        skScene.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        skScene.touchesCancelled(touches, with: event)
    }
}

#if DEBUG
/// The pacing test (pause card): a bare scene, one ball plus `load` drifting shapes, drawn by either loop.
/// iPad Air M3: 400 shapes ran at 40 fps through SKView and 60 through SKRenderer.
final class BlankPacingScene: SKScene {
    private let ball = SKShapeNode(circleOfRadius: 18)
    private var velocity = CGVector(dx: 520, dy: 380)
    private var last: TimeInterval?
    private var extras: [(SKShapeNode, CGVector)] = []

    init(load: Int, title: String) {
        super.init(size: CGSize(width: 400, height: 800))
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(white: 0.12, alpha: 1)
        ball.fillColor = .white
        ball.strokeColor = .clear
        addChild(ball)
        for i in 0..<load {
            let n = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 2)
            n.fillColor = SKColor(hue: CGFloat(i % 12) / 12, saturation: 0.6, brightness: 0.8, alpha: 1)
            n.strokeColor = .clear
            n.position = CGPoint(x: CGFloat(i % 20) * 18 - 180, y: CGFloat(i / 20) * 18 - 300)
            addChild(n)
            extras.append((n, CGVector(dx: CGFloat((i * 37) % 200) - 100, dy: CGFloat((i * 53) % 200) - 100)))
        }
        let hint = SKLabelNode(text: "Pacing test · \(title) · \(load) shapes · tap to close")
        hint.fontName = "Menlo"
        hint.fontSize = 16
        hint.fontColor = SKColor(white: 0.7, alpha: 1)
        hint.name = "hint"
        addChild(hint)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(currentTime - (last ?? currentTime), 1.0 / 30))
        last = currentTime
        var p = ball.position
        p.x += velocity.dx * dt
        p.y += velocity.dy * dt
        let hx = size.width / 2 - 18, hy = size.height / 2 - 18
        if abs(p.x) > hx { velocity.dx = -velocity.dx; p.x = max(-hx, min(hx, p.x)) }
        if abs(p.y) > hy { velocity.dy = -velocity.dy; p.y = max(-hy, min(hy, p.y)) }
        ball.position = p
        for (n, v) in extras {
            var q = n.position
            q.x += v.dx * dt; q.y += v.dy * dt
            if q.x < -hx { q.x += 2 * hx } else if q.x > hx { q.x -= 2 * hx }
            if q.y < -hy { q.y += 2 * hy } else if q.y > hy { q.y -= 2 * hy }
            n.position = q
        }
        childNode(withName: "hint")?.position = CGPoint(x: 0, y: -size.height / 2 + 60)
    }
}

/// The pacing test's view: the loop is chosen explicitly, whatever TableSKView would pick.
struct PacingTestView: UIViewRepresentable {
    let scene: SKScene
    let useRenderer: Bool

    func makeUIView(context: Context) -> UIView {
        if useRenderer { return SceneHostView(scene: scene, preferredFramesPerSecond: DisplayRate.max) }
        let view = SKView(frame: .zero)
        view.preferredFramesPerSecond = DisplayRate.max
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}
}
#endif
