import CoreGraphics
import SpriteKit
import UIKit
import Foundation

// Pinball Lab Table 03 (Cthulhu Rising, Oct 2026). Every Table 03 type is prefixed "Cth" (the app bundle is
// flat, and Grey Invasion already uses the plain names). Milestone 1: Grey Invasion's proven lower table,
// copied as it is; the top of the table is built in milestone 3.

/// All Table 03 geometry in world points. SpriteKit's origin is bottom-left.
/// Same 600 x 1300 world, radius-9 ball and physics as Grey Invasion (see TableLayout.swift for why
/// each number is what it is; every value here was proven on device there).
enum CthTableLayout {
    static let worldSize = CGSize(width: 600, height: 1300)

    // MARK: Physics
    static let gravity: CGFloat = -9.2
    static let ballRadius: CGFloat = 9
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1
    static let maxBallSpeed: CGFloat = 2460
    static let wallRestitution: CGFloat = 0.3
    static let wallFriction: CGFloat = 0.1
    static let railRestitution: CGFloat = 0.15
    static let railFriction: CGFloat = 0.02

    // MARK: Art (milestone 2)
    /// The oblique view the art is drawn in (tools/cth_layout.py): a point at height z appears z × this
    /// farther up the table (tan 22°). The floor lines up exactly with the physics.
    static let oblique: CGFloat = 0.4040
    /// The world rectangle the baked lower-table image covers (tools/cth_render_lower.py, 3 px per point).
    static let lowerArtRect = CGRect(x: -40, y: -75, width: 680, height: 600)
    /// Milestone 8: the upper table's baked art (cth_upper.png, from the same Blender scene as cth_lower).
    static let upperArtRect = CGRect(x: -40, y: 525, width: 680, height: 805)
    /// Art round 2b (T3 M8 v5): rendered part sprites (tools/cth_render_parts2.py). Each rect is the sprite's box in
    /// points around the part's physics centre (x0, y0, width, height); the anchor point is (-x0/w, -y0/h).
    static let bumperArtBox = CGRect(x: -40, y: -48, width: 96, height: 100)
    static let targetArtBox = CGRect(x: -16, y: -24, width: 42, height: 58)
    static let spinnerArtBox = CGRect(x: -22, y: -10, width: 44, height: 32)
    static let spinnerFrames = (columns: 6, rows: 4)
    static let magnetArtBox = CGRect(x: -20, y: -20, width: 46, height: 42)
    /// Art round 3 (T3 M8 v9): the right ramp and the Library wire, one sprite in world coordinates
    /// (tools/cth_render_ramps.py prints this box), placed at the origin over the floor balls.
    static let rampArtRect = CGRect(x: 53, y: 467, width: 519, height: 503)
    /// Art round 4 (T3 M8 v10): Cthulhu (tools/cth_render_cthulhu.py, 6 px/pt). The head's box is round the physics
    /// centre; each tentacle's box is round its own base. Bases: angle from straight down the table (+ = toward +x)
    /// in degrees, and distance from the centre; tentacle 2 is the raised one behind his head.
    static let cthulhuArtBox = CGRect(x: -30, y: -33, width: 72, height: 64)
    static let tentacleArtBoxes = [
        CGRect(x: -30, y: -11, width: 38, height: 24),
        CGRect(x: -30, y: -19, width: 40, height: 28),
        CGRect(x: -17, y: -11, width: 33, height: 52),
        CGRect(x: -6, y: -19, width: 37, height: 28),
        CGRect(x: -3, y: -11, width: 35, height: 24),
    ]
    static let tentacleBases: [(degrees: CGFloat, distance: CGFloat)] = [(-80, 19), (-45, 19), (180, 12), (45, 19), (80, 19)]
    /// Where his eyes draw, round the physics centre (the render's eyes at height 14.5, leaned).
    static let cthulhuEyes = [CGPoint(x: -5.8, y: -8.3), CGPoint(x: 5.8, y: -8.3)]
    /// Art round 5a (T3 M8 v11, tools/cth_render_parts3.py): the upper flipper's own render (box round its pivot,
    /// pointing -x) and the two gates, each rendered in place at its closed angle (box round its hinge).
    static let upperFlipperArtBox = CGRect(x: -76, y: -15, width: 91, height: 30)
    static let topGateArtBox = CGRect(x: -6, y: -48, width: 18, height: 59)
    static let launchGateArtBox = CGRect(x: -35, y: -37, width: 47, height: 48)
    /// The painted candle flames under the Candle lanes (tools/cth_floor_table.py): the lane lights.
    static let candleFlameY: CGFloat = 1156

