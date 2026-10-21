import SwiftUI
import UIKit
import Foundation

/// Pinball Lab (Oct 2026): every table we build, in the order we built it, so players can see how the
/// tables evolve as we get better at making them. The home screen lists the tables; tapping one plays it,
/// and each table's own menu has a "Tables" button back here.
enum LabTable: String, CaseIterable, Identifiable {
    case orbit, greyInvasion, cthulhu, monsoon, lamplight

    var id: String { rawValue }

    var number: Int {
        switch self {
        case .orbit: return 1
        case .greyInvasion: return 2
        case .cthulhu: return 3
        case .monsoon: return 4
        case .lamplight: return 5
        }
    }

    var title: String {
        switch self {
        case .orbit: return "Orbit Pinball"
        case .greyInvasion: return "Grey Invasion"
        case .cthulhu: return "Cthulhu Rising"
        case .monsoon: return "Monsoon"
        case .lamplight: return "The Lamplight"
        }
    }

    var built: String {
        switch self {
        case .orbit: return "Oct 2026 · the first table"
        case .greyInvasion: return "Oct 2026 · table two"
        case .cthulhu: return "Oct 2026 · table three"
        case .monsoon: return "Oct 2026 · table four"
        case .lamplight: return "Oct 2026 · table five"
        }
    }

    var blurb: String {
        switch self {
        case .orbit:
            return "Where it started: a one-screen space table with bumpers, slingshots, drop targets and a wormhole."
        case .greyInvasion:
            return "Grey aliens raid a farm town: two ramps, multiball, three waves and a Mothership, a camera that follows the ball."
        case .cthulhu:
            return "Research forbidden tomes, perform the ritual, then fight Cthulhu as he rises from the Lagoon. Every part modelled and rendered like a real table."
        case .monsoon:
            return "A desert sketched in pencil. Every goal brings the summer storm closer, and the rain washes watercolor into the table until the desert blooms."
        case .lamplight:
            return "A cozy bookshop-café on a rainy evening. Nothing to beat: every game fills the shelves, furnishes the shop and brings back the regulars."
        }
    }

    /// Short tags for what this table added.
    var firsts: [String] {
        switch self {
        case .orbit: return ["Flippers", "Bumpers", "Wormhole", "Skill shot"]
        case .greyInvasion: return ["Ramps", "Multiball", "Waves", "Flying camera", "Robot-tested"]
        case .cthulhu: return ["Spinner", "Magnet", "Moving toy", "Up-kicker", "Real-table art"]
        case .monsoon: return ["Color as progress", "Habitrails", "Captive ball", "Dust devil", "Watercolor"]
        case .lamplight: return ["Cozy", "Collections", "The loft", "A cat", "Seasons"]
        }
    }

    var accent: Color {
        switch self {
        case .orbit: return Color(red: 0.55, green: 0.45, blue: 1.0)
        case .greyInvasion: return Color(red: 0.35, green: 0.95, blue: 0.55)
        case .cthulhu: return Color(red: 0.30, green: 0.85, blue: 0.75)
        case .monsoon: return Color(red: 0.96, green: 0.78, blue: 0.45)
        case .lamplight: return Color(red: 1.0, green: 0.74, blue: 0.40)
        }
    }

    /// Picture on the card (an image in the bundle), if there is one yet.
    var thumbnail: String? {
        switch self {
        case .orbit: return "orbit_lab_thumb"     // the whole table (tools/orbit_lab_thumb.py), was the nebula
        case .greyInvasion: return "howto_map"
        case .cthulhu: return "cth_lab_thumb"       // the rendered table with Cthulhu risen (art round 5b)
        case .monsoon: return "mon_lab_thumb"       // the finished table, half pencil, half watercolor (tools/mon_lab_thumb_table.py)
        case .lamplight: return "lmp_lab_thumb"     // the shop on a festival evening (tools/lmp_howto.py)
        }
    }

}

