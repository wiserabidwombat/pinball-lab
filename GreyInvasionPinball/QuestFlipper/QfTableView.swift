// Pinball Lab Table 09 (Quest & Flipper): the table's screen, from Neon Labyrinth's (CHOMP!'s) with the "Qf" prefix.
// T9 M1 v1: menu, LED strip with the run's HP and the score, the plunger hint, pause (with the camera button) and game
// over cards, "‹ Tables". How to Play and the labs come later.
import SwiftUI
import SpriteKit
import Foundation

struct QfTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: QfGameState
    @State private var settings: GameSettings
    @State private var scene: QfTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @Environment(\.scenePhase) private var scenePhase

    /// Lantern amber, the table's accent (lantern light is the forest's only warm colour).
    static let accent = Color(red: 1.0, green: 0.72, blue: 0.30)
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = QfGameState()
        let settings = GameSettings()
        let scene = QfTableScene(game: game, settings: settings)
        scene.isAttractMode = true
        _game = State(initialValue: game)
        _settings = State(initialValue: settings)
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack {
            TableSKView(scene: scene, preferredFramesPerSecond: DisplayRate.max)   // 120 or the screen's 60; SKRenderer on devices (iPad pacing)
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
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: settings.cameraMode) { _, _ in
            scene.refreshCamera()
        }
        .onAppear {
            // Game controller: A = Play / Resume / Play Again, Menu = pause (flippers and plunger: the scene)
            LabGamepad.shared.claim("quest", onA: { gamepadA() }, onMenu: { gamepadMenu() })
            #if DEBUG
            // DEBUG `-playlab quest -questRampProbe`: fires balls up the Old Road at rising speeds (prints RAMPPROBE).
            if ProcessInfo.processInfo.arguments.contains("-questRampProbe") {
                Task { @MainActor in
                    while scene.view == nil && scene.hostView == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .milliseconds(500))
                    screen = .playing
                    setPaused(false)
                    scene.debugStartRampProbe()
                }
            }
            #endif
        }
        .onDisappear { LabGamepad.shared.release("quest") }
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
        switch screen {
        case .menu:
            startGame()
        case .playing:
            if isPaused { setPaused(false) } else if game.isGameOver { startGame() }
        }
    }

    private func gamepadMenu() {
        guard screen == .playing, !game.isGameOver else { return }
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
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The run's HP and the score on a dark LED panel; the bottom row shows messages.
    private var ledStrip: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(hpColor)
                    Text("\(game.hp)/\(game.maxHP)")
                        .font(.orbitron(13, .bold))
                        .monospacedDigit()
                        .foregroundStyle(hpColor)
                }
                .accessibilityLabel("Health \(game.hp) of \(game.maxHP)")
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
                    .foregroundStyle(Self.accent)
                    .shadow(color: Self.accent.opacity(0.7), radius: 6)
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
                        .foregroundStyle(Self.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else if let status = game.status {
                    Text(status)
                        .font(.orbitron(12, .bold))
                        .foregroundStyle(Self.accent.opacity(0.6))
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.accent.opacity(0.35), lineWidth: 1))
    }

    /// Red when one more drain would end the game.
    private var hpColor: Color {
        game.hp <= game.run.damagePerDrain ? Color(red: 1.0, green: 0.35, blue: 0.30) : Self.accent
    }

    // MARK: - Overlays

    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 6) {
                    Text("QUEST & FLIPPER")
                        .font(.orbitron(30, .black))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(Self.accent)
                    Text("THE HAUNTED FOREST · TABLE 09")
                        .font(.orbitron(12, .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)
                }
                .shadow(color: Self.accent.opacity(0.6), radius: 12)

                if game.highScore > 0 {
                    Text("High score \(game.highScore.formatted())")
                        .font(.orbitron(15))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()

                overlayButton("Play", prominent: true, action: startGame)

                Text("Touch left or right to flip · pull down to launch · drains cost HP")
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
            volumeRow
            overlayButton("Camera: \(settings.cameraMode.label)") {
                settings.cameraMode = settings.cameraMode.next
            }
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
        }
    }

    private var gameOverOverlay: some View {
        overlayCard {
            Text(game.leftForest ? "You Escaped" : "Game Over")
                .font(.orbitron(30, .black))
            if game.leftForest {
                Text("Out of the Haunted Forest with \(game.hp) HP")
                    .font(.orbitron(13))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
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

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.soundVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .frame(width: 24)
            Slider(value: $settings.soundVolume, in: 0...1)
                .tint(Self.accent)
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
                .background(prominent ? Color(red: 0.22, green: 0.30, blue: 0.62) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}
