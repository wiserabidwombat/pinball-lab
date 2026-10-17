// Pinball Lab Table 05 (The Lamplight): the shop that persists between games (milestone 6 round 1).
// The save file (versioned JSON in the app's Documents), the books you can find (6 genres × 20, common to ultra rare),
// and the find engine: rarity odds 60 / 25 / 10 / 4 / 1 with a pity counter (a rare or better within 15 finds, an ultra
// rare within 120), better odds from the loft, and "lucky evenings". The collection book (round 2) and furniture with
// the cat's perches (round 3) build on this.
import Foundation
import CoreGraphics
import Observation

/// How rare a find is. The raw value orders them. (Value types are `nonisolated`: the app defaults to the main actor,
/// and these are plain data used from SwiftUI and the scene alike.)
nonisolated enum LmpRarity: Int, Codable, CaseIterable, Comparable {
    case common, uncommon, rare, veryRare, ultraRare

    var name: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .veryRare: return "Very rare"
        case .ultraRare: return "Ultra rare"
        }
    }

    /// The edition a book of this rarity is (the plan: paperbacks to first editions).
    var edition: String {
        switch self {
        case .common: return "paperback"
        case .uncommon: return "hardback"
        case .rare: return "illustrated edition"
        case .veryRare: return "signed copy"
        case .ultraRare: return "one of a kind"
        }
    }

    static func < (a: LmpRarity, b: LmpRarity) -> Bool { a.rawValue < b.rawValue }
}

nonisolated struct LmpBook: Identifiable, Hashable {
    let id: String
    let title: String
    let genre: String
    let rarity: LmpRarity
}

/// Where a find came from: the loft keeps the rarest books.
nonisolated enum LmpFindSource { case shelf, loft, cat }

nonisolated struct LmpFind {
    let book: LmpBook
    let isNew: Bool
}

/// What's saved. `version` lets later updates add things without breaking old saves.
nonisolated struct LmpShopSave: Codable {
    struct Owned: Codable {
        var firstFound: Date
        var count: Int
    }
    var version = 2
    var daysPlayed = 0
    var tips = 0
    var bestEvening = 0
    var owned: [String: Owned] = [:]
    var findsSinceRare = 0
    var findsSinceUltra = 0
    /// M6 round 3 (version 2): furniture owned, by id (the cat's perches so far).
    var furniture: [String] = []
    /// M8: friendship with each regular (requests finished for them), by regular id.
    var friendship: [String: Int] = [:]

    init() {}

    /// Every field is optional on the way in, so an older save (or one from a newer build) still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        daysPlayed = try c.decodeIfPresent(Int.self, forKey: .daysPlayed) ?? 0
        tips = try c.decodeIfPresent(Int.self, forKey: .tips) ?? 0
        bestEvening = try c.decodeIfPresent(Int.self, forKey: .bestEvening) ?? 0
        owned = try c.decodeIfPresent([String: Owned].self, forKey: .owned) ?? [:]
        findsSinceRare = try c.decodeIfPresent(Int.self, forKey: .findsSinceRare) ?? 0
        findsSinceUltra = try c.decodeIfPresent(Int.self, forKey: .findsSinceUltra) ?? 0
        furniture = try c.decodeIfPresent([String].self, forKey: .furniture) ?? []
        friendship = try c.decodeIfPresent([String: Int].self, forKey: .friendship) ?? [:]
        version = 2
    }
}

/// The cat's perches (M6 round 3): furniture for her. The shelf is hers from the start; each perch you buy adds a spot
/// she roams to, and wherever she is changes that shot a little (the sentence shown everywhere).
nonisolated enum LmpPerch: String, CaseIterable, Codable {
    case shelf, mantel, kettle, windowSeat

    /// Where she sits ("on the mantel").
    var spot: String {
        switch self {
        case .shelf: return "on her shelf"
        case .mantel: return "on the mantel"
        case .kettle: return "by the kettle"
        case .windowSeat: return "in the window seat"
        }
    }

    /// The piece of furniture that makes the spot hers.
    var furnitureName: String {
        switch self {
        case .shelf: return "Cat shelf"
        case .mantel: return "Mantel blanket"
        case .kettle: return "Basket by the kettle"
        case .windowSeat: return "Window-seat cushion"
        }
    }

    var price: Int {
        switch self {
        case .shelf: return 0
        case .mantel: return 8
        case .kettle: return 5
        case .windowSeat: return 6
        }
    }

    /// The one sentence shown in the collection book, on the pause card and when she moves there.
    var effect: String {
        switch self {
        case .shelf: return "She walks her shelf and swats balls back down."
        case .mantel: return "She swats balls off the fireplace roof."
        case .kettle: return "The kettle scores double while she warms her paws."
        case .windowSeat: return "The window seat finds an extra book while she's there."
        }
    }

    /// Up in the loft: drawn above it, with no body (floor balls can't reach her there).
    var onLoft: Bool { self == .windowSeat }

    /// Where she sits (the shelf is where she starts her walk).
    var position: CGPoint {
        switch self {
        case .shelf: return CGPoint(x: 370, y: 1175)
        case .mantel: return CGPoint(x: 252, y: 877)
        case .kettle: return CGPoint(x: 134, y: 945)
        case .windowSeat: return CGPoint(x: 165, y: 1140)
        }
    }
}

