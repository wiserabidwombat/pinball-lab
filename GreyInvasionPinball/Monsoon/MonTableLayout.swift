import CoreGraphics
import SpriteKit
import UIKit
import Foundation

// Pinball Lab Table 04 (Monsoon, Oct 2026). Every Table 04 type is prefixed "Mon" (the app bundle is flat).
// Milestone 1: Table 03's proven lower table, launch gate and top-right lane, copied as they are; the upper
// table (habitrails, captive ball, dust devil) is built from milestone 3 on.

/// All Table 04 geometry in world points. SpriteKit's origin is bottom-left.
/// Same 600 x 1300 world, radius-9 ball and physics as Tables 02 and 03 (see CthTableLayout.swift and
/// TableLayout.swift for why each number is what it is; every value here was proven on device there).
enum MonTableLayout {
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

    // MARK: Art
    /// The oblique view the art is drawn in (Table 03's 22°): a point at height z appears z × this farther up the
    /// table. The floor lines up exactly with the physics.
    static let oblique: CGFloat = 0.4040
    /// Rendered part boxes (none yet; the parts fall back to their grey-box shapes). Kept so the copied parts build.
    static let upperFlipperArtBox = CGRect(x: -76, y: -15, width: 91, height: 30)
    static let topGateArtBox = CGRect(x: -6, y: -48, width: 18, height: 59)
    static let launchGateArtBox = CGRect(x: -35, y: -37, width: 47, height: 48)
    /// Milestone 2: the world rectangle the lower-table art covers (tools/mon_render_lower.py, 3 px per point), and
    /// the same for its sketch and region map (MonPaint mixes them).
    static let lowerArtRect = CGRect(x: -40, y: -75, width: 680, height: 600)
    /// Milestone 9: the upper table's art (world y 525…1330), above the lower art.
    static let upperArtRect = CGRect(x: -40, y: 525, width: 680, height: 805)

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

