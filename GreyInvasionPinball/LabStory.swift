import SwiftUI
import UIKit
import Foundation

// Pinball Lab round 3 (Oct 2026): each table's "how it evolved" page, the shared credits and the shared
// sound/haptics settings, all reached from the Pinball Lab home screen.

/// One line in a table's "At a glance" list. The same labels are used for every table, in the same
/// order, so each page can show what the previous table had beside it.
struct LabStat: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// A short headline and a sentence: something a table added, or something we learned building it.
struct LabNote: Identifiable {
    let title: String
    let detail: String
    var id: String { title }
}

extension LabTable {
    /// The table before this one, if there is one.
    var previous: LabTable? {
        let all = LabTable.allCases
        guard let i = all.firstIndex(of: self), i > 0 else { return nil }
        return all[i - 1]
    }

    var stats: [LabStat] {
        switch self {
        case .orbit:
            return [
                LabStat(label: "Table size", value: "390 × 844 points, one screen"),
                LabStat(label: "Camera", value: "Fixed: the whole table is always in view"),
                LabStat(label: "Frame rate", value: "60 fps"),
                LabStat(label: "Goal", value: "High score: 3 balls, multiplier up to 5×"),
                LabStat(label: "Art", value: "Kenney space packs (free, CC0)"),
                LabStat(label: "Sounds", value: "13 effects"),
                LabStat(label: "Code", value: "About 2,000 lines in 13 files"),
                LabStat(label: "Testing", value: "Played by hand"),
            ]
        case .greyInvasion:
            return [
                LabStat(label: "Table size", value: "600 × 1300 points, bigger than the screen"),
                LabStat(label: "Camera", value: "Flies with the ball, or a Top-Down view"),
                LabStat(label: "Frame rate", value: "120 fps on ProMotion iPhones"),
                LabStat(label: "Goal", value: "Beat 3 waves of saucers, then the Mothership"),
                LabStat(label: "Art", value: "All drawn for this table, in code"),
                LabStat(label: "Sounds", value: "28 effects"),
                LabStat(label: "Code", value: "About 5,500 lines in 26 files"),
                LabStat(label: "Testing", value: "By hand, plus the Shot Lab robot"),
            ]
        case .cthulhu:
            // Polish round 2 (T3 M10 v2): the finished table's numbers.
            return [
                LabStat(label: "Table size", value: "600 × 1300 points, the same as Grey Invasion"),
                LabStat(label: "Camera", value: "Flies with the ball, a Wide view, or Top-Down"),
                LabStat(label: "Frame rate", value: "120 fps on ProMotion iPhones"),
                LabStat(label: "Goal", value: "Read 3 tomes, perform the Ritual, banish Cthulhu"),
                LabStat(label: "Art", value: "Every part modelled and rendered in 3D, like a real machine"),
                LabStat(label: "Sounds", value: "39 effects and a looping drone for the finale"),
                LabStat(label: "Code", value: "About 6,100 lines in 23 files"),
                LabStat(label: "Testing", value: "Shot Lab and Sling Lab robots, plus a game simulator"),
            ]
        case .monsoon:
            // Polish round 2 (T4 M11 v3): the finished table's numbers.
            return [
                LabStat(label: "Table size", value: "600 × 1300 points, the same as Tables 02 and 03"),
                LabStat(label: "Camera", value: "Flies with the ball, a Wide view, or Top-Down"),
                LabStat(label: "Frame rate", value: "120 fps on ProMotion iPhones, even in the storm"),
                LabStat(label: "Goal", value: "Paint the desert, call the Monsoon, reach the Superbloom"),
                LabStat(label: "Art", value: "A watercolor that starts as a pencil sketch, with parts rendered in 3D"),
                LabStat(label: "Sounds", value: "36 effects and a four-layer storm that follows the game"),
                LabStat(label: "Code", value: "About 6,500 lines in 21 files"),
                LabStat(label: "Testing", value: "Shot Lab robot and a game simulator"),
            ]
        case .lamplight:
            // T5 M1: the plan's numbers, filled in as the table is built.
            return [
                LabStat(label: "Table size", value: "600 × 1300 points, plus a loft upstairs"),
                LabStat(label: "Camera", value: "Flies with the ball, a Wide view, or Top-Down"),
                LabStat(label: "Frame rate", value: "Aiming for 120 fps on ProMotion iPhones"),
                LabStat(label: "Goal", value: "Nothing to beat: fill the shelves and furnish the shop"),
                LabStat(label: "Art", value: "Being made"),
                LabStat(label: "Sounds", value: "Being made"),
                LabStat(label: "Code", value: "Being written"),
                LabStat(label: "Testing", value: "Shot Lab robot and a game simulator, as before"),
            ]
        }
    }

