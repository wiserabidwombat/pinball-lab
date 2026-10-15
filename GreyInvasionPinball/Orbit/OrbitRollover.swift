// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was Rollover.swift.
import SpriteKit

/// A top rollover lane: a sensor the ball rolls through, with a light above it.
/// One lane at a time can also be the skill-shot target (pulsing ring).
final class OrbitRollover: SKNode {
    var isLit = false {
        didSet { light.fillColor = isLit ? Self.onColor : Self.offColor }
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

    private static let onColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
    private static let offColor = SKColor(white: 0.25, alpha: 1)
    private let light = SKShapeNode(circleOfRadius: 5)
    private let skillRing = SKShapeNode(circleOfRadius: 10)

    init(laneCenterX x: CGFloat) {
        super.init()
        position = CGPoint(x: x, y: OrbitTableLayout.laneSensorY)
        let lightOffset = CGPoint(x: 0, y: OrbitTableLayout.laneLightY - OrbitTableLayout.laneSensorY)

        light.position = lightOffset
        light.fillColor = Self.offColor
        light.strokeColor = .clear
        addChild(light)

        skillRing.position = lightOffset
        skillRing.fillColor = .clear
        skillRing.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        skillRing.lineWidth = 2
        skillRing.alpha = 0
        addChild(skillRing)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 26, height: 10))
        body.isDynamic = false
        body.categoryBitMask = OrbitPhysicsCategory.rollover
        body.collisionBitMask = OrbitPhysicsCategory.none   // sensor: the ball passes through
        body.contactTestBitMask = OrbitPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
