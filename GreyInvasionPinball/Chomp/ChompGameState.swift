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
    // M2 v1 (placeholders)
    static let spin = 100
    static let loop = 1_000
    static let quickshotLane = 500
    static let bankTarget = 500
    static let bankComplete = 5_000
    static let waveRamp = 2_500                 // M2 v5 placeholder (the real rules come with M4)
    static let centerRamp = 2_000               // M3 v1 placeholder
    static let rightRamp = 2_500                // M3 v10 placeholder
    static let boat = 3_000                     // M3 v4 placeholder
    static let reelTurn = 500                   // M3 v9 placeholder (each turn of the fishing reel)
    static let fin = 1_000                      // M3 v15 placeholder (the fin dropped)
    static let chumBucket = 750                 // M3 v16 placeholder (the chum bucket target)
    static let sharkTarget = 500                // M3 v17 placeholder (each shark tower standup)
    static let sharkTowerComplete = 5_000       // M3 v17 placeholder (all three)
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
