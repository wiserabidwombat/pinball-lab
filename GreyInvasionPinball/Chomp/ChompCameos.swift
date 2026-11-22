// Pinball Lab Table 07 (CHOMP!), M5 v2: Kevin's Cameos — the real table's Shark Encounters, renamed (the plan's
// section 5). Pure rules: the scene feeds it shots and time and applies what comes back (points, banners, the fin).
// Rules from the Jaws rulesheet (code 1.01, pinballrulesheets.com): lit at the boat (1 hit + 1 per cameo played),
// started at a flashing white beach shot, boosted by more boat hits (+15 s → 5M + Beach Junk → 2x), blue shots
// advance, finishing lights the cameo jackpot at the fin (a share of the mode's total; a smaller backup at the boat if
// the fin is missed). Base timer, fin window and the values the rulesheet doesn't give are placeholders (marked).
import Foundation

/// The shots the rules talk about (the lab event names).
enum ChompShot: String, CaseIterable {
    case leftLoop, waveRamp, centerRamp, reel, rightRamp, harpoonGate, fishPhone, fin, boat
    /// The five beach shots, left to right (cameos start here; the roving shots move across them).
    static let beach: [ChompShot] = [.leftLoop, .waveRamp, .centerRamp, .reel, .rightRamp]
}

@MainActor
final class ChompCameos {
    enum Kind: Int, CaseIterable {
        case nightSwim, beachPanic, scars, pondAttack, raftAttack
        var title: String {
            switch self {
            case .nightSwim: return "SKINNY DIP PANIC"
            case .beachPanic: return "FLAMINGO FLOAT STAMPEDE"
            case .scars: return "SCAR COMPARISON NIGHT"
            case .pondAttack: return "KIDDIE POOL INCIDENT"
            case .raftAttack: return "POOL NOODLE RAFT"
            }
        }
        var startShot: ChompShot { ChompShot.beach[rawValue] }
        /// The jackpot's share of the cameo's total, and the backup's if the fin is missed (the real percentages).
        var jackpotShare: Double { [0.35, 0.50, 0.35, 0.20, 0.30][rawValue] }
        var backupShare: Double { [0.20, 0.25, 0.15, 0.10, 0.15][rawValue] }
    }

    enum Lamp { case off, white, blue, blueFast, final, jackpot }

    enum Effect {
        case score(Int, String?)          // points (already × the 2x boost) and an optional banner
        case banner(String)
        case beachJunk
        case raiseFin
        case dropFin
        case started(Kind)
        case ended(Kind, completed: Bool)
    }

    // Placeholders (the rulesheet gives no number for these).
    static let baseSeconds: TimeInterval = 45
    static let boostSeconds: TimeInterval = 15
    static let finWindow: TimeInterval = 15
    static let boostPoints = 5_000_000
    static let beachPanicValue = 3_000_000
    static let pondShotValue = 1_000_000
    static let pondReelStart = 2_000_000
    static let raftComboWindow: TimeInterval = 5

    // Lighting
    private(set) var played: Set<Kind> = []
    private(set) var boatHits = 0
    private(set) var boost = 0                       // 0…3 (1: +15 s, 2: 5M + Beach Junk, 3: 2x)
    private(set) var macheteBonus = 0                // +1 per cameo jackpot (the machete milestone uses it)
    private(set) var festivalLit = false             // all five played (the 4th of July comes with rules depth)
    var isLit: Bool {
        active == nil && jackpotUntil == nil && played.count < Kind.allCases.count && boatHits >= 1 + played.count
    }

    // The running cameo
    private(set) var active: Kind?
    private(set) var timeLeft: TimeInterval = 0
    private(set) var total = 0
    private var phase = 1
    private var count = 0
    private var value = 0
    private var lit: [ChompShot: Lamp] = [:]
    private var lastMade: ChompShot?
    private var deductions = 0                       // Scars: shark tower hits this phase
    private var reelAward = 0                        // Pond Attack
    private var reelAt: TimeInterval = -10
    private var awards = 0                           // Pond Attack reel awards / Raft Attack fin awards
    private var rampAt: TimeInterval = -10           // Raft Attack combo
    private var comboFrom: ChompShot?
    private var comboMult = 1
    private var finUp = false                        // Raft Attack: raised by a ramp
    private var rove = 0                             // Night Swim phase 2: the first of the two roving shots
    private var roveAt: TimeInterval = 0

    // The jackpot (after a cameo is finished) and the backup
    /// Seconds left to hit the fin (nil = no jackpot lit). Counts down with the cameo clock once the fin is up.
    private(set) var jackpotUntil: TimeInterval?
    private var jackpotRunning = false
    private var jackpotKind: Kind?
    private(set) var backupValue = 0

