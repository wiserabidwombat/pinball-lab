import Foundation

/// The shots a wave can light. Raw values match the shot-arrow lamp names ("arrow.<name>").
enum Shot: String, CaseIterable {
    case leftRamp, rightRamp, orbit, hangar, abduction

    /// Name for the HUD status line (M7 v10: name the shots still to hit).
    var label: String {
        switch self {
        case .leftRamp: return "LEFT RAMP"
        case .rightRamp: return "RIGHT RAMP"
        case .orbit: return "ORBIT"
        case .hangar: return "HANGAR"
        case .abduction: return "ABDUCTION"
        }
    }
}

/// The invasion campaign (milestone 7): light the Hangar, shoot it to start the next wave,
/// clear the wave's goal. Progress carries across balls and resets each game.
/// The scene reports shots, the fighter bank and time; this class keeps score of the campaign
/// and returns what happened, so the scene can award points, show banners and run lamp shows.
///
/// Round 2 built Wave 1 (Scout Saucers); round 3 added Wave 2 (Fighter Squadron), Wave 3
/// (Abductors) and the Extra Ball; round 4 adds the Mothership (wave 4, a 2-ball multiball run
/// by the scene) and Invasion 2+: after the Mothership the campaign restarts at Wave 1 and every
/// campaign award is multiplied by the invasion number.
final class Campaign {
    enum Phase {
        case building      // collecting toward lighting the Hangar
        case ready         // Hangar lit: shoot it to start the wave
        case running       // a wave is on
    }

    enum Event {
        case none
        case waveLit
        case waveStarted(wave: Int)
        /// A step inside a wave: points, a HUD banner, and whether it counts as a ship down.
        case progress(points: Int, banner: String, shipDown: Bool)
        /// Points include the wave-clear bonus (and, for the Mothership, the destroy bonus).
        case waveCleared(wave: Int, points: Int)
        case waveFailed(wave: Int)
        case cowAbducted
        case extraBall
        case coreHit(points: Int, hitsLeft: Int)   // Mothership jackpot; the shields come back up
    }

    /// Waves that exist so far (raised when the Mothership is built).
    static let builtWaves = 4                  // 4 = the Mothership
    static let rampsToLight = 3
    static let waveClearPoints = 25_000        // × wave number

    // Wave 1: Scout Saucers
    /// M10 v17 (Shot Lab game simulation): 3 → 2. With three, only ~1 in 6 beginners cleared Wave 1
    /// before draining; with two, ~1 in 3 (average players 84% → 92%).
    static let scoutCount = 2
    static let scoutSeconds: TimeInterval = 30
    static let scoutBasePoints = 5_000
    static let scoutPointsPerSecond = 250      // a faster scout is worth more: + 250 per second left

    // Wave 2: Fighter Squadron (untimed): the whole fighter bank, then the Defense Cannon ramp
    static let cannonPoints = 10_000

    // Wave 3: Abductors, one at a time; the Abduction scoop or the Tractor Beam (right ramp) saves the cow.
    // M11 (Play Lab sweep 2026-10-22): the scoop alone was too precise for a timed goal. At 120 Hz the left
    // flipper's line sweeps across it fast (a 17 ms window, ~25% for an average player, ~13% from the right),
    // so the robots saved 5 cows and lost 15. The right ramp (~42% at 120 Hz, ~50% at 60 Hz) now saves a cow too; the scoop stays
    // the hard lock shot.
    static let cowsToSave = 3
    static let beamSeconds: TimeInterval = 20
    static let cowSavedPoints = 7_500

    // Wave 4: the Mothership. Its shield generators are the three saucer bumpers.
    static let shieldHitsPerGenerator = 3
    /// M10 v17: aimed shots that also knock out a generator hit while the shields are up (the bumpers can't be
    /// aimed at — the Shot Lab found ~0.1 bumper hits per aimed flip — so without these the kill was luck).
    static let shieldShots: Set<Shot> = [.orbit, .hangar, .abduction]
    static let shieldHitPoints = 1_000
    static let coreOpenPoints = 25_000
    static let coreHitPoints = 250_000
    static let coreHitsToDestroy = 3
    static let destroyPoints = 1_000_000

    private(set) var wave = 1                  // the next or current wave
    private(set) var phase: Phase = .building
    private(set) var wavesCleared = 0
    private(set) var litShots: Set<Shot> = []
    private(set) var timeLeft: TimeInterval = 0
    private(set) var fightersDown = false      // Wave 2: the bank is done, the cannon is lit
    private(set) var cowsSaved = 0             // Wave 3
    private(set) var extraBallLit = false
    private(set) var invasion = 1              // Invasion 2, 3…: every campaign award × this
    private(set) var shieldHits: [Int] = []    // Mothership: hits left per bumper (empty = no shields)
    private(set) var coreOpen = false
    private(set) var coreHits = 0              // kept if the Mothership escapes
    private var extraBallGiven = false         // one per game
    private var rampsTowardWave = 0