    /// What the table added. For the first table, what it started with.
    var newThings: [LabNote] {
        switch self {
        case .orbit:
            return [
                LabNote(title: "Flippers and a plunger", detail: "Touch the left or right half of the screen to flip; pull the plunger to launch."),
                LabNote(title: "Bumpers and slingshots", detail: "Three planet bumpers and two slingshots keep the ball moving."),
                LabNote(title: "Lanes and drop targets", detail: "Light all three top lanes to raise the multiplier; knock down all four asteroids for a bank bonus."),
                LabNote(title: "The wormhole", detail: "Swallows the ball, holds it for a moment, then fires it back into play."),
                LabNote(title: "Skill shot and ball save", detail: "A bonus for a well-judged launch, and a free ball if you drain straight away."),
            ]
        case .greyInvasion:
            return [
                LabNote(title: "A table bigger than the screen", detail: "Two ramps, an orbit lane, the Hangar and Abduction holes, and a camera that flies with the ball."),
                LabNote(title: "A story to play through", detail: "Three waves of saucers, shields to knock down, and a Mothership to destroy."),
                LabNote(title: "Multiball", detail: "Lock balls in the Abduction hole to start a multiball; the camera eases out to show the whole table."),
                LabNote(title: "Original art", detail: "The playfield, ball, saucers, Mothership and cow are all drawn by code written for this table."),
                LabNote(title: "Readable at any zoom", detail: "Table names are live labels that grow as the camera pulls back."),
                LabNote(title: "Settings and How to Play", detail: "Camera, volume, haptics and tips, and a guide to every part of the table."),
                LabNote(title: "The Shot Lab", detail: "A robot player that fires thousands of shots to measure how hard each one really is."),
            ]
        case .cthulhu:
            return [
                LabNote(title: "Four new toys", detail: "A spinner, a magnet, a vertical up-kicker with its brass wire, and Cthulhu himself, swaying as a moving target."),
                LabNote(title: "Art like a real table", detail: "Every part modelled and rendered in 3D with chrome, gloss and shadows. The ramp is clear plastic, and the ball climbs it."),
                LabNote(title: "A story in three acts", detail: "Research three tomes, light five candles in the Ritual multiball, then cut tentacles and strike the eye in a three-ball finale."),
                LabNote(title: "Real pinball parts", detail: "One-way gates, rubber-lined guides, a kickback and an Elder Sign ball save, where Grey Invasion had plain lines."),
                LabNote(title: "Its own sounds", detail: "Bells, gongs, a chant and Cthulhu's roar made in code for this table, and a drone under the finale."),
                LabNote(title: "Robot-tested from the start", detail: "Every shot is measured on the grey box, before the art is drawn."),
            ]
        case .monsoon:
            return [
                LabNote(title: "Color as progress", detail: "The table starts as a pencil sketch. Every goal lays a wash of watercolor that spreads from the shot you made, and no two games paint it the same way."),
                LabNote(title: "Wire habitrails", detail: "Wires that cross over each other at different heights, a gate that picks the route, and a corkscrew helix."),
                LabNote(title: "Two new toys", detail: "A captive ball you knock up its own channel, and a spinning dust devil that bends the ball's path."),
                LabNote(title: "A storm that builds", detail: "Wind and cicadas give way to thunder as you paint; Monsoon brings rain and lightning over the sky, and birds come out for the Superbloom."),
                LabNote(title: "Parts that color in", detail: "The storm-cloud bumpers and saguaro targets start in pencil and take on color with their part of the painting."),
            ]
        case .lamplight:
            return [
                LabNote(title: "A new lower table", detail: "A rubber center post between the flippers and only one outlane, where every earlier table had two."),
                LabNote(title: "Cozy pinball", detail: "No villain and no game over to fear: every game adds books to the shelves and furniture to the shop, and it all stays."),
                LabNote(title: "Collections", detail: "Books from common to ultra rare, furniture, teas and regulars, each one kept in a collection book."),
            ]
        }
    }

