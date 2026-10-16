// Pinball Lab Table 05 (The Lamplight): the evening's score and balls, shared with the SwiftUI HUD (milestone 1).
// The persistent shop (collections, tips, friends) gets its own save file in milestone 6.
import Foundation
import Observation

private let lmpBestEveningKey = "lamplight.bestEvening"

@MainActor
@Observable
final class LmpGameState {
    static let ballsPerGame = LmpTableLayout.ballsPerGame

    var score = 0
    var ballsLeft = ballsPerGame
    var ballOnPlunger = false
    /// Short HUD message; the scene clears it.
    var banner: String?
    /// Kept quietly (the plan: "best evening" lives in the collection book, not on the menu).
    var bestEvening = UserDefaults.standard.integer(forKey: lmpBestEveningKey)

    var isGameOver: Bool { ballsLeft == 0 }

    func add(_ points: Int) {
        score += points
    }

    func ballDrained() {
        ballOnPlunger = false
        ballsLeft = max(0, ballsLeft - 1)
        if isGameOver, score > bestEvening {
            bestEvening = score
            UserDefaults.standard.set(score, forKey: lmpBestEveningKey)
        }
    }

    func reset() {
        score = 0
        ballsLeft = Self.ballsPerGame
        ballOnPlunger = false
        banner = nil
    }
}
