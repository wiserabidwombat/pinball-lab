// Pinball Lab Table 03: copied from Grey Invasion (milestone 3) with the "Cth" prefix.
import SpriteKit
import CoreGraphics
import Foundation

/// A U-F-O lane: a sensor the ball rolls through, with a light above it (from Orbit Pinball).
/// One lane at a time can also be the skill-shot target (pulsing ring) once the rules arrive.
final class CthRollover: SKNode {
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

    private static let onColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
    private static let offColor = SKColor(white: 0.25, alpha: 1)
    private let light = SKShapeNode(circleOfRadius: 6)
    private let skillRing = SKShapeNode(circleOfRadius: 12)
    /// Art round 5a: with the painted table, the lane light is the candle printed under the lane; lit, its flame
    /// glows (an additive flame + halo over the painting) instead of a grey/green dot above the lane.
    private let painted: Bool
    private let flame = SKNode()

    init(laneCenterX x: CGFloat, painted: Bool = false) {
        self.painted = painted
        super.init()
        position = CGPoint(x: x, y: CthTableLayout.laneSensorY)
        let lightOffset = painted ? CGPoint(x: 0, y: CthTableLayout.candleFlameY - CthTableLayout.laneSensorY)
                                  : CGPoint(x: 0, y: CthTableLayout.laneLightY - CthTableLayout.laneSensorY)

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
            light.strokeColor = .clear
            addChild(light)
        }

        skillRing.position = lightOffset
        skillRing.fillColor = .clear
        skillRing.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        skillRing.lineWidth = 2
        skillRing.alpha = 0
        addChild(skillRing)

        let body = SKPhysicsBody(rectangleOf: CthTableLayout.laneSensorSize)
        body.isDynamic = false
        body.categoryBitMask = CthPhysicsCategory.rollover
        body.collisionBitMask = CthPhysicsCategory.none   // sensor: the ball passes through
        body.contactTestBitMask = CthPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
