// Pinball Lab Table 03: score, balls and high score (milestone 1). Grows with the rules in milestone 7.
import Foundation
import Observation

private let cthHighScoreKey = "cthulhu.highScore"

/// Table 03 point values (from the plan's scoring table; placeholders until the rules milestone).
enum CthPoints {
    static let slingshot = 10
    static let bumper = 100
    static let laneLit = 500
    static let laneRepeat = 50
    static let orbit = 1_000
    static let rampShot = 2_500
    static let library = 1_500
    static let lagoon = 1_500
    static let sigilTarget = 250
    static let sigilBank = 5_000
    static let magnet = 500           // the magnet grabs the ball
    static let skillShot = 10_000
}

/// Shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class CthGameState {
    static let ballsPerGame = CthTableLayout.ballsPerGame
    static let maxMultiplier = 5

    var score = 0
    var ballsLeft = ballsPerGame
    var ballOnPlunger = false
    var multiplier = 1
    /// Short HUD message; the scene clears it.
    var banner: String?
    /// The end-of-ball bonus count while it runs (shown in the LED strip instead of the banner).
    var bonusText: String?
    /// The act and goal (M7 v2), e.g. "RESEARCH · CLUE 2 OF 3"; shown dim when there's no banner.
    var status: String?
    var highScore = UserDefaults.standard.integer(forKey: cthHighScoreKey)
    /// A Play Lab robot is playing: its scores never become the high score.
    var isRobot = false
    var isNewHighScore = false

    var isGameOver: Bool { ballsLeft == 0 }

    func add(_ points: Int) {
        score += points * multiplier
    }

    /// Returns true if the multiplier went up (false when it's already at the max).
    @discardableResult
    func raiseMultiplier() -> Bool {
        guard multiplier < Self.maxMultiplier else { return false }
        multiplier += 1
        return true
    }

    /// A drain the Elder Sign or the outlane save rescued: no ball lost, multiplier kept.
    func ballSaved() {
        ballOnPlunger = false
    }

    func ballDrained() {
        ballOnPlunger = false
        multiplier = 1
        ballsLeft = max(0, ballsLeft - 1)
        if isGameOver { recordHighScore() }
    }

    func reset() {
        score = 0
        ballsLeft = Self.ballsPerGame
        ballOnPlunger = false
        multiplier = 1
        banner = nil
        bonusText = nil
        status = nil
        isNewHighScore = false
    }

    private func recordHighScore() {
        guard !isRobot, score > highScore else { return }
        highScore = score
        isNewHighScore = true
        UserDefaults.standard.set(score, forKey: cthHighScoreKey)
    }
}
