import SpriteKit
import CoreGraphics
import Foundation
import QuartzCore

#if DEBUG
/// Shot Lab (debug builds): a robot player that measures how hard each shot is, using the table's
/// real physics. Table-agnostic — any table's scene adopts ShotLabHost and reports shot events by name.
///
/// Each trial copies how a player aims: hold the flipper up with the ball cradled, drop the flipper,
/// wait a set delay while the ball rolls down it, flip, and record the first thing the ball hits.
/// Sweeping the delay maps flip timing → shot. The window of delays that makes a shot, compared
/// with how precisely a human can time a flip, gives the chance of hitting it (analysed off-device).
@MainActor
protocol ShotLabHost: AnyObject {
    /// The flippers the robot aims from.
    var shotLabFlippers: [ShotLab.FlipperSpec] { get }
    /// A name for the results file ("Grey Invasion").
    var shotLabTableName: String { get }
    func shotLabSetFlipper(_ index: Int, pressed: Bool)
    func shotLabPlaceBall(at point: CGPoint)
    /// Remove every ball and put the table back to a neutral state (targets up, no saves lit, scoops empty).
    func shotLabResetTable()
    /// The ball in play, if any.
    var shotLabBall: (position: CGPoint, velocity: CGVector)? { get }
    /// Optional probe lines (v4): where each flip's ball crosses them, to see near misses.
    var shotLabProbes: [ShotLab.Probe] { get }
    /// The shot events that end a trial (Pinball Lab: each table has its own shots).
    var shotLabMajorEvents: Set<String> { get }
    /// Optional number recorded at each flip (Table 03: where Cthulhu is in his sway, 0–1), or nil.
    var shotLabContext: Double? { get }
}

extension ShotLabHost {
    var shotLabProbes: [ShotLab.Probe] { [] }
    var shotLabMajorEvents: Set<String> { ShotLab.majorEvents }
    var shotLabContext: Double? { nil }
}

@MainActor
final class ShotLab {
    struct FlipperSpec {
        let name: String
        /// The flipper's pivot (for the ball's distance along the flipper at the flip).
        let pivot: CGPoint
        /// Where to drop the ball with the flipper held up, so it settles in the cradle.
        let cradle: CGPoint
    }

    /// A horizontal line across the table at height `y`. The first time a flip's ball crosses it going
    /// up, the lab records the x (and the ball's heading) — e.g. just below a scoop, to see by how much
    /// shots miss it.
    struct Probe {
        let name: String
        let y: CGFloat
    }

    struct Crossing: Codable {
        let x: Double
        let degrees: Double             // heading when it crossed (90 = straight up)
        let speed: Double
    }

    struct Trial: Codable {
        let flipper: String
        let plannedDelay: Double        // seconds from dropping the flipper to flipping
        var physicsStepMs: Double = 0   // table time per physics step (8.3 = a 120 Hz phone, 16.7 = 60 Hz)
        var actualDelay: Double = 0     // what the frame timing allowed
        var flipAlong: Double = 0       // ball's distance from the pivot when flipped (pt)
        var outcome: String = ""        // first shot event, "drain", "none" or "invalid"
        var events: [String] = []       // everything hit, in order (bumpers and slings included)
        var seconds: Double = 0         // flip → outcome
        var note: String = ""           // why a trial was invalid
        var crossings: [String: Crossing] = [:]   // probe name → where the ball crossed it
        var context: Double?             // the host's shotLabContext at the flip (Table 03: Cthulhu's sway phase)
    }

    struct Results: Codable {
        let table: String
        let date: String
        let fps: Double
        let delayStep: Double
        let passes: [Double]            // physics speeds run (0.5 at 60 fps = 120 Hz steps, 1.0 = 60 Hz)
        let majorEvents: [String]
        let trials: [Trial]
    }

    // MARK: Settings
    /// Grey Invasion's events that end a trial: the shots a player aims for. Anything else (bumpers, slings)
    /// is noted only. Other tables supply their own through ShotLabHost.shotLabMajorEvents.
    static let majorEvents: Set<String> = ["rightRamp", "leftRamp", "orbit", "hangar", "abduction", "fighter", "lane"]
    /// Delays swept (v3). v1 (60 fps, 16.7 ms physics steps): shots came from 380–520 ms. v2 (¼ speed,
    /// ~4 ms steps): a wide early Hangar band appeared at 304–367 ms that v1 didn't have — the outcome
    /// depends on the physics step size. So v3 sweeps 200–580 ms…
    static let minDelay = 0.20
    static let maxDelay = 0.58
    static let delayStep = 0.004
    /// …once per pass, each at a physics speed. From the drop to the outcome the scene runs
    /// physicsWorld.speed, the flipper steps and the lab clock at this fraction of real time. In the
    /// 60 fps Simulator, 0.5 gives 8.3 ms steps (a 120 Hz iPhone, like Aaron's) and 1.0 gives 16.7 ms
    /// steps (a 60 Hz iPhone).
    static let passes: [Double] = [0.5, 1.0]
    static let raiseTime: TimeInterval = 0.3     // hold the flipper up this long before dropping the ball
    static let settleTime: TimeInterval = 1.2    // cradle the ball this long first
    static let flipHold: TimeInterval = 0.35     // hold the flip this long
    static let timeout: TimeInterval = 4.0       // after the flip
    static let drainY: CGFloat = -27
    /// A ball that went above `leftFlippersY` and comes back below `returnY` moving down missed everything.
    static let leftFlippersY: CGFloat = 420
    static let returnY: CGFloat = 300

