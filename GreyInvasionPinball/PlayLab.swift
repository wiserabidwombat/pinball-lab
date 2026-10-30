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
// the JSON (playlab-<table>-<date>/NN-<reason>.jpg, half size, at most `maxCapturesPerGame`). Every aimed flip records the ball's
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
// `-playlab-cap SECONDS` (a game that runs this long is closed early, default 480), `-playlab-plunge [REPEATS]` (plan 2
// round 7a: the plunge sweep — no flipping, every served ball plunged at the next power of 0.20…1.00 by 0.05, REPEATS
// balls per power (default 3), and what each plunge did recorded in the report's `plunges`).
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

    /// Round 6a: whether they tap a flipper to move the lit lanes under a ball heading into the top lanes.
    var changesLanes: Bool { aims }

    /// Round 9: whether they let a fast crossing ball hit the resting flipper and bounce to the other side (a dead
    /// bounce) instead of flipping at it.
    var deadBounces: Bool { self == .expert }

    /// Round 10: whether they pass a cradled ball to the other flipper when the wanted shot is over there.
    var passes: Bool { self == .expert }

    /// Round 11: whether they trap one ball on a flipper during multiball and play the other.
    var trapsInMultiball: Bool { self == .expert }

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
    /// Round 6a: the top lanes, for lane changes — each lane's x, their y, and which are lit now. Hosts whose
    /// flippers rotate the lit lanes (a tap of the left button shifts the pattern one lane left, right one lane
    /// right) pass this; nil while the lanes are blinking complete, or on tables without the rule.
    struct Lanes {
        let xs: [CGFloat]
        let y: CGFloat
        let lit: [Bool]
    }
    let now: TimeInterval
    let balls: [Ball]
    /// The shots the table wants, most wanted first.
    let wanted: [String]
    var lanes: Lanes? = nil
    /// Round 7b: the plunger power (0–1) that puts the ball through the table's ringed skill-shot lane right now, or
    /// nil when no ring is lit or that lane can't be reached from the plunger. From the table's plunge sweep.
    var skillPlunge: CGFloat? = nil
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
    /// Round 9b: the inlane Shot Lab's windows (round 15) — for a ball rolling onto this flipper from the inlane, the
    /// shot made by a flip with the ball `lo`…`hi` pt from the pivot, per pass. Empty = no live catch here (the robot
    /// flips a feed at mid-face without aiming).
    var inlane: [(name: String, lo: CGFloat, hi: CGFloat)] = []
    var inlane60: [(name: String, lo: CGFloat, hi: CGFloat)] = []

    /// The shots the robot can aim at on a pass.
    func shots(for pass: PlayPass) -> [(name: String, delay: Double)] {
        pass == .hz60 && !shots60.isEmpty ? shots60 : shots
    }

    /// Round 15c: no fallback — every table's 60 Hz feed windows are measured, so an empty `inlane60` means this
    /// flipper has no usable 60 Hz feed window (Cthulhu's right flipper was aiming at the 120 Hz orbit window).
    func inlane(for pass: PlayPass) -> [(name: String, lo: CGFloat, hi: CGFloat)] {
        pass == .hz60 ? inlane60 : inlane
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
    /// Round 6a: this frame's press is a lane change (a tap to rotate the lit lanes), not a flip at a ball.
    var laneTap = false
    /// Round 7b: this plunge went for the ringed lane (counted as an aim "skillShot").
    var skillPlunge = false
    /// Round 8b: shove the table this way (the host applies it through its own nudge, tilt rule included).
    var nudge: Nudge.Direction? = nil
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
    /// Round 9: per flipper, whether the ball now approaching is being left to bounce off the resting flipper.
    private var decidedBounce: [Bool?]
    /// Round 9b: per flipper, the inlane feed in hand — the shot chosen for it and how far along the face (pt from
    /// the pivot) the ball must be when the flip goes.
    private var inlaneTarget: [(name: String, along: CGFloat)?]
    /// Round 9b: live catches — inlane feeds flipped on the fly at a measured window.
    private(set) var liveCatches = 0
    /// Round 9b⁗: what happened to each inlane feed — aim / none / raise, and for raises caught / launched / dropped.
    private(set) var feeds: [String: Int] = [:]
    /// Round 9b⁗: the current `.catching` began as a feed raise (so its outcome is tallied in `feeds`).
    private var catchFromFeed = false
    /// Round 9c′: every feed raise — [along at the press, ball speed at the press, outcome 0/1/2/3].
    private(set) var raiseLog: [[Double]] = []
    private var plungeAt: TimeInterval?
    /// Round 7a: set by the lab in a plunge sweep — plunge the next served ball at exactly this power, never flip.
    var sweepPower: CGFloat?
    /// Round 6a: lane changes — the tap being held (a couple of frames), which button, and the pause between taps.
    private var laneTapUntil: TimeInterval = -1
    private var laneTapRight = false
    private var laneCooldownUntil: TimeInterval = -1

    private(set) var catches = 0
    private(set) var laneTaps = 0
    /// Round 8b: nudges made, the expert's own count of them in the tilt window, and when the last one was.
    private(set) var nudges = 0
    /// Round 9: dead bounces — crossing balls left to hit the resting flipper and go across.
    private(set) var bounces = 0
    /// Round 10: post passes — the late-flip delays tried (seconds after the drop), the one in flight (which flipper
    /// should receive it, by when, under which name) and the tally per delay: "pass@0.54" → [tried, made].
    static let passLadder = [0.52, 0.54, 0.56]
    private var pendingPass: (flipper: Int, until: TimeInterval, target: String)?
    private(set) var passResults: [String: [Int]] = [:]
    /// Round 11: multiball traps — whether the cradle in hand is being held because another ball is loose, and how
    /// many such holds there were.
    private var trapHeld = false
    private(set) var traps = 0
    private var nudgeTimes: [TimeInterval] = []
    private var nudgeCooldownUntil: TimeInterval = -1
    private(set) var lastNudgeAt: TimeInterval = -.infinity

    init(skill: PlaySkill, pass: PlayPass, flippers: [PlayRobotFlipper], ballRadius: CGFloat) {
        self.skill = skill
        self.pass = pass
        self.flippers = flippers
        self.ballRadius = ballRadius
        trigger = Array(repeating: nil, count: flippers.count)
        holdUntil = Array(repeating: -1, count: flippers.count)
        decidedCatch = Array(repeating: nil, count: flippers.count)
        decidedBounce = Array(repeating: nil, count: flippers.count)
        inlaneTarget = Array(repeating: nil, count: flippers.count)
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
        return !isCrossing(b, f) && b.velocity.dy < 80
    }

    /// A ball coming across low and fast from the other flipper's side (round 4e's crossing ball; round 9's dead-bounce
    /// candidate).
    private func isCrossing(_ b: PlayRobotView.Ball, _ f: PlayRobotFlipper) -> Bool {
        let towardPivot = f.pointsLeft ? b.velocity.dx > 0 : b.velocity.dx < 0
        let low = b.position.y < f.pivot.y + 20
        return low && towardPivot && abs(b.velocity.dx) > 200 && abs(b.velocity.dx) > abs(b.velocity.dy)
    }

    /// Round 9: is a dead bounce the better play for a crossing ball at flipper i? Yes when the OTHER lower flipper
    /// has the table's most wanted shot and this one doesn't (the bounce delivers the ball there), or when the ball
    /// is too fast to catch anyway (a flip would only clip it off the raised tip).
    private func bounceWorthIt(_ i: Int, ball b: PlayRobotView.Ball, wanted: [String]) -> Bool {
        if hypot(b.velocity.dx, b.velocity.dy) >= 1100 { return true }
        guard let want = wanted.first,
              let other = flippers.indices.first(where: { $0 != i && !flippers[$0].upper }) else { return false }
        let mine = flippers[i].shots(for: pass).contains { $0.name == want }
        let theirs = flippers[other].shots(for: pass).contains { $0.name == want }
        return theirs && !mine
    }

    /// While catching: the ball is still over the flipper (not past the tip into the gap, not gone).
    /// Round 9c′: the outcome of the most recent feed raise (1 caught, 2 launched, 3 dropped).
    private func resolveRaise(_ outcome: Double) {
        if let i = raiseLog.indices.last, raiseLog[i][2] == 0 { raiseLog[i][2] = outcome }
    }

    /// Round 9c: a feed still coming down the inlane toward this flipper (above the pivot on the inlane side).
    private func feedComing(_ b: PlayRobotView.Ball, _ f: PlayRobotFlipper) -> Bool {
        let inlaneSide = f.pointsLeft ? b.position.x > f.pivot.x : b.position.x < f.pivot.x
        return b.isUpper == f.upper && !b.isHeld && inlaneSide && abs(b.position.x - f.pivot.x) < 140
            && b.position.y > f.pivot.y - 10 && b.position.y < f.pivot.y + 160
    }

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
                if sweepPower == nil, skill.aims, let p = view.skillPlunge {
                    // Round 7b: go for the ringed lane. The window per lane is ~0.02 of the pull; the expert's hand is
                    // steadier than the advanced player's.
                    let sigma: CGFloat = skill == .expert ? 0.01 : 0.02
                    let u1 = CGFloat.random(in: 0.0001...1, using: &rng), u2 = CGFloat.random(in: 0...1, using: &rng)
                    let noise = sigma * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
                    cmd.plunge = min(1, max(0.1, p + noise))
                    cmd.skillPlunge = true
                } else {
                    cmd.plunge = sweepPower ?? skill.plungePower(&rng)
                }
            }
        } else {
            plungeAt = nil
        }
        if sweepPower != nil { return cmd }   // round 7a: the plunge sweep never flips

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
                    if catchFromFeed { feeds["caught", default: 0] += 1; catchFromFeed = false; resolveRaise(1) }
                    let (target, delay) = pickShot(f, wanted: view.wanted)
                    mode = .cradled(flipper: i, dropAt: now + Double.random(in: 0.4...1.0, using: &rng),
                                    target: target, delay: delay)
                } else {
                    mode = .catching(flipper: i, since: since, steadySince: s)
                }
            } else if now - since > 2.5 || !free.contains(where: { overFlipper($0, f) || (catchFromFeed && feedComing($0, f)) }) {
                if catchFromFeed {
                    // Round 9b⁗: a feed raise that didn't settle — was the ball thrown up the table (the crook-press
                    // shape) or did it just roll off / time out?
                    let b = lowerFree.min(by: { hypot($0.position.x - f.cradle.x, $0.position.y - f.cradle.y)
                                                < hypot($1.position.x - f.cradle.x, $1.position.y - f.cradle.y) })
                    let launched = b.map { $0.position.y > f.pivot.y + 80 || $0.velocity.dy > 100 } ?? false
                    feeds[launched ? "launched" : "dropped", default: 0] += 1
                    catchFromFeed = false
                    resolveRaise(launched ? 2 : 3)
                }
                mode = .free
            } else {
                mode = .catching(flipper: i, since: since, steadySince: nil)
            }
        case .cradled(let i, let dropAt, let target, let delay):
            // Round 11: multiball sense. The expert keeps the trapped ball while another lower ball is loose — the
            // other flipper plays that one — unless the table's most wanted shot is this flipper's. On release the
            // shot is picked afresh (the table may have moved on while the ball waited).
            let f = flippers[i]
            let anotherLoose = lowerFree.contains { hypot($0.position.x - f.cradle.x, $0.position.y - f.cradle.y) > 40 }
            let wantedHere = view.wanted.first.map { w in f.shots(for: pass).contains { $0.name == w } } ?? false
            if skill.trapsInMultiball, anotherLoose, !wantedHere {
                if !trapHeld { trapHeld = true; traps += 1 }
                pressed[i] = true
                mode = .cradled(flipper: i, dropAt: max(dropAt, now + 0.3), target: target, delay: delay)
            } else if now >= dropAt {
                var (target, delay) = (target, delay)
                if trapHeld { trapHeld = false; (target, delay) = pickShot(f, wanted: view.wanted) }
                mode = .dropped(flipper: i, flipAt: now + max(0.05, delay + gauss(skill.timingSigma)), target: target)
            } else {
                pressed[i] = true
            }
        case .dropped(let i, let flipAt, let target):
            if now >= flipAt {
                pressed[i] = true
                if target.hasPrefix("pass@") {
                    // Round 10: a pass, scored by the robot itself (did the other flipper get it?), not as an aim.
                    passResults[target, default: [0, 0]][0] += 1
                    if let j = flippers.indices.first(where: { $0 != i && !flippers[$0].upper }) {
                        pendingPass = (j, now + 3, target)
                    }
                } else if target != "none" { cmd.aimedAt = target; cmd.aimedFrom = i }   // a flipper with no shots just flips
                mode = .shooting(flipper: i, until: now + 0.35)
            }
        case .shooting(let i, let until):
            if now < until { pressed[i] = true } else { mode = .free }
        }

        // Round 10: did the pass arrive? Made when the ball is caught by, or settles over, the other flipper in time.
        if let pp = pendingPass {
            let f = flippers[pp.flipper]
            var caught = false
            if case .catching(let k, _, _) = mode, k == pp.flipper { caught = true }
            if case .cradled(let k, _, _, _) = mode, k == pp.flipper { caught = true }
            if caught || lowerFree.contains(where: { inZone($0, f, height: 60) && hypot($0.velocity.dx, $0.velocity.dy) < 160 }) {
                passResults[pp.target, default: [0, 0]][1] += 1
                pendingPass = nil
            } else if now > pp.until {
                pendingPass = nil
            }
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
                decidedBounce[i] = nil
                inlaneTarget[i] = nil
                continue
            }
            // Round 9: the dead bounce. A ball coming across low and fast is left to hit the resting flipper and
            // bounce to the other side — hands off this flipper until the ball has left its zone.
            if skill.deadBounces, !f.upper, busy == nil, decidedBounce[i] == nil {
                let bounce = isCrossing(b, f) && bounceWorthIt(i, ball: b, wanted: view.wanted)
                decidedBounce[i] = bounce
                if bounce { bounces += 1 }
            }
            if decidedBounce[i] == true {
                trigger[i] = nil
                decidedCatch[i] = nil
                continue
            }
            // Round 9b: the live catch. An inlane feed — a slow ball near the face, rolling from the pivot end toward
            // the tip. The inlane Shot Lab (round 15) measured it: a press with the ball in the crook (< 30 pt from
            // the pivot) lifts it weakly and it falls back down the middle (held up, the flipper then leaves the gap
            // open: the "library · 1105" drains); a flip with the ball 30–75 pt out makes the shot whose window it is
            // in; past ~80 pt it is off the tip. So: hands off until the ball reaches the chosen window, then flip.
            // 9b″: a feed is known by where it comes from — above the pivot on the inlane side, dropping toward the
            // tip (it arrives at ~850 pt/s down the slant); `proj` is the ball's projection along the resting face,
            // negative in the crook, growing as it rolls out (its distance from the pivot shrinks first, so it can't
            // be the trigger). Dribbling balls already on the face don't qualify and keep the old reactive flip.
            let along = hypot(b.position.x - f.pivot.x, b.position.y - f.pivot.y)
            let proj = ((b.position.x - f.pivot.x) * (f.restTip.x - f.pivot.x) + (b.position.y - f.pivot.y) * (f.restTip.y - f.pivot.y))
                / max(f.length, 1)
            let towardTip = f.pointsLeft ? b.velocity.dx < 0 : b.velocity.dx > 0
            let inlaneSide = f.pointsLeft ? b.position.x > f.pivot.x + 4 : b.position.x < f.pivot.x - 4
            let fromInlane = inlaneSide && b.position.y > f.pivot.y + 8 && b.velocity.dy < 0
            if inlaneTarget[i] == nil, !f.upper, fromInlane, towardTip, along < 130, hypot(b.velocity.dx, b.velocity.dy) < 1200 {
                // First sight of a feed: choose the window (the table's wanted shot if this flipper has one for a
                // feed, else the first measured one), and turn this player's timing error into distance along the
                // face (the ball rolls out at ~450 pt/s there). Windows under 30 pt are the crook: never used.
                // 9b‴: live-flip only at the table's WANTED shot when this flipper has a feed window for it; a catcher
                // otherwise raises at the cradle point (38 pt, past the crook) and holds — the normal catch — and the
                // rest flip at mid-face.
                // 9c (the hold Shot Lab): a raise made while the ball is still 40+ pt out — coming down the inlane onto
                // an already-raised flipper — cradles every time; a raise once it is in the crook or on the face
                // launches it. So a catcher raises NOW, on first sight, while the feed is at least 45 pt out, and the
                // catch roll comes before the live aim (a player cradles a feed and shoots from the cradle).
                let windows = f.inlane(for: pass).filter { $0.lo >= 30 }
                let pick = windows.first(where: { w in view.wanted.contains(w.name) })
                let noise = CGFloat(gauss(skill.timingSigma)) * 450
                let calm = lowerFree.count == 1 || skill.trapsInMultiball
                if busy == nil, skill.catchChance > 0, calm, along >= 55, Double.random(in: 0..<1, using: &rng) < skill.catchChance {
                    // 9c′: 55 (was 45) — the lab cradles from 40 pt, but a 60 Hz feed moves 14–20 pt a frame and the
                    // flipper has to get up, so the press has to be decided with margin.
                    mode = .catching(flipper: i, since: now, steadySince: nil)
                    catchFromFeed = true
                    feeds["raise", default: 0] += 1
                    raiseLog.append([Double(along), Double(hypot(b.velocity.dx, b.velocity.dy)), 0])
                    pressed[i] = true
                    trigger[i] = nil
                    decidedCatch[i] = nil
                    break
                } else if let w = pick, skill.aims {
                    inlaneTarget[i] = (w.name, (w.lo + w.hi) / 2 + noise)
                } else {
                    inlaneTarget[i] = ("none", 42 + noise)         // mid-face, clear of the crook (no aim)
                }
            }
            if let t = inlaneTarget[i] {
                if !towardTip || b.velocity.dy > 200 || proj > 95 {
                    inlaneTarget[i] = nil                           // the feed is over (bounced off, past the tip)
                } else if proj >= t.along {
                    holdUntil[i] = now + 0.22
                    pressed[i] = true
                    liveCatches += 1
                    feeds[t.name == "none" ? "none" : "aim", default: 0] += 1
                    if t.name != "none" && t.name != "catch" { cmd.aimedAt = t.name; cmd.aimedFrom = i }
                    inlaneTarget[i] = nil
                    trigger[i] = nil
                    decidedCatch[i] = nil
                    continue
                } else {
                    trigger[i] = nil                                // hands off: the ball is still in the crook
                    decidedCatch[i] = nil
                    continue
                }
            }
            // A catch? Only one lower ball in play, not too fast, and nothing else going on.
            if busy == nil, decidedCatch[i] == nil {
                let calm = f.upper || lowerFree.count == 1 || skill.trapsInMultiball   // round 11: the expert traps
                decidedCatch[i] = calm && hypot(b.velocity.dx, b.velocity.dy) < 1100 && catchable(b, f)
                    && Double.random(in: 0..<1, using: &rng) < skill.catchChance
            }
            if busy == nil, decidedCatch[i] == true {
                mode = .catching(flipper: i, since: now, steadySince: nil)
                catchFromFeed = false
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

        // Round 6a: lane changes. A ball heading into the top lanes toward a LIT lane while another is dark: tap the
        // button that brings a dark lane under it (left shifts the lit pattern one lane left, right one lane right),
        // the fewer taps the better, one tap every 0.3 s. Only when no ball is anywhere near the flippers (the tap
        // flips a lower flipper too) and the robot isn't mid-shot — the way a player picks the moment.
        if now < laneTapUntil {
            if laneTapRight { cmd.right = true } else { cmd.left = true }
        } else if let lanes = view.lanes, skill.changesLanes, busy == nil, now >= laneCooldownUntil,
                  lanes.xs.count == lanes.lit.count, lanes.xs.count >= 2, lanes.lit.contains(false),
                  !pressed.contains(true) {
            let lowY = (flippers.map(\.pivot.y).max() ?? 220) + 260
            if lowerFree.allSatisfy({ $0.position.y > lowY }),
               let b = lowerFree.first(where: { ball in
                   let dy = ball.position.y - lanes.y
                   let toward = (dy > 0 && ball.velocity.dy < -40) || (dy < 0 && ball.velocity.dy > 40)
                   return toward && abs(dy) < 170 && ball.position.x > lanes.xs.min()! - 24 && ball.position.x < lanes.xs.max()! + 24
               }) {
                let n = lanes.xs.count
                let i = lanes.xs.indices.min(by: { abs(lanes.xs[$0] - b.position.x) < abs(lanes.xs[$1] - b.position.x) })!
                if lanes.lit[i] {
                    // Taps of the left button needed until the lane under the ball is dark, and of the right button.
                    let leftTaps = (1..<n).first(where: { !lanes.lit[(i + $0) % n] }) ?? n
                    let rightTaps = (1..<n).first(where: { !lanes.lit[((i - $0) % n + n) % n] }) ?? n
                    laneTapRight = rightTaps < leftTaps
                    laneTapUntil = now + 0.06
                    laneCooldownUntil = now + 0.3
                    laneTaps += 1
                    cmd.laneTap = true
                    if laneTapRight { cmd.right = true } else { cmd.left = true }
                }
            }
        }

        // Round 8b: the nudge.
        if skill.aims, let direction = nudgeDecision(lowerFree, now: now) { cmd.nudge = direction }
        return cmd
    }

    /// Round 8b: a free lower ball on its way out gets a shove. Down the outlane side of a flipper, above the lane
    /// guide (where the ball still chooses between the outlane and the inlane): toward the centre. Into the centre
    /// gap, slowly: back toward the nearer flipper, straight up when it's dead centre. The advanced player reacts
    /// late (only near the guide) and can tilt; the expert reacts higher up and never makes the third nudge in 3 s.
    private func nudgeDecision(_ lowerFree: [PlayRobotView.Ball], now: TimeInterval) -> Nudge.Direction? {
        guard now >= nudgeCooldownUntil else { return nil }
        guard let left = flippers.first(where: { $0.name == "left" }),
              let right = flippers.first(where: { $0.name == "right" }) else { return nil }
        let py = max(left.pivot.y, right.pivot.y)
        let centreX = (left.restTip.x + right.restTip.x) / 2
        let gapHalf = max(0, (right.restTip.x - left.restTip.x) / 2 - ballRadius)
        let outlaneTop: CGFloat = skill == .expert ? 460 : 340        // above py: how early the player reacts
        // 8b′: the advanced player can't watch a multiball; the expert can.
        if skill != .expert, lowerFree.count > 1 { return nil }
        var choice: Nudge.Direction?
        for b in lowerFree where b.velocity.dy < -30 {
            let x = b.position.x, y = b.position.y
            // 8b′: the outlane proper only (x more than 110 pt outside a pivot — the inlane is nearer the flipper and a
            // shove there just skips the ball off the tip), from the guide post's height up.
            if y > py + 240, y < py + outlaneTop {
                if x < left.pivot.x - 110 { choice = .right; break }       // the left outlane
                if x > right.pivot.x + 110 { choice = .left; break }       // the right outlane
            }
            if y > py - 30, y < py + 60, abs(x - centreX) < gapHalf, hypot(b.velocity.dx, b.velocity.dy) < 220 {
                choice = abs(x - centreX) < 10 ? .up : (x < centreX ? .left : .right)
                break
            }
        }
        guard let direction = choice else { return nil }
        if skill == .expert {
            nudgeTimes = nudgeTimes.filter { now - $0 < Nudge.window }
            if nudgeTimes.count >= Nudge.tiltAt - 1 { return nil }         // the next one would tilt
            nudgeTimes.append(now)
        }
        nudgeCooldownUntil = now + (skill == .expert ? 0.6 : 1.5)
        nudges += 1
        lastNudgeAt = now
        return direction
    }

    /// The shot to try from a cradle: the most wanted one this flipper has (if they aim), else one at random.
    private func pickShot(_ f: PlayRobotFlipper, wanted: [String]) -> (String, Double) {
        let shots = f.shots(for: pass)
        if skill.aims {
            // Round 10: the post pass. The expert, holding the ball on the wrong flipper (the MOST wanted shot is the
            // other lower flipper's and not this one's), flips late to loft the ball across instead of settling for a
            // lesser shot from here. Checked before the wanted loop (10′): the loop always finds a fallback.
            if skill.passes, !f.upper, let w = wanted.first, !shots.contains(where: { $0.name == w }),
               let other = flippers.first(where: { $0.name != f.name && !$0.upper }),
               other.shots(for: pass).contains(where: { $0.name == w }) {
                let d = nextPassDelay()
                return ("pass@" + String(format: "%.2f", d), d)
            }
            for w in wanted { if let s = shots.first(where: { $0.name == w }) { return (s.name, s.delay) } }
        }
        // No cradle shots from this flipper (Monsoon's upper flipper: the Shot Lab found only slivers there): just flip
        // it off the cradle somewhere, as a player would, without scoring an aim.
        let s = shots.randomElement(using: &rng) ?? (name: "none", delay: Double.random(in: 0.28...0.42, using: &rng))
        return (s.name, s.delay)
    }
}

