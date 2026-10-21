// Pinball Lab Table 05 (The Lamplight): the collection book (milestone 6 round 2).
// T5 M9 v46 (Aaron: the page listed the books, then a catalog with no word on what it was or how tips are earned): three
// tabs. THE SHOP: the shop at a glance (books, tips, best evening, season and festival, treasures, the cat's gifts), how
// the shop works, your regulars and their friendship, and "Start a new shop". BOOKS: where books come from, the rarities,
// the six genre shelves, the seasonal treasures and the cat's gifts (found books in colour, missing ones as silhouettes;
// tap a found one for its card). THE CATALOG: your tips and how to earn them, then the cozy furniture (with what a cozy
// spot is) and the cat's perches.
import SwiftUI

struct LmpCollectionView: View {
    let onClose: () -> Void
    @State private var selected: LmpBook?
    @State private var confirmNewShop = false
    @State private var tab: Tab = .shop
    @State private var pulled: String?                 // T5 M9 v47: the book slid up off its shelf
    private var shop: LmpShop { LmpShop.shared }

    private enum Tab: String, CaseIterable { case shop = "The Shop", books = "Books", catalog = "The Catalog" }

    private static let paper = Color(red: 0.13, green: 0.10, blue: 0.08)
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private static let tipBrown = Color(red: 0.62, green: 0.40, blue: 0.20)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("Section", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 12)
                    switch tab {
                    case .shop: shopPage
                    case .books: booksPage
                    case .catalog: catalogPage
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Self.paper.ignoresSafeArea())
            .navigationTitle("The Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Debug") {
                        Button("Find 1 book") { _ = shop.find(from: .shelf, lucky: false) }
                        Button("Find 10 books") { for _ in 0..<10 { _ = shop.find(from: .shelf, lucky: false) } }
                        Button("Find 50 books") { for _ in 0..<50 { _ = shop.find(from: .shelf, lucky: false) } }
                        Button("Add 10 tips") { shop.debugAddTips(10) }
                    }
                }
                #endif
            }
            .sheet(item: $selected) { book in
                bookCard(book)
                    .presentationDetents([.height(260)])
            }
            .onChange(of: selected) { _, now in
                if now == nil { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pulled = nil } }
            }
            .alert("Start a new shop?", isPresented: $confirmNewShop) {
                Button("Start over", role: .destructive) { shop.startNewShop() }
                Button("Keep my shop", role: .cancel) { }
            } message: {
                Text("Every book, tip and day played is cleared. This can't be undone.")
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - The Shop

    private var shopPage: some View {
        let treasures = LmpSeason.allCases.flatMap { LmpShop.treasures(of: $0) }
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("The Lamplight")
                    .font(.orbitron(22, .black))
                    .foregroundStyle(LmpTableView.gold)
                Text(shop.seasonLine)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.75))
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile("Books", "\(shop.booksOwned) of \(LmpShop.books.count)") { tab = .books }
                tile("Tips to spend", "\(shop.save.tips)") { tab = .catalog }
                tile("Best evening", shop.save.bestEvening.formatted())
                tile("Evenings played", "\(shop.save.daysPlayed)")
                tile("Seasonal treasures", "\(treasures.filter { shop.owns($0) }.count) of \(treasures.count)") { tab = .books }
                tile("Gifts from the cat", "\(LmpShop.catGifts.filter { shop.owns($0) }.count) of \(LmpShop.catGifts.count)") { tab = .books }
            }
            note("FESTIVAL NIGHT", shop.festivalLine)
            sectionTitle("HOW THE SHOP WORKS")
            howItem("person.2.fill", "Help the regulars",
                    "Each evening regulars come in asking for something; the flashing arrows on the table show the shots. Every one you help is points, a tip and a step of friendship. Help \(LmpSeason.festivalGoal) in a season and its Festival Night lights at the fireplace.")
            howItem("books.vertical.fill", "Find books",
                    "Books turn up in the fireplace, the window seat and when you wake the cat. They go on your shelves for good; see Books.")
            howItem("dollarsign.circle.fill", "Earn tips, furnish the shop",
                    "Tips come from your score, the regulars you help and the spare books you lend. Spend them in The Catalog on furniture that changes how the table plays, and on new perches for the cat.")
            sectionTitle("YOUR REGULARS")
            ForEach(LmpRegulars.all + [LmpRegulars.winterVisitor], id: \.self) { r in
                let level = shop.save.friendship[r.id] ?? 0
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(.white)
                        Text(r.who).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text(level == 0 ? "not met yet" : "friendship \(level)")
                        .font(.orbitron(11, .bold))
                        .foregroundStyle(level == 0 ? .white.opacity(0.4) : LmpTableView.gold)
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            Button(role: .destructive) { confirmNewShop = true } label: {
                Text("Start a new shop")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Books

    private var booksPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Books \(shop.booksOwned) of \(LmpShop.books.count)")
                    .font(.orbitron(20, .black))
                    .foregroundStyle(LmpTableView.gold)
                ProgressView(value: Double(shop.booksOwned), total: Double(LmpShop.books.count))
                    .tint(LmpTableView.gold)
                HStack(spacing: 10) {
                    ForEach(LmpRarity.allCases, id: \.self) { r in
                        HStack(spacing: 4) {
                            Circle().fill(LmpTableView.rarityColor(r)).frame(width: 8, height: 8)
                            Text(r.name).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }
            }
            note("WHERE BOOKS COME FROM", "The fireplace (the first ball in after you knock down the whole fire screen), the window seat up in the loft (once a ball) and waking the napping cat. Lucky evenings and Festival Night bring rarer books. A copy you already have is lent out for a tip. Tap a book you've found to see it.")
            ForEach(LmpShop.genres.map { $0.name }, id: \.self) { genre in
                shelf(genre)
            }
            sectionTitle("SEASONAL TREASURES", "Six a season, found only in their season; a missed one comes back next year.")
            ForEach(LmpSeason.allCases, id: \.self) { season in
                shelf(season.name, books: LmpShop.treasures(of: season))
            }
            sectionTitle("GIFTS FROM THE CAT", "Wake her while she naps and now and then she brings you something instead of a book.")
            shelf("Cat gifts", books: LmpShop.catGifts)
                .padding(.bottom, 24)
        }
    }

    // MARK: - The Catalog

    private var catalogPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(shop.save.tips)")
                    .font(.orbitron(30, .black))
                    .foregroundStyle(LmpTableView.gold)
                Text(shop.save.tips == 1 ? "tip to spend" : "tips to spend")
                    .font(.orbitron(14, .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 4)
            note("HOW TO EARN TIPS", "1 for every \(LmpShop.pointsPerTip.formatted()) points when the shop closes · 1 for each regular you help · 1 for each spare copy of a book you lend out.")
            catalog
            perches
                .padding(.bottom, 24)
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ title: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.orbitron(13, .bold))
                .tracking(1.5)
                .foregroundStyle(LmpTableView.gold)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A boxed explanation.
    private func note(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.orbitron(12, .bold))
                .tracking(1.2)
                .foregroundStyle(LmpTableView.gold)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LmpTableView.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LmpTableView.gold.opacity(0.25), lineWidth: 1))
    }

    /// A number on the shop page; tapping one with a page behind it goes there.
    @ViewBuilder
    private func tile(_ label: String, _ value: String, action: (() -> Void)? = nil) -> some View {
        let card = VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.orbitron(18, .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                if action != nil {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        if let action {
            Button(action: action) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }

    private func howItem(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(LmpTableView.gold)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(.white)
                Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// M8 round 3: the catalog's cozy pieces. Bought ones go into a free cozy spot; tap to move them in or out.
    private var catalog: some View {
        let used = shop.placedCozy.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("COZY FURNITURE")
                Spacer()
                Text("COZY SPOTS \(used) / \(LmpShop.cozySpots)")
                    .font(.orbitron(12, .bold))
                    .foregroundStyle(LmpTableView.gold)
            }
            Text("Furniture changes how the table plays. The shop has \(LmpShop.cozySpots) cozy spots (the lamps on the left apron); a piece works only while it's in one. Buy a piece and it goes into a free spot. Tap IN A SPOT to take a piece out, and PLACE to put one in.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(LmpCozy.allCases, id: \.self) { piece in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: piece.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(shop.isPlaced(piece) ? LmpTableView.gold : .white.opacity(0.45))
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(piece.name)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text(piece.effect)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer(minLength: 8)
                    if !shop.owns(piece) {
                        Button("\(piece.price) tips") { shop.buy(piece) }
                            .font(.orbitron(12, .bold))
                            .buttonStyle(.borderedProminent)
                            .tint(Self.tipBrown)
                            .disabled(shop.save.tips < piece.price)
                    } else if shop.isPlaced(piece) {
                        Button("IN A SPOT") { shop.togglePlaced(piece) }
                            .font(.orbitron(11, .bold))
                            .buttonStyle(.bordered)
                            .tint(LmpTableView.gold)
                    } else {
                        Button("PLACE") { shop.togglePlaced(piece) }
                            .font(.orbitron(11, .bold))
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .disabled(used >= LmpShop.cozySpots)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// M6 round 3: the cat's perches. Each one bought adds a spot she roams to; the sentence says what she does there.
    private var perches: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("THE CAT'S PERCHES", "Each perch you buy is another place she naps and sits around the shop. Yours to keep.")
            ForEach(LmpPerch.allCases, id: \.self) { perch in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(perch.furnitureName)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text(perch.effect)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer(minLength: 8)
                    if shop.owns(perch) {
                        Text(perch == .shelf ? "HERS" : "OWNED")
                            .font(.orbitron(11, .bold))
                            .foregroundStyle(LmpTableView.gold)
                    } else {
                        Button("\(perch.price) tips") { shop.buy(perch) }
                            .font(.orbitron(12, .bold))
                            .buttonStyle(.borderedProminent)
                            .tint(Self.tipBrown)
                            .disabled(shop.save.tips < perch.price)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Shelves (T5 M9 v47: real spines on a walnut shelf)
    // Every genre is a shelf of up to 10 books a row, standing upright with their spines out between brass bookends.
    // The edition shows in the spine: a paperback is thin and plain; a hardback cloth with two gilt bands; an illustrated
    // edition adds a gold title and an emblem; the two rarest are leather with raised bands and gilt lettering, the first
    // edition with gilt edges and a warm shine. A missing book is a gap with a faint outline (its rarity's colour at the
    // foot). Tap a book: it slides up off the shelf and its card opens.

    private static let booksPerRow = 10
    private static let rowHeight: CGFloat = 118
    private static let brass = LinearGradient(colors: [Color(red: 0.98, green: 0.84, blue: 0.52), Color(red: 0.72, green: 0.52, blue: 0.24),
                                                       Color(red: 0.92, green: 0.74, blue: 0.40)], startPoint: .leading, endPoint: .trailing)
    private static let gilt = Color(red: 0.95, green: 0.78, blue: 0.42)

    private func shelf(_ genre: String, books given: [LmpBook]? = nil) -> some View {
        let books = given ?? LmpShop.books.filter { $0.genre == genre }
        let owned = books.filter { shop.owns($0) }.count
        let rows = stride(from: 0, to: books.count, by: Self.booksPerRow).map {
            Array(books[$0..<min($0 + Self.booksPerRow, books.count)])
        }
        let complete = owned == books.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(genre.uppercased())
                    .font(.orbitron(13, .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(complete ? "SHELF COMPLETE" : "\(owned) / \(books.count)")
                    .font(.orbitron(12, .bold))
                    .foregroundStyle(complete ? LmpTableView.gold : .white.opacity(0.55))
            }
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    shelfRow(rows[i], plate: complete && i == rows.count - 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .background(                                            // the bookcase's dark back and walnut sides
                LinearGradient(colors: [Color(red: 0.09, green: 0.06, blue: 0.04), Color(red: 0.16, green: 0.10, blue: 0.06)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.36, green: 0.22, blue: 0.12), lineWidth: 3))
        }
    }

    /// One row of books between bookends, standing on a walnut board, scaled down to fit narrow screens.
    private func shelfRow(_ books: [LmpBook], plate: Bool) -> some View {
        let natural = books.reduce(CGFloat(0)) { $0 + Self.spineSize($1).width + 2 } + 2 * 9
        return VStack(spacing: 0) {
            GeometryReader { geo in
                let k = min(1, geo.size.width / natural)
                HStack(alignment: .bottom, spacing: 2) {
                    bookend()
                    ForEach(books) { book in
                        spine(book)
                            .offset(y: pulled == book.id ? -14 : 0)
                            .onTapGesture {
                                guard shop.owns(book) else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pulled = book.id }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { selected = book }
                            }
                    }
                    bookend()
                }
                .scaleEffect(k, anchor: .bottomLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            }
            .frame(height: Self.rowHeight)
            ZStack {                                               // the shelf board
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.35, blue: 0.19), Color(red: 0.32, green: 0.19, blue: 0.09)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 10)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
                if plate {
                    Text("COMPLETE")
                        .font(.system(size: 7, weight: .heavy, design: .serif))
                        .tracking(1)
                        .foregroundStyle(Color(red: 0.25, green: 0.15, blue: 0.05))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Self.brass, in: RoundedRectangle(cornerRadius: 2))
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func bookend() -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4)
            .fill(Self.brass)
            .frame(width: 7, height: 66)
            .shadow(color: .black.opacity(0.5), radius: 1.5, x: 1)
    }

    /// A stable size per book: width by edition (thicker as it gets rarer), height varied a little by its id.
    private static func spineSize(_ book: LmpBook) -> CGSize {
        let seed = book.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let widths: [LmpRarity: CGFloat] = [.common: 22, .uncommon: 26, .rare: 28, .veryRare: 30, .ultraRare: 32]
        let w = (widths[book.rarity] ?? 26) + CGFloat(seed % 4)
        let h = 86 + CGFloat(seed % 23)
        return CGSize(width: w, height: h)
    }

    /// A book standing on the shelf: its spine as the edition dresses it, or a gap where a missing one will go.
    @ViewBuilder
    private func spine(_ book: LmpBook) -> some View {
        let size = Self.spineSize(book)
        let ribbon = LmpTableView.rarityColor(book.rarity)
        if shop.owns(book) {
            let base = Self.cover(book)
            let r = book.rarity
            let cloth = r == .common ? base.opacity(0.75) : base
            let leather = r >= .veryRare
            ZStack {
                RoundedRectangle(cornerRadius: r == .common ? 1.5 : 3)
                    .fill(LinearGradient(colors: [cloth.opacity(0.55), cloth, cloth.opacity(0.85), .black.opacity(0.55)],
                                         startPoint: .leading, endPoint: .trailing))
                    .background(RoundedRectangle(cornerRadius: 3).fill(leather ? Color(red: 0.12, green: 0.06, blue: 0.03) : base))
                if r == .common {                                   // a paperback: a little white publisher's mark
                    Circle().fill(.white.opacity(0.7)).frame(width: 5, height: 5)
                        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                }
                if r >= .uncommon && !leather {                     // cloth with two gilt bands
                    VStack {
                        band(); Spacer(); band()
                    }
                    .padding(.vertical, 7)
                }
                if leather {                                        // raised bands across the leather
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { i in
                            if i > 0 { Spacer() }
                            ridge()
                        }
                    }
                    .padding(.vertical, 6)
                }
                if r == .rare {                                     // an illustrated edition's little emblem
                    Image(systemName: "seal.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Self.gilt)
                        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 14)
                }
                Text(book.title)
                    .font(.system(size: 9, weight: r >= .rare ? .bold : .semibold, design: .serif))
                    .foregroundStyle(r >= .rare ? Self.gilt : .white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(width: size.height - 34, height: size.width - 6)
                    .rotationEffect(.degrees(90))
                    .frame(width: size.width, height: size.height - 34)
            }
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {                             // a first edition's gilt top edge
                if r == .ultraRare {
                    Rectangle().fill(Self.gilt).frame(height: 2).padding(.horizontal, 2)
                }
            }
            .shadow(color: r == .ultraRare ? Self.gilt.opacity(0.55) : .black.opacity(0.5), radius: r == .ultraRare ? 5 : 1.5, x: 1)
            .accessibilityLabel("\(book.title), \(book.rarity.name)")
        } else {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .overlay(alignment: .bottom) {
                    Capsule().fill(ribbon.opacity(0.4)).frame(width: size.width * 0.5, height: 3).padding(.bottom, 4)
                }
                .frame(width: size.width, height: size.height)
                .accessibilityLabel("Missing \(book.rarity.name) book")
        }
    }

    private func band() -> some View {
        VStack(spacing: 2) {
            Rectangle().fill(Self.gilt).frame(height: 1.2)
            Rectangle().fill(Self.gilt).frame(height: 1.2)
        }
        .padding(.horizontal, 2)
    }

    private func ridge() -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
            Rectangle().fill(.black.opacity(0.45)).frame(height: 1.5)
        }
        .padding(.horizontal, 1)
    }

    /// Each genre's covers share a colour family.
    private static func cover(_ book: LmpBook) -> Color {
        switch book.genre {
        case "Mystery": return Color(red: 0.20, green: 0.24, blue: 0.36)
        case "Romance": return Color(red: 0.45, green: 0.22, blue: 0.28)
        case "Adventure": return Color(red: 0.22, green: 0.36, blue: 0.26)
        case "Poetry": return Color(red: 0.34, green: 0.26, blue: 0.42)
        case "Cookbooks": return Color(red: 0.50, green: 0.34, blue: 0.18)
        case "Spring": return Color(red: 0.42, green: 0.30, blue: 0.40)     // M8 round 4: the seasons' treasures
        case "Summer": return Color(red: 0.22, green: 0.38, blue: 0.44)
        case "Autumn": return Color(red: 0.52, green: 0.28, blue: 0.14)
        case "Winter": return Color(red: 0.26, green: 0.32, blue: 0.44)
        default: return Color(red: 0.36, green: 0.30, blue: 0.22)
        }
    }

    private func bookCard(_ book: LmpBook) -> some View {
        let owned = shop.save.owned[book.id]
        return VStack(spacing: 10) {
            Text(book.rarity.name.uppercased())
                .font(.orbitron(12, .black))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(LmpTableView.rarityColor(book.rarity), in: Capsule())
            Text(book.title)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
            Text(book.editionLine)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
            if let owned {
                Text("Found \(owned.firstFound.formatted(date: .abbreviated, time: .omitted))"
                     + (owned.count > 1 ? " · \(owned.count) copies (the spares are lent out)" : ""))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }
}
