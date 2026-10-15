// Pinball Lab Table 03 (Cthulhu Rising), milestone 5 round 2: the slingshot test (debug builds).
import SpriteKit
import CoreGraphics
import Foundation
import QuartzCore

#if DEBUG
/// What the Sling Lab needs from the table scene.
@MainActor
protocol CthSlingLabHost: AnyObject {
    /// Remove every ball and put the table back to neutral (flippers down, targets up, Cthulhu under).
    func slingLabResetTable()
    /// Rebuild both slingshots with this geometry (left sling given; the right one mirrors it).
    func slingLabSetSlings(_ variant: CthSlingLab.Variant)
    func slingLabLaunch(at point: CGPoint, velocity: CGVector)
    var slingLabBall: (position: CGPoint, velocity: CGVector)? { get }
}

/// The slingshot test. The robot throws the same set of balls at the lower table once per sling design
/// and records where each ball ends up: on a flipper (saveable), down an outlane, straight down the
/// middle, back up the table, or still bouncing at the timeout. Every sling kick on the way is logged,
/// with where along the rubber it hit (0 = the tip post by the flipper, 1 = the top post).
///
/// Two families of balls:
/// - "drop": loose balls coming down from just above the slings (y 470, anywhere between the lane
///   guides, heading down at any angle, 0–600 pt/s), as after a bumper, target or Cthulhu hit.
/// - "flipper": balls bouncing up off a lowered flipper (anywhere along it, up at 20°–160°, 250–950 pt/s),
///   the classic way into a slingshot.
/// The flippers stay down the whole time (no robot flipping), so any flipper touch counts as saveable.
/// Runs at 120 Hz physics steps (half speed in the 60 fps Simulator, like the Shot Lab's first pass).
@MainActor
final class CthSlingLab {
    /// One sling design. `rotate` turns the rubber face about its top post (degrees; + = the tip moves
    /// up and in, so the kick points further up the table). The kicking part of the face runs from
    /// `kickFrom` to `kickTo` (fractions from the tip post to the top post).
    struct Variant: Codable {
        let name: String
        let rotate: Double
        let kickFrom: Double
        let kickTo: Double

        /// The left sling for this design (top and corner stay put, the tip swings about the top).
        var leftSling: (top: CGPoint, corner: CGPoint, tip: CGPoint) {
            let s = CthTableLayout.leftSling
            let a = CGFloat(rotate) * .pi / 180
            let d = CGVector(dx: s.tip.x - s.top.x, dy: s.tip.y - s.top.y)
            let tip = CGPoint(x: s.top.x + d.dx * cos(a) - d.dy * sin(a),
                              y: s.top.y + d.dx * sin(a) + d.dy * cos(a))
            return (s.top, s.corner, tip)
        }

        var rightSling: (top: CGPoint, corner: CGPoint, tip: CGPoint) {
            let l = leftSling
            return (CthTableLayout.mirrored(l.top), CthTableLayout.mirrored(l.corner), CthTableLayout.mirrored(l.tip))
        }

        /// The left sling's kick direction, in degrees above horizontal (the right one mirrors it).
        var kickDegrees: Double {
            let l = leftSling
            let d = CGVector(dx: l.tip.x - l.top.x, dy: l.tip.y - l.top.y)
            var n = CGVector(dx: d.dy, dy: -d.dx)
            if n.dx * (l.corner.x - l.top.x) + n.dy * (l.corner.y - l.top.y) > 0 { n = CGVector(dx: -n.dx, dy: -n.dy) }
            return (Double(atan2(n.dy, n.dx)) * 1800 / .pi).rounded() / 10
        }
    }

    /// The designs compared. "current" is the table as built (T3 M2 v2: rubber 6–94% of the face).
    static let variants: [Variant] = [
        Variant(name: "current", rotate: 0, kickFrom: Double(CthTableLayout.slingKickFrom),
                kickTo: Double(CthTableLayout.slingKickTo)),
        Variant(name: "short rubber", rotate: 0, kickFrom: 0.12, kickTo: 0.75),   // Grey Invasion's
        Variant(name: "steeper 5°", rotate: 5, kickFrom: Double(CthTableLayout.slingKickFrom),
                kickTo: Double(CthTableLayout.slingKickTo)),
        Variant(name: "steeper 10°", rotate: 10, kickFrom: Double(CthTableLayout.slingKickFrom),
                kickTo: Double(CthTableLayout.slingKickTo)),
    ]
    // (A flatter sling isn't tested: 3° flatter already leaves the inlane only ~3 pt wider than the ball.)

