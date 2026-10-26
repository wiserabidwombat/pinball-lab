import SpriteKit

/// Improve mode's flip-spot bands for The Lamplight (2026-10-26): the ball-centre distance from each flipper's pivot
/// at the flip that made each shot, from the Shot Lab — runs that made the shot at least 3 times and in 60 %+ of the
/// trials inside the band (both runs together), padded 1.5 pt each side. One band per shot per flipper.
/// Data: shotlab-the-lamplight-2026-10-26T15-20-57Z (books up) and shotlab-the-lamplight--books-down--2026-10-26T16-23-32Z
/// (books down), the current table at both rates. The same spot near each pivot hits the book bank while it's up and
/// goes into the fireplace once it's down, so each flipper has a BOOKS band and a FIREPLACE band over the same range;
/// the scene lights one of them. Band names are the lamps' names.
/// Left out: the loft's 120 Hz mail (8/18: the parked mail aim), the right 60 Hz mail near the pivot (15/42), the
/// loft's 60 Hz ramp (it overlaps the inner mail run), the left 60 Hz left loop (one loop per flipper), the cat.
enum LmpCoachBands {
    private static let books = SKColor(red: 0.96, green: 0.56, blue: 0.40, alpha: 1)     // old leather and the fire
    private static let ramp = SKColor(red: 0.40, green: 0.90, blue: 0.82, alpha: 1)
    private static let loop = SKColor(red: 1.00, green: 0.84, blue: 0.40, alpha: 1)      // lamplight gold
    private static let kettle = SKColor(red: 0.95, green: 0.66, blue: 0.30, alpha: 1)    // copper
    private static let mail = SKColor(red: 0.80, green: 0.62, blue: 1.00, alpha: 1)
    private static let window = SKColor(red: 0.50, green: 0.76, blue: 1.00, alpha: 1)    // evening sky

    private static func band(_ shot: String, _ label: String, _ from: CGFloat, _ to: CGFloat,
                             _ color: SKColor) -> FlipCoach.Band {
        FlipCoach.Band(shot: shot, label: label, from: from - 1.5, to: to + 1.5, color: color)
    }

    /// The book bank and, once it's down, the fireplace behind it: the same spot.
    private static func shelf(_ from: CGFloat, _ to: CGFloat) -> [FlipCoach.Band] {
        [band("bookTarget", "BOOKS", from, to, books), band("fireplace", "FIREPLACE", from, to, books)]
    }

    static let left120 = shelf(28.7, 45.6) + [band("ramp", "RAMP", 53.1, 61.5, ramp),
                                              band("rightLoop", "LOOP", 65.7, 77.4, loop)]
    static let right120 = shelf(28.7, 45.7) + [band("kettle", "KETTLE", 55.0, 63.5, kettle),
                                               band("leftLoop", "LOOP", 65.7, 77.4, loop)]
    static let loft120 = [band("windowSeat", "WINDOW", 39.6, 50.8, window)]

    static let left60 = shelf(28.7, 42.2) + [band("ramp", "RAMP", 53.0, 53.0, ramp),
                                             band("rightLoop", "LOOP", 70.2, 70.2, loop),
                                             band("mail", "MAIL", 74.9, 75.0, mail)]
    static let right60 = shelf(28.7, 42.2) + [band("kettle", "KETTLE", 49.2, 53.0, kettle),
                                              band("leftLoop", "LOOP", 61.2, 65.8, loop)]
    static let loft60 = [band("mail", "MAIL", 31.0, 31.0, mail), band("windowSeat", "WINDOW", 36.8, 47.5, window)]
}
