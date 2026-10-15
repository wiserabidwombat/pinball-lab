// Pinball Lab Table 03 (Cthulhu Rising), juice round 3: the table's own effects. Bursts in the table's palette
// (instead of Grey Invasion's alien green and orange), water splashes with ripples for the Lagoon and Cthulhu,
// and rising embers for the candles. Built on Effects.burst (spark.png, no .sks files).
import SpriteKit
import CoreGraphics
import Foundation

@MainActor
enum CthEffects {
    // The table's palette (from the rendered art)
    static let eldritch = SKColor(red: 0.30, green: 0.95, blue: 0.80, alpha: 1)   // the sea-green glow of the caps and eyes
    static let sea = SKColor(red: 0.45, green: 0.85, blue: 0.82, alpha: 1)        // spray
    static let bone = SKColor(red: 1.0, green: 0.92, blue: 0.76, alpha: 1)        // rubbers, targets, the flippers
    static let candle = SKColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1)      // flames
    static let brass = SKColor(red: 1.0, green: 0.80, blue: 0.42, alpha: 1)       // the Library, the wire

    private static let spark = SKTexture(imageNamed: "spark")

    /// A burst of sparks in the table's palette (Effects.burst).
    static func burst(in parent: SKNode, at point: CGPoint, color: SKColor, count: Int = 14, speed: CGFloat = 220,
                      lifetime: CGFloat = 0.35, size: CGFloat = 0.3) {
        Effects.burst(in: parent, at: point, color: color, count: count, speed: speed, lifetime: lifetime, size: size)
    }

    /// Water breaking: spray thrown up the table that falls back, and `rings` ripples spreading out over the
    /// floor (under the balls). `radius` = how far the ripples spread.
    static func splash(in parent: SKNode, at point: CGPoint, radius: CGFloat = 40, rings: Int = 3, drops: Int = 24) {
        let e = SKEmitterNode()
        e.particleTexture = spark
        e.position = point
        e.zPosition = 35
        e.particleBirthRate = CGFloat(drops) * 30
        e.numParticlesToEmit = drops
        e.particleLifetime = 0.55
        e.particleLifetimeRange = 0.2
        e.emissionAngle = .pi / 2                     // up the table (the oblique "up")
        e.emissionAngleRange = .pi * 0.9
        e.particleSpeed = radius * 4.5
        e.particleSpeedRange = radius * 2.5
        e.yAcceleration = -radius * 14                // falls back into the water
        e.particleScale = 0.22
        e.particleScaleRange = 0.1
        e.particleScaleSpeed = -0.2
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -1.4
        e.particleColor = sea
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        parent.addChild(e)
        e.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))

        for k in 0..<rings {
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.position = point
            ring.zPosition = 2                        // on the floor: over the art, under the balls
            ring.fillColor = .clear
            ring.strokeColor = sea.withAlphaComponent(0.75)
            ring.lineWidth = 2.2
            ring.alpha = 0
            ring.setScale(0.25)
            parent.addChild(ring)
            let grow = SKAction.scale(to: 1.0 + CGFloat(k) * 0.25, duration: 0.9)
            grow.timingMode = .easeOut
            ring.run(.sequence([
                .wait(forDuration: 0.14 * Double(k)),
                .group([.fadeAlpha(to: 1, duration: 0.05), grow,
                        .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.6)])]),
                .removeFromParent(),
            ]))
        }
    }

    /// A candle catching: a bright flare and a few embers drifting up.
    static func embers(in parent: SKNode, at point: CGPoint, count: Int = 12) {
        Effects.burst(in: parent, at: point, color: candle, count: 8, speed: 70, lifetime: 0.3, size: 0.35)
        let e = SKEmitterNode()
        e.particleTexture = spark
        e.position = point
        e.zPosition = 35
        e.particleBirthRate = CGFloat(count) * 8      // spread over ~1/8 s
        e.numParticlesToEmit = count
        e.particleLifetime = 0.9
        e.particleLifetimeRange = 0.4
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi * 0.35
        e.particleSpeed = 55
        e.particleSpeedRange = 30
        e.yAcceleration = 30                          // embers rise
        e.xAcceleration = 0
        e.particlePositionRange = CGVector(dx: 6, dy: 2)
        e.particleScale = 0.12
        e.particleScaleRange = 0.06
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.0
        e.particleColor = candle
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        parent.addChild(e)
        e.run(.sequence([.wait(forDuration: 1.6), .removeFromParent()]))
    }
}