@MainActor
@Observable
final class LmpShop {
    static let shared = LmpShop()

    private(set) var save = LmpShopSave()

    // MARK: The books

    /// Six genre shelves of 20: 8 common, 5 uncommon, 4 rare, 2 very rare, 1 ultra rare each (in that order).
    static let genres: [(name: String, titles: [String])] = [
        ("Mystery", ["The Vicar's Umbrella", "Murder at Mill Lane", "A Quiet Death in Thornbury", "The Missing Marmalade",
                     "Tea, Toast and Trouble", "The Postman Rings at Nine", "Footprints in the Frost",
                     "The Case of the Crooked Hedge",
                     "The Lighthouse Keeper's Daughter", "Inspector Fennel Investigates", "Poison in the Pantry",
                     "The Clock That Struck Thirteen", "Death Wears Tweed",
                     "The Owl at Midnight", "A Riddle in the Rectory", "The Seven Locked Drawers", "Shadows on the Harbour",
                     "The Silent Bell", "Inspector Fennel's Last Case",
                     "The Lost Diary of Agnes Thorne"]),
        ("Romance", ["Letters from the Orchard", "A Summer at Rosehill", "The Baker's Promise", "Love Among the Lavender",
                     "Rain on Primrose Street", "The Bookbinder's Heart", "Second Chances at Seaview", "Under the Willow",
                     "The Lighthouse Waltz", "A Garden for Two", "The Ferryman's Song", "Snowfall at Hartley Hall",
                     "The Last Train to Ambleside",
                     "Beneath a Paper Moon", "The Rose-Pressed Letters", "An Autumn Courtship", "The Glassblower's Bride",
                     "Tides of the Heart", "The Midsummer Dance",
                     "A Book of Pressed Flowers"]),
        ("Adventure", ["The Map in the Attic", "Beyond the Misty Fells", "The Clockwork Balloon", "Smugglers' Cove",
                       "The Island of Gulls", "Over the Hills to Barrow", "The Brass Compass", "Lanterns on the River",
                       "The Secret of Gull Rock", "Captain Marlow's Voyage", "The Hidden Glen", "Across the Frozen Lake",
                       "The Cartographer's Apprentice",
                       "The Sunken Bell", "Twenty Leagues of Fog", "The Kite That Crossed the Sea", "The Lost Lighthouse",
                       "The Golden Albatross", "The Last Expedition",
                       "The 1890 Village Map"]),
        ("Poetry", ["Small Hours", "Teacups and Thunder", "Hedgerow Verses", "Songs for a Rainy Window", "The Quiet Year",
                    "Moss and Morning", "Crumbs for the Robins", "A Pocket of Stars",
                    "Lamplight Sonnets", "The Shy Poet's Notebook", "Odes to Ordinary Things", "Winter Lullabies",
                    "The Fern Collection",
                    "Selected Verses of E. Hartwell", "A Year of Haiku", "The Owl and the Hearth", "Harbour Songs",
                    "Letters to the Moon", "The Nightingale Cycle",
                    "The Poet's Handwritten Draft"]),
        ("Cookbooks", ["Soups for Sundays", "The Little Book of Scones", "Jams and Preserves", "One-Pot Suppers",
                       "Teatime Treats", "Bread for Beginners", "The Allotment Kitchen", "Pies for Every Season",
                       "Grandmother's Recipe Box", "The Village Fete Cookbook", "Cakes of the Coast", "Herbs and Honey",
                       "Biscuits by the Fire",
                       "The Lighthouse Café Cookbook", "Feasts for Festival Nights", "A Baker's Dozen Secrets",
                       "The Honey Harvest",
                       "The Duke's Banquet", "Recipes from the Old Mill",
                       "The Original Thornbury Pie Recipe"]),
        ("Local history", ["A Short History of Thornbury", "The Mill and the River", "Churches of the Valley",
                           "Old Inns and Coaching Roads", "The Harbour in Photographs", "Walks Around the Village",
                           "Wildflowers of the Fells", "The Railway Comes to Town",
                           "The Great Flood of 1903", "Lighthouses of the Coast", "The Thornbury Fair Through the Years",
                           "Legends of the Fells", "The Old School House",
                           "The Founding Families", "Smuggling Tales of the Bay", "The Lost Village of Ashby",
                           "The Clockmaker's Workshop",
                           "The Parish Register, 1750–1800", "The Squire's Letters",
                           "The Village Charter of 1602"]),
    ]

