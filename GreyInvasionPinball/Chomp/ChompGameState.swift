// Pinball Lab Table 07 (CHOMP! The Terror of Calamity Island): copied from Table 06's milestone-1 file (e023ac3) with the "Chomp" prefix.
// Grows with the rules in milestone 7.
import Foundation
import Observation

private let chompHighScoreKey = "chomp.highScore"

/// Table 07 point values (placeholders until the rules milestone).
enum ChompPoints {
    static let slingshot = 10
    static let lane = 100
    static let miniLane = 500
    static let bumper = 100
    static let buoy = 250
    static let innerTube = 1_000
    static let outlaneSave = 1_000
}

/// Shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class ChompGameState {
    static let ballsPerGame = ChompTableLayout.ballsPerGame
    static let maxMultiplier = 6

    var score = 0
    var ballsLeft = ballsPerGame
    /// A robot (Play Lab) game: never recorded as the high score.
    var isRobot = false
    var ballOnPlunger = false
    var multiplier = 1
    /// Short HUD message; the scene clears it.
    var banner: String?
    /// The end-of-ball bonus count while it runs (shown in the LED strip instead of the banner).
    var bonusText: String?
    /// The mission and goal (from the rules milestone); shown dim when there's no banner.
    var status: String?
    var highScore = UserDefaults.standard.integer(forKey: chompHighScoreKey)
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

    /// A drain a save rescued: no ball lost, multiplier kept.
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
        UserDefaults.standard.set(score, forKey: chompHighScoreKey)
    }
}
