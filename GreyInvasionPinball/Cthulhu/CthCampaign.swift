// Pinball Lab Table 03 (Cthulhu Rising), milestone 7: the story as rules. Round 2: Act 1, Research (three tomes).
// Round 3: Act 2, the Ritual (two-ball multiball, five candles). Round 4: Act 3, the Awakening (three-ball finale).
// Grey Invasion's Campaign pattern: the scene reports shots and time, the campaign keeps the act's state and
// returns events, and the scene turns events into points, banners, lamps and sounds.
import Foundation

/// The shots the rules care about. Raw values match the shot-arrow lamp names ("arrow.<rawValue>").
enum CthShot: String, CaseIterable {
    case rightRamp, orbit, library, lagoon, sigil

    var label: String {
        switch self {
        case .rightRamp: return "RAMP"
        case .orbit: return "ORBIT"
        case .library: return "LIBRARY"
        case .lagoon: return "LAGOON"
        case .sigil: return "SIGIL"
        }
    }
}

@MainActor
final class CthCampaign {
    enum Phase: Equatable {
        case research           // earning clues
        case libraryLit         // three clues: the Library opens the next tome
        case tome(Int)          // 0 Necronomicon, 1 Pnakotic Manuscripts, 2 Sea Captain's Log
        case ritualLit          // three tomes read: the Library starts the Ritual
        case ritual             // the Ritual multiball: five candle shots
        case awakening          // the finale: cut four tentacles, then strike the eye three times
    }

    enum Event {
        case clue(Int)                              // clues so far
        case libraryLit
        case tomeStarted(Int)
        case progress(points: Int, banner: String?)
        case tomeFinished(Int, points: Int)
        case tomeFailed(Int)
        case ritualLit
        case ritualStarted                          // the scene starts the two-ball multiball
        case candleLit(Int, points: Int)            // candle index (= ritualShots index)
        case summoning(points: Int)                 // all five candles
        case ritualFaltered                         // the multiball ended first: candles kept, Ritual relit
        case awakeningStarted                       // Cthulhu rises; the scene makes it a three-ball multiball
        case tentacleHit(Int, cut: Bool, points: Int)
        case eyeOpen                                // all four tentacles cut
        case eyeStruck(Int, points: Int)            // eye hits so far
        case banished(points: Int)                  // the third eye hit: next cycle, all awards ×cycle
        case cthulhuEscaped                         // the multiball ended first: he sinks, the Ritual relights
    }

    static let tomeNames = ["NECRONOMICON", "PNAKOTIC MANUSCRIPTS", "SEA CAPTAIN'S LOG"]
    static let tomeShortNames = ["NECRONOMICON", "PNAKOTIC", "CAPTAIN'S LOG"]
    static let roman = ["I", "II", "III"]
    static let cluesNeeded = 2                      // M7 v5 (simulator): was 3
    // Tome I: turn 40 pages in 50 s; each spinner spin turns a page, each ramp turns 10.
    // M7 v5 (simulator): was 60 pages in 40 s, which stopped nearly every beginner.
    static let pagesNeeded = 40
    static let pagesPerRamp = 10
    static let necronomiconTime: TimeInterval = 50
    // Tome II: two random lit shots in 30 s (two, not three: Grey Invasion's simulator lesson).
    static let glyphCount = 2
    static let glyphTime: TimeInterval = 30
    static let glyphPool: [CthShot] = [.rightRamp, .orbit, .library, .lagoon, .sigil]
    static let glyphPoints = 5_000
    static let tomePoints = 25_000                  // × tome number × cycle
    /// The Ritual's five candle shots, one per candle lamp (candle.0 … candle.4).
    static let ritualShots: [CthShot] = [.orbit, .rightRamp, .library, .lagoon, .sigil]
    static let candlePoints = 10_000                // × cycle
    static let summoningPoints = 100_000            // × cycle
    // The Awakening: four tentacles × two hits (Cthulhu himself, the ramp or the orbit), then three eye hits.
    static let tentacleCount = 4
    static let tentacleHits = 1                     // M7 v5 (simulator): was 2
    static let eyeHitsNeeded = 3
    static let tentacleHitPoints = 5_000            // × cycle; a cut adds tentacleCutPoints
    static let tentacleCutPoints = 25_000
    static let eyePoints = 250_000
    static let banishPoints = 1_000_000