    static let dropLaunches = 100
    static let flipperLaunches = 60
    static let physicsSpeed = 0.5
    static let timeout: TimeInterval = 6
    /// Outcome lines.
    static let upfieldY: CGFloat = 620
    static let drainY: CGFloat = 150
    static let outlaneTopY: CGFloat = CthTableLayout.laneGuideBend

    struct Launch: Codable {
        let family: String
        let side: String            // which side of the table it starts on
        let x: Double, y: Double, vx: Double, vy: Double
    }

    struct Kick: Codable {
        let sling: String           // "left" / "right"
        let along: Double           // 0 = tip post, 1 = top post
        let seconds: Double
    }

    struct Trial: Codable {
        let launch: Int
        let variant: String
        var outcome = ""            // flipper, outlaneLeft, outlaneRight, drain, upfield, timeout
        var seconds: Double = 0
        var kicks: [Kick] = []
    }

    struct Results: Codable {
        let table: String
        let date: String
        let fps: Double
        let physicsSpeed: Double
        let variants: [Variant]
        let kickDegrees: [String: Double]
        let launches: [Launch]
        let trials: [Trial]
    }

    private unowned let host: CthSlingLabHost
    private(set) var launches: [Launch] = []
    private var plan: [(launch: Int, variant: Int)] = []
    private var index = 0
    private var startedTrialAt: TimeInterval?
    private var current: Trial?
    private var currentVariant: Int = -1
    private(set) var trials: [Trial] = []
    private var frames = 0
    private var startedAt: CFTimeInterval?

    init(host: CthSlingLabHost) {
        self.host = host
        var rng = SplitMix(seed: 0x5117_0C70)      // the same balls every run
        for i in 0..<(Self.dropLaunches + Self.flipperLaunches) {
            launches.append(i < Self.dropLaunches ? Self.dropLaunch(&rng) : Self.flipperLaunch(&rng))
        }
        // Each ball is thrown at every design before the next ball, so a part run still compares fairly.
        for l in launches.indices {
            for v in Self.variants.indices { plan.append((l, v)) }
        }
    }

    private static func dropLaunch(_ rng: inout SplitMix) -> Launch {
        let x = rng.uniform(66, 502)
        let a = rng.uniform(-150, -30) * .pi / 180
        let s = rng.uniform(0, 600)
        return Launch(family: "drop", side: x < Double(CthTableLayout.mirrorSum) / 2 ? "left" : "right",
                      x: x, y: 470, vx: s * cos(a), vy: s * sin(a))
    }

    /// A ball just above a lowered flipper, bouncing up off it.
    private static func flipperLaunch(_ rng: inout SplitMix) -> Launch {
        let left = rng.uniform(0, 1) < 0.5
        let p = CthTableLayout.leftFlipperPivot
        let rest = Double(CthTableLayout.flipperRestAngle)          // 30° below horizontal
        let along = rng.uniform(20, 80)
        let radius = 12 - 6 * along / 96                             // the flipper tapers 12 → 6
        let off = Double(CthTableLayout.ballRadius) + radius + 2
        var x = Double(p.x) + along * cos(rest) + off * sin(rest)
        let y = Double(p.y) - along * sin(rest) + off * cos(rest)
        var a = rng.uniform(20, 160) * .pi / 180
        let s = rng.uniform(250, 950)
        if !left {
            x = Double(CthTableLayout.mirrorSum) - x
            a = .pi - a
        }
        return Launch(family: "flipper", side: left ? "left" : "right", x: x, y: y, vx: s * cos(a), vy: s * sin(a))
    }

    var progressText: String {
        guard index < plan.count else { return "SLING LAB DONE" }
        return "SLING LAB \(index + 1)/\(plan.count) · \(Self.variants[plan[index].variant].name.uppercased())"
    }

    /// A sling kicked the ball (from the scene's contact handler). `sling` 0 = left, 1 = right.
    func kick(sling: Int, ballAt p: CGPoint, now: TimeInterval) {
        guard var trial = current, let start = startedTrialAt, currentVariant >= 0 else { return }
        let v = Self.variants[currentVariant]
        let s = sling == 0 ? v.leftSling : v.rightSling
        let d = CGVector(dx: s.top.x - s.tip.x, dy: s.top.y - s.tip.y)
        let len2 = max(d.dx * d.dx + d.dy * d.dy, 0.001)
        let f = ((p.x - s.tip.x) * d.dx + (p.y - s.tip.y) * d.dy) / len2
        trial.kicks.append(Kick(sling: sling == 0 ? "left" : "right",
                                along: (Double(f) * 1000).rounded() / 1000,
                                seconds: ((now - start) * 1000).rounded() / 1000))
        current = trial
    }

