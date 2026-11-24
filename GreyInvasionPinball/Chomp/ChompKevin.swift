// Pinball Lab Table 07 (CHOMP!), M5 v4: the Stink Line, the flamingos and Kevin Multiball — the real table's chum
// line, barrels and Jaws Multiball, renamed (the plan's section 5: "the casserole fills the Stink Line; a full line
// lights the fin; hitting the moving fin harpoons a pool flamingo onto Kevin. Flamingos needed: 1, 2, 3").
// Pure rules: the scene feeds it the chum bucket, shots and time, and applies what comes back.
// Rules from the Jaws rulesheet (code 1.01, pinballrulesheets.com): a chum bucket hit starts the line; three red
// arrows light at the left loop, wave ramp and center ramp and move right every few seconds (wrapping); shooting a
// red arrow — or the bucket again — advances the line. A full line lights the shots that feed the left flipper
// (harpoon, left loop, center ramp) yellow; a yellow shot raises the fin and hitting it attaches a flamingo. With
// enough flamingos, a shot that feeds the inlanes (harpoon, left loop, center ramp, right ramp) starts the multiball:
// red shots pay awards; after three, a jackpot shot flashes; more red shots before it raise it (to 3x); five
// jackpots finish it. Numbers the rulesheet doesn't give are placeholders (marked).
// M5 v6 — the later levels (rulesheet): the line takes 1 / 2 / 3 bucket hits to start; at level 2 the red arrows go
// out when hit or when they move past the right ramp (the bucket lights three new ones once all are gone); at level 3
// the bucket no longer advances a started line. Later flamingos: a full line lights "ready flamingo" at the Fish Phone
// bank; completing the bank lights only the left loop and harpoon yellow to raise the fin. KMB 2 "The Chase": switch
// hits light all five beach shots for jackpots, more (each time more) light them again; once all five have paid, 90
// more switches light the boat for 20M super jackpots for 10 s. KMB 3 "Dog Crate Dive": red shots raise a hurry-up
// jackpot at the boat before its time runs out; after three, 50M super jackpots at the fin, each fin hit one more x.
import Foundation

@MainActor
final class ChompKevin {
    enum Lamp { case off, red, yellow, start, jackpot }
    enum Effect {
        case score(Int, String?)          // points and an optional banner (held over the shot names)
        case startMultiball(Int)          // balls in play wanted
        case addBall                      // M5 v5: the Stink Line refilled during the multiball
        case multiballOver
    }
    enum Stage { case idle, line, readyBarrel, yellow, finUp, ready, multiball }

    static let titles = ["REEL HIM IN-ISH!", "THE CHASE (IS ON, SORT OF)", "DOG CRATE DIVE"]
    static let yellowShots: [ChompShot] = [.harpoonGate, .leftLoop, .centerRamp]
    static let laterYellowShots: [ChompShot] = [.leftLoop, .harpoonGate]      // M5 v6: after the bank (flamingos 2+)
    static let startHits = [1, 2, 3]                                             // bucket hits that start the line
    static let superJackpot2 = 20_000_000, superSeconds2: TimeInterval = 10, superSwitches2 = 90
    static let superJackpot3 = 50_000_000, diveJackpotsForSuper = 3
    static let startShots: [ChompShot] = [.harpoonGate, .leftLoop, .centerRamp, .rightRamp]
    static let jackpotsToFinish = 5
    static let awardsBeforeJackpot = 3
    static let redsLit = 2
    static let maxJackpotMultiplier = 3
    // Placeholders (the rulesheet gives no number for these).
    static let lineNeeded = 3
    static let arrowStepSeconds: TimeInterval = 3
    static let lineBase = 1_000_000
    static let lineStep = 250_000
    static let flamingoPoints = 5_000_000
    static let multiballBalls = 2
    static let multiballSaveSeconds: TimeInterval = 15
    static let launchSpeed: CGFloat = 1_800      // an auto-launched ball: off the pin, down to the flippers
    static let redValue = 2_500_000
    static let jackpotBase = 10_000_000
    /// M5 v5: chum bucket hits that refill the line during KMB 1 / 2 / 3 and add a ball (rulesheet: 3, 8, 5).
    static let refillHits = [3, 8, 5]
    static let maxBalls = 4                        // placeholder cap on add-a-balls
    // M5 v6 placeholders: The Chase's switch counts and jackpot; Dog Crate Dive's hurry-up.
    static let chaseFirstSwitches = 25, chaseMoreSwitches = 15, chaseJackpot = 8_000_000
    static let hurryStart = 10_000_000, hurryPerRed = 2_500_000, hurrySeconds: TimeInterval = 30, hurryFloor = 0.25

