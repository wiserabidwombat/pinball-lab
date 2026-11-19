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
        fx.zPosition = 0.03                   // M9 r3: effects on the glass, over the planet
        crop.addChild(fx)
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

    // MARK: - M9 r4: the outer leg's effects

    private var swirl: SKSpriteNode?
    private var deepTint: SKSpriteNode?
    private var planetSunk = false

    /// A spin or bumper counted toward the running stop's step (`made` steps done, `count` toward the next).
    func effectProgress(_ name: String, made: Int, count: Int) {
        switch name {
        case "jupiter" where made == 0:              // the storm spins up with the spinners
            let p = min(1, CGFloat(count) / CGFloat(TourModes.jupiterSpins))
            swirl?.alpha = 0.18 + 0.62 * p
            swirl?.speed = 0.4 + 2.6 * p
        case "neptune" where made == 0:              // diving: the planet sinks and the blue deepens
            let p = min(1, CGFloat(count) / CGFloat(TourModes.neptuneSpins))
            planet?.setScale(1 - 0.2 * p)
            planetSunk = true
            deepTint?.alpha = 0.45 * p
        case "neptune":                              // the bumpers: a pulse of cold light each
            ring(SKColor(red: 0.35, green: 0.6, blue: 1.0, alpha: 1), to: 0.6)
        default: break
        }
    }

    /// A step of the running stop was made.
    func effectStep(_ name: String, made: Int) {
        switch name {
        case "jupiter":                              // the storm breaks: lightning
            swirl?.alpha = 0.9
            swirl?.speed = 3
            lightning()
        case "saturn": glint(angle: -0.32, color: SKColor(red: 1.0, green: 0.93, blue: 0.75, alpha: 1))
        case "uranus": glint(angle: 1.35, color: SKColor(red: 0.6, green: 1.0, blue: 0.95, alpha: 1))
        case "neptune":
            ring(SKColor(red: 0.35, green: 0.6, blue: 1.0, alpha: 1))
        case "sun":                                    // M9 r5: a sun jackpot — a flare off the limb
            ring(SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1))
            glint(angle: CGFloat.random(in: 0..<(.pi)), color: SKColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1))
        default: break
        }
    }

    /// Jupiter Storm: a spiral storm over the planet, faint and slow until the spinners wind it up.
    private func jupiterStorm() {
        let s = SKSpriteNode(texture: Self.spiral, size: CGSize(width: radius * 1.5, height: radius * 1.5))
        s.position = CGPoint(x: center.x + radius * 0.08, y: center.y - radius * 0.06)
        s.blendMode = .add
        s.color = SKColor(red: 1.0, green: 0.78, blue: 0.55, alpha: 1)
        s.colorBlendFactor = 1
        s.alpha = 0
        s.zPosition = 0.5
        s.name = "fx"
        s.yScale = 0.8                              // seen a little edge-on, like the bands
        planetLayer.addChild(s)
        s.speed = 0.4
        s.run(.sequence([.wait(forDuration: 0.6), .fadeAlpha(to: 0.18, duration: 0.4)]))
        s.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 4)))
        swirl = s
    }

    private func lightning() {
        for k in 0..<3 {
            let bolt = SKSpriteNode(texture: Self.glow, size: CGSize(width: radius * 0.9, height: radius * 0.9))
            bolt.position = CGPoint(x: center.x + CGFloat(k - 1) * radius * 0.3, y: center.y + CGFloat(k % 2) * 6 - 3)
            bolt.blendMode = .add
            bolt.color = SKColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 1)
            bolt.colorBlendFactor = 1
            bolt.alpha = 0
            bolt.zPosition = 0.3
            fx.addChild(bolt)
            bolt.run(.sequence([.wait(forDuration: 0.12 * Double(k)), .fadeAlpha(to: 1, duration: 0.03),
                                .fadeAlpha(to: 0.2, duration: 0.06), .fadeAlpha(to: 0.9, duration: 0.03),
                                .fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
    }

    /// A streak of light sweeping across the planet along `angle` (Saturn's rings, Uranus's).
    private func glint(angle: CGFloat, color: SKColor) {
        let g = SKSpriteNode(texture: Self.glow, size: CGSize(width: radius * 0.7, height: 5))
        g.blendMode = .add
        g.color = color
        g.colorBlendFactor = 1
        g.zRotation = angle
        g.zPosition = 0.3
        let dx = cos(angle) * radius * 1.1, dy = sin(angle) * radius * 1.1
        g.position = CGPoint(x: center.x - dx, y: center.y - dy)
        g.alpha = 0
        fx.addChild(g)
        let sweep = SKAction.move(to: CGPoint(x: center.x + dx, y: center.y + dy), duration: 0.55)
        sweep.timingMode = .easeInEaseOut
        g.run(.sequence([.group([sweep, .sequence([.fadeAlpha(to: 1, duration: 0.12), .wait(forDuration: 0.25),
                                                   .fadeOut(withDuration: 0.18)])]), .removeFromParent()]))
    }

    /// M9 r5: Sun Slingshot — the corona blazes and breathes on the glass while the finale runs.
    private func sunCorona() {
        let glow = SKSpriteNode(texture: Self.glow, size: CGSize(width: radius * 3.4, height: radius * 3.4))
        glow.position = center
        glow.blendMode = .add
        glow.color = SKColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1)
        glow.colorBlendFactor = 1
        glow.alpha = 0
        glow.zPosition = 0.2
        fx.addChild(glow)
        let breathe = SKAction.sequence([.fadeAlpha(to: 0.7, duration: 0.5), .fadeAlpha(to: 0.4, duration: 0.5)])
        breathe.timingMode = .easeInEaseOut
        glow.run(.sequence([.wait(forDuration: 0.5), .repeatForever(breathe)]))
        let rays = SKSpriteNode(texture: Self.spiral, size: CGSize(width: radius * 2.2, height: radius * 2.2))
        rays.position = center
        rays.blendMode = .add
        rays.color = SKColor(red: 1.0, green: 0.78, blue: 0.4, alpha: 1)
        rays.colorBlendFactor = 1
        rays.alpha = 0
        rays.zPosition = 0.21
        fx.addChild(rays)
        rays.run(.sequence([.wait(forDuration: 0.5), .fadeAlpha(to: 0.35, duration: 0.6)]))
        rays.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 9)))
    }

    /// Uranus Roll: a cold cyan glow breathing on the glass.
    private func uranusCold() {
        let wash = SKSpriteNode(texture: Self.glow, size: CGSize(width: radius * 3, height: radius * 3))
        wash.position = center
        wash.blendMode = .add
        wash.color = SKColor(red: 0.4, green: 0.95, blue: 0.9, alpha: 1)
        wash.colorBlendFactor = 1
        wash.alpha = 0
        wash.zPosition = 0.2
        fx.addChild(wash)
        let breathe = SKAction.sequence([.fadeAlpha(to: 0.32, duration: 1.4), .fadeAlpha(to: 0.16, duration: 1.4)])
        breathe.timingMode = .easeInEaseOut
        wash.run(.sequence([.wait(forDuration: 0.6), .repeatForever(breathe)]))
    }

    /// Neptune Deep: the blue that deepens as the planet sinks (driven by `effectProgress`).
    private func neptuneDeep() {
        let tint = SKSpriteNode(color: SKColor(red: 0.02, green: 0.08, blue: 0.35, alpha: 1),
                                size: CGSize(width: radius * 2, height: radius * 2))
        tint.position = center
        tint.alpha = 0
        tint.zPosition = 0.6
        tint.name = "fx"
        planetLayer.addChild(tint)
        deepTint = tint
    }

    /// A loose three-armed spiral (Jupiter's storm), drawn once.
    private static let spiral: SKTexture = {
        let side: CGFloat = 128
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let g = ctx.cgContext
            let c = side / 2
            g.setLineCap(.round)
            for arm in 0..<3 {
                var prev: CGPoint?
                for i in 0...60 {
                    let t = CGFloat(i) / 60
                    let a = CGFloat(arm) * .pi * 2 / 3 + t * .pi * 2.2
                    let r = c * (0.08 + 0.86 * t)
                    let p = CGPoint(x: c + cos(a) * r, y: c + sin(a) * r)
                    if let q = prev {
                        g.setStrokeColor(UIColor(white: 1, alpha: 0.85 * (1 - t) + 0.1).cgColor)
                        g.setLineWidth(2 + 7 * (1 - t))
                        g.move(to: q); g.addLine(to: p); g.strokePath()
                    }
                    prev = p
                }
            }
        }
        return SKTexture(image: image)
    }()

    // MARK: - M9 r3: planet effects (the inner leg and Pluto; the outer leg is r4)

    /// What runs over the planet while its stop is on: Mercury's glare and shimmer, Venus's clouds, Mars's dust, Pluto's
    /// frost. Glass effects (glare, frost, flashes) sit on `fx`, over the planet; clouds and dust ride the planet layer.
    private let fx = SKNode()
    private var venusClouds: [SKSpriteNode] = []
    private var venusPerReveal = 3

    /// Starts the stop's own effect (call after `show(planet:)`; it waits for the planet to arrive).
    func startEffect(for name: String) {
        stopEffect(animated: false)
        switch name {
        case "mercury": mercuryHeat()
        case "venus": venusVeil()
        case "mars": marsDust()
        case "pluto": plutoFrost()
        case "jupiter": jupiterStorm()                 // M9 r4
        case "uranus": uranusCold()
        case "neptune": neptuneDeep()
        case "sun": sunCorona()                         // M9 r5
        default: break
        }
    }

    /// The stop ended (lost, or finished — `celebrate` calls this): its effect fades away.
    func stopEffect(animated: Bool = true) {
        if let p = planet, p.action(forKey: "shimmer") != nil {
            p.removeAction(forKey: "shimmer")
            p.run(.scale(to: 1, duration: 0.2))
        }
        venusClouds = []
        swirl = nil; deepTint = nil                       // M9 r4
        if planetSunk { planetSunk = false; planet?.run(.scale(to: 1, duration: 0.4)) }
        let nodes = fx.children + planetLayer.children.filter { $0.name == "fx" }
        for n in nodes {
            n.name = nil
            (n as? SKEmitterNode)?.particleBirthRate = 0
            n.removeAllActions()
            if animated {
                n.run(.sequence([.fadeOut(withDuration: 0.6), .wait(forDuration: 1.5), .removeFromParent()]))
            } else {
                n.removeFromParent()
            }
        }
    }

    /// A stop is visited: its effect clears and the glass flashes warm white with a ring running out to the rim.
    func celebrate() {
        stopEffect()
        let flash = SKSpriteNode(texture: Self.glow, size: CGSize(width: radius * 3.2, height: radius * 3.2))
        flash.position = center
        flash.blendMode = .add
        flash.color = SKColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1)
        flash.colorBlendFactor = 1
        flash.alpha = 0
        flash.zPosition = 0.3
        fx.addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.08), .fadeOut(withDuration: 0.6), .removeFromParent()]))
        ring(SKColor(red: 1.0, green: 0.85, blue: 0.55, alpha: 1))
    }

    /// A ring of light running out from the planet to the rim (a Moon lock, a visit).
    func ring(_ color: SKColor, to reach: CGFloat = 1.1) {
        let r0: CGFloat = 8
        let ring = SKShapeNode(circleOfRadius: r0)
        ring.position = center
        ring.strokeColor = color
        ring.lineWidth = 2.5
        ring.glowWidth = 3
        ring.fillColor = .clear
        ring.blendMode = .add
        ring.zPosition = 0.25
        fx.addChild(ring)
        let grow = SKAction.scale(to: radius * reach / r0, duration: 0.7)
        grow.timingMode = .easeOut
        ring.run(.sequence([.group([grow, .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.45)])]),
                            .removeFromParent()]))
    }

    /// Mercury Dash: the Sun's glare on the glass, pulsing, and the planet shimmering in the heat.
    private func mercuryHeat() {
        let glare = SKSpriteNode(texture: Self.glow, size: CGSize(width: radius * 2.4, height: radius * 2.4))
        glare.position = CGPoint(x: center.x - radius * 0.65, y: center.y + radius * 0.6)
        glare.blendMode = .add
        glare.color = SKColor(red: 1.0, green: 0.80, blue: 0.48, alpha: 1)
        glare.colorBlendFactor = 1
        glare.alpha = 0
        glare.zPosition = 0.2
        fx.addChild(glare)
        let pulse = SKAction.sequence([.fadeAlpha(to: 0.62, duration: 0.6), .fadeAlpha(to: 0.38, duration: 0.6)])
        pulse.timingMode = .easeInEaseOut
        glare.run(.sequence([.wait(forDuration: 0.6), .repeatForever(pulse)]))
        let wash = SKSpriteNode(color: SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1),
                                size: CGSize(width: radius * 2, height: radius * 2))
        wash.position = center
        wash.blendMode = .add
        wash.alpha = 0
        wash.zPosition = 0.19
        fx.addChild(wash)
        wash.run(.sequence([.wait(forDuration: 0.6), .fadeAlpha(to: 0.10, duration: 0.5)]))
        planet?.run(.sequence([.wait(forDuration: 0.75), .repeatForever(.customAction(withDuration: 2.0) { n, t in
            n.xScale = 1 + 0.014 * sin(t * .pi * 6)
            n.yScale = 1 + 0.014 * sin(t * .pi * 4.6 + 1)
        })]), withKey: "shimmer")
    }

    /// Venus Veil: thick yellow-white clouds cover the planet; each reveal (a R-O-C-K-E-T hit) blows a third away.
    private func venusVeil() {
        var seq = Seq(s: 77)
        let count = 9
        venusPerReveal = 3
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * .pi * 2 + seq.next() * 0.6
            let d = (i == 0 ? 0 : radius * (0.18 + 0.30 * seq.next()))
            let size = radius * (0.85 + 0.45 * seq.next())
            let puff = SKSpriteNode(texture: Self.cloud, size: CGSize(width: size * 1.3, height: size))
            puff.position = i == 0 ? center : CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d)
            puff.color = SKColor(red: 0.96, green: 0.90, blue: 0.72, alpha: 1)
            puff.colorBlendFactor = 1
            puff.alpha = 0
            puff.zPosition = 0.5
            puff.name = "fx"
            planetLayer.addChild(puff)
            let drift = SKAction.moveBy(x: 3 + 3 * seq.next(), y: 0, duration: 3 + 2 * seq.next())
            drift.timingMode = .easeInEaseOut
            puff.run(.sequence([.wait(forDuration: 0.6 + 0.05 * Double(i)), .fadeAlpha(to: 0.92, duration: 0.5),
                                .repeatForever(.sequence([drift, drift.reversed()]))]))
            venusClouds.append(puff)
        }
        venusClouds.shuffle()
    }

    /// Venus: a shot revealed — a third of the clouds blow away.
    func venusReveal() {
        for _ in 0..<min(venusPerReveal, venusClouds.count) {
            let puff = venusClouds.removeLast()
            puff.name = nil
            let away = SKAction.moveBy(x: (puff.position.x - center.x) * 1.6 + 6, y: (puff.position.y - center.y) * 1.6,
                                       duration: 0.7)
            away.timingMode = .easeIn
            puff.run(.sequence([.group([away, .fadeOut(withDuration: 0.7), .scale(to: 1.4, duration: 0.7)]),
                                .removeFromParent()]))
        }
    }

    /// Mars Recon: a dust storm blowing across the planet, gusting.
    private func marsDust() {
        let dust = SKEmitterNode()
        dust.particleTexture = Self.cloud
        dust.particleBirthRate = 0
        dust.particleLifetime = 2.6
        dust.particleLifetimeRange = 0.6
        dust.emissionAngle = 0.12
        dust.emissionAngleRange = 0.35
        dust.particleSpeed = 48
        dust.particleSpeedRange = 18
        dust.particlePositionRange = CGVector(dx: 6, dy: radius * 2)
        dust.particleSize = CGSize(width: 18, height: 12)
        dust.particleScaleRange = 0.5
        dust.particleScaleSpeed = 0.25
        dust.particleColor = SKColor(red: 0.86, green: 0.48, blue: 0.24, alpha: 1)
        dust.particleColorBlendFactor = 1
        dust.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.5, 0.35, 0] as [NSNumber],
                                                        times: [0, 0.2, 0.7, 1])
        dust.position = CGPoint(x: center.x - radius - 8, y: center.y)
        dust.zPosition = 0.5
        dust.particleZPosition = 0.5
        dust.name = "fx"
        planetLayer.addChild(dust)
        dust.advanceSimulationTime(0)
        dust.run(.sequence([.wait(forDuration: 0.6), .repeatForever(.sequence([
            .run { dust.particleBirthRate = 26 }, .wait(forDuration: 1.6),
            .run { dust.particleBirthRate = 60 }, .wait(forDuration: 1.1)]))]))
    }

    /// Pluto: frost creeps in from the rim of the glass over the stop's 30 s, glittering.
    private func plutoFrost() {
        let frost = SKSpriteNode(texture: Self.frost, size: CGSize(width: radius * 2, height: radius * 2))
        frost.position = center
        frost.color = SKColor(red: 0.82, green: 0.92, blue: 1.0, alpha: 1)
        frost.colorBlendFactor = 1
        frost.blendMode = .add
        frost.alpha = 0
        frost.setScale(1.45)
        frost.zPosition = 0.2
        fx.addChild(frost)
        let creep = SKAction.group([.scale(to: 1.0, duration: 30), .fadeAlpha(to: 0.8, duration: 8)])
        creep.timingMode = .easeOut
        frost.run(.sequence([.wait(forDuration: 0.6), creep]))
        let glitter = SKEmitterNode()
        glitter.particleTexture = Self.glow
        glitter.particleBirthRate = 7
        glitter.particleLifetime = 0.9
        glitter.particleLifetimeRange = 0.4
        glitter.particleSpeed = 0
        glitter.particlePositionRange = CGVector(dx: radius * 1.9, dy: radius * 1.9)
        glitter.particleSize = CGSize(width: 4, height: 4)
        glitter.particleBlendMode = .add
        glitter.particleColor = SKColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1)
        glitter.particleColorBlendFactor = 1
        glitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0] as [NSNumber], times: [0, 0.4, 1])
        glitter.position = center
        glitter.zPosition = 0.21
        glitter.particleZPosition = 0.21
        fx.addChild(glitter)
    }

    /// A soft flat-topped puff (clouds, dust).
    private static let cloud: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0.85).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
        return SKTexture(image: image)
    }()

    /// Frost on the glass: clear in the middle, white toward the rim, ragged.
    private static let frost: SKTexture = {
        let side = 128
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let c = CGFloat(side) / 2
            let colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0).cgColor,
                          UIColor(white: 1, alpha: 0.75).cgColor, UIColor(white: 1, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 0.85, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: c, y: c), startRadius: 0,
                                             endCenter: CGPoint(x: c, y: c), endRadius: c, options: [])
            var seq = Seq(s: 5)                              // frost fingers reaching in from the rim
            ctx.cgContext.setStrokeColor(UIColor(white: 1, alpha: 0.55).cgColor)
            for _ in 0..<40 {
                let a = seq.next() * .pi * 2
                let r0 = c * 0.98, r1 = c * (0.55 + 0.3 * seq.next())
                ctx.cgContext.setLineWidth(0.6 + 1.4 * seq.next())
                ctx.cgContext.move(to: CGPoint(x: c + cos(a) * r0, y: c + sin(a) * r0))
                let b = a + (seq.next() - 0.5) * 0.25
                ctx.cgContext.addLine(to: CGPoint(x: c + cos(b) * r1, y: c + sin(b) * r1))
                ctx.cgContext.strokePath()
            }
        }
        return SKTexture(image: image)
    }()

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
