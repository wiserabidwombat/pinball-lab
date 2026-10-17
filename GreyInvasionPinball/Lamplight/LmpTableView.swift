// Pinball Lab Table 05 (The Lamplight): the table's screen. Milestone 1 = Monsoon's shell, trimmed: menu, LED score
// strip, pause and game over cards, the camera button and "‹ Tables". The shop's collection book comes later.
import SwiftUI
import SpriteKit
import Foundation

struct LmpTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: LmpGameState
    @State private var settings: GameSettings
    @State private var scene: LmpTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @State private var showCollection = false      // M6 round 2: the collection book
    @Environment(\.scenePhase) private var scenePhase

    /// Lamp amber, the table's accent (the warm light in the shop window).
    static let gold = Color(red: 1.0, green: 0.74, blue: 0.40)
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = LmpGameState()
        let settings = GameSettings()
        let scene = LmpTableScene(game: game, settings: settings)
        scene.isAttractMode = true
        _game = State(initialValue: game)
        _settings = State(initialValue: settings)
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [])
                .ignoresSafeArea()

            if screen == .playing {
                playingOverlay
            }

            switch screen {
            case .menu:
                menuOverlay
            case .playing where isPaused:
                pauseOverlay
            case .playing where game.isGameOver:
                gameOverOverlay
            default:
                EmptyView()
            }
        }
        .fullScreenCover(isPresented: $showCollection) {
            LmpCollectionView { showCollection = false }
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: settings.cameraMode) { _, _ in
            scene.refreshCamera()
        }
        .onAppear {
            // Game controller: A = Play / Resume / Play Again, Menu = pause (flippers and plunger: the scene)
            LabGamepad.shared.claim("lamplight", onA: { gamepadA() }, onMenu: { gamepadMenu() })
        }
        .onDisappear { LabGamepad.shared.release("lamplight") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, screen == .playing, !game.isGameOver {
                setPaused(true)
            }
        }
    }

    // MARK: - Actions

    private func startGame() {
        scene.newGame()
        screen = .playing
        setPaused(false)
    }

    private func goToMenu() {
        screen = .menu
        isPaused = false
        scene.isGamePaused = false
        scene.isAttractMode = true
    }

    private func gamepadA() {
        guard !showCollection else { return }
        switch screen {
        case .menu:
            startGame()
        case .playing:
            if isPaused { setPaused(false) } else if game.isGameOver { startGame() }
        }
    }

    private func gamepadMenu() {
        guard !showCollection, screen == .playing, !game.isGameOver else { return }
        setPaused(!isPaused)
    }

    private func setPaused(_ paused: Bool) {
        isPaused = paused
        scene.isGamePaused = paused
    }

    // MARK: - HUD

    private var playingOverlay: some View {
        VStack {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    setPaused(true)
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("Pause")
                .disabled(game.isGameOver)

                ledStrip.allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            if let find = game.findToast {
                findCard(find)
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }

            Spacer()

            if game.ballOnPlunger && !game.isGameOver && settings.tipsOn {
                Text("Pull down on the plunger to launch")
                    .font(.orbitron(13))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Balls left and the score on a dark LED panel; the bottom row shows messages.
    private var ledStrip: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<max(min(game.ballsLeft, 5), 0), id: \.self) { _ in
                        Circle()
                            .fill(Self.gold)
                            .frame(width: 8, height: 8)
                            .shadow(color: Self.gold.opacity(0.8), radius: 3)
                    }
                }
                .accessibilityLabel("Balls \(game.ballsLeft)")
                Spacer(minLength: 4)
                Text(game.score.formatted())
                    .font(.orbitron(18, .black))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Self.gold)
                    .shadow(color: Self.gold.opacity(0.7), radius: 6)
            }
            Group {
                if let banner = game.banner {
                    Text(banner)
                        .font(.orbitron(14, .bold))
                        .foregroundStyle(Self.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 17)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.gold.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Overlays

    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 6) {
                    Text("THE LAMPLIGHT")
                        .font(.orbitron(36, .black))
                        .foregroundStyle(Self.gold)
                    Text("TABLE 05 · PINBALL LAB")
                        .font(.orbitron(12, .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)
                }
                .shadow(color: Self.gold.opacity(0.6), radius: 12)

                Text("A cozy bookshop-café · being built")
                    .font(.orbitron(13))
                    .foregroundStyle(.white.opacity(0.7))
                Text(shopLine)
                    .font(.orbitron(13))
                    .monospacedDigit()
                    .foregroundStyle(Self.gold.opacity(0.85))
                Spacer()

                overlayButton("Play", prominent: true, action: startGame)
                overlayButton("The Collection") { showCollection = true }
                cameraButton

                Text("Touch left or right to flip · pull down to launch")
                    .font(.system(.footnote))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onExit) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Tables")
                }
                .font(.orbitron(14, .bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .padding(.leading, 16)
            .padding(.top, 12)
            .accessibilityLabel("Back to all tables")
        }
    }

    private var pauseOverlay: some View {
        overlayCard {
            Text("Paused")
                .font(.orbitron(30, .black))
            Text("Score \(game.score.formatted())")
                .font(.orbitron(17))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
            // M6 round 3: where the cat is and what she does there.
            VStack(spacing: 2) {
                Text("The cat is \(game.catPerch.spot)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Self.gold)
                Text(game.catPerch.effect)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            overlayButton("Resume", prominent: true) { setPaused(false) }
                .padding(.top, 8)
            cameraButton
            volumeRow
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
            #if DEBUG
            // Milestone 5: the Shot Lab robot (~40 min in the Simulator; results go to ShotLab/ on the Mac)
            debugButton("Shot Lab") { scene.debugStartShotLab(); setPaused(false) }
                .padding(.top, 4)
            #endif
        }
    }



    #if DEBUG
    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.25), in: Capsule())
        }
        .foregroundStyle(.orange)
    }
    #endif

    // MARK: - Finds (milestone 6)

    /// "Books 12 / 120 · Day 4" (the shop's progress, from the save file).
    private var shopLine: String {
        let shop = LmpShop.shared
        return "Books \(shop.booksOwned) / \(LmpShop.books.count) · Day \(shop.save.daysPlayed + 1)"
    }

    static func rarityColor(_ r: LmpRarity) -> Color {
        switch r {
        case .common: return Color(white: 0.85)
        case .uncommon: return Color(red: 0.55, green: 0.85, blue: 0.55)
        case .rare: return Color(red: 0.45, green: 0.70, blue: 1.0)
        case .veryRare: return Color(red: 0.78, green: 0.55, blue: 1.0)
        case .ultraRare: return Color(red: 1.0, green: 0.80, blue: 0.30)
        }
    }

    /// The find card under the score: NEW BOOK (or "Another copy") with its rarity ribbon, then the title.
    private func findCard(_ find: LmpFind) -> some View {
        let color = Self.rarityColor(find.book.rarity)
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text(find.isNew ? "NEW BOOK" : "ANOTHER COPY · LENT FOR A TIP")
                    .font(.orbitron(11, .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(find.book.rarity.name.uppercased())
                    .font(.orbitron(11, .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color, in: Capsule())
            }
            Text(find.book.title)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(find.book.genre) · \(find.book.rarity.edition)")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.8), lineWidth: 1.5))
        .padding(.horizontal, 40)
    }

    private var gameOverOverlay: some View {
        overlayCard {
            Text("Closing Time")
                .font(.orbitron(30, .black))
            Text("Score \(game.score.formatted())")
                .font(.orbitron(22, .bold))
                .monospacedDigit()
            Text("Best evening \(game.bestEvening.formatted())")
                .font(.orbitron(15))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
            // M6: what tonight found, and the whole collection so far.
            Text(game.findsTonight == 0 ? "No books found tonight"
                 : "Found \(game.findsTonight) book\(game.findsTonight == 1 ? "" : "s") tonight · \(game.newTonight) new")
                .font(.orbitron(14, .bold))
                .foregroundStyle(Self.gold)
            Text(shopLine)
                .font(.orbitron(13))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
            overlayButton("Play Again", prominent: true, action: startGame)
            overlayButton("The Collection") { showCollection = true }
                .padding(.top, 8)
            overlayButton("Menu", action: goToMenu)
        }
    }

    /// Cycles Flying → Wide → Top-Down (the same saved setting as Grey Invasion's).
    private var cameraButton: some View {
        overlayButton("Camera: \(settings.cameraMode.label)") {
            settings.cameraMode = settings.cameraMode.next
        }
    }

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.soundVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .frame(width: 24)
            Slider(value: $settings.soundVolume, in: 0...1)
                .tint(Self.gold)
        }
        .frame(maxWidth: 240)
        .accessibilityLabel("Sound volume")
    }

    private func overlayCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12, content: content)
                .foregroundStyle(.white)
                .padding(28)
                .frame(maxWidth: 300)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .environment(\.colorScheme, .dark)
        }
    }

    private func overlayButton(_ title: String, prominent: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.orbitron(17, .bold))
                .frame(maxWidth: 240)
                .padding(.vertical, 12)
                .background(prominent ? Color(red: 0.62, green: 0.40, blue: 0.20) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}