    private(set) var stage: Stage = .idle
    private(set) var level = 1                     // the next / running KMB (1–3)
    private(set) var flamingos = 0
    private(set) var lineCount = 0
    private var lineValue = 0                      // the line's total: the next multiball's jackpot grows with it
    private var arrows: [Int] = []                 // indexes into ChompShot.beach
    private var arrowAt: TimeInterval = 0
    // The running multiball
    private var reds: Set<ChompShot> = []
    private var awards = 0
    private var jackpotShot: ChompShot?
    private var jackpotMult = 1
    private(set) var jackpots = 0
    private(set) var refill = 0                    // M5 v5: bucket hits toward the next add-a-ball
    private var startCount = 0                     // M5 v6: bucket hits toward starting the line
    private var flamingoPath: [ChompShot] { flamingos == 0 && level == 1 ? Self.yellowShots : Self.laterYellowShots }
    // KMB 2
    private var chaseSwitches = 0, chaseNeeded = 0
    private var chaseLit: Set<ChompShot> = [], chasePaid: Set<ChompShot> = []
    private var superSwitches = 0
    private var superUntil: TimeInterval?
    // KMB 3
    private var hurryBase = 0
    private var hurryUntil: TimeInterval = 0
    private var supers = 0
    private var now: TimeInterval = 0
    var refillNeeded: Int { Self.refillHits[min(level, 3) - 1] }

    var multiballActive: Bool { stage == .multiball }
    var title: String { Self.titles[min(level, 3) - 1] }
    /// The fin is held up while a yellow shot has raised it for a flamingo.
    var finWanted: Bool? { stage == .finUp || (multiballActive && level == 3 && jackpots >= Self.diveJackpotsForSuper) ? true : nil }
    var hurryValue: Int {
        let left = max(0, hurryUntil - now) / Self.hurrySeconds
        return Int(Double(hurryBase) * (Self.hurryFloor + (1 - Self.hurryFloor) * left)) / 100_000 * 100_000
    }
    var jackpotValue: Int { (Self.jackpotBase + lineValue) * jackpotMult }

    func lamp(_ s: ChompShot) -> Lamp {
        switch stage {
        case .line: return arrows.contains(where: { ChompShot.beach[$0] == s }) ? .red : .off
        case .readyBarrel: return s == .fishPhone ? .yellow : .off
        case .yellow: return flamingoPath.contains(s) ? .yellow : .off
        case .ready: return Self.startShots.contains(s) ? .start : .off
        case .multiball:
            switch level {
            case 2: return (s == .boat && superUntil != nil) || chaseLit.contains(s) ? .jackpot : .off
            case 3:
                if jackpots >= Self.diveJackpotsForSuper { return s == .fin ? .jackpot : .off }
                return s == .boat ? .jackpot : (reds.contains(s) ? .red : .off)
            default: return s == jackpotShot ? .jackpot : (reds.contains(s) ? .red : .off)
            }
        case .idle, .finUp: return .off
        }
    }

