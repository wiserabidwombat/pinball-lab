import SwiftUI

/// Improve mode's welcome card (2026-10-26): shown once on the Pinball Lab home screen, the first time the app opens
/// with Improve mode in it. "Turn on Improve" switches it on for every table (GameSettings.improveOn lives in
/// UserDefaults); "Maybe later" leaves it off. Either way it doesn't show again.
enum ImproveWelcome {
    private static let seenKey = "improveWelcomeSeen"

    static var shouldShow: Bool { !UserDefaults.standard.bool(forKey: seenKey) }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}

struct ImproveWelcomeView: View {
    let onDone: () -> Void

    private static let accent = Color(red: 0.55, green: 0.45, blue: 1.0)    // the home screen's violet

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("NEW")
                        .font(.orbitron(12, .bold))
                        .tracking(2)
                        .foregroundStyle(Self.accent)
                    Text("IMPROVE MODE")
                        .font(.orbitron(24, .black))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Text("A coach for every campaign table: Grey Invasion, Cthulhu Rising, Monsoon and The Lamplight.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    row("scope", "Flip marks",
                        "Coloured marks on the flippers show where to flip for each shot. Lit shots glow and are labelled.")
                    row("point.topleft.down.to.point.bottomright.curvepath", "Drain replay",
                        "Lose a ball and its path replays on the table, with how it got away.")
                    row("chart.bar.fill", "Drain tally",
                        "The pause card counts where this game's balls drained.")
                }
                Text("Each table has a colour key on its pause card. Turn Improve on or off there any time.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button {
                        let settings = GameSettings()
                        settings.improveOn = true
                        finish()
                    } label: {
                        Text("Turn on Improve")
                            .font(.orbitron(17, .bold))
                            .frame(maxWidth: 240)
                            .padding(.vertical, 12)
                            .background(Self.accent.opacity(0.85), in: Capsule())
                    }
                    Button {
                        finish()
                    } label: {
                        Text("Maybe later")
                            .font(.orbitron(15, .bold))
                            .frame(maxWidth: 240)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
                .foregroundStyle(.white)
                .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .padding(26)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Self.accent.opacity(0.35), lineWidth: 1))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 16)
        }
    }

    private func finish() {
        ImproveWelcome.markSeen()
        onDone()
    }

    private func row(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Self.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.orbitron(14, .bold))
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
