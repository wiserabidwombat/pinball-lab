// Pinball Lab Table 06 (Orbit: Grand Tour), M3 v2: a pop bumper (grey box), Table 03/04's proven bumper trimmed of
// their art and shields: on every hit it kicks the ball straight away from its centre at TourTableLayout.bumperKickSpeed.
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

final class TourBumper: SKNode {
    private let disc: SKSpriteNode
    /// M5 v6: the bumper's own light (TourLighting): dark at rest, a warm flash on every hit.
    let light = SKLightNode()
    private let flashDisc: SKShapeNode
    private var lastHit: TimeInterval = -1
    /// M5 v4: the drawn cap in its own holder, so parallax can slide it (the physics body stays on this node).
    let art = SKNode()

    init(at center: CGPoint) {
        let r = TourTableLayout.bumperRadius
        // M6 v7: the whole bumper rendered in Blender (tools/tour_render_toys.py: base, chrome skirt, body, red dome cap)
        // in the table's oblique, centred on the floor centre, 6 px/pt, with a normal map (was M5 v6's flat cap).
        let image = UIImage(named: "tour_bumper")
        disc = SKSpriteNode(imageNamed: "tour_bumper")
        disc.size = image.map { CGSize(width: $0.size.width * $0.scale / 6, height: $0.size.height * $0.scale / 6) }
            ?? CGSize(width: 50, height: 50)
        disc.normalTexture = SKTexture(imageNamed: "tour_bumper_n")
        disc.lightingBitMask = TourLighting.spriteMask
        flashDisc = SKShapeNode(circleOfRadius: r - 1)
        flashDisc.position = CGPoint(x: 0, y: 7.5)          // over the cap, which draws ~20 pt up × K above the floor
        super.init()
        position = center
        zPosition = 3
        addChild(art)
        art.addChild(disc)
        flashDisc.fillColor = .white
        flashDisc.strokeColor = .clear
        flashDisc.blendMode = .add
        flashDisc.alpha = 0
        art.addChild(flashDisc)
        light.categoryBitMask = TourLighting.category
        light.falloff = TourLighting.falloff
        light.ambientColor = TourLighting.ambientShare
        light.lightColor = .black
        art.addChild(light)

        let body = SKPhysicsBody(circleOfRadius: r)
        body.isDynamic = false
        body.restitution = 0
        body.friction = 0
        body.categoryBitMask = TourPhysicsCategory.bumper
        body.collisionBitMask = TourPhysicsCategory.ball
        body.contactTestBitMask = TourPhysicsCategory.ball
        physicsBody = body
    }

    /// M5 v6 (DEBUG test modes): steady = the light held on; off = no lighting at all.
    func applyLightingMode() {
        light.removeAction(forKey: "flash")
        light.isEnabled = TourLighting.mode != 2
        light.lightColor = TourLighting.mode == 1 ? TourLighting.flash(0.8) : .black
        disc.lightingBitMask = TourLighting.spriteMask
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Kicks the ball away from the centre (velocities only: safe in a contact callback). False inside the 50 ms cooldown.
    func hit(ball: SKPhysicsBody, ballPosition: CGPoint, at time: TimeInterval) -> Bool {
        guard time - lastHit > 0.05 else { return false }
        lastHit = time
        let dx = ballPosition.x - position.x, dy = ballPosition.y - position.y
        let len = max(hypot(dx, dy), 0.001)
        let kick = TourTableLayout.bumperKickSpeed
        ball.velocity = CGVector(dx: dx / len * kick, dy: dy / len * kick)
        flashDisc.removeAllActions()
        flashDisc.alpha = 0.6
        flashDisc.run(.fadeOut(withDuration: 0.18))
        if TourLighting.mode == 0 {                       // M5 v6: the light flashes and fades
            light.removeAction(forKey: "flash")
            light.lightColor = TourLighting.flash(1)
            let d = CGFloat(TourLighting.flashDuration)
            light.run(.customAction(withDuration: TourLighting.flashDuration) { node, t in
                (node as? SKLightNode)?.lightColor = TourLighting.flash(max(0, 1 - t / d))
            }, withKey: "flash")
        }
        disc.removeAction(forKey: "pop")
        disc.setScale(1.1)
        disc.run(.scale(to: 1, duration: 0.12), withKey: "pop")
        return true
    }
}