    func reset() {
        wave = 1
        phase = .building
        wavesCleared = 0
        litShots = []
        timeLeft = 0
        fightersDown = false
        cowsSaved = 0
        extraBallLit = false
        extraBallGiven = false
        rampsTowardWave = 0
        invasion = 1
        shieldHits = []
        coreOpen = false
        coreHits = 0
    }

    static func name(of wave: Int) -> String {
        switch wave {
        case 1: return "SCOUT SAUCERS"
        case 2: return "FIGHTER SQUADRON"
        case 3: return "ABDUCTORS"
        default: return "MOTHERSHIP"
        }
    }

    /// Wave 2 running and the bank still to finish: the bank arrow blinks.
    var wantsFighterBank: Bool { phase == .running && wave == 2 && !fightersDown }

    /// Wave 3 running: the Abduction scoop (or the Tractor Beam ramp) saves cows; the scoop doesn't lock balls.
    var abductorsActive: Bool { phase == .running && wave == 3 }

    /// The Mothership finale is on.
    var mothershipActive: Bool { phase == .running && wave == 4 }

    /// A saucer bumper (index 0–2) was hit: during the Mothership it knocks down that shield.
    func bumperHit(_ index: Int) -> Event {
        guard mothershipActive, !coreOpen, shieldHits.indices.contains(index), shieldHits[index] > 0 else {
            return .none
        }
        return shieldHit(index)
    }

    /// One hit on generator `index` (a bumper hit, or an aimed shield shot on the strongest generator).
    private func shieldHit(_ index: Int) -> Event {
        shieldHits[index] -= 1
        guard shieldHits.allSatisfy({ $0 == 0 }) else {
            let banner = shieldHits[index] == 0 ? "SHIELD DOWN" : ""
            return .progress(points: Self.shieldHitPoints * invasion, banner: banner, shipDown: false)
        }
        coreOpen = true
        litShots = [.leftRamp, .rightRamp]
        return .progress(points: Self.coreOpenPoints * invasion, banner: "CORE OPEN! SHOOT A RAMP", shipDown: false)
    }

    /// The scene's Mothership multiball ended without destroying it: it escapes, the Hangar
    /// relights to try again, and the core hits made so far are kept.
    func mothershipEscaped() -> Event {
        guard mothershipActive else { return .none }
        phase = .ready
        shieldHits = []
        coreOpen = false
        litShots = []
        return .waveFailed(wave: 4)
    }

    /// All three U-F-O lanes were completed.
    func lanesCompleted() -> Event {
        lightIfBuilding()
    }

    /// All four fighters are down (the scene still awards the bank and lights the kickback).
    func fighterBankCompleted() -> Event {
        guard wantsFighterBank else { return .none }
        fightersDown = true
        litShots = [.leftRamp]
        return .progress(points: 0, banner: "SHOOT THE DEFENSE CANNON", shipDown: false)
    }

    /// A ramp, the orbit or a scoop was made. `canStart`: whether a lit Hangar may start a wave
    /// now (not during Abduction multiball).
    func shotMade(_ shot: Shot, canStart: Bool) -> Event {
        // A lit Extra Ball is collected first; the next Hangar shot can start a wave.
        if shot == .hangar, extraBallLit {
            extraBallLit = false
            return .extraBall
        }
        switch phase {
        case .building:
            if shot == .leftRamp || shot == .rightRamp {
                rampsTowardWave += 1
                if rampsTowardWave >= Self.rampsToLight { return lightIfBuilding() }
            }
            return .none

        case .ready:
            guard shot == .hangar, canStart else { return .none }
            startWave()
            return .waveStarted(wave: wave)

        case .running:
            guard litShots.contains(shot) else { return .none }
            switch wave {
            case 1:
                litShots.remove(shot)
                let points = Self.scoutBasePoints + Int(timeLeft.rounded(.down)) * Self.scoutPointsPerSecond
                if litShots.isEmpty { return clearWave(points: points) }
                return .progress(points: points * invasion, banner: "SCOUT DOWN", shipDown: true)
            case 2:
                return clearWave(points: Self.cannonPoints)      // the cannon finishes the squadron
            case 3:
                cowsSaved += 1
                if cowsSaved >= Self.cowsToSave { return clearWave(points: Self.cowSavedPoints) }
                timeLeft = Self.beamSeconds                        // the next abductor arrives
                return .progress(points: Self.cowSavedPoints * invasion, banner: "COW SAVED", shipDown: true)
            default:
                // M10 v17: while the shields are up, the orbit, Hangar and Abduction also hit a generator
                // (the one with the most hits left).
                if !coreOpen, Self.shieldShots.contains(shot),
                   let strongest = shieldHits.indices.max(by: { shieldHits[$0] < shieldHits[$1] }),
                   shieldHits[strongest] > 0 {
                    return shieldHit(strongest)
                }
                // Mothership: a ramp while the core is open is a core hit.
                guard coreOpen, shot == .leftRamp || shot == .rightRamp else { return .none }
                coreHits += 1
                let points = Self.coreHitPoints * invasion
                if coreHits >= Self.coreHitsToDestroy { return destroyMothership(corePoints: points) }
                coreOpen = false
                litShots = Self.shieldShots
                shieldHits = Array(repeating: Self.shieldHitsPerGenerator, count: 3)   // shields back up
                return .coreHit(points: points, hitsLeft: Self.coreHitsToDestroy - coreHits)
            }
        }
    }

