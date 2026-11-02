// Pinball Lab Table 04 (Monsoon), 2026-11-02: the Dust Storm's dust devil. While the disc rages, a column of dust rises
// out of it: dense and dark on the disc, widening and paling upward into haze, with soft edges throughout (Aaron's
// reference: a photo of a real dust devil). It's built from large, very soft blobs that overlap so much they blend into
// one smooth column: a core stack (still, but swaying), a dark skirt whirling on the disc, and long thin wisps orbiting
// the column (anticlockwise, like the disc's push) — darker behind the core, lighter in front — which is what makes it
// read as spinning. The top sways and the neck twists. It grows out of the disc when the storm starts and sinks back
// when it ends. Translucent enough to follow the ball.
// v1: pale sand, invisible on the sketch. v2: small dots with solid cores, a hard cone and streak lines ("splotchy
// balls"). v3 (this): soft blobs only, mocked up on Aaron's screenshot first.
// Art only: no physics (MonDustDevil.stir does the pushing). Driven by MonDustDevil.animate(dt:) from the scene.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class MonDustFunnel: SKNode {
    /// v3b (Aaron: "make it feel a bit bigger"): everything below is scaled by this.
    private static let scale: CGFloat = 1.4
    /// Screen height of the column above the disc (drawn standing up, like the table's raised parts, a bit taller).
    private static let height: CGFloat = 170 * scale
    /// A ring seen at the table's lean: its depth is this fraction of its width.
    private static let squash: CGFloat = 0.34
    private static let coreCount = 26
    private static let wispLevels = 14
    private static let wispsPerLevel = 3
    private static let skirtCount = 8
    /// Spin, radians a second (anticlockwise, as the disc pushes); the top turns a little slower than the base.
    private static let spin: CGFloat = 9
    private static let skirtSpin: CGFloat = 11

    private static let dark: (CGFloat, CGFloat, CGFloat) = (0.30, 0.21, 0.13)
    private static let mid: (CGFloat, CGFloat, CGFloat) = (0.55, 0.42, 0.28)
    private static let light: (CGFloat, CGFloat, CGFloat) = (0.80, 0.72, 0.60)

    /// The column's half-width at height fraction f (0 = the disc, 1 = the top).
    private static func radius(_ f: CGFloat) -> CGFloat { (9 + 50 * pow(f, 1.5)) * scale }

    /// Dust colour at height fraction f, times a brightness.
    private static func color(_ f: CGFloat, _ k: CGFloat = 1) -> SKColor {
        let f = min(1, max(0, f))
        let (a, b, t) = f < 0.5 ? (dark, mid, 2 * f) : (mid, light, 2 * f - 1)
        func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { min(1, (x + (y - x) * t) * k) }
        return SKColor(red: mix(a.0, b.0), green: mix(a.1, b.1), blue: mix(a.2, b.2), alpha: 1)
    }

    private struct Wisp {
        let sprite: SKSpriteNode
        let f: CGFloat
        let phase: CGFloat
        let back: SKColor
        let front: SKColor
    }

    private let shadow: SKSpriteNode
    private var core: [(sprite: SKSpriteNode, f: CGFloat)] = []
    private var wisps: [Wisp] = []
    private var skirt: [SKSpriteNode] = []
    private var time: CGFloat = 0
    /// 0 = sunk into the disc, 1 = fully up; eases toward `target`.
    private var grow: CGFloat = 0
    private var target: CGFloat = 0

    override init() {
        let soft = Self.softBlob()
        shadow = SKSpriteNode(texture: soft)
        super.init()

        // Each blob's sprite is 4 × its radius: the texture's falloff matches exp(−2.2 d²) out to 2 radii.
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = 0.40
        shadow.size = CGSize(width: 4 * 42 * Self.scale, height: 4 * 14 * Self.scale)
        shadow.position = CGPoint(x: 0, y: -2 * Self.scale)
        shadow.zPosition = -3
        addChild(shadow)

        for k in 0..<Self.wispLevels {
            let f = CGFloat(k) / CGFloat(Self.wispLevels - 1)
            for i in 0..<Self.wispsPerLevel {
                let s = SKSpriteNode(texture: soft)
                s.colorBlendFactor = 1
                addChild(s)
                wisps.append(Wisp(sprite: s, f: f,
                                  phase: CGFloat(i) * 2 * .pi / CGFloat(Self.wispsPerLevel) + CGFloat(k) * 0.8,
                                  back: Self.color(f + 0.15, 0.85), front: Self.color(f + 0.25, 1.08)))
            }
        }
        for k in 0..<Self.coreCount {
            let f = CGFloat(k) / CGFloat(Self.coreCount - 1)
            let s = SKSpriteNode(texture: soft)
            s.color = Self.color(f)
            s.colorBlendFactor = 1
            s.alpha = 0.50 * (1 - 0.5 * f)
            s.zPosition = 0
            addChild(s)
            core.append((s, f))
        }
        for _ in 0..<Self.skirtCount {
            let s = SKSpriteNode(texture: soft)
            s.colorBlendFactor = 1
            s.alpha = 0.55
            s.zPosition = 0.5
            addChild(s)
            skirt.append(s)
        }
        alpha = 0
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Up (the storm) or down (calm). The change eases in over ~0.6 s up, ~0.8 s down.
    func setRaging(_ raging: Bool) {
        target = raging ? 1 : 0
        if raging { isHidden = false }
    }

    func animate(dt: CGFloat) {
        guard !isHidden else { return }
        let rate: CGFloat = target > grow ? 1 / 0.6 : 1 / 0.8
        grow = target > grow ? min(target, grow + rate * dt) : max(target, grow - rate * dt)
        if grow <= 0, target == 0 { isHidden = true; alpha = 0; return }
        time += dt
        let g = grow * grow * (3 - 2 * grow)          // smoothstep
        alpha = g
        shadow.setScale(0.6 + 0.4 * g)

        // The column sways at the top and twists in the neck; the base stays on the disc.
        let sway = 10 * sin(time * 1.7) + 4 * sin(time * 3.1 + 1)
        func centre(_ f: CGFloat) -> CGFloat { sway * f * f + 6 * sin(f * .pi * 1.2 + time * 0.9) }
        let widen = 0.35 + 0.65 * g

        for (s, f) in core {
            let r = Self.radius(f) * widen
            s.position = CGPoint(x: centre(f), y: Self.height * f * g)
            s.size = CGSize(width: 4 * 0.95 * r, height: 4 * (0.55 * r + 4 * Self.scale))
        }
        for w in wisps {
            let r = Self.radius(w.f) * widen
            let a = w.phase + Self.spin * (1 - 0.35 * w.f) * time
            let near = -sin(a)                          // 1 at the front of the column, −1 at the back
            let s = w.sprite
            s.position = CGPoint(x: centre(w.f) + 0.55 * r * cos(a), y: Self.height * w.f * g + r * Self.squash * sin(a))
            s.size = CGSize(width: 4 * 0.75 * r, height: 4 * 0.22 * r)
            if near > 0 {
                s.color = w.front
                s.alpha = 0.36 * (1 - 0.45 * w.f)
                s.zPosition = 1
            } else {
                s.color = w.back
                s.alpha = 0.38 * (1 - 0.45 * w.f)
                s.zPosition = -2
            }
        }
        for (i, s) in skirt.enumerated() {
            let a = CGFloat(i) * 2 * .pi / CGFloat(Self.skirtCount) + Self.skirtSpin * time
            let near = -sin(a)
            let r = 24 * Self.scale * widen
            s.position = CGPoint(x: r * cos(a), y: 4 * Self.scale + r * Self.squash * sin(a))
            s.size = CGSize(width: 4 * 20 * Self.scale * widen, height: 4 * 9 * Self.scale * widen)
            s.color = Self.color(0, near > 0 ? 1.1 : 0.9)
        }
    }

    /// A very soft round blob: white with a Gaussian falloff (no solid core), so overlapping blobs blend smoothly.
    private static func softBlob() -> SKTexture {
        let n = 64
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n {
            for x in 0..<n {
                let u = (CGFloat(x) + 0.5) / CGFloat(n) * 2 - 1
                let v = (CGFloat(y) + 0.5) / CGFloat(n) * 2 - 1
                let a = exp(-8.8 * (u * u + v * v))     // exp(−2.2 d²) with d in radii, the sprite being 2 radii each side
                let i = (y * n + x) * 4
                let byte = UInt8(max(0, min(255, a * 255)))
                pixels[i] = byte; pixels[i + 1] = byte; pixels[i + 2] = byte; pixels[i + 3] = byte   // premultiplied
            }
        }
        return SKTexture(data: Data(pixels), size: CGSize(width: n, height: n))
    }
}
