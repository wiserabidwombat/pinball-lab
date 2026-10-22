import SwiftUI
import UIKit

/// How to Play (M10 v11, Aaron: "add a how to that explains what all the elements are and how you
/// play through and defeat the mothership"). Opens from the menu and the pause card.
/// 2026-10-20 (Aaron's testers: "Light the hangar: show the table with the three lanes highlighted"): every goal now has
/// a picture of the table with that goal's lamps lit and the shot drawn on (tools/art_howto_goals.py → howto_goal_*).
/// A numbered map of the table, then the controls, the invasion wave by wave, the Mothership,
/// ways to save a ball and scoring tips. Every number here comes from Campaign.swift / TableLayout.
struct HowToPlayView: View {
    let onClose: () -> Void

    private static let green = Color(red: 0.35, green: 0.95, blue: 0.55)
    private static let yellow = Color(red: 1.0, green: 0.85, blue: 0.3)

    /// A numbered spot on the map: world position (TableLayout points) and what it is.
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
        Spot(id: 3, at: CGPoint(x: 110, y: 385), name: "Slingshots",
             what: "Kick the ball back into play above each flipper."),
        Spot(id: 4, at: CGPoint(x: 274, y: 1000), name: "Saucer bumpers",
             what: "Three bumpers at the top. In the Mothership fight they're its shield generators."),
        Spot(id: 5, at: CGPoint(x: 274, y: 1158), name: "U-F-O lanes",
             what: "Light all three for +1 multiplier (up to 5X). Each flipper press moves the lit lanes."),
        Spot(id: 6, at: CGPoint(x: 39, y: 900), name: "Orbit",
             what: "The lane up the left side and round the top. Shoot it from the right flipper."),
        Spot(id: 7, at: CGPoint(x: 228, y: 630), name: "Defense Cannon ramp",
             what: "The left ramp. Shoot it from the right flipper."),
        Spot(id: 8, at: CGPoint(x: 360, y: 630), name: "Tractor Beam ramp",
             what: "The right ramp. Shoot it from the left flipper. Worth a jackpot in multiball, and it saves cows in Wave 3."),
        Spot(id: 9, at: CGPoint(x: 244, y: 658), name: "Hangar",
             what: "The centre hole. When it's lit, shoot it to start the next wave."),
        Spot(id: 10, at: CGPoint(x: 502, y: 688), name: "Abduction scoop",
             what: "Lock 3 balls here for multiball. In Wave 3 it saves cows instead (so does the Tractor Beam)."),
        Spot(id: 11, at: CGPoint(x: 464, y: 550), name: "Fighter bank",
             what: "Four drop targets. Knock them all down to light the kickback."),
        Spot(id: 12, at: CGPoint(x: 505, y: 790), name: "Upper flipper",
             what: "Moves with the right flipper. Good for the Hangar and the lanes."),
        Spot(id: 13, at: CGPoint(x: 37, y: 262), name: "Kickback",
             what: "When lit, fires a ball back up the left outlane. Relight it at the fighter bank."),
        Spot(id: 14, at: CGPoint(x: 531, y: 262), name: "Outlane save",
             what: "Clearing a wave lights it. One ball down the right outlane comes back."),
        Spot(id: 15, at: CGPoint(x: 205, y: 455), name: "Earth Defense",
             what: "One lamp per wave: lit when cleared, blinking for the wave you're on."),
        Spot(id: 16, at: CGPoint(x: 380, y: 410), name: "Ships Down",
             what: "Lights up for every ship you shoot down this ball."),
        Spot(id: 17, at: CGPoint(x: 284, y: 300), name: "Shields Up",
             what: "Ball save: on for 10 seconds after each launch, blinking as it runs out."),
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
                        section("THE INVASION") {
                            para("Earth faces three waves of invaders, then the Mothership. Your progress carries over from ball to ball.")
                            step(1, "Light the Hangar",
                                 "Light all three U-F-O lanes, or make 3 ramp shots. The Hangar arrow starts blinking.")
                            picture("howto_goal_lanes", "All three U-F-O lanes lit: roll the ball through each lane at the top.")
                            step(2, "Shoot the Hangar",
                                 "A lit Hangar starts the next wave. The status line under the score always says what to hit.")
                            picture("howto_goal_hangar", "The Hangar arrow lit: shoot straight up the middle.")
                            step(3, "Wave 1 · Scout Saucers",
                                 "Two shots light up with a scout over each. Hit both within 30 seconds; the faster you are, the more each one is worth. If time runs out the scouts escape, and the Hangar stays lit so you can try again.")
                            picture("howto_goal_wave1", "Two shots lit, a scout over each: here the Tractor Beam ramp (1) and the orbit (2).")
                            step(4, "Wave 2 · Fighter Squadron",
                                 "Knock down all four fighters in the bank, then shoot the Defense Cannon (left ramp). No time limit. Clearing it lights an Extra Ball at the Hangar, once per game.")
                            picture("howto_goal_wave2a", "First the fighter bank: knock down all four.")
                            picture("howto_goal_wave2b", "Then the Defense Cannon: the left ramp, from the right flipper.")
                            step(5, "Wave 3 · Abductors",
                                 "A saucer beams up a cow over the Abduction scoop. Shoot the scoop or the Tractor Beam (right ramp) before the beam finishes (20 seconds) to save it. Save 3 cows to clear the wave.")
                            picture("howto_goal_wave3", "A cow in the beam over the Abduction scoop: shoot the scoop or the Tractor Beam before it's gone.")
                            step(6, "Wave 4 · The Mothership",
                                 "Light the Hangar again and shoot it to bring in the Mothership.")
                        }
                        section("DEFEAT THE MOTHERSHIP") {
                            para("Shooting the Hangar starts a 2-ball multiball. For the first 15 seconds any drained ball comes straight back.")
                            step(1, "Knock out the shields",
                                 "The three saucer bumpers are its shield generators, each good for 3 hits. Bump them, or shoot the orbit, Hangar or Abduction scoop (their arrows blink) to knock out a hit on the strongest one. The status line counts the hits left on each.")
                            picture("howto_goal_shields", "The Mothership overhead: its three shield generators are the saucer bumpers.")
                            step(2, "Hit the core",
                                 "With every shield down, the core opens and glows green. Shoot either ramp for a core hit worth 250,000. The shields then come back up.")
                            picture("howto_goal_core", "The core open and glowing green: shoot either ramp.")
                            step(3, "Do it three times",
                                 "The third core hit destroys the Mothership for 1,000,000. The next invasion starts at Wave 1 with every wave and Mothership award doubled (then tripled, and so on).")
                            para("If you're down to one ball first, the Mothership escapes. Your core hits are kept, and the Hangar relights so you can call it back.")
                        }
                        section("SAVING YOUR BALL") {
                            tip("Shields Up", "For 10 seconds after each launch, a drained ball comes back.")
                            tip("Kickback", "Lit by the fighter bank. Fires a ball back out of the left outlane once.")
                            picture("howto_goal_kickback", "The kickback lamp lit: a ball down the left outlane (1) is fired back up (2).")
                            tip("Outlane save", "Lit by clearing a wave. Brings back one ball from the right outlane.")
                            tip("Extra Ball", "Lit at the Hangar after Wave 2.")
                        }
                        section("SCORING TIPS") {
                            tip("Multiplier", "Every set of U-F-O lanes adds 1X, up to 5X. It multiplies everything until you lose the ball.")
                            tip("Skill shot", "A ring marks one U-F-O lane at each launch. Roll through it within 5 seconds for 10,000.")
                            tip("Combos", "Make a ramp or the orbit within 3 seconds of the last one for double points.")
                            tip("Multiball", "Lock 3 balls in the Abduction scoop (its three green lamps count them) for Abduction multiball.")
                            picture("howto_goal_lock", "Two of the three lock lamps lit: one more ball in the scoop starts multiball.")
                            tip("Multiball jackpot", "In Abduction multiball, the Tractor Beam ramp is worth +50,000.")
                            tip("Bonus", "Each lost ball pays 1,000 per ship down and 500 per ramp, times your multiplier.")
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
        para("Defend Earth from the grey invasion! Shoot the Hangar to start each wave of invaders, clear all three, then bring down the Mothership.")
    }

    /// The whole table (howto_map.png, drawn by tools/art_howto_map.py with every part on it) with a
    /// numbered badge on each part. The picture covers world (-40,-75)–(640,1330).
    private var tableMap: some View {
        let world = CGRect(x: -40, y: -75, width: 680, height: 1405)
        return Group {
            if let art = UIImage(named: "howto_map") {
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

    /// One goal as it looks on the table, with a caption under it.
    private func picture(_ name: String, _ caption: String) -> some View {
        VStack(spacing: 6) {
            if let art = UIImage(named: name) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 440)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Self.green.opacity(0.35), lineWidth: 1))
            }
            Text(caption)
                .font(.system(.caption))
                .italic()
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
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
