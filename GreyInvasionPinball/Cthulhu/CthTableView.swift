// Pinball Lab Table 03 (Cthulhu Rising): the table's screen. Milestone 1 = Grey Invasion's shell, trimmed:
// menu, LED score strip, pause and game over cards, the camera button and "‹ Tables". Polish round 1 adds How to
// Play (menu and pause). Sound and haptics settings are on the Pinball Lab gear; credits are Pinball Lab's.
import SwiftUI
import SpriteKit
import Foundation

struct CthTableView: View {
    private enum Screen { case menu, playing }

    @State private var game: CthGameState
    @State private var settings: GameSettings
    @State private var scene: CthTableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @State private var showHowTo = false         // polish round 1: How to Play (menu and pause)
    @State private var showCoachKey = false      // Improve mode: the colour key (first time with Improve on, and the pause card)
    @Environment(\.scenePhase) private var scenePhase

    /// Sickly sea-green, the table's accent.
    static let seaGreen = Color(red: 0.30, green: 0.85, blue: 0.75)
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = CthGameState()
        let settings = GameSettings()
        let scene = CthTableScene(game: game, settings: settings)
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
                CthHowToPlayView { showHowTo = false }
            }

            if showCoachKey {
                CoachKeyView(table: "Cthulhu Rising", entries: CthCoachBands.key) {
                    showCoachKey = false
                    CoachKey.markSeen("cthulhu")
                }
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
            LabGamepad.shared.claim("cthulhu", onA: { gamepadA() }, onMenu: { gamepadMenu() })
            #if DEBUG
            // Launched with `-playlab cthulhu`: run the Play Lab unattended (the scene quits the app when done).
            if PlayLab.launchTable == "cthulhu" {
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
        .onDisappear { LabGamepad.shared.release("cthulhu") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, screen == .playing, !game.isGameOver {
                setPaused(true)
            }
        }
    }

    // MARK: - Actions

    private func startGame() {
        scene.newGame()
        if settings.improveOn, !CoachKey.seen("cthulhu") { showCoachKey = true }   // Improve was already on: show the key once
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
        if showCoachKey { showCoachKey = false; CoachKey.markSeen("cthulhu"); return }
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
                            .fill(Self.seaGreen)
                            .frame(width: 8, height: 8)
                            .shadow(color: Self.seaGreen.opacity(0.8), radius: 3)
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
                    .foregroundStyle(Self.seaGreen)
                    .shadow(color: Self.seaGreen.opacity(0.7), radius: 6)
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
                        .foregroundStyle(Self.seaGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else if let status = game.status {
                    Text(status)
                        .font(.orbitron(12, .bold))
                        .foregroundStyle(Self.seaGreen.opacity(0.6))
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.seaGreen.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Overlays

    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 6) {
                    Text("CTHULHU")
                        .font(.orbitron(36, .black))
                    Text("RISING")
                        .font(.orbitron(24, .bold))
                        .tracking(8)
                        .foregroundStyle(Self.seaGreen)
                    Text("TABLE 03 · PINBALL LAB")
                        .font(.orbitron(12, .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)
                }
                .shadow(color: Self.seaGreen.opacity(0.6), radius: 12)

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
            if let tally = scene.drainTally {              // Improve mode: where this game's balls went
                VStack(spacing: 4) {
                    Text("DRAINS THIS GAME")
                        .font(.orbitron(10))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 22) {
                        ForEach(Array(tally.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: 1) {
                                Text("\(column.count)")
                                    .font(.orbitron(20, .bold))
                                    .monospacedDigit()
                                Text(column.label)
                                    .font(.orbitron(10))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            if let meter = scene.shotMeter {               // Improve mode: this game's made shots
                ShotMeterView(cells: meter)
            }
            overlayButton("Resume", prominent: true) { setPaused(false) }
                .padding(.top, 8)
            overlayButton("How to Play") { showHowTo = true }
            cameraButton
            overlayButton("Improve: \(settings.improveOn ? "On" : "Off")") {
                settings.improveOn.toggle()
                if settings.improveOn, !CoachKey.seen("cthulhu") { showCoachKey = true }   // the first time it's on here
            }
            if settings.improveOn {
                overlayButton("Colour Key") { showCoachKey = true }
            }
            volumeRow
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
            #if DEBUG
            // Shot Lab (milestone 5): the robot measures every shot's timing window from the left, right and
            // upper flippers (~40 min; run it in the Simulator). The second run keeps Cthulhu up and swaying.
            HStack(spacing: 8) {
                debugButton("Shot Lab") { scene.debugStartShotLab(cthulhuUp: false); setPaused(false) }
                debugButton("Lab: Cthulhu up") { scene.debugStartShotLab(cthulhuUp: true); setPaused(false) }
            }
            .padding(.top, 4)
            // Sling Lab (milestone 5 round 2): the same balls thrown at four sling designs (~30 min).
            debugButton("Sling Lab") { scene.debugStartSlingLab(); setPaused(false) }
            // Play Lab (shared): robot players at four skills, 120 Hz and 60 Hz passes (~1 h in the Simulator).
            debugButton("Play Lab") { scene.debugStartPlayLab(); setPaused(false) }
            // Plan 2 round 6: one expert game at the phone's own step, 3-minute cap, the report shared when done.
            debugButton("Play Lab · quick") { PlayLab.nextRunIsQuick = true; scene.debugStartPlayLab(); setPaused(false) }
            // Plan 2 round 12: one game of your own, watched by the lab (no robot), the report shared when it ends.
            debugButton("Record me") { PlayLab.nextRunIsRecording = true; scene.debugStartPlayLab(); setPaused(false) }
            // Rules shortcuts (M7 v2): skip ahead through the tomes, or straight to the Ritual.
            HStack(spacing: 8) {
                debugButton("Skip Tome") { scene.debugSkipTome(); setPaused(false) }
                debugButton("Light Ritual") { scene.debugLightRitual(); setPaused(false) }
                debugButton("Awaken") { scene.debugAwaken(); setPaused(false) }
            }
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
                .tint(Self.seaGreen)
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
                .background(prominent ? Color(red: 0.15, green: 0.55, blue: 0.50) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}
