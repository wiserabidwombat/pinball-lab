// Pinball Lab Table 07 (CHOMP! The Terror of Calamity Island): the table's screen. Milestone 1 = Table 06's M1 shell:
// menu, LED score strip, pause and game over cards, the camera button and "‹ Tables", plus the ACTION button (the
// inner tube save now; flip-lock and the wheel later). How to Play and the labs come in later milestones.
import SwiftUI
import SpriteKit
import Foundation

struct ChompTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: ChompGameState
    @State private var settings: GameSettings
    @State private var scene: ChompTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    /// The ACTION button acts on touch-down (a Button waits for the finger to lift; the save window is 0.6 s).
    @State private var actionDown = false
    @Environment(\.scenePhase) private var scenePhase

    /// Beach-umbrella yellow, the table's accent.
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.30)
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = ChompGameState()
        let settings = GameSettings()
        let scene = ChompTableScene(game: game, settings: settings)
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
            LabGamepad.shared.claim("chomp", onA: { gamepadA() }, onMenu: { gamepadMenu() })
            #if DEBUG
            // M4 v1: `-playlab chomp` (tools/playlab_run.sh chomp) starts the Play Lab at once; the app quits when done.
            if PlayLab.launchTable == "chomp" {
                Task { @MainActor in
                    while scene.view == nil && scene.hostView == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .milliseconds(500))
                    screen = .playing
                    setPaused(false)
                    scene.debugStartPlayLab()
                }
            }
            // M2 v6: `-shotlab chomp` (tools/shotlab_run.sh chomp) starts the Shot Lab at once; the app quits when done.
            if PlayLab.launchTable == nil, ShotLab.launchTable == "chomp" {
                Task { @MainActor in
                    while scene.view == nil && scene.hostView == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .milliseconds(500))
                    screen = .playing
                    setPaused(false)
                    if ShotLab.launchScenario == "fanprobe" { scene.debugFanProbe() } else if ShotLab.launchScenario == "pierprobe" { scene.debugPierProbe() } else if ShotLab.launchScenario == "dropprobe" { scene.debugDropProbe() } else if ShotLab.launchScenario == "catchprobe" { scene.debugCatchProbe() } else { scene.debugStartShotLab() }
                }
            }
            #endif
        }
        .onDisappear { LabGamepad.shared.release("chomp") }
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
                    .font(.orbitron(13))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }

            // The ACTION button, centred over the drain: arms the inner tube save for a moment.
            Image(systemName: "lifepreserver")
                .font(.system(size: 22, weight: .bold))
                .frame(width: 52, height: 52)
                .background(Self.gold.opacity(actionDown ? 0.5 : 0.22), in: Circle())
                .overlay(Circle().stroke(Self.gold.opacity(0.7), lineWidth: 1.5))
                .foregroundStyle(Self.gold)
                .contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !actionDown { actionDown = true; scene.actionPressed() }
                    }
                    .onEnded { _ in actionDown = false })
                .accessibilityElement()
                .accessibilityLabel("Action")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { scene.actionPressed() }
                .padding(.bottom, 8)
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
                    Text("CHOMP!")
                        .font(.orbitron(30, .black))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(Self.gold)
                    Text("TABLE 07 · PINBALL LAB")
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
            cameraButton
            volumeRow
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
            #if DEBUG
            // M5 v6c: light Kevin Multiball 2 or 3 now, to test them without playing up to them.
            HStack(spacing: 10) {
                overlayButton("KMB 2") { scene.debugReadyKMB(2); setPaused(false) }
                overlayButton("KMB 3") { scene.debugReadyKMB(3); setPaused(false) }
            }
            overlayButton("TAXI") { scene.debugStartRescue(); setPaused(false) }   // M5 v10 (v10b: own row)
            #endif
        }
    }

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
                .background(prominent ? Color(red: 0.22, green: 0.30, blue: 0.62) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}
