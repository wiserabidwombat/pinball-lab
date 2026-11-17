// Pinball Lab Table 06 (Orbit: Grand Tour), M8: the tour loop and its mode framework.
// Mission Control (open once the countdown is done) starts the next stop on the tour. Each stop is a timed mode with
// a goal; finish it in time and the planet is visited, run out of time (or drain) and it waits for the next Mission
// Control. The stops go round the ring in order: Mercury out to Neptune, then the Sun; after the Sun the tour starts
// again (tour 2, 3 …) with everything worth more.
// v1: every stop had a stand-in goal ("make N of the lit shots"). v2: the inner leg's own rules —
//   Mercury Dash: one shot lit on each side, make both;
//   Venus Veil: three of the five shots hidden; each R-O-C-K-E-T hit reveals one; make the revealed ones;
//   Mars Recon: drop all three sample targets, then shoot the rover.
// v4: Moonshot: two Moon ramps lock (a virtual lock: the ball sinks into lunar orbit, a new one is served); the second
//   starts a 2-ball multiball (the locked ball comes back out of Mission Control); the first jackpot (Moon or Saturn)
//   visits the Moon. The clock runs only for the locks.
// v5: the outer leg — Jupiter Storm (40 spins, then a ramp), Ring Runner (3 Saturns, each within 8 s of the last),
//   Uranus Roll (5 lit shots, sides alternating), Neptune Deep (60 spins, then 10 bumpers).
// v6: Sun Slingshot — a 3-ball multiball; the four floor shots are jackpots; all four drop the blast door and light the
//   super jackpot at Mission Control, which finishes the tour (tour 2 starts; everything × the tour number).
import Foundation

/// One stop on the tour: its planet, its kind of goal and a timer.
struct TourStop {
    enum Kind {
        case shots(Set<String>)     // stand-in: make `need` of these (they stay lit)
        case mercury                // one lit shot per side; each goes dark when made
        case venus                  // hidden shots, revealed by R-O-C-K-E-T hits
        case mars                   // samples, then the rover
        case moonshot               // v4: two Moon locks start a 2-ball multiball; the first jackpot finishes it
        case jupiter                // v5: 40 spinner spins build the storm, then either ramp
        case ringRunner             // v5: 3 Saturn ramps, each within 8 s of the last
        case uranus                 // v5: 5 lit shots, the lit side alternating after each
        case neptune                // v5: 60 spins dive deep, then 10 pop-bumper hits
        case sun                    // v6: 3-ball multiball; 4 jackpots light the super jackpot at Mission Control
    }
    let planet: String          // the ring's insert name and the window's picture (tour_window_<planet>)
    let title: String           // the mode's name on the banner
    let kind: Kind
    let need: Int               // steps to finish
    let seconds: TimeInterval
}

@MainActor
final class TourModes {
    /// The arrows' shots. "rocket" during a stop is a blast-door hit (Mission Control is shut while a stop runs).
    static let arrowShots = ["leftOrbit", "moon", "rocket", "saturn", "rightOrbit"]
    static let floorShots: Set<String> = ["leftOrbit", "moon", "saturn", "rightOrbit"]
    /// The ring's order (left to right on the arc).
    static let tour: [TourStop] = [
        TourStop(planet: "mercury", title: "MERCURY DASH", kind: .mercury, need: 2, seconds: 30),   // v3: 20 → 30
        TourStop(planet: "venus", title: "VENUS VEIL", kind: .venus, need: 3, seconds: 40),
        TourStop(planet: "mars", title: "MARS RECON", kind: .mars, need: 2, seconds: 45),
        TourStop(planet: "moon", title: "MOONSHOT", kind: .moonshot, need: 3, seconds: 45),
        TourStop(planet: "jupiter", title: "JUPITER STORM", kind: .jupiter, need: 2, seconds: 40),
        TourStop(planet: "saturn", title: "RING RUNNER", kind: .ringRunner, need: 3, seconds: 45),
        TourStop(planet: "uranus", title: "URANUS ROLL", kind: .uranus, need: 5, seconds: 40),
        TourStop(planet: "neptune", title: "NEPTUNE DEEP", kind: .neptune, need: 2, seconds: 50),
        TourStop(planet: "sun", title: "SUN SLINGSHOT", kind: .sun, need: 5, seconds: 60),
    ]

