// Pinball Lab: the Play Lab (debug builds), shared by every table.
// Robot players at four skills (beginner, intermediate, advanced, expert) play whole games with a table's real rules
// and physics, in two passes: physics stepped like a 120 Hz phone and like a 60 Hz phone. The beginner flips whenever
// the ball is near, with sloppy timing; better players catch the ball on a raised flipper, then aim at the shot the
// table wants (what the host says is lit or asked for) using the Shot Lab's flip timings, with less timing error the
// better they are. Every game is recorded: score, balls, catches, every banner and shot, aims tried and made, when
// each of the table's objectives was first reached, and what the watchdog caught. The report lands in ShotLab/ on
// the Mac (from the Simulator) as playlab-<table>-<date>.json; tools/playlab_report.py reads it.
// Round 4b: flip delays per pass (the 60 Hz windows differ) and a drain log (where, how fast, what the robot was doing,
// how long since the plunge) so the report can say why a skill loses balls.
// Round 2: screenshots and shot tracks. The lab grabs a picture of the table (SKView.texture(from:)) the first time
// each objective is reached in a game, at every watchdog incident and at the end of each game, into a folder beside
// the JSON (playlab-<table>-<date>/NN-<reason>.png, at most `maxCapturesPerGame`). Every aimed flip records the ball's
// path for the next few seconds (PlayTrack: flipper, target, outcome made / miss / drain, points), and the report tool
// draws the tracks over the table as an SVG.
//
// A table joins by adopting PlayLabHost (see LmpTableScene for the pattern): it names its objectives (the same
// goals its How to Play describes), gives its flippers with the Shot Lab's cradle points and flip delays, says what
// it wants shot right now, starts and ends games, and reports shots, banners and objectives as they happen.
//
// Unattended runs: launch the app with `-playlab <table>` (lamplight, greyinvasion, cthulhu, monsoon) and it opens
// that table, runs the lab and quits when the report is saved. Options: `-playlab-games N` (per skill and pass,
// default 2), `-playlab-hz 120|60|both` (default both), `-playlab-skills beginner,expert` (default all),
// `-playlab-cap SECONDS` (a game that runs this long is closed early, default 480).
#if DEBUG
import Foundation
import CoreGraphics
import QuartzCore
import SpriteKit
import UIKit

// MARK: - Skills

nonisolated enum PlaySkill: String, CaseIterable, Codable {
    case beginner, intermediate, advanced, expert

    /// Timing error (seconds, one standard deviation) on every flip.
    var timingSigma: Double {
        switch self {
        case .beginner: return 0.040
        case .intermediate: return 0.025
        case .advanced: return 0.015
        case .expert: return 0.008
        }
    }

    /// How often they try to catch a ball coming down to a flipper (instead of just flipping at it).
    var catchChance: Double {
        switch self {
        case .beginner: return 0
        case .intermediate: return 0.4
        case .advanced: return 0.8
        case .expert: return 0.95
        }
    }

    /// Whether they aim at what the table wants (otherwise a random shot from that flipper).
    var aims: Bool { self == .advanced || self == .expert }

    /// Beginners often hit both buttons at once.
    var flailChance: Double { self == .beginner ? 0.5 : 0 }

    /// How far they pull the plunger (1 = all the way). Better players either go for a full plunge or a
    /// controlled medium one.
    func plungePower(_ rng: inout SystemRandomNumberGenerator) -> CGFloat {
        let r = Double.random(in: 0..<1, using: &rng)
        switch self {
        case .beginner: return CGFloat.random(in: 0.2...1, using: &rng)
        case .intermediate: return CGFloat.random(in: 0.4...1, using: &rng)
        case .advanced: return r < 0.3 ? 0.96 : CGFloat.random(in: 0.55...0.8, using: &rng)
        case .expert: return r < 0.6 ? 0.97 : CGFloat.random(in: 0.6...0.8, using: &rng)
        }
    }
}

/// A pass: how the physics is stepped. The Simulator draws 60 frames a second, so half speed = 120 Hz steps.
nonisolated enum PlayPass: String, CaseIterable, Codable {
    case hz120, hz60

    var physicsSpeed: CGFloat { self == .hz120 ? 0.5 : 1 }
    var stepMs: Double { self == .hz120 ? 1000 / 120 : 1000 / 60 }
    var label: String { self == .hz120 ? "120 Hz" : "60 Hz" }
}

// MARK: - What the robot sees and does

/// What the robot sees each frame.
struct PlayRobotView {
    struct Ball {
        let position: CGPoint
        let velocity: CGVector
        let isUpper: Bool         // on a raised layer (ramp, loft)
        let isHeld: Bool          // in a hole or on a ride
        let onPlunger: Bool
        /// Optional: a stable id per ball (hosts may leave it 0; the lab then follows the aimed ball by proximity).
        var id: Int = 0
    }
    let now: TimeInterval
    let balls: [Ball]
    /// The shots the table wants, most wanted first.
    let wanted: [String]
}

