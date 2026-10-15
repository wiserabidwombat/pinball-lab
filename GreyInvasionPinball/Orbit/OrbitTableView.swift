// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was ContentView.swift.
import SwiftUI
import SpriteKit

struct OrbitTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: OrbitGameState
    @State private var scene: OrbitTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @State private var showCredits = false
    @Environment(\.scenePhase) private var scenePhase
    /// Pinball Lab: back to the table list (the "Tables" link on the menu).
    private let onExit: () -> Void
    /// Pinball Lab: the shared settings (sound volume, haptics). Loading them also applies the haptics switch.
    @State private var settings = GameSettings()

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = OrbitGameState()
        let scene = OrbitTableScene(game: game)
        scene.isGamePaused = true          // the menu shows a frozen table behind it
        _game = State(initialValue: game)
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack {
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: 60,   // Pinball Lab: Orbit was built and tuned at 60 fps; keep its physics as they were
                options: [],   // draw children in order (layered sprites rely on it)
                debugOptions: debugOptions
            )
            .ignoresSafeArea()

            if screen == .playing {
                playingOverlay
            }

            if let banner = game.banner, screen == .playing, !game.isGameOver, !isPaused {
                Text(banner)
                    .font(.orbitron(34, .black))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 8)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
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
        .animation(.spring(duration: 0.25), value: game.banner)
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showCredits) {
            OrbitCreditsView()
        }
        .onAppear {
            OrbitSoundPlayer.volume = Float(settings.soundVolume)
            LabGamepad.shared.claim("orbit", onA: { gamepadA() }, onMenu: { gamepadMenu() })
        }
        .onDisappear { LabGamepad.shared.release("orbit") }
        .onChange(of: scenePhase) { _, phase in
            // Auto-pause whenever the app leaves the foreground mid-game.
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
        scene.isGamePaused = true
    }

    // Game controller (Pinball Lab): A = Play on the menu, Resume when paused, Play Again after a game;
    // Menu = pause / resume while playing. Ignored while a card is open over the table.
    private func gamepadA() {
        guard !showCredits else { return }
        switch screen {
        case .menu:
            startGame()
        case .playing:
            if isPaused { setPaused(false) } else if game.isGameOver { startGame() }
        }
    }

    private func gamepadMenu() {
        guard !showCredits, screen == .playing, !game.isGameOver else { return }
        setPaused(!isPaused)
    }

    private func setPaused(_ paused: Bool) {
        isPaused = paused
        scene.isGamePaused = paused
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        return [.showsFPS]
        #else
        return []
        #endif
    }

    // MARK: - In-game HUD

    private var playingOverlay: some View {
        VStack {
            HStack(spacing: 12) {
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

                hud.allowsHitTesting(false)
            }
            .padding(.leading, 16)
            .padding(.trailing, 24)
            .padding(.top, 4)

            Spacer()

            if game.ballOnPlunger && !game.isGameOver {
                Text("Pull down on the plunger to launch")
                    .font(.orbitron(13))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 40)
                    .allowsHitTesting(false)
            }
        }
    }

    private var hud: some View {
        HStack(spacing: 10) {
            Text("Balls \(game.ballsLeft)")
            if game.ballSaveActive {
                Text("SAVE")
                    .foregroundStyle(.green)
            }
            Spacer()
            if game.multiplier > 1 {
                Text("\(game.multiplier)x")
                    .foregroundStyle(.yellow)
            }
            Text("\(game.score)")
        }
        .font(.orbitron(15, .bold))
        .monospacedDigit()
        .foregroundStyle(.white)
    }

    // MARK: - Overlays

    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 4) {
                    Text("ORBIT")
                        .font(.orbitron(52, .black))
                    Text("PINBALL")
                        .font(.orbitron(26, .bold))
                        .tracking(8)
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                }
                .shadow(color: .purple.opacity(0.8), radius: 12)

                if game.highScore > 0 {
                    Text("High score \(game.highScore)")
                        .font(.orbitron(15))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()

                overlayButton("Play", prominent: true, action: startGame)
                overlayButton("Credits") { showCredits = true }

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
            // Pinball Lab: back to the table list.
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
            Text("Score \(game.score)")
                .font(.orbitron(17))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
            overlayButton("Resume", prominent: true) { setPaused(false) }
                .padding(.top, 8)
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
        }
    }

    private var gameOverOverlay: some View {
        overlayCard {
            Text("Game Over")
                .font(.orbitron(30, .black))
            Text("Score \(game.score)")
                .font(.orbitron(22, .bold))
                .monospacedDigit()
            if game.isNewHighScore {
                Text("New high score!")
                    .font(.orbitron(17, .bold))
                    .foregroundStyle(.yellow)
            } else {
                Text("High score \(game.highScore)")
                    .font(.orbitron(15))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            overlayButton("Play Again", prominent: true, action: startGame)
                .padding(.top, 8)
            overlayButton("Menu", action: goToMenu)
        }
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
                .background(prominent ? Color(red: 0.3, green: 0.55, blue: 1.0) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}

/// In-app credits for every third-party asset (matches CREDITS.md).
struct OrbitCreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Art") {
                    credit("Planets", "Kenney · kenney.nl", "CC0 1.0 (public domain)")
                    credit("Space Shooter Remastered", "Kenney · kenney.nl",
                           "CC0 1.0 (public domain) — asteroids, wormhole ring, stars")
                }
                Section("Sound") {
                    credit("Sci-fi Sounds", "Kenney · kenney.nl", "CC0 1.0 (public domain)")
                    credit("Impact Sounds", "Kenney · kenney.nl", "CC0 1.0 (public domain)")
                }
                Section("Font") {
                    credit("Orbitron", "The Orbitron Project Authors",
                           "SIL Open Font License 1.1")
                }
                Section("Made with") {
                    Text("Swift, SwiftUI and SpriteKit")
                }
                Section {
                    Text("Thanks to Kenney for the free game assets.")
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

    private func credit(_ title: String, _ author: String, _ license: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(author).font(.subheadline)
            Text(license).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    OrbitTableView()
}