extension PlayRobot {
    /// Round 10: the pass delay to try next — each rung of the ladder twice, then the one with the best rate.
    fileprivate func nextPassDelay() -> Double {
        let ladder = PlayRobot.passLadder
        func stats(_ d: Double) -> [Int] { passResults["pass@" + String(format: "%.2f", d)] ?? [0, 0] }
        if let d = ladder.first(where: { stats($0)[0] < 2 }) { return d }
        func rate(_ d: Double) -> Double { let s = stats(d); return s[0] > 0 ? Double(s[1]) / Double(s[0]) : 0 }
        return ladder.max(by: { rate($0) < rate($1) }) ?? 0.54
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
    /// Round 8b: the robot nudged within 1.5 s before the ball went.
    var nudged = false
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
    var laneTaps = 0                    // round 6a: flipper taps made to move the lit lanes under a ball
    var nudges = 0                      // round 8b: nudges the robot made
    var tilts = 0                       // round 8b: TILT banners (flippers dead for the rest of that ball)
    var bounces = 0                     // round 9: dead bounces (a crossing ball left to bounce off the resting flipper)
    var traps = 0                       // round 11: multiball traps (a cradle held while another ball was loose)
    var liveCatches = 0                 // round 9b: inlane feeds flipped on the fly at a measured window
    var feeds: [String: Int] = [:]      // round 9b⁗: aim / none / raise → caught / launched / dropped
    var feedRaises: [[Double]] = []     // round 9c′: per raise [along, speed, outcome 0/1 caught/2 launched/3 dropped]
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
    var plunges: [PlayPlunge] = []      // round 7a: the plunge sweep's record of every plunge (empty in normal runs)
}

/// Round 7a: what one plunge did — for the sweep that maps plunger power to the top lanes / skill shot per table.
nonisolated struct PlayPlunge: Codable {
    var at: Double              // seconds into the game
    var power: Double           // 0–1
    var event: String           // the first shot event within 4 s ("" if none)
    var lane: Int               // the top lane the ball crossed first (index into the host's lanes), -1 if none seen
    var litLane: Int            // the lane that was lit at the plunge (one lit lane = the skill target), -1 if n/a
    var peakY: Double           // the highest the ball got in 4 s
    var skillShot: Bool         // the table's SKILL SHOT objective fired while watching
    var drained: Bool           // the ball was lost within the watch
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
    /// Plan 2 round 1: which build played. `-playlab-build` is written by tools/playlab_run.sh at build time (git hash,
    /// dirty files, branch); the rest the app reads about itself, so a phone run is identified too.
    var build = PlayLabBuild.current(fromArguments: nil)
    /// Plan 2 round 6: play at the display's own physics step (speed 1) instead of the Simulator's scaled passes —
    /// the phone is the real thing. The pass label is picked from the display's refresh rate.
    var nativeSpeed = false
    /// Round 6: open the share sheet with the report when it is saved (the phone's Documents folder is otherwise
    /// out of reach).
    var shareOnSave = false
    /// Round 12: no robot — the lab only watches while YOU play (drains, shots, objectives, catches), and the game is
    /// labelled "you" in the report, so tools/playlab_calibrate.py can say which robot you play like.
    var recording = false

    /// Round 12, the "Record me" button: one game of your own, at the phone's own step, a 15-minute cap, the report
    /// shared when it ends.
    static var recording: PlayLabConfig {
        var c = PlayLabConfig.quick
        c.maxGameSeconds = 900
        c.recording = true
        return c
    }
    /// Round 7a: the plunge sweep — no flipping; every served ball is plunged at the next power in `plungePowers`
    /// (each repeated `plungeRepeats` times, in order), and what it did is recorded.
    var plungeSweep = false
    var plungePowers: [CGFloat] = stride(from: 0.20, through: 1.001, by: 0.025).map { CGFloat($0) }
    var plungeRepeats = 2   // the Simulator is deterministic at a fixed step: a finer power grid beats repeats

    /// Round 6, the "Play Lab · quick" button: one expert game, 120 Hz (or the phone's own rate), a 3-minute cap, a
    /// few screenshots, the report shared when done — a rule change checked in three minutes without the Mac.
    static var quick: PlayLabConfig {
        var c = PlayLabConfig()
        c.gamesPerSkill = 1
        c.skills = [.expert]
        let fps = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.maximumFramesPerSecond }.max() ?? 60
        c.passes = [fps >= 100 ? .hz120 : .hz60]
        c.maxGameSeconds = 180
        c.maxCapturesPerGame = 4
        c.nativeSpeed = true
        c.shareOnSave = true
        return c
    }

