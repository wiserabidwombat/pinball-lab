// Pinball Lab Table 07 (CHOMP!), M5 v10: TOURIST TAXI — the real table's Rescue Multiball, renamed (the plan: the 5th
// beach closure starts Rescue "Tourist Taxi" or Search "Missing Sunscreen" by choice; Search and the choice come next).
// Pure rules: the scene feeds it shots, the bucket, the Fish Phone bank and time, and applies what comes back.
// Rules from the Jaws rulesheet (code 1.01, pinballrulesheets.com): fifteen beachgoers, three at each beach shot;
// flashing shots pay 1x / 2x / 3x jackpots by how many have been saved at that shot; one blue shot is the pursuing
// shark, which eats a beachgoer there unless that shot is hit in time; completing the 3-bank spots the blue shot;
// once all fifteen are saved or eaten, shoot the boat, then the fin again and again for super jackpots (+2M each, to
// 30M) until time runs out; six chum bucket hits add a ball. The ball count, ball save, jackpot value, the shark's
// timer, the first super and the super round's time aren't given: placeholders (marked p).
import Foundation

@MainActor
final class ChompRescue {
    enum Effect {
        case score(Int, String?)          // points and an optional banner (held)
        case note(String)                 // a plain banner
        case startMultiball(Int)          // balls wanted in play
        case addBall
        case multiballOver
    }

    enum Phase { case rescue, boat, supers, done }

    static let title = "TOURIST TAXI"
    static let perBeach = 3
    static let balls = 3                                  // p
    static let saveSeconds: TimeInterval = 20             // p
    static let jackpotBase = 5_000_000                    // p (× 1 / 2 / 3)
    static let sharkSeconds: TimeInterval = 8             // p (how long the shark waits before it eats one)
    static let superStart = 10_000_000                    // p
    static let superStep = 2_000_000, superMax = 30_000_000
    static let superSeconds: TimeInterval = 30            // p
    static let bucketHitsPerBall = 6

    private(set) var active = false
    private(set) var phase = Phase.done
    private(set) var waiting: [ChompShot: Int] = [:]
    private(set) var saved: [ChompShot: Int] = [:]
    private(set) var eaten: [ChompShot: Int] = [:]
    private(set) var sharkShot: ChompShot?
    private var sharkLeft: TimeInterval = 0
    private var superValue = 0
    private var superLeft: TimeInterval = 0
    private var bucketHits = 0
    private(set) var total = 0

    /// The fin is wanted up for the super jackpots.
    var finWanted: Bool? { active && phase == .supers ? true : nil }

    func newGame() {
        active = false; phase = .done; waiting = [:]; saved = [:]; eaten = [:]; sharkShot = nil; total = 0
    }

    func start() -> [Effect] {
        active = true
        phase = .rescue
        waiting = Dictionary(uniqueKeysWithValues: ChompShot.beach.map { ($0, Self.perBeach) })
        saved = [:]; eaten = [:]; total = 0; bucketHits = 0
        sharkShot = nil
        moveShark()
        return [.startMultiball(Self.balls), .score(0, "\(Self.title) · SAVE THE TOURISTS")]
    }

    private var left: Int { waiting.values.reduce(0, +) }

    private func moveShark() {
        let open = ChompShot.beach.filter { (waiting[$0] ?? 0) > 0 }
        let others = open.filter { $0 != sharkShot }
        sharkShot = (others.isEmpty ? open : others).randomElement()
        sharkLeft = Self.sharkSeconds
    }

    private func rescue(_ s: ChompShot, chasedOff: Bool) -> [Effect] {
        waiting[s, default: 0] -= 1
        saved[s, default: 0] += 1
        let x = saved[s] ?? 1
        let pay = Self.jackpotBase * x
        total += pay
        var fx: [Effect] = [.score(pay, (chasedOff ? "SHARK CHASED OFF · " : "") + "TAXI JACKPOT \(x)X · \(ChompCameos.millions(pay))")]
        if s == sharkShot || sharkShot.map({ (waiting[$0] ?? 0) == 0 }) == true { moveShark() }
        fx += checkDone()
        return fx
    }

