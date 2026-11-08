import CoreGraphics
import SpriteKit
import UIKit
import Foundation

// Pinball Lab Table 06 (Orbit: Grand Tour, Nov 2026): Orbit reborn as a full table, a grand tour of the planets.
// Every Table 06 type is prefixed "Tour" (the app bundle is flat). Plan: "Pinball Lab Table 06 — Orbit: Grand Tour —
// Table Plan" (claude.ai doc).
// Milestone 1: the Lab card and a grey box of the lower table: the proven walls, flippers and slings of Tables 02–04,
// plus what is new here: an O-R-B-T rollover in every inlane and outlane (lit lanes rotate with the flippers), the
// kickback in the left outlane, and a pop-up rocket post between the flippers that the lanes light. Checked in
// tools/tour_render_m1.py. The upper table is open floor until milestone 3.

/// All Table 06 geometry in world points. SpriteKit's origin is bottom-left.
/// Same 600 x 1300 world, radius-9 ball and physics as Tables 02–05 (every value proven on device there).
enum TourTableLayout {
    static let worldSize = CGSize(width: 600, height: 1300)

    // MARK: Physics
    static let gravity: CGFloat = -9.2
    static let ballRadius: CGFloat = 9
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1
    /// v14 what-if: a faster flipper needs a higher cap (35 rad/s × 96 = 3,360 pt/s at the tip). `Tour.maxSpeed`.
    static var maxBallSpeed: CGFloat { LabOverrides.cg("Tour.maxSpeed", 3500) }
    static let wallRestitution: CGFloat = 0.3
    static let wallFriction: CGFloat = 0.1
    static let railRestitution: CGFloat = 0.15
    static let railFriction: CGFloat = 0.02

    // MARK: Art
    /// The oblique view the art will be drawn in (Tables 03–05's 22°): a point at height z appears z × this farther up.
    static let oblique: CGFloat = 0.4040
    /// Rendered part boxes (none yet: the parts fall back to their grey-box shapes). Kept so the copied parts build.
    static let upperFlipperArtBox = CGRect(x: -76, y: -15, width: 91, height: 30)

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
    /// 0 = a straight left wall (Grand Tour, 7 Nov 2026): the R-O-C bank's '/' deflector over the left outlane turns the
    /// kickback into the table and sheds balls coming down the wall, which was the bulge's job.
    static let leftBulgeControlInset: CGFloat = 0
    static let rightBulgeBottom: CGFloat = 540
    static let rightBulgeTop: CGFloat = 780
    /// 0 = a straight right wall (Grand Tour, 7 Nov 2026): the Mars bunker over the right outlane now does the bulge's
    /// job (balls sliding down the wall roll off its roof into play); the left bulge stays for the kickback.
    static let rightBulgeControlInset: CGFloat = 0
    static var laneCenterX: CGFloat { (laneWallX + rightWallX) / 2 }

