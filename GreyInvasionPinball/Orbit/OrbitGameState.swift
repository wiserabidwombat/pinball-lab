// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was GameState.swift.
import Foundation
import Observation

/// Point values from the plan doc. Tune in playtesting.
enum OrbitPoints {
    static let bumper = 100
    static let slingshot = 10
    static let laneLit = 500
    static let laneRepeat = 50          // rolling through a lane that's already lit
    static let dropTarget = 250
    static let dropTargetBank = 5_000   // all 4 asteroids down
    static let wormhole = 1_000
    static let skillShot = 2_500
}

private let highScoreKey = "orbit.highScore"   // Pinball Lab: its own high score

/// Score, balls, multiplier and high score, shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class OrbitGameState {
    static let ballsPerGame = 3
    static let maxMultiplier = 5

    var score = 0
    var ballsLeft = ballsPerGame
    var ballInPlay = false
    var ballOnPlunger = false
    var multiplier = 1
    var ballSaveActive = false
    var highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    var isNewHighScore = false
    /// Short message shown mid-screen ("BALL SAVED", "SKILL SHOT", "3X"). The scene clears it.
    var banner: String?

    var isGameOver: Bool { ballsLeft == 0 }

    func add(_ points: Int) {
        score += points * multiplier
    }

    /// Returns true if the multiplier went up (false when already at max).
    @discardableResult
    func raiseMultiplier() -> Bool {
        guard multiplier < Self.maxMultiplier else { return false }
        multiplier += 1
        return true
    }

    func ballPlaced() {
        ballInPlay = true
    }

    /// A drain that ball save rescued: no ball lost, multiplier kept.
    func ballSaved() {
        ballInPlay = false
        ballOnPlunger = false
        ballSaveActive = false
    }

    func ballDrained() {
        ballInPlay = false
        ballOnPlunger = false
        ballSaveActive = false
        multiplier = 1
        ballsLeft = max(0, ballsLeft - 1)
        if isGameOver { recordHighScore() }
    }

    func reset() {
        score = 0
        ballsLeft = Self.ballsPerGame
        ballInPlay = false
        ballOnPlunger = false
        multiplier = 1
        ballSaveActive = false
        isNewHighScore = false
        banner = nil
    }

    private func recordHighScore() {
        guard score > highScore else { return }
        highScore = score
        isNewHighScore = true
        UserDefaults.standard.set(score, forKey: highScoreKey)
    }
}