    private enum Stage {
        case start
        case raising(until: TimeInterval)
        case settling(until: TimeInterval)
        case dropped(at: TimeInterval)
        case flipped(at: TimeInterval)
    }

    private unowned let host: ShotLabHost
    private let flippers: [FlipperSpec]
    private let majorEvents: Set<String>
    private var plan: [(flipper: Int, delay: Double, speed: Double)] = []
    private var index = 0
    private var stage: Stage = .start
    private var current: Trial?
    private var leftFlippers = false
    private var lastBall: CGPoint?
    private let probes: [Probe]
    private(set) var trials: [Trial] = []
    private var frames = 0
    private var startedAt: CFTimeInterval?          // real time (the lab clock runs slow at times)

    init(host: ShotLabHost) {
        self.host = host
        flippers = host.shotLabFlippers
        probes = host.shotLabProbes
        majorEvents = host.shotLabMajorEvents
        let steps = Int(((Self.maxDelay - Self.minDelay) / Self.delayStep).rounded())
        for speed in Self.passes {
            for f in flippers.indices {
                for i in 0...steps {
                    // A little jitter (± half a step) so frame timing samples every phase.
                    let jitter = Double.random(in: -0.5...0.5) * Self.delayStep
                    plan.append((f, Self.minDelay + Double(i) * Self.delayStep + jitter, speed))
                }
            }
        }
    }

    /// The physics speed the scene should run this frame: the pass's speed from the flipper drop to
    /// the outcome, full speed while setting up.
    var physicsSpeed: Double {
        guard index < plan.count else { return 1 }
        switch stage {
        case .dropped, .flipped: return plan[index].speed
        default: return 1
        }
    }

    var progressText: String {
        let pass = index < plan.count ? (plan[index].speed == 1 ? " · 60 Hz PASS" : " · 120 Hz PASS") : ""
        return "SHOT LAB \(min(index + 1, plan.count))/\(plan.count)\(pass)"
    }

    /// A shot event from the scene (rightRamp, hangar, fighter, bumper…).
    func event(_ name: String, at now: TimeInterval) {
        guard case .flipped(let at) = stage, var trial = current else { return }
        trial.events.append(name)
        if trial.outcome.isEmpty, majorEvents.contains(name) {
            trial.outcome = name
            trial.seconds = now - at
        }
        current = trial
    }

