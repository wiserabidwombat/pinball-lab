// Pinball Lab Table 06 (Orbit: Grand Tour), milestone 1: an O-R-B-T rollover in an inlane or outlane. A sensor the
// ball rolls through, and a round lamp insert with its letter just below it (grey box; the art pass bakes the insert).
import SpriteKit
import CoreGraphics
import Foundation

final class TourRollover: SKNode {
    let letter: String

    var isLit = false {
        didSet {
            guard isLit != oldValue else { return }
            insert.fillColor = isLit ? Self.onColor : Self.offColor
            glow.alpha = isLit ? 0.5 : 0
            label.fontColor = isLit ? Self.onText : Self.offText
        }
    }

    private static let onColor = SKColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1)
    private static let offColor = SKColor(red: 0.32, green: 0.26, blue: 0.14, alpha: 0.9)
    private static let onText = SKColor(red: 0.20, green: 0.10, blue: 0.0, alpha: 1)
    private static let offText = SKColor(red: 0.75, green: 0.65, blue: 0.45, alpha: 0.8)

    private let insert = SKShapeNode(circleOfRadius: 8)
    private let glow = SKShapeNode(circleOfRadius: 14)
    private let label = SKLabelNode(fontNamed: "Menlo-Bold")

    /// `y` and `lampDy` (the lamp insert's offset from the wire) default to the O-R-B-T lanes' (M3 v2: the S-T-A-R top
    /// lanes pass their own).
    init(letter: String, x: CGFloat, y: CGFloat = TourTableLayout.laneRolloverY,
         lampDy: CGFloat = TourTableLayout.laneLampY - TourTableLayout.laneRolloverY) {
        self.letter = letter
        super.init()
        position = CGPoint(x: x, y: y)
        let lamp = CGPoint(x: 0, y: lampDy)

        // The rollover wire: a thin steel bar across the lane.
        let wire = SKShapeNode(rectOf: CGSize(width: TourTableLayout.laneSensorSize.width, height: 3), cornerRadius: 1.5)
        wire.fillColor = SKColor(white: 0.75, alpha: 1)
        wire.strokeColor = .clear
        wire.zPosition = -18
        addChild(wire)

        glow.position = lamp
        glow.fillColor = Self.onColor
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.alpha = 0
        glow.zPosition = -18
        addChild(glow)
        insert.position = lamp
        insert.fillColor = Self.offColor
        insert.strokeColor = SKColor(white: 1, alpha: 0.3)
        insert.lineWidth = 1
        insert.zPosition = -17.9
        addChild(insert)
        label.text = letter
        label.fontSize = 10
        label.fontColor = Self.offText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = lamp
        label.zPosition = -17.8
        addChild(label)

        let body = SKPhysicsBody(rectangleOf: TourTableLayout.laneSensorSize)
        body.isDynamic = false
        body.categoryBitMask = TourPhysicsCategory.rollover
        body.collisionBitMask = TourPhysicsCategory.none   // sensor: the ball passes through
        body.contactTestBitMask = TourPhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
