import SwiftUI
import SpriteKit
import Foundation

struct ContentView: View {
    private enum Screen { case menu, playing }

    @State private var game: GameState
    @State private var settings: GameSettings
    @State private var scene: TableScene
    @State private var screen: Screen = .menu
    @State private var isPaused = false
    @State private var showSettings = false      // M10: the settings card (from the menu or pause)
    @State private var showCredits = false       // M10 round 2: fonts, sounds and art credits
    @State private var showHowTo = false         // M10 v11: How to Play (menu and pause)
    @Environment(\.scenePhase) private var scenePhase

    private static let alienGreen = Color(red: 0.35, green: 0.95, blue: 0.55)
    /// Pinball Lab: back to the table list (the "Tables" link on the menu).
    private let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
        let game = GameState()
        let settings = GameSettings()
        let scene = TableScene(game: game, settings: settings)
        scene.isAttractMode = true         // the menu shows the table in attract mode (lamp chase)
        _game = State(initialValue: game)
        _settings = State(initialValue: settings)
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack {
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: 120,
                options: [],   // draw children in order (layered sprites rely on it)
                debugOptions: debugOptions
            )
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

            if showSettings {
                settingsOverlay
            }

            if showCredits {
                creditsOverlay
            }

            if showHowTo {
                HowToPlayView { showHowTo = false }
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: settings.cameraMode) { _, _ in
            // The mode is changed from the menu or pause card, while the scene is frozen.
            scene.refreshCamera()
        }
        .onChange(of: settings.multiballFullTable) { _, _ in
            scene.refreshCamera()
        }
        .onAppear {
            LabGamepad.shared.claim("greyInvasion", onA: { gamepadA() }, onMenu: { gamepadMenu() })
            #if DEBUG
            // Launched with `-playlab greyinvasion`: run the Play Lab unattended (the scene quits the app when done).
            if PlayLab.launchTable == "greyinvasion" {
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
        .onDisappear { LabGamepad.shared.release("greyInvasion") }
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
        scene.isGamePaused = false
        scene.isAttractMode = true         // physics stops; the lamps chase behind the menu
    }

    // Game controller (Pinball Lab): A = Play on the menu, Resume when paused, Play Again after a game;
    // Menu = pause / resume while playing. Ignored while a card is open over the table.
    private func gamepadA() {
        guard !(showHowTo || showSettings || showCredits) else { return }
        switch screen {
        case .menu:
            startGame()
        case .playing:
            if isPaused { setPaused(false) } else if game.isGameOver { startGame() }
        }
    }

    private func gamepadMenu() {
        guard !(showHowTo || showSettings || showCredits), screen == .playing, !game.isGameOver else { return }
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

    // MARK: - In-game HUD (the LED strip replaces this in milestone 7)

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
                    .background(.black.opacity(0.6), in: Capsule())   // M8: readable over the apron art
                    .padding(.bottom, 10)   // M7 v7: lowered, clear of the drain
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - LED strip (M7 round 5)

    private static let ledGreen = Color(red: 0.35, green: 1.0, blue: 0.55)
    private static let ledYellow = Color(red: 1.0, green: 0.88, blue: 0.3)

    /// The score display: a dark LED panel, green on black. Top row: balls left, multiplier,
    /// score. Bottom row: the bonus count, else the latest message, else the wave status.
    private var ledStrip: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<max(min(game.ballsLeft, 5), 0), id: \.self) { _ in
                        Circle()
                            .fill(Self.ledGreen)
                            .frame(width: 8, height: 8)
                            .shadow(color: Self.ledGreen.opacity(0.8), radius: 3)
                    }
                }
                .accessibilityLabel("Balls \(game.ballsLeft)")
                if game.multiplier > 1 {
                    Text("\(game.multiplier)X")
                        .font(.orbitron(13, .black))
                        .foregroundStyle(Self.ledYellow)
                }
                Spacer(minLength: 4)
                Text(game.score.formatted())
                    .font(.orbitron(18, .black))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Self.ledGreen)
                    .shadow(color: Self.ledGreen.opacity(0.7), radius: 6)
            }
            ledMessage
                .frame(maxWidth: .infinity)
                .frame(height: 17)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.ledGreen.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private var ledMessage: some View {
        if let bonus = game.bonusText {
            ledLine(bonus, color: Self.ledYellow, size: 14)
        } else if let banner = game.banner {
            ledLine(banner, color: Self.ledYellow, size: 14)
        } else if let status = game.status {
            ledLine(status, color: Self.ledGreen.opacity(0.75), size: 11)
        } else {
            Color.clear
        }
    }

    private func ledLine(_ text: String, color: Color, size: CGFloat) -> some View {
        Text(text)
            .font(.orbitron(size, .bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 4)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    // MARK: - Overlays

    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 4) {
                    Text("GREY INVASION")
                        .font(.orbitron(34, .black))
                        .multilineTextAlignment(.center)
                    Text("PINBALL")
                        .font(.orbitron(24, .bold))
                        .tracking(8)
                        .foregroundStyle(Self.alienGreen)
                }
                .shadow(color: Self.alienGreen.opacity(0.7), radius: 12)

                if game.highScore > 0 {
                    Text("High score \(game.highScore.formatted())")
                        .font(.orbitron(15))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()

                overlayButton("Play", prominent: true, action: startGame)
                overlayButton("How to Play") { showHowTo = true }
                overlayButton("Settings") { showSettings = true }
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
            Text("Score \(game.score.formatted())")
                .font(.orbitron(17))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
            overlayButton("Resume", prominent: true) { setPaused(false) }
                .padding(.top, 8)
            cameraButton
            overlayButton("Improve: \(settings.improveOn ? "On" : "Off")") { settings.improveOn.toggle() }
            volumeRow
            overlayButton("How to Play") { showHowTo = true }
            overlayButton("Settings") { showSettings = true }
            overlayButton("Restart", action: startGame)
            overlayButton("Menu", action: goToMenu)
            #if DEBUG
            // Testing shortcuts (debug builds only): light the Hangar for the next wave or the
            // Mothership, then resume and shoot the Hangar.
            HStack(spacing: 8) {
                debugButton("Skip Wave") { scene.debugSkipWave(); setPaused(false) }
                debugButton("Mothership") { scene.debugLightMothership(); setPaused(false) }
            }
            .padding(.top, 4)
            // Shot Lab (M10 v12): a robot measures every shot's timing window (~15 min; best in the Simulator).
            debugButton("Shot Lab") { scene.debugStartShotLab(); setPaused(false) }
            // Play Lab (shared): robot players at four skills, 120 Hz and 60 Hz passes (~1 h in the Simulator).
            debugButton("Play Lab") { scene.debugStartPlayLab(); setPaused(false) }
            // Plan 2 round 6: one expert game at the phone's own step, 3-minute cap, the report shared when done.
            debugButton("Play Lab · quick") { PlayLab.nextRunIsQuick = true; scene.debugStartPlayLab(); setPaused(false) }
            // Plan 2 round 12: one game of your own, watched by the lab (no robot), the report shared when it ends.
            debugButton("Record me") { PlayLab.nextRunIsRecording = true; scene.debugStartPlayLab(); setPaused(false) }
            #endif
        }
    }

    // MARK: - Settings (milestone 10)

    /// Camera, multiball view, sound volume, haptics, tips and bonus count. Saved as they change.
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { showSettings = false }
            VStack(spacing: 12) {
                Text("Settings")
                    .font(.orbitron(26, .black))
                cameraButton
                multiballViewButton
                volumeRow
                settingsToggle("Haptics", isOn: $settings.hapticsOn)
                settingsToggle("Tips", isOn: $settings.tipsOn)
                settingsToggle("Bonus count", isOn: $settings.bonusCountOn)
                overlayButton("Done", prominent: true) { showSettings = false }
                    .padding(.top, 6)
                Button("Credits") { showCredits = true }
                    .font(.orbitron(13, .bold))
                    .foregroundStyle(Self.alienGreen)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .dark)
        }
    }

    // MARK: - Credits (milestone 10 round 2)

    /// Who made what: the font's licence, the sound packs and our own art. Mirrors CREDITS.md.
    private var creditsOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { showCredits = false }
            VStack(spacing: 14) {
                Text("Credits")
                    .font(.orbitron(26, .black))
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        creditBlock("GAME", "Grey Invasion Pinball by Aaron Tilley, built with Claude.")
                        creditBlock("ART", "Playfield, ball, saucers, Mothership, cow and app icon: all original, drawn for this game.")
                        creditBlock("SOUND", "Sci-fi Sounds and Impact Sounds by Kenney (kenney.nl), CC0 public domain. Edited and levelled for the game.")
                        creditBlock("FONT", "Orbitron by Matt McInerney, via Google Fonts. SIL Open Font License 1.1.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 360)
                Text("Version \(Self.appVersion)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                overlayButton("Done", prominent: true) { showCredits = false }
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 330)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .environment(\.colorScheme, .dark)
        }
    }

    private func creditBlock(_ heading: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.orbitron(13, .bold))
                .tracking(2)
                .foregroundStyle(Self.alienGreen)
            Text(body)
                .font(.system(.subheadline))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "1.0 (1)" from the app's Info.plist.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    /// Sound volume slider (0 = silent), shown in Settings and on the pause card.
    private var volumeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.soundVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .frame(width: 24)
            Slider(value: $settings.soundVolume, in: 0...1)
                .tint(Self.alienGreen)
        }
        .frame(maxWidth: 240)
        .accessibilityLabel("Sound volume")
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(.orbitron(15, .bold))
        }
        .tint(Self.alienGreen)
        .frame(maxWidth: 240)
    }

    /// Cycles Flying → Wide → Top-Down (saved for next time).
    private var cameraButton: some View {
        overlayButton("Camera: \(settings.cameraMode.label)") {
            settings.cameraMode = settings.cameraMode.next
        }
    }

    /// Multiball view: whole table while 2+ balls are in play, or keep the chosen camera.
    private var multiballViewButton: some View {
        overlayButton("Multiball: \(settings.multiballFullTable ? "Full Table" : "Follow")") {
            settings.multiballFullTable.toggle()
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

    private func overlayButton(_ title: String, prominent: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.orbitron(17, .bold))
                .frame(maxWidth: 240)
                .padding(.vertical, 12)
                .background(prominent ? Color(red: 0.20, green: 0.70, blue: 0.40) : .white.opacity(0.12),
                            in: Capsule())
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    ContentView()
}
