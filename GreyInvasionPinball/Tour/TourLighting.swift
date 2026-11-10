// Pinball Lab Table 06 (Orbit: Grand Tour), M5 v6: real light on the parts (the plan's third 3D trick).
// Parts drawn as sprites carry a normal map (which way each pixel faces) and SpriteKit's SKLightNodes light them live:
// each bumper has its own light that flashes on a hit, throwing a moving highlight across the bumper caps and the ball.
// Grey-box test: the three bumper caps (tools/tour_lit_parts.py) and the ball; the baked art adds normal maps per part.
import SpriteKit

enum TourLighting {
    /// The one light category: every light lights every lit sprite.
    static let category: UInt32 = 1
    /// How fast a light fades with distance (SpriteKit's exponent).
    static let falloff: CGFloat = 1.0
    /// Each of the three bumper lights carries a third of the ambient light, so a lit sprite looks as it did unlit
    /// while every light is dark (SpriteKit adds the lights' ambient colours together).
    static let ambientShare = SKColor(white: 1.0 / 3.0, alpha: 1)
    /// A bumper's flash at strength k (0…1): warm white.
    /// M5 v6b: peak 0.45 (at 1.0 the bumper's chrome skirt burned to white in the Simulator).
    static func flash(_ k: CGFloat) -> SKColor {
        let a = 0.45 * k
        return SKColor(red: a, green: 0.80 * a, blue: 0.55 * a, alpha: 1)
    }
    static let flashDuration: TimeInterval = 0.32
    /// DEBUG test modes (pause card): 0 = flash on hits, 1 = steady (every light on: look and worst-case cost), 2 = off.
    nonisolated(unsafe) static var mode = 0
    /// What lit sprites use for lightingBitMask (0 when the test turns lighting off).
    static var spriteMask: UInt32 { mode == 2 ? 0 : category }
}
