// Pinball Lab Table 04 (Monsoon): score, balls and high score (milestone 1), copied from Table 03's game state.
// Grows with the rules in milestone 8.
import Foundation
import Observation

private let monHighScoreKey = "monsoon.highScore"

/// Table 04 point values (placeholders until the rules milestone).
enum MonPoints {
    static let slingshot = 10
    static let bumper = 100
    static let laneLit = 500
    static let laneRepeat = 50
    static let orbit = 1_000
    static let rampShot = 2_500
    static let arroyo = 1_500
    static let standup = 250
    static let standupBank = 5_000
    static let captiveKnock = 100
    static let captiveTop = 2_500
    static let dustDevil = 50
    /// M8 v2: each wash of color, and a region painted all the way.
    static let wash = 250
    static let regionPainted = 10_000
    /// M8 v3: a Monsoon jackpot (the helix, or the mesa ramp if it goes round on the wire).
    static let jackpot = 25_000
    /// M8 v4: Superbloom — every lit shot, and the helix's super jackpot (both × the cycle).
    static let bloomShot = 15_000
    static let superJackpot = 75_000
    /// M8 v5: the skill shot (the ringed top lane straight off the plunger).
    static let skillShot = 10_000
}

/// Shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class MonGameState {
    static let ballsPerGame = MonTableLayout.ballsPerGame
    static let maxMultiplier = 5

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
    /// The act and goal (from the rules milestone); shown dim when there's no banner.
    var status: String?
    var highScore = UserDefaults.standard.integer(forKey: monHighScoreKey)
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

    /// A drain the ball save rescued: no ball lost, multiplier kept.
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
        UserDefaults.standard.set(score, forKey: monHighScoreKey)
    }
}