    func statusText() -> String? {
        switch stage {
        case .idle: return startCount > 0 ? "STINK LINE · BUCKET \(startCount)/\(Self.startHits[level - 1])" : nil
        case .line: return "STINK LINE \(lineCount)/\(Self.lineNeeded) · RED ARROWS" + (level < 3 ? " OR THE BUCKET" : "")
        case .readyBarrel: return "READY FLAMINGO · COMPLETE THE FISH PHONE BANK"
        case .yellow: return "STINK LINE FULL · A YELLOW SHOT RAISES THE FIN"
        case .finUp: return "HIT THE FIN · FLAMINGO \(flamingos + 1)/\(level)"
        case .ready: return "KEVIN MULTIBALL LIT · LOOP · HARPOON · RAMPS"
        case .multiball where level == 2:
            let phase = superUntil != nil ? "BOAT SUPER JACKPOT \(ChompCameos.millions(Self.superJackpot2)) · \(max(0, Int(((superUntil ?? now) - now).rounded(.up))))s"
                : !chaseLit.isEmpty ? "JACKPOTS LIT · \(chasePaid.count)/5 PAID"
                : chasePaid.count >= ChompShot.beach.count ? "SUPER \(superSwitches)/\(Self.superSwitches2) · RELIGHT \(chaseSwitches)/\(chaseNeeded)"
                : "SWITCHES \(chaseSwitches)/\(chaseNeeded)"
            return "\(title) · \(phase) · ADD-A-BALL \(refill)/\(refillNeeded)"
        case .multiball where level == 3:
            let phase = jackpots >= Self.diveJackpotsForSuper ? "FIN SUPER \(ChompCameos.millions(Self.superJackpot3 * (supers + 1)))"
                : "BOAT \(ChompCameos.millions(hurryValue)) · \(max(0, Int((hurryUntil - now).rounded(.up))))s · \(jackpots)/\(Self.diveJackpotsForSuper)"
            return "\(title) · \(phase) · ADD-A-BALL \(refill)/\(refillNeeded)"
        case .multiball:
            let jp = jackpotShot != nil ? " · JACKPOT \(ChompCameos.millions(jackpotValue))" : ""
            let count = jackpots >= Self.jackpotsToFinish ? "COMPLETE · JACKPOTS \(jackpots)" : "JACKPOTS \(jackpots)/\(Self.jackpotsToFinish)"
            return "\(title) · \(count)\(jp) · ADD-A-BALL \(refill)/\(refillNeeded)"
        }
    }

    func newGame() {
        stage = .idle; level = 1; flamingos = 0; lineCount = 0; lineValue = 0; arrows = []
        reds = []; awards = 0; jackpotShot = nil; jackpotMult = 1; jackpots = 0; startCount = 0
        chaseLit = []; chasePaid = []; superUntil = nil; supers = 0
    }

    /// Every frame: the red arrows move right along the beach shots (wrapping from the right ramp to the left loop;
    /// at level 2 an arrow moving past the right ramp goes out). v6: the multiball clocks.
    func tick(now: TimeInterval) -> [Effect] {
        self.now = now
        if stage == .multiball {
            if level == 2, let until = superUntil, now >= until {
                superUntil = nil; superSwitches = 0
                return [.score(0, "SUPER JACKPOT OVER")]
            }
            if level == 3, jackpots < Self.diveJackpotsForSuper, now >= hurryUntil {
                hurryBase = Self.hurryStart + lineValue; hurryUntil = now + Self.hurrySeconds
                return [.score(0, "BOAT JACKPOT TIMED OUT · AGAIN")]
            }
            return []
        }
        guard stage == .line, now - arrowAt >= Self.arrowStepSeconds else { return [] }
        arrowAt = now
        if level == 2 {
            arrows = arrows.compactMap { $0 + 1 < ChompShot.beach.count ? $0 + 1 : nil }
        } else {
            arrows = arrows.map { ($0 + 1) % ChompShot.beach.count }
        }
        return []
    }

    /// M5 v6: any switch (the scene's labEvent) — The Chase counts them.
    func switchHit() -> [Effect] {
        guard stage == .multiball, level == 2 else { return [] }
        var fx: [Effect] = []
        if chaseLit.isEmpty {                                        // v6b: the re-light runs on every switch too
            chaseSwitches += 1
            if chaseSwitches >= chaseNeeded {
                chaseSwitches = 0
                chaseNeeded += Self.chaseMoreSwitches
                chaseLit = Set(ChompShot.beach)
                fx.append(.score(0, "JACKPOTS LIT"))
            }
        }
        if chasePaid.count >= ChompShot.beach.count, superUntil == nil {
            superSwitches += 1
            if superSwitches >= Self.superSwitches2 {
                superUntil = now + Self.superSeconds2
                fx.append(.score(0, "BOAT SUPER JACKPOT LIT · 10s"))
            }
        }
        return fx
    }