    /// Runs the robot. Returns false when every trial is done.
    func update(now: TimeInterval) -> Bool {
        frames += 1
        if startedAt == nil { startedAt = CACurrentMediaTime() }
        guard index < plan.count else { return false }
        let step = plan[index]

        guard let start = startedTrialAt else {
            host.slingLabResetTable()
            if step.variant != currentVariant {
                currentVariant = step.variant
                host.slingLabSetSlings(Self.variants[step.variant])
            }
            let l = launches[step.launch]
            host.slingLabLaunch(at: CGPoint(x: l.x, y: l.y), velocity: CGVector(dx: l.vx, dy: l.vy))
            current = Trial(launch: step.launch, variant: Self.variants[step.variant].name)
            startedTrialAt = now
            return true
        }

        guard let ball = host.slingLabBall else {
            finish("timeout", seconds: now - start)
            return index < plan.count
        }
        let p = ball.position
        if p.y < Self.outlaneTopY && p.x < CthTableLayout.laneGuideX {
            finish("outlaneLeft", seconds: now - start)
        } else if p.y < Self.outlaneTopY && p.x > CthTableLayout.mirrorSum - CthTableLayout.laneGuideX
                    && p.x < CthTableLayout.laneWallX {
            finish("outlaneRight", seconds: now - start)
        } else if touchesFlipper(p) {
            finish("flipper", seconds: now - start)
        } else if p.y < Self.drainY {
            finish("drain", seconds: now - start)
        } else if p.y > Self.upfieldY {
            finish("upfield", seconds: now - start)
        } else if now - start > Self.timeout {
            finish("timeout", seconds: now - start)
        }
        return index < plan.count
    }

    /// The ball is touching (or within 2 pt of) either lowered main flipper.
    private func touchesFlipper(_ p: CGPoint) -> Bool {
        let rest = CthTableLayout.flipperRestAngle
        let len = CthTableLayout.flipperLength
        let r0 = CthTableLayout.flipperPivotRadius, r1 = CthTableLayout.flipperTipRadius
        for (pivot, dir) in [(CthTableLayout.leftFlipperPivot, CGVector(dx: cos(rest), dy: -sin(rest))),
                             (CthTableLayout.rightFlipperPivot, CGVector(dx: -cos(rest), dy: -sin(rest)))] {
            let t = max(0, min(len, (p.x - pivot.x) * dir.dx + (p.y - pivot.y) * dir.dy))
            let q = CGPoint(x: pivot.x + dir.dx * t, y: pivot.y + dir.dy * t)
            let reach = CthTableLayout.ballRadius + r0 + (r1 - r0) * t / len + 2
            if hypot(p.x - q.x, p.y - q.y) <= reach { return true }
        }
        return false
    }

    private func finish(_ outcome: String, seconds: Double) {
        if var trial = current {
            trial.outcome = outcome
            trial.seconds = (seconds * 1000).rounded() / 1000
            trials.append(trial)
        }
        current = nil
        startedTrialAt = nil
        index += 1
    }

    /// Saves next to the Shot Lab's results (~/Documents/GreyInvasionPinball/ShotLab on the Mac from the
    /// Simulator). Returns the file name, or an error.
    func save() -> String {
        let real = CACurrentMediaTime()
        let fps = startedAt.map { real > $0 ? Double(frames) / (real - $0) : 0 } ?? 0
        let stamp = ISO8601DateFormatter().string(from: Date())
        var degrees: [String: Double] = [:]
        for v in Self.variants { degrees[v.name] = v.kickDegrees }
        let results = Results(table: "Cthulhu Rising (slings)", date: stamp, fps: (fps * 10).rounded() / 10,
                              physicsSpeed: Self.physicsSpeed, variants: Self.variants, kickDegrees: degrees,
                              launches: launches, trials: trials)
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
        let name = "slinglab-cthulhu-rising-" + stamp.replacingOccurrences(of: ":", with: "-") + ".json"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(name)
            try data.write(to: url)
            print("SLING LAB: saved \(trials.count) trials to \(url.path)")
            return name
        } catch {
            print("SLING LAB: save failed: \(error)")
            return "save failed"
        }
    }
}

/// A tiny seeded random generator (SplitMix64), so every run throws the same balls.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// Uniform in lo…hi.
    mutating func uniform(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * Double(next() >> 11) / Double(1 << 53)
    }
}
#endif