    // MARK: - Reading

    func lamp(_ s: ChompShot) -> Lamp {
        if jackpotUntil != nil { return s == .fin ? .jackpot : .off }
        if let k = active {
            if k == .raftAttack, s == .fin { return finUp ? .final : .off }
            return lit[s] ?? .off
        }
        if s == .boat, backupValue > 0 { return .jackpot }
        if isLit, ChompShot.beach.contains(s), !played.contains(Kind.allCases[ChompShot.beach.firstIndex(of: s)!]) { return .white }
        if s == .boat { return .blue }                // the boat lights the next cameo
        return .off
    }

    /// What the fin should do: nil = its own behaviour (it pops back up), true = up, false = down.
    var finWanted: Bool? {
        if jackpotUntil != nil { return true }
        if active == .raftAttack { return finUp }
        return nil
    }

    var isRunning: Bool { active != nil || jackpotUntil != nil }

    func statusText(now: TimeInterval) -> String? {
        if let left = jackpotUntil, let k = jackpotKind {
            let pay = Self.millions(Int(Double(total) * k.jackpotShare))
            return jackpotRunning ? "FIN JACKPOT \(pay) · \(max(0, Int(left)))s" : "FIN JACKPOT \(pay) · HIT THE FIN"
        }
        if let k = active { return "\(k.title) · \(progressText(k)) · \(max(0, Int(timeLeft)))s" }
        if isLit { return "CAMEO LIT · SHOOT A FLASHING SHOT" }
        if backupValue > 0 { return "BOAT: BACKUP JACKPOT \(Self.millions(backupValue))" }
        return nil
    }

    private func progressText(_ k: Kind) -> String {
        switch k {
        case .nightSwim: return phase == 1 ? "BLUE \(min(count, 4))/4" : phase == 2 ? "ROVING \(count)/3" : "LEFT LOOP"
        case .beachPanic: return phase == 1 ? "\(min(count, 8))/8" : "WAVE RAMP"
        case .scars: return "PHASE \(phase) · \(Self.millions(scarValue))"
        case .pondAttack: return "REEL \(awards)/3 · \(Self.millions(reelAward))"
        case .raftAttack: return "FIN \(awards)/3"
        }
    }

    static func millions(_ p: Int) -> String {
        p >= 1_000_000 ? String(format: p % 1_000_000 == 0 ? "%.0fM" : "%.1fM", Double(p) / 1_000_000) : "\(p / 1000)K"
    }

    // MARK: - Game flow

    func newGame() {
        played = []; boatHits = 0; boost = 0; macheteBonus = 0; festivalLit = false
        active = nil; jackpotUntil = nil; jackpotKind = nil; jackpotRunning = false; backupValue = 0; lit = [:]
    }

    /// A ball lost (not saved): a running cameo ends without its jackpot; a lit fin jackpot becomes the boat backup (v2c).
    func ballLost() -> [Effect] {
        var fx: [Effect] = []
        if let k = active { fx.append(.ended(k, completed: false)); active = nil; lit = [:]; boost = 0; finUp = false }
        if jackpotUntil != nil, let k = jackpotKind {     // M5 v2c: as a missed fin — the backup lights at the boat
            backupValue = Int(Double(total) * k.backupShare)
            jackpotUntil = nil; jackpotKind = nil; jackpotRunning = false
            fx.append(.banner("BACKUP AT THE BOAT"))
            fx.append(.ended(k, completed: true))
        }
        return fx
    }

    func tick(dt: TimeInterval, now: TimeInterval) -> [Effect] {
        var fx: [Effect] = []
        if jackpotRunning, let left = jackpotUntil { jackpotUntil = left - dt }
        if jackpotRunning, let left = jackpotUntil, left <= 0, let k = jackpotKind {
            jackpotUntil = nil; jackpotKind = nil; jackpotRunning = false
            backupValue = Int(Double(total) * k.backupShare)
            fx.append(.banner("FIN MISSED · BACKUP AT THE BOAT"))
            fx.append(.ended(k, completed: true))
            return fx
        }
        guard let k = active else { return fx }
        timeLeft -= dt
        if timeLeft <= 0 {
            active = nil; lit = [:]; boost = 0
            fx.append(.banner("\(k.title) · TIME"))
            if k == .raftAttack { finUp = false }
            fx.append(.ended(k, completed: false))
            return fx
        }
        if k == .pondAttack, lit[.harpoonGate] != nil, now - reelAt > 6 { lit[.harpoonGate] = nil }
        if k == .nightSwim, phase == 2, now - roveAt >= 1.5 {            // the two roving blue shots move along
            roveAt = now
            rove = (rove + 1) % ChompShot.beach.count
            lightRoving()
        }
        return fx
    }