/// One flipper as the robot knows it.
struct PlayRobotFlipper {
    let name: String            // "left", "right", "upper", "loft"
    let pivot: CGPoint
    let length: CGFloat
    /// The rest angle below horizontal (π/6 on every table so far).
    let restAngle: CGFloat
    let pointsLeft: Bool
    /// Where a caught ball rests on the raised flipper (the Shot Lab's cradle).
    let cradle: CGPoint
    let rightButton: Bool
    let upper: Bool             // works on upper-layer balls
    /// The shots from a cradle on this flipper and the Shot Lab's flip delay for each (seconds after dropping it):
    /// the middle of the shot's window in the 120 Hz pass.
    let shots: [(name: String, delay: Double)]
    /// Round 4b: the same for the 60 Hz pass, whose windows differ (the Shot Lab's 60 Hz strip). A shot left out
    /// here has no 60 Hz window: the robot doesn't try it on that pass and the report says so. Empty = use `shots`.
    var shots60: [(name: String, delay: Double)] = []

    /// The shots the robot can aim at on a pass.
    func shots(for pass: PlayPass) -> [(name: String, delay: Double)] {
        pass == .hz60 && !shots60.isEmpty ? shots60 : shots
    }

    /// The resting flipper's tip.
    var restTip: CGPoint {
        let s: CGFloat = pointsLeft ? -1 : 1
        return CGPoint(x: pivot.x + s * length * cos(restAngle), y: pivot.y - length * sin(restAngle))
    }
}

struct PlayRobotCommand {
    var left = false
    var right = false
    var plunge: CGFloat?
    /// A shot the robot just flipped for (to score aims), and the flipper it flipped.
    var aimedAt: String?
    var aimedFrom: Int?
}

final class PlayRobot {
    let skill: PlaySkill
    let pass: PlayPass
    private let flippers: [PlayRobotFlipper]
    private let ballRadius: CGFloat
    private var rng = SystemRandomNumberGenerator()

    private enum Mode {
        case free
        case catching(flipper: Int, since: TimeInterval, steadySince: TimeInterval?)
        case cradled(flipper: Int, dropAt: TimeInterval, target: String, delay: Double)
        case dropped(flipper: Int, flipAt: TimeInterval, target: String)
        case shooting(flipper: Int, until: TimeInterval)
    }
    private var mode: Mode = .free
    /// Reactive flips: per flipper, the trigger drawn for the ball now approaching, and how long to hold a flip.
    private var trigger: [Double?]
    private var holdUntil: [TimeInterval]
    private var decidedCatch: [Bool?]
    private var plungeAt: TimeInterval?

    private(set) var catches = 0

    init(skill: PlaySkill, pass: PlayPass, flippers: [PlayRobotFlipper], ballRadius: CGFloat) {
        self.skill = skill
        self.pass = pass
        self.flippers = flippers
        self.ballRadius = ballRadius
        trigger = Array(repeating: nil, count: flippers.count)
        holdUntil = Array(repeating: -1, count: flippers.count)
        decidedCatch = Array(repeating: nil, count: flippers.count)
    }

    /// What the robot is doing (for the drain log).
    var modeName: String {
        switch mode {
        case .free: return "free"
        case .catching: return "catching"
        case .cradled: return "cradled"
        case .dropped: return "dropped"
        case .shooting: return "shooting"
        }
    }