    private func checkDone() -> [Effect] {
        guard phase == .rescue, left == 0 else { return [] }
        phase = .boat
        sharkShot = nil
        let n = saved.values.reduce(0, +)
        return [.score(0, "\(n)/15 SAVED · SHOOT THE BOAT")]
    }

    /// A shot made during the multiball.
    func shot(_ s: ChompShot) -> [Effect] {
        guard active else { return [] }
        switch phase {
        case .rescue:
            guard (waiting[s] ?? 0) > 0 else { return [] }
            return rescue(s, chasedOff: s == sharkShot)
        case .boat:
            guard s == .boat else { return [] }
            phase = .supers
            superValue = Self.superStart
            superLeft = Self.superSeconds
            return [.score(0, "SUPER JACKPOTS · HIT THE FIN")]
        case .supers:
            guard s == .fin else { return [] }
            let pay = superValue
            total += pay
            superValue = min(Self.superMax, superValue + Self.superStep)
            return [.score(pay, "TAXI SUPER JACKPOT · \(ChompCameos.millions(pay))")]
        case .done:
            return []
        }
    }

    /// The Fish Phone 3-bank completed: spots the blue shot (as if it had been hit).
    func bankComplete() -> [Effect] {
        guard active, phase == .rescue, let s = sharkShot, (waiting[s] ?? 0) > 0 else { return [] }
        return rescue(s, chasedOff: true)
    }

    /// Six chum bucket hits add a ball.
    func bucketHit() -> [Effect] {
        guard active else { return [] }
        bucketHits += 1
        if bucketHits >= Self.bucketHitsPerBall {
            bucketHits = 0
            return [.addBall, .note("ADD-A-BALL")]
        }
        return [.note("ADD-A-BALL \(bucketHits)/\(Self.bucketHitsPerBall)")]
    }

    /// Every frame of the multiball (not while a ball waits on the plunger).
    func tick(dt: TimeInterval) -> [Effect] {
        guard active else { return [] }
        switch phase {
        case .rescue:
            guard let s = sharkShot else { return [] }
            sharkLeft -= dt
            guard sharkLeft <= 0 else { return [] }
            waiting[s, default: 0] -= 1
            eaten[s, default: 0] += 1
            moveShark()
            var fx: [Effect] = [.note("TOURIST EATEN AT THE \(s.label)")]
            fx += checkDone()
            return fx
        case .supers:
            superLeft -= dt
            guard superLeft <= 0 else { return [] }
            phase = .done
            return [.note("SUPER JACKPOTS OVER")]
        case .boat, .done:
            return []
        }
    }

    /// One ball (or none) left: the multiball is over.
    func multiballEnded() -> [Effect] {
        guard active else { return [] }
        active = false
        phase = .done
        sharkShot = nil
        return [.multiballOver, .score(0, "\(Self.title) OVER · \(ChompCameos.millions(total))")]
    }

    /// The shot lamps: flashing white = tourists waiting, blue fast = the shark, gold = the boat / fin to shoot.
    func lamp(_ s: ChompShot) -> ChompCameos.Lamp {
        guard active else { return .off }
        switch phase {
        case .rescue:
            if s == sharkShot { return .blueFast }
            return (waiting[s] ?? 0) > 0 ? .white : .off
        case .boat: return s == .boat ? .jackpot : .off
        case .supers: return s == .fin ? .jackpot : .off
        case .done: return .off
        }
    }

    func statusText() -> String? {
        guard active else { return nil }
        switch phase {
        case .rescue:
            let shark = sharkShot.map { " · SHARK AT \($0.label) \(max(0, Int(sharkLeft.rounded(.up))))s" } ?? ""
            return "\(Self.title) · \(left) LEFT" + shark
        case .boat: return "\(Self.title) · SHOOT THE BOAT"
        case .supers: return "\(Self.title) · FIN \(ChompCameos.millions(superValue)) · \(max(0, Int(superLeft.rounded(.up))))s"
        case .done: return "\(Self.title) · \(ChompCameos.millions(total))"
        }
    }
}
