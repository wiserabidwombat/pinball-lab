// Pinball Lab Table 06 (Orbit: Grand Tour), M5 v5: the planet window (the plan's second 3D trick, "a deep playfield").
// A round window in the floor of the insert field looks down into space: far stars and the planet being visited sit
// "below the glass" in two parallax layers (negative heights in TourParallax), so they slide the other way from the
// raised parts and lag the floor — it reads as depth. An SKCropNode (proven under the SKRenderer host: Monsoon's live
// storm) keeps them inside the round hole; a chrome rim, an inner shadow and a glare on the glass sit over it.
// Grey-box test: Jupiter, drawn here in Core Graphics; the planet changes with every mode in the rules milestone.
// M6 v11: the Grand Tour's eight painted planets (tools/tour_paint_window.py: tour_window_<name>, the window's full
// circle at 6 px/pt), shown one at a time; `show(_:)` flies to the next stop (the old planet falls away, the new one
// comes up out of the deep), with its name on a little plate at the bottom of the glass.
import SpriteKit
import UIKit

@MainActor
final class TourPlanetWindow: SKNode {
    /// The far stars (deepest) and the planet; TourParallax slides each by its own depth.
    let deepLayer = SKNode()
    let planetLayer = SKNode()
    let center: CGPoint
    let radius: CGFloat
    /// M6 v11: the tour's stops. M8 v1: Earth (home), then the ring's order: Mercury out to Neptune, then the Sun.
    static let stops = ["earth", "mercury", "venus", "mars", "moon", "jupiter", "saturn", "uranus", "neptune", "sun",
                              "pluto"]   // M8 v9: the hidden stop
    private var textures: [SKTexture] = []
    private var planet: SKSpriteNode?
    private let namePlate = SKLabelNode()
    private(set) var stop = 0
    /// M9 r2: the cropped inside of the window, for the liftoff's ship.
    private var inside: SKNode?

    init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
        super.init()
        zPosition = -19                       // over the floor (-20), under the lamps (-18, -17) and everything else

        let crop = SKCropNode()
        let mask = SKShapeNode(circleOfRadius: radius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.position = center
        crop.maskNode = mask
        addChild(crop)
        inside = crop

        let back = SKSpriteNode(color: SKColor(red: 0.004, green: 0.006, blue: 0.018, alpha: 1),
                                size: CGSize(width: radius * 2 + 4, height: radius * 2 + 4))
        back.position = center
        back.zPosition = 0
        crop.addChild(back)

        deepLayer.zPosition = 0.01
        crop.addChild(deepLayer)
        let starSide = (radius + 70) * 2      // room for the deep layer's slide
        let stars = SKSpriteNode(texture: SKTexture(image: Self.starImage(side: starSide)))
        stars.size = CGSize(width: starSide, height: starSide)
        stars.position = center
        deepLayer.addChild(stars)

        planetLayer.zPosition = 0.02
        crop.addChild(planetLayer)
        textures = Self.stops.compactMap { UIImage(named: "tour_window_" + $0).map { SKTexture(image: $0) } }
        if textures.count == Self.stops.count {
            SKTexture.preload(textures) { }
            let p = SKSpriteNode(texture: textures[0], size: CGSize(width: radius * 2, height: radius * 2))
            p.position = center
            planetLayer.addChild(p)
            planet = p
        } else {
            textures = []
            let pr = (radius * 0.52).rounded()
            let p = SKSpriteNode(texture: SKTexture(image: Self.jupiterImage(radius: pr)))
            p.size = CGSize(width: pr * 2, height: pr * 2)
            p.position = center
            planetLayer.addChild(p)
        }

        // The glass: a soft inner shadow round the edge, the chrome rim, a glare up-left.
        let shade = SKShapeNode(circleOfRadius: radius - 3)
        shade.position = center
        shade.fillColor = .clear
        shade.strokeColor = SKColor(white: 0, alpha: 0.55)
        shade.lineWidth = 7
        shade.zPosition = 0.1
        addChild(shade)
        let rimDark = SKShapeNode(circleOfRadius: radius + 1)
        rimDark.position = center
        rimDark.fillColor = .clear
        rimDark.strokeColor = SKColor(red: 0.23, green: 0.25, blue: 0.32, alpha: 1)
        rimDark.lineWidth = 5
        rimDark.zPosition = 0.2
        addChild(rimDark)
        let rim = SKShapeNode(circleOfRadius: radius + 1)
        rim.position = center
        rim.fillColor = .clear
        rim.strokeColor = SKColor(red: 0.79, green: 0.81, blue: 0.85, alpha: 1)
        rim.lineWidth = 2.6
        rim.zPosition = 0.21
        addChild(rim)
        let glarePath = CGMutablePath()
        glarePath.addArc(center: .zero, radius: radius - 9, startAngle: .pi * 0.62, endAngle: .pi * 0.98, clockwise: false)
        let glare = SKShapeNode(path: glarePath)
        glare.position = center
        glare.strokeColor = SKColor(white: 1, alpha: 0.22)
        glare.lineWidth = 5
        glare.lineCap = .round
        glare.zPosition = 0.3
        addChild(glare)

        if !textures.isEmpty {
            namePlate.fontName = "AvenirNext-DemiBold"
            namePlate.fontSize = 6.5
            namePlate.fontColor = SKColor(red: 0.80, green: 0.90, blue: 1.0, alpha: 0.85)
            namePlate.verticalAlignmentMode = .center
            namePlate.position = CGPoint(x: center.x, y: center.y - radius + 8)
            namePlate.zPosition = 0.35
            namePlate.text = Self.plateName(0)
            addChild(namePlate)
        }
    }