    private func gauss(_ sigma: Double) -> Double {
        // Box–Muller
        let u1 = max(Double.random(in: 0..<1, using: &rng), 1e-9), u2 = Double.random(in: 0..<1, using: &rng)
        return sigma * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    private static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 0.0001)))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    /// The flipper's "zone": above it and within its reach, on its layer.
    private func inZone(_ b: PlayRobotView.Ball, _ f: PlayRobotFlipper, height: CGFloat) -> Bool {
        guard b.isUpper == f.upper, !b.isHeld, !b.onPlunger else { return false }
        let tip = f.restTip
        let minX = min(f.pivot.x, tip.x) - 14, maxX = max(f.pivot.x, tip.x) + 14
        return b.position.x >= minX && b.position.x <= maxX
            && b.position.y >= tip.y - 12 && b.position.y <= f.pivot.y + height
    }

    /// Round 4d/4e: a ball worth holding the flipper up for: anything over the flipper except a ball crossing low from
    /// the other flipper — that one used to raise the flipper too, and the raised tip clipped it into the drain (run 6's
    /// repeated (251, 283) drains).
    private func catchable(_ b: PlayRobotView.Ball, _ f: PlayRobotFlipper) -> Bool {
        let tip = f.restTip
        let lo = min(f.pivot.x, tip.x), hi = max(f.pivot.x, tip.x)
        let span = (lo - 14)...(hi + 14)
        guard span.contains(b.position.x) else { return false }
        // Round 4e: only the crossing ball is refused — low (below pivot height + 20) and moving in from the tip side
        // at speed. Inlane feeds (slow, at the pivot end) and balls dropping from above are caught as before.
        let towardPivot = f.pointsLeft ? b.velocity.dx > 0 : b.velocity.dx < 0
        let low = b.position.y < f.pivot.y + 20
        let crossing = low && towardPivot && abs(b.velocity.dx) > 200 && abs(b.velocity.dx) > abs(b.velocity.dy)
        return !crossing && b.velocity.dy < 80
    }

    /// While catching: the ball is still over the flipper (not past the tip into the gap, not gone).
    private func overFlipper(_ b: PlayRobotView.Ball, _ f: PlayRobotFlipper) -> Bool {
        let tip = f.restTip
        let lo = min(f.pivot.x, tip.x), hi = max(f.pivot.x, tip.x)
        let span = f.pointsLeft ? (lo + 4)...(hi + 14) : (lo - 14)...(hi - 4)
        return b.isUpper == f.upper && !b.isHeld && span.contains(b.position.x) && b.position.y > tip.y - 12
            && b.position.y < f.pivot.y + 160
    }

    func step(_ view: PlayRobotView) -> PlayRobotCommand {
        var cmd = PlayRobotCommand()
        let now = view.now
        var pressed = Array(repeating: false, count: flippers.count)

        // The plunger: pull after a moment, with this player's habit.
        if view.balls.contains(where: { $0.onPlunger }) {
            if plungeAt == nil { plungeAt = now + Double.random(in: 0.5...1.2, using: &rng) }
            if let at = plungeAt, now >= at {
                plungeAt = nil
                cmd.plunge = skill.plungePower(&rng)
            }
        } else {
            plungeAt = nil
        }

        let free = view.balls.filter { !$0.isHeld && !$0.onPlunger }
        let lowerFree = free.filter { !$0.isUpper }

        // The aimed-shot state machine (one ball at a time).
        switch mode {
        case .free:
            break
        case .catching(let i, let since, let steadySince):
            let f = flippers[i]
            pressed[i] = true
            let near = free.first(where: { $0.isUpper == f.upper && hypot($0.position.x - f.cradle.x, $0.position.y - f.cradle.y) < 26 })
            if let b = near, hypot(b.velocity.dx, b.velocity.dy) < 60 {
                let s = steadySince ?? now
                if now - s >= 0.3 {
                    catches += 1
                    let (target, delay) = pickShot(f, wanted: view.wanted)
                    mode = .cradled(flipper: i, dropAt: now + Double.random(in: 0.4...1.0, using: &rng),
                                    target: target, delay: delay)
                } else {
                    mode = .catching(flipper: i, since: since, steadySince: s)
                }
            } else if now - since > 2.5 || !free.contains(where: { overFlipper($0, f) }) {
                mode = .free
            } else {
                mode = .catching(flipper: i, since: since, steadySince: nil)
            }
        case .cradled(let i, let dropAt, let target, let delay):
            if now >= dropAt {
                mode = .dropped(flipper: i, flipAt: now + max(0.05, delay + gauss(skill.timingSigma)), target: target)
            } else {
                pressed[i] = true
            }
        case .dropped(let i, let flipAt, let target):
            if now >= flipAt {
                pressed[i] = true
                cmd.aimedAt = target
                cmd.aimedFrom = i
                mode = .shooting(flipper: i, until: now + 0.35)
            }
        case .shooting(let i, let until):
            if now < until { pressed[i] = true } else { mode = .free }
        }

        // Reactive flips (and starting a catch) for every flipper not busy with an aimed shot.
        let busy: Int? = {
            switch mode {
            case .free: return nil
            case .catching(let i, _, _), .cradled(let i, _, _, _), .dropped(let i, _, _), .shooting(let i, _): return i
            }
        }()
        for (i, f) in flippers.enumerated() where i != busy {
            if now < holdUntil[i] { pressed[i] = true; continue }
            let approaching = free.filter { inZone($0, f, height: 140) && $0.velocity.dy < 80 }
            guard let b = approaching.min(by: { $0.position.y < $1.position.y }) else {
                trigger[i] = nil
                decidedCatch[i] = nil
                continue
            }
            // A catch? Only one lower ball in play, not too fast, and nothing else going on.
            if busy == nil, decidedCatch[i] == nil {
                let calm = f.upper || lowerFree.count == 1
                decidedCatch[i] = calm && hypot(b.velocity.dx, b.velocity.dy) < 1100 && catchable(b, f)
                    && Double.random(in: 0..<1, using: &rng) < skill.catchChance
            }
            if busy == nil, decidedCatch[i] == true {
                mode = .catching(flipper: i, since: now, steadySince: nil)
                pressed[i] = true
                decidedCatch[i] = nil
                break
            }
            // Flip when the ball is about to reach the flipper, give or take this player's timing.
            if trigger[i] == nil { trigger[i] = max(0, 0.025 + gauss(skill.timingSigma)) }
            let d = Self.distance(b.position, toSegment: f.pivot, f.restTip) - ballRadius - 8
            let speed = max(40, hypot(b.velocity.dx, b.velocity.dy))
            let ttc = Double(max(0, d) / speed)
            if ttc <= trigger[i] ?? 0 {
                holdUntil[i] = now + 0.22
                pressed[i] = true
                trigger[i] = nil
                decidedCatch[i] = nil
                if Double.random(in: 0..<1, using: &rng) < skill.flailChance {
                    for j in flippers.indices where j != i { holdUntil[j] = now + 0.22 }
                }
            }
        }

        for (i, f) in flippers.enumerated() where pressed[i] {
            if f.rightButton { cmd.right = true } else { cmd.left = true }
        }
        return cmd
    }

    /// The shot to try from a cradle: the most wanted one this flipper has (if they aim), else one at random.
    private func pickShot(_ f: PlayRobotFlipper, wanted: [String]) -> (String, Double) {
        let shots = f.shots(for: pass)
        if skill.aims {
            for w in wanted { if let s = shots.first(where: { $0.name == w }) { return (s.name, s.delay) } }
        }
        let s = shots.randomElement(using: &rng) ?? (name: "none", delay: 0.35)
        return (s.name, s.delay)
    }
}