    // MARK: Launch lane gate (Table 03's one-way flap)
    static let laneWallTop: CGFloat = 955
    static var gateLow: CGPoint { CGPoint(x: laneWallX, y: laneWallTop) }
    static var gateHigh: CGPoint { CGPoint(x: rightWallX, y: laneWallTop + 28) }
    /// A ball crossing the launch gate going up swings its flap open.
    static var launchGateSwitch: MonRampSwitch {
        MonRampSwitch(a: gateLow, b: gateHigh, forward: CGVector(dx: 0, dy: 1))
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
    /// Table 03's rubber: kicks from just past the tip post to just short of the top post.
    static let slingKickFrom: CGFloat = 0.06
    static let slingKickTo: CGFloat = 0.94
    static let slingTopPostRadius: CGFloat = 7
    static let slingTipPostRadius: CGFloat = 6
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
    /// The left outlane post (Play Lab run 3: the left outlane took 31 of 83 drains). A ball that comes up the left
    /// side hits the underside of the captive channel, slides to the wall and drops straight down at x ≈ 47, just
    /// left of the lane guide's top post, so it went down the outlane; 9 of 26 kickbacks came straight back that way.
    /// A short rail from the guide's top post up and left to a second post moves the split point to x 44: those
    /// balls now roll off it to the right. The outlane mouth stays 24 wide (the ball is 18), so balls hugging the
    /// wall still drain, and a kickback (x ≈ 31) still clears it. Checked in a 2D model (tools/mon_outlane_sim.py).
    static let leftOutlanePostTip = CGPoint(x: 44, y: 482)
    static var leftOutlanePostRail: [CGPoint] { [CGPoint(x: laneGuideX, y: laneGuideTop), leftOutlanePostTip] }

    // MARK: Top-right lane and its one-way gate (Table 03's: a plunge swings the gate and rides the arch;
    // a ball coming round the top the other way is stopped and drops back into the playfield).
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
    static var topGateSwitch: MonRampSwitch {
        MonRampSwitch(a: topGateHinge, b: topGateEnd, forward: CGVector(dx: -1, dy: 0))
    }

    // MARK: Upper table (milestone 3, grey box). Table 03's proven top (every shot measured there with the Shot Lab),
    // with its Lagoon and Cthulhu gone: the top right is kept clear for the helix (milestone 4), the left side for the
    // captive ball and the centre for the dust devil (milestone 5). Checked in tools/mon_render_m3.py.

    /// Orbit: a lane up the left side (x 20…58) following the arch; its entrance is a funnel facing the right flipper.
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
    /// Orbit switches: armed crossing the lower one going up, made crossing the top one going right.
    static let orbitArmSwitch = MonRampSwitch(a: CGPoint(x: leftWallX, y: 990), b: CGPoint(x: orbitInnerX, y: 990),
                                              forward: CGVector(dx: 0, dy: 1))
    static let orbitMadeSwitch = MonRampSwitch(a: CGPoint(x: 200, y: 1205), b: CGPoint(x: 200, y: 1265),
                                               forward: CGVector(dx: 1, dy: 0))
    /// The spinner across the orbit lane above the funnel (either direction spins it).
    static let spinnerLine = (a: CGPoint(x: leftWallX, y: 935), b: CGPoint(x: orbitInnerX, y: 935))
    static let spinnerSwitch = MonRampSwitch(a: spinnerLine.a, b: spinnerLine.b, forward: CGVector(dx: 0, dy: 1))
    static let spinnerArtBox = CGRect(x: -22, y: -10, width: 44, height: 32)
    static let spinnerFrames = (columns: 6, rows: 4)
    static let spinnerPoints = 20

    /// Top lanes: 3 lanes 36 wide between 4 thin posts, under the top of the arch, feeding the bumpers.
    static let lanePostXs: [CGFloat] = [220, 256, 292, 328]
    static let lanePostBottom: CGFloat = 1130
    static let lanePostTop: CGFloat = 1185
    static let laneSensorY: CGFloat = 1150
    static let laneLightY: CGFloat = 1205
    static let laneSensorSize = CGSize(width: 28, height: 10)
    /// Where a painted lane light sits (the rollover's painted mode; unused in the grey box).
    static let candleFlameY: CGFloat = 1156
    static var laneCenterXs: [CGFloat] {
        zip(lanePostXs, lanePostXs.dropFirst()).map { ($0 + $1) / 2 }
    }

    /// Pop bumpers (the storm clouds): an open triangle fed by the lanes (gaps ~4 balls).
    static let bumperRadius: CGFloat = 28
    static let bumperCenters: [CGPoint] = [
        CGPoint(x: 210, y: 1050),
        CGPoint(x: 338, y: 1050),
        CGPoint(x: 274, y: 950),
    ]
    static let bumperKickSpeed: CGFloat = 1150
    static let bumperArtBox = CGRect(x: -40, y: -48, width: 96, height: 100)

    /// The mesa ramp and its high wire (milestone 4): Table 03's right ramp climb (shot from the left flipper, ~5.9° of
    /// aim), but at the top it turns LEFT onto a high wire that runs back across the table (gently downhill, heading
    /// 188°), turns down the far left side and drops the ball straight down into the left inlane at y 490 (Table
    /// 03's proven wire release). It rises to 90 pt (the arroyo's low wire is 40) and crosses over the low wire at
    /// about (205, 884), where it is ~67 pt up to the low wire's 40. Checked in tools/mon_render_m4.py.
    static let rampMouth = CGPoint(x: 360, y: 600)
    static let rampMouthHalfWidth: CGFloat = 30
    static let rampHalfWidth: CGFloat = 16
    static let rampFlareLength: CGFloat = 70
    static let rampPostLength: CGFloat = 24
    /// The ramp's low end, solid for floor balls (sides + back) this far up from the mouth.
    static let rampLowLength: CGFloat = 80
    /// The high wire's height profile: up to 90 over the whole climb, then down to 12 at the release.
    static let highWireTopHeight: CGFloat = 90
    static let highWireRiseLength: CGFloat = 275
    static let leftInlaneCenterX: CGFloat = 69
    static var rightInlaneCenterX: CGFloat { mirrorSum - leftInlaneCenterX }    // 499
    static let wireReleaseY: CGFloat = 490
    static func mesaRampPath() -> (path: MonRampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))                 // ~71°, up and to the right
        var p = MonRampPath(start: rampMouth, heading: climb)
        p.line(hypot(90, 260))                                       // the plastic climb, to (450, 860)
        p.arc(radius: 40, turn: .pi - climb + 8 * .pi / 180)         // over the top, turning left to head 188°
        let apex = p.length
        p.line(262)                                                  // back across the table, gently downhill
        p.arc(radius: 40, turn: 82 * .pi / 180)                      // down the far left side
        p.line(150)
        sBend(&p, toX: leftInlaneCenterX)
        p.line(max(p.points[p.points.count - 1].y - wireReleaseY, 20))
        return (p, apex)
    }

    /// The arroyo's up-kicker and its low wire (milestone 4): from the scoop it climbs up-left (Table 03's Library
    /// wire), turns RIGHT over the top (passing under the high wire), runs east across the table (gently downhill,
    /// over the bottom bumper), turns down the right side and drops into the right inlane at y 490.
    static func arroyoWirePath() -> (path: MonRampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))
        var p = MonRampPath(start: arroyoCenter, heading: .pi - climb)  // ~109°, up and to the left
        p.line(hypot(90, 260))                                       // up to (194, 910)
        p.arc(radius: 36, turn: -(.pi - climb) - 8 * .pi / 180)      // over the top, turning right to head -8°
        let apex = p.length
        p.line(250)                                                  // east across the table
        p.arc(radius: 36, turn: -82 * .pi / 180)                     // down the right side (x ≈ 512)
        p.line(150)
        sBend(&p, toX: rightInlaneCenterX)
        p.line(max(p.points[p.points.count - 1].y - wireReleaseY, 20))
        return (p, apex)
    }

    /// M4 round 2: the diverter sits at the top of the mesa ramp's climb (where the high wire turns left). Thrown, it
    /// sends the ball straight on up into the helix instead: it curves to head straight up at x 516, corkscrews 1.5
    /// turns anticlockwise round (468, 1064) (r 48) from 100 pt down to the floor, turns right and drops the ball
    /// at about (375, 1020) heading 200°, into the bumpers (it grazes the bottom one). The helix is ridden on rails.
    static var diverterDistance: CGFloat { hypot(90, 260) }
    static let helixEntryX: CGFloat = 516
    static let helixStartHeight: CGFloat = 90
    static let helixTopHeight: CGFloat = 100
    /// Riding speed on the helix: at least this, speeding up to the max as it corkscrews down.
    static let helixMinSpeed: CGFloat = 450
    static let helixMaxSpeed: CGFloat = 950
    static let helixAcceleration: CGFloat = 500
    static func helixPath() -> (path: MonRampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))
        let (mesa, _) = mesaRampPath()
        let start = mesa.sample(at: diverterDistance).point                  // ≈ (450, 860)
        let r: CGFloat = 80
        var p = MonRampPath(start: start, heading: climb)
        p.line((helixEntryX - start.x - r * (1 - sin(climb))) / cos(climb))
        p.arc(radius: r, turn: .pi / 2 - climb)                              // straight up at x 516, y ≈ 1064
        let apex = p.length
        p.arc(radius: helixRadius, turn: 3 * .pi)                            // the corkscrew: 1.5 turns
        p.arc(radius: 40, turn: -70 * .pi / 180)                             // out to heading 200°
        p.line(20)
        return (p, apex)
    }

    /// Two equal arcs that move a path heading straight down sideways onto `x`.
    private static func sBend(_ p: inout MonRampPath, toX x: CGFloat) {
        let shift = x - p.points[p.points.count - 1].x
        guard abs(shift) > 0.5 else { return }
        let bend = acos(1 - min(abs(shift), 119) / 120)
        let turn = shift > 0 ? bend : -bend
        p.arc(radius: 60, turn: turn)
        p.arc(radius: 60, turn: -turn)
    }
    /// The up-kicker fires the ball onto the low wire at this speed, this far along it (a climb of 260 pt needs at
    /// least ~850 pt/s under the table's gravity).
    static let upKickerSpeed: CGFloat = 1150
    static let upKickerStart: CGFloat = 20
    static let upKickerHold: TimeInterval = 0.6

    /// The arroyo scoop: on Table 03's Library spot (~65% from a cradled ball, either flipper). Its up-kicker puts
    /// the ball on the low wire; the eject velocity is only used if the wire is missing.
    static let arroyoCenter = CGPoint(x: 284, y: 650)
    static let arroyoEject = CGVector(dx: -100, dy: -480)

    /// The saguaro standups: three targets on Table 03's bank spot, facing the left flipper (~8–11° of aim), with a
    /// wall behind them and a sloped cap on top.
    static let standupSize = CGSize(width: 12, height: 24)
    static let standupX: CGFloat = 464
    static let standupYs: [CGFloat] = [590, 560, 530]
    static let standupBankBackWall = [CGPoint(x: 476, y: 487), CGPoint(x: 476, y: 621)]
    static let standupBankCap = [CGPoint(x: 476, y: 621), CGPoint(x: 454, y: 613)]
    /// After the bank is complete it stays lit this long, then clears.
    static let standupResetDelay: TimeInterval = 1.0

    /// Upper flipper: Table 03's, on the right wall under the ramp's wire, on the right button.
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

    /// Milestone 5, the dust devil: a spinning disc in the floor above the flippers (the plan's spot). T4 M5 v1 put it
    /// above the arroyo, but Aaron never reached it ("I hit the arroyo with most shots up the middle"); he chose this
    /// spot, where the ball crosses it on most shots. The calm push only bends slow rolling balls; raging (a mode)
    /// makes centre shots wobble.
    static let dustDevilCenter = CGPoint(x: 284, y: 470)
    static let dustDevilRadius: CGFloat = 44

    /// Milestone 5, the captive ball: a channel on the left side, its mouth facing the right flipper (heading 120°,
    /// up and to the left), 82 long, 21 wide, ending 12 pt off the left wall's bulge (too narrow for a ball). It stays
    /// left of the orbit's shot line from the right flipper.
    static let captiveMouth = CGPoint(x: 100, y: 592)
    static let captiveHeading: CGFloat = 120 * .pi / 180
    static let captiveLength: CGFloat = 82
    static let captiveHalfWidth: CGFloat = 10.5
    /// A guard from the left wall's bulge down onto the channel's top corner, so a ball coming down the wall rolls off
    /// the channel's top to the right instead of resting in the V between the wall and the channel's end.
    static var captiveTopGuard: [CGPoint] {
        let a = CGVector(dx: cos(captiveHeading), dy: sin(captiveHeading))
        let end = CGPoint(x: captiveMouth.x + a.dx * captiveLength, y: captiveMouth.y + a.dy * captiveLength)
        let corner = CGPoint(x: end.x + a.dy * captiveHalfWidth, y: end.y - a.dx * captiveHalfWidth)   // ≈ (68, 668)
        return [CGPoint(x: 36.5, y: 694), corner]                                                      // wall x at y 694
    }
    static let helixCenter = CGPoint(x: 468, y: 1064)
    static let helixRadius: CGFloat = 48

    // MARK: Ramps and holes (used by the copied MonRamp / MonScoop; the upper table's own numbers come in M3–M4)
    static let rampEntryDistance: CGFloat = 12
    static let rampMadeAfterApex: CGFloat = 10
    static let rampExitBeforeEnd: CGFloat = 15
    static let rampFriction: CGFloat = 0.05
    static let rampRestitution: CGFloat = 0.1
    static let rampReturnMaxSpeed: CGFloat = 700
    static let rampTopHeight: CGFloat = 40
    static let rampRiseLength: CGFloat = 110
    static let rampEndHeight: CGFloat = 12
    static let wireEndHeight: CGFloat = 10
    static let scoopRadius: CGFloat = 15
    static let scoopCaptureRadius: CGFloat = 18
    static let scoopHold: TimeInterval = 1.0
    static let scoopRecapture: TimeInterval = 0.6

    // MARK: Rules (milestone 1: slings score; the acts come in milestone 8)
    static let ballsPerGame = 3
    static let bannerSeconds: TimeInterval = 1.6

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

    // MARK: Lamps (milestone 7). Shot arrows sit on each shot's line from the flipper that shoots it, in front of
    // the shot; the four shared with Table 03's top keep its proven spots.
    /// name → (position, angle in radians). Arrows are 24 x 18.
    static let shotArrows: [String: (CGPoint, CGFloat)] = [
        "mesaRamp": (CGPoint(x: 336.3, y: 532), 70.8 * .pi / 180),     // from the left flipper (Table 03's ramp)
        "orbit": (CGPoint(x: 121.4, y: 722.7), 113.8 * .pi / 180),     // from the right flipper
        "arroyo": (CGPoint(x: 284, y: 582), .pi / 2),                  // Table 03's Library arrow (same hole)
        "saguaros": (CGPoint(x: 411.1, y: 493.2), 54.3 * .pi / 180),   // from the left flipper (Table 03's Sigil)
        // From the right flipper, on the captive channel's axis, 50 pt in front of the mouth posts
        "captive": (CGPoint(x: captiveMouth.x - 50 * cos(captiveHeading), y: captiveMouth.y - 50 * sin(captiveHeading)),
                    captiveHeading),
    ]
    /// Five paint drops round the dust devil, one per region (sky, mesas, saguaros, arroyo, desert): radius 60 from
    /// its centre, the first straight up, then clockwise. They show how far each region is painted.
    static var paintDropLamps: [CGPoint] {
        (0..<5).map { i in
            let a = CGFloat.pi / 2 - CGFloat(i) * 2 * .pi / 5
            return CGPoint(x: dustDevilCenter.x + 60 * cos(a), y: dustDevilCenter.y + 60 * sin(a))
        }
    }
    static let paintDropRadius: CGFloat = 7
    /// The diverter lamp, beside the mesa ramp arrow: lit = the next mesa shot climbs the helix.
    static let helixLamp = CGPoint(x: 364, y: 550)
    /// Shoot again (ball save), between the flippers.
    static let shootAgainLamp = CGPoint(x: 284, y: 150)
    /// Superbloom (the finale) star, between the flippers and the dust devil.
    static let superbloomLamp = CGPoint(x: 284, y: 335)

    // MARK: Monsoon (milestone 8 round 3)
    /// The second ball follows the first out of the arroyo this long after (and drained balls during the save).
    static let monsoonReleaseDelay: TimeInterval = 1.0
    /// Monsoon's ball save: every ball lost in the first 10 s is fired back out of the arroyo.
    static let monsoonBallSaveSeconds: TimeInterval = 10
    /// Jackpots that bloom the wildflowers (with all five regions they light Superbloom, next round).
    static let wildflowersNeeded = 4          // M8 v6 (simulator): was 3
    /// M10 v3: the storm bed's overall level under the effects (× the sound slider).
    static let stormBedGain: CGFloat = 0.55
    /// M10 v4 (Aaron: "the wind sound is a bit loud… more in the background"): the desert layer's share of the bed.
    static let desertWindGain: CGFloat = 0.4
    /// M10 v4 (Aaron: "the storm in the sky more intense"): the live storm over the painted sky. How dark it gets in
    /// Monsoon / when Monsoon is lit, and the gaps between lightning flashes (seconds).
    static let stormDarkMonsoon: CGFloat = 0.45
    static let stormDarkLit: CGFloat = 0.18
    static let lightningGapMonsoon: ClosedRange<Double> = 1.6...4.2
    static let lightningGapLit: ClosedRange<Double> = 6...12
    static let monsoonRainRate: CGFloat = 320
    /// M11 v2: every storm-cloud bumper hit adds this much of a sky wash (a little at a time; ~33 hits = one wash).
    /// The sky now needs 5 washes (was 4); tools/mon_simulate.py: Superbloom reached about as often as before.
    static let bumperSkyUnits: CGFloat = 0.03

    // MARK: Superbloom (milestone 8 round 4)
    /// The finale's ball save: 25 s (Table 03's Awakening, after its simulator).
    static let superbloomBallSaveSeconds: TimeInterval = 25
    /// After the finale, the finished painting is held this long before a new sketch (the next cycle) starts.
    static let paintingHoldSeconds: TimeInterval = 4

    // MARK: Carried over from Table 03 (milestone 8 round 5): same lower table, same spots and numbers.
    /// Lamps for the kickback (left outlane) and the outlane save (right), over the outlanes.
    static let kickbackLamp = CGPoint(x: 37, y: 300)
    static let outlaneSaveLamp = CGPoint(x: mirrorSum - 37, y: 300)
    /// A floor ball inside this x, below this y and falling is in the left outlane: a lit kickback fires it back up.
    static let kickbackMaxX: CGFloat = 60
    static let kickbackTriggerY: CGFloat = 240
    static let kickbackSpeed: CGFloat = 1500
    /// Crossed downward = the ball is going down the right outlane (for the outlane save).
    static let rightOutlaneSwitch = MonRampSwitch(a: CGPoint(x: 514, y: 240), b: CGPoint(x: laneWallX, y: 240),
                                                  forward: CGVector(dx: 0, dy: -1))
    /// Ball save: armed while the ball waits on the plunger and for 10 s after launch, once per player ball; the
    /// shoot-again lamp fast-blinks for the last 3 s.
    static let ballSaveSeconds: TimeInterval = 10
    static let ballSaveWarning: TimeInterval = 3
    /// Skill shot: the ringed top lane, if it's the first lane within 5 s of launch.
    static let skillShotWindow: TimeInterval = 5
    /// End-of-ball bonus: shots made this ball × 1,000 + spinner spins × 20, × the multiplier.
    static let bonusPerShot = 1_000
    static let bonusPerSpin = 20
    static let bonusCountSeconds: TimeInterval = 1.2
    static let bonusHoldSeconds: TimeInterval = 1.0
}