    /// Which tour this is (1, then 2 after the Sun …) and the stops done on it.
    private(set) var tourNumber = 1
    private(set) var visited: Set<String> = []
    /// The running stop, if any, and its progress.
    private(set) var active: TourStop?
    private(set) var made = 0
    /// v3: the clock counts only while the scene says it runs (not while a ball sits in Mission Control, a crater or
    /// on the plunger), so a stop's time starts when its ball is kicked out.
    private(set) var timeLeft: TimeInterval = 0
    /// The shots that count right now (their arrows blink).
    private(set) var lit: Set<String> = []
    /// Venus: the chosen shots still under the clouds.
    private var hidden: [String] = []
    /// v5: Jupiter / Neptune — spins or bumper hits counted toward the current step; Ring Runner — time left to chain.
    private(set) var count = 0
    private(set) var chainLeft: TimeInterval = 0
    static let jupiterSpins = 40, neptuneSpins = 60, neptuneBumpers = 10
    static let ringChain: TimeInterval = 8
    static let leftShots: Set<String> = ["leftOrbit", "moon"], rightShots: Set<String> = ["saturn", "rightOrbit"]

    /// The next stop Mission Control will start (the first on the ring not yet visited this tour).
    var nextStop: TourStop { Self.tour.first { !visited.contains($0.planet) } ?? Self.tour[0] }

    func reset() {
        tourNumber = 1
        visited.removeAll()
        active = nil
        made = 0
        lit = []
        hidden = []
    }

    /// Starts the next stop. Returns it (nil if one is already running).
    func start(now: TimeInterval) -> TourStop? {
        guard active == nil else { return nil }
        let s = nextStop
        active = s
        made = 0
        timeLeft = s.seconds
        hidden = []
        count = 0
        chainLeft = 0
        switch s.kind {
        case .shots(let pool):
            lit = pool
        case .mercury:
            lit = [["leftOrbit", "moon"].randomElement()!, ["saturn", "rightOrbit"].randomElement()!]
        case .venus:
            hidden = Array(Self.arrowShots.shuffled().prefix(s.need))
            lit = []
        case .mars:
            lit = []
        case .moonshot:
            lit = ["moon"]
        case .jupiter, .neptune:
            lit = []
        case .ringRunner:
            lit = ["saturn"]
        case .uranus:
            lit = Bool.random() ? Self.leftShots : Self.rightShots
        case .sun:
            lit = Self.floorShots
        }
        return s
    }

    /// Whether `shot` counts toward the running goal.
    func isLit(_ shot: String) -> Bool { lit.contains(shot) }

    /// v5: `counting` = a spin / bumper counted toward a step (the HUD changes; no step yet).
    enum Result { case none, counting, progress, complete(TourStop) }

    /// A shot was made (an arrow's shot; "rocket" = the blast door during a stop).
    func shot(_ name: String) -> Result {
        guard let s = active, lit.contains(name) else { return .none }
        switch s.kind {
        case .shots: break                       // stays lit
        case .mercury, .venus: lit.remove(name)  // each lit shot counts once
        case .mars: return .none
        case .moonshot:                          // lock, lock, then a jackpot on either ramp
            if made + 1 == 2 { lit = ["moon", "saturn"] }
        case .jupiter, .neptune: break           // jupiter: the ramp after the storm
        case .ringRunner:                        // a Saturn after the chain ran out starts again at 1
            if made > 0, chainLeft <= 0 { made = 0 }
            chainLeft = Self.ringChain
        case .sun:                               // each floor jackpot once, then the super at Mission Control
            lit.remove(name)
            if made + 1 == 4 { lit = ["rocket"] }
        case .uranus:                            // the lit side swaps after every make
            let r = step()
            if case .progress = r { lit = Self.leftShots.contains(name) ? Self.rightShots : Self.leftShots }
            return r
        }
        return step()
    }

    /// Venus: an R-O-C-K-E-T hit reveals the next hidden shot. Returns it (nil if none is left to reveal).
    func reveal() -> String? {
        guard case .venus? = active?.kind, !hidden.isEmpty else { return nil }
        let name = hidden.removeFirst()
        lit.insert(name)
        return name
    }

