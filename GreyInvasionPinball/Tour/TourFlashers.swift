// Pinball Lab Table 06 (Orbit: Grand Tour), M7 v4: general illumination (GI) and flashers. Real tables light the
// playfield with GI bulbs under the plastics and punctuate big moments with flashers: the GI drops out, the flashers
// strobe, the lit inserts carry the room for a beat. Here: a dark veil over the floor art and hardware (under the lamps,
// toys and balls) that fades in to "drop" the GI, and flashers — big soft additive bursts of coloured light where a
// flasher bulb would hide under a plastic or ramp.
import SpriteKit
import UIKit

@MainActor
final class TourFlashers: SKNode {
    /// Where each flasher's light falls, and its colour.
    static let spots: [String: (at: CGPoint, color: SKColor, size: CGFloat)] = [
        "rocket": (CGPoint(x: 284, y: 905), SKColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 1), 300),
        "moon": (CGPoint(x: 112, y: 930), SKColor(red: 0.70, green: 0.82, blue: 1.0, alpha: 1), 260),
        "saturn": (CGPoint(x: 486, y: 925), SKColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 1), 260),
        "left": (CGPoint(x: 120, y: 230), SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1), 240),
        "right": (CGPoint(x: 448, y: 230), SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1), 240),
    ]

    private let veil: SKSpriteNode
    private var lights: [String: SKSpriteNode] = [:]

    override init() {
        // the table's whole art rect (LOWER_RECT ∪ UPPER_RECT)
        veil = SKSpriteNode(color: SKColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1), size: CGSize(width: 700, height: 1440))
        super.init()
        veil.position = CGPoint(x: 290, y: 632)
        veil.zPosition = -17.5                    // over the floor, bake and shadows; under the lamps (−17.2) and toys
        veil.alpha = 0
        veil.isHidden = true
        addChild(veil)
        for (name, spot) in Self.spots {
            let l = SKSpriteNode(texture: Self.flashTexture, size: CGSize(width: spot.size, height: spot.size))
            l.position = spot.at
            l.color = spot.color
            l.colorBlendFactor = 1
            l.blendMode = .add
            l.alpha = 0
            l.isHidden = true
            l.zPosition = 26                      // over the toys and ramps: the light is in the air
            addChild(l)
            lights[name] = l
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Fires a flasher `times` times (each a quick bright pop that decays).
    func flash(_ name: String, times: Int = 1, gap: TimeInterval = 0.16, peak: CGFloat = 0.85) {
        guard let l = lights[name] else { return }
        l.removeAllActions()
        let pop = SKAction.sequence([.fadeAlpha(to: peak, duration: 0.03), .fadeAlpha(to: 0, duration: 0.14),
                                     .wait(forDuration: max(0, gap - 0.17))])
        l.isHidden = false
        l.run(.sequence([.repeat(pop, count: times), .run { l.isHidden = true }]))
    }

    /// Every flasher at once, staggered a touch so it ripples.
    func flashAll(times: Int = 3) {
        for (i, name) in ["left", "right", "rocket", "moon", "saturn"].enumerated() {
            run(.sequence([.wait(forDuration: Double(i) * 0.04), .run { [weak self] in self?.flash(name, times: times) }]))
        }
    }

    /// GI out: the table drops dark for `duration` (the inserts and flashers carry it), then comes back up.
    func giOut(for duration: TimeInterval, depth: CGFloat = 0.62) {
        veil.removeAllActions()
        veil.isHidden = false
        veil.run(.sequence([.fadeAlpha(to: depth, duration: 0.06), .wait(forDuration: duration),
                            .fadeAlpha(to: 0, duration: 0.45), .run { [weak self] in self?.veil.isHidden = true }]))
    }

    private static let flashTexture: SKTexture = {
        let side: CGFloat = 128
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let colors = [UIColor(white: 1, alpha: 0.95).cgColor, UIColor(white: 1, alpha: 0.45).cgColor,
                          UIColor(white: 1, alpha: 0.12).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.18, 0.5, 1])!
            let c = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: side / 2,
                                             options: [])
        }
        return SKTexture(image: image)
    }()
}