    /// What building it taught us.
    var lessons: [LabNote] {
        switch self {
        case .orbit:
            return [
                LabNote(title: "Start small", detail: "One screen and a few toys was enough to get the flippers and ball feeling right."),
                LabNote(title: "Feel comes first", detail: "Flipper speed, ball weight and bounce took more tuning than any rule."),
            ]
        case .greyInvasion:
            return [
                LabNote(title: "Measure, don't guess", detail: "The Hangar felt hard. The Shot Lab showed it was hit only about 7% of the time from a caught ball; moving it lifted that to about 65%."),
                LabNote(title: "Smooth sound matters", detail: "Playing sounds the simple way caused stutters; preloading them fixed the lag."),
                LabNote(title: "Physics depend on the frame rate", detail: "The same shot can land differently at 60 and 120 fps, so shots are tested at the speed you play."),
                LabNote(title: "Playtests set the rules", detail: "Two scouts per wave and shields that drop from the orbit, Hangar and Abduction shots both came from testing."),
            ]
        case .cthulhu:
            return [
                LabNote(title: "Reuse what works", detail: "Starting from Grey Invasion's proven parts made the first playable build one step instead of four."),
                LabNote(title: "Simulate the whole game", detail: "Under the first rules, a game simulator found only about 4% of average players would banish Cthulhu. Fewer clues, a longer Necronomicon and one-hit tentacles lifted that to about 43%."),
                LabNote(title: "Test the slingshots too", detail: "A robot threw 640 balls at four slingshot designs. The original was already the best, so it stayed."),
                LabNote(title: "Judge it at phone size", detail: "A dropped target looked fine in a close-up but read as still standing on the phone, so it became an empty slot."),
                LabNote(title: "Make it look like pinball", detail: "Playtests turned plain lines into one-way gates, rubber guides and a real ramp the ball can't fall through."),
            ]
        case .monsoon:
            return [
                LabNote(title: "Started from a painting", detail: "The whole table grows out of one watercolor of a desert storm."),
                LabNote(title: "Check effects on the phone", detail: "The sketch-to-color shader failed silently from the first build and just showed the color art. One console line gave it away; now every new shader gets checked on the device first."),
                LabNote(title: "Paint should follow the rules", detail: "At first the picture filled in long before the storm came. Each wash is now measured on the painting itself, so the color always matches your progress."),
                LabNote(title: "A toy can steer the game", detail: "The Shot Lab found the dust devil was bending shots into the arroyo. Halving its pull brought the ramp back."),
                LabNote(title: "Contrast on paper", detail: "Chrome wires and lamps disappeared on the light painting, so they got dark ink outlines and sockets."),
            ]
        case .lamplight:
            return [
                LabNote(title: "Change the layout", detail: "Tables 02 to 04 shared a lower table and kept the drop targets and upper flipper in the same places; this one starts from a new lower table."),
            ]
        }
    }
}

// MARK: - How it evolved