    static let books: [LmpBook] = {
        let rarityByIndex: [LmpRarity] = Array(repeating: .common, count: 8) + Array(repeating: .uncommon, count: 5)
            + Array(repeating: .rare, count: 4) + Array(repeating: .veryRare, count: 2) + [.ultraRare]
        var all: [LmpBook] = []
        for (g, genre) in genres.enumerated() {
            for (i, title) in genre.titles.enumerated() {
                all.append(LmpBook(id: "book.\(g).\(i)", title: title, genre: genre.name, rarity: rarityByIndex[i]))
            }
        }
        return all
    }()

    var booksOwned: Int { Self.books.filter { save.owned[$0.id] != nil }.count }

    func owns(_ book: LmpBook) -> Bool { save.owned[book.id] != nil }

    // MARK: Finding

    /// Odds per find, common → ultra rare (the plan's 60 / 25 / 10 / 4 / 1).
    static let shelfWeights: [Double] = [60, 25, 10, 4, 1]
    /// The loft keeps the rarest books.
    static let loftWeights: [Double] = [40, 30, 18, 9, 3]
    /// A lucky evening multiplies rare-and-better odds by this.
    static let luckyBoost: Double = 1.5
    static let pityRare = 15
    static let pityUltra = 120

    /// Rolls a find, records it and saves. A duplicate is lent to a neighbour for a tip.
    func find(from source: LmpFindSource, lucky: Bool) -> LmpFind {
        save.findsSinceRare += 1
        save.findsSinceUltra += 1
        var rarity = rollRarity(source: source, lucky: lucky)
        if save.findsSinceUltra >= Self.pityUltra {
            rarity = .ultraRare
        } else if save.findsSinceRare >= Self.pityRare, rarity < .rare {
            rarity = .rare
        }
        if rarity >= .rare { save.findsSinceRare = 0 }
        if rarity == .ultraRare { save.findsSinceUltra = 0 }

        let ofRarity = Self.books.filter { $0.rarity == rarity }
        let missing = ofRarity.filter { save.owned[$0.id] == nil }
        let book = (missing.randomElement() ?? ofRarity.randomElement())!
        let isNew = save.owned[book.id] == nil
        if isNew {
            save.owned[book.id] = LmpShopSave.Owned(firstFound: Date(), count: 1)
        } else {
            save.owned[book.id]?.count += 1
            save.tips += 1
        }
        write()
        return LmpFind(book: book, isNew: isNew)
    }

    private func rollRarity(source: LmpFindSource, lucky: Bool) -> LmpRarity {
        var w = source == .loft ? Self.loftWeights : Self.shelfWeights
        if lucky { for i in 2..<w.count { w[i] *= Self.luckyBoost } }
        var r = Double.random(in: 0..<w.reduce(0, +))
        for (i, weight) in w.enumerated() {
            if r < weight { return LmpRarity(rawValue: i) ?? .common }
            r -= weight
        }
        return .common
    }

    /// Closing time: one more day played; the evening's score is kept if it's the best.
    func endEvening(score: Int) {
        save.daysPlayed += 1
        save.bestEvening = max(save.bestEvening, score)
        save.tips += Self.tips(forScore: score)
        write()
    }

    // MARK: Tips and furniture (M6 round 3)

    /// The evening's score becomes tips at closing (the plan: 1 tip per 10,000 points, to tune).
    static let pointsPerTip = 10_000
    static func tips(forScore score: Int) -> Int { score / pointsPerTip }

    func owns(_ perch: LmpPerch) -> Bool { perch == .shelf || save.furniture.contains(perch.rawValue) }

    var ownedPerches: [LmpPerch] { LmpPerch.allCases.filter { owns($0) } }

    /// Buys a perch with tips. Returns false if it's already owned or there aren't enough tips.
    @discardableResult
    func buy(_ perch: LmpPerch) -> Bool {
        guard !owns(perch), save.tips >= perch.price else { return false }
        save.tips -= perch.price
        save.furniture.append(perch.rawValue)
        write()
        return true
    }

    // MARK: Regulars (M8)

    /// A finished request: a tip from them and a step of friendship. Returns their new friendship.
    @discardableResult
    func finishRequest(for regular: LmpRegular) -> Int {
        save.tips += 1
        let level = (save.friendship[regular.id] ?? 0) + 1
        save.friendship[regular.id] = level
        write()
        return level
    }

    #if DEBUG
    func debugAddTips(_ n: Int) {
        save.tips += n
        write()
    }
    #endif

    /// "Start a new shop" in the collection book (after a confirm): everything back to day one.
    func startNewShop() {
        save = LmpShopSave()
        write()
    }

    // MARK: The save file

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lamplight", isDirectory: true)
            .appendingPathComponent("shop.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let loaded = try? JSONDecoder().decode(LmpShopSave.self, from: data) {
            save = loaded
        }
    }

    private func write() {
        do {
            try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(save).write(to: Self.fileURL, options: .atomic)
        } catch {
            print("LAMPLIGHT: couldn't save the shop: \(error)")
        }
    }
}
