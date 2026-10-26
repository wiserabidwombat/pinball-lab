import SwiftUI
import SpriteKit

/// Improve mode's colour key (2026-10-26): which colour on the flippers is which shot, for one table. Built from the
/// same band lists the coach draws (`<Tbl>CoachBands`), so a refreshed Shot Lab updates the key too. Shown the first
/// time a table is played with Improve on, and from the pause card's "Colour Key" button.
struct CoachKeyEntry: Identifiable {
    let label: String             // the band's label, e.g. "LIBRARY"
    let shot: String              // the band's shot name (its lamp / the table's shot event), e.g. "library"
    let color: SKColor
    let flippers: String          // e.g. "Left & right flippers"
    var id: String { label }
}

enum CoachKey {
    /// One entry per shot, in the order they first appear, with the flippers that have a mark for it.
    /// `flippers`: each flipper's name ("left", "right", "upper", "loft") and all its bands (both rates).
    static func entries(_ flippers: [(name: String, bands: [FlipCoach.Band])]) -> [CoachKeyEntry] {
        var order: [String] = []
        var first: [String: FlipCoach.Band] = [:]
        var on: [String: [String]] = [:]
        for flipper in flippers {
            for band in flipper.bands {
                if first[band.label] == nil { first[band.label] = band; order.append(band.label) }
                if !(on[band.label] ?? []).contains(flipper.name) { on[band.label, default: []].append(flipper.name) }
            }
        }
        return order.compactMap { label in
            guard let band = first[label] else { return nil }
            return CoachKeyEntry(label: label, shot: band.shot, color: band.color, flippers: describe(on[label] ?? []))
        }
    }

    /// ["left", "right"] → "Left & right flippers"; ["upper"] → "Upper flipper".
    private static func describe(_ names: [String]) -> String {
        guard let firstName = names.first else { return "" }
        if names.count == 1 { return firstName.capitalized + " flipper" }
        let head = names.dropLast().joined(separator: ", ")
        let text = head + " & " + (names.last ?? "") + " flippers"
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Whether this table's key has been shown (and dismissed) before.
    static func seen(_ table: String) -> Bool {
        UserDefaults.standard.bool(forKey: "coachKeySeen." + table)
    }

    static func markSeen(_ table: String) {
        UserDefaults.standard.set(true, forKey: "coachKeySeen." + table)
    }
}

/// The card: a colour swatch, the shot and its flippers for each shot, then how to read the marks.
struct CoachKeyView: View {
    let table: String
    let entries: [CoachKeyEntry]
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("COLOUR KEY")
                        .font(.orbitron(22, .black))
                    Text(table)
                        .font(.orbitron(12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(entries) { entry in
                        HStack(spacing: 12) {
                            Capsule()
                                .fill(Color(uiColor: entry.color))
                                .frame(width: 28, height: 7)
                                .overlay(Capsule().stroke(.black.opacity(0.7), lineWidth: 1.5))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.label)
                                    .font(.orbitron(14, .bold))
                                    .foregroundStyle(Color(uiColor: entry.color))
                                Text(entry.flippers)
                                    .font(.orbitron(10))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("The marks on each flipper show where the ball should be when you flip to make that shot. "
                     + "Bright, labelled marks are lit right now; faint ones are always there. "
                     + "Flip on a mark and it flashes white.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onDone) {
                    Text("Got it")
                        .font(.orbitron(17, .bold))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.15, green: 0.55, blue: 0.50), in: Capsule())
                }
                .foregroundStyle(.white)
            }
            .foregroundStyle(.white)
            .padding(26)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .dark)
        }
    }
}

/// Improve mode's shot meter (2026-10-26): the pause card's "SHOTS THIS GAME" block — one cell per shot in the
/// table's colour key, its count this game over its label in its colour.
struct ShotMeterView: View {
    let cells: [(label: String, count: Int, color: SKColor)]

    var body: some View {
        VStack(spacing: 6) {
            Text("SHOTS THIS GAME")
                .font(.orbitron(10))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.55))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 8) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    VStack(spacing: 1) {
                        Text("\(cell.count)")
                            .font(.orbitron(18, .bold))
                            .monospacedDigit()
                            .foregroundStyle(cell.count > 0 ? .white : .white.opacity(0.4))
                        Text(cell.label)
                            .font(.orbitron(9, .bold))
                            .foregroundStyle(Color(uiColor: cell.color))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}