    // MARK: - Shots

    func sharkTowerHit() {
        guard active == .scars else { return }
        deductions += 1
    }

    func shot(_ s: ChompShot, now: TimeInterval) -> [Effect] {
        if s == .boat { return boatHit() }
        if s == .fin, let k = jackpotKind, jackpotUntil != nil {
            let pay = Int(Double(total) * k.jackpotShare)
            jackpotUntil = nil; jackpotKind = nil; jackpotRunning = false
            macheteBonus += 1
            return [.score(pay, "CAMEO JACKPOT \(Self.millions(pay))"), .ended(k, completed: true)]
        }
        if let k = active { return modeShot(k, s, now: now) }
        if isLit, ChompShot.beach.contains(s) {
            let k = Kind.allCases[ChompShot.beach.firstIndex(of: s)!]
            if !played.contains(k) { return start(k, now: now) }
        }
        return []
    }

    private func boatHit() -> [Effect] {
        var fx: [Effect] = []
        if backupValue > 0, active == nil {
            let pay = backupValue; backupValue = 0
            fx.append(.score(pay, "BACKUP JACKPOT \(Self.millions(pay))"))
        }
        if active != nil || isLit {
            guard boost < 3 else { return fx }
            boost += 1
            switch boost {
            case 1:
                if active != nil { timeLeft += Self.boostSeconds }
                fx.append(.banner("BOOST · +15 SECONDS"))
            case 2:
                fx.append(.score(multiplied(Self.boostPoints), "BOOST · 5M + BEACH JUNK"))
                fx.append(.beachJunk)
            default:
                fx.append(.banner("BOOST · 2X SCORING"))
            }
            return fx
        }
        guard jackpotUntil == nil else { return fx }
        boatHits += 1
        if isLit { fx.append(.banner("CAMEO LIT")) }
        return fx
    }

    private func multiplied(_ p: Int) -> Int { boost >= 3 ? p * 2 : p }

    private func start(_ k: Kind, now: TimeInterval) -> [Effect] {
        played.insert(k)
        if played.count == Kind.allCases.count { festivalLit = true }
        active = k
        boatHits = 0
        timeLeft = Self.baseSeconds + (boost >= 1 ? Self.boostSeconds : 0)
        total = 0; phase = 1; count = 0; lit = [:]; lastMade = nil; deductions = 0; awards = 0
        backupValue = 0
        var fx: [Effect] = [.started(k), .banner(k.title)]
        switch k {
        case .nightSwim:
            value = 1_000_000
            lightNightSwimPhase1(except: nil)
        case .beachPanic:
            value = Self.beachPanicValue
            relightBeachPanic()
        case .scars:
            lightScars()
        case .pondAttack:
            reelAward = Self.pondReelStart
            for b in ChompShot.beach where b != .reel { lit[b] = .blue }
            lit[.reel] = .final
        case .raftAttack:
            lit[.waveRamp] = .blue; lit[.rightRamp] = .blue
            finUp = false; comboFrom = nil
            fx.append(.dropFin)
        }
        return fx
    }