    // MARK: Flippers
    static let leftFlipperPivot = CGPoint(x: 179, y: 220)
    static let rightFlipperPivot = CGPoint(x: 389, y: 220)
    static let flipperLength: CGFloat = 96
    static let flipperPivotRadius: CGFloat = 12
    static let flipperTipRadius: CGFloat = 6
    static let flipperRestAngle: CGFloat = .pi / 6
    static let flipperTravel: CGFloat = .pi / 3
    /// Real-table flippers (Aaron, 7 Nov 2026: "I want the flippers to play like an actual table" → "Love it. I can
    /// easily reach the rocket"). The other tables' 25.5 rad/s puts the tip at 136 ball-widths/s where a real machine's
    /// is ~185, on a table 1.5× longer in ball widths, so a ball flipped from the crook (28 pt out) barely reached y 940
    /// and arrived dead; the 2D rig (tools/flipper_rig.py) and the phone agree. 35 rad/s = 3,360 pt/s at the tip, the
    /// real figure; with the rubber's bounce at 0.3 the crook shot leaves at ~1,750 pt/s toward the centre (87°).
    /// Still what-ifs (`Tour.flipUp`, `Tour.flipBounce`, `Tour.maxSpeed`) for the Shot Lab's A/Bs.
    static var flipperUpSpeed: CGFloat { LabOverrides.cg("Tour.flipUp", 35) }
    static var flipperDownSpeed: CGFloat { LabOverrides.cg("Tour.flipDown", 14) }
    /// The flipper rubber's bounce (SpriteKit uses the HIGHER of the two bodies' restitutions, so with the ball at 0.1
    /// anything under 0.1 here is "dead"). Real rubber is ~0.4–0.5; the 2D rig (tools/flipper_rig.py, 7 Nov 2026)
    /// says the bounce is what turns a crook shot toward the centre. `Tour.flipBounce`.
    static var flipperRestitution: CGFloat { LabOverrides.cg("Tour.flipBounce", 0.3) }
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
    /// Monsoon's outlane posts (Play Lab runs 3 and 6): a short rail from each lane guide's top post up and out, so a
    /// ball dropping off the side-wall bulge rolls into the inlane instead of catching the post's outer side.
    static let leftOutlanePostTip = CGPoint(x: 44, y: 482)
    static var leftOutlanePostRail: [CGPoint] { [CGPoint(x: laneGuideX, y: laneGuideTop), leftOutlanePostTip] }
    static var rightOutlanePostRail: [CGPoint] { leftOutlanePostRail.map { mirrored($0) } }

    // MARK: Milestone 1, new: the O-R-B-T lanes and the rocket post
    /// One rollover in each lane, left to right: left outlane, left inlane, right inlane, right outlane. Their lamp
    /// inserts sit just below them; lit lanes rotate with the flippers (lane change).
    static let laneLetters = ["O", "R", "B", "T"]
    static var laneRolloverXs: [CGFloat] {
        let outlane = (leftWallX + laneGuideX) / 2, inlane = (laneGuideX + leftSling.corner.x) / 2   // 37, 71
        return [outlane, inlane, mirrorSum - inlane, mirrorSum - outlane]
    }
    static let laneRolloverY: CGFloat = 405
    static let laneLampY: CGFloat = 378
    static let laneSensorSize = CGSize(width: 24, height: 10)
    /// The pop-up rocket post between the flipper tips: lit by completing O-R-B-T, it rises and saves one ball from the
    /// centre drain, then drops. It sits 11 pt from each resting flipper tip (less than a ball) and clear of the
    /// flippers at every angle (tools/tour_render_m1.py).
    static let rocketPost = CGPoint(x: 284, y: 162)
    static let rocketPostRadius: CGFloat = 7
    static let rocketPostRestitution: CGFloat = 0.6
    /// After a ball hits the raised post, it drops this long later (time for the ball to bounce clear).
    static let rocketPostDropDelay: TimeInterval = 0.6

    // MARK: Rules (milestone 1: slings and lanes score; the tour comes in milestone 7)
    static let ballsPerGame = 3
    static let bannerSeconds: TimeInterval = 1.6
    /// The kickback lamp over the left outlane, and where a falling ball in that outlane gets fired back up.
    static let kickbackLamp = CGPoint(x: 37, y: 300)
    static let kickbackMaxX: CGFloat = 60
    static let kickbackTriggerY: CGFloat = 240
    static let kickbackSpeed: CGFloat = 1500
    /// Ball save: armed while the ball waits on the plunger and for 10 s after launch, once per player ball.
    static let ballSaveSeconds: TimeInterval = 10

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


    // MARK: - Milestone 2: Concept A, the Grand Fan (tools/tour_layout_a.py, render + checks tools/tour_render_a.py)
    // Nothing to hit in the middle of the lower table between the slings (y 470) and the shot line (y 790): the
    // centrepiece sits behind the centre shot, and the only lower targets hug a side wall (Aaron, 7 Nov 2026; see
    // the plan's layout guidelines). The shot mouths (orbits, ramps, Saturn, asteroids) come in milestone 3.

    /// A target is a thin plate: face width along its face, depth front to back.
    static let dropSize = CGSize(width: 24, height: 8)
    static let standupSize = CGSize(width: 26, height: 8)

