// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was Effects.swift.
import SpriteKit
import UIKit

/// Particle effects built in code from the "orbit_star" sprite (Kenney, CC0). No .sks files needed.
@MainActor
enum OrbitEffects {
    private static let spark = SKTexture(imageNamed: "orbit_star")

    /// A one-shot burst of sparks that removes itself when done.
    static func burst(in parent: SKNode, at point: CGPoint, color: SKColor,
                      count: Int = 14, speed: CGFloat = 220,
                      lifetime: CGFloat = 0.35, size: CGFloat = 0.22) {
        let e = SKEmitterNode()
        e.particleTexture = spark
        e.position = point
        e.zPosition = 20
        e.particleBirthRate = CGFloat(count) * 40     // all out in ~1/40 s
        e.numParticlesToEmit = count
        e.particleLifetime = lifetime
        e.particleLifetimeRange = lifetime * 0.4
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.6
        e.emissionAngleRange = .pi * 2
        e.particleScale = size
        e.particleScaleRange = size * 0.5
        e.particleScaleSpeed = -size / lifetime
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1 / lifetime
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        parent.addChild(e)
        e.run(.sequence([.wait(forDuration: TimeInterval(lifetime * 1.5) + 0.1), .removeFromParent()]))
    }

    /// A glowing trail for the ball. Add as a child of the ball, then set targetNode to the scene
    /// so the particles stay where they were emitted.
    static func ballTrail() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = spark
        e.zPosition = -1
        e.particleBirthRate = 90
        e.particleLifetime = 0.22
        e.particleSpeed = 0
        e.particleScale = 0.32
        e.particleScaleSpeed = -1.4
        e.particleAlpha = 0.6
        e.particleAlphaSpeed = -2.7
        e.particleColor = SKColor(red: 0.45, green: 0.8, blue: 1.0, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        return e
    }

    // Shared colors
    static let sparkOrange = SKColor(red: 1.0, green: 0.6, blue: 0.25, alpha: 1)
    static let rockBrown = SKColor(red: 0.85, green: 0.55, blue: 0.3, alpha: 1)
    static let wormholePurple = SKColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 1)
    static let gold = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
}

/// Shakes the scene's camera. Skipped when the system "Reduce Motion" setting is on.
@MainActor
final class OrbitCameraShake {
    let camera = SKCameraNode()
    private var home: CGPoint = .zero

    func install(in scene: SKScene) {
        home = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        camera.position = home
        scene.addChild(camera)
        scene.camera = camera
    }

    /// `strength` is the largest offset in points (try 4 for small hits, 10 for big ones).
    func shake(strength: CGFloat, duration: TimeInterval = 0.3) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        camera.removeAction(forKey: "shake")
        camera.position = home
        let steps = 8
        var moves: [SKAction] = []
        for i in 0..<steps {
            let falloff = 1 - CGFloat(i) / CGFloat(steps)
            let offset = CGPoint(x: .random(in: -1...1) * strength * falloff,
                                 y: .random(in: -1...1) * strength * falloff)
            moves.append(.move(to: CGPoint(x: home.x + offset.x, y: home.y + offset.y),
                               duration: duration / Double(steps + 1)))
        }
        moves.append(.move(to: home, duration: duration / Double(steps + 1)))
        camera.run(.sequence(moves), withKey: "shake")
    }
}