    private static func plateName(_ i: Int) -> String {
        stops[i].uppercased().map(String.init).joined(separator: "\u{2009}")          // thin-spaced capitals
    }

    /// M8 v1: flies to the named stop.
    func show(planet: String, animated: Bool = true) {
        if let i = Self.stops.firstIndex(of: planet) { show(i, animated: animated) }
    }

    /// Flies to stop `i` (wrapping): the planet in view shrinks away into the deep as the next one rises to the glass.
    func show(_ i: Int, animated: Bool = true) {
        guard !textures.isEmpty else { return }
        stop = ((i % textures.count) + textures.count) % textures.count
        namePlate.text = Self.plateName(stop)
        guard animated, let old = planet else {
            planet?.texture = textures[stop]
            return
        }
        old.removeAllActions()
        let leave = SKAction.group([.scale(to: 0.25, duration: 0.35), .fadeOut(withDuration: 0.35)])
        leave.timingMode = .easeIn
        old.run(.sequence([leave, .removeFromParent()]))
        let next = SKSpriteNode(texture: textures[stop], size: CGSize(width: radius * 2, height: radius * 2))
        next.position = center
        next.setScale(1.8)
        next.alpha = 0
        planetLayer.addChild(next)
        let arrive = SKAction.group([.scale(to: 1, duration: 0.55), .fadeIn(withDuration: 0.3)])
        arrive.timingMode = .easeOut
        next.run(.sequence([.wait(forDuration: 0.15), arrive]))
        planet = next
        namePlate.removeAllActions()
        namePlate.alpha = 0
        namePlate.run(.sequence([.wait(forDuration: 0.4), .fadeIn(withDuration: 0.3)]))
    }