    /// Heights: the shot line is y 600, the height our flippers reach (Monsoon's centre hole and ramp mouth sit at
    /// 582–600). v2–v4 put it at 790 and Mission Control at 900+ from real-table proportions, and flipper shots fell
    /// short (Aaron, 7 Nov 2026): in ball widths our table is ~1.8× longer than a real one.
    /// v10 (Aaron 7 Nov 2026, after v9: "I want to avoid this in the middle and pattern the layout of this table after
    /// real tables", then "Let's do it!" to the rethink): NO target bank anywhere. The centrepiece is the ROCKET on its
    /// launch pad at the back of an open centre channel (Medieval Madness's castle, Attack from Mars's saucer): a bash
    /// target — the pad's blast door — that counts the countdown down on five lamps; on "1" the rocket lifts off, the
    /// door drops, and the scoop under the rocket (Mission Control) is open. One toy, one target, one scoop.
    /// The pad: a pocket round the scoop with a peak at the back (balls from above roll off) and, v11, a FUNNEL in
    /// front: two guide rails 70° steep (near-parallel to the shot, so it doesn't bounce out) from a 122 pt mouth at
    /// y 808 down to the 36 pt door, like the castle's moat walls / the saucer's rails. Aaron on v10: "I can't hit the
    /// rocket with a caught ball… I miss to either side" — a bare 34 pt door 800 pt away is a 2.5° window; the mouth is
    /// 11.5°, and a ball that enters it rides a rail into the door.
    /// v16 (Aaron: "hitting the rocket frequently drops the ball right down the center through the drain"): the v11
    /// funnel rails are gone — they straightened every shot to vertical and re-centred every rebound, so the door's
    /// return went straight down the middle (a rail-guided ball arrives vertical at x 267–301 and leaves vertical:
    /// between the flipper tips). The door stays 34 pt: a crook shot that lands on it arrives drifting across the table
    /// and reflects to the OPPOSITE flipper (from x 207 at 87°: hits x 284, returns to x 361). A wider door would be
    /// worse — a hit on its left third from the left flipper returns to the centre. Short 45° shoulders at the door's
    /// ends send glancing hits sideways. The real-table flippers (v15) reach the door without rails.
    /// v17 (Aaron on v16: "I can't quite hit the rocket. I miss just left or right"): the rocket's base is a convex
    /// hull — the 34 pt blast door in the centre and a 24 pt WING each side angled 30° back (bash targets that never
    /// drop). 76 pt wide (~5.5° from each flipper) and, unlike the funnel, a convex front scatters rebounds AWAY from the
    /// middle: a hit on a wing comes off toward that side's sling. The pad's walls run from the wings' outer ends to the peak.
    /// v18 (Aaron on v17: launched the rocket off bounces, "didn't manage to hit from a caught ball"): the rig puts the
    /// crook shot (35 rad/s, rubber 0.3) at x ≈ 245 at this height — the v17 hull's left edge (246). Wings 24 → 40 pt:
    /// the hull is now 103 pt wide (x 232–336, ~7.5° from each flipper), a ball width past each crook shot.
    /// v20 (Shot Lab 11-08, 120 Hz, 1,098 trials): caught shots leave at 80–83°, not the rig's 87°, and cross the hull's
    /// height at x 327–346 (left flipper) / 226–241 (right): the wing TIPS. The door was made only 7 times (late tip
    /// flips off an inlane). Wings 40 → 52 pt: the hull is x 222–346, so the crook band lands on a wing, not its tip.
    static let rocketPad = [CGPoint(x: 222.0, y: 960.0), CGPoint(x: 266, y: 980), CGPoint(x: 284, y: 998),
                            CGPoint(x: 302, y: 980), CGPoint(x: 346.0, y: 960.0)]
    static let rocketWingSize = CGSize(width: 52, height: 8)
    static let rocketWings: [(center: CGPoint, normal: CGFloat)] = [
        (CGPoint(x: 244.5, y: 947.0), -.pi / 2 - .pi / 6),     // left wing faces down-left
        (CGPoint(x: 323.5, y: 947.0), -.pi / 2 + .pi / 6),     // right wing faces down-right
    ]
    /// The blast door: a drop target across the pocket's mouth (1 pt to each wall), facing down the table. It stays up
    /// through the countdown (hits only count) and drops on the last hit.
    static let blastDoor = CGPoint(x: 284, y: 934)
    static let blastDoorSize = CGSize(width: 34, height: 8)
    static let countdownHits = 5
    /// The five countdown lamps, a column under the centre arrow in the insert field (grey box: plain circles).
    static let countdownLamps = (0..<5).map { CGPoint(x: 284, y: 500 + 18 * CGFloat($0)) }
    /// The rocket toy stands over the pad (no body; it lifts off on the last hit).
    static let rocketToy = CGPoint(x: 284, y: 986)
    static let missionScoop = CGPoint(x: 284, y: 966)
    /// Mission Control kicks the ball into a subway: it comes out at the top of the left inlane (between the lane guide,
    /// x 54, and the sling, x 88), rolling down onto the left flipper — never back down the middle (AFM's hole).
    static let missionSubwayExit = CGPoint(x: 71, y: 490)
    static let missionEject = CGVector(dx: 0, dy: -300)        // the subway ball's velocity as it comes out
    /// Inside the pad behind the door: Mission Control catches any ball found here (tested against the peak, not a box).
    static func inMissionBay(_ p: CGPoint) -> Bool {
        // The pocket is wider at the front now (the wings' backs), so the zone is too; it's all behind the hull.
        let roof = [CGPoint(x: 222.0, y: 960.0), CGPoint(x: 266, y: 980), CGPoint(x: 284, y: 998),
                    CGPoint(x: 302, y: 980), CGPoint(x: 346.0, y: 960.0)]
        guard p.x > 244, p.x < 324, p.y > 946, let top = lineY(roof, at: p.x) else { return false }
        return p.y < top
    }

