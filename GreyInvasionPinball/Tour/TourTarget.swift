// Pinball Lab Table 06 (Orbit: Grand Tour), milestone 2: the grey-box targets. TourDropTarget is Table 05's drop
// target (LmpDropTarget) and TourStandup Table 04's standup (MonStandup), both turned to face a flipper and labelled,
// with the art left for the art milestone.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// A thin plate turned so its face points along `normal` (radians), with its letter or number above it.
private func makePlate(size: CGSize, normal: CGFloat, color: SKColor) -> SKShapeNode {
    let plate = SKShapeNode(rectOf: size, cornerRadius: 2)
    plate.fillColor = color
    plate.strokeColor = SKColor(white: 1, alpha: 0.5)
    plate.lineWidth = 1
    plate.zRotation = normal - .pi / 2          // the rectangle's +y side becomes the face
    return plate
}

private func makeLabel(_ text: String, normal: CGFloat) -> SKLabelNode {
    let label = SKLabelNode(text: text)
    label.fontName = "Menlo-Bold"
    label.fontSize = 11
    label.fontColor = SKColor(white: 1, alpha: 0.9)
    label.verticalAlignmentMode = .center
    label.horizontalAlignmentMode = .center
    label.position = CGPoint(x: cos(normal) * 14, y: sin(normal) * 14)     // in front of the face, upright
    return label
}

/// A drop target: hit it once and it drops (the ball passes over); the scene raises the bank.
final class TourDropTarget: SKNode {
    private(set) var isDown = false
    /// Set the moment a hit is seen, so repeat contacts that frame don't count twice.
    private(set) var isHit = false
    private let plate: SKShapeNode
    private let label: SKLabelNode

    init(at center: CGPoint, normal: CGFloat, label text: String, size: CGSize = TourTableLayout.dropSize,
         color: SKColor = SKColor(red: 1.0, green: 0.70, blue: 0.28, alpha: 1)) {
        plate = makePlate(size: size, normal: normal, color: color)
        label = makeLabel(text, normal: normal)
        super.init()
        position = center
        zPosition = 1
        addChild(plate)
        addChild(label)

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.2
        body.collisionBitMask = TourPhysicsCategory.ball
        body.contactTestBitMask = TourPhysicsCategory.ball
        plate.physicsBody = body                 // on the turned plate, so the body turns with it
        setUp(true)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Marks the hit. Returns false if it was already hit or down.
    func registerHit() -> Bool {
        guard !isHit, !isDown else { return false }
        isHit = true
        return true
    }

    /// Drops the target. Call from update(), not from inside a contact callback.
    func drop() {
        isDown = true
        setUp(false)
    }

    func raise() {
        isDown = false
        isHit = false
        setUp(true)
    }

    /// For a bash target that stays up: ready to count the next hit (v10, the rocket pad's blast door).
    func clearHit() { isHit = false }

    private func setUp(_ up: Bool) {
        plate.physicsBody?.categoryBitMask = up ? TourPhysicsCategory.target : TourPhysicsCategory.none
        plate.alpha = up ? 1 : 0.18
        label.alpha = up ? 0.9 : 0.35
    }
}

/// A standup: never goes down. A hit lights it; the scene clears the bank once every one is lit.
final class TourStandup: SKNode {
    var isLit = false {
        didSet { fill.fillColor = isLit ? Self.litColor : Self.offColor }
    }
    /// `plate` carries the physics body and never scales; `fill` is the look that pulses on a hit.
    private let plate: SKShapeNode
    private let fill: SKShapeNode
    private var lastHit: TimeInterval = -1
    private static let offColor = SKColor(red: 0.20, green: 0.42, blue: 0.62, alpha: 1)
    private static let litColor = SKColor(red: 0.55, green: 0.88, blue: 1.0, alpha: 1)
    /// One hit per 0.15 s, so a rattling ball doesn't count twice.
    private static let cooldown: TimeInterval = 0.15

    init(at center: CGPoint, normal: CGFloat, label text: String) {
        let size = TourTableLayout.standupSize
        plate = makePlate(size: size, normal: normal, color: .clear)
        plate.strokeColor = .clear
        fill = SKShapeNode(rectOf: size, cornerRadius: 2)
        fill.fillColor = Self.offColor
        fill.strokeColor = SKColor(white: 1, alpha: 0.5)
        fill.lineWidth = 1
        plate.addChild(fill)
        super.init()
        position = center
        zPosition = 1
        addChild(plate)
        addChild(makeLabel(text, normal: normal))

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.3
        body.categoryBitMask = TourPhysicsCategory.target
        body.collisionBitMask = TourPhysicsCategory.ball
        body.contactTestBitMask = TourPhysicsCategory.ball
        plate.physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A ball hit it. Returns false inside the cooldown.
    func hit(at time: TimeInterval) -> Bool {
        guard time - lastHit > Self.cooldown else { return false }
        lastHit = time
        fill.removeAllActions()
        fill.run(.sequence([.scale(to: 0.85, duration: 0.04), .scale(to: 1, duration: 0.1)]))
        return true
    }
}
