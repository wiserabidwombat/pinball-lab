// Pinball Lab Table 06 (Orbit: Grand Tour): score, balls and high score (milestone 1), from Table 04's game state.
// Grows with the rules in milestone 7.
import Foundation
import Observation

private let tourHighScoreKey = "grandtour.highScore"

/// Table 06 point values (placeholders until the rules milestone).
enum TourPoints {
    static let slingshot = 10
    static let laneLit = 500
    static let laneRepeat = 50
    static let lanesComplete = 5_000
    static let rocketPost = 1_000
    // Milestone 2 (placeholder scoring until the rules milestone)
    static let countdownDrop = 500
    static let countdownComplete = 5_000
    static let missionControl = 10_000
    static let sampleDrop = 750
    static let samplesComplete = 3_000
    static let rover = 2_000
    static let roverHome = 15_000
    static let rocketLetter = 250
    static let rocketRepeat = 50
    static let rocketComplete = 10_000
    // Milestone 3 (placeholder)
    static let orbit = 5_000
    static let spin = 20
    static let starLit = 500
    static let starRepeat = 50
    static let starComplete = 5_000
    static let bumper = 100
    static let moon = 7_500
    static let saturn = 7_500
}

/// Shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class TourGameState {
    static let ballsPerGame = TourTableLayout.ballsPerGame
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
    var highScore = UserDefaults.standard.integer(forKey: tourHighScoreKey)
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
        UserDefaults.standard.set(score, forKey: tourHighScoreKey)
    }
}