    static func fromLaunchArguments() -> PlayLabConfig {
        var c = PlayLabConfig()
        let d = UserDefaults.standard
        c.build = PlayLabBuild.current(fromArguments: d.string(forKey: "playlab-build"))
        if let n = d.object(forKey: "playlab-games") as? String, let v = Int(n), v > 0 { c.gamesPerSkill = v }
        if let hz = d.string(forKey: "playlab-hz") {
            switch hz { case "120": c.passes = [.hz120]; case "60": c.passes = [.hz60]; default: break }
        }
        if let s = d.string(forKey: "playlab-skills") {
            let picked = s.split(separator: ",").compactMap { PlaySkill(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
            if !picked.isEmpty { c.skills = picked }
        }
        if let cap = d.object(forKey: "playlab-cap") as? String, let v = Double(cap), v > 30 { c.maxGameSeconds = v }
        if let r = d.object(forKey: "playlab-plunge") as? String {
            c.plungeSweep = true
            c.plungeRepeats = max(1, Int(r) ?? 2)
            c.skills = [.expert]
            // Three balls per game on every table; a short cap, since an unflipped ball rarely lives long.
            c.gamesPerSkill = (c.plungePowers.count * c.plungeRepeats + 2) / 3
            c.maxGameSeconds = 240
            c.maxCapturesPerGame = 0
        }
        return c
    }
}

/// What was built and where it ran, for the report header: a run is only comparable with another when this matches.
struct PlayLabBuild: Codable {
    /// From the runner: "c6650e8 · dirty: MonTableScene.swift · main · 2026-10-23 21:10" (nil on a phone build).
    let id: String?
    /// The app's own facts: CFBundleVersion, when the executable was written (= built), and what ran it.
    let bundleVersion: String
    let builtAt: String
    let device: String

    static func current(fromArguments id: String?) -> PlayLabBuild {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))"
        var built = "?"
        if let exe = Bundle.main.executableURL,
           let date = (try? FileManager.default.attributesOfItem(atPath: exe.path))?[.modificationDate] as? Date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm"
            built = f.string(from: date)
        }
        let env = ProcessInfo.processInfo.environment
        let device = env["SIMULATOR_HOST_HOME"] != nil
            ? "simulator " + (env["SIMULATOR_DEVICE_NAME"] ?? "")
            : UIDevice.current.model + " " + UIDevice.current.systemVersion
        return PlayLabBuild(id: id, bundleVersion: version, builtAt: built, device: device.trimmingCharacters(in: .whitespaces))
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