    /// Runs the robot. Returns false when every trial is done.
    func update(now: TimeInterval) -> Bool {
        frames += 1
        if startedAt == nil { startedAt = CACurrentMediaTime() }
        guard index < plan.count else { return false }
        let step = plan[index]
        let spec = flippers[step.flipper]

        switch stage {
        case .start:
            host.shotLabResetTable()
            for f in flippers.indices { host.shotLabSetFlipper(f, pressed: f == step.flipper) }
            current = Trial(flipper: spec.name, plannedDelay: step.delay)
            leftFlippers = false
            stage = .raising(until: now + Self.raiseTime)     // v2: let the flipper get all the way up first

        case .raising(let until):
            guard now >= until else { break }
            host.shotLabPlaceBall(at: spec.cradle)
            stage = .settling(until: now + Self.settleTime)

        case .settling(let until):
            guard now >= until else { break }
            guard let ball = host.shotLabBall else {
                current?.note = "no ball"
                finishTrial("invalid", now: now)
                break
            }
            let speed = hypot(ball.velocity.dx, ball.velocity.dy)
            let away = hypot(ball.position.x - spec.cradle.x, ball.position.y - spec.cradle.y)
            guard speed < 40, away < 60 else {
                current?.note = String(format: "not settled: speed %.0f, %.0f pt from the cradle at (%.0f, %.0f)",
                                       speed, away, ball.position.x, ball.position.y)
                finishTrial("invalid", now: now)
                break
            }
            host.shotLabSetFlipper(step.flipper, pressed: false)      // drop the flipper: the ball rolls
            stage = .dropped(at: now)
            // Table time per physics step on this pass: a real frame × the pass speed.
            let frame = startedAt.map { frames > 1 ? (CACurrentMediaTime() - $0) / Double(frames) : 1.0 / 60 } ?? 1.0 / 60
            current?.physicsStepMs = (frame * step.speed * 10_000).rounded() / 10

        case .dropped(let at):
            guard now - at >= step.delay else { break }
            host.shotLabSetFlipper(step.flipper, pressed: true)       // flip
            if var trial = current {
                trial.actualDelay = now - at
                trial.context = host.shotLabContext
                if let ball = host.shotLabBall {
                    trial.flipAlong = Double(hypot(ball.position.x - spec.pivot.x, ball.position.y - spec.pivot.y))
                }
                current = trial
            }
            stage = .flipped(at: now)
            lastBall = host.shotLabBall?.position

        case .flipped(let at):
            recordCrossings()
            if now - at >= Self.flipHold { host.shotLabSetFlipper(step.flipper, pressed: false) }
            if let outcome = current?.outcome, !outcome.isEmpty {
                finishTrial(outcome, now: now)
                break
            }
            guard let ball = host.shotLabBall else {                   // e.g. locked away by a scoop
                finishTrial("none", now: now)
                break
            }
            if ball.position.y < Self.drainY {
                finishTrial("drain", now: now, seconds: now - at)
            } else if ball.position.y > Self.leftFlippersY {
                leftFlippers = true
            } else if leftFlippers, ball.position.y < Self.returnY, ball.velocity.dy < 0 {
                finishTrial("none", now: now, seconds: now - at)       // came back without hitting a shot
            } else if now - at > Self.timeout {
                finishTrial("none", now: now, seconds: now - at)
            }
        }
        return index < plan.count
    }

    /// Probe lines: the first upward crossing of each, interpolated between this frame and the last.
    private func recordCrossings() {
        guard let ball = host.shotLabBall else { lastBall = nil; return }
        defer { lastBall = ball.position }
        guard let p0 = lastBall, var trial = current, !probes.isEmpty else { return }
        let p1 = ball.position
        for probe in probes where trial.crossings[probe.name] == nil {
            guard p0.y < probe.y, p1.y >= probe.y, p1.y > p0.y else { continue }
            let t = (probe.y - p0.y) / (p1.y - p0.y)
            let x = p0.x + t * (p1.x - p0.x)
            let v = ball.velocity
            trial.crossings[probe.name] = Crossing(
                x: (Double(x) * 10).rounded() / 10,
                degrees: (Double(atan2(v.dy, v.dx)) * 180 / .pi * 10).rounded() / 10,
                speed: Double(hypot(v.dx, v.dy)).rounded())
        }
        current = trial
    }

    private func finishTrial(_ outcome: String, now: TimeInterval, seconds: Double? = nil) {
        if var trial = current {
            trial.outcome = outcome
            if let seconds { trial.seconds = seconds }
            trials.append(trial)
        }
        current = nil
        for f in flippers.indices { host.shotLabSetFlipper(f, pressed: false) }
        index += 1
        stage = .start
    }

    /// Writes the results. On the Simulator they go straight to ~/Documents/GreyInvasionPinball/ShotLab on
    /// the Mac (SIMULATOR_HOST_HOME); on a phone, to the app's Documents. Returns where, or an error.
    func save(now: TimeInterval) -> String {
        let real = CACurrentMediaTime()
        let fps = startedAt.map { real > $0 ? Double(frames) / (real - $0) : 0 } ?? 0
        let stamp = ISO8601DateFormatter().string(from: Date())
        let results = Results(table: host.shotLabTableName, date: stamp, fps: (fps * 10).rounded() / 10,
                              delayStep: Self.delayStep, passes: Self.passes,
                              majorEvents: majorEvents.sorted(), trials: trials)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(results) else { return "couldn't encode results" }

        var folder: URL
        if let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            folder = URL(fileURLWithPath: hostHome).appendingPathComponent("Documents/GreyInvasionPinball/ShotLab")
        } else {
            folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ShotLab")
        }
        // Pinball Lab: the table's name in the file name (e.g. shotlab-cthulhu-rising-…).
        let slug = host.shotLabTableName.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let name = "shotlab-" + String(slug) + "-" + stamp.replacingOccurrences(of: ":", with: "-") + ".json"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(name)
            try data.write(to: url)
            print("SHOT LAB: saved \(trials.count) trials to \(url.path)")
            return name
        } catch {
            print("SHOT LAB: save failed: \(error)")
            return "save failed"
        }
    }
}
#endif
