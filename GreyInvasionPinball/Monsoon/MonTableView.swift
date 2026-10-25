// Pinball Lab Table 04 (Monsoon): the table's screen. Milestone 1 = Table 03's shell, trimmed: menu, LED score
// strip, pause and game over cards, the camera button and "‹ Tables". Polish round 1 adds How to Play (menu and pause).
// Sound and haptics settings are on the Pinball Lab gear; credits are Pinball Lab's.
import SwiftUI
import SpriteKit
import Foundation

struct MonTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: MonGameState
    @State private var settings: GameSettings
    @State private var scene: MonTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @State private var showHowTo = false         // polish round 1: How to Play (menu and pause)
    @Environment(\.scenePhase) private var scenePhase

    /// Storm-light gold, the table's accent (the light breaking through in the painting).
    static let gold = Color(red: 0.96, green: 0.78, blue: 0.45)
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = MonGameState()
        let settings = GameSettings()
        let scene = MonTableScene(game: game, settings: settings)
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

            if showHowTo {
                MonHowToPlayView { showHowTo = false }
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: settings.cameraMode) { _, _ in
            scene.refreshCamera()
        }
        .onAppear {
            // Game controller: A = Play / Resume / Play Again, Menu = pause (flippers and plunger: the scene)
            LabGamepad.shared.claim("monsoon", onA: { gamepadA() }, onMenu: { gamepadMenu() })
            #if DEBUG
            // Launched with `-playlab monsoon`: run the Play Lab unattended (the scene quits the app when done).
            if PlayLab.launchTable == "monsoon" {
                Task { @MainActor in
                    while scene.view == nil { try? await Task.sleep(for: .milliseconds(100)) }   // built in didMove
                    try? await Task.sleep(for: .milliseconds(500))
                    screen = .playing
                    setPaused(false)
                    scene.debugStartPlayLab()
                }
            }
            #endif
        }
        .onDisappear { LabGamepad.shared.release("monsoon") }
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
        guard !showHowTo else { return }
        switch screen {
        case .menu:
            startGame()
        case .playing:
            if isPaused { setPaused(false) } else if game.isGameOver { startGame() }
        }
    }

    private func gamepadMenu() {
        guard !showHowTo, screen == .playing, !game.isGameOver else { return }
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
                if game.multiplier > 1 {
                    Text("\(game.multiplier)X")
                        .font(.orbitron(14, .black))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.6), radius: 4)
                }
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
                if let bonus = game.bonusText {
                    Text(bonus)
                        .font(.orbitron(14, .bold))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else if let banner = game.banner {
                    Text(banner)
                        .font(.orbitron(14, .bold))
                        .foregroundStyle(Self.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else if let status = game.status {
                    Text(status)
                        .font(.orbitron(12, .bold))
                        .foregroundStyle(Self.gold.opacity(0.6))
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
                    Text("MONSOON")
                        .font(.orbitron(36, .black))
                        .foregroundStyle(Self.gold)
                    Text("TABLE 04 · PINBALL LAB")
                        .font(.orbitron(12, .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)
                }
                .shadow(color: Self.gold.opacity(0.6), radius: 12)

                if game.highScore > 0 {
                    Text("High score \(game.highScore.formatted())")
                        .font(.orbitron(15))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()

                overlayButton("Play", prominent: true, action: startGame)
                overlayButton("How to Play") { showHowTo = true }
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
            overlayButton("Resume", prominent: true) { setPaused(false) }
                .padding(.top, 8)
            overlayButton("How to Play") { showHowTo = true }
            cameraButton
            volumeRow
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
            #if DEBUG
            // Look development (M2): lay a wash, fill the lower table, or go back to the sketch.
            HStack(spacing: 8) {
                debugButton("Wash") { scene.debugWash(); setPaused(false) }
                debugButton("Fill") { scene.debugFill(); setPaused(false) }
                debugButton("Sketch") { scene.debugSketch(); setPaused(false) }
            }
            // M4 round 2: flip the diverter at the top of the mesa ramp (helix ↔ high wire).
            HStack(spacing: 8) {
                debugButton("Diverter") { scene.debugToggleDiverter(); setPaused(false) }
                // M5: make the dust devil rage (or calm it)
                debugButton("Dust devil") { scene.debugToggleDustDevil(); setPaused(false) }
            }
            .padding(.top, 4)
            // M8 v3: light Monsoon without painting three regions first
            HStack(spacing: 8) {
                debugButton("Light Monsoon") { scene.debugLightMonsoon(); setPaused(false) }
                debugButton("Light Superbloom") { scene.debugLightSuperbloom(); setPaused(false) }
            }
            .padding(.top, 4)
            // M6: the Shot Lab robot (~25 min each in the Simulator; results go to ShotLab/ on the Mac)
            HStack(spacing: 8) {
                debugButton("Shot Lab") { scene.debugStartShotLab(devilRaging: false); setPaused(false) }
                debugButton("Lab: devil raging") { scene.debugStartShotLab(devilRaging: true); setPaused(false) }
            }
            .padding(.top, 4)
            // Play Lab (shared): robot players at four skills, 120 Hz and 60 Hz passes (~1 h in the Simulator).
            debugButton("Play Lab") { scene.debugStartPlayLab(); setPaused(false) }
            // Plan 2 round 6: one expert game at the phone's own step, 3-minute cap, the report shared when done.
            debugButton("Play Lab · quick") { PlayLab.nextRunIsQuick = true; scene.debugStartPlayLab(); setPaused(false) }
            // Plan 2 round 12: one game of your own, watched by the lab (no robot), the report shared when it ends.
            debugButton("Record me") { PlayLab.nextRunIsRecording = true; scene.debugStartPlayLab(); setPaused(false) }
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


    private var gameOverOverlay: some View {
        overlayCard {
            Text("Game Over")
                .font(.orbitron(30, .black))
            Text("Score \(game.score.formatted())")
                .font(.orbitron(22, .bold))
                .monospacedDigit()
            if game.isNewHighScore {
                Text("New high score!")
                    .font(.orbitron(17, .bold))
                    .foregroundStyle(.yellow)
            } else {
                Text("High score \(game.highScore.formatted())")
                    .font(.orbitron(15))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            overlayButton("Play Again", prominent: true, action: startGame)
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
                .background(prominent ? Color(red: 0.42, green: 0.33, blue: 0.58) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}