    private(set) var phase: Phase = .research
    private(set) var clues = 0
    private(set) var tomesDone = 0                  // = ritual pages read
    private(set) var cycle = 1                      // banishing Cthulhu (round 4) doubles everything
    private(set) var pagesTurned = 0
    private(set) var timeLeft: TimeInterval = 0
    private(set) var litShots: [CthShot] = []
    private(set) var sealsBroken = false
    /// Candles lit in the Ritual; kept if the multiball ends early.
    private(set) var candles: Set<CthShot> = []
    /// Hits left on each tentacle in the Awakening, and eye hits (kept if he escapes, like GI's core hits).
    private(set) var tentacles: [Int] = Array(repeating: CthCampaign.tentacleHits, count: CthCampaign.tentacleCount)
    private(set) var eyeHits = 0
    /// M7 v5: a tome that ran out of time keeps its progress (pages, deciphered glyphs) for the retry.
    private var failedTome: Int?
    var tentaclesLeft: Int { tentacles.filter { $0 > 0 }.count }

    var runningTome: Int? {
        if case .tome(let i) = phase { return i }
        return nil
    }

    /// Points per spinner spin: 500 while the Necronomicon is open, else 100.
    var spinnerPoints: Int { runningTome == 0 ? 500 : 100 }

    func reset() {
        phase = .research
        clues = 0
        tomesDone = 0
        cycle = 1
        pagesTurned = 0
        timeLeft = 0
        litShots = []
        sealsBroken = false
        candles = []
        tentacles = Array(repeating: Self.tentacleHits, count: Self.tentacleCount)
        eyeHits = 0
        failedTome = nil
    }

    // MARK: Reports from the scene

    /// A shot was made (not the Library: that's libraryCaught). `.sigil` = one Sigil target.
    func shotMade(_ shot: CthShot) -> [Event] {
        switch phase {
        case .research:
            return shot == .sigil ? [] : earnClue()          // a single Sigil target isn't a clue; the bank is
        case .tome(let i):
            return tomeShot(i, shot)
        case .ritual:
            return ritualShot(shot)
        case .awakening:
            return shot == .rightRamp || shot == .orbit ? hitTentacle() : []
        case .libraryLit, .ritualLit:
            return []
        }
    }

    /// A ball hit Cthulhu himself: a tentacle while any are left, then the eye.
    func cthulhuHit() -> [Event] {
        guard phase == .awakening else { return [] }
        if tentaclesLeft > 0 { return hitTentacle() }
        eyeHits += 1
        guard eyeHits >= Self.eyeHitsNeeded else {
            return [.eyeStruck(eyeHits, points: Self.eyePoints * cycle)]
        }
        let events: [Event] = [.eyeStruck(eyeHits, points: Self.eyePoints * cycle),
                               .banished(points: Self.banishPoints * cycle)]
        startNextCycle()
        return events
    }

    func lanesCompleted() -> [Event] {
        phase == .research ? earnClue() : []
    }

    func sigilBankCompleted() -> [Event] {
        switch phase {
        case .research:
            return earnClue()
        case .tome(2) where !sealsBroken:
            sealsBroken = true
            return [.progress(points: Self.glyphPoints * cycle, banner: "SEALS BROKEN · SHOOT THE RAMP")]
        default:
            return []
        }
    }

    func spins(_ n: Int) -> [Event] {
        guard runningTome == 0, n > 0 else { return [] }
        pagesTurned += n
        return pagesTurned >= Self.pagesNeeded ? finishTome(0) : []
    }

    /// The Library caught a ball: opens the next tome when lit, counts as a shot during a tome.
    func libraryCaught() -> [Event] {
        switch phase {
        case .research:
            return []
        case .libraryLit:
            return startTome(tomesDone)
        case .tome(let i):
            return tomeShot(i, .library)
        case .ritualLit:
            if candles.count == Self.ritualShots.count { return startAwakening() }   // he escaped: re-summon him
            phase = .ritual
            return [.ritualStarted]
        case .ritual:
            return ritualShot(.library)
        case .awakening:
            return []
        }
    }