    /// Round 6: set by a view's "Play Lab · quick" button just before it calls the host's debugStartPlayLab(), so the
    /// hosts (which construct the lab with the default config) need no change. Consumed by init.
    static var nextRunIsQuick = false
    /// Round 12: set by a view's "Record me" button the same way.
    static var nextRunIsRecording = false

    private unowned let host: PlayLabHost
    let config: PlayLabConfig
    let plan: [Plan]
    private(set) var index = 0
    private(set) var games: [PlayGame] = []
    private(set) var current: PlayGame?
    private(set) var robot: PlayRobot?
    private var pendingAim: (target: String, until: TimeInterval)?
    /// Round 7b: a skill plunge is an aim at "skillShot", made if the objective fires within 4 s.
    private var pendingSkill: TimeInterval?
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
    /// Round 7a: the plunge sweep — which scheduled plunge is next, and the plunge being watched (index into
    /// current.plunges, until when, the ball's last y so a lane crossing is seen).
    private var plungeIndex = 0
    private var watching: (index: Int, until: TimeInterval, lastY: CGFloat?)?
    /// Round 4c: where the lowest free ball has been (every 3rd frame, ~2 s) and the recent shot events, for the
    /// drain log.
    private var lowPath: [(x: CGFloat, y: CGFloat, at: TimeInterval, buttons: Double)] = []
    private var recentShots: [(name: String, at: TimeInterval)] = []
    private var lastButtons = 0.0

