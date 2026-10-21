import SwiftUI
import UIKit

/// Table 05's How to Play (T5 M9 v44): Monsoon's How to Play screen with the Lamplight's map and rules, and (Aaron's
/// testers: "for each goal, show what it would look like on the table") a picture for every goal: the table as the game
/// draws it, with the lamps that goal lights and the shot drawn on (tools/lmp_howto.py → lmp_howto_*.png). Opens from
/// the menu and the pause card. Every number here comes from LmpTableScene / LmpTableLayout / LmpShop / LmpCozy /
/// LmpSeasons; update this screen (and re-run the pictures) if a rule changes.
struct LmpHowToPlayView: View {
    let onClose: () -> Void

    private static let gold = Color(red: 1.0, green: 0.74, blue: 0.40)        // headings (the LED strip's gold)
    private static let yellow = Color(red: 1.0, green: 0.86, blue: 0.45)      // map badges and tip titles

    /// A numbered spot on the map: world position (LmpTableLayout points, as drawn: loft parts include its lift).
    private struct Spot: Identifiable {
        let id: Int
        let at: CGPoint
        let name: String
        let what: String
    }

    private static let spots: [Spot] = [
        Spot(id: 1, at: CGPoint(x: 150, y: 236), name: "Flippers",
             what: "Touch the left or right half of the screen. The right side also works the loft flipper."),
        Spot(id: 2, at: CGPoint(x: 564, y: 150), name: "Plunger",
             what: "Pull down in the bottom-right corner and let go. Pull it all the way for a full plunge up into the loft."),
        Spot(id: 3, at: CGPoint(x: 112, y: 385), name: "Slingshots",
             what: "Kick the ball back into play above each flipper."),
        Spot(id: 4, at: CGPoint(x: 284, y: 718), name: "Fire screen",
             what: "Four iron panels. Knock all four down to open the fireplace."),
        Spot(id: 5, at: CGPoint(x: 284, y: 812), name: "Fireplace",
             what: "Behind the screen. Open, it scores and finds you a book; it also starts Festival Night."),
        Spot(id: 6, at: CGPoint(x: 182, y: 800), name: "Kettle lane",
             what: "Shoot it from the right flipper, past the teapot spinner (20 a spin)."),
        Spot(id: 7, at: CGPoint(x: 112, y: 880), name: "Kettle",
             what: "Brews the tea (1,500) and lights the dumbwaiter: the next kettle shot rides up to the loft."),
        Spot(id: 8, at: CGPoint(x: 470, y: 868), name: "Ramp",
             what: "Shoot it from the left flipper. It climbs to the loft (1,000)."),
        Spot(id: 9, at: CGPoint(x: 196, y: 1100), name: "The loft",
             what: "The reading nook upstairs. A ball up here plays the loft flipper, then comes down the stairs."),
        Spot(id: 10, at: CGPoint(x: 86, y: 1150), name: "Window seat",
             what: "Shoot it from the loft flipper: 5,000 and a book, once a ball."),
        Spot(id: 11, at: CGPoint(x: 262, y: 1020), name: "Loft flipper",
             what: "Moves with the right flipper."),
        Spot(id: 12, at: CGPoint(x: 40, y: 760), name: "Left loop",
             what: "Shoot it from the right flipper: up the left lane, round the top and down onto the teacups (500)."),
        Spot(id: 13, at: CGPoint(x: 527, y: 860), name: "Right loop",
             what: "Shoot it from the left flipper: up the right lane, round the top and down the left (500)."),
        Spot(id: 14, at: CGPoint(x: 318, y: 965), name: "Teacups",
             what: "Three teacup bumpers, 100 a hit."),
        Spot(id: 15, at: CGPoint(x: 395, y: 1250), name: "Top gate",
             what: "Lets the right loop and the plunger through; stops the left loop and drops it on the teacups."),
        Spot(id: 16, at: CGPoint(x: 380, y: 668), name: "Mail slot",
             what: "A soft shot from the left flipper posts a letter (2,000). Too fast and it rolls over."),
        Spot(id: 17, at: CGPoint(x: 370, y: 1212), name: "The cat and her shelf",
             what: "She walks her bookshelf and naps on her perches. The shelf fills with spines as your collection grows."),
        Spot(id: 18, at: CGPoint(x: 284, y: 352), name: "Lucky star",
             what: "Lit for a lucky evening: rare books turn up more often."),
        Spot(id: 19, at: CGPoint(x: 531, y: 322), name: "Cat flap",
             what: "When its green lamp is lit, a ball down the right outlane is kicked straight back up."),
        Spot(id: 20, at: CGPoint(x: 456, y: 196), name: "Shop lamps",
             what: "Come on one by one as the evening goes by. They flash during the Evening Rush."),
        Spot(id: 21, at: CGPoint(x: 118, y: 72), name: "Cozy spots",
             what: "Tonight's three pieces of furniture stand on the hearth above their lamps; a lamp flashes while its piece is working."),
        Spot(id: 22, at: CGPoint(x: 284, y: 150), name: "Centre post",
             what: "Pops a ball dropping straight down the middle onto a flipper."),
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
                    VStack(alignment: .leading, spacing: 24) {
                        para("You keep The Lamplight, a little bookshop-café on a rainy evening. Regulars come in with something they'd like, and the lit shots make it. Help them, find books for your collection, spend your tips on cozy furniture, and when the season's regulars are happy, hold Festival Night. Your collection, tips and furniture are kept from evening to evening.")
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
                        section("REGULARS AND THEIR REQUESTS") {
                            para("A regular comes in a few seconds into the evening, and the next a few seconds after you help one. Their card shows what they'd like; the arrows for the next shot flash, in order. There's no clock: they wait until it's done.")
                            para("A finished request pays 5,000, a tip and a step of their friendship, and adds 1X to your bonus multiplier (up to 5X).")
                            step(1, "Tea: the ramp, then the kettle", "The ramp arrow flashes first; once you've made it, the kettle's.")
                            picture("lmp_howto_req_tea", "Tea: the ramp from the left flipper (1), then the kettle from the right (2).")
                            step(2, "A book: the fire screen, then a loop", "Knock down all four panels, then make either loop.")
                            picture("lmp_howto_req_book", "First the fire screen: the fireplace arrow flashes. Knock down all four panels.")
                            picture("lmp_howto_req_loop", "Then a loop: both loop arrows flash. The right loop from the left flipper (1) or the left loop from the right (2).")
                            step(3, "A favor: post a letter", "The ring round the mail slot lights. A soft shot from the left flipper.")
                            picture("lmp_howto_req_mail", "The mail slot's ring lit: a soft shot from the left flipper.")
                            step(4, "A chat: come up to the loft", "The ramp arrow flashes. Any way up counts (see Up to the Loft).")
                        }
                        section("THE FIRE SCREEN AND THE FIREPLACE") {
                            para("Each panel you knock down is 100; all four are 1,000 and open the fireplace, its arrow flashing. A ball in the fireplace scores 2,500, and the first one after each full screen finds you a book. The screen comes back up once the ball is out of the fireplace.")
                            picture("lmp_howto_fireplace", "All four panels down: the fireplace is open. Shoot straight up into it.")
                        }
                        section("UP TO THE LOFT") {
                            step(1, "The ramp", "From the left flipper (1,000).")
                            step(2, "The dumbwaiter", "Make the kettle and its arrow blinks: the dumbwaiter is lit. The next kettle shot rides up (1,000).")
                            step(3, "A full plunge", "Pull the plunger all the way down: the ball goes round the top and drops through the hatch into the loft (2,500).")
                            picture("lmp_howto_loft", "The three ways up: the ramp (1), the kettle and its dumbwaiter (2), a full plunge (3).")
                            para("Up there, the loft flipper shoots the window seat: 5,000 and a book, once a ball (its arrow is lit while it's still yours). A second visit on the same ball sends the ball back downstairs.")
                            picture("lmp_howto_windowseat", "In the loft: the window-seat arrow lit, from the loft flipper.")
                        }
                        section("LOOPS AND LUCKY EVENINGS") {
                            para("Each loop is 500. Make the other one within 5 seconds for a loop combo (1,000): both loop arrows flash while the combo's open. A loop combo or a full plunge makes it a lucky evening: the green star lights, the ramp arrow blinks, and rare books turn up more often until closing.")
                            picture("lmp_howto_combo", "A loop combo: the right loop (1) and then the left (2), the lucky star lit.")
                        }
                        section("FINDING BOOKS") {
                            para("Books come from the fireplace (the first after each full fire screen), the window seat (once a ball) and waking the cat. Each find has a rarity: common to ultra rare, with rarer books after a long dry spell. A new book goes into your collection and onto the cat's shelf, one spine per genre for every few books; a copy you already own is lent out for a tip. Each season has six seasonal treasures to find too.")
                        }
                        section("THE CAT") {
                            para("She walks her bookshelf, and naps on the perches you've bought for her (the mantel, a basket by the kettle, the window-seat cushion).")
                            tip("Wake her", "Hit her while she naps: 500, and a book, or now and then a gift for your collection.")
                            tip("Pet her", "Hit her while she's awake: 250 and a purr.")
                            tip("Swat!", "Now and then she swats a ball that comes past her (100).")
                            picture("lmp_howto_cat", "Napping by the kettle: shoot the kettle lane to wake her.")
                        }
                        section("THE EVENING RUSH") {
                            para("Every third request you finish in an evening starts the Rush: a second ball is plunged in for you, every request pays double, and for the first 10 seconds a lost ball comes straight back. The shop lamps flash until you're down to one ball.")
                            picture("lmp_howto_rush", "The Rush: two balls, every shop lamp flashing.")
                        }
                        section("FESTIVAL NIGHT") {
                            para("Each season lasts 7 evenings. Help 9 regulars in a season (or reach its last evening) and its festival lights at the fireplace, blinking: knock down the screen and shoot the fireplace. Three balls, a 15-second ball save, string lights over the shop, every shot lit and worth 25,000 more, requests pay double and every find is rare or better. One festival a season.")
                            picture("lmp_howto_festival", "Festival Night: every shot lit, three balls in play.")
                        }
                        section("COZY FURNITURE") {
                            para("Tips buy furniture in The Collection's catalog; up to three pieces stand in the shop each evening. A tip is every 25,000 points, every regular helped and every book lent out.")
                            picture("lmp_howto_cozy", "Tonight's pieces on the hearth, their lamps lit.")
                            ForEach(LmpCozy.allCases, id: \.self) { piece in
                                tip("\(piece.name) · \(piece.price) tips", piece.effect)
                            }
                        }
                        section("SAVING YOUR BALL") {
                            tip("Cat flap", "Lit at the start of each ball. Kicks one ball from the right outlane straight back up.")
                            picture("lmp_howto_catflap", "The cat flap's green lamp lit: a ball down the right outlane comes back up.")
                            tip("The Rush and Festival Night", "10 and 15 seconds of ball save when they start.")
                            tip("Grandfather clock", "Each ball starts with an 8-second ball save.")
                            tip("Rocking chair", "Relights the cat flap every time you help a regular.")
                        }
                        section("SCORING") {
                            tip("Bonus", "Each ball you lose pays 2,000 per book found, 3,000 per regular helped and 500 per loop, times your multiplier. The multiplier goes back to 1X with the next ball (the armchair keeps it).")
                            tip("The evening", "About five minutes; the shop lamps come on as it goes and it closes when your last ball is lost. Your best evening is kept.")
                            tip("Small things", "Teacups and panels 100, the centre post 50, slingshots 10, the spinner 20 a spin.")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 440)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 12)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Pieces

    /// The whole table (lmp_howto_map.png, tools/lmp_howto.py) with a numbered badge on each part. The picture covers
    /// world (-40,-75)–(640,1330).
    private var tableMap: some View {
        let world = CGRect(x: -40, y: -75, width: 680, height: 1405)
        return Group {
            if let art = UIImage(named: "lmp_howto_map") {
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
                    .frame(maxHeight: 460)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Self.gold.opacity(0.35), lineWidth: 1))
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
            .background(Self.yellow, in: Circle())
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
            Text(title).font(.orbitron(13, .bold)).foregroundStyle(Self.yellow)
            para(text)
        }
    }
}