    /// The multiball ended (one ball left). In the Ritual the lit candles stay lit and the Library relights the
    /// Ritual. In the Awakening he sinks and the tentacles grow back, but (M7 v5) the five candles stay lit, so
    /// the next Library shot re-summons him straight away; eye hits are kept.
    func multiballEnded() -> [Event] {
        switch phase {
        case .ritual:
            phase = .ritualLit
            return [.ritualFaltered]
        case .awakening:
            phase = .ritualLit
            tentacles = Array(repeating: Self.tentacleHits, count: Self.tentacleCount)
            return [.cthulhuEscaped]
        default:
            return []
        }
    }

    /// Runs the tome clocks; `active` = a launched ball is in play (clocks stop between balls).
    func tick(_ dt: TimeInterval, active: Bool) -> [Event] {
        guard active, let i = runningTome, i < 2 else { return [] }
        timeLeft -= dt
        guard timeLeft <= 0 else { return [] }
        phase = .libraryLit                                     // retry the same tome, progress kept
        failedTome = i
        return [.tomeFailed(i)]
    }

    // MARK: Status line (LED strip, bottom row)

    var statusText: String? {
        switch phase {
        case .research:
            return "RESEARCH · CLUE \(clues) OF \(Self.cluesNeeded)"
        case .libraryLit:
            return "SHOOT THE LIBRARY · TOME \(Self.roman[min(tomesDone, 2)])"
        case .tome(0):
            return "NECRONOMICON · \(max(0, Self.pagesNeeded - pagesTurned)) PAGES · \(seconds)s"
        case .tome(1):
            return "PNAKOTIC · HIT " + litShots.map { $0.label }.joined(separator: " · ") + " · \(seconds)s"
        case .tome:
            return sealsBroken ? "CAPTAIN'S LOG · SHOOT THE RAMP" : "CAPTAIN'S LOG · BREAK THE 4 SEALS"
        case .ritualLit:
            if candles.count == Self.ritualShots.count { return "HE STIRS · SHOOT THE LIBRARY TO SUMMON HIM" }
            let lit = candles.isEmpty ? "" : " · \(candles.count)/5 CANDLES"
            return "RITUAL LIT · SHOOT THE LIBRARY" + lit
        case .ritual:
            let left = Self.ritualShots.filter { !candles.contains($0) }.map { $0.label }
            return "RITUAL · \(candles.count)/5 · " + left.joined(separator: " · ")
        case .awakening:
            if tentaclesLeft > 0 {
                return "AWAKENING · CUT TENTACLES · \(Self.tentacleCount - tentaclesLeft)/\(Self.tentacleCount)"
            }
            return "AWAKENING · STRIKE THE EYE · \(eyeHits)/\(Self.eyeHitsNeeded)"
        }
    }

    private var seconds: Int { max(0, Int(timeLeft.rounded(.up))) }

    // MARK: Debug shortcuts (pause card, debug builds)

    #if DEBUG
    /// Research → Library lit; Library lit → the next tome read; a running tome → read.
    func debugSkip() -> [Event] {
        switch phase {
        case .research:
            clues = Self.cluesNeeded
            phase = .libraryLit
            return [.libraryLit]
        case .libraryLit:
            _ = startTome(tomesDone)
            return finishTome(tomesDone)
        case .tome(let i):
            return finishTome(i)
        case .ritualLit:
            if candles.count == Self.ritualShots.count { return startAwakening() }
            phase = .ritual
            return [.ritualStarted]
        case .ritual:
            var events: [Event] = []
            for shot in Self.ritualShots where phase == .ritual && !candles.contains(shot) { events += ritualShot(shot) }
            return events
        case .awakening:
            if tentaclesLeft > 0 {                              // cut every tentacle
                var events: [Event] = []
                while tentaclesLeft > 0 { events += hitTentacle() }
                return events
            }
            return cthulhuHit()                                 // one eye hit
        }
    }

