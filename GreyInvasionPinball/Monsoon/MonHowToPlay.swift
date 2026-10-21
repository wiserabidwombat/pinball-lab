import SwiftUI
import UIKit

/// Table 04's How to Play (polish round 1): Table 03's How to Play screen with Monsoon's map and rules. Opens from the
/// menu and the pause card. A numbered map of the table, then the three acts (paint the desert, Monsoon, Superbloom),
/// ways to save a ball and scoring tips. Every number here comes from MonTableScene / MonTableLayout / MonGameState;
/// update this screen if a rule changes.
struct MonHowToPlayView: View {
    let onClose: () -> Void

    private static let green = Color(red: 0.96, green: 0.78, blue: 0.45)      // the table's storm-light gold (headings)
    private static let yellow = Color(red: 1.0, green: 0.84, blue: 0.40)      // map badges

    /// A numbered spot on the map: world position (MonTableLayout points) and what it is.
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
        Spot(id: 4, at: CGPoint(x: 274, y: 1210), name: "Raindrop lanes",
             what: "Each lane you light paints a little sky; all three add +1 multiplier (up to 5X). Each flipper press moves the lit lanes."),
        Spot(id: 5, at: CGPoint(x: 274, y: 1010), name: "Storm-cloud bumpers",
             what: "Every hit adds a touch of sky, and every 10th washes color into the desert. The clouds color in with the sky."),
        Spot(id: 6, at: CGPoint(x: 39, y: 935), name: "Orbit and spinner",
             what: "The lane up the left side and round the top. Shoot it from the right flipper. Paints the sky."),
        Spot(id: 7, at: CGPoint(x: 392, y: 690), name: "Mesa ramp",
             what: "Shoot it from the left flipper. Paints the mesas. A gate at the top sends the ball over the high wire, or into the helix in Monsoon and Superbloom."),
        Spot(id: 8, at: CGPoint(x: 306, y: 668), name: "Arroyo",
             what: "The centre hole. Paints the arroyo, then kicks the ball up the low wire. Starts Monsoon and Superbloom when they're lit."),
        Spot(id: 9, at: CGPoint(x: 145, y: 900), name: "High wire",
             what: "Brings mesa ramp shots back over the table to the left inlane. A finished ride adds a little arroyo color."),
        Spot(id: 10, at: CGPoint(x: 355, y: 960), name: "Low wire",
             what: "Takes every arroyo ball round the top to the right inlane. A finished ride adds a little arroyo color."),
        Spot(id: 11, at: CGPoint(x: 430, y: 1165), name: "Helix",
             what: "A corkscrew down into the bumpers. Paints the mesas, and it's the jackpot in Monsoon and Superbloom."),
        Spot(id: 12, at: CGPoint(x: 496, y: 560), name: "Saguaro standups",
             what: "Each one you light paints the saguaros a little. Light all three for 5,000, more saguaros and to relight the kickback."),
        Spot(id: 13, at: CGPoint(x: 112, y: 640), name: "Captive ball",
             what: "Knock it to the top of its channel for 2,500 and a wash of saguaro green."),
        Spot(id: 14, at: CGPoint(x: 505, y: 790), name: "Upper flipper",
             what: "Moves with the right flipper."),
        Spot(id: 15, at: CGPoint(x: 284, y: 470), name: "Dust devil",
             what: "Bends the ball's path as it crosses. Each pass adds a touch of desert color."),
        Spot(id: 16, at: CGPoint(x: 284, y: 532), name: "Paint drops",
             what: "One lamp per region round the dust devil: lit when it's painted, blinking while it's under way."),
        Spot(id: 17, at: CGPoint(x: 37, y: 300), name: "Kickback",
             what: "When lit, fires a ball back up the left outlane. Light it with the saguaro standups."),
        Spot(id: 18, at: CGPoint(x: 531, y: 300), name: "Outlane save",
             what: "Painting a region lights it. One ball down the right outlane comes back."),
        Spot(id: 19, at: CGPoint(x: 284, y: 150), name: "Shoot again",
             what: "Ball save: on for 10 seconds after each launch and through the multiball saves, blinking as it runs out."),
        Spot(id: 20, at: CGPoint(x: 284, y: 335), name: "Superbloom",
             what: "Blinks when Superbloom is lit, and stays on while it runs."),
        Spot(id: 21, at: CGPoint(x: 364, y: 550), name: "Helix lamp",
             what: "On while the gate at the top of the mesa ramp is set to the helix."),
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
                        section("ACT 1 · PAINT THE DESERT") {
                            para("The table starts as a pencil sketch. Five regions take color: the sky, the mesas, the saguaros, the arroyo and the desert floor. A shot that paints a region lays a wash there (250). When the region has all its washes it fills in (10,000) and lights the outlane save.")
                            step(1, "Sky · 5 washes", "The orbit is a whole wash. Each raindrop lane you light is a quarter, and finishing all three another quarter. Every bumper hit adds a touch.")
                            picture("mon_goal_sky", "Sky: the orbit from the right flipper (1), the raindrop lanes (2) and the storm clouds (3). Every arrow blinks on the fresh sketch; the sky's paint drop blinks once it's under way.")
                            step(2, "Mesas · 3 washes", "The mesa ramp and the helix.")
                            picture("mon_goal_mesas", "Mesas: the mesa ramp from the left flipper (1) climbs to the gate; the helix (2) paints them too. The sky is done, so its drop is lit and the orbit arrow has gone out.")
                            step(3, "Saguaros · 5 washes", "Each standup you light is half a wash; the full set of three is a whole one. So is the captive ball reaching the top.")
                            picture("mon_goal_saguaros", "Saguaros: the standups from the left flipper (1), each one lighting as you hit it, and the captive ball from the right flipper (2).")
                            step(4, "Arroyo · 6 washes", "The arroyo hole. A finished wire ride is half a wash.")
                            picture("mon_goal_arroyo", "Arroyo: the centre hole (1), which sends the ball round the low wire (2) to the right inlane. A painted region has lit the outlane save, bottom right.")
                            step(5, "Desert · 6 washes", "Every 10th bumper hit. Each pass through the dust devil is a quarter wash.")
                            picture("mon_goal_desert", "Desert: every 10th storm-cloud hit (1) and every pass through the dust devil (2).")
                            para("Shot arrows blink while their region still needs color, and the five paint drops round the dust devil show how far each region has got.")
                        }
                        section("ACT 2 · MONSOON") {
                            para("Paint three regions and Monsoon lights at the arroyo. Shoot it for a 2-ball multiball: the storm rolls in, a second ball fires up the low wire, and for 10 seconds any drained ball comes back.")
                            picture("mon_goal_monsoon", "Three regions painted: the arroyo arrow blinks fast and the sky starts to darken. Shoot the arroyo.")
                            step(1, "Bloom the wildflowers",
                                 "The gate throws to the helix. Every helix ride, or a mesa ramp made, is a 25,000 jackpot that blooms a patch of wildflowers. Bloom four.")
                            picture("mon_goal_wildflowers", "In Monsoon the helix lamp is on: the mesa ramp throws the ball into the helix for a 25,000 jackpot. Shoot again stays lit through the multiball save.")
                            step(2, "The storm passes",
                                 "Monsoon ends when you're down to one ball. It lights again after two more regions are painted, or straight away if the whole desert is painted and the wildflowers aren't all out.")
                        }
                        section("ACT 3 · SUPERBLOOM") {
                            para("With all five regions painted and four wildflowers bloomed, Superbloom lights at the arroyo. Shoot it for a 3-ball multiball with a 25-second ball save, and the petals fall.")
                            picture("mon_goal_superbloom_lit", "The whole desert painted and four wildflowers out: the Superbloom star blinks. Shoot the arroyo.")
                            step(1, "Every shot blooms",
                                 "The orbit, the mesa ramp, the arroyo, each standup and the captive ball: 15,000 each.")
                            step(2, "Super jackpot", "The helix: 75,000.")
                            picture("mon_goal_superbloom", "Superbloom: every shot arrow lit for 15,000, and the helix (pink) for the 75,000 super jackpot.")
                            step(3, "A new sketch",
                                 "When you're down to one ball the painting is finished. A moment later the table goes back to pencil and starts again, with every painting award doubled (then tripled, and so on).")
                        }
                        section("SAVING YOUR BALL") {
                            picture("mon_goal_saves", "Shoot again (1), the kickback (2), lit at the start of every ball and relit by the three saguaro standups, and the outlane save (3).")
                            tip("Shoot again", "For 10 seconds after each launch, a drained ball comes back.")
                            tip("Kickback", "Lit by the three saguaro standups. Fires a ball back out of the left outlane once.")
                            tip("Outlane save", "Lit by painting a region. Brings back one ball from the right outlane.")
                            tip("Multiball saves", "10 seconds at the start of Monsoon, 25 at the start of Superbloom.")
                        }
                        section("SCORING TIPS") {
                            tip("Multiplier", "Every set of raindrop lanes adds 1X, up to 5X. It multiplies everything until you lose the ball.")
                            picture("mon_goal_lanes", "All three raindrop lanes lit: +1X. Each flipper press moves the lit lanes along.")
                            tip("Skill shot", "A ring circles one raindrop lane at each launch. Roll through that lane within 5 seconds for 10,000.")
                            tip("Spinner", "20 a spin.")
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
        para("Every shot washes color into a pencil sketch of the Sonoran desert. Paint it, call the Monsoon, then bring on the Superbloom. Your progress carries over from ball to ball; each new game starts from the sketch.")
    }

    /// The whole table (mon_howto_map.png, tools/mon_howto_map.py: the painting in full color with every part and the
    /// wires) with a numbered badge on each part. The picture covers world (-40,-75)–(640,1330).
    private var tableMap: some View {
        let world = CGRect(x: -40, y: -75, width: 680, height: 1405)
        return Group {
            if let art = UIImage(named: "mon_howto_map") {
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

    /// A goal picture (tools/mon_howto_goals.py: the table as the game draws it in that state, lamps lit by the rules
    /// and the shots drawn on in gold) with a caption under it. Skipped if the image is missing.
    @ViewBuilder
    private func picture(_ name: String, _ caption: String) -> some View {
        if let art = UIImage(named: name) {
            VStack(alignment: .leading, spacing: 6) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 460)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.green.opacity(0.5), lineWidth: 1))
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
