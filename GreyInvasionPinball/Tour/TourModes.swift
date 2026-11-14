// Pinball Lab Table 06 (Orbit: Grand Tour), M8 v1: the tour loop and its mode framework.
// Mission Control (open once the countdown is done) starts the next stop on the tour. Each stop is a timed mode with
// a goal (a number of lit shots to make); finish it in time and the planet is visited, run out of time (or drain) and
// it waits for the next Mission Control. The stops go round the ring in order: Mercury out to Neptune, then the Sun;
// after the Sun the tour starts again (tour 2, 3 …) with everything worth more.
// Round 1 gives every stop a stand-in goal ("make N of the lit shots"); rounds 2–5 give each its own rules.
import Foundation

/// One stop on the tour: its planet, a goal and a timer.
struct TourStop {
    let planet: String          // the ring's insert name and the window's picture (tour_window_<planet>)
    let title: String           // the mode's name on the banner
    let shots: Set<String>      // the shots lit for the goal: leftOrbit, moon, saturn, rightOrbit
    let need: Int               // how many lit shots finish it
    let seconds: TimeInterval
}

@MainActor
final class TourModes {
    static let allShots: Set<String> = ["leftOrbit", "moon", "saturn", "rightOrbit"]
    /// The ring's order (left to right on the arc).
    static let tour: [TourStop] = [
        TourStop(planet: "mercury", title: "MERCURY DASH", shots: allShots, need: 2, seconds: 20),
        TourStop(planet: "venus", title: "VENUS VEIL", shots: allShots, need: 3, seconds: 40),
        TourStop(planet: "mars", title: "MARS RECON", shots: ["leftOrbit", "rightOrbit"], need: 3, seconds: 45),
        TourStop(planet: "moon", title: "MOONSHOT", shots: ["moon"], need: 2, seconds: 45),
        TourStop(planet: "jupiter", title: "JUPITER STORM", shots: allShots, need: 3, seconds: 40),
        TourStop(planet: "saturn", title: "RING RUNNER", shots: ["saturn"], need: 3, seconds: 45),
        TourStop(planet: "uranus", title: "URANUS ROLL", shots: allShots, need: 5, seconds: 40),
        TourStop(planet: "neptune", title: "NEPTUNE DEEP", shots: allShots, need: 4, seconds: 50),
        TourStop(planet: "sun", title: "SUN SLINGSHOT", shots: allShots, need: 3, seconds: 60),
    ]

    /// Which tour this is (1, then 2 after the Sun …) and how many stops of it are done.
    private(set) var tourNumber = 1
    private(set) var visited: Set<String> = []
    /// The running mode, if any.
    private(set) var active: TourStop?
    private(set) var made = 0
    private(set) var endsAt: TimeInterval = 0

    /// The next stop Mission Control will start (the first on the ring not yet visited this tour).
    var nextStop: TourStop { Self.tour.first { !visited.contains($0.planet) } ?? Self.tour[0] }

    func reset() {
        tourNumber = 1
        visited.removeAll()
        active = nil
        made = 0
    }

    /// Starts the next stop. Returns it (nil if one is already running).
    func start(now: TimeInterval) -> TourStop? {
        guard active == nil else { return nil }
        let s = nextStop
        active = s
        made = 0
        endsAt = now + s.seconds
        return s
    }

    /// Whether `shot` counts toward the running goal.
    func isLit(_ shot: String) -> Bool { active?.shots.contains(shot) ?? false }

    enum ShotResult { case none, progress, complete(TourStop) }

    func shot(_ name: String) -> ShotResult {
        guard let s = active, s.shots.contains(name) else { return .none }
        made += 1
        guard made >= s.need else { return .progress }
        visited.insert(s.planet)
        active = nil
        return .complete(s)
    }

    /// The running mode's time is up (or its ball drained): it ends unvisited, to be restarted.
    func fail() -> TourStop? {
        let s = active
        active = nil
        return s
    }

    /// True once every stop is visited: the next tour begins (the caller shows it).
    func finishTourIfDone() -> Bool {
        guard visited.count == Self.tour.count else { return false }
        visited.removeAll()
        tourNumber += 1
        return true
    }

    func secondsLeft(now: TimeInterval) -> Int { max(0, Int((endsAt - now).rounded(.up))) }
}
