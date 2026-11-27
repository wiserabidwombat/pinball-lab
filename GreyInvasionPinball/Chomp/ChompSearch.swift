// Pinball Lab Table 07 (CHOMP!), M5 v11: MISSING SUNSCREEN — the real table's Search Multiball, renamed (the plan:
// the 5th beach closure starts Rescue "Tourist Taxi" or Search "Missing Sunscreen" by choice).
// Pure rules: the scene feeds it shots, the bucket, the shark tower set, the balls in play and time.
// Rules from the Jaws rulesheet (code 1.01, pinballrulesheets.com): 2 balls with a 30 s ball save; further balls by
// hitting all the orange arrow shots; phase 1: the chum bucket or the shark tower set raises and lights the fin for
// fin jackpots, 5M + 2M per jackpot; after five, phase 2 with a minute-long timer: the center captive ball (our boat)
// for shark jackpots, 3M + 1M per jackpot × the balls in play × a multiplier built by the orange arrows; five shark
// jackpots before time runs out finish it. Which shots are orange and how much each adds to the multiplier aren't
// given: here the five beach shots, +1x each (p), relit once all five are made (with the added ball).
import Foundation

@MainActor
final class ChompSearch {
    enum Effect {
        case score(Int, String?)
        case note(String)
        case startMultiball(Int)
        case addBall
        case multiballOver
    }

    enum Phase { case fin, shark, done }

    static let title = "MISSING SUNSCREEN"
    static let balls = 2
    static let saveSeconds: TimeInterval = 30
    static let finBase = 5_000_000, finStep = 2_000_000, finJackpotsNeeded = 5
    static let sharkBase = 3_000_000, sharkStep = 1_000_000, sharkJackpotsNeeded = 5
    static let sharkSeconds: TimeInterval = 60
    static let maxMultiplier = 6                                // p

    private(set) var active = false
    private(set) var phase = Phase.done
    private(set) var finLit = false
    private(set) var finJackpots = 0
    private(set) var sharkJackpots = 0
    private(set) var multiplier = 1
    private(set) var orange: Set<ChompShot> = []
    private var sharkLeft: TimeInterval = 0
    private(set) var total = 0
    /// Phase 1 done (the rulesheet: victory combos also start on a drain after it) — kept for the victory combos.
    private(set) var reachedSharkPhase = false

    /// Up while the fin is lit for a jackpot; held down in phase 1 until the bucket / shark tower lights it.
    var finWanted: Bool? {
        guard active, phase == .fin else { return nil }
        return finLit
    }

    func newGame() {
        active = false; phase = .done; finLit = false; orange = []; total = 0; reachedSharkPhase = false
    }

    func start() -> [Effect] {
        active = true
        phase = .fin
        finLit = false
        finJackpots = 0; sharkJackpots = 0; multiplier = 1; total = 0; reachedSharkPhase = false
        orange = Set(ChompShot.beach)
        return [.startMultiball(Self.balls), .score(0, "\(Self.title) · SHOOT THE BUCKET")]
    }

    private func lightFin(_ why: String) -> [Effect] {
        guard active, phase == .fin, !finLit else { return [] }
        finLit = true
        return [.note("\(why) · FIN LIT")]
    }

    func bucketHit() -> [Effect] { lightFin("CHUM IN") }
    func towerComplete() -> [Effect] { lightFin("SHARK TOWER") }

    /// A shot made during the multiball; `ballsInPlay` multiplies the shark jackpots.
    func shot(_ s: ChompShot, ballsInPlay: Int) -> [Effect] {
        guard active else { return [] }
        var fx: [Effect] = []
        if phase != .done, orange.contains(s) {                 // v11b: nothing more once it's finished / over
            orange.remove(s)
            multiplier = min(Self.maxMultiplier, multiplier + 1)
            fx.append(.note("SHARK MULTIPLIER \(multiplier)X"))
            if orange.isEmpty {
                orange = Set(ChompShot.beach)
                fx += [.addBall, .note("ADD-A-BALL")]
            }
        }
        switch phase {
        case .fin where s == .fin && finLit:
            let pay = Self.finBase + Self.finStep * finJackpots
            finJackpots += 1
            finLit = false
            total += pay
            fx.append(.score(pay, "FIN JACKPOT \(finJackpots) · \(ChompCameos.millions(pay))"))
            if finJackpots >= Self.finJackpotsNeeded {
                phase = .shark
                reachedSharkPhase = true
                sharkLeft = Self.sharkSeconds
                fx.append(.score(0, "SHARK SPOTTED · SHOOT THE BOAT"))
            }
        case .shark where s == .boat:
            let pay = (Self.sharkBase + Self.sharkStep * sharkJackpots) * max(1, ballsInPlay) * multiplier
            sharkJackpots += 1
            total += pay
            fx.append(.score(pay, "SHARK JACKPOT \(sharkJackpots) · \(ChompCameos.millions(pay))"))
            if sharkJackpots >= Self.sharkJackpotsNeeded {
                phase = .done
                fx.append(.score(0, "SHARK ESCAPED · \(Self.title) COMPLETE"))
            }
        default:
            break
        }
        return fx
    }

    func tick(dt: TimeInterval) -> [Effect] {
        guard active, phase == .shark else { return [] }
        sharkLeft -= dt
        guard sharkLeft <= 0 else { return [] }
        phase = .done
        return [.note("THE SHARK GOT AWAY")]
    }

    func multiballEnded() -> [Effect] {
        guard active else { return [] }
        active = false
        phase = .done
        finLit = false
        orange = []
        return [.multiballOver, .score(0, "\(Self.title) OVER · \(ChompCameos.millions(total))")]
    }

    /// Orange arrows (orange / blue flashing), the boat gold in phase 2.
    func lamp(_ s: ChompShot) -> ChompCameos.Lamp {
        guard active else { return .off }
        if phase == .shark, s == .boat { return .jackpot }
        if phase == .fin, s == .fin, finLit { return .jackpot }
        return phase != .done && orange.contains(s) ? .final : .off
    }

    func statusText() -> String? {
        guard active else { return nil }
        switch phase {
        case .fin:
            return "\(Self.title) · FIN \(finJackpots)/\(Self.finJackpotsNeeded)" + (finLit ? " · HIT THE FIN" : " · SHOOT THE BUCKET")
        case .shark:
            return "\(Self.title) · SHARK \(sharkJackpots)/\(Self.sharkJackpotsNeeded) · \(multiplier)X · \(max(0, Int(sharkLeft.rounded(.up))))s"
        case .done:
            return "\(Self.title) · \(ChompCameos.millions(total))"
        }
    }
}
