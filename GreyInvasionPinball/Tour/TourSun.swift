// Pinball Lab Table 06 (Orbit: Grand Tour), M6 v12: the Sun comes alive. The upper floor painting has the Sun behind the
// S-T-A-R lanes (tools/tour_floor_upper.py: centre (284, 1365), r 205); this lays light over it: a warm glow that
// breathes slowly and two faint corona layers turning opposite ways (the shimmer). It sits between the upper painting
// (z −19.55) and the upper hardware bake (−19.45), so the cabinet and rails stay on top. Each lit S-T-A-R letter makes it
// brighter; completing S-T-A-R throws a flare.
import SpriteKit
import UIKit

@MainActor
final class TourSun: SKNode {
    static let center = CGPoint(x: 284, y: 1365)
    static let radius: CGFloat = 205

    /// level → brightness; breath → the slow pulse inside it
    private let levelNode = SKNode()
    private let breath = SKNode()
    private let glow: SKSpriteNode
    private let raysA: SKSpriteNode
    private let raysB: SKSpriteNode

    override init() {
        let r = Self.radius
        glow = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: r * 2.3, height: r * 2.3))
        raysA = SKSpriteNode(texture: Self.raysTexture(seed: 0x5A11), size: CGSize(width: r * 2.7, height: r * 2.7))
        raysB = SKSpriteNode(texture: Self.raysTexture(seed: 0x50AA), size: CGSize(width: r * 2.5, height: r * 2.5))
        super.init()
        position = Self.center
        zPosition = -19.52
        addChild(levelNode)
        levelNode.addChild(breath)
        for (node, a) in [(glow, CGFloat(0.55)), (raysA, 0.30), (raysB, 0.24)] {
            node.blendMode = .add
            node.alpha = a
            breath.addChild(node)
        }
        raysA.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 140)))
        raysB.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 190)))
        let up = SKAction.fadeAlpha(to: 1.0, duration: 3.2), down = SKAction.fadeAlpha(to: 0.72, duration: 3.2)
        up.timingMode = .easeInEaseOut; down.timingMode = .easeInEaseOut
        breath.alpha = 0.72
        breath.run(.repeatForever(.sequence([up, down])))
        setLevel(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// How many S-T-A-R letters are lit (0…4): brighter with each.
    func setLevel(_ lit: Int) {
        levelNode.removeAction(forKey: "level")
        levelNode.run(.fadeAlpha(to: 0.55 + 0.16 * CGFloat(min(max(lit, 0), 4)), duration: 0.4), withKey: "level")
    }

    /// S-T-A-R complete: a quick bright flare that settles back.
    func flare() {
        glow.removeAction(forKey: "flare")
        glow.run(.sequence([.fadeAlpha(to: 1.0, duration: 0.12), .fadeAlpha(to: 0.55, duration: 1.4)]), withKey: "flare")
        for rays in [raysA, raysB] {
            rays.removeAction(forKey: "flare")
            rays.run(.sequence([.scale(to: 1.12, duration: 0.15), .scale(to: 1.0, duration: 1.4)]), withKey: "flare")
        }
    }

    /// White-gold at the middle, orange, then nothing (the glow; drawn small, it's soft anyway).
    private static let glowTexture: SKTexture = {
        let side: CGFloat = 256
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            // v12b: tighter (r × 2.3) and no wide orange tail — it read as a brown haze over the pops
            let colors = [UIColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 0.75).cgColor,
                          UIColor(red: 1.0, green: 0.84, blue: 0.50, alpha: 0.45).cgColor,
                          UIColor(red: 1.0, green: 0.70, blue: 0.32, alpha: 0.10).cgColor,
                          UIColor(red: 1.0, green: 0.60, blue: 0.25, alpha: 0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                               locations: [0, 0.62, 0.86, 1])!
            let c = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: side / 2,
                                             options: [])
        }
        return SKTexture(image: image)
    }()

    /// Faint corona streamers: thin tapered rays from the limb outward, uneven in length and strength.
    private static func raysTexture(seed: UInt64) -> SKTexture {
        let side: CGFloat = 384
        var s = seed
        func rnd() -> CGFloat {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((s >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let cg = ctx.cgContext
            let c = CGPoint(x: side / 2, y: side / 2)
            let limb = side / 2 / 1.3                    // the Sun's edge inside this square
            for _ in 0..<70 {
                let a = rnd() * .pi * 2
                let len = limb * (0.10 + 0.28 * pow(rnd(), 1.6))
                let w = 0.006 + 0.022 * rnd()              // half-width at the base, radians
                let alpha = 0.10 + 0.30 * rnd()
                let p0 = CGPoint(x: c.x + cos(a - w) * limb * 0.92, y: c.y + sin(a - w) * limb * 0.92)
                let p1 = CGPoint(x: c.x + cos(a) * (limb + len), y: c.y + sin(a) * (limb + len))
                let p2 = CGPoint(x: c.x + cos(a + w) * limb * 0.92, y: c.y + sin(a + w) * limb * 0.92)
                cg.saveGState()
                let path = CGMutablePath()
                path.move(to: p0); path.addLine(to: p1); path.addLine(to: p2); path.closeSubpath()
                cg.addPath(path); cg.clip()
                let colors = [UIColor(red: 1.0, green: 0.86, blue: 0.55, alpha: alpha).cgColor,
                              UIColor(red: 1.0, green: 0.60, blue: 0.25, alpha: 0).cgColor] as CFArray
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                cg.drawRadialGradient(g, startCenter: c, startRadius: limb * 0.9, endCenter: c,
                                      endRadius: limb + len, options: [])
                cg.restoreGState()
            }
        }
        return SKTexture(image: image)
    }
}
