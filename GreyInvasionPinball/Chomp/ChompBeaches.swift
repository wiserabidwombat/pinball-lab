// Pinball Lab Table 07 (CHOMP!), M5 v3: tourists and beach closures — the real table's beachgoers and Beach Closed
// hurry-ups, renamed (the plan's section 5: lifeguard-tower hits add tourists, three closes the beach and plays a
// Mayor Meltdown hurry-up). Pure rules: the scene feeds it tower hits, shots and time and applies what comes back.
// Rules from the Jaws rulesheet (code 1.01, pinballrulesheets.com): a shark tower hit lights a beachgoer at a beach
// shot beside it; shooting that shot rescues the lit ones; three rescued at a beach starts its hurry-up (15M base,
// ticking down) at that shot; collecting it boosts later lit shots there by 20 % of the value; the 5th hurry-up adds
// the values of the four before (no boost) and its end resets the beaches (Rescue / Search multiball comes later);
// 8 rescued = an extra ball (+ Beach Junk, the plan's version of "light gear"). While a mode runs, a beach's last
// tourist waits. The rescue value, the hurry-up's timer and how far it ticks down are placeholders (marked).
import Foundation

extension ChompShot {
    var label: String {
        switch self {
        case .leftLoop: return "LEFT LOOP"
        case .waveRamp: return "WAVE RAMP"
        case .centerRamp: return "CENTER RAMP"
        case .reel: return "FISHING REEL"
        case .rightRamp: return "RIGHT RAMP"
        case .harpoonGate: return "HARPOON GATE"
        case .fishPhone: return "FISH PHONE"
        case .fin: return "FIN"
        case .boat: return "BOAT"
        }
    }
}

@MainActor
final class ChompBeaches {
    enum Effect {
        case score(Int, String?)          // points and an optional banner (held over the shot names)
        case note(String)                 // a plain banner
        case meltdownStarted(ChompShot)
        case extraBall
        case beachJunk
    }

    static let touristsPerBeach = 3
    static let extraBallAt = 8
    static let meltdownBase = 15_000_000
    static let boostShare = 0.20
    // Placeholders (the rulesheet gives no number for these).
    static let rescueValue = 1_000_000
    static let meltdownSeconds: TimeInterval = 20
    static let meltdownFloor = 0.25                  // the value it ticks down to before it runs out
    /// The beaches beside each shark tower target (Tgt1 left of the loop / wave ramp, Tgt2 left of the reel,
    /// Tgt3 between the reel and the right ramp's lane).
    static let towerBeaches: [[ChompShot]] = [[.leftLoop, .waveRamp], [.centerRamp, .reel], [.reel, .rightRamp]]

    private(set) var lit: [ChompShot: Int] = [:]
    private(set) var rescued: [ChompShot: Int] = [:]
    private(set) var closed: Set<ChompShot> = []
    private(set) var boost: [ChompShot: Int] = [:]
    private(set) var savedTotal = 0
    private var extraBallGiven = false
    private var collectedSum = 0                     // the hurry-ups collected since the last reset (for the 5th)

    // The running hurry-up
    private(set) var meltdownShot: ChompShot?
    private var meltdownStart = 0
    private var meltdownLeft: TimeInterval = 0
    private var meltdownIsFifth = false

    var meltdownValue: Int {
        guard meltdownShot != nil else { return 0 }
        let f = Self.meltdownFloor + (1 - Self.meltdownFloor) * max(0, meltdownLeft) / Self.meltdownSeconds
        return Int(Double(meltdownStart) * f) / 100_000 * 100_000
    }

    func statusText() -> String? {
        guard let s = meltdownShot else { return nil }
        return "MAYOR MELTDOWN · \(s.label) · \(ChompCameos.millions(meltdownValue)) · \(max(0, Int(meltdownLeft.rounded(.up))))s"
    }

    func newGame() {
        resetBeaches()
        savedTotal = 0; extraBallGiven = false
    }

    private func resetBeaches() {
        lit = [:]; rescued = [:]; closed = []; boost = [:]; collectedSum = 0
        meltdownShot = nil; meltdownLeft = 0; meltdownIsFifth = false
    }

    private func count(_ b: ChompShot) -> Int { (lit[b] ?? 0) + (rescued[b] ?? 0) }