    private func modeShot(_ k: Kind, _ s: ChompShot, now: TimeInterval) -> [Effect] {
        let lamp = lit[s] ?? .off
        switch k {
        case .nightSwim:
            guard lamp != .off else { return [] }
            if phase == 1 {
                if lamp == .final {                                       // a phase-2 opener: left loop, right ramp, gate
                    phase = 2; count = 0; roveAt = now; rove = 0; lightRoving()
                    return [pay(value, "\(k.title) · PHASE 2")]
                }
                let fast = lamp == .blueFast
                count += fast ? 2 : 1
                let fx = pay(value * (fast ? 2 : 1), nil)
                value += 750_000
                if count >= 4 {
                    lit = [.leftLoop: .final, .rightRamp: .final, .harpoonGate: .final]
                } else {
                    lightNightSwimPhase1(except: s)
                }
                return [fx]
            }
            if phase == 2 {
                count += 1
                let fx = pay(value, nil)
                value += 750_000
                if count >= 3 { phase = 3; lit = [.leftLoop: .final] }
                return [fx]
            }
            return finish(k, pay(value, nil))                             // phase 3: the left loop
        case .beachPanic:
            guard lamp != .off else { return [] }
            if phase == 2 {
                if s == .waveRamp { return finish(k, pay(value, nil)) }
                let fx = pay(value, nil)                                  // points only, no 2x
                lastMade = s
                for b in ChompShot.beach where b != .waveRamp { lit[b] = b == lastMade ? .off : .blue }
                return [fx]
            }
            let fast = lamp == .blueFast
            count += fast ? 2 : 1
            let fx = pay(value * (fast ? 2 : 1), nil)
            lastMade = s
            if count >= 8 {
                phase = 2
                for b in ChompShot.beach { lit[b] = b == .waveRamp ? .final : (b == s ? .off : .blue) }
            } else {
                relightBeachPanic()
            }
            return [fx]
        case .scars:
            guard lamp != .off else { return [] }
            let fx = pay(scarValue, nil)
            if phase == 3 { return finish(k, fx) }                       // any Fish Phone target
            if lamp == .final {                                           // the center ramp ends the phase
                phase += 1; deductions = 0; count = 0
                lightScars()
                return [fx, .banner("\(k.title) · PHASE \(phase)")]
            }
            lit[s] = .off
            count += 1
            if count >= 2 { lit = [.centerRamp: .final] }
            return [fx]
        case .pondAttack:
            if s == .reel {
                awards += 1
                reelAt = now
                let fx = pay(reelAward, "REEL AWARD \(Self.millions(multiplied(reelAward)))")
                lit[.harpoonGate] = .blueFast
                if awards >= 3 { return finish(k, fx) }
                return [fx]
            }
            if s == .harpoonGate, lamp == .blueFast, now - reelAt <= 6 {  // the harpoon right after a reel: the award again
                lit[.harpoonGate] = .off
                return [pay(reelAward, "HARPOONED · \(Self.millions(multiplied(reelAward)))")]
            }
            guard lamp == .blue else { return [] }
            reelAward += 100_000
            return [pay(Self.pondShotValue, nil)]
        case .raftAttack:
            if s == .waveRamp || s == .rightRamp {
                rampAt = now; comboFrom = s; comboMult = 1
                let wasUp = finUp
                finUp = true
                return wasUp ? [] : [.raiseFin]
            }
            if let from = comboFrom, now - rampAt <= Self.raftComboWindow, finUp {
                // The real combos: ramp → center ramp → fin 2x; ramp → left loop → fin 3x; wave ramp → gate → fin 4x.
                if s == .centerRamp { comboMult = 2; rampAt = now }
                if s == .leftLoop { comboMult = 3; rampAt = now }
                if s == .harpoonGate, from == .waveRamp { comboMult = 4; rampAt = now }
            }
            if s == .fin, finUp {
                let mult = now - rampAt <= Self.raftComboWindow ? comboMult : 1
                let award = (5_000_000 + 2_000_000 * awards) * mult
                awards += 1
                finUp = false; comboFrom = nil; comboMult = 1
                let fx = pay(award, "FIN AWARD \(Self.millions(multiplied(award)))")
                if awards >= 3 { return finish(k, fx) }
                return [fx, .dropFin]
            }
            return []
        }
    }

    private var scarValue: Int {
        let cuts = [2_250_000, 1_500_000, 1_125_000, 625_000]
        let cut = cuts.prefix(min(deductions, cuts.count)).reduce(0, +)
        return max(0, [6_000_000, 7_000_000, 8_000_000][min(phase, 3) - 1] - cut)
    }

    private func pay(_ points: Int, _ banner: String?) -> Effect {
        let p = multiplied(points)
        total += p
        return .score(p, banner)
    }

    private func finish(_ k: Kind, _ last: Effect) -> [Effect] {
        active = nil; lit = [:]; boost = 0; finUp = false
        jackpotKind = k
        jackpotUntil = Self.finWindow
        jackpotRunning = false                                          // starts once the fin is up
        return [last, .banner("\(k.title) DONE · HIT THE FIN"), .raiseFin]
    }

    /// The scene starts the fin window on its own clock once the fin is up.
    func startJackpotWindow(now: TimeInterval) {
        if jackpotUntil != nil { jackpotRunning = true }
    }

    // MARK: - Lamps

    private func lightNightSwimPhase1(except made: ChompShot?) {
        lit = [:]
        let choices = ChompShot.beach.filter { $0 != made }.shuffled()
        lit[choices[0]] = .blueFast
        lit[choices[1]] = .blue
    }

    private func lightRoving() {
        lit = [:]
        let a = ChompShot.beach[rove % 5], b = ChompShot.beach[(rove + 1) % 5]
        lit[a] = .blue; lit[b] = .blue
    }

    private func relightBeachPanic() {
        lit = [:]
        for b in ChompShot.beach where b != lastMade { lit[b] = .blue }
        if let fast = ChompShot.beach.filter({ $0 != lastMade }).randomElement() { lit[fast] = .blueFast }
    }

    private func lightScars() {
        lit = [:]
        switch phase {
        case 1: lit[.waveRamp] = .blue; lit[.rightRamp] = .blue
        case 2: lit[.waveRamp] = .blue; lit[.harpoonGate] = .blue
        default: lit[.fishPhone] = .final
        }
    }
}
