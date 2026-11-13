// Pinball Lab Table 06 (Orbit: Grand Tour), milestone 2: the grey-box targets. TourDropTarget is Table 05's drop
// target (LmpDropTarget) and TourStandup Table 04's standup (MonStandup), both turned to face a flipper and labelled,
// with the art left for the art milestone. M6 v6: rendered sprites (makeArt) over the same physics plates.
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

/// M6 v6: a rendered target (tools/tour_render_targets.py), already in its facing and the table's oblique, so it is
/// NOT turned with the plate. 6 px/pt, centred on the target; lit by the table's lights when it has a normal map.
private func makeArt(_ name: String) -> SKSpriteNode? {
    guard let image = UIImage(named: name) else { return nil }
    let sprite = SKSpriteNode(texture: SKTexture(image: image))
    sprite.size = CGSize(width: image.size.width * image.scale / 6, height: image.size.height * image.scale / 6)
    if let n = UIImage(named: name + "_n") {
        sprite.normalTexture = SKTexture(image: n)
        sprite.lightingBitMask = TourLighting.spriteMask
    }
    return sprite
}

/// M6 v10 (Aaron: make the targets "look lit up when you need to hit them so they pop more"): a soft additive glow
/// spilling onto the floor round a target's face, turned with the plate. Pulses while the target is wanted.
private func makeHalo(width: CGFloat, normal: CGFloat, color: SKColor) -> SKSpriteNode {
    let halo = SKSpriteNode(texture: haloTexture, size: CGSize(width: width + 26, height: 30))
    halo.color = color
    halo.colorBlendFactor = 1
    halo.blendMode = .add
    halo.zRotation = normal - .pi / 2
    halo.position = CGPoint(x: cos(normal) * 3, y: sin(normal) * 3)      // a little in front of the face
    halo.zPosition = -0.5
    halo.alpha = 0
    return halo
}

/// A soft white rounded glow, drawn once.
private let haloTexture: SKTexture = {
    let size = CGSize(width: 96, height: 48)
    let image = UIGraphicsImageRenderer(size: size).image { ctx in
        let cg = ctx.cgContext
        for i in 0..<14 {                                   // stacked rounded rects, fading outward
            let inset = CGFloat(i) * 1.6
            let r = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            cg.setFillColor(UIColor(white: 1, alpha: 0.075).cgColor)
            cg.addPath(UIBezierPath(roundedRect: r, cornerRadius: r.height / 2).cgPath)
            cg.fillPath()
        }
    }
    return SKTexture(image: image)
}()

/// The wanted target's pulse: the glow breathes and the label brightens with it.
private func wantedPulse() -> SKAction {
    let up = SKAction.fadeAlpha(to: 1.0, duration: 0.32)
    let down = SKAction.fadeAlpha(to: 0.35, duration: 0.32)
    up.timingMode = .easeInEaseOut; down.timingMode = .easeInEaseOut
    return .repeatForever(.sequence([up, down]))
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
    /// M6 v6: the rendered target (nil: the grey-box plate). Down, it hides and the plate shows as the empty slot.
    private let art: SKSpriteNode?
    /// M6 v10: the wanted glow (nil: none — the blast door and its wings).
    private let halo: SKSpriteNode?

    init(at center: CGPoint, normal: CGFloat, label text: String, size: CGSize = TourTableLayout.dropSize,
         color: SKColor = SKColor(red: 1.0, green: 0.70, blue: 0.28, alpha: 1), art artName: String? = nil,
         glow: SKColor? = nil) {
        plate = makePlate(size: size, normal: normal, color: color)
        label = makeLabel(text, normal: normal)
        art = artName.flatMap(makeArt)
        halo = glow.map { makeHalo(width: size.width, normal: normal, color: $0) }
        super.init()
        position = center
        zPosition = 1
        if let halo { addChild(halo) }
        addChild(plate)
        if let art {
            plate.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
            plate.strokeColor = SKColor(white: 0.75, alpha: 0.8)
            addChild(art)
        }
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
        if let art {
            art.isHidden = !up
            plate.alpha = up ? 0 : 1             // physics doesn't care about alpha
        } else {
            plate.alpha = up ? 1 : 0.18
        }
        label.alpha = up ? 0.9 : 0.35
        if let halo {                            // M6 v10: an up target is wanted: it glows
            halo.removeAllActions()
            label.removeAllActions()
            if up {
                halo.alpha = 1
                halo.run(wantedPulse())
                label.fontColor = SKColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 1)
                label.run(wantedPulse())
            } else {
                halo.alpha = 0
                label.fontColor = SKColor(white: 1, alpha: 0.9)
            }
        }
    }
}

