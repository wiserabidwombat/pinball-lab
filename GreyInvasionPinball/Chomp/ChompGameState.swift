// Pinball Lab Table 07 (CHOMP! The Terror of Calamity Island): copied from Table 06's milestone-1 file (e023ac3) with the "Chomp" prefix.
// Grows with the rules in milestone 7.
import Foundation
import Observation

private let chompHighScoreKey = "chomp.highScore"

/// Table 07 point values (placeholders until the rules milestone).
enum ChompPoints {
    // M5 v8: the basics on the real table's scale (Jaws scores run to billions; the rules' awards are millions).
    // From the rulesheet (Jaws 1.01): a boat ("shark hit") 5M, reel spins 15K (its Feeding Frenzy value), skill shots
    // 5 / 10 / 15M. The rest are placeholders sized to modern Stern switch values (marked "p"), to tune by play.
    static let slingshot = 10_000               // p
    static let lane = 25_000                    // p (inlanes / outlanes)
    static let miniLane = 250_000               // p
    static let bumper = 50_000                  // p
    static let buoy = 100_000                   // p (the "light life ring" target)
    static let innerTube = 1_000_000            // p
    static let outlaneSave = 1_000_000          // p
    static let spin = 10_000                    // p (the left loop's spinner, each spin)
    static let loop = 500_000                   // p
    static let quickshotLane = 250_000          // p (each harpoon lane rollover)
    static let bankTarget = 100_000             // p (each Fish Phone standup)
    static let bankComplete = 1_000_000         // p
    static let waveRamp = 750_000               // p
    static let centerRamp = 500_000             // p (the easiest shot)
    static let rightRamp = 1_000_000            // p ("tight")
    static let boat = 5_000_000                 // rulesheet: a shark hit scores 5M
    static let reelTurn = 15_000                // rulesheet: 15K a reel spin (Feeding Frenzy)
    static let fin = 500_000                    // p (the fin dropped)
    static let chumBucket = 250_000             // p
    static let sharkTarget = 250_000            // p (each shark tower standup)
    static let sharkTowerComplete = 1_000_000   // p (all three)
    static let skillShot1 = 5_000_000           // plunge into the bumper
    static let skillShot2 = 10_000_000          // plunge into the lane above the mini flipper, bumper untouched
    static let skillShot3 = 15_000_000          // the flashing Fish Phone target, no other switch first
    // M5 v9: the end-of-ball Ball Bonus (the rulesheet: "more information needed") — what each switch this ball adds.
    static let bonusShot = 250_000              // p (left loop, the three ramps, the boat, the reel, the harpoon lane)
    static let bonusSwitch = 25_000             // p (every other switch but the spinner)
}

/// Shared between the SpriteKit scene and the SwiftUI HUD.
@MainActor
@Observable
final class ChompGameState {
    static let ballsPerGame = ChompTableLayout.ballsPerGame
    static let maxMultiplier = 6

    var score = 0
    var ballsLeft = ballsPerGame
    /// M5 v3: extra balls won this game (the Play Lab's balls-played count).
    var extraBallsEarned = 0
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
    /// M5 v1: Beach Junk (the real table's gear) lit and not yet collected. Skill shots 2 and 3 light one; collecting
    /// comes with the rules-depth milestone.
    var beachJunkLit = 0
    /// M5 v2: every cameo jackpot adds +1x to the Flip-Flop Smack (the real machete), built in rules depth.
    var smackBonus = 0
    /// M5 v9: the end-of-ball bonus. Ball Bonus counts this ball's switches; Feeding Frenzy points bank for the whole
    /// game (the frenzy itself comes later); the bonus X grows with Quint's knots (later): the first knot of a game
    /// +1x for that ball only (`ballBonusX`), later knots +1x for the rest of the game (`bonusX`).
    var ballBonus = 0
    var frenzyBank = 0
    var bonusX = 1
    var ballBonusX = 0
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
        extraBallsEarned = 0
        ballOnPlunger = false
        multiplier = 1
        banner = nil
        bonusText = nil
        status = nil
        beachJunkLit = 0
        smackBonus = 0
        ballBonus = 0
        frenzyBank = 0
        bonusX = 1
        ballBonusX = 0
        isNewHighScore = false
    }

    private func recordHighScore() {
        guard !isRobot, score > highScore else { return }
        highScore = score
        isNewHighScore = true
        UserDefaults.standard.set(score, forKey: chompHighScoreKey)
    }
}
