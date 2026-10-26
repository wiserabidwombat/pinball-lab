import SpriteKit

/// Improve mode's flip-spot bands for Grey Invasion (2026-10-26): the ball-centre distance from each flipper's pivot
/// at the flip that made each shot, from the Shot Lab — runs that made the shot at least 3 times and in 60 %+ of the
/// trials inside the band, padded 1.5 pt each side. One band per shot per flipper.
/// Data: shotlab-grey-invasion-2026-10-26T17-33-44Z (the current table, the 60 Hz-only assist), lower flippers only:
/// the Shot Lab doesn't sweep the upper flipper, so it has no marks. Band names are the arrow lamps' names
/// ("arrow.<name>"; the fighter bank's lamp is "arrow.bank").
/// The 120 Hz HANGAR runs are kept just under the rule (left 10/17, right 10/16): the misses sit inside the same run,
/// and the Hangar is the table's main shot. Left out: the stray 120 Hz shots on the right (one abduction, one fighter).
enum GiCoachBands {
    private static let hangar = SKColor(red: 0.45, green: 1.00, blue: 0.45, alpha: 1)    // alien green
    private static let leftRamp = SKColor(red: 0.35, green: 0.92, blue: 1.00, alpha: 1)  // cyan
    private static let rightRamp = SKColor(red: 0.55, green: 0.62, blue: 1.00, alpha: 1) // blue-violet
    private static let orbit = SKColor(red: 1.00, green: 0.62, blue: 0.30, alpha: 1)
    private static let lock = SKColor(red: 1.00, green: 0.45, blue: 0.90, alpha: 1)      // the abduction lock
    private static let bank = SKColor(red: 1.00, green: 0.90, blue: 0.35, alpha: 1)      // the fighter bank

    private static func band(_ shot: String, _ label: String, _ from: CGFloat, _ to: CGFloat,
                             _ color: SKColor) -> FlipCoach.Band {
        FlipCoach.Band(shot: shot, label: label, from: from - 1.5, to: to + 1.5, color: color)
    }

    static let left120 = [band("hangar", "HANGAR", 27.0, 32.0, hangar), band("rightRamp", "R RAMP", 55.1, 63.5, rightRamp),
                          band("abduction", "LOCK", 67.7, 72.3, lock), band("bank", "BANK", 74.7, 84.6, bank)]
    static let right120 = [band("hangar", "HANGAR", 27.0, 32.1, hangar), band("leftRamp", "L RAMP", 45.7, 61.1, leftRamp),
                           band("orbit", "ORBIT", 65.4, 72.3, orbit)]

    static let left60 = [band("leftRamp", "L RAMP", 32.2, 32.2, leftRamp), band("hangar", "HANGAR", 40.4, 40.6, hangar),
                         band("rightRamp", "R RAMP", 50.9, 55.0, rightRamp), band("abduction", "LOCK", 58.9, 59.0, lock),
                         band("bank", "BANK", 67.6, 72.2, bank)]
    static let right60 = [band("abduction", "LOCK", 34.6, 34.7, lock), band("hangar", "HANGAR", 40.5, 40.6, hangar),
                          band("leftRamp", "L RAMP", 43.6, 55.0, leftRamp), band("orbit", "ORBIT", 58.7, 72.4, orbit)]
}
