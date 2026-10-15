import SwiftUI
import UIKit

/// Table 03's How to Play (polish round 1): Grey Invasion's How to Play screen (HowToPlay.swift) with Cthulhu
/// Rising's map and rules. Opens from the menu and the pause card. A numbered map of the table, then the three
/// acts (Research, the Ritual, the Awakening), ways to save a ball and scoring tips. Every number here comes from
/// CthCampaign.swift / CthTableLayout / CthGameState; update this screen if a rule changes.
struct CthHowToPlayView: View {
    let onClose: () -> Void

    private static let green = Color(red: 0.30, green: 0.85, blue: 0.75)       // the table's sea-green
    private static let yellow = Color(red: 1.0, green: 0.72, blue: 0.32)       // candle gold

    /// A numbered spot on the map: world position (CthTableLayout points) and what it is.
    private struct Spot: Identifiable {
        let id: Int
        let at: CGPoint
        let name: String
        let what: String
    }

    private static let spots: [Spot] = [
        Spot(id: 1, at: CGPoint(x: 284, y: 195), name: "Flippers",
             what: "Touch the left or right half of the screen. The right side also works the small upper flipper."),
        Spot(id: 2, at: CGPoint(x: 564, y: 60), name: "Plunger",
             what: "Pull down in the bottom-right corner and let go. A quick tap gives a medium launch."),
        Spot(id: 3, at: CGPoint(x: 115, y: 385), name: "Slingshots",
             what: "Kick the ball back into play above each flipper."),
        Spot(id: 4, at: CGPoint(x: 274, y: 1158), name: "Candle lanes",
             what: "Light all three candles for +1 multiplier (up to 5X). Each flipper press moves the lit candles."),
        Spot(id: 5, at: CGPoint(x: 274, y: 1005), name: "Pop bumpers",
             what: "Three bumpers under the Candle lanes."),
        Spot(id: 6, at: CGPoint(x: 39, y: 935), name: "Orbit and spinner",
             what: "The lane up the left side and round the top. Shoot it from the right flipper. Its spinner turns the Necronomicon's pages."),
        Spot(id: 7, at: CGPoint(x: 430, y: 760), name: "Ramp",
             what: "The plastic ramp. Shoot it from the left flipper; its wire brings the ball back to the right inlane."),
        Spot(id: 8, at: CGPoint(x: 300, y: 668), name: "Library",
             what: "The centre hole. When it's lit it opens the next tome, and later the Ritual."),
        Spot(id: 9, at: CGPoint(x: 124, y: 800), name: "Brass wire",
             what: "Every ball the Library catches is kicked up this wire and dropped into the left inlane."),
        Spot(id: 10, at: CGPoint(x: 505, y: 1060), name: "Lagoon",
             what: "The top-right hole, from the upper or right flipper. Cthulhu rises here in the Awakening."),
        Spot(id: 11, at: CGPoint(x: 464, y: 550), name: "Sigil bank",
             what: "Four drop targets. Knock them all down to light the kickback."),
        Spot(id: 12, at: CGPoint(x: 505, y: 790), name: "Upper flipper",
             what: "Moves with the right flipper. Good for the Lagoon."),
        Spot(id: 13, at: CGPoint(x: 284, y: 470), name: "Ritual circle",
             what: "Its five candles show the Ritual. The magnet at its centre wakes in the Awakening."),
        Spot(id: 14, at: CGPoint(x: 37, y: 300), name: "Kickback",
             what: "When lit, fires a ball back up the left outlane. Relight it at the Sigil bank."),
        Spot(id: 15, at: CGPoint(x: 531, y: 300), name: "Outlane save",
             what: "Finishing a tome lights it. One ball down the right outlane comes back."),
        Spot(id: 16, at: CGPoint(x: 284, y: 312), name: "Elder Sign",
             what: "Ball save: on for 10 seconds after each launch, blinking as it runs out."),
        Spot(id: 17, at: CGPoint(x: 284, y: 598), name: "Tomes",
             what: "One lamp per tome: lit when it's read, blinking for the one that's next."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                HStack {
                    Text("How to Play")
                        .font(.orbitron(24, .black))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intro
                        section("THE TABLE") {
                            tableMap
                            ForEach(Self.spots) { spot in
                                HStack(alignment: .top, spacing: 10) {
                                    badge(spot.id)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(spot.name).font(.orbitron(14, .bold))
                                        para(spot.what)
                                    }
                                }
                            }
                        }
                        section("ACT 1 · RESEARCH") {
                            para("Three forbidden tomes stand between you and the Ritual. Each one is opened at the Library.")
                            step(1, "Find two clues",
                                 "Make the ramp, the orbit or the Lagoon, finish all three Candle lanes, or clear the Sigil bank. Each is a clue; two light the Library.")
                            step(2, "Open a tome",
                                 "Shoot the lit Library. The status line under the score always says what to hit next.")
                            step(3, "Tome I · Necronomicon",
                                 "Turn 40 pages in 50 seconds. Every spin of the orbit's spinner turns a page; every ramp turns 10.")
                            step(4, "Tome II · Pnakotic Manuscripts",
                                 "Two shots light up. Hit both within 30 seconds.")
                            step(5, "Tome III · Sea Captain's Log",
                                 "Break the four seals (clear the Sigil bank), then shoot the ramp. No time limit.")
                            para("Each tome pays 25,000 × its number, plus a mystery award: the kickback, +1X or 50,000. It also lights the outlane save. If a tome's time runs out, the Library relights and you carry on where you left off. After each tome, find two more clues for the next.")
                        }
                        section("ACT 2 · THE RITUAL") {
                            para("With all three tomes read, the Library lights for the Ritual. Shoot it to start a 2-ball multiball: a second ball fires up the brass wire, and for 10 seconds any drained ball comes back.")
                            step(1, "Light the five candles",
                                 "Each candle is one shot: the orbit, the ramp, the Library, the Lagoon and a Sigil target. Their arrows blink until they're lit. 10,000 each.")
                            step(2, "The Summoning",
                                 "The fifth candle pays 100,000, and Cthulhu rises.")
                            para("If you're down to one ball first, the Ritual falters. The candles you lit stay lit, and the Library relights the Ritual.")
                        }
                        section("ACT 3 · THE AWAKENING") {
                            para("Cthulhu rises out of the Lagoon and sways from side to side. Balls fire out of the Library until three are in play, and for 25 seconds any drained ball comes back. The magnet in the ritual circle wakes too: it grabs a passing ball and flings it.")
                            step(1, "Cut his tentacles",
                                 "Hit Cthulhu, or shoot the ramp or the orbit, to cut a tentacle: 30,000 each. Four to cut.")
                            step(2, "Strike the eye",
                                 "With every tentacle cut, his eye opens. Hit Cthulhu himself three times, 250,000 each.")
                            step(3, "Banish him",
                                 "The third eye hit banishes him for 1,000,000. Research starts again with every award doubled (then tripled, and so on).")
                            para("If you're down to one ball first, he sinks back into the Lagoon. Your eye hits are kept and the candles stay lit: shoot the Library to summon him again (his tentacles grow back).")
                        }
                        section("SAVING YOUR BALL") {
                            tip("Elder Sign", "For 10 seconds after each launch, a drained ball comes back.")
                            tip("Kickback", "Lit by the Sigil bank. Fires a ball back out of the left outlane once.")
                            tip("Outlane save", "Lit by finishing a tome. Brings back one ball from the right outlane, on that ball.")
                            tip("Multiball saves", "10 seconds at the start of the Ritual, 25 at the start of the Awakening.")
                        }
                        section("SCORING TIPS") {
                            tip("Multiplier", "Every set of Candle lanes adds 1X, up to 5X. It multiplies everything until you lose the ball.")
                            tip("Skill shot", "A ring circles one candle at each launch. Roll through that lane within 5 seconds for 10,000.")
                            tip("Spinner", "100 a spin, 500 while the Necronomicon is open.")
                            tip("Bonus", "Each lost ball pays 1,000 per shot made and 20 per spin, times your multiplier.")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 420)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 12)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Pieces

    private var intro: some View {
        para("Read the forbidden tomes, perform the Ritual, then fight Cthulhu himself as he rises from the Lagoon. Your progress carries over from ball to ball.")
    }

    /// The whole table (cth_howto_map.png, tools/cth_howto_map.py: the rendered table with every part and Cthulhu
    /// risen) with a numbered badge on each part. The picture covers world (-40,-75)–(640,1330).
    private var tableMap: some View {
        let world = CGRect(x: -40, y: -75, width: 680, height: 1405)
        return Group {
            if let art = UIImage(named: "cth_howto_map") {
                Image(uiImage: art)
                    .resizable()
                    .aspectRatio(world.width / world.height, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            ForEach(Self.spots) { spot in
                                badge(spot.id)
                                    .position(x: (spot.at.x - world.minX) / world.width * geo.size.width,
                                              y: (world.maxY - spot.at.y) / world.height * geo.size.height)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.orbitron(15, .bold))
                .tracking(2)
                .foregroundStyle(Self.green)
            content()
        }
    }

    private func para(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline))
            .foregroundStyle(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func badge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .frame(width: 20, height: 20)
            .background(Self.yellow, in: Circle())
            .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1))
    }

    private func step(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.orbitron(13, .black))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(Self.green, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.orbitron(14, .bold))
                para(text)
            }
        }
    }

    private func tip(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.orbitron(13, .bold)).foregroundStyle(Self.yellow)
            para(text)
        }
    }
}