    /// A sprite placed by its art box (size + anchor), or nil when the image isn't in the app (grey box then).
    static func artSprite(_ name: String, box: CGRect) -> SKSpriteNode? {
        guard UIImage(named: name) != nil else { return nil }
        let s = SKSpriteNode(imageNamed: name)
        s.size = box.size
        s.anchorPoint = CGPoint(x: -box.minX / box.width, y: -box.minY / box.height)
        return s
    }

    // MARK: Walls
    static let leftWallX: CGFloat = 20
    static let rightWallX: CGFloat = 580
    static let laneWallX: CGFloat = 548
    static let laneFloorY: CGFloat = 40
    static let archStartY: CGFloat = 1000
    static let topY: CGFloat = 1270
    static let apronTopY: CGFloat = 185
    static let drainEdgeX: CGFloat = 250
    static let drainEdgeY: CGFloat = 105
    static let drainLipY: CGFloat = 85
    static let leftBulgeBottom: CGFloat = 540
    static let leftBulgeTop: CGFloat = 780
    static let leftBulgeControlInset: CGFloat = 36
    static let rightBulgeBottom: CGFloat = 540
    static let rightBulgeTop: CGFloat = 780
    static let rightBulgeControlInset: CGFloat = 36
    static var laneCenterX: CGFloat { (laneWallX + rightWallX) / 2 }
    static var playfieldCenterX: CGFloat { (leftWallX + laneWallX) / 2 }

    // MARK: Flippers
    static let leftFlipperPivot = CGPoint(x: 179, y: 220)
    static let rightFlipperPivot = CGPoint(x: 389, y: 220)
    static let flipperLength: CGFloat = 96
    static let flipperPivotRadius: CGFloat = 12
    static let flipperTipRadius: CGFloat = 6
    static let flipperRestAngle: CGFloat = .pi / 6
    static let flipperTravel: CGFloat = .pi / 3
    static let flipperUpSpeed: CGFloat = 25.5
    static let flipperDownSpeed: CGFloat = 14
    static let flipperMass: CGFloat = 2
    static let flipperFriction: CGFloat = 0.4

    static var leftGuideEnd: CGPoint {
        let r = flipperPivotRadius + 1
        return CGPoint(x: leftFlipperPivot.x + r * sin(flipperRestAngle),
                       y: leftFlipperPivot.y + r * cos(flipperRestAngle))
    }

    // MARK: Plunger
    static let plungerSize = CGSize(width: 24, height: 50)
    static let plungerRestTop: CGFloat = 120
    static var plungerRestPosition: CGPoint {
        CGPoint(x: laneCenterX, y: plungerRestTop - plungerSize.height / 2)
    }
    static let plungerMaxPull: CGFloat = 60
    static let minLaunchSpeed: CGFloat = 1080
    static let maxLaunchSpeed: CGFloat = 2310
    static let tapLaunchPower: CGFloat = 0.6
    static let plungerZoneMinX: CGFloat = 0.62
    static let plungerZoneMinY: CGFloat = 0.55

    // MARK: Launch lane gate
    static let laneWallTop: CGFloat = 955
    static var gateLow: CGPoint { CGPoint(x: laneWallX, y: laneWallTop) }
    static var gateHigh: CGPoint { CGPoint(x: rightWallX, y: laneWallTop + 28) }
    /// T3 M8 v3: a ball crossing the launch gate going up swings its flap open.
    static var launchGateSwitch: CthRampSwitch {
        CthRampSwitch(a: gateLow, b: gateHigh, forward: CGVector(dx: 0, dy: 1))
    }