    /// M5 v6: the Fish Phone bank completed — the ready flamingo (later flamingos) lights the left loop and harpoon.
    func bankComplete() -> [Effect] {
        guard stage == .readyBarrel else { return [] }
        stage = .yellow
        return [.score(0, "FLAMINGO READY · LOOP OR HARPOON RAISES THE FIN")]
    }

    /// The chum bucket: the first hit starts the line, later hits advance it.
    func bucketHit(now: TimeInterval) -> [Effect] {
        switch stage {
        case .idle:
            startCount += 1
            guard startCount >= Self.startHits[level - 1] else {
                return [.score(0, "STINK LINE · BUCKET \(startCount)/\(Self.startHits[level - 1])")]
            }
            startCount = 0
            stage = .line
            lineCount = 0                                       // v6: lineValue keeps growing until the multiball
            arrows = [0, 1, 2]
            arrowAt = now
            return [.score(0, "STINK LINE · CHASE THE RED ARROWS")]
        case .line:
            if level == 3 { return [] }                         // v6: at level 3 the bucket no longer advances it
            if level == 2, arrows.isEmpty { arrows = [0, 1, 2]; arrowAt = now; return [.score(0, "THREE NEW RED ARROWS")] }
            return advance(now: now)
        case .multiball:
            refill += 1
            guard refill >= refillNeeded else { return [.score(Self.lineBase, "ADD-A-BALL \(refill)/\(refillNeeded)")] }
            refill = 0
            return [.score(Self.lineBase, "ADD-A-BALL"), .addBall]
        default:
            return []
        }
    }

    func shot(_ s: ChompShot, now: TimeInterval) -> [Effect] {
        switch stage {
        case .idle:
            return []
        case .line:
            guard let k = arrows.firstIndex(where: { ChompShot.beach[$0] == s }) else { return [] }
            arrows.remove(at: k)
            let fx = advance(now: now)
            if stage == .line, arrows.isEmpty, level != 2 { arrows = [0, 1, 2]; arrowAt = now }   // three more
            return fx
        case .readyBarrel:
            return []
        case .yellow:
            guard flamingoPath.contains(s) else { return [] }
            stage = .finUp
            return [.score(0, "FIN UP · HIT IT")]
        case .finUp:
            guard s == .fin else { return [] }
            flamingos += 1
            if flamingos >= level {
                stage = .ready
                return [.score(Self.flamingoPoints, "FLAMINGO \(flamingos)/\(level) · KEVIN MULTIBALL LIT")]
            }
            stage = .idle                                                  // the next flamingo needs another line
            return [.score(Self.flamingoPoints, "FLAMINGO \(flamingos)/\(level)")]
        case .ready:
            guard Self.startShots.contains(s) else { return [] }
            stage = .multiball
            reds = []; awards = 0; jackpotShot = nil; jackpotMult = 1; jackpots = 0; refill = 0
            chaseLit = []; chasePaid = []; chaseSwitches = 0; chaseNeeded = Self.chaseFirstSwitches
            superSwitches = 0; superUntil = nil; supers = 0
            hurryBase = Self.hurryStart + lineValue; hurryUntil = now + Self.hurrySeconds
            if level != 2 { topUpReds() }
            return [.score(0, title), .startMultiball(Self.multiballBalls)]
        case .multiball where level == 2:
            if s == .boat, superUntil != nil {
                supers += 1
                return [.score(Self.superJackpot2, "SUPER JACKPOT · \(ChompCameos.millions(Self.superJackpot2))")]
            }
            guard chaseLit.contains(s) else { return [] }
            chaseLit.remove(s)
            let first = !chasePaid.contains(s)
            chasePaid.insert(s)
            jackpots += 1
            let pay = Self.chaseJackpot + lineValue / 4
            let all = first && chasePaid.count == ChompShot.beach.count
            return [.score(pay, all ? "\(title) COMPLETE · \(ChompCameos.millions(pay)) · 90 SWITCHES FOR THE SUPER"
                                    : "CHASE JACKPOT · \(ChompCameos.millions(pay))")]
        case .multiball where level == 3:
            if jackpots >= Self.diveJackpotsForSuper {
                guard s == .fin else { return [] }
                supers += 1
                let pay = Self.superJackpot3 * supers
                return [.score(pay, (supers == 1 ? "\(title) COMPLETE · " : "") + "FIN SUPER JACKPOT · \(ChompCameos.millions(pay))")]
            }
            if s == .boat {
                let pay = hurryValue
                jackpots += 1
                hurryBase = Self.hurryStart + lineValue; hurryUntil = now + Self.hurrySeconds
                let lit = jackpots >= Self.diveJackpotsForSuper
                return [.score(pay, "BOAT JACKPOT \(jackpots) · \(ChompCameos.millions(pay))" + (lit ? " · FIN SUPER LIT" : ""))]
            }
            guard reds.contains(s) else { return [] }
            reds.remove(s)
            topUpReds()
            hurryBase += Self.hurryPerRed
            return [.score(Self.redValue, "BOAT JACKPOT · \(ChompCameos.millions(hurryValue))")]
        case .multiball:
            if s == jackpotShot {
                let pay = jackpotValue
                jackpots += 1
                jackpotShot = nil; jackpotMult = 1; awards = 0
                topUpReds()
                let done = jackpots == Self.jackpotsToFinish
                return [.score(pay, done ? "\(title) COMPLETE · \(ChompCameos.millions(pay))"
                                         : "KEVIN JACKPOT \(jackpots) · \(ChompCameos.millions(pay))")]
            }
            guard reds.contains(s) else { return [] }
            reds.remove(s)
            topUpReds()
            if jackpotShot != nil {
                jackpotMult = min(Self.maxJackpotMultiplier, jackpotMult + 1)
                return [.score(Self.redValue, "JACKPOT \(jackpotMult)X · \(ChompCameos.millions(jackpotValue))")]
            }
            awards += 1
            if awards >= Self.awardsBeforeJackpot {
                jackpotShot = ChompShot.beach.filter { !reds.contains($0) }.randomElement()
                return [.score(Self.redValue, "JACKPOT LIT · \(ChompCameos.millions(jackpotValue))")]
            }
            return [.score(Self.redValue, nil)]
        }
    }