// MARK: - Records

/// Something the watchdog caught.
nonisolated struct PlayIncident: Codable {
    let kind: String        // "stuck", "offTable", "heldTooLong"
    let x: Double
    let y: Double
    let upper: Bool
    let time: Double        // seconds into the game
}

/// One of a table's goals, as its How to Play describes it. The host reports `objective(name)` when it happens.
nonisolated struct PlayObjective: Codable {
    let name: String
    let text: String
}

/// The ball's path after one aimed flip: world points every other frame, until the shot resolves.
nonisolated struct PlayTrack: Codable {
    var flipper: String
    var target: String
    var outcome = "miss"            // "made" (the target's event came), "drain", or "miss"
    var at: Double                  // seconds into the game at the flip
    var points: [[Double]] = []     // [x, y], rounded
}

/// Round 4b: a ball lost — where it was last seen below the flipper pivots, what the robot was doing, how long it
/// had been in play. The report groups these to show WHY a skill drains (fast plunge returns, failed catches…).
nonisolated struct PlayDrain: Codable {
    var at: Double              // seconds into the game
    var x: Double               // the ball's x when last seen below the pivots, heading down
    var speed: Double           // its speed then (pt/s)
    var life: Double            // seconds since the last plunge (the ball's life, with one ball in play)
    var plunge: Double          // that plunge's power (0–1), -1 if no plunge was seen
    var mode: String            // the robot at the last sighting: free / catching / cradled / dropped / shooting
    /// Round 4c/4d: the ball's path over the ~4 s before it went out ([x, y, buttons] every 3rd frame; buttons 0 none,
    /// 1 left, 2 right, 3 both) and the shot events of the 4 s before (newest last), so the report can say what fed
    /// the drain and what the robot was holding.
    var path: [[Double]] = []
    var after: [String] = []
}

/// A screenshot the lab took.
nonisolated struct PlayCapture: Codable {
    let file: String                // relative to the run's folder beside the JSON
    let reason: String              // "objective:<name>", "incident:<kind>", "gameEnd"
    let at: Double                  // seconds into the game
}

/// One robot game.
nonisolated struct PlayGame: Codable {
    var skill: String
    var pass: String                    // "hz120" / "hz60"
    var physicsStepMs: Double
    var variant: String                 // what the host set up for this game ("" if nothing varies)
    var score = 0
    var seconds = 0.0
    var endedBy = ""                    // "gameOver" (balls gone) or "time" (the cap)
    var ballsPlayed = 0
    var catches = 0
    var banners: [String: Int] = [:]
    var shots: [String: Int] = [:]
    var aims: [String: [Int]] = [:]     // target → [tried, made]
    var objectives: [String: Double] = [:]      // objective → seconds into the game it was first reached
    var objectiveCounts: [String: Int] = [:]
    var extras: [String: Int] = [:]     // the host's own counters (requests, waves, regions…)
    var incidents: [PlayIncident] = []
    var tracks: [PlayTrack] = []
    var captures: [PlayCapture] = []
    var drains: [PlayDrain] = []
}

// MARK: - Host

