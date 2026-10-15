import Foundation
import Observation

private let highScoreKey = "highScore"

/// Point values from the plan doc. Tune in playtesting.
enum Points {
    static let rampShot = 2_500
    static let orbit = 1_000            // M7 v1: an orbit shot round the top
    static let skillShot = 10_000       // M7 v1: plunge into the lane with the pulsing ring
    static let slingshot = 10
    static let bumper = 100
    static let laneLit = 500
    static let laneRepeat = 50          // rolling through a lane that's already lit
    static let hangar = 1_000           // placeholder until the waves (milestone 7)
    static let abduction = 1_500
    static let dropTarget = 250
    static let fighterBank = 5_000      // all 4 fighters down (also lights the kickback)
    static let ballLocked = 5_000
    static let multiballStart = 10_000
    static let abductionJackpot = 50_000   // Tractor Beam ramp during Abduction multiball
}

/// Score, balls, multiplier, HUD message and high score, shared between the SpriteKit scene
/// and the SwiftUI HUD. Waves and the bonus count join in later rounds of milestone 7.
@MainActor
@Observable
final class GameState {
    static let ballsPerGame = 3
    static let maxMultiplier = 5

    var score = 0
    var ballsLeft = ballsPerGame
    var ballOnPlunger = false
    /// U-F-O lane multiplier (1x–5x): every award is multiplied by it; back to 1x on a lost ball.
    var multiplier = 1
    /// Short HUD message ("SKILL SHOT", "BALL SAVED", "3X"). The scene clears it.
    var banner: String?
    /// Standing HUD line for the campaign ("WAVE 1 · SCOUTS LEFT 2 · 18s"), nil when quiet.
    var status: String?
    /// End-of-ball bonus count in the LED strip ("BONUS 8,500 × 2"), nil when not counting.
    var bonusText: String?
    var highScore = UserDefaults.standard.integer(forKey: highScoreKey)
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

    /// Extra Ball collected at the Hangar (M7 round 3): one more ball this game.
    func awardExtraBall() {
        ballsLeft += 1
    }

    /// A drain that Shields Up rescued: no ball lost, multiplier kept.
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
        status = nil
        bonusText = nil
        isNewHighScore = false
    }

    private func recordHighScore() {
        guard score > highScore else { return }
        highScore = score
        isNewHighScore = true
        UserDefaults.standard.set(score, forKey: highScoreKey)
    }
}