    /// Straight to the Awakening (Cthulhu rises, three-ball multiball).
    func debugAwaken() -> [Event] {
        guard phase != .awakening else { return [] }
        return startAwakening()
    }

    /// All three tomes read: the Ritual is lit.
    func debugLightRitual() -> [Event] {
        tomesDone = 3
        litShots = []
        phase = .ritualLit
        return [.ritualLit]
    }
    #endif

    // MARK: Private

    private func earnClue() -> [Event] {
        clues += 1
        guard clues >= Self.cluesNeeded else { return [.clue(clues)] }
        phase = .libraryLit
        return [.libraryLit]
    }

    private func startTome(_ i: Int) -> [Event] {
        let resume = failedTome == i                            // a retry carries on where the clock ran out
        failedTome = nil
        phase = .tome(i)
        if !resume {
            pagesTurned = 0
            sealsBroken = false
            litShots = []
        }
        switch i {
        case 0:
            timeLeft = Self.necronomiconTime
        case 1:
            timeLeft = Self.glyphTime
            if !resume || litShots.isEmpty { litShots = Array(Self.glyphPool.shuffled().prefix(Self.glyphCount)) }
        default:
            timeLeft = 0                                        // untimed
        }
        return [.tomeStarted(i)]
    }

    private func tomeShot(_ i: Int, _ shot: CthShot) -> [Event] {
        switch i {
        case 0:
            guard shot == .rightRamp else { return [] }
            pagesTurned += Self.pagesPerRamp
            if pagesTurned >= Self.pagesNeeded { return finishTome(0) }
            return [.progress(points: 0, banner: "+\(Self.pagesPerRamp) PAGES")]
        case 1:
            guard let k = litShots.firstIndex(of: shot) else { return [] }
            litShots.remove(at: k)
            if litShots.isEmpty { return finishTome(1) }
            return [.progress(points: Self.glyphPoints * cycle, banner: "GLYPH DECIPHERED")]
        default:
            guard shot == .rightRamp, sealsBroken else { return [] }
            return finishTome(2)
        }
    }

    private func ritualShot(_ shot: CthShot) -> [Event] {
        guard phase == .ritual, let i = Self.ritualShots.firstIndex(of: shot), !candles.contains(shot) else { return [] }
        candles.insert(shot)
        var events: [Event] = [.candleLit(i, points: Self.candlePoints * cycle)]
        if candles.count == Self.ritualShots.count {
            events.append(.summoning(points: Self.summoningPoints * cycle))
            events += startAwakening()
        }
        return events
    }

    private func startAwakening() -> [Event] {
        phase = .awakening
        tentacles = Array(repeating: Self.tentacleHits, count: Self.tentacleCount)
        return [.awakeningStarted]
    }

    /// One hit on the tentacle with the most hits left.
    private func hitTentacle() -> [Event] {
        guard let i = tentacles.indices.max(by: { tentacles[$0] < tentacles[$1] }), tentacles[i] > 0 else { return [] }
        tentacles[i] -= 1
        let cut = tentacles[i] == 0
        let points = (Self.tentacleHitPoints + (cut ? Self.tentacleCutPoints : 0)) * cycle
        var events: [Event] = [.tentacleHit(i, cut: cut, points: points)]
        if tentaclesLeft == 0 { events.append(.eyeOpen) }
        return events
    }

    /// Banished: the story starts again from Research with every award × the new cycle.
    private func startNextCycle() {
        cycle += 1
        phase = .research
        clues = 0
        tomesDone = 0
        candles = []
        tentacles = Array(repeating: Self.tentacleHits, count: Self.tentacleCount)
        eyeHits = 0
    }

    private func finishTome(_ i: Int) -> [Event] {
        let points = Self.tomePoints * (i + 1) * cycle
        failedTome = nil
        tomesDone = min(tomesDone + 1, 3)
        litShots = []
        timeLeft = 0
        clues = 0
        if tomesDone >= 3 {
            phase = .ritualLit
            return [.tomeFinished(i, points: points), .ritualLit]
        }
        phase = .research
        return [.tomeFinished(i, points: points)]
    }
}
