import SpriteKit

/// Improve mode's flip-spot bands for Monsoon (2026-10-26): the ball-centre distance from each flipper's pivot at
/// the flip that made each shot, from the Shot Lab — runs that made the shot at least 3 times and in 60 %+ of the
/// trials inside the band, padded 1.5 pt each side. One band per shot per flipper.
/// Both rates: shotlab-monsoon-2026-10-21T21-32-47Z (the current physics, with the 60 Hz flip assist).
/// Band names are the arrow lamps' names ("arrow.<name>"), plus "lane" for the raindrop lanes (lit while one is dark).
/// Left out as too mixed: the left 120 Hz arroyo near the pivot (13/28), the right 120 Hz lanes (3/6) and captive
/// (2 trials), the upper 120 Hz arroyo (5/27) and inner lane run (8/21), the upper 60 Hz saguaros (5/26).
/// Re-derive after a Shot Lab sweep that moves the windows.
enum MonCoachBands {
    private static let arroyo = SKColor(red: 0.42, green: 0.70, blue: 1.00, alpha: 1)    // water
    private static let mesa = SKColor(red: 1.00, green: 0.52, blue: 0.36, alpha: 1)      // red rock
    private static let saguaro = SKColor(red: 0.50, green: 0.92, blue: 0.48, alpha: 1)   // cactus
    private static let orbit = SKColor(red: 1.00, green: 0.84, blue: 0.38, alpha: 1)     // sun
    private static let lane = SKColor(red: 1.00, green: 0.55, blue: 0.85, alpha: 1)      // the raindrop lanes

    private static func band(_ shot: String, _ label: String, _ from: CGFloat, _ to: CGFloat,
                             _ color: SKColor) -> FlipCoach.Band {
        FlipCoach.Band(shot: shot, label: label, from: from - 1.5, to: to + 1.5, color: color)
    }

    static let left120 = [band("arroyo", "ARROYO", 37.5, 49.1, arroyo), band("mesaRamp", "MESA", 54.9, 61.3, mesa),
                          band("saguaros", "SAGUAROS", 70.2, 84.6, saguaro)]
    static let right120 = [band("arroyo", "ARROYO", 33.5, 51.0, arroyo), band("orbit", "ORBIT", 63.2, 72.3, orbit)]
    static let upper120 = [band("lane", "LANES", 32.5, 37.9, lane)]

    static let left60 = [band("arroyo", "ARROYO", 47.2, 47.4, arroyo), band("mesaRamp", "MESA", 50.9, 55.0, mesa),
                         band("saguaros", "SAGUAROS", 67.6, 72.2, saguaro)]
    static let right60 = [band("arroyo", "ARROYO", 40.5, 40.6, arroyo), band("lane", "LANES", 43.9, 43.9, lane),
                          band("orbit", "ORBIT", 58.8, 63.3, orbit)]
    static let upper60 = [band("lane", "LANES", 26.9, 33.3, lane), band("arroyo", "ARROYO", 38.8, 38.8, arroyo)]
}