    init(host: PlayLabHost, config given: PlayLabConfig? = nil) {
        self.host = host
        let config: PlayLabConfig
        if let given {
            config = given
        } else if PlayLab.nextRunIsQuick {
            PlayLab.nextRunIsQuick = false
            config = .quick
        } else if PlayLab.nextRunIsRecording {
            PlayLab.nextRunIsRecording = false
            config = .recording
        } else {
            config = .fromLaunchArguments()
        }
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
    var physicsSpeed: CGFloat { index < plan.count && !config.nativeSpeed ? plan[index].pass.physicsSpeed : 1 }

    var progressText: String {
        guard index < plan.count else { return "PLAY LAB DONE" }
        let p = plan[index]
        if config.recording { return "RECORDING YOU · \(p.pass.label) · play as you always do" }
        return "PLAY LAB · \(p.skill.rawValue.uppercased()) · \(p.pass.label) · GAME \(index + 1)/\(plan.count)"
    }

    /// Starts the next game: the host sets the table up, the robot for this skill takes the flippers.
    func beginGame(now: TimeInterval) {
        guard index < plan.count else { return }
        let p = plan[index]
        let label = host.playLabStartGame(variant: p.variant)
        robot = config.recording ? nil
            : PlayRobot(skill: p.skill, pass: p.pass, flippers: host.playLabFlippers, ballRadius: host.playLabBallRadius)
        current = PlayGame(skill: config.recording ? "you" : p.skill.rawValue, pass: p.pass.rawValue,
                           physicsStepMs: p.pass.stepMs, variant: label)
        humanCatches = 0
        humanCradle = [:]
        pendingAim = nil
        gameStart = now
        track = nil
        ballCount = 0
        lowBall = nil
        lastPlunge = nil
        watching = nil
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
    /// Round 12: catches made by a human — a lower ball resting at a flipper's cradle (within 26 pt, under 60 pt/s)
    /// for 0.3 s counts once, until the ball leaves the cradle again.
    private var humanCatches = 0
    private var humanCradle: [Int: (since: TimeInterval, counted: Bool)] = [:]

    private func watchHumanCatches(_ view: PlayRobotView) {
        for (i, f) in host.playLabFlippers.enumerated() {
            let resting = view.balls.first { b in
                !b.isHeld && !b.onPlunger && b.isUpper == f.upper
                    && hypot(b.position.x - f.cradle.x, b.position.y - f.cradle.y) < 26
                    && hypot(b.velocity.dx, b.velocity.dy) < 60
            }
            guard resting != nil else { humanCradle[i] = nil; continue }
            var c = humanCradle[i] ?? (view.now, false)
            if !c.counted, view.now - c.since >= 0.3 { humanCatches += 1; c.counted = true }
            humanCradle[i] = c
        }
    }

    func frame(_ view: PlayRobotView) -> PlayRobotCommand? {
        frames += 1
        guard current != nil else { return nil }
        if config.recording {
            // Round 12: only watching. The host gets no command, so the flippers stay with the player.
            takeQueuedCaptures()
            noteDrains(view, mode: "you")
            watchHumanCatches(view)
            return nil
        }
        guard let robot else { return nil }
        takeQueuedCaptures()
        stepTrack(view)
        noteDrains(view, mode: robot.modeName)
        if config.plungeSweep {
            robot.sweepPower = config.plungePowers[(plungeIndex / config.plungeRepeats) % config.plungePowers.count]
            watchPlunge(view)
        }
        let cmd = robot.step(view)
        lastButtons = (cmd.left ? 1 : 0) + (cmd.right ? 2 : 0)
        if let power = cmd.plunge {
            lastPlunge = (view.now, power)
            if cmd.skillPlunge {
                current?.aims["skillShot", default: [0, 0]][0] += 1
                pendingSkill = view.now + 4
            }
            if config.plungeSweep, var g = current {
                let lit = view.lanes.map { l in l.lit.filter { $0 }.count == 1 ? (l.lit.firstIndex(of: true) ?? -1) : -1 } ?? -1
                g.plunges.append(PlayPlunge(at: (view.now - gameStart).rounded(), power: (Double(power) * 100).rounded() / 100,
                                            event: "", lane: -1, litLane: lit, peakY: 0, skillShot: false, drained: false))
                current = g
                watching = (g.plunges.count - 1, view.now + 4, nil)
                plungeIndex += 1
            }
        }
        if let target = cmd.aimedAt {
            current?.aims[target, default: [0, 0]][0] += 1
            pendingAim = (target, view.now + config.aimWindow)
            startTrack(view, target: target, flipper: cmd.aimedFrom ?? 0)
        }
        return cmd
    }

    // MARK: Plunge sweep (round 7a)

    /// Follows the plunged ball for 4 s: its peak, the first top lane it crosses (the host's lanes), a drain.
    private func watchPlunge(_ view: PlayRobotView) {
        guard let w = watching, w.index < (current?.plunges.count ?? 0) else { return }
        let i = w.index
        if view.now > w.until { watching = nil; return }
        let free = view.balls.filter { !$0.isHeld && !$0.onPlunger && !$0.isUpper }
        guard let b = free.max(by: { $0.position.y < $1.position.y }) else {
            // No free ball a second after the plunge: it drained (the next ball may already sit on the plunger).
            if view.now > w.until - 3 { current?.plunges[i].drained = true; watching = nil }
            return
        }
        let y = b.position.y
        if Double(y) > current!.plunges[i].peakY { current?.plunges[i].peakY = Double(y.rounded()) }
        // A lane crossing in either direction: up from the plunge, or down from the top arch after an orbit ride.
        if let lanes = view.lanes, current!.plunges[i].lane < 0, let last = w.lastY, (last - lanes.y) * (y - lanes.y) <= 0, last != y,
           lanes.xs.count >= 2, b.position.x > lanes.xs.min()! - 24, b.position.x < lanes.xs.max()! + 24 {
            current?.plunges[i].lane = lanes.xs.indices.min(by: { abs(lanes.xs[$0] - b.position.x) < abs(lanes.xs[$1] - b.position.x) })!
        }
        watching = (i, w.until, y)
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
                                         after: recentShots.filter { now - $0.at <= 4 }.map(\.name),
                                         nudged: now - (robot?.lastNudgeAt ?? -.infinity) < 1.5))
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
            // 2026-10-23: half-size JPEG (~0.3–0.5 MB) instead of a full-size PNG (~8 MB); full PNGs filled the Mac's disk
            // during an overnight sweep (~1.2 GB per run).
            let full = texture.cgImage()
            let half = CGSize(width: max(1, full.width / 2), height: max(1, full.height / 2))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: half, format: format).image { _ in
                UIImage(cgImage: full).draw(in: CGRect(origin: .zero, size: half))
            }
            guard let data = image.jpegData(compressionQuality: 0.7) else { continue }
            capturesThisGame += 1
            let reason = item.reason.replacingOccurrences(of: ":", with: "-")
            let name = "g" + String(format: "%02d", index + 1) + "-" + String(format: "%02d", capturesThisGame) + "-\(reason).jpg"
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
        if let w = watching, w.index < (current?.plunges.count ?? 0), current!.plunges[w.index].event.isEmpty,
           !["bumper", "sling", "dustDevil", "spinner"].contains(name) {   // round 7a: the first real event after the plunge
            current?.plunges[w.index].event = name
        }
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
        if name == "skillShot", let w = watching, w.index < (current?.plunges.count ?? 0) { current?.plunges[w.index].skillShot = true }
        if name == "skillShot", let until = pendingSkill, now <= until {
            current?.aims["skillShot", default: [0, 0]][1] += 1
            pendingSkill = nil
        }
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
        g.catches = robot?.catches ?? humanCatches
        g.laneTaps = robot?.laneTaps ?? 0
        g.nudges = robot?.nudges ?? 0
        g.tilts = g.banners["TILT"] ?? 0
        g.bounces = robot?.bounces ?? 0
        g.traps = robot?.traps ?? 0
        g.liveCatches = robot?.liveCatches ?? 0
        g.feeds = robot?.feeds ?? [:]
        g.feedRaises = robot?.raiseLog ?? []
        for (k, v) in robot?.passResults ?? [:] { g.aims[k] = v }      // round 10: "pass@0.54" → [tried, made]
        g.extras = host.playLabEndGame()
        games.append(g)
        current = nil
        robot = nil
        index += 1
        // 2026-10-29: write the report after every game (the same file, overwritten), so a run stopped by the
        // runner's time limit keeps every finished game instead of losing them all.
        if index < plan.count { _ = save() }
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
            let build: PlayLabBuild
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
        let report = Report(table: host.playLabTableName, date: stamp, build: config.build,
                            fps: real > 0 ? (Double(frames) / real * 10).rounded() / 10 : 0,
                            gamesPerSkill: config.gamesPerSkill, maxGameSeconds: config.maxGameSeconds,
                            objectives: host.playLabObjectives, flippers: flippers, games: games)
        let name = LabFiles.write(report, prefix: "playlab", table: host.playLabTableName, stamp: stamp)
        if config.shareOnSave, name.hasSuffix(".json") {
            let url = LabFiles.folder.appendingPathComponent(name)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { LabFiles.share(url) }
        }
        return name
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

    /// Round 6: the share sheet for a report saved on the phone (AirDrop it to the Mac, save it to Files, …).
    static func share(_ url: URL) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.keyWindow,
              let root = window.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        top.present(sheet, animated: true)
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
