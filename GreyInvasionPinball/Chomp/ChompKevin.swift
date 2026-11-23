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
// jackpots finish it. Numbers the rulesheet doesn't give are placeholders (marked). KMB 2–3's own rules (The Chase,
// Dog Crate Dive), the add-a-ball refill and flip-lock come in later rounds; until then levels 2–3 play like level 1.
import Foundation

@MainActor
final class ChompKevin {
    enum Lamp { case off, red, yellow, start, jackpot }
    enum Effect {
        case score(Int, String?)          // points and an optional banner (held over the shot names)
        case startMultiball(Int)          // balls in play wanted
        case multiballOver
    }
    enum Stage { case idle, line, yellow, finUp, ready, multiball }

    static let titles = ["REEL HIM IN-ISH!", "THE CHASE (IS ON, SORT OF)", "DOG CRATE DIVE"]
    static let yellowShots: [ChompShot] = [.harpoonGate, .leftLoop, .centerRamp]
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

    var multiballActive: Bool { stage == .multiball }
    var title: String { Self.titles[min(level, 3) - 1] }
    /// The fin is held up while a yellow shot has raised it for a flamingo.
    var finWanted: Bool? { stage == .finUp ? true : nil }
    var jackpotValue: Int { (Self.jackpotBase + lineValue) * jackpotMult }

    func lamp(_ s: ChompShot) -> Lamp {
        switch stage {
        case .line: return arrows.contains(where: { ChompShot.beach[$0] == s }) ? .red : .off
        case .yellow: return Self.yellowShots.contains(s) ? .yellow : .off
        case .ready: return Self.startShots.contains(s) ? .start : .off
        case .multiball: return s == jackpotShot ? .jackpot : (reds.contains(s) ? .red : .off)
        case .idle, .finUp: return .off
        }
    }

    func statusText() -> String? {
        switch stage {
        case .idle: return nil
        case .line: return "STINK LINE \(lineCount)/\(Self.lineNeeded) · RED ARROWS OR THE BUCKET"
        case .yellow: return "STINK LINE FULL · A YELLOW SHOT RAISES THE FIN"
        case .finUp: return "HIT THE FIN · FLAMINGO \(flamingos + 1)/\(level)"
        case .ready: return "KEVIN MULTIBALL LIT · LOOP · HARPOON · RAMPS"
        case .multiball:
            let jp = jackpotShot != nil ? " · JACKPOT \(ChompCameos.millions(jackpotValue))" : ""
            let count = jackpots >= Self.jackpotsToFinish ? "COMPLETE · JACKPOTS \(jackpots)" : "JACKPOTS \(jackpots)/\(Self.jackpotsToFinish)"
            return "\(title) · \(count)\(jp)"
        }
    }

    func newGame() {
        stage = .idle; level = 1; flamingos = 0; lineCount = 0; lineValue = 0; arrows = []
        reds = []; awards = 0; jackpotShot = nil; jackpotMult = 1; jackpots = 0
    }

    /// Every frame: the red arrows move right along the beach shots (wrapping from the right ramp to the left loop).
    func tick(now: TimeInterval) {
        guard stage == .line, now - arrowAt >= Self.arrowStepSeconds else { return }
        arrowAt = now
        arrows = arrows.map { ($0 + 1) % ChompShot.beach.count }
    }

    /// The chum bucket: the first hit starts the line, later hits advance it.
    func bucketHit(now: TimeInterval) -> [Effect] {
        switch stage {
        case .idle:
            stage = .line
            lineCount = 0; lineValue = 0
            arrows = [0, 1, 2]
            arrowAt = now
            return [.score(0, "STINK LINE · CHASE THE RED ARROWS")]
        case .line:
            return advance(now: now)
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
            if stage == .line, arrows.isEmpty { arrows = [0, 1, 2]; arrowAt = now }   // the bucket lights three more
            return fx
        case .yellow:
            guard Self.yellowShots.contains(s) else { return [] }
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
            reds = []; awards = 0; jackpotShot = nil; jackpotMult = 1; jackpots = 0
            topUpReds()
            return [.score(0, title), .startMultiball(Self.multiballBalls)]
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

    /// The scene: one ball (or none) left in play. The next multiball needs one more flamingo.
    func multiballEnded() -> [Effect] {
        guard stage == .multiball else { return [] }
        let t = title
        stage = .idle
        level = min(level + 1, 3)
        flamingos = 0; lineCount = 0; lineValue = 0
        reds = []; jackpotShot = nil; jackpotMult = 1
        return [.score(0, "\(t) OVER"), .multiballOver]
    }

    private func advance(now: TimeInterval) -> [Effect] {
        lineCount += 1
        let value = Self.lineBase + Self.lineStep * (lineCount - 1)
        lineValue += value
        if lineCount >= Self.lineNeeded {
            stage = .yellow
            arrows = []
            return [.score(value, "STINK LINE FULL · SHOOT A YELLOW SHOT")]
        }
        return [.score(value, "STINK LINE \(lineCount)/\(Self.lineNeeded)")]
    }

    /// Two red shots lit at all times (never the jackpot shot), so three beach shots are always free for a jackpot.
    private func topUpReds() {
        while reds.count < Self.redsLit,
              let s = ChompShot.beach.filter({ !reds.contains($0) && $0 != jackpotShot }).randomElement() { reds.insert(s) }
    }
}
