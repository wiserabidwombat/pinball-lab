// Pinball Lab Table 07 (CHOMP!), M5 v12: victory combos — the real table's reward for finishing a multiball.
// Pure rules: the scene starts them and feeds them beach shots and time.
// Rules from the Jaws rulesheet (code 1.01, pinballrulesheets.com): victory combos start once any Jaws (our Kevin)
// multiball is completed, once Rescue's super jackpot round times out, once Search's five shark jackpots are scored,
// or when the player drains out of Search after its fin jackpots; "shoot the lit jackpot shots as combos to increase
// their value"; the beach boosts from the most recent five hurry-ups count during them. The rulesheet gives no shots,
// values, combo window or ending: here the five beach shots, 2M + 1M per shot in a combo chain made within 3 s of the
// one before (p), for the rest of the multiball (or of the ball, after a Search drain-out).
import Foundation

@MainActor
final class ChompVictory {
    enum Effect {
        case score(Int, String?)
        case note(String)
    }

    static let base = 2_000_000                      // p
    static let step = 1_000_000                      // p (per shot in the chain)
    static let window: TimeInterval = 3              // p

    private(set) var active = false
    private var untilBallEnd = false
    private var lastShotAt: TimeInterval = -100
    private var chain = 0
    private(set) var total = 0

    func newGame() {
        active = false; untilBallEnd = false; chain = 0; total = 0; lastShotAt = -100
    }

    /// `untilBallEnd`: they outlast the multiball (a Search drain-out), ending with the ball.
    func start(untilBallEnd: Bool) -> [Effect] {
        if active {
            self.untilBallEnd = self.untilBallEnd || untilBallEnd
            return []
        }
        active = true
        self.untilBallEnd = untilBallEnd
        chain = 0; total = 0; lastShotAt = -100
        return [.note("VICTORY COMBOS · SHOOT THE LIT SHOTS")]
    }

    /// A shot made; `boost` = that beach's value boost from the last five hurry-ups.
    func shot(_ s: ChompShot, now: TimeInterval, boost: Int) -> [Effect] {
        guard active, ChompShot.beach.contains(s) else { return [] }
        chain = now - lastShotAt <= Self.window ? chain + 1 : 0
        lastShotAt = now
        let pay = Self.base + Self.step * chain + boost
        total += pay
        return [.score(pay, chain > 0 ? "VICTORY COMBO \(chain + 1) · \(ChompCameos.millions(pay))"
                                      : "VICTORY JACKPOT · \(ChompCameos.millions(pay))")]
    }

    func multiballEnded() -> [Effect] {
        guard active, !untilBallEnd else { return [] }
        return end()
    }

    func ballLost() -> [Effect] {
        guard active else { return [] }
        return end()
    }

    private func end() -> [Effect] {
        active = false
        untilBallEnd = false
        chain = 0
        return [.note("VICTORY COMBOS · \(ChompCameos.millions(total))")]
    }

    /// Gold on every beach shot; blue / white fast while a combo is on.
    func lamp(_ s: ChompShot, now: TimeInterval) -> ChompCameos.Lamp {
        guard active, ChompShot.beach.contains(s) else { return .off }
        return now - lastShotAt <= Self.window ? .blueFast : .jackpot
    }

    func statusText(now: TimeInterval) -> String? {
        guard active else { return nil }
        let combo = now - lastShotAt <= Self.window ? " · COMBO \(chain + 1) · \(max(0, Int((Self.window - (now - lastShotAt)).rounded(.up))))s" : ""
        return "VICTORY COMBOS · \(ChompCameos.millions(total))" + combo
    }
}