    // MARK: Lower table: inlanes, outlanes, slingshots (left shown; right mirrors about x 284)
    static let mirrorSum: CGFloat = leftWallX + laneWallX   // 568
    static func mirrored(_ p: CGPoint) -> CGPoint { CGPoint(x: mirrorSum - p.x, y: p.y) }

    static let laneGuideX: CGFloat = 54
    static let laneGuideTop: CGFloat = 470
    static let laneGuideBend: CGFloat = 330
    static var leftLaneGuide: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd]
    }
    static var rightLaneGuide: [CGPoint] { leftLaneGuide.map { mirrored($0) } }

    static let leftSling = (top: CGPoint(x: 88, y: 450),
                            corner: CGPoint(x: 88, y: 347),
                            tip: CGPoint(x: 150, y: 300.4))
    static var rightSling: (top: CGPoint, corner: CGPoint, tip: CGPoint) {
        (mirrored(leftSling.top), mirrored(leftSling.corner), mirrored(leftSling.tip))
    }
    static let slingKickSpeed: CGFloat = 920
    /// T3 M2 v2 (Aaron: the rubber should fill more of the long side): the face kicks from just past the
    /// tip post to just short of the top post (face 162 pt; posts take ~4% at each end). Grey Invasion
    /// used 12%–75% because a kick right up to the top corner drained balls there; watch for that here.
    static let slingKickFrom: CGFloat = 0.06
    static let slingKickTo: CGFloat = 0.94
    static let slingTopPostRadius: CGFloat = 7
    static let slingTipPostRadius: CGFloat = 6
    /// A dead post at the third (outer) corner too, matching the art's post and ring.
    static let slingCornerPostRadius: CGFloat = 5.5
    static let slingPostRestitution: CGFloat = 0.1

    /// The right apron: from the plunger-lane wall down to the right side of the drain chute.
    static var rightApron: [CGPoint] {
        [CGPoint(x: laneWallX, y: apronTopY),
         CGPoint(x: mirrorSum - drainEdgeX, y: drainEdgeY),
         CGPoint(x: mirrorSum - drainEdgeX, y: drainLipY)]
    }
    static let outlaneWallBottom: CGFloat = 215
    static var leftOutlaneWall: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideBend), CGPoint(x: laneGuideX, y: outlaneWallBottom)]
    }
    static var rightOutlaneWall: [CGPoint] { leftOutlaneWall.map { mirrored($0) } }

    // MARK: Top of the table (milestone 3) — Grey Invasion's proven top, unless noted.
    // Checked in tools/cth_render_m3.py (gap checks + shot sweeps).

    /// Orbit: a lane up the left side (x 20…58) following the arch; its entrance is a funnel facing the
    /// right flipper (~6.6° of aim measured; better than Grey Invasion's, with no left ramp mouth beside it).
    static let orbitInnerX: CGFloat = 58
    static let orbitFunnelTip = CGPoint(x: 112, y: 800)
    static let orbitFunnelBendY: CGFloat = 890
    static let orbitInnerEndX: CGFloat = 190
    static var orbitInnerWall: [CGPoint] {
        let innerTop = topY - (orbitInnerX - leftWallX)
        let arc = quadCurve(from: CGPoint(x: orbitInnerX, y: archStartY),
                            control: CGPoint(x: orbitInnerX, y: innerTop),
                            to: CGPoint(x: worldSize.width / 2, y: innerTop),
                            segments: 32)
        return [orbitFunnelTip, CGPoint(x: orbitInnerX, y: orbitFunnelBendY), CGPoint(x: orbitInnerX, y: archStartY)]
            + arc.filter { $0.x <= orbitInnerEndX }
    }
    /// T3 M8 v2 (Aaron: the blinking diverter line "doesn't feel like a natural pinball element"): the top right
    /// is now a lane, a curved wall 38 pt inside the arch (as wide as the orbit lane) running from the top of the
    /// shooter lane round to x ≈ 400, with a one-way gate across its mouth. A plunge (moving left) swings the gate
    /// open and carries on along the arch; an orbit shot coming round (moving right) is stopped by it and drops
    /// back into the lanes and bumpers, as the diverter did. Physics: the gate is the per-ball diverter edge
    /// (solid only for a ball moving right); the flap's swing is drawn.
    static func archRightPoint(_ t: CGFloat) -> CGPoint {
        let p0 = CGPoint(x: worldSize.width / 2, y: topY), c = CGPoint(x: rightWallX, y: topY)
        let p1 = CGPoint(x: rightWallX, y: archStartY)
        let u = 1 - t
        return CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x, y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
    }
    /// A point `inset` inside the right half of the arch (along its inward normal).
    static func archRightInner(_ t: CGFloat, inset: CGFloat) -> CGPoint {
        let p0 = CGPoint(x: worldSize.width / 2, y: topY), c = CGPoint(x: rightWallX, y: topY)
        let p1 = CGPoint(x: rightWallX, y: archStartY)
        let u = 1 - t
        var dx = 2 * u * (c.x - p0.x) + 2 * t * (p1.x - c.x)
        var dy = 2 * u * (c.y - p0.y) + 2 * t * (p1.y - c.y)
        let l = max(hypot(dx, dy), 0.001); dx /= l; dy /= l
        let p = archRightPoint(t)
        return CGPoint(x: p.x + dy * inset, y: p.y - dx * inset)
    }
    static let topLaneWidth: CGFloat = 38
    static let topGateT: CGFloat = 0.187             // the hinge on the arch, x ≈ 395
    static let topLaneStartT: CGFloat = 0.217        // the gate's free end / where the curved wall starts
    static var topGateHinge: CGPoint { archRightPoint(topGateT) }                                  // ≈ (395, 1261)
    static var topGateEnd: CGPoint { archRightInner(topLaneStartT, inset: topLaneWidth) }         // ≈ (399, 1221)
    /// The curved inner wall of the top-right lane, from the gate down to (542, 1000) above the shooter lane.
    static var topLaneWall: [CGPoint] {
        (0...24).map { k in
            archRightInner(topLaneStartT + (1 - topLaneStartT) * CGFloat(k) / 24, inset: topLaneWidth)
        }
    }
    /// A ball crossing the gate going left (a plunge) swings the flap open.
    static var topGateSwitch: CthRampSwitch {
        CthRampSwitch(a: topGateHinge, b: topGateEnd, forward: CGVector(dx: -1, dy: 0))
    }
    /// Orbit switches: armed crossing the lower one going up, made crossing the top one going right.
    static let orbitArmSwitch = CthRampSwitch(a: CGPoint(x: leftWallX, y: 990), b: CGPoint(x: orbitInnerX, y: 990),
                                              forward: CGVector(dx: 0, dy: 1))
    static let orbitMadeSwitch = CthRampSwitch(a: CGPoint(x: 200, y: 1205), b: CGPoint(x: 200, y: 1265),
                                               forward: CGVector(dx: 1, dy: 0))
    /// NEW: where the spinner goes, across the orbit lane above the funnel (it spins in milestone 4).
    static let spinnerLine = (a: CGPoint(x: leftWallX, y: 935), b: CGPoint(x: orbitInnerX, y: 935))
    /// The same line as a switch (either direction spins it).
    static let spinnerSwitch = CthRampSwitch(a: spinnerLine.a, b: spinnerLine.b, forward: CGVector(dx: 0, dy: 1))

    /// Candle lanes: 3 lanes 36 wide between 4 thin posts, under the top of the arch.
    static let lanePostXs: [CGFloat] = [220, 256, 292, 328]
    static let lanePostBottom: CGFloat = 1130
    static let lanePostTop: CGFloat = 1185
    static let laneSensorY: CGFloat = 1150
    static let laneLightY: CGFloat = 1205
    static let laneSensorSize = CGSize(width: 28, height: 10)
    static var laneCenterXs: [CGFloat] {
        zip(lanePostXs, lanePostXs.dropFirst()).map { ($0 + $1) / 2 }
    }

    /// Pop bumpers: an open triangle fed by the lanes (gaps ~4 balls).
    static let bumperRadius: CGFloat = 28
    static let bumperCenters: [CGPoint] = [
        CGPoint(x: 210, y: 1050),
        CGPoint(x: 338, y: 1050),
        CGPoint(x: 274, y: 950),
    ]
    static let bumperKickSpeed: CGFloat = 1150

    // Right ramp (the Chant ramp): Grey Invasion's right ramp. Shot from the left flipper (~5.9°);
    // the wire drops into the top of the right inlane.
    static let rampMouth = CGPoint(x: 360, y: 600)
    static let rampMouthHalfWidth: CGFloat = 30
    static let rampHalfWidth: CGFloat = 16
    static let rampFlareLength: CGFloat = 70
    static let rampPostLength: CGFloat = 24
    /// T3 M8 v7: the ramp's low end, solid for floor balls (sides + back) for this far up from the mouth; beyond it
    /// the ramp is high enough for a floor ball to roll underneath.
    static let rampLowLength: CGFloat = 80
    static let rampEntryDistance: CGFloat = 12
    static let rampMadeAfterApex: CGFloat = 10
    static let rampExitBeforeEnd: CGFloat = 15
    static let rampFriction: CGFloat = 0.05
    static let rampRestitution: CGFloat = 0.1
    static let rampReturnMaxSpeed: CGFloat = 700
    /// Art round 3: how high the ramps' running surface is (tools/cth_layout.py ramp_height draws them the same way).
    /// It rises from the floor over `rampRiseLength` (a quarter sine) to `rampTopHeight`, holds to the apex, then
    /// falls in a straight line to the end height. The ball is drawn lifted and a little bigger by its height.
    static let rampTopHeight: CGFloat = 40
    static let rampRiseLength: CGFloat = 110
    static let rampEndHeight: CGFloat = 12
    static let wireEndHeight: CGFloat = 10
    /// Juice round 2: the Awakening drone's volume relative to the sound setting (it sits under the effects).
    static let awakeningDroneGain: Float = 0.7

    static func rightRampPath() -> (path: CthRampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))
        var p = CthRampPath(start: rampMouth, heading: climb)
        p.line(hypot(90, 260))
        p.arc(radius: 36, turn: -(climb + .pi / 2))
        let apex = p.length
        p.line(248)
        let bend = acos(1 - CGFloat(23) / CGFloat(120))
        p.arc(radius: 60, turn: -bend)
        p.arc(radius: 60, turn: bend)
        p.line(40)
        return (p, apex)
    }

    // Kick-out holes
    static let scoopRadius: CGFloat = 15
    static let scoopCaptureRadius: CGFloat = 18
    static let scoopHold: TimeInterval = 1.0
    static let scoopRecapture: TimeInterval = 0.6
    /// The Library: on Grey Invasion's Hangar spot, which the Shot Lab tuned (~65% from a cradled ball,
    /// either flipper). In milestone 3 it kicks out like the Hangar did (onto the left flipper); the
    /// up-kicker and its wire come in milestone 4.
    static let libraryCenter = CGPoint(x: 284, y: 650)
    static let libraryEject = CGVector(dx: -100, dy: -480)   // unused since the up-kicker (kept for the grey box)

    /// Milestone 4 round 2: the up-kicker's wire. From the Library it climbs up-left (the angle of Grey
    /// Invasion's left ramp), turns over the top at r 36, runs down the left side at x ≈ 124, S-bends onto the
    /// left inlane's centre line and drops the ball straight down into it at y 490 (Grey Invasion's left-ramp
    /// release). Checked in tools/cth_render_m3.py. It's a wire-only CthRamp: no floor entry, no mouth posts.
    static let leftInlaneCenterX: CGFloat = 69
    static let wireReleaseY: CGFloat = 490
    static func libraryWirePath() -> (path: CthRampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))      // ~71°, so the climb heads up-left at ~109°
        var p = CthRampPath(start: libraryCenter, heading: .pi - climb)
        p.line(hypot(90, 260))                            // up to (194, 910)
        p.arc(radius: 36, turn: climb + .pi / 2)          // over the top, ends heading straight down at x ≈ 124
        let apex = p.length
        p.line(200)                                       // down the left side to y ≈ 698
        let shift = leftInlaneCenterX - p.points[p.points.count - 1].x
        if abs(shift) > 0.5 {
            let bend = acos(1 - min(abs(shift), 119) / 120)
            let turn = shift > 0 ? bend : -bend
            p.arc(radius: 60, turn: turn)
            p.arc(radius: 60, turn: -turn)
        }
        p.line(max(p.points[p.points.count - 1].y - wireReleaseY, 20))
        return (p, apex)
    }
    /// The up-kicker fires the ball onto the wire at this speed, this far along it (a climb of 260 pt needs
    /// at least ~850 pt/s under the table's gravity).
    static let upKickerSpeed: CGFloat = 1150
    static let upKickerStart: CGFloat = 20
    static let upKickerHold: TimeInterval = 0.6
    /// NEW: the Lagoon, top right of the nest, where Cthulhu rises. Shot from the upper flipper (~8°) and
    /// the right flipper (~2.7°); kicks the ball down-right onto the upper flipper.
    /// T3 M5 v2 (Shot Lab runs 1–2): the Lagoon was far too easy (98% from the upper flipper, 77% from the left
    /// for an average player; target 25–50%) and its kick-out fed the upper flipper, a near-endless loop.
    /// Now: 12 pt right (so Cthulhu's wider sway keeps 1.5 balls from the right bumper), a tighter catch
    /// (14, was 18), and it spits the ball left across the top into the bumper nest instead.
    static let lagoonCenter = CGPoint(x: 452, y: 1030)
    static let lagoonCaptureRadius: CGFloat = 14
    static let lagoonEject = CGVector(dx: -260, dy: 60)

    /// The ritual circle (lamps in milestone 6) with the magnet at its centre (milestone 4).
    static let ritualCenter = CGPoint(x: 284, y: 470)
    static let ritualRadius: CGFloat = 40

    /// Milestone 4 round 3: the magnet at the centre of the ritual circle. A floor ball within pullRadius is
    /// pulled toward the centre (magnetPull × (1 − distance / pullRadius), pt/s²); one that gets within
    /// grabRadius slower than grabMaxSpeed is caught, held, then flung upward (40°–140°). Until the rules
    /// milestone it re-arms itself magnetCooldown seconds after each fling (and magnetFirstArm into a game).
    static let magnetPullRadius: CGFloat = 44
    static let magnetGrabRadius: CGFloat = 9
    static let magnetGrabMaxSpeed: CGFloat = 900
    static let magnetPull: CGFloat = 5000
    static let magnetHold: TimeInterval = 1.2
    static let magnetFlingSpeed: CGFloat = 1150
    static let magnetCooldown: TimeInterval = 8
    static let magnetFirstArm: TimeInterval = 3

    // Sigil bank: Grey Invasion's target bank (four drop targets facing the left flipper, ~8–11° of aim).
    static let dropTargetSize = CGSize(width: 12, height: 24)
    static let dropTargetX: CGFloat = 464
    static let dropTargetYs: [CGFloat] = [595, 565, 535, 505]
    static let dropTargetResetDelay: TimeInterval = 1.0
    static let sigilBankBackWall = [CGPoint(x: 476, y: 487), CGPoint(x: 476, y: 621)]
    static let sigilBankCap = [CGPoint(x: 476, y: 621), CGPoint(x: 454, y: 613)]

    // Upper flipper: Grey Invasion's, on the right wall under the ramp's wire, on the right button.
    static let upperFlipperPivot = CGPoint(x: 528, y: 800)
    static let upperFlipperLength: CGFloat = 64
    static let upperFlipperPivotRadius: CGFloat = 10
    static let upperFlipperTipRadius: CGFloat = 5
    static let upperFlipperGuideTrim: CGFloat = 0.33
    static var upperFlipperGuide: [CGPoint] {
        let r = upperFlipperPivotRadius + 1
        let full = CGPoint(x: upperFlipperPivot.x - r * sin(flipperRestAngle),
                           y: upperFlipperPivot.y + r * cos(flipperRestAngle))
        let wall = CGPoint(x: laneWallX, y: full.y + (laneWallX - full.x) * tan(flipperRestAngle))
        let t = upperFlipperGuideTrim
        let end = CGPoint(x: full.x + (wall.x - full.x) * t, y: full.y + (wall.y - full.y) * t)
        return [wall, end]
    }

    // MARK: Lamps (milestone 6 round 1). Arrows sit on each shot's line from the flipper that shoots it,
    // 56–90 pt in front of the shot (Grey Invasion's proven spots where the shot is the same).
    /// name → (position, angle in radians). Arrows are 24 x 18.
    static let shotArrows: [String: (CGPoint, CGFloat)] = [
        "rightRamp": (CGPoint(x: 336.3, y: 532), 70.8 * .pi / 180),     // from the left flipper (GI)
        "orbit": (CGPoint(x: 121.4, y: 722.7), 113.8 * .pi / 180),      // from the right flipper (GI)
        "library": (CGPoint(x: 284, y: 582), .pi / 2),                  // GI's Hangar arrow (same spot)
        "sigil": (CGPoint(x: 411.1, y: 493.2), 54.3 * .pi / 180),       // from the left flipper (GI)
        "lagoon": (CGPoint(x: 467, y: 962), 102.6 * .pi / 180),         // from the upper flipper, 70 pt short
    ]
    /// Three tomes (Act 1, research): a row between the Library arrow and the hole.
    static let tomeLamps: [CGPoint] = [CGPoint(x: 260, y: 615), CGPoint(x: 284, y: 615), CGPoint(x: 308, y: 615)]
    static let tomeLampRadius: CGFloat = 6
    /// Five ritual candles (Act 2) on a pentagram round the magnet: radius 54 from the ritual centre,
    /// the first straight up, then clockwise.
    static var candleLamps: [CGPoint] {
        (0..<5).map { i in
            let a = CGFloat.pi / 2 - CGFloat(i) * 2 * .pi / 5
            return CGPoint(x: ritualCenter.x + 54 * cos(a), y: ritualCenter.y + 54 * sin(a))
        }
    }
    static let candleLampRadius: CGFloat = 7
    /// Three Cthulhu hits (Act 3): an arc over the Lagoon.
    static let cthulhuLamps: [CGPoint] = [CGPoint(x: 430, y: 1070), CGPoint(x: 452, y: 1076), CGPoint(x: 474, y: 1070)]
    static let cthulhuLampRadius: CGFloat = 5
    /// Four tentacles (the Awakening, M7 v4): an arc under the Lagoon, above the Lagoon arrow.
    static let tentacleLamps: [CGPoint] = [CGPoint(x: 414, y: 996), CGPoint(x: 438, y: 989),
                                           CGPoint(x: 466, y: 989), CGPoint(x: 490, y: 996)]
    static let tentacleLampRadius: CGFloat = 5
    /// The Awakening's three-ball multiball: ball save for its first 25 s (M7 v5, simulator; was 15).
    static let awakeningBallSaveSeconds: TimeInterval = 25
    static let awakeningBalls = 3
    /// Lamps over the inserts painted into the lower art (tools/cth_floor_lower.py; same shapes and spots).
    static let inlaneArrowLeft = CGPoint(x: 71, y: 410)            // 26 x 16, pointing up
    static let flipperArrowLeft = CGPoint(x: 118, y: 286)          // 18 x 11, -36°
    static let kickbackLamp = CGPoint(x: 37, y: 300)               // r 9
    static let elderSign = CGPoint(x: 284, y: 312)                 // star 20 / 8.5 (ball save)

    // MARK: Carried-over rules (milestone 7 round 1), Grey Invasion's numbers
    /// Kickback in the left outlane: a ball centre left of this, below the trigger line, moving down…
    static let kickbackMaxX: CGFloat = 60
    static let kickbackTriggerY: CGFloat = 240
    /// …is fired straight back up the outlane (clears the lane guide top with room to spare).
    static let kickbackSpeed: CGFloat = 1500
    /// A ball crossing this line going DOWN inside the right outlane is on its way to the drain (marks
    /// an outlane-save drain; with the apron every ball leaves through the centre drain).
    static let rightOutlaneSwitch = CthRampSwitch(a: CGPoint(x: 514, y: 240), b: CGPoint(x: laneWallX, y: 240),
                                                  forward: CGVector(dx: 0, dy: -1))
    /// Elder Sign (ball save): armed while the ball waits on the plunger and for 10 s after launch, once
    /// per player ball; its lamp fast-blinks for the last 3 s.
    static let elderSignSeconds: TimeInterval = 10
    static let elderSignWarning: TimeInterval = 3
    static let skillShotWindow: TimeInterval = 5         // the first Candle lane within 5 s of launch
    static let bannerSeconds: TimeInterval = 1.6
    /// End-of-ball bonus: shots made this ball × 1,000 + spinner spins × 20, × the multiplier. Shots = the
    /// right ramp, orbit, Library, Lagoon and a full Sigil bank.
    static let bonusPerShot = 1_000
    static let bonusPerSpin = 20
    static let bonusCountSeconds: TimeInterval = 1.2
    static let bonusHoldSeconds: TimeInterval = 1.0
    /// The Ritual (M7 v3): the second ball comes up out of the Library 1 s after the catch, and for the first
    /// 10 s of the multiball every drained ball is re-fired from the Library.
    static let ritualReleaseDelay: TimeInterval = 1.0
    static let ritualBallSaveSeconds: TimeInterval = 10

    // MARK: Rules (milestone 3: placeholder points until the rules milestone)
    static let ballsPerGame = 3

    /// One continuous wall: left wall (with the bulge) → arched top → right wall → plunger lane
    /// floor → inner plunger lane wall (also the outside of the right outlane, with its own bulge).
    static var outerWall: [CGPoint] {
        var points: [CGPoint] = [
            CGPoint(x: drainEdgeX, y: drainLipY),
            CGPoint(x: drainEdgeX, y: drainEdgeY),
            CGPoint(x: leftWallX, y: apronTopY),
            CGPoint(x: leftWallX, y: leftBulgeBottom),
        ]
        points += quadCurve(from: CGPoint(x: leftWallX, y: leftBulgeBottom),
                            control: CGPoint(x: leftWallX + leftBulgeControlInset,
                                             y: (leftBulgeBottom + leftBulgeTop) / 2),
                            to: CGPoint(x: leftWallX, y: leftBulgeTop))
        points.append(CGPoint(x: leftWallX, y: archStartY))
        let midX = worldSize.width / 2
        points += quadCurve(from: CGPoint(x: leftWallX, y: archStartY),
                            control: CGPoint(x: leftWallX, y: topY),
                            to: CGPoint(x: midX, y: topY))
        points += quadCurve(from: CGPoint(x: midX, y: topY),
                            control: CGPoint(x: rightWallX, y: topY),
                            to: CGPoint(x: rightWallX, y: archStartY))
        points += [
            CGPoint(x: rightWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: rightBulgeBottom),
        ]
        points += quadCurve(from: CGPoint(x: laneWallX, y: rightBulgeBottom),
                            control: CGPoint(x: laneWallX - rightBulgeControlInset,
                                             y: (rightBulgeBottom + rightBulgeTop) / 2),
                            to: CGPoint(x: laneWallX, y: rightBulgeTop))
        points.append(CGPoint(x: laneWallX, y: laneWallTop))
        return points
    }

    /// Samples a quadratic Bézier into straight segments so it works as an edge chain.
    static func quadCurve(from p0: CGPoint, control c: CGPoint, to p1: CGPoint,
                          segments: Int = 16) -> [CGPoint] {
        (1...segments).map { i in
            let t = CGFloat(i) / CGFloat(segments)
            let u = 1 - t
            return CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                           y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
        }
    }
}