struct LabTableStoryView: View {
    let table: LabTable
    let onPlay: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    section("AT A GLANCE") { glance }
                    section(table.previous.map { "NEW SINCE TABLE \(String(format: "%02d", $0.number))" } ?? "WHERE IT STARTED") {
                        notes(table.newThings)
                    }
                    section("WHAT WE LEARNED") { notes(table.lessons) }
                    Button {
                        dismiss()
                        onPlay()
                    } label: {
                        Text("PLAY \(table.title.uppercased()) ›")
                            .font(.orbitron(15, .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(table.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(LabHomeView.background.ignoresSafeArea())
            .navigationTitle("How it evolved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            LabThumbnail(table: table, width: 110, height: 196)
            VStack(alignment: .leading, spacing: 6) {
                Text("TABLE \(String(format: "%02d", table.number))")
                    .font(.orbitron(12, .bold))
                    .tracking(2)
                    .foregroundStyle(table.accent)
                Text(table.title)
                    .font(.orbitron(22, .black))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(table.built)
                    .font(.system(.caption))
                    .foregroundStyle(.white.opacity(0.55))
                Text(table.blurb)
                    .font(.system(.subheadline))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    /// Each stat, with the previous table's value underneath when there is one.
    private var glance: some View {
        let before = table.previous?.stats ?? []
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(table.stats) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.label.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(stat.value)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let old = before.first(where: { $0.label == stat.label }), let prev = table.previous {
                        Text("\(prev.title): \(old.value)")
                            .font(.system(.caption))
                            .foregroundStyle(prev.accent.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func notes(_ list: [LabNote]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(list) { note in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(table.accent)
                        .frame(width: 7, height: 7)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text(note.detail)
                            .font(.system(.subheadline))
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.orbitron(13, .bold))
                .tracking(2)
                .foregroundStyle(table.accent)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A table's picture (or a numbered placeholder), used on the home cards and the story page.
struct LabThumbnail: View {
    let table: LabTable
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        if let name = table.thumbnail, let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(shape)
                .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 1))
        } else {
            shape
                .fill(LinearGradient(colors: [table.accent.opacity(0.5), .black],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: height)
                .overlay(Text("\(table.number)").font(.orbitron(34, .black)).foregroundStyle(.white.opacity(0.8)))
        }
    }
}

// MARK: - Shared credits

struct LabCreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Pinball Lab") {
                    Text("Made by Aaron Tilley, built with Claude, in Swift, SwiftUI and SpriteKit.")
                    credit("App icon", "Drawn for Pinball Lab", "Original")
                    credit("Orbitron font", "Matt McInerney, The Orbitron Project Authors (Google Fonts)",
                           "SIL Open Font License 1.1")
                }
                Section("Table 01 · Orbit Pinball") {
                    credit("Planets", "Kenney · kenney.nl", "CC0 1.0 (public domain)")
                    credit("Space Shooter Remastered", "Kenney · kenney.nl",
                           "CC0 1.0 (public domain): asteroids, wormhole ring, stars")
                    credit("Sci-fi Sounds and Impact Sounds", "Kenney · kenney.nl", "CC0 1.0 (public domain)")
                }
                Section("Table 02 · Grey Invasion") {
                    credit("Playfield, ball, saucers, Mothership, cow", "Drawn for this table", "Original")
                    credit("Sci-fi Sounds and Impact Sounds", "Kenney · kenney.nl",
                           "CC0 1.0 (public domain), edited and levelled for the table")
                }
                Section("Table 03 · Cthulhu Rising") {
                    credit("Table art", "Modelled and rendered in Blender for this table", "Original")
                    credit("Cinzel font (in the table art)", "The Cinzel Project Authors", "SIL Open Font License 1.1")
                    credit("Bells, gongs, chants, Cthulhu's roar", "Synthesized for this table", "Original")
                    credit("Impact Sounds (flippers, bumpers, targets, holes)", "Kenney · kenney.nl",
                           "CC0 1.0 (public domain), edited and levelled for the table")
                }
                Section("Table 04 · Monsoon") {
                    credit("Desert storm watercolor (the playfield painting and the card)",
                           "Made with ChatGPT from Aaron Tilley's description", "Original")
                    credit("Table art and parts", "Modelled and rendered in Blender for this table, with a watercolor and pencil pass",
                           "Original")
                    credit("Cinzel font (in the apron art)", "The Cinzel Project Authors", "SIL Open Font License 1.1")
                    credit("Thunder, rain, brush washes, desert chimes, sand, the helix whir", "Synthesized for this table", "Original")
                    credit("Impact Sounds (flippers, slings, targets, holes, gates)", "Kenney · kenney.nl",
                           "CC0 1.0 (public domain), edited and levelled for the table")
                }
                Section("Table 05 · The Lamplight") {
                    credit("Table art (the shop floor, rug, fireplace, loft, cabinet and rails)",
                           "Painted and rendered in Blender for this table", "Original")
                }
                Section {
                    Text("Thanks to Kenney for the free game assets.")
                        .foregroundStyle(.secondary)
                    Text("Version \(Self.appVersion)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Credits")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func credit(_ title: String, _ author: String, _ license: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(author).font(.subheadline)
            Text(license).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared settings

/// Sound and haptics for every table (Orbit has no settings screen of its own). Same saved values
/// as Grey Invasion's Settings, so a change in either place shows up in both.
struct LabSettingsView: View {
    @State private var settings = GameSettings()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("All tables") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sound volume: \(Int((settings.soundVolume * 100).rounded()))%")
                        Slider(value: $settings.soundVolume, in: 0...1, step: 0.1)
                    }
                    Toggle("Haptics", isOn: $settings.hapticsOn)
                }
                Section {
                    Text("Grey Invasion's camera, tips and bonus settings are in its own Settings menu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