    /// ROCKET moves to the upper table in milestone 3 (Aaron, 7 Nov 2026): R-O-C beside the Moon, K-E-T in front of
    /// the bumpers. Side-wall banks are straight rows on a backboard, capped to the wall (see the skill).
    static let rocketLabels = ["R", "O", "C", "K", "E", "T"]
    /// R-O-C (milestone 2 v7–v8, Aaron 7 Nov 2026): three standups on the left wall, in a straight row running on up the
    /// line of a 65° '/' deflector, every face pointing −25° (down and right, toward the right flipper). v8: the row
    /// follows the '/' (v7 leaned out at 40° and reached x 116; Aaron: it "sticks out pretty far and removes the risk of
    /// the ball draining"), so it reaches x 86. K-E-T comes in milestone 3, in front of the bumpers.
    static let rocketNormal: CGFloat = -0.4363
    static let rocketCenters = [CGPoint(x: 60.8, y: 608.1), CGPoint(x: 72.6, y: 633.4), CGPoint(x: 84.5, y: 658.8)]
    /// The bank's structure as one wall: the '/' from the wall up to the bank, the backboard behind the standups, and a
    /// roof sloping from the bank's top back down to the wall (balls from above roll off it into play). The kickback's
    /// ball hits the underside of the '/' and comes off it up and right, arcing into the middle (tools/tour_kickback_sim.py).
    /// v8: the '/' starts at y 530, 50 pt above the outlane's top (v7: 480, right on it), so balls sliding down the wall
    /// can drop into the left outlane under it again (tools/tour_left_drain_sim.py: 0% in v7 → ~4.5%; v6's bulge 7%).
    static let rocStructure = [CGPoint(x: 20, y: 530), CGPoint(x: 50, y: 594.3), CGPoint(x: 86.3, y: 672.3),
                               CGPoint(x: 20, y: 714.3)]
    /// The kickback fires from the left outlane's centre (between the wall and the lane guide), as on Grey Invasion.
    static let kickbackLaneX: CGFloat = 37

