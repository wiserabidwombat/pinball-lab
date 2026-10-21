// Pinball Lab Table 05 (The Lamplight): seasons (milestone 8 round 4).
// Seven evenings make a season and four seasons a year, counted in evenings played (never by the calendar, so nothing is
// missed for not playing). Each season has six treasures found only in that season (they come back next year if you
// missed them), and winter brings a mysterious visitor. Helping enough regulars in a season lights its Festival Night
// (round 5), a 3-ball party; the art overlays come with the art milestone.
import Foundation

nonisolated enum LmpSeason: Int, CaseIterable, Codable {
    case spring, summer, autumn, winter

    static let eveningsPerSeason = 7
    /// M8 round 5: regulars helped in a season that light its festival (it lights on the season's last evening anyway).
    static let festivalGoal = 9

    var name: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        }
    }

    /// The season's finale, Festival Night (round 5 of M8).
    var festival: String {
        switch self {
        case .spring: return "Blossom Fair"
        case .summer: return "Midsummer Lanterns"
        case .autumn: return "Harvest Supper"
        case .winter: return "Winter Lights"
        }
    }

    /// The six treasures found only in this season.
    var treasures: [String] {
        switch self {
        case .spring: return ["Pressed Cherry Blossom", "Robin's Egg Teacup", "Seed Packet Bookmark", "Bluebell Jar",
                              "The Easter Bonnet", "Kite from the Fair"]
        case .summer: return ["Seashell Paperweight", "Straw Sunhat", "Jar of Fireflies", "Strawberry Jam Label",
                              "Lighthouse Postcard", "Midsummer Lantern"]
        case .autumn: return ["Golden Maple Leaf", "Carved Pumpkin", "Apple Cider Jug", "Acorn Bookends",
                              "Harvest Corn Doll", "Bonfire Toffee Tin"]
        case .winter: return ["Snow Globe", "Knitted Scarf", "Gingerbread Shop", "Holly Wreath",
                              "Star for the Window", "The Visitor's Lantern"]
        }
    }

    /// The season for an evening number (0-based evenings played before it).
    static func of(evening days: Int) -> LmpSeason {
        LmpSeason(rawValue: (max(days, 0) / eveningsPerSeason) % allCases.count) ?? .spring
    }
}