    /// M9 r2: liftoff — a ship lifts off the planet in view and climbs away out of the glass, shrinking into the
    /// distance, a thin glowing trail left behind it (in the deep, so the window's parallax carries it).
    func launch(after delay: TimeInterval = 0.7) {
        guard let layer = inside else { return }
        let ship = SKSpriteNode(texture: Self.glow, size: CGSize(width: 8, height: 8))
        ship.blendMode = .add
        ship.color = SKColor(red: 1.0, green: 0.88, blue: 0.62, alpha: 1)
        ship.colorBlendFactor = 1
        let start = CGPoint(x: center.x - radius * 0.10, y: center.y - radius * 0.02)
        ship.position = start
        ship.zPosition = 0.05
        ship.alpha = 0
        layer.addChild(ship)
        let trail = SKEmitterNode()
        trail.particleTexture = Self.glow
        trail.particleBirthRate = 140
        trail.particleLifetime = 0.7
        trail.particleLifetimeRange = 0.2
        trail.particleSpeed = 0
        trail.particleSize = CGSize(width: 5, height: 5)
        trail.particleScaleSpeed = -0.6
        trail.particleBlendMode = .add
        trail.particleColorBlendFactor = 1
        trail.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [SKColor(red: 1.0, green: 0.75, blue: 0.40, alpha: 1),
                             SKColor(red: 0.55, green: 0.70, blue: 1.0, alpha: 1)], times: [0, 1])
        trail.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.85, 0] as [NSNumber], times: [0, 1])
        trail.particleBirthRate = 0
        trail.targetNode = layer
        trail.particleZPosition = 0.04
        ship.addChild(trail)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: CGPoint(x: center.x + radius * 0.95, y: center.y + radius * 1.35),
                          control: CGPoint(x: center.x - radius * 0.12, y: center.y + radius * 0.75))
        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.9)
        fly.timingMode = .easeIn
        ship.run(.sequence([
            .wait(forDuration: delay),
            .run { trail.particleBirthRate = 140 },
            .fadeIn(withDuration: 0.15),
            .group([fly, .scale(to: 0.45, duration: 1.9)]),
            .run { trail.particleBirthRate = 0 },
            .wait(forDuration: 0.9),
            .removeFromParent()]))
    }

    /// A soft white dot (the ship and its trail).
    private static let glow: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0.35).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.3, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                             endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
        }
        return SKTexture(image: image)
    }()

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A small deterministic random sequence (the same sky every launch).
    private struct Seq {
        var s: UInt64
        mutating func next() -> CGFloat {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((s >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
    }

    /// Far stars on near-black with a faint violet-teal haze: tiny points, a few brighter.
    private static func starImage(side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            for (cx, cy, r, c) in [(0.35, 0.40, 0.45, [0.20, 0.10, 0.32]), (0.68, 0.62, 0.40, [0.05, 0.20, 0.28])] {
                let colors = [UIColor(red: c[0], green: c[1], blue: c[2], alpha: 0.55).cgColor,
                              UIColor(red: c[0], green: c[1], blue: c[2], alpha: 0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                    let p = CGPoint(x: side * cx, y: side * cy)
                    cg.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: side * r,
                                          options: [])
                }
            }
            var rnd = Seq(s: 0x5EED_0006)
            let count = Int(side * side / 90)
            for _ in 0..<count {
                let x = rnd.next() * side, y = rnd.next() * side
                let b = pow(rnd.next(), 2.6)
                let r = 0.22 + 0.7 * b
                let tint = rnd.next()
                let col = tint < 0.15 ? UIColor(red: 0.80, green: 0.88, blue: 1.0, alpha: 0.35 + 0.65 * b)
                    : (tint < 0.25 ? UIColor(red: 1.0, green: 0.88, blue: 0.75, alpha: 0.35 + 0.65 * b)
                       : UIColor(white: 1, alpha: 0.3 + 0.7 * b))
                cg.setFillColor(col.cgColor)
                cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
        }
    }

    /// Jupiter: cream and tan cloud bands, the Great Red Spot, lit from the upper left with a dark limb.
    private static func jupiterImage(radius r: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let side = r * 2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            let cg = ctx.cgContext
            cg.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            cg.clip()
            // bands, top to bottom (fractions of the diameter)
            let bands: [(CGFloat, UIColor)] = [
                (0.10, UIColor(red: 0.62, green: 0.56, blue: 0.50, alpha: 1)),
                (0.08, UIColor(red: 0.86, green: 0.78, blue: 0.64, alpha: 1)),
                (0.09, UIColor(red: 0.66, green: 0.46, blue: 0.32, alpha: 1)),
                (0.11, UIColor(red: 0.94, green: 0.88, blue: 0.76, alpha: 1)),
                (0.12, UIColor(red: 0.78, green: 0.58, blue: 0.40, alpha: 1)),
                (0.10, UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1)),
                (0.12, UIColor(red: 0.72, green: 0.50, blue: 0.34, alpha: 1)),
                (0.09, UIColor(red: 0.90, green: 0.83, blue: 0.70, alpha: 1)),
                (0.08, UIColor(red: 0.68, green: 0.54, blue: 0.42, alpha: 1)),
                (0.11, UIColor(red: 0.58, green: 0.52, blue: 0.47, alpha: 1)),
            ]
            var y: CGFloat = 0
            for (f, c) in bands {
                cg.setFillColor(c.cgColor)
                cg.fill(CGRect(x: 0, y: y, width: side, height: f * side + 0.5))
                y += f * side
            }
            // soft edges between bands: thin translucent wavy strokes
            var rnd = Seq(s: 0x10_0B17E5)
            for _ in 0..<26 {
                let yy = rnd.next() * side
                cg.setStrokeColor(UIColor(white: rnd.next() < 0.5 ? 1 : 0.35, alpha: 0.10).cgColor)
                cg.setLineWidth(0.6 + rnd.next())
                cg.move(to: CGPoint(x: 0, y: yy))
                var x: CGFloat = 0
                while x < side {
                    x += side / 8
                    cg.addLine(to: CGPoint(x: x, y: yy + (rnd.next() - 0.5) * side * 0.03))
                }
                cg.strokePath()
            }
            // the Great Red Spot, in the southern belt
            cg.setFillColor(UIColor(red: 0.80, green: 0.40, blue: 0.27, alpha: 0.95).cgColor)
            cg.fillEllipse(in: CGRect(x: side * 0.56, y: side * 0.61, width: side * 0.22, height: side * 0.12))
            cg.setStrokeColor(UIColor(red: 0.96, green: 0.86, blue: 0.74, alpha: 0.7).cgColor)
            cg.setLineWidth(0.8)
            cg.strokeEllipse(in: CGRect(x: side * 0.55, y: side * 0.60, width: side * 0.24, height: side * 0.14))
            // lit from the upper left: dark toward the lower right limb
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.15).cgColor,
                          UIColor(white: 0, alpha: 0.82).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.55, 1]) {
                cg.drawRadialGradient(g, startCenter: CGPoint(x: side * 0.36, y: side * 0.34), startRadius: 0,
                                      endCenter: CGPoint(x: side * 0.5, y: side * 0.5), endRadius: r * 1.02,
                                      options: [.drawsAfterEndLocation])
            }
        }
    }
}