/// What a table scene gives the lab.
protocol PlayLabHost: AnyObject {
    /// For the file name and the report ("The Lamplight").
    var playLabTableName: String { get }
    /// The table's goals, in the order a player meets them.
    var playLabObjectives: [PlayObjective] { get }
    /// The flippers with the Shot Lab's cradles and flip delays.
    var playLabFlippers: [PlayRobotFlipper] { get }
    var playLabBallRadius: CGFloat { get }
    /// How many set-ups the host rotates through (cozy pieces, settings…); 1 if nothing varies.
    var playLabVariantCount: Int { get }
    /// Set the table up for a game (sandbox the save, pick the variant) and start a new game. Returns a label for
    /// the variant ("" if nothing varies).
    func playLabStartGame(variant: Int) -> String
    /// The game is over or capped: tidy up and return the host's own counters for the record.
    func playLabEndGame() -> [String: Int]
    /// The run is over or was stopped: put the player's real table back.
    func playLabStop()
    /// The view the table is drawn in, for screenshots (scenes get this for free below).
    var playLabView: SKView? { get }
}

extension PlayLabHost where Self: SKScene {
    var playLabView: SKView? { view }
}

/// The run's settings, from the launch arguments when there are any.
struct PlayLabConfig {
    var gamesPerSkill = 2
    var skills = PlaySkill.allCases
    var passes = PlayPass.allCases
    /// A game that runs this long (table time) is closed early.
    var maxGameSeconds: TimeInterval = 480
    /// A flip "made" its shot if that shot's event comes within this long.
    var aimWindow: TimeInterval = 3
    /// Screenshots per game at most (the first of each objective, incidents, the end of the game).
    var maxCapturesPerGame = 14
    /// A shot track records the ball every `trackEvery` frames, for at most `trackSeconds` after the flip.
    var trackEvery = 2
    var trackSeconds: TimeInterval = 3.5

