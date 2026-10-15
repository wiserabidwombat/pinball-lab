import SpriteKit
import CoreGraphics
import Foundation

/// A U-F-O lane: a sensor the ball rolls through, with a light above it (from Orbit Pinball).
/// One lane at a time can also be the skill-shot target (pulsing ring) once the rules arrive.
final class Rollover: SKNode {
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

    private static let onColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
    private static let offColor = SKColor(white: 0.25, alpha: 1)
    private let light = SKShapeNode(circleOfRadius: 6)
    private let skillRing = SKShapeNode(circleOfRadius: 12)

    init(laneCenterX x: CGFloat) {
        super.init()
        position = CGPoint(x: x, y: TableLayout.laneSensorY)
        let lightOffset = CGPoint(x: 0, y: TableLayout.laneLightY - TableLayout.laneSensorY)

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

        let body = SKPhysicsBody(rectangleOf: TableLayout.laneSensorSize)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.rollover
        body.collisionBitMask = PhysicsCategory.none   // sensor: the ball passes through
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
