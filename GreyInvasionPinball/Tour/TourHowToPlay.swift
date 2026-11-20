import SwiftUI
import UIKit

/// Table 06's How to Play (M10 r2; goal pictures r3): Monsoon's How to Play screen with the Grand Tour's map and rules. Opens from the
/// menu and the pause card. A numbered map of the table (tour_howto_map.png: a TOP-camera capture of the game with
/// `-tourCleanShot`), then liftoff, the nine stops, Pluto, ways to save a ball and scoring tips. Every number here comes
/// from TourModes / TourPoints / TourTableScene / TourTableLayout; update this screen if a rule changes.
struct TourHowToPlayView: View {
    let onClose: () -> Void

    private static let gold = Color(red: 1.0, green: 0.74, blue: 0.32)      // the Sun's gold (headings)
    private static let cyan = Color(red: 0.55, green: 0.90, blue: 1.0)      // map badges, tips

    /// A numbered spot on the map: world position (TourTableLayout points) and what it is.
    private struct Spot: Identifiable {
        let id: Int
        let at: CGPoint
        let name: String
        let what: String
    }

    private static let spots: [Spot] = [
        Spot(id: 1, at: CGPoint(x: 284, y: 222), name: "Flippers",
             what: "Touch the left or right half of the screen. Each press also moves the lit O-R-B-T and S-T-A-R lanes along."),
        Spot(id: 2, at: CGPoint(x: 561, y: 110), name: "Plunger",
             what: "Pull down in the bottom-right corner and let go. A strong launch drops into the S-T-A-R lanes."),
        Spot(id: 3, at: CGPoint(x: 60, y: 420), name: "O-R-B-T lanes",
             what: "The inlanes and outlanes. Light all four for 5,000, +1X multiplier (up to 6X) and the rocket post."),
        Spot(id: 4, at: CGPoint(x: 284, y: 900), name: "Blast door and Mission Control",
             what: "Hit the door to count down to liftoff. Once the rocket has gone, shoot the open bay to start the next stop on the tour."),
        Spot(id: 5, at: CGPoint(x: 284, y: 536), name: "Countdown",
             what: "One lamp goes out with each blast-door hit. Five for the first liftoff, then one more each time (up to nine)."),
        Spot(id: 6, at: CGPoint(x: 200, y: 770), name: "Moon ramp",
             what: "A right-flipper shot up to the Moon (7,500). The ball rests in the Moon's crater, then rides the wire to the left inlane."),
        Spot(id: 7, at: CGPoint(x: 420, y: 712), name: "Saturn ramp",
             what: "A left-flipper shot round Saturn (7,500), back down to the right inlane. The hardest shot on the table."),
        Spot(id: 8, at: CGPoint(x: 58, y: 880), name: "Left orbit",
             what: "Up the left side and round the top, from the right flipper (5,000). Its spinner pays 20 a spin."),
        Spot(id: 9, at: CGPoint(x: 512, y: 760), name: "Right orbit",
             what: "Up the right side, from the left flipper (5,000), through the second spinner."),
        Spot(id: 10, at: CGPoint(x: 72, y: 633), name: "R-O-C standups",
             what: "Half of R-O-C-K-E-T, from the right flipper."),
        Spot(id: 11, at: CGPoint(x: 390, y: 963), name: "K-E-T standups",
             what: "The other half, from the left flipper. All six letters: 10,000, and the first time each game lights an extra ball."),
        Spot(id: 12, at: CGPoint(x: 502, y: 548), name: "Sample targets",
             what: "Drop all three (3,000) to open the rover."),
        Spot(id: 13, at: CGPoint(x: 532, y: 515), name: "Rover",
             what: "Brings the samples home for 15,000 once they're down, and collects the extra ball when it's lit."),
        Spot(id: 14, at: CGPoint(x: 286, y: 1178), name: "S-T-A-R lanes",
             what: "Light all four for 5,000. The Sun at the top brightens with each letter and flares when they're done."),
        Spot(id: 15, at: CGPoint(x: 286, y: 1062), name: "Bumpers",
             what: "100 a hit. Neptune Deep needs ten of them."),
        Spot(id: 16, at: CGPoint(x: 284, y: 654), name: "Shot arrows",
             what: "Blink for the shots the running stop wants. The three lamps behind each fill gold, red and blue at 1, 3 and 5 makes."),
        Spot(id: 17, at: CGPoint(x: 159, y: 351), name: "Planet arc",
             what: "One lamp per stop, Mercury to the Sun: lit when visited, blinking for the next stop."),
        Spot(id: 18, at: CGPoint(x: 284, y: 350), name: "Planet window",
             what: "A window down into space. It flies to each stop and shows what's happening there."),
        Spot(id: 19, at: CGPoint(x: 37, y: 300), name: "Kickback",
             what: "Lit at the start of every ball. Fires one ball back up the left outlane."),
        Spot(id: 20, at: CGPoint(x: 284, y: 162), name: "Rocket post",
             what: "Pops up between the flippers when you complete O-R-B-T and saves one ball."),
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
                        section("LIFTOFF") {
                            step(1, "Count down", "Hit the blast door in front of the rocket. Each hit is 500 and puts out a countdown lamp.")
                            picture("tour_goal_liftoff", "Shoot the blast door (1) from either flipper. Each hit puts out a countdown lamp (2); the rocket's arrow blinks while the door is up.")
                            step(2, "Liftoff", "The last hit launches the rocket (5,000). Play holds while it climbs, then carries on exactly where it was.")
                            step(3, "Mission Control", "The door is down and the bay is open: shoot it (10,000) to start the next stop on the tour.")
                            picture("tour_goal_mission", "After liftoff the door is down and the rocket arrow blinks fast: shoot into the open bay (1).")
                        }
                        section("THE GRAND TOUR") {
                            para("Each stop is a timed mode. Its clock starts when the ball comes out of Mission Control, and you get a 6-second ball save at the start. Every step pays 25,000; finishing a stop pays 250,000 and lights its planet. Run out of time or lose the ball and the stop waits for the next Mission Control.")
                            step(1, "Mercury Dash · 30 s", "One shot is lit on each side. Make both.")
                            picture("tour_goal_mercury", "Mercury Dash: one lit arrow on each side, here the Moon ramp (1) and the Saturn ramp (2). The planet window shows Mercury in the Sun's glare.")
                            step(2, "Venus Veil · 40 s", "Three shots are hidden under the clouds. Each R-O-C-K-E-T hit reveals one; make the three you uncover.")
                            picture("tour_goal_venus", "Venus Veil: hit any R-O-C-K-E-T standup (1) to clear the clouds off a shot, then make it (2).")
                            step(3, "Mars Recon · 45 s", "Drop all three sample targets, then shoot the rover.")
                            picture("tour_goal_mars", "Mars Recon: drop the three sample targets (1), then shoot the rover hole (2). Dust blows across Mars in the window.")
                            step(4, "Moonshot · 45 s to lock", "Shoot the Moon ramp to lock a ball, then again to start a 2-ball multiball. The Moon and Saturn ramps are jackpots (150,000, then 50,000 more each); the first one visits the Moon.")
                            picture("tour_goal_moonshot", "Moonshot: the Moon ramp (1) from the right flipper, twice to lock, then any ramp for the jackpots.")
                            step(5, "Jupiter Storm · 40 s", "Spin the spinners 40 times to build the storm, then shoot either ramp.")
                            picture("tour_goal_jupiter", "Jupiter Storm: the orbits (1) drive both spinners (blue rings) and wind up the storm in the window; then either ramp (2).")
                            step(6, "Ring Runner · 45 s", "Three Saturn ramps, each within 8 seconds of the last.")
                            picture("tour_goal_ringrunner", "Ring Runner: the Saturn ramp (1) from the left flipper, three times in quick succession.")
                            step(7, "Uranus Roll · 40 s", "Five lit shots, the lit side swapping after each one.")
                            picture("tour_goal_uranus", "Uranus Roll: here the right side is lit, the right orbit (1) and the Saturn ramp (2). Make one and the left side lights.")
                            step(8, "Neptune Deep · 50 s", "Spin 60 times to dive, then hit the bumpers 10 times.")
                            picture("tour_goal_neptune", "Neptune Deep: spin the spinners with the orbits (1) and Neptune sinks deeper in the window; then the bumpers (2).")
                            step(9, "Sun Slingshot · the finale", "A 3-ball multiball with a 15-second ball save. The orbits and both ramps are Sun jackpots (250,000 each). Make all four to drop the blast door, then shoot Mission Control for the 1,000,000 super jackpot.")
                            picture("tour_goal_sun", "Sun Slingshot with two jackpots made: the right orbit (1) and the Saturn ramp (2) are still lit. Then Mission Control (3) for the super jackpot.")
                            para("The super jackpot finishes the Grand Tour, and the next tour begins: every stop, jackpot and award is worth twice as much on tour 2, three times on tour 3, and so on.")
                        }
                        section("PLUTO") {
                            para("Finish a tour and Pluto lights for that ball only. Shoot Mission Control to go there: make both orbits, then Saturn, within 30 seconds, for 2,500,000. Lose the ball first and it's gone until the next tour.")
                            picture("tour_goal_pluto", "Pluto: both orbits (1), then the Saturn ramp (2). Frost creeps over the window as the clock runs.")
                        }
                        section("SAVING YOUR BALL") {
                            picture("tour_goal_saves", "The kickback (1), lit at the start of every ball, and the rocket post (2), up after an O-R-B-T.")
                            tip("Ball save", "For 10 seconds after each launch, a drained ball comes back once.")
                            tip("Kickback", "Lit at the start of every ball. Fires a ball back out of the left outlane once.")
                            tip("Rocket post", "Raised by completing O-R-B-T. Stops one ball between the flippers.")
                            tip("Stop saves", "6 seconds at the start of each stop, 10 at the start of Moonshot's multiball, 15 at the start of the Sun Slingshot.")
                            tip("Extra ball", "The first R-O-C-K-E-T of each game lights the rover for an extra ball.")
                            tip("Nudge", "Flick a finger up, left or right to nudge the table. Too many and you get a warning, then a tilt: the flippers go dead until the next ball.")
                        }
                        section("SCORING TIPS") {
                            tip("Multiplier", "Every O-R-B-T adds 1X, up to 6X. It multiplies everything until you lose the ball.")
                            picture("tour_goal_lanes", "The O-R-B-T lanes (1), three of four lit; the flippers move the lit lanes along. The S-T-A-R lanes (2) brighten the Sun as they light.")
                            tip("Combos", "A different shot (a ramp, an orbit or Mission Control) within 4 seconds of the last one: 10,000, 20,000, 30,000, then 50,000 a link.")
                            tip("Bonus", "Each lost ball pays 25,000 per planet visited this game and 1,000 per ramp and orbit made, times your multiplier.")
                            tip("Pluto", "The biggest single award on the table. Save a ball for it after the Sun.")
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
        para("Fly one ship from Earth to every planet and round the Sun. Count down to liftoff, then shoot Mission Control to start each stop on the tour. Every stop is its own short mode with a clock; finish them all, then win the Sun Slingshot to complete the Grand Tour.")
    }

    /// The whole table (tour_howto_map.png) with a numbered badge on each part. The picture covers world
    /// (-25.3, -12.0)–(625.3, 1354.1): a TOP-camera capture (cam (300, 695.3), scale 1.6186, view 402 × 874 pt, the top
    /// 30 pt of the screen cut off).
    private var tableMap: some View {
        let world = CGRect(x: -25.33, y: -12.0, width: 650.67, height: 1366.08)
        return Group {
            if let art = UIImage(named: "tour_howto_map") {
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

    /// A goal picture (tools/tour_howto_goals.py: the game posed in the Simulator with `-tourPose`, the shots drawn on
    /// in gold) with a caption under it. Skipped if the image is missing.
    @ViewBuilder
    private func picture(_ name: String, _ caption: String) -> some View {
        if let art = UIImage(named: name + ".jpg") {
            VStack(alignment: .leading, spacing: 6) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 460)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.gold.opacity(0.5), lineWidth: 1))
                Text(caption)
                    .font(.system(.footnote).italic())
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.orbitron(15, .bold))
                .tracking(2)
                .foregroundStyle(Self.gold)
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
            .background(Self.cyan, in: Circle())
            .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1))
    }

    private func step(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.orbitron(13, .black))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(Self.gold, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.orbitron(14, .bold))
                para(text)
            }
        }
    }

    private func tip(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.orbitron(13, .bold)).foregroundStyle(Self.cyan)
            para(text)
        }
    }
}
