import SpriteKit

/// Improve mode's flip-spot bands for Cthulhu Rising (2026-10-26): the ball-centre distance from each flipper's
/// pivot at the flip that made each shot, from the Shot Lab — solid runs of 3+ trials, padded 1.5 pt each side.
/// 120 Hz: shotlab-cthulhu-rising-2026-10-13T16-18-01Z (the 120 Hz pass has no flip assist, as then).
/// 60 Hz: shotlab-cthulhu-rising-2026-10-23T02-38-40Z (with the 60 Hz flip assist).
/// Lanes aren't arrow shots, so they have no band. Re-derive after a Shot Lab sweep that moves the windows.
enum CthCoachBands {
    private static let library = SKColor(red: 0.98, green: 0.80, blue: 0.36, alpha: 1)
    private static let ramp = SKColor(red: 0.38, green: 0.93, blue: 0.86, alpha: 1)
    private static let sigil = SKColor(red: 0.78, green: 0.58, blue: 1.00, alpha: 1)
    private static let orbit = SKColor(red: 1.00, green: 0.62, blue: 0.32, alpha: 1)
    private static let lagoon = SKColor(red: 0.45, green: 0.74, blue: 1.00, alpha: 1)

    private static func band(_ shot: CthShot, _ from: CGFloat, _ to: CGFloat, _ color: SKColor) -> FlipCoach.Band {
        FlipCoach.Band(shot: shot.rawValue, label: shot.label, from: from - 1.5, to: to + 1.5, color: color)
    }

    static let left120 = [band(.library, 27, 31, library), band(.lagoon, 36, 37, lagoon),
                          band(.rightRamp, 55, 59, ramp), band(.sigil, 75, 85, sigil)]
    static let right120 = [band(.library, 27, 31, library), band(.orbit, 65, 73, orbit)]
    static let upper120 = [band(.lagoon, 21, 31, lagoon)]

    static let left60 = [band(.library, 40, 41, library), band(.rightRamp, 51, 55, ramp), band(.sigil, 68, 72, sigil)]
    static let right60 = [band(.library, 40, 41, library), band(.orbit, 59, 72, orbit)]
    static let upper60 = [band(.lagoon, 22, 28, lagoon)]

    /// The colour key (CoachKey): every shot with a mark, and the flippers it's on.
    static var key: [CoachKeyEntry] {
        CoachKey.entries([("left", left120 + left60), ("right", right120 + right60), ("upper", upper120 + upper60)])
    }
}
