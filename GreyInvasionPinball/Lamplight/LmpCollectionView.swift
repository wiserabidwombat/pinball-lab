// Pinball Lab Table 05 (The Lamplight): the collection book (milestone 6 round 2).
// One shelf per genre: books you've found in colour with their rarity ribbon, missing ones as silhouettes (their ribbon
// still shows how rare they are). Tap a found book for its edition, when you found it and how many copies. The book
// also keeps the shop's numbers (days played, best evening, tips) and, at the bottom, "Start a new shop".
import SwiftUI

struct LmpCollectionView: View {
    let onClose: () -> Void
    @State private var selected: LmpBook?
    @State private var confirmNewShop = false
    private var shop: LmpShop { LmpShop.shared }

    private static let paper = Color(red: 0.13, green: 0.10, blue: 0.08)
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    catalog
                    perches
                    ForEach(LmpShop.genres.map { $0.name }, id: \.self) { genre in
                        shelf(genre)
                    }
                    // M8 round 4: the seasonal treasures, six a season, found only in their season.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SEASONAL TREASURES")
                            .font(.orbitron(13, .bold))
                            .tracking(1.5)
                            .foregroundStyle(LmpTableView.gold)
                        Text("Found only in their season; a missed one comes back next year.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    ForEach(LmpSeason.allCases, id: \.self) { season in
                        shelf(season.name, books: LmpShop.treasures(of: season))
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
            .alert("Start a new shop?", isPresented: $confirmNewShop) {
                Button("Start over", role: .destructive) { shop.startNewShop() }
                Button("Keep my shop", role: .cancel) { }
            } message: {
                Text("Every book, tip and day played is cleared. This can't be undone.")
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Books \(shop.booksOwned) of \(LmpShop.books.count)")
                .font(.orbitron(20, .black))
                .foregroundStyle(LmpTableView.gold)
            Text("\(shop.seasonLine) · best evening \(shop.save.bestEvening.formatted()) · \(shop.save.tips) tips")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 10) {
                ForEach(LmpRarity.allCases, id: \.self) { r in
                    HStack(spacing: 4) {
                        Circle().fill(LmpTableView.rarityColor(r)).frame(width: 8, height: 8)
                        Text(r.name).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.top, 12)
    }

    /// M8 round 3: the catalog's cozy pieces. Bought ones go into a free cozy spot; tap to move them in or out.
    private var catalog: some View {
        let used = shop.placedCozy.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("THE CATALOG")
                    .font(.orbitron(13, .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("COZY SPOTS \(used) / \(LmpShop.cozySpots)")
                    .font(.orbitron(12, .bold))
                    .foregroundStyle(LmpTableView.gold)
            }
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
                            .tint(Color(red: 0.62, green: 0.40, blue: 0.20))
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
            Text("Up to three pieces sit in your cozy spots and change play; tap one you own to take it out or put it back.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    /// M6 round 3: the cat's perches. Each one bought adds a spot she roams to; the sentence says what she does there.
    private var perches: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE CAT'S PERCHES")
                .font(.orbitron(13, .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.9))
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
                            .tint(Color(red: 0.62, green: 0.40, blue: 0.20))
                            .disabled(shop.save.tips < perch.price)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            Text("Tips come from your score at closing (1 per \(LmpShop.pointsPerTip.formatted()) points) and from lending spare books.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func shelf(_ genre: String, books given: [LmpBook]? = nil) -> some View {
        let books = given ?? LmpShop.books.filter { $0.genre == genre }
        let owned = books.filter { shop.owns($0) }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(genre.uppercased())
                    .font(.orbitron(13, .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(owned == books.count ? "SHELF COMPLETE" : "\(owned) / \(books.count)")
                    .font(.orbitron(12, .bold))
                    .foregroundStyle(owned == books.count ? LmpTableView.gold : .white.opacity(0.55))
            }
            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(books) { book in
                    spine(book)
                        .onTapGesture { if shop.owns(book) { selected = book } }
                }
            }
            Rectangle()                                   // the shelf board
                .fill(Color(red: 0.42, green: 0.28, blue: 0.16))
                .frame(height: 5)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    /// A found book: its title on a warm cover with a rarity ribbon. A missing one: a dark silhouette, ribbon dimmed.
    private func spine(_ book: LmpBook) -> some View {
        let found = shop.owns(book)
        let ribbon = LmpTableView.rarityColor(book.rarity)
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5)
                .fill(found ? Self.cover(book) : Color.white.opacity(0.06))
            RoundedRectangle(cornerRadius: 5)
                .stroke(found ? ribbon.opacity(0.9) : Color.white.opacity(0.12), lineWidth: found ? 1.5 : 1)
            Rectangle()
                .fill(ribbon.opacity(found ? 1 : 0.35))
                .frame(height: 5)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.horizontal, 6)
                .padding(.top, 5)
            Group {
                if found {
                    Text(book.title)
                        .font(.system(size: 10.5, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("?")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 5)
            .padding(.top, 14)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 82)
        .accessibilityLabel(found ? "\(book.title), \(book.rarity.name)" : "Missing \(book.rarity.name) book")
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
