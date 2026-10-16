// Pinball Lab Table 04 (Monsoon): copied from Table 03 (Cthulhu Rising) with the "Mon" prefix; behaviour unchanged.
import SpriteKit
import CoreGraphics
import Foundation

/// A U-F-O lane: a sensor the ball rolls through, with a light above it (from Orbit Pinball).
/// One lane at a time can also be the skill-shot target (pulsing ring) once the rules arrive.
final class MonRollover: SKNode {
    var isLit = false {
        didSet {
            if painted {
                guard isLit != oldValue else { return }
                flame.removeAllActions()
                if isLit {
                    // a lit candle: the flame flares up, then flickers
                    flame.alpha = 1
                    flame.setScale(1.5)
                    flame.run(.scale(to: 1, duration: 0.25))
                    flame.run(.repeatForever(.sequence([
                        .fadeAlpha(to: 0.78, duration: 0.09), .fadeAlpha(to: 1.0, duration: 0.13),
                        .fadeAlpha(to: 0.86, duration: 0.07), .fadeAlpha(to: 1.0, duration: 0.17),
                    ])), withKey: "flicker")
                } else {
                    flame.run(.fadeOut(withDuration: 0.2))
                }
            } else {
                light.fillColor = isLit ? Self.onColor : Self.offColor
                glow.alpha = isLit ? 0.45 : 0
            }
        }
    }

    var isSkillTarget = false {
        didSet {
            guard isSkillTarget != oldValue else { return }
            skillRing.removeAllActions()
            if isSkillTarget {
                skillRing.alpha = 1
                skillRing.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.2, duration: 0.3),
                    .fadeAlpha(to: 1.0, duration: 0.3),
                ])))
            } else {
                skillRing.alpha = 0
            }
        }
    }

    // M9 v5: Monsoon's lane lights are raindrops — rain-blue when lit, a dim glass drop when not, with a soft halo.
    private static let onColor = SKColor(red: 0.62, green: 0.84, blue: 1.0, alpha: 1)
    private static let offColor = SKColor(red: 0.30, green: 0.34, blue: 0.42, alpha: 0.85)
    private static let dropPath: CGPath = {
        let p = CGMutablePath()                      // a raindrop, point up, ~9 pt tall
        p.move(to: CGPoint(x: 0, y: 6.5))
        p.addQuadCurve(to: CGPoint(x: 3.8, y: -1.2), control: CGPoint(x: 3.4, y: 2.8))
        p.addArc(center: CGPoint(x: 0, y: -1.2), radius: 3.8, startAngle: 0, endAngle: .pi, clockwise: true)
        p.addQuadCurve(to: CGPoint(x: 0, y: 6.5), control: CGPoint(x: -3.4, y: 2.8))
        p.closeSubpath()
        return p
    }()
    private let light = SKShapeNode(path: MonRollover.dropPath)
    private let glow = SKShapeNode(circleOfRadius: 10)
    private let skillRing = SKShapeNode(circleOfRadius: 12)
    /// Art round 5a: with the painted table, the lane light is the candle printed under the lane; lit, its flame
    /// glows (an additive flame + halo over the painting) instead of a grey/green dot above the lane.
    private let painted: Bool
    private let flame = SKNode()

    init(laneCenterX x: CGFloat, painted: Bool = false) {
        self.painted = painted
        super.init()
        position = CGPoint(x: x, y: MonTableLayout.laneSensorY)
        let lightOffset = painted ? CGPoint(x: 0, y: MonTableLayout.candleFlameY - MonTableLayout.laneSensorY)
                                  : CGPoint(x: 0, y: MonTableLayout.laneLightY - MonTableLayout.laneSensorY)

        if painted {
            flame.position = lightOffset
            flame.zPosition = -18                        // just over the painted table (z -19)
            flame.alpha = 0
            let halo = SKShapeNode(circleOfRadius: 11)
            halo.fillColor = SKColor(red: 1.0, green: 0.62, blue: 0.20, alpha: 0.30)
            halo.strokeColor = .clear
            halo.blendMode = .add
            flame.addChild(halo)
            let tongue = CGMutablePath()                 // a teardrop flame, point up
            tongue.move(to: CGPoint(x: 0, y: 8))
            tongue.addQuadCurve(to: CGPoint(x: 3.6, y: -1.5), control: CGPoint(x: 3.2, y: 3.5))
            tongue.addArc(center: CGPoint(x: 0, y: -1.5), radius: 3.6, startAngle: 0, endAngle: .pi, clockwise: true)
            tongue.addQuadCurve(to: CGPoint(x: 0, y: 8), control: CGPoint(x: -3.2, y: 3.5))
            tongue.closeSubpath()
            let outer = SKShapeNode(path: tongue)
            outer.fillColor = SKColor(red: 1.0, green: 0.66, blue: 0.22, alpha: 1)
            outer.strokeColor = .clear
            outer.blendMode = .add
            flame.addChild(outer)
            let core = SKShapeNode(path: tongue)
            core.fillColor = SKColor(red: 1.0, green: 0.95, blue: 0.75, alpha: 1)
            core.strokeColor = .clear
            core.blendMode = .add
            core.setScale(0.5)
            core.position = CGPoint(x: 0, y: -1.5)
            flame.addChild(core)
            addChild(flame)
        } else {
            light.position = lightOffset
            light.fillColor = Self.offColor
            light.strokeColor = SKColor(white: 1, alpha: 0.35)
            light.lineWidth = 0.6
            glow.position = lightOffset
            glow.fillColor = Self.onColor
            glow.strokeColor = .clear
            glow.blendMode = .add
            glow.alpha = 0
            addChild(glow)
            addChild(light)
        }

        skillRing.position = lightOffset
        skillRing.fillColor = .clear
        skillRing.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        skillRing.lineWidth = 2
        skillRing.alpha = 0
        addChild(skillRing)

        let body = SKPhysicsBody(rectangleOf: MonTableLayout.laneSensorSize)
        body.isDynamic = false
        body.categoryBitMask = MonPhysicsCategory.rollover
        body.collisionBitMask = MonPhysicsCategory.none   // sensor: the ball passes through
        body.contactTestBitMask = MonPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