/// A standup: never goes down. A hit lights it; the scene clears the bank once every one is lit.
final class TourStandup: SKNode {
    var isLit = false {
        didSet { applyLamp() }
    }
    /// M6 v6: the rendered standup, its off and lit looks (nil: the grey-box fill).
    private let art: SKSpriteNode?
    private let offTexture: SKTexture?
    private let litTexture: SKTexture?
    /// M6 v10: a letter still to collect is WANTED: its face blinks lit/off, a cyan glow pulses on the floor and its
    /// letter brightens with it. Collected (isLit): v10b — dark (the off face dimmed, no glow, a faint letter), so only the
    /// letters still to hit look hittable.
    private let halo: SKSpriteNode
    private let label: SKLabelNode
    /// `plate` carries the physics body and never scales; `fill` is the look that pulses on a hit.
    private let plate: SKShapeNode
    private let fill: SKShapeNode
    private var lastHit: TimeInterval = -1
    private static let offColor = SKColor(red: 0.20, green: 0.42, blue: 0.62, alpha: 1)
    private static let litColor = SKColor(red: 0.55, green: 0.88, blue: 1.0, alpha: 1)
    /// One hit per 0.15 s, so a rattling ball doesn't count twice.
    private static let cooldown: TimeInterval = 0.15

    init(at center: CGPoint, normal: CGFloat, label text: String, art artName: String? = nil) {
        let size = TourTableLayout.standupSize
        plate = makePlate(size: size, normal: normal, color: .clear)
        plate.strokeColor = .clear
        fill = SKShapeNode(rectOf: size, cornerRadius: 2)
        fill.fillColor = Self.offColor
        fill.strokeColor = SKColor(white: 1, alpha: 0.5)
        fill.lineWidth = 1
        plate.addChild(fill)
        art = artName.flatMap(makeArt)
        offTexture = art?.texture
        litTexture = artName.flatMap { UIImage(named: $0 + "_lit") }.map { SKTexture(image: $0) }
        if art != nil { fill.isHidden = true }
        halo = makeHalo(width: size.width, normal: normal, color: SKColor(red: 0.30, green: 0.75, blue: 1.0, alpha: 1))
        label = makeLabel(text, normal: normal)
        super.init()
        position = center
        zPosition = 1
        addChild(halo)
        addChild(plate)
        if let art { addChild(art) }
        addChild(label)
        applyLamp()

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

    private func applyLamp() {
        fill.fillColor = isLit ? Self.litColor : Self.offColor
        halo.removeAllActions(); label.removeAllActions()
        art?.removeAction(forKey: "blink")
        if isLit {                                    // M6 v10b (Aaron): collected goes DARK, like a dropped target
            if let art, let offTexture { art.texture = offTexture }
            art?.alpha = 0.55
            halo.alpha = 0
            label.alpha = 0.35
            label.fontColor = SKColor(white: 1, alpha: 0.9)
        } else {
            art?.alpha = 1
            halo.alpha = 1
            halo.run(wantedPulse())
            label.fontColor = SKColor(red: 0.62, green: 0.92, blue: 1.0, alpha: 1)
            label.run(wantedPulse())
            if let art, let litTexture, let offTexture {
                art.texture = litTexture
                art.run(.repeatForever(.sequence([.setTexture(litTexture), .wait(forDuration: 0.32),
                                                  .setTexture(offTexture), .wait(forDuration: 0.32)])),
                        withKey: "blink")
            }
        }
    }

    /// A ball hit it. Returns false inside the cooldown.
    func hit(at time: TimeInterval) -> Bool {
        guard time - lastHit > Self.cooldown else { return false }
        lastHit = time
        let look: SKNode = art ?? fill
        look.removeAction(forKey: "pop")              // not "blink" (M6 v10)
        look.run(.sequence([.scale(to: art == nil ? 0.85 : 0.92, duration: 0.04), .scale(to: 1, duration: 0.1)]),
                 withKey: "pop")
        return true
    }
}