    /// Runs the wave clocks. `active` is false while no launched ball is in play (between balls,
    /// waiting on the plunger), so the time isn't lost to a drain.
    func tick(_ dt: TimeInterval, active: Bool) -> Event {
        guard phase == .running, active, wave == 1 || wave == 3 else { return .none }   // 2 and 4 are untimed
        timeLeft -= dt
        guard timeLeft <= 0 else { return .none }
        if wave == 3 {
            timeLeft = Self.beamSeconds          // that cow is gone; the next abductor arrives
            return .cowAbducted
        }
        // Wave 1 time's up: the scouts get away. The Hangar stays lit, so the player can retry.
        litShots = []
        timeLeft = 0
        phase = .ready
        return .waveFailed(wave: wave)
    }

    /// One line for the HUD while it matters, nil otherwise.
    var statusText: String? {
        switch phase {
        case .building:
            return extraBallLit ? "EXTRA BALL LIT · SHOOT THE HANGAR" : nil
        case .ready:
            if wave == 4 { return "SHOOT THE HANGAR · MOTHERSHIP" }
            return "SHOOT THE HANGAR · WAVE \(wave)"
        case .running:
            let seconds = Int(timeLeft.rounded(.up))
            switch wave {
            case 1:
                let targets = Shot.allCases.filter { litShots.contains($0) }.map { $0.label }.joined(separator: " · ")
                return "WAVE 1 · HIT \(targets) · \(seconds)s"
            case 2: return fightersDown ? "WAVE 2 · SHOOT THE DEFENSE CANNON" : "WAVE 2 · KNOCK DOWN THE FIGHTERS"
            case 3: return "WAVE 3 · ABDUCTION OR RIGHT RAMP · SAVED \(cowsSaved)/\(Self.cowsToSave) · \(seconds)s"
            default:
                let core = "CORE HITS \(coreHits)/\(Self.coreHitsToDestroy)"
                if coreOpen { return "MOTHERSHIP · CORE OPEN · SHOOT A RAMP · \(core)" }
                let shields = shieldHits.map { String($0) }.joined(separator: "·")
                return "MOTHERSHIP · SHIELDS \(shields) · \(core)"
            }
        }
    }

    #if DEBUG
    /// Debug shortcuts (pause menu, debug builds only).
    /// Skip Wave: end any wave in progress (not the Mothership) and light the Hangar for the next one.
    func debugSkipWave() {
        guard !mothershipActive else { return }
        if phase == .running { wavesCleared = min(wave, 3); wave = min(wave + 1, 4) }
        litShots = []
        timeLeft = 0
        fightersDown = false
        phase = .ready
    }

    /// Mothership: light the Hangar for the finale straight away.
    func debugLightMothership() {
        guard !mothershipActive else { return }
        wave = 4
        wavesCleared = 3
        litShots = []
        timeLeft = 0
        phase = .ready
    }
    #endif

    private func startWave() {
        phase = .running
        switch wave {
        case 1:
            timeLeft = Self.scoutSeconds
            litShots = Set(Shot.allCases.shuffled().prefix(Self.scoutCount))
        case 2:
            timeLeft = 0
            fightersDown = false
            litShots = []                        // the bank arrow blinks instead (wantsFighterBank)
        case 3:
            timeLeft = Self.beamSeconds
            cowsSaved = 0
            litShots = [.abduction, .rightRamp]  // M11: the Tractor Beam saves cows too
        default:
            timeLeft = 0
            coreOpen = false
            litShots = Self.shieldShots          // M10 v17: their arrows blink while the shields are up
            shieldHits = Array(repeating: Self.shieldHitsPerGenerator, count: 3)
        }
    }

    /// Third core hit: the Mothership is destroyed, and the next invasion starts at Wave 1.
    private func destroyMothership(corePoints: Int) -> Event {
        let points = corePoints + Self.destroyPoints * invasion
        invasion += 1
        wave = 1
        wavesCleared = 0
        phase = .building
        rampsTowardWave = 0
        litShots = []
        shieldHits = []
        coreOpen = false
        coreHits = 0
        cowsSaved = 0
        fightersDown = false
        return .waveCleared(wave: 4, points: points)
    }

    private func clearWave(points: Int) -> Event {
        let cleared = wave
        let total = (points + Self.waveClearPoints * cleared) * invasion
        wavesCleared += 1
        wave += 1
        phase = .building
        rampsTowardWave = 0
        timeLeft = 0
        litShots = []
        fightersDown = false
        if cleared == 2, !extraBallGiven {       // Extra Ball: lit at the Hangar after Wave 2, once a game
            extraBallGiven = true
            extraBallLit = true
        }
        return .waveCleared(wave: cleared, points: total)
    }

    private func lightIfBuilding() -> Event {
        guard phase == .building, wave <= Self.builtWaves else { return .none }
        phase = .ready
        return .waveLit
    }
}