    static func fromLaunchArguments() -> PlayLabConfig {
        var c = PlayLabConfig()
        let d = UserDefaults.standard
        if let n = d.object(forKey: "playlab-games") as? String, let v = Int(n), v > 0 { c.gamesPerSkill = v }
        if let hz = d.string(forKey: "playlab-hz") {
            switch hz { case "120": c.passes = [.hz120]; case "60": c.passes = [.hz60]; default: break }
        }
        if let s = d.string(forKey: "playlab-skills") {
            let picked = s.split(separator: ",").compactMap { PlaySkill(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
            if !picked.isEmpty { c.skills = picked }
        }
        if let cap = d.object(forKey: "playlab-cap") as? String, let v = Double(cap), v > 30 { c.maxGameSeconds = v }
        return c
    }
}

// MARK: - The lab

final class PlayLab {
    /// The table named by `-playlab <table>` at launch (lowercase, letters only: "lamplight"), or nil.
    static let launchTable: String? = {
        guard let t = UserDefaults.standard.string(forKey: "playlab") else { return nil }
        let slug = String(t.lowercased().filter { $0.isLetter })
        return slug.isEmpty ? nil : slug
    }()

    struct Plan {
        let skill: PlaySkill
        let pass: PlayPass
        let variant: Int
    }

    private unowned let host: PlayLabHost
    let config: PlayLabConfig
    let plan: [Plan]
    private(set) var index = 0
    private(set) var games: [PlayGame] = []
    private(set) var current: PlayGame?
    private(set) var robot: PlayRobot?
    private var pendingAim: (target: String, until: TimeInterval)?
    private var gameStart: TimeInterval = 0
    private let startedAt = CACurrentMediaTime()
    private var frames = 0
    /// Round 2: the run's stamp (names the JSON and the screenshot folder), the track being recorded, the balls seen
    /// last frame (to follow the aimed ball), screenshots asked for by events (taken at the next frame, before the
    /// physics step) and how many were taken this game.
    private let stamp = ISO8601DateFormatter().string(from: Date())
    private var track: (index: Int, id: Int, last: CGPoint, until: TimeInterval, frame: Int)?
    private var captureQueue: [(reason: String, at: TimeInterval)] = []
    private var capturesThisGame = 0
    /// Round 4b (drain log): balls seen last frame, the lowest ball heading out, the last plunge.
    private var ballCount = 0
    private var lowBall: (x: CGFloat, speed: CGFloat, at: TimeInterval, mode: String)?
    private var lastPlunge: (at: TimeInterval, power: CGFloat)?
    /// Round 4c: where the lowest free ball has been (every 3rd frame, ~2 s) and the recent shot events, for the
    /// drain log.
    private var lowPath: [(x: CGFloat, y: CGFloat, at: TimeInterval, buttons: Double)] = []
    private var recentShots: [(name: String, at: TimeInterval)] = []
    private var lastButtons = 0.0

    init(host: PlayLabHost, config: PlayLabConfig = .fromLaunchArguments()) {
        self.host = host
        self.config = config
        var plan: [Plan] = []
        var k = 0
        let variants = max(1, host.playLabVariantCount)
        for pass in config.passes {
            for skill in config.skills {
                for _ in 0..<config.gamesPerSkill {
                    plan.append(Plan(skill: skill, pass: pass, variant: k % variants))
                    k += 1
                }
            }
        }
        self.plan = plan
    }

    var isDone: Bool { index >= plan.count }

    /// The physics speed for the game in progress (1 between games).
    var physicsSpeed: CGFloat { index < plan.count ? plan[index].pass.physicsSpeed : 1 }

    var progressText: String {
        guard index < plan.count else { return "PLAY LAB DONE" }
        let p = plan[index]
        return "PLAY LAB · \(p.skill.rawValue.uppercased()) · \(p.pass.label) · GAME \(index + 1)/\(plan.count)"
    }

    /// Starts the next game: the host sets the table up, the robot for this skill takes the flippers.
    func beginGame(now: TimeInterval) {
        guard index < plan.count else { return }
        let p = plan[index]
        let label = host.playLabStartGame(variant: p.variant)
        robot = PlayRobot(skill: p.skill, pass: p.pass, flippers: host.playLabFlippers, ballRadius: host.playLabBallRadius)
        current = PlayGame(skill: p.skill.rawValue, pass: p.pass.rawValue, physicsStepMs: p.pass.stepMs, variant: label)
        pendingAim = nil
        gameStart = now
        track = nil
        ballCount = 0
        lowBall = nil
        lastPlunge = nil
        lowPath.removeAll()
        recentShots.removeAll()
        captureQueue.removeAll()
        capturesThisGame = 0
    }

    /// Seconds into the game in progress.
    func elapsed(now: TimeInterval) -> TimeInterval { now - gameStart }

    /// Whether the game in progress has run past the cap.
    func isTimeUp(now: TimeInterval) -> Bool { now - gameStart > config.maxGameSeconds }

    /// One frame of play: the robot looks and decides. Returns nil between games.
    func frame(_ view: PlayRobotView) -> PlayRobotCommand? {
        frames += 1
        guard current != nil, let robot else { return nil }
        takeQueuedCaptures()
        stepTrack(view)
        noteDrains(view, mode: robot.modeName)
        let cmd = robot.step(view)
        lastButtons = (cmd.left ? 1 : 0) + (cmd.right ? 2 : 0)
        if let power = cmd.plunge { lastPlunge = (view.now, power) }
        if let target = cmd.aimedAt {
            current?.aims[target, default: [0, 0]][0] += 1
            pendingAim = (target, view.now + config.aimWindow)
            startTrack(view, target: target, flipper: cmd.aimedFrom ?? 0)
        }
        return cmd
    }

    // MARK: Shot tracks

    /// Starts recording the ball the robot just flipped: the one nearest that flipper's cradle.
    private func startTrack(_ view: PlayRobotView, target: String, flipper: Int) {
        finishTrack(outcome: "miss")
        let flippers = host.playLabFlippers
        guard flipper < flippers.count else { return }
        let f = flippers[flipper]
        let candidates = view.balls.filter { $0.isUpper == f.upper && !$0.isHeld && !$0.onPlunger }
        guard let ball = candidates.min(by: {
            hypot($0.position.x - f.cradle.x, $0.position.y - f.cradle.y) < hypot($1.position.x - f.cradle.x, $1.position.y - f.cradle.y)
        }) else { return }
        current?.tracks.append(PlayTrack(flipper: f.name, target: target, at: (view.now - gameStart).rounded(),
                                         points: [[Double(ball.position.x.rounded()), Double(ball.position.y.rounded())]]))
        track = (index: (current?.tracks.count ?? 1) - 1, id: ball.id, last: ball.position,
                 until: view.now + config.trackSeconds, frame: 0)
    }

    /// Follows the tracked ball by proximity (ids are optional), every `trackEvery` frames, until the time is up or
    /// it drains.
    private func stepTrack(_ view: PlayRobotView) {
        guard var t = track else { return }
        if view.now > t.until { finishTrack(outcome: "miss"); return }
        // By id when the host gives one, else the nearest ball to where it was last frame.
        let near = t.id != 0 ? view.balls.first(where: { $0.id == t.id }) : view.balls.min(by: {
            hypot($0.position.x - t.last.x, $0.position.y - t.last.y) < hypot($1.position.x - t.last.x, $1.position.y - t.last.y)
        })
        guard let b = near, hypot(b.position.x - t.last.x, b.position.y - t.last.y) < 90 else {
            // The ball is gone (drained, removed) or jumped: a drain if it was already below the flippers.
            finishTrack(outcome: t.last.y < drainY ? "drain" : "miss")
            return
        }
        t.last = b.position
        t.frame += 1
        if t.frame % max(1, config.trackEvery) == 0 {
            current?.tracks[t.index].points.append([Double(b.position.x.rounded()), Double(b.position.y.rounded())])
        }
        track = t
    }

    /// Below the lowest flipper pivot the ball is on its way out.
    private var drainY: CGFloat { (host.playLabFlippers.map(\.pivot.y).min() ?? 220) - 40 }

    // MARK: Drain log

    /// A ball that vanishes within 0.6 s of being seen below the flipper pivots, heading down, drained: note where it
    /// was, how fast, what the robot was doing and how long since the plunge that put it in play.
    private func noteDrains(_ view: PlayRobotView, mode: String) {
        let count = view.balls.count
        if count < ballCount { logDrain(now: view.now, mode: mode) }
        ballCount = count
        let pivots = drainY + 40
        let lower = view.balls.filter { !$0.isUpper && !$0.isHeld && !$0.onPlunger }
        if let b = lower.filter({ $0.position.y < pivots && $0.velocity.dy < 0 }).min(by: { $0.position.y < $1.position.y }) {
            lowBall = (b.position.x, hypot(b.velocity.dx, b.velocity.dy), view.now, mode)
        }
        // The path of the lowest free ball, every 3rd frame, kept for 4 s, with the buttons the robot was holding.
        if frames % 3 == 0, let b = lower.min(by: { $0.position.y < $1.position.y }) {
            lowPath.append((b.position.x, b.position.y, view.now, lastButtons))
            while let first = lowPath.first, view.now - first.at > 4 { lowPath.removeFirst() }
        }
    }

    /// Records the drain if a ball was seen on its way out within the last 0.6 s.
    private func logDrain(now: TimeInterval, mode: String) {
        guard let low = lowBall, now - low.at < 0.6 else { return }
        let life = now - (lastPlunge?.at ?? gameStart)
        current?.drains.append(PlayDrain(at: (now - gameStart).rounded(), x: Double(low.x.rounded()),
                                         speed: Double(low.speed.rounded()), life: (life * 10).rounded() / 10,
                                         plunge: lastPlunge.map { (Double($0.power) * 100).rounded() / 100 } ?? -1,
                                         mode: low.mode,
                                         path: lowPath.map { [Double($0.x.rounded()), Double($0.y.rounded()), $0.buttons] },
                                         after: recentShots.filter { now - $0.at <= 4 }.map(\.name)))
        lowBall = nil
        lowPath.removeAll()
    }

    private func finishTrack(outcome: String) {
        guard let t = track else { return }
        if current?.tracks.indices.contains(t.index) == true, current?.tracks[t.index].outcome == "miss" {
            current?.tracks[t.index].outcome = outcome
        }
        track = nil
    }

    // MARK: Screenshots

    /// Asks for a screenshot at the next frame (events arrive mid-update; the picture is taken before the next
    /// physics step).
    private func requestCapture(_ reason: String, now: TimeInterval) {
        guard current != nil, capturesThisGame + captureQueue.count < config.maxCapturesPerGame else { return }
        captureQueue.append((reason, now - gameStart))
    }

    private func takeQueuedCaptures() {
        guard !captureQueue.isEmpty else { return }
        let queue = captureQueue
        captureQueue.removeAll()
        guard let view = host.playLabView, let scene = view.scene else { return }
        for item in queue {
            guard let texture = view.texture(from: scene) else { continue }
            let image = UIImage(cgImage: texture.cgImage())
            guard let data = image.pngData() else { continue }
            capturesThisGame += 1
            let reason = item.reason.replacingOccurrences(of: ":", with: "-")
            let name = "g" + String(format: "%02d", index + 1) + "-" + String(format: "%02d", capturesThisGame) + "-\(reason).png"
            if LabFiles.writeData(data, folder: runFolderName, name: name) {
                current?.captures.append(PlayCapture(file: name, reason: item.reason, at: item.at.rounded()))
            }
        }
    }

    /// The folder beside the JSON that holds this run's screenshots.
    private var runFolderName: String { LabFiles.fileStem(prefix: "playlab", table: host.playLabTableName, stamp: stamp) }

    /// Banners are counted by their first part, numbers blanked ("TEAPOT × #", "THANK YOU!", "COMES IN").
    func banner(_ text: String) {
        guard current != nil else { return }
        var key = String(text.split(separator: "·").first ?? Substring(text)).trimmingCharacters(in: .whitespaces)
        key = String(key.map { $0.isNumber ? "#" : $0 })
        while key.contains("##") { key = key.replacingOccurrences(of: "##", with: "#") }
        if key.hasSuffix(" COMES IN") { key = "COMES IN" }
        current?.banners[key, default: 0] += 1
    }

    /// A shot was made (the Shot Lab's event names).
    func shot(_ name: String, now: TimeInterval) {
        guard current != nil else { return }
        current?.shots[name, default: 0] += 1
        recentShots.append((name, now))
        if recentShots.count > 12 { recentShots.removeFirst() }
        // An event named after the target with a suffix ("windowSeatRepeat" for "windowSeat") is the same shot made
        // in a different state: the aim counts.
        if let aim = pendingAim, name.hasPrefix(aim.target), now <= aim.until {
            current?.aims[aim.target, default: [0, 0]][1] += 1
            pendingAim = nil
            finishTrack(outcome: "made")
        }
    }

    /// One of the table's objectives happened.
    func objective(_ name: String, now: TimeInterval) {
        guard current != nil else { return }
        current?.objectiveCounts[name, default: 0] += 1
        if current?.objectives[name] == nil {
            current?.objectives[name] = (now - gameStart).rounded()
            requestCapture("objective:" + name, now: now)
        }
    }

    func incident(_ i: PlayIncident) {
        current?.incidents.append(i)
        requestCapture("incident:" + i.kind, now: gameStart + i.time)
    }

    /// The game in progress is over (or capped): record it; the host tidies up.
    func endGame(score: Int, ballsPlayed: Int, endedBy: String, now: TimeInterval) {
        finishTrack(outcome: "miss")
        if ballCount > 0 { logDrain(now: now, mode: robot?.modeName ?? "free") }   // the game-ending drain: hosts stop calling frame() at game over
        requestCapture("gameEnd", now: now)
        takeQueuedCaptures()
        guard var g = current else { return }
        g.score = score
        g.seconds = (now - gameStart).rounded()
        g.endedBy = endedBy
        g.ballsPlayed = ballsPlayed
        g.catches = robot?.catches ?? 0
        g.extras = host.playLabEndGame()
        games.append(g)
        current = nil
        robot = nil
        index += 1
    }

    /// Stops the run (the host puts the table back); saves what was played if asked.
    @discardableResult
    func stop(saving: Bool) -> String? {
        current = nil
        robot = nil
        index = plan.count
        host.playLabStop()
        return saving && !games.isEmpty ? save() : nil
    }

    /// Writes the report; returns the file name (or why it failed).
    func save() -> String {
        struct Flipper: Codable {
            let name: String
            let pivot: [Double]
            let length: Double
            let restAngle: Double
            let pointsLeft: Bool
            let upper: Bool
            let shots120: [String: Double]
            let shots60: [String: Double]
        }
        struct Report: Codable {
            let table: String
            let date: String
            let fps: Double
            let gamesPerSkill: Int
            let maxGameSeconds: Double
            let objectives: [PlayObjective]
            let flippers: [Flipper]
            let games: [PlayGame]
        }
        let real = CACurrentMediaTime() - startedAt
        var flippers: [Flipper] = []
        for f in host.playLabFlippers {
            var s120: [String: Double] = [:], s60: [String: Double] = [:]
            for s in f.shots { s120[s.name] = s.delay }
            for s in f.shots(for: .hz60) { s60[s.name] = s.delay }
            flippers.append(Flipper(name: f.name, pivot: [Double(f.pivot.x), Double(f.pivot.y)], length: Double(f.length),
                                    restAngle: Double(f.restAngle), pointsLeft: f.pointsLeft, upper: f.upper,
                                    shots120: s120, shots60: s60))
        }
        let report = Report(table: host.playLabTableName, date: stamp,
                            fps: real > 0 ? (Double(frames) / real * 10).rounded() / 10 : 0,
                            gamesPerSkill: config.gamesPerSkill, maxGameSeconds: config.maxGameSeconds,
                            objectives: host.playLabObjectives, flippers: flippers, games: games)
        return LabFiles.write(report, prefix: "playlab", table: host.playLabTableName, stamp: stamp)
    }

    /// Launched with `-playlab`: quit once the report is saved, so a script running the Simulator can move on.
    static func quitIfLaunchedForLab() {
        guard launchTable != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
    }
}

/// Where lab reports go: ShotLab/ on the Mac from the Simulator, the app's Documents on a phone.
enum LabFiles {
    /// ShotLab/ on the Mac from the Simulator, the app's Documents on a phone.
    static var folder: URL {
        if let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            return URL(fileURLWithPath: hostHome).appendingPathComponent("Documents/GreyInvasionPinball/ShotLab")
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ShotLab")
    }

    /// "playlab-the-lamplight-2026-10-17T22-50-36Z": the JSON's name without .json, and the screenshot folder.
    static func fileStem(prefix: String, table: String, stamp: String) -> String {
        let slug = String(table.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
        return "\(prefix)-\(slug)-" + stamp.replacingOccurrences(of: ":", with: "-")
    }

    /// Writes a file into a subfolder of the lab folder (screenshots).
    static func writeData(_ data: Data, folder sub: String, name: String) -> Bool {
        let dir = folder.appendingPathComponent(sub)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dir.appendingPathComponent(name))
            return true
        } catch {
            print("LAB: couldn't write \(name): \(error)")
            return false
        }
    }

    static func write<T: Encodable>(_ value: T, prefix: String, table: String, stamp: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return "couldn't encode" }
        let folder = Self.folder
        let name = fileStem(prefix: prefix, table: table, stamp: stamp) + ".json"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(name))
            print("LAB: saved \(folder.appendingPathComponent(name).path)")
            return name
        } catch {
            print("LAB: save failed: \(error)")
            return "save failed"
        }
    }
}
#endif
