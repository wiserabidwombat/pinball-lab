// Pinball Lab Table 05 (The Lamplight): cozy spots (milestone 8 round 3).
// Furniture with a gameplay effect, bought with tips in the catalog (the collection book). Up to three sit in the shop's
// cozy spots; each is a lamp on the left apron with the piece's icon, lit while it's placed and flashing while it acts,
// and a banner names it the moment it helps. The same one sentence shows in the catalog and on the pause card.
// First five pieces; the cat bed, armchair, rocking chair and window seat wait for the rules they need (gifts, a bonus
// multiplier, a kickback).
import Foundation

nonisolated enum LmpCozy: String, CaseIterable, Codable {
    case shopBell, teapot, readingLamp, ladder, clock

    var name: String {
        switch self {
        case .shopBell: return "Shop bell"
        case .teapot: return "Big teapot"
        case .readingLamp: return "Reading lamp"
        case .ladder: return "Library ladder"
        case .clock: return "Grandfather clock"
        }
    }

    /// The one sentence shown everywhere.
    var effect: String {
        switch self {
        case .shopBell: return "Regulars arrive twice as fast."
        case .teapot: return "The kettle brews in half the time."
        case .readingLamp: return "Each ball starts with the fireplace open."
        case .ladder: return "A shelf with one book left drops it for you."
        case .clock: return "Each ball starts with an 8-second ball save, and the Rush's lasts 3 seconds longer."
        }
    }

    /// From a few evenings' tips to a season's saving (the clock).
    /// T5 M8 v19 (economy round 2): 6 / 8 / 10 / 12 / 20 → 15 / 20 / 25 / 30 / 55 (a casual player earns ~8 tips an
    /// evening, a strong one ~25).
    var price: Int {
        switch self {
        case .shopBell: return 15
        case .teapot: return 20
        case .readingLamp: return 25
        case .ladder: return 30
        case .clock: return 55
        }
    }

    /// The SF Symbol on its lamp.
    var symbol: String {
        switch self {
        case .shopBell: return "bell.fill"
        case .teapot: return "cup.and.saucer.fill"
        case .readingLamp: return "lamp.desk.fill"
        case .ladder: return "books.vertical.fill"
        case .clock: return "clock.fill"
        }
    }
}