    /// Mars: "samples" (the bank is down) then "rover" (the rover hole while it's lit).
    func event(_ name: String, amount: Int = 1) -> Result {
        switch active?.kind {
        case .mars?:
            if name == "samples", made == 0 { return step() }
            if name == "rover", made == 1 { return step() }
        case .jupiter?:                          // v5: spins build the storm, then the ramps light
            guard name == "spin", made == 0 else { return .none }
            count += amount
            guard count >= Self.jupiterSpins else { return .counting }
            count = 0
            lit = ["moon", "saturn"]
            return step()
        case .neptune?:                          // v5: spins, then bumpers
            if name == "spin", made == 0 {
                count += amount
                guard count >= Self.neptuneSpins else { return .counting }
                count = 0
                return step()
            }
            if name == "bumper", made == 1 {
                count += amount
                guard count >= Self.neptuneBumpers else { return .counting }
                return step()
            }
        default: break
        }
        return .none
    }

    private func step() -> Result {
        guard let s = active else { return .none }
        made += 1
        guard made >= s.need else { return .progress }
        visited.insert(s.planet)
        active = nil
        lit = []
        hidden = []
        count = 0
        return .complete(s)
    }

    /// What the running stop wants next, for the HUD ("1/2", "DROP SAMPLES", "HIT R-O-C-K-E-T" …).
    var stepText: String {
        guard let s = active else { return "" }
        switch s.kind {
        case .mars: return made == 0 ? "DROP SAMPLES" : "ROVER"
        case .moonshot: return made < 2 ? "LOCK \(made + 1)" : "JACKPOT"
        case .jupiter: return made == 0 ? "SPINS \(count)/\(Self.jupiterSpins)" : "SHOOT A RAMP"
        case .neptune: return made == 0 ? "SPINS \(count)/\(Self.neptuneSpins)" : "BUMPERS \(count)/\(Self.neptuneBumpers)"
        case .ringRunner:
            return made == 0 ? "SATURN 0/\(s.need)" : "SATURN \(made)/\(s.need) · \(Int(chainLeft.rounded(.up)))s"
        case .uranus: return "\(made)/\(s.need) · \(lit.isSubset(of: Self.leftShots) ? "LEFT" : "RIGHT")"
        case .sun: return made < 4 ? "JACKPOTS \(made)/4" : "SUPER · MISSION CONTROL"
        case .venus where lit.isEmpty && !hidden.isEmpty: return "\(made)/\(s.need) · HIT R-O-C-K-E-T"
        default: return "\(made)/\(s.need)"
        }
    }

    /// The running stop's time is up (or its ball drained): it ends unvisited, to be restarted.
    func fail() -> TourStop? {
        let s = active
        active = nil
        lit = []
        hidden = []
        return s
    }

    /// True once every stop is visited: the next tour begins (the caller shows it).
    func finishTourIfDone() -> Bool {
        guard visited.count == Self.tour.count else { return false }
        visited.removeAll()
        tourNumber += 1
        return true
    }

    /// v5: the robot's hint — the orbits feed the spinners (and loop into the pops).
    var wantsOrbits: Bool {
        switch active?.kind {
        case .jupiter?: return made == 0
        case .neptune?: return true
        default: return false
        }
    }

    func tick(_ dt: TimeInterval) {
        let d = max(0, min(dt, 0.25))
        timeLeft -= d
        if case .ringRunner? = active?.kind, made > 0 {   // v5: the chain runs with the stop clock
            chainLeft -= d
            if chainLeft <= 0 { made = 0 }
        }
    }
    var timeUp: Bool { active != nil && timeLeft <= 0 }
    var secondsLeft: Int { max(0, Int(timeLeft.rounded(.up))) }

    #if DEBUG
    /// `-tourStartAt <planet>`: every stop before it counts as visited, so Mission Control starts it.
    func debugSkip(to planet: String) {
        for st in Self.tour { if st.planet == planet { break }; visited.insert(st.planet) }
    }

    /// `-tourModes`: one step of the running stop, as if the player made it.
    func debugStepName() -> (kind: String, name: String)? {
        guard let s = active else { return nil }
        switch s.kind {
        case .mars: return ("event", made == 0 ? "samples" : "rover")
        case .jupiter where made == 0: return ("spin", "")
        case .neptune: return made == 0 ? ("spin", "") : ("bumper", "")
        case .venus where lit.isEmpty: return ("reveal", "")
        default: return lit.sorted().first.map { ("shot", $0) }
        }
    }
    #endif
}