    /// Mars: the rover scoop in a bunker on the RIGHT wall (the left wall stays clear above the kickback, whose ball rides
    /// the bulge up the left side). The sample bank, three drops in a straight row leaning out 12° with faces at 192°
    /// (left, 12° down toward the left flipper), is the bunker's front, so the rover is open only once samples are down.
    static let sampleNormal: CGFloat = 3.3510
    static let sampleCenters = [CGPoint(x: 508.0, y: 522.0), CGPoint(x: 502.4, y: 548.4), CGPoint(x: 496.8, y: 574.8)]
    static let roverScoop = CGPoint(x: 532, y: 530)
    /// The bunker's floor is a V under the scoop; its roof slopes up to the wall so balls from above (the right orbit's
    /// exit) roll off into play.
    static let bunkerFloor = [CGPoint(x: 507.0, y: 509.5), CGPoint(x: 532, y: 514), CGPoint(x: 548, y: 522)]
    static let bunkerRoof = [CGPoint(x: 489.9, y: 585.7), CGPoint(x: 516, y: 606), CGPoint(x: 548, y: 623.3)]   // to the wall
    /// Inside the bunker: behind the bank's face line, below the roof line and above the floor line (the real shape, not
    /// a box: v3's box caught balls rolling on the roof).
    static func inBunker(_ p: CGPoint) -> Bool {
        let a = CGPoint(x: 507.0, y: 507.5), b = CGPoint(x: 489.9, y: 587.7)   // the face line's ends
        let x0 = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)
        guard p.x > x0 + 6, let roof = lineY(bunkerRoof, at: p.x), let floor = lineY(bunkerFloor, at: p.x) else {
            return false
        }
        return p.y < roof && p.y > floor
    }
    static let roverEject = CGVector(dx: -240, dy: 60)       // out through the dropped bank, a lob onto the right flipper

    // MARK: - Milestone 3 v1: the two orbits with spinners (tools/tour_layout_m3.py, checks tools/tour_render_m3.py)
    // A shot up one orbit rides the arch round and comes down the other: onto the R-O-C roof (left) or the Mars bunker
    // roof (right), which shed it toward the flippers. The inner walls are OFFSETS of the arch (the skill: never a second
    // guessed curve) and smooth rails, like the outer wall; the top centre between them stays open for the lanes and
    // bumpers. Each mouth is a funnel flared 10° flatter than the shot from the opposite flipper (Grey Invasion's proven
    // funnel was 7°; a parallel one left ~3°, because the R-O-C bank caps the left orbit at 112° and the bunker roof caps
    // the right at 62°): aim windows by geometry 107.7–112.1° (left, from the right flipper) and 62.3–67.0° (right, from
    // the left flipper). The Shot Lab measures the real ones.

    /// The outer arch's inward offset by `inset`: its left half (from the left wall's foot to the top centre) or its right
    /// half (from the top centre down to the right wall), keeping points with x in `xRange`.
    static func archOffset(inset: CGFloat, rightHalf: Bool, xRange: ClosedRange<CGFloat>) -> [CGPoint] {
        let mid = CGPoint(x: worldSize.width / 2, y: topY)
        let (p0, c, p1) = rightHalf
            ? (mid, CGPoint(x: rightWallX, y: topY), CGPoint(x: rightWallX, y: archStartY))
            : (CGPoint(x: leftWallX, y: archStartY), CGPoint(x: leftWallX, y: topY), mid)
        var points: [CGPoint] = []
        for i in 0...64 {
            let t = CGFloat(i) / 64, u = 1 - t
            let p = CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                            y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
            let d = CGVector(dx: 2 * u * (c.x - p0.x) + 2 * t * (p1.x - c.x),
                             dy: 2 * u * (c.y - p0.y) + 2 * t * (p1.y - c.y))
            let l = max(hypot(d.dx, d.dy), 0.001)
            let q = CGPoint(x: p.x + d.dy / l * inset, y: p.y - d.dx / l * inset)   // the right-hand side = inward
            if xRange.contains(q.x) { points.append(q) }
        }
        return points
    }
    /// Left orbit: a 40 pt lane up the left wall (x 20…60); the inner wall stops at x 190.
    static let leftOrbitTip = CGPoint(x: 105.1, y: 837.1)
    static let leftOrbitBend = CGPoint(x: 60, y: 915)
    static var leftOrbitInner: [CGPoint] {
        [leftOrbitTip, leftOrbitBend] + archOffset(inset: 40, rightHalf: false, xRange: 0...190)
    }
    /// Right orbit: a 44 pt lane inside the plunger-lane wall (x 504…548); above the launch gate it shares the arch with
    /// the shooter lane (76 pt to the right wall). The inner wall runs up from the funnel and over to x 384.
    static let rightOrbitTip = CGPoint(x: 459.3, y: 664.8)
    static let rightOrbitBend = CGPoint(x: 504, y: 725)
    static var rightOrbitInner: [CGPoint] {
        [rightOrbitTip, rightOrbitBend] + archOffset(inset: 76, rightHalf: true, xRange: 384...600).reversed()
    }
    /// Arm switches low in each lane (up arms that orbit, down disarms); the right one stops at the lane wall, so a plunge
    /// up the shooter lane never arms it. Made = crossing the top centre line the right way (left orbit → right).
    static let leftOrbitArm = TourSwitch(a: CGPoint(x: leftWallX, y: 990), b: CGPoint(x: 60, y: 990),
                                         forward: CGVector(dx: 0, dy: 1))
    static let rightOrbitArm = TourSwitch(a: CGPoint(x: 504, y: 900), b: CGPoint(x: laneWallX, y: 900),
                                          forward: CGVector(dx: 0, dy: 1))
    /// A ball armed this long ago or more no longer scores the made switch (a weak shot that dropped off the arch into the
    /// open top centre would stay armed for good otherwise; a slow orbit takes well under a second).
    static let orbitMadeWithin: TimeInterval = 2.0
    static let orbitMade = TourSwitch(a: CGPoint(x: 284, y: 1150), b: CGPoint(x: 284, y: 1275),
                                      forward: CGVector(dx: 1, dy: 0))
    /// The spinners across each lane above its mouth (either direction spins them).
    static let leftSpinnerLine = (a: CGPoint(x: leftWallX, y: 960), b: CGPoint(x: 60, y: 960))
    static let rightSpinnerLine = (a: CGPoint(x: 504, y: 800), b: CGPoint(x: laneWallX, y: 800))
    static let leftSpinnerSwitch = TourSwitch(a: leftSpinnerLine.a, b: leftSpinnerLine.b, forward: CGVector(dx: 0, dy: 1))
    static let rightSpinnerSwitch = TourSwitch(a: rightSpinnerLine.a, b: rightSpinnerLine.b, forward: CGVector(dx: 0, dy: 1))
    /// The spinner's rendered frames, when the art comes (none yet: TourSpinner draws its blade).
    static let spinnerArtBox = CGRect(x: -22, y: -10, width: 44, height: 32)
    static let spinnerFrames = (columns: 6, rows: 4)

    /// The height of a wall polyline at x (nil outside its x range).
    static func lineY(_ pts: [CGPoint], at x: CGFloat) -> CGFloat? {
        for (u, v) in zip(pts, pts.dropFirst()) {
            let lo = min(u.x, v.x), hi = max(u.x, v.x)
            if x >= lo && x <= hi, hi > lo { return u.y + (x - u.x) * (v.y - u.y) / (v.x - u.x) }
        }
        return nil
    }

    /// Scoops (Table 04's pattern): the hole, the catch radius, how long a ball is held, and how long after the eject
    /// the same scoop ignores it.
    static let scoopRadius: CGFloat = 14
    static let scoopCaptureRadius: CGFloat = 16
    static let scoopHold: TimeInterval = 1.0
    static let scoopRecapture: TimeInterval = 0.5
    /// The bank comes back up this long after its scoop kicks the ball out (so the eject passes through first).
    static let bankResetDelay: TimeInterval = 0.6

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
