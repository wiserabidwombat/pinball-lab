// Pinball Lab Table 06 (Orbit: Grand Tour): the table's screen. Milestone 1 = Monsoon's shell, trimmed: menu, LED
// score strip, pause and game over cards, the camera button and "‹ Tables". How to Play, Improve mode and the labs
// come in later milestones. Sound and haptics settings are on the Pinball Lab gear; credits are Pinball Lab's.
import SwiftUI
import SpriteKit
import Foundation

struct TourTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: TourGameState
    @State private var settings: GameSettings
    @State private var scene: TourTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @Environment(\.scenePhase) private var scenePhase

    /// Rocket-exhaust amber, the table's accent.
    static let gold = Color(red: 1.0, green: 0.70, blue: 0.32)
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = TourGameState()
        let settings = GameSettings()
        let scene = TourTableScene(game: game, settings: settings)
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
            LabGamepad.shared.claim("grandtour", onA: { gamepadA() }, onMenu: { gamepadMenu() })
            #if DEBUG
            // `-shotlab grandtour [-shotlab-flippers left,right] [-shotlab-start inlane|drop]`: the Shot Lab sweep
            // unattended (tools/shotlab_run.sh grandtour), as on the other tables.
            // M4 v1: `-playlab grandtour` (tools/playlab_run.sh grandtour): the Play Lab unattended (quits when done).
            if PlayLab.launchTable == "grandtour" {
                Task { @MainActor in
                    while scene.view == nil && scene.hostView == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .milliseconds(500))
                    screen = .playing
                    setPaused(false)
                    scene.debugStartPlayLab()
                }
            }
            if PlayLab.launchTable == nil, ShotLab.launchTable == "grandtour" {
                Task { @MainActor in
                    while scene.view == nil && scene.hostView == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .milliseconds(500))
                    screen = .playing
                    setPaused(false)
                    if ShotLab.launchScenario == "plungeprobe" { scene.debugPlungeProbe() } else if ShotLab.launchScenario == "roctrap" { scene.debugRocProbe() } else if ShotLab.launchScenario == "rampride" { scene.debugRideProbe() } else { scene.debugStartShotLab() }
                }
            }
            #endif
        }
        .onDisappear { LabGamepad.shared.release("grandtour") }
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
                    Text("ORBIT: GRAND TOUR")
                        .font(.orbitron(30, .black))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(Self.gold)
                    Text("TABLE 06 · PINBALL LAB")
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
            // What-if overrides typed here (LabOverrides.swift): applied at once, until the app quits (Tour.flipUp …).
            LabOverridesField()
            // The Shot Lab robot (~25 min in the Simulator; results go to ShotLab/ on the Mac).
            debugButton("Shot Lab") { scene.debugStartShotLab(); setPaused(false) }
            // Play Lab (shared): robot players at four skills, 120 Hz and 60 Hz passes (~1 h in the Simulator).
            debugButton("Play Lab") { scene.debugStartPlayLab(); setPaused(false) }
            debugButton("Play Lab · quick") { PlayLab.nextRunIsQuick = true; scene.debugStartPlayLab(); setPaused(false) }
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
                .background(prominent ? Color(red: 0.22, green: 0.30, blue: 0.62) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}