    /// Shark tower target `i` hit: a tourist appears at the beach beside it that needs one most (any open beach if
    /// both are full or closed). `modeRunning`: a cameo is on, so a beach's last tourist waits.
    func towerHit(_ i: Int, modeRunning: Bool) -> [Effect] {
        guard Self.towerBeaches.indices.contains(i) else { return [] }
        let blockLast = modeRunning || meltdownShot != nil
        func open(_ b: ChompShot) -> Bool {
            guard !closed.contains(b) else { return false }
            let n = count(b)
            return n < Self.touristsPerBeach - (blockLast ? 1 : 0)
        }
        let near = Self.towerBeaches[i].filter(open)
        let pool = near.isEmpty ? ChompShot.beach.filter(open) : near
        guard let b = pool.min(by: { count($0) < count($1) }) else { return [] }
        lit[b, default: 0] += 1
        return [.note("TOURIST AT THE \(b.label)")]
    }

    /// A beach shot made: the hurry-up there, or the tourists lit there.
    func shot(_ s: ChompShot) -> [Effect] {
        guard ChompShot.beach.contains(s) else { return [] }
        if s == meltdownShot { return collect() }
        guard let n = lit[s], n > 0 else { return [] }
        lit[s] = 0
        rescued[s, default: 0] += n
        savedTotal += n
        var fx: [Effect] = []
        let points = n * Self.rescueValue
        fx.append(.score(points, n == 1 ? "TOURIST SAVED · \(savedTotal)" : "\(n) TOURISTS SAVED · \(savedTotal)"))
        // A beach that fills while another's hurry-up runs waits for it (started from close()).
        if (rescued[s] ?? 0) >= Self.touristsPerBeach, meltdownShot == nil { fx += startMeltdown(s) }
        if !extraBallGiven, savedTotal >= Self.extraBallAt {    // last, so its banner isn't covered
            extraBallGiven = true
            fx.append(.extraBall)
            fx.append(.beachJunk)
        }
        return fx
    }

    private func startMeltdown(_ s: ChompShot) -> [Effect] {
        meltdownIsFifth = closed.count == ChompShot.beach.count - 1
        meltdownStart = Self.meltdownBase + (meltdownIsFifth ? collectedSum : 0)
        meltdownLeft = Self.meltdownSeconds
        meltdownShot = s
        return [.score(0, "MAYOR MELTDOWN · \(s.label) · \(ChompCameos.millions(meltdownStart))"), .meltdownStarted(s)]
    }

    private func collect() -> [Effect] {
        guard let s = meltdownShot else { return [] }
        let pay = meltdownValue
        var fx: [Effect] = [.score(pay, "BEACH CLOSED · \(ChompCameos.millions(pay))")]
        if !meltdownIsFifth {
            boost[s] = Int(Double(pay) * Self.boostShare) / 100 * 100
            collectedSum += pay
        }
        fx += close(s)
        return fx
    }

    /// The hurry-up ran out (or the ball was lost): the beach closes without a boost.
    private func miss(_ banner: String?) -> [Effect] {
        guard let s = meltdownShot else { return [] }
        var fx: [Effect] = []
        if let banner { fx.append(.note(banner)) }
        fx += close(s)
        return fx
    }

    private func close(_ s: ChompShot) -> [Effect] {
        closed.insert(s)
        meltdownShot = nil
        if meltdownIsFifth {
            resetBeaches()                               // Rescue / Search multiball comes in a later round
            return [.score(0, "ALL BEACHES CLOSED")]
        }
        // A beach that filled up during this hurry-up starts its own now.
        if let next = ChompShot.beach.first(where: { !closed.contains($0) && (rescued[$0] ?? 0) >= Self.touristsPerBeach }) {
            return startMeltdown(next)
        }
        return []
    }

    /// Every frame off the plunger.
    func tick(dt: TimeInterval) -> [Effect] {
        guard meltdownShot != nil else { return [] }
        meltdownLeft -= dt
        return meltdownLeft <= 0 ? miss("MAYOR MELTDOWN OVER") : []
    }

    /// A ball lost (not saved): the hurry-up is lost; the tourists stay.
    func ballLost() -> [Effect] { miss(nil) }
}
