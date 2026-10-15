import SpriteKit
import CoreGraphics
import Foundation

/// Particle bursts built in code from spark.png (milestone 9, adapted from Orbit Pinball).
/// No .sks files. Bursts sit above the balls (z 35) and remove themselves.
@MainActor
enum Effects {
    private static let spark = SKTexture(imageNamed: "spark")

    /// A one-shot burst of sparks. `size` is the particle scale of the 32 px texture
    /// (0.3 ≈ 10 pt dots).
    static func burst(in parent: SKNode, at point: CGPoint, color: SKColor,
                      count: Int = 14, speed: CGFloat = 220,
                      lifetime: CGFloat = 0.35, size: CGFloat = 0.3) {
        let e = SKEmitterNode()
        e.particleTexture = spark
        e.position = point
        e.zPosition = 35
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

    /// A soft glowing trail for the ball (from Orbit Pinball). Add as a child of the ball and set
    /// targetNode to the scene so the particles stay where they were emitted; the ball turns the
    /// birth rate up only while it's moving fast.
    static func ballTrail() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = spark
        e.zPosition = -2
        e.particleBirthRate = 0
        e.particleLifetime = 0.22
        e.particleSpeed = 0
        e.particleScale = 0.45
        e.particleScaleSpeed = -1.8
        e.particleAlpha = 0.5
        e.particleAlphaSpeed = -2.2
        e.particleColor = SKColor(red: 0.6, green: 1.0, blue: 0.85, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        return e
    }

    // Shared colours (from the art palette)
    static let orange = SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
    static let gold = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
    static let alienGreen = SKColor(red: 0.35, green: 1.0, blue: 0.55, alpha: 1)
    static let fighterRed = SKColor(red: 1.0, green: 0.35, blue: 0.3, alpha: 1)
    static let beamWhite = SKColor(red: 0.92, green: 1.0, blue: 0.85, alpha: 1)
}
