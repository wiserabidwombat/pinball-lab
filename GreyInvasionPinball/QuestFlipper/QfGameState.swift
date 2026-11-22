// Pinball Lab Table 09 (Quest & Flipper): the score and the HUD's state. Drains cost HP (from QfRunState), not balls:
// zero HP ends the game. Grows with the rules in a later milestone.
import Foundation
import Observation

private let qfHighScoreKey = "quest.highScore"

/// Table 09 point values (placeholders until the rules milestone).
enum QfPoints {
    static let slingshot = 10
    static let target = 500
    static let bark = 1000
    static let treantFelled = 25_000
    static let scoop = 2000
    static let orbit = 3000
    static let ramp = 3000
    static let spin = 100
}

/// Shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class QfGameState {
    static let maxMultiplier = 6

    var score = 0
    /// The run the table reads (HP, ball strength, armour, loot). A new game starts a new Knight run for now.
    var run = QfRunState.knight
    /// A robot (Play Lab) game: never recorded as the high score.
    var isRobot = false
    var ballOnPlunger = false
    var multiplier = 1
    /// Short HUD message; the scene clears it.
    var banner: String?
    var bonusText: String?
    /// The current goal; shown dim when there's no banner.
    var status: String?
    var highScore = UserDefaults.standard.integer(forKey: qfHighScoreKey)
    var isNewHighScore = false

    var hp: Int { run.hp }
    var maxHP: Int { run.maxHP }
    var isGameOver: Bool { run.hp <= 0 }

    func add(_ points: Int) {
        score += points * multiplier
    }

    @discardableResult
    func raiseMultiplier() -> Bool {
        guard multiplier < Self.maxMultiplier else { return false }
        multiplier += 1
        return true
    }

    /// A drain: costs the run's drain damage less armour. Returns the HP lost.
    @discardableResult
    func ballDrained() -> Int {
        ballOnPlunger = false
        multiplier = 1
        let lost = min(run.hp, run.damagePerDrain)
        run.hp -= lost
        if isGameOver { recordHighScore() }
        return lost
    }

    func reset(run newRun: QfRunState = .knight) {
        score = 0
        run = newRun
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
        UserDefaults.standard.set(score, forKey: qfHighScoreKey)
    }
}