    #if DEBUG
    /// M5 v6c (debug): jump to KMB `level` (1–3), lit and ready — a start shot (harpoon, loop, center or right ramp)
    /// begins it. Only while no multiball is running.
    func debugReady(level l: Int) {
        guard stage != .multiball else { return }
        level = max(1, min(l, 3))
        flamingos = level
        lineCount = 0; startCount = 0; arrows = []
        stage = .ready
    }
    #endif

    /// The scene: one ball (or none) left in play. The next multiball needs one more flamingo.
    func multiballEnded() -> [Effect] {
        guard stage == .multiball else { return [] }
        let t = title
        stage = .idle
        level = min(level + 1, 3)
        flamingos = 0; lineCount = 0; lineValue = 0; startCount = 0
        reds = []; jackpotShot = nil; jackpotMult = 1
        chaseLit = []; chasePaid = []; superUntil = nil
        return [.score(0, "\(t) OVER"), .multiballOver]
    }

    private func advance(now: TimeInterval) -> [Effect] {
        lineCount += 1
        let value = Self.lineBase + Self.lineStep * (lineCount - 1)
        lineValue += value
        if lineCount >= Self.lineNeeded {
            arrows = []
            if flamingos == 0 && level == 1 {
                stage = .yellow
                return [.score(value, "STINK LINE FULL · SHOOT A YELLOW SHOT")]
            }
            stage = .readyBarrel                                 // v6: later flamingos go through the bank
            return [.score(value, "STINK LINE FULL · READY FLAMINGO AT THE FISH PHONE")]
        }
        return [.score(value, "STINK LINE \(lineCount)/\(Self.lineNeeded)")]
    }

    /// Two red shots lit at all times (never the jackpot shot), so three beach shots are always free for a jackpot.
    private func topUpReds() {
        while reds.count < Self.redsLit,
              let s = ChompShot.beach.filter({ !reds.contains($0) && $0 != jackpotShot }).randomElement() { reds.insert(s) }
    }
}
