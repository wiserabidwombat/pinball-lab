import SwiftUI
import UIKit
import Foundation

// Play Lab plan 2, round 23: the robots' hall of fame on each table's "How it evolved" page. The data is
// HallOfFame/halloffame.json (bundled), written on the Mac by tools/playlab_halloffame.py after every Play Lab sweep:
// the best robot game per table and skill, and the top game's last screenshot (hof-<table>.jpg).

nonisolated struct LabHallEntry: Codable {
    let score: Int
    let date: String
    let pass: String
    let minutes: Double
    let picture: String?
}

nonisolated struct LabHall: Codable {
    let updated: String
    let tables: [String: [String: LabHallEntry]]
}

enum LabHallOfFame {
    static let skills = ["beginner", "intermediate", "advanced", "expert"]

    static let hall: LabHall? = {
        guard let url = Bundle.main.url(forResource: "halloffame", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LabHall.self, from: data)
    }()

    /// This table's entries in skill order, or nil when the hall has none (Orbit, or no sweep yet).
    static func entries(for table: LabTable) -> [(skill: String, entry: LabHallEntry)]? {
        guard let t = hall?.tables[table.title] else { return nil }
        let list = skills.compactMap { s in t[s].map { (s, $0) } }
        return list.isEmpty ? nil : list
    }
}

struct LabHallOfFameView: View {
    let table: LabTable
    let entries: [(skill: String, entry: LabHallEntry)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The robots' best games in the Play Lab, the lab where they test every table. Can you beat them?")
                .font(.system(.subheadline))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(entries, id: \.skill) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text(item.skill.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 104, alignment: .leading)
                    Text(item.entry.score.formatted())
                        .font(.orbitron(15, .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text("\(item.entry.date) · \(item.entry.pass == "hz60" ? "60 Hz" : "120 Hz")")
                        .font(.system(.caption))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            if let name = entries.compactMap({ $0.entry.picture }).first,
               let path = Bundle.main.path(forResource: (name as NSString).deletingPathExtension,
                                           ofType: (name as NSString).pathExtension),
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(table.accent.opacity(0.4), lineWidth: 1))
                    .frame(maxWidth: .infinity)
                Text("The top game's last moment")
                    .font(.system(.caption))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