/// The app's root: the table list, or the table being played.
struct PinballLabRoot: View {
    @State private var playing: LabTable? = PinballLabRoot.launchTable

    /// Debug builds launched with `-playlab <table>` (or `-shotlab <table>`) open that table at once (its view starts
    /// the lab).
    private static var launchTable: LabTable? {
        #if DEBUG
        switch PlayLab.launchTable ?? ShotLab.launchTable {
        case "lamplight": return .lamplight
        case "greyinvasion": return .greyInvasion
        case "cthulhu": return .cthulhu
        case "monsoon": return .monsoon
        case "orbit": return .orbit
        default: return nil
        }
        #else
        return nil
        #endif
    }

    var body: some View {
        Group {
            switch playing {
            case .some(.greyInvasion):
                ContentView(onExit: { playing = nil })
            case .some(.orbit):
                OrbitTableView(onExit: { playing = nil })
            case .some(.cthulhu):
                CthTableView(onExit: { playing = nil })
            case .some(.monsoon):
                MonTableView(onExit: { playing = nil })
            case .some(.lamplight):
                LmpTableView(onExit: { playing = nil })
            case .none:
                LabHomeView { table in playing = table }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

struct LabHomeView: View {
    let onPlay: (LabTable) -> Void
    @State private var story: LabTable?
    @State private var showCredits = false
    @State private var showSettings = false

    private static let ink = Color(red: 0.04, green: 0.04, blue: 0.09)
    static let background = LinearGradient(colors: [Color(red: 0.09, green: 0.07, blue: 0.20), ink],
                                           startPoint: .top, endPoint: .bottom)

    var body: some View {
        ZStack {
            Self.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            Text("PINBALL LAB")
                                .font(.orbitron(34, .black))
                                .foregroundStyle(.white)
                                .shadow(color: Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.7), radius: 12)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Settings")
                        }
                        Text("Every table we've built, in order. Play them to see how they've evolved.")
                            .font(.system(.subheadline))
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 24)

                    ForEach(LabTable.allCases) { table in
                        tableCard(table)
                    }

                    Text("More tables to come.")
                        .font(.system(.footnote))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    Button("Credits") { showCredits = true }
                        .font(.orbitron(13, .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $story) { table in
            LabTableStoryView(table: table) { onPlay(table) }
        }
        .sheet(isPresented: $showCredits) { LabCreditsView() }
        .sheet(isPresented: $showSettings) { LabSettingsView() }
    }

    private func tableCard(_ table: LabTable) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Button { onPlay(table) } label: {
                LabThumbnail(table: table, width: 84, height: 150)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(table.title)")
            VStack(alignment: .leading, spacing: 6) {
                Text("TABLE \(String(format: "%02d", table.number))")
                    .font(.orbitron(11, .bold))
                    .tracking(2)
                    .foregroundStyle(table.accent)
                Text(table.title)
                    .font(.orbitron(19, .black))
                    .foregroundStyle(.white)
                Text(table.built)
                    .font(.system(.caption))
                    .foregroundStyle(.white.opacity(0.55))
                Text(table.blurb)
                    .font(.system(.footnote))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                tags(table)
                HStack(spacing: 8) {
                    Button { onPlay(table) } label: {
                        Text("PLAY ›")
                            .font(.orbitron(12, .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(table.accent, in: Capsule())
                    }
                    Button { story = table } label: {
                        Text("HOW IT EVOLVED")
                            .font(.orbitron(10, .bold))
                            .foregroundStyle(table.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(table.accent.opacity(0.7), lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(table.accent.opacity(0.35), lineWidth: 1))
    }

    private func tags(_ table: LabTable) -> some View {
        // Wraps by hand: two rows at most on a phone.
        let rows = table.firsts.count > 3 ? [Array(table.firsts.prefix(3)), Array(table.firsts.dropFirst(3))] : [table.firsts]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    ForEach(rows[i], id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(table.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .overlay(Capsule().stroke(table.accent.opacity(0.6), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.top, 2)
    }
}
