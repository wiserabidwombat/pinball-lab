// Pinball Lab Table 05 (The Lamplight): the evening's score and balls, shared with the SwiftUI HUD (milestone 1).
// The persistent shop (collections, tips, friends) lives in LmpShop (milestone 6); this is just tonight.
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
    /// M6: the last find, shown as a card under the score for a moment (the scene clears it).
    var findToast: LmpFind?
    var findsTonight = 0
    var newTonight = 0
    /// M6: a loop combo or a full plunge makes it a lucky evening: better odds on rare books until closing.
    var lucky = false
    /// M6 round 3: where the cat is tonight (shown on the pause card with what she does there).
    var catPerch: LmpPerch = .shelf
    /// M8: the request in progress, shown on the LED strip's bottom row when there's no banner.
    var status: String?
    var requestsTonight = 0
    /// M8 round 2: Evening Rushes tonight (shown on the closing card).
    var rushesTonight = 0
    /// M8: the regular who just came in (their card shows for a few seconds).
    var visitor: LmpRequest?
    /// The Play Lab's robot is playing (its evenings never count as your best).
    var isRobot = false
    /// M8 round 3: tonight's cozy spots (shown on the pause card).
    var cozy: [LmpCozy] = []
    /// M8 round 4: tonight's place in the year ("Spring · evening 3 of 7 · year 1"), for the closing card.
    var seasonLine = ""
    /// M8 round 5: the season's festival — progress toward it, lit, or held (for the closing card).
    var festivalLine = ""
    /// Tonight's Festival Night, if there was one ("Blossom Fair").
    var festivalTonight: String?
    /// Kept quietly (the plan: "best evening" lives in the collection book, not on the menu).
    var bestEvening = UserDefaults.standard.integer(forKey: lmpBestEveningKey)

    var isGameOver: Bool { ballsLeft == 0 }

    func add(_ points: Int) {
        score += points
    }

    func ballDrained() {
        ballOnPlunger = false
        ballsLeft = max(0, ballsLeft - 1)
        if isGameOver, !isRobot, score > bestEvening {
            bestEvening = score
            UserDefaults.standard.set(score, forKey: lmpBestEveningKey)
        }
    }

    func reset() {
        score = 0
        ballsLeft = Self.ballsPerGame
        ballOnPlunger = false
        banner = nil
        findToast = nil
        findsTonight = 0
        newTonight = 0
        lucky = false
        status = nil
        requestsTonight = 0
        rushesTonight = 0
        visitor = nil
        festivalLine = ""
        festivalTonight = nil
    }
}
