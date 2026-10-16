src = open('cthulhu/CthHowToPlay.swift').read()
head_end = src.index("    var body: some View {")
pieces_start = src.index("    // MARK: - Pieces")
new_head = '''import SwiftUI
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
             what: "Light all three for +1 multiplier (up to 5X) and a wash of sky. Each flipper press moves the lit lanes."),
        Spot(id: 5, at: CGPoint(x: 274, y: 1010), name: "Storm-cloud bumpers",
             what: "Every 10th bumper hit washes color into the desert. The clouds color in as the sky is painted."),
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
             what: "Each one you light paints the saguaros a little. Light all three for 5,000, more saguaros and the kickback."),
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

'''
body = src[head_end:pieces_start]
a = body.index('                        section("ACT 1 · RESEARCH") {')
b = body.index('                    }\n                    .padding(.horizontal, 20)')
acts = '''                        section("ACT 1 · PAINT THE DESERT") {
                            para("The table starts as a pencil sketch. Five regions take color: the sky, the mesas, the saguaros, the arroyo and the desert floor. A shot that paints a region lays a wash there (250). When the region has all its washes it fills in (10,000) and lights the outlane save.")
                            step(1, "Sky · 4 washes", "The orbit, and finishing all three raindrop lanes.")
                            step(2, "Mesas · 3 washes", "The mesa ramp and the helix.")
                            step(3, "Saguaros · 5 washes", "Each standup you light is half a wash; the full set of three is a whole one. So is the captive ball reaching the top.")
                            step(4, "Arroyo · 6 washes", "The arroyo hole. A finished wire ride is half a wash.")
                            step(5, "Desert · 6 washes", "Every 10th bumper hit. Each pass through the dust devil is a quarter wash.")
                            para("Shot arrows blink while their region still needs color, and the five paint drops round the dust devil show how far each region has got.")
                        }
                        section("ACT 2 · MONSOON") {
                            para("Paint three regions and Monsoon lights at the arroyo. Shoot it for a 2-ball multiball: the storm rolls in, a second ball fires up the low wire, and for 10 seconds any drained ball comes back.")
                            step(1, "Bloom the wildflowers",
                                 "The gate throws to the helix. Every helix ride, or a mesa ramp made, is a 25,000 jackpot that blooms a patch of wildflowers. Bloom four.")
                            step(2, "The storm passes",
                                 "Monsoon ends when you're down to one ball. It lights again after two more regions are painted, or straight away if the whole desert is painted and the wildflowers aren't all out.")
                        }
                        section("ACT 3 · SUPERBLOOM") {
                            para("With all five regions painted and four wildflowers bloomed, Superbloom lights at the arroyo. Shoot it for a 3-ball multiball with a 25-second ball save, and the petals fall.")
                            step(1, "Every shot blooms",
                                 "The orbit, the mesa ramp, the arroyo, each standup and the captive ball: 15,000 each.")
                            step(2, "Super jackpot", "The helix: 75,000.")
                            step(3, "A new sketch",
                                 "When you're down to one ball the painting is finished. A moment later the table goes back to pencil and starts again, with every painting award doubled (then tripled, and so on).")
                        }
                        section("SAVING YOUR BALL") {
                            tip("Shoot again", "For 10 seconds after each launch, a drained ball comes back.")
                            tip("Kickback", "Lit by the three saguaro standups. Fires a ball back out of the left outlane once.")
                            tip("Outlane save", "Lit by painting a region. Brings back one ball from the right outlane.")
                            tip("Multiball saves", "10 seconds at the start of Monsoon, 25 at the start of Superbloom.")
                        }
                        section("SCORING TIPS") {
                            tip("Multiplier", "Every set of raindrop lanes adds 1X, up to 5X. It multiplies everything until you lose the ball.")
                            tip("Skill shot", "A ring circles one raindrop lane at each launch. Roll through that lane within 5 seconds for 10,000.")
                            tip("Spinner", "20 a spin.")
                            tip("Bonus", "Each lost ball pays 1,000 per shot made and 20 per spin, times your multiplier.")
                        }
'''
body = body[:a] + acts + body[b:]
pieces = src[pieces_start:]
old_intro = 'para("Read the forbidden tomes, perform the Ritual, then fight Cthulhu himself as he rises from the Lagoon. Your progress carries over from ball to ball.")'
assert old_intro in pieces
pieces = pieces.replace(old_intro, 'para("Every shot washes color into a pencil sketch of the Sonoran desert. Paint it, call the Monsoon, then bring on the Superbloom. Your progress carries over from ball to ball; each new game starts from the sketch.")')
old_doc = '''    /// The whole table (cth_howto_map.png, tools/cth_howto_map.py: the rendered table with every part and Cthulhu
    /// risen) with a numbered badge on each part. The picture covers world (-40,-75)–(640,1330).'''
assert old_doc in pieces
pieces = pieces.replace(old_doc, '''    /// The whole table (mon_howto_map.png, tools/mon_howto_map.py: the painting in full color with every part and the
    /// wires) with a numbered badge on each part. The picture covers world (-40,-75)–(640,1330).''')
pieces = pieces.replace('UIImage(named: "cth_howto_map")', 'UIImage(named: "mon_howto_map")')
out = new_head + body + pieces
bad = [l for l in out.splitlines() if any(w in l for w in ('Cth', 'cth', 'Cthulhu', 'Library', 'tome'))]
assert not bad, bad
open('monsoon/MonHowToPlay.swift', 'w').write(out)
print(len(out.splitlines()))
