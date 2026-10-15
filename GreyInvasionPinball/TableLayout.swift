import CoreGraphics
import Foundation

/// All table geometry in world points. SpriteKit's origin is bottom-left.
/// The table is a 600 x 1300 world with a radius-9 ball (about 3% of the width).
/// The camera (Camera.swift) decides how much of the world is on screen.
///
/// Scaling from Orbit Pinball (390 wide): world distances, gravity and speeds are the
/// POC values x k (600 / 390 ≈ 1.54). Things the ball has to fit through (drain gap,
/// plunger lane, inlane-to-pivot clearance) are sized in ball diameters to match the POC.
/// Angular speeds (rad/s) don't scale.
enum TableLayout {
    static let worldSize = CGSize(width: 600, height: 1300)

    // MARK: Physics (milestone 10 tunes these from playtest notes)
    static let gravity: CGFloat = -9.2            // POC -6 x k
    static let ballRadius: CGFloat = 9
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1     // SpriteKit uses the higher of two bodies' bounce
    static let maxBallSpeed: CGFloat = 2460       // POC 1600 x k
    static let wallRestitution: CGFloat = 0.3
    static let wallFriction: CGFloat = 0.1
    /// The outer wall and the orbit's inner wall are smooth metal rails: low bounce and almost
    /// no friction, so a ball heading up the orbit keeps its speed instead of rattling (M4 v5).
    static let railRestitution: CGFloat = 0.15
    static let railFriction: CGFloat = 0.02

    // MARK: Art (milestone 8)
    /// The world rectangle covered by playfield.png (tools/art_playfield.py: x -40…640, y -75…1330,
    /// 2.9 px per point, 1972 x 4074 px). Includes the cabinet round the table.
    static let playfieldArtRect = CGRect(x: -40, y: -75, width: 680, height: 1405)

    // MARK: Walls
    static let leftWallX: CGFloat = 20
    static let rightWallX: CGFloat = 580
    static let laneWallX: CGFloat = 548           // inner wall of the plunger lane (lane = 32, ~1.8 balls)
    static let laneFloorY: CGFloat = 40
    static let archStartY: CGFloat = 1000         // side walls turn into the arched top here
    static let topY: CGFloat = 1270
    static let bottomY: CGFloat = -60             // the drain chute runs off the bottom
    /// Apron (M7 v6): below the flippers the outer walls angle in to one centre drain, as on a
    /// real table (Aaron, with a Wild West screenshot: the outlane lines ran straight off the
    /// bottom). Each outlane ends on a 19° slope that runs under its flipper to the drain chute.
    /// Checked in tools/render_m7a.py: 61 pt from any flipper position, outlane exit gap 39.5.
    static let apronTopY: CGFloat = 185           // where the slope leaves the side wall
    static let drainEdgeX: CGFloat = 250          // drain chute 250…318 (68 wide), centred under the flippers
    static let drainEdgeY: CGFloat = 105
    /// The drain chute's sides stop just under the slope (M7 v7): Aaron, the lines running to the
    /// bottom edge crossed the launch hint text. The ball still drops straight off the bottom.
    static let drainLipY: CGFloat = 85
    /// A gentle inward bulge in the left wall above the outlane (playtest, M4 v1): a full plunge
    /// sliding down the wall gets nudged over the lane guide into the inlane instead of the outlane,
    /// and a kickback shot going straight up gets pushed out into the playfield instead of falling
    /// back down the outlane. Peak 18 pt in, at y 660.
    static let leftBulgeBottom: CGFloat = 540
    static let leftBulgeTop: CGFloat = 780
    static let leftBulgeControlInset: CGFloat = 36   // quadratic control point; the curve peaks at half this
    /// The same bulge on the right (plunger-lane) wall, added in M4 v6: a ball hit into the right
    /// wall used to slide straight down into the right outlane. The ramp's wire passes over it on
    /// its own layer, so they don't interact.
    static let rightBulgeBottom: CGFloat = 540
    static let rightBulgeTop: CGFloat = 780
    static let rightBulgeControlInset: CGFloat = 36
    static var laneCenterX: CGFloat { (laneWallX + rightWallX) / 2 }
    /// Center of the playfield (excluding the plunger lane); the flippers are symmetric about it.
    static var playfieldCenterX: CGFloat { (leftWallX + laneWallX) / 2 }

    // MARK: Flippers
    static let leftFlipperPivot = CGPoint(x: 179, y: 220)
    static let rightFlipperPivot = CGPoint(x: 389, y: 220)
    static let flipperLength: CGFloat = 96        // ~5.3 ball diameters; tips leave a 32pt drain gap
    static let flipperPivotRadius: CGFloat = 12
    static let flipperTipRadius: CGFloat = 6
    static let flipperRestAngle: CGFloat = .pi / 6   // 30° below horizontal
    static let flipperTravel: CGFloat = .pi / 3      // 60° swing
    /// Radians per second. The tip speed should scale with the world like every other speed:
    /// POC tip 22 x 72 = 1,584 → x k = 2,440 → / 96 = 25.4 rad/s. The first build kept 22,
    /// which made the tips ~13% too slow for this table (orbit unreachable, playtest M4 v4).
    static let flipperUpSpeed: CGFloat = 25.5        // tip ~2,450 pt/s
    static let flipperDownSpeed: CGFloat = 14        // POC 12, scaled the same way
    static let flipperMass: CGFloat = 2
    static let flipperFriction: CGFloat = 0.4        // grip helps the ball settle when cradled

    /// Where each inlane guide ends: just above the top edge of the flipper's
    /// pivot at rest, so the ball rolls straight onto the flipper instead of
    /// wedging into the corner between the guide and the pivot.
    static var leftGuideEnd: CGPoint {
        let r = flipperPivotRadius + 1
        return CGPoint(x: leftFlipperPivot.x + r * sin(flipperRestAngle),
                       y: leftFlipperPivot.y + r * cos(flipperRestAngle))
    }
    static var rightGuideEnd: CGPoint {
        let r = flipperPivotRadius + 1
        return CGPoint(x: rightFlipperPivot.x - r * sin(flipperRestAngle),
                       y: rightFlipperPivot.y + r * cos(flipperRestAngle))
    }

    // MARK: Plunger
    static let plungerSize = CGSize(width: 24, height: 50)
    static let plungerRestTop: CGFloat = 120
    static var plungerRestPosition: CGPoint {
        CGPoint(x: laneCenterX, y: plungerRestTop - plungerSize.height / 2)
    }
    static let plungerMaxPull: CGFloat = 60
    static let minLaunchSpeed: CGFloat = 1080        // POC 700 x k (too weak to clear the gate)
    static let maxLaunchSpeed: CGFloat = 2310        // POC 1500 x k
    static let tapLaunchPower: CGFloat = 0.6         // a quick tap = medium launch
    /// Touches in the bottom-right of the SCREEN drive the plunger while a ball is waiting
    /// in the lane: right of this fraction of the width, below this fraction of the height.
    static let plungerZoneMinX: CGFloat = 0.62
    static let plungerZoneMinY: CGFloat = 0.55

    // MARK: Launch lane gate (one-way: closes once the ball has left the lane)
    static let laneWallTop: CGFloat = 955
    /// Slopes down to the left so a ball landing on it rolls into the playfield.
    static var gateLow: CGPoint { CGPoint(x: laneWallX, y: laneWallTop) }
    static var gateHigh: CGPoint { CGPoint(x: rightWallX, y: laneWallTop + 28) }

    // MARK: Lower table (milestone 4 round 1): inlanes, outlanes, slingshots, kickback
    // Left side shown; the right side mirrors it about the playfield centre (x' = 568 - x).
    // Outlane 20…54 runs off the bottom (drain). Lane guide at x 54 from y 470 down to y 330,
    // then slants (36.9°) to the flipper pivot. Inlane 34 wide between the lane guide and the
    // slingshot, whose bottom side runs parallel to the slant. Checked in tools/render_m4a.py.
    static let mirrorSum: CGFloat = leftWallX + laneWallX   // 568
    static func mirrored(_ p: CGPoint) -> CGPoint { CGPoint(x: mirrorSum - p.x, y: p.y) }

    static let laneGuideX: CGFloat = 54           // outlane 34 wide (1.9 balls)
    static let laneGuideTop: CGFloat = 470
    static let laneGuideBend: CGFloat = 330
    static var leftLaneGuide: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd]
    }
    static var rightLaneGuide: [CGPoint] { leftLaneGuide.map { mirrored($0) } }

    // Slingshots: top → corner → tip are the passive sides; tip → top is the kicking face.
    static let leftSling = (top: CGPoint(x: 88, y: 450),
                            corner: CGPoint(x: 88, y: 347),
                            tip: CGPoint(x: 150, y: 300.4))
    static var rightSling: (top: CGPoint, corner: CGPoint, tip: CGPoint) {
        (mirrored(leftSling.top), mirrored(leftSling.corner), mirrored(leftSling.tip))
    }
    static let slingKickSpeed: CGFloat = 920       // POC 600 x k
    /// Only the middle of the face kicks (M4 v5, playtest: the bouncy face running up to the top
    /// kicked too much and drained balls). Fractions along the face from the tip to the top.
    static let slingKickFrom: CGFloat = 0.12
    static let slingKickTo: CGFloat = 0.75
    /// Dead round posts at the top and tip corners, as on real tables.
    static let slingTopPostRadius: CGFloat = 7      // keeps the inlane top 27 wide (1.5 balls)
    static let slingTipPostRadius: CGFloat = 6
    static let slingPostRestitution: CGFloat = 0.1

    // Kickback at the bottom of the left outlane: fires a draining ball back up the outlane.
    // Lit by completing the fighter bank (M4 v9, as in the plan); one save, then it must be relit.
    static let kickbackMaxX: CGFloat = 60          // ball centre left of this…
    static let kickbackTriggerY: CGFloat = 240     // …and below this, moving down (M7 v6: was 170, before the apron)
    static let kickbackSpeed: CGFloat = 1500       // straight up: clears the lane guide top with room to spare
    static let kickbackLampCenter = CGPoint(x: 37, y: 255)   // M7 v6: moved up into the channel
    static let kickbackLampSize = CGSize(width: 28, height: 10)
    /// Right outlane save (M7 v5): lit by clearing a wave; if the last ball drains down the right
    /// outlane while it's lit, the ball comes back on the plunger. A drained ball counts as a
    /// right-outlane drain when it left the table right of the right flipper's pivot (only the
    /// outlane leads there). Lamp mirrors the kickback lamp.
    static var outlaneSaveLampCenter: CGPoint { mirrored(kickbackLampCenter) }
    /// M7 v6: with the apron every ball leaves through the centre drain, so a right-outlane drain
    /// is marked when the ball crosses this line going DOWN inside the right outlane (nothing
    /// below it can send the ball back up).
    static let rightOutlaneSwitch = RampSwitch(a: CGPoint(x: 514, y: 240), b: CGPoint(x: laneWallX, y: 240),
                                               forward: CGVector(dx: 0, dy: -1))
    /// The right apron: from the plunger-lane wall down to the right side of the drain chute.
    static var rightApron: [CGPoint] {
        [CGPoint(x: laneWallX, y: apronTopY),
         CGPoint(x: mirrorSum - drainEdgeX, y: drainEdgeY),
         CGPoint(x: mirrorSum - drainEdgeX, y: drainLipY)]
    }
    /// Outlane walls (M7 v4, shortened in M7 v6): each lane guide carries straight on down from
    /// its bend, so each outlane stays a 34-wide channel past the kickback (playtest: under the
    /// slanted guide the outlane opened out to ~160 wide and balls bounced past the kickback).
    /// They stop 39.5 pt above the apron so the ball rolls out under them to the drain.
    static let outlaneWallBottom: CGFloat = 215
    static var kickbackLaneWall: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideBend), CGPoint(x: laneGuideX, y: outlaneWallBottom)]
    }
    static var rightOutlaneWall: [CGPoint] { kickbackLaneWall.map { mirrored($0) } }

    // MARK: Top of the table (milestone 4 round 2): orbit, U-F-O lanes, saucer bumpers
    // Checked in tools/render_m4b.py.

    /// Orbit: a lane up the left side (x 20…58, 38 wide) that follows the arch over the top.
    /// Its entrance is a funnel (below).
    /// The inner wall stops at the top-left, so the top right is open: a strong shot rides the
    /// arch all the way round and comes down onto the closed launch gate (the one-way gate),
    /// which rolls it back into play; a soft plunge drops off the top into the U-F-O lanes.
    static let orbitInnerX: CGFloat = 58
    /// The entrance is a funnel facing the right flipper: the inner wall's bottom slants out
    /// to this tip (M4 v4). The first try, a straight 38-wide slot opening downward, left only
    /// about 1° of aim from the right flipper (Aaron: "I have yet to get the ball in the lane");
    /// the funnel accepts about 9° (tools/render_m4b.py measures it).
    /// M4 v5: shortened from (140,790)/900 at Aaron's request ("the opening extends too far");
    /// still about 6° of aim.
    static let orbitFunnelTip = CGPoint(x: 112, y: 800)
    static let orbitFunnelBendY: CGFloat = 890      // the inner wall is vertical above this
    static let orbitInnerEndX: CGFloat = 190       // the inner wall ends here along the top
    static var orbitInnerWall: [CGPoint] {
        let innerTop = topY - (orbitInnerX - leftWallX)
        let arc = quadCurve(from: CGPoint(x: orbitInnerX, y: archStartY),
                            control: CGPoint(x: orbitInnerX, y: innerTop),
                            to: CGPoint(x: worldSize.width / 2, y: innerTop),
                            segments: 32)
        return [orbitFunnelTip, CGPoint(x: orbitInnerX, y: orbitFunnelBendY), CGPoint(x: orbitInnerX, y: archStartY)]
            + arc.filter { $0.x <= orbitInnerEndX }
    }

    /// One-way orbit diverter at the top right (M4 v6): solid only while the ball moves right,
    /// so a ball coming round the orbit is peeled off the arch down onto the top-right bumper,
    /// while a plunge (moving left along the top) passes through. Playtest M4 v5: orbit shots
    /// sailed over the lanes and never reached the bumpers.
    static let orbitDiverterTop = CGPoint(x: 412, y: 1262)    // just outside the arch, so there's no gap
    static let orbitDiverterBottom = CGPoint(x: 365, y: 1160) // 37 clear of the last lane post

    /// U-F-O lanes: 3 lanes 36 wide between 4 thin posts, under the top of the arch.
    static let lanePostXs: [CGFloat] = [220, 256, 292, 328]
    static let lanePostBottom: CGFloat = 1130
    static let lanePostTop: CGFloat = 1185
    static let laneSensorY: CGFloat = 1150
    static let laneLightY: CGFloat = 1205
    static let laneSensorSize = CGSize(width: 28, height: 10)
    static var laneCenterXs: [CGFloat] {
        zip(lanePostXs, lanePostXs.dropFirst()).map { ($0 + $1) / 2 }
    }

    /// Saucer bumpers: an open triangle below the lanes, fed by them. M4 v7 spread them out
    /// (gaps 63–72, ~4 balls; was 28–32): packed tight, the ball only ever hit the outside of
    /// one and kicked away. The middle lane now drops straight into the nest.
    static let bumperRadius: CGFloat = 28
    static let bumperCenters: [CGPoint] = [
        CGPoint(x: 210, y: 1050),
        CGPoint(x: 338, y: 1050),
        CGPoint(x: 274, y: 950),
    ]
    static let bumperKickSpeed: CGFloat = 1150      // POC 750 x k

    // MARK: Tractor Beam ramp (right ramp, milestone 3)
    // Mouth mid-table, climbing up-right at the same angle as a shot from near the left
    // flipper's tip; a tight turn at the top; then a wire down the right side with a small
    // S-bend that drops the ball into the top of the right inlane. Checked in tools/render_m4a.py.
    static let rampMouth = CGPoint(x: 360, y: 600)
    static let rampMouthHalfWidth: CGFloat = 30     // funnel entrance, 60 wide (3.3 balls); was 40, too hard to hit (playtest 1)
    static let rampHalfWidth: CGFloat = 16          // channel 32 wide (1.8 balls)
    static let rampFlareLength: CGFloat = 70        // the funnel narrows to the channel over this distance
    static let rampPostLength: CGFloat = 24         // floor-layer posts at the mouth edges
    static let rampEntryDistance: CGFloat = 12      // entry switch, along the path from the mouth
    static let rampMadeAfterApex: CGFloat = 10      // "ramp made" switch, just past the top turn
    static let rampExitBeforeEnd: CGFloat = 15      // exit switch, just before the wire ends
    static let rampFriction: CGFloat = 0.05
    static let rampRestitution: CGFloat = 0.1       // low, so the ball doesn't rattle in the channel
    /// Speed cap on the wire return, so it feeds the inlane gently (world points/s).
    static let rampReturnMaxSpeed: CGFloat = 700

    /// The Tractor Beam ramp's centerline, and how far along it the top turn ends.
    static func tractorBeamPath() -> (path: RampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))     // ~71° up-right
        var p = RampPath(start: rampMouth, heading: climb)
        p.line(hypot(90, 260))                            // climb to (450, 860)
        p.arc(radius: 36, turn: -(climb + .pi / 2))       // tight turn, ends heading straight down
        let apex = p.length
        p.line(248)                                       // wire down the right side, x 520, to y 600
        // S-bend 23 pt to the left, onto the right inlane's centre line (x 497)
        let bend = acos(1 - CGFloat(23) / CGFloat(120))   // ~36°
        p.arc(radius: 60, turn: -bend)
        p.arc(radius: 60, turn: bend)
        p.line(40)                                        // release at about (497, 490), straight down
        return (p, apex)
    }

    // MARK: Defense Cannon ramp (left ramp, milestone 4 round 3)
    // Mirror image of the Tractor Beam, shot from the right flipper, with a wire down the left
    // side into the top of the left inlane. Its mouth sits at x 228 rather than the exact mirror
    // (208), so it doesn't block the orbit shot: orbit ~5.0° of aim, this ramp ~5.1° (the right
    // ramp is ~5.1° too). Checked in tools/render_m4c.py.
    static let leftRampMouth = CGPoint(x: 228, y: 600)
    static let leftInlaneCenterX: CGFloat = 69      // the wire drops the ball here…
    static let wireReleaseY: CGFloat = 490          // …at this height, straight down

    static func defenseCannonPath() -> (path: RampPath, apexDistance: CGFloat) {
        let climb = atan2(CGFloat(260), CGFloat(90))
        var p = RampPath(start: leftRampMouth, heading: .pi - climb)   // climbs up-left
        p.line(hypot(90, 260))
        p.arc(radius: 36, turn: climb + .pi / 2)          // tight turn, ends heading straight down
        let apex = p.length
        p.line(248)                                       // wire down the left side
        // S-bend onto the left inlane's centre line (a positive turn heading down = toward +x)
        let shift = leftInlaneCenterX - p.points[p.points.count - 1].x
        if abs(shift) > 0.5 {
            let bend = acos(1 - min(abs(shift), 119) / 120)
            let turn = shift > 0 ? bend : -bend
            p.arc(radius: 60, turn: turn)
            p.arc(radius: 60, turn: -turn)
        }
        p.line(max(p.points[p.points.count - 1].y - wireReleaseY, 20))  // straight down to the release
        return (p, apex)
    }

    // MARK: Scoops (milestone 4 round 3)
    // Hangar: dead centre between the two ramp mouths, shot from either flipper; kicks the
    // ball out onto the left flipper. Abduction: right side, beside the Tractor Beam's climb,
    // shot from either flipper; kicks out onto the right flipper. ~2–3° of aim each (precise shots).
    static let scoopRadius: CGFloat = 15             // drawn size
    /// The ball's centre must come this close. M10 v4 (Aaron: "hitting the hangar seems hard" from a
    /// cradled ball): 12 → 18, about the painted glow ring; ~±1.9° of aim from the flippers instead of ~±1.3°.
    static let scoopCaptureRadius: CGFloat = 18
    static let scoopHold: TimeInterval = 1.0
    static let scoopRecapture: TimeInterval = 0.6    // ignore the hole this long after a kick-out
    /// M10 v16 (Shot Lab): moved down from y 760 to 650, onto the crossing of the two flippers' early-flip
    /// "up the middle" lines. At 760 a cradled shot made it 7% (average player, right flipper) and never
    /// from the left; at 650 it's ~50–56% from either flipper on 120 Hz and 60 Hz phones. 630 → ~70%.
    static let hangarCenter = CGPoint(x: 284, y: 650)
    /// From the lower hole the old kick (-30, -480) landed past the left flipper's tip (x ≈ 268, the drain
    /// gap); -100 lands it mid-flipper (x ≈ 230), clear of the left ramp mouth and the sling.
    static let hangarEject = CGVector(dx: -100, dy: -480)
    static let abductionCenter = CGPoint(x: 470, y: 700)
    static let abductionEject = CGVector(dx: -180, dy: -520)  // clears the right ramp mouth, lands on the right flipper

    // MARK: Abduction ball lock + multiball (milestone 5 round 2)
    // Outside multiball, a ball caught by the Abduction scoop is "abducted" (it floats up and
    // fades) and locked, and a new ball is served. The third catch kicks its ball out and
    // releases the two locked balls from the scoop one after another: 3-ball multiball.
    static let locksForMultiball = 3
    /// Above the scoop (moved from below it in M6 to make room for the Abduction shot arrow).
    static let lockLampCenters: [CGPoint] = [CGPoint(x: 452, y: 738), CGPoint(x: 470, y: 738), CGPoint(x: 488, y: 738)]
    static let lockLampRadius: CGFloat = 5

    // MARK: Lamp inserts (milestone 6)
    // Decals under everything (no physics). Each shot arrow sits on the line from the flipper
    // that shoots it, 56–90 pt in front of the shot, pointing at it. Checked in tools/render_m6a.py.
    static let arrowLength: CGFloat = 24
    static let arrowWidth: CGFloat = 18
    static let shotArrows: [(name: String, at: CGPoint, degrees: CGFloat)] = [
        ("rightRamp", CGPoint(x: 336.3, y: 532.0), 70.8),   // Tractor Beam, from the left flipper
        ("leftRamp", CGPoint(x: 248.0, y: 530.8), 106.2),   // Defense Cannon, from the right flipper
        ("orbit", CGPoint(x: 121.4, y: 722.7), 113.8),      // from the right flipper
        ("hangar", CGPoint(x: 284.0, y: 582.0), 90.0),      // straight up the middle (68 below the Hangar, M10 v16)
        ("abduction", CGPoint(x: 444.3, y: 650.3), 62.7),   // from the left flipper
        ("bank", CGPoint(x: 411.1, y: 493.2), 54.3),        // fighter bank, from the left flipper
    ]
    /// Earth Defense meter: Wave 1, Wave 2, Wave 3, Mothership.
    static let earthDefenseLamps: [CGPoint] = [239, 269, 299, 329].map { CGPoint(x: $0, y: 455) }
    static let earthDefenseRadius: CGFloat = 9
    /// Ships Down ladder: 10 lamps feeding the end-of-ball bonus.
    static let shipsDownLamps: [CGPoint] = (0..<10).map { CGPoint(x: 284 + (CGFloat($0) - 4.5) * 16, y: 410) }
    static let shipsDownRadius: CGFloat = 5
    static let shieldsUpCenter = CGPoint(x: 284, y: 300)
    static let shieldsUpSize = CGSize(width: 44, height: 14)
    static let extraBallCenter = CGPoint(x: 312, y: 650)     // beside the Hangar (moved with it, M10 v16)
    static let extraBallRadius: CGFloat = 6
    // MARK: Rules (milestone 7 round 1)
    static let shieldsUpSeconds: TimeInterval = 10      // ball save after launch, once per ball
    static let shieldsUpWarning: TimeInterval = 3       // the lamp fast-blinks for the last 3 s
    static let skillShotWindow: TimeInterval = 5        // first lane within 5 s of launch
    static let comboWindow: TimeInterval = 3            // ramp/orbit within 3 s of another = double
    static let bannerSeconds: TimeInterval = 1.6        // HUD message time
    /// End-of-ball bonus (M7 round 5, plan: ships shot down × 1,000 + ramps made × 500, times
    /// the bonus multiplier — the U-F-O multiplier). Counted up in the LED strip before the next ball.
    static let bonusPerShip = 1_000
    static let bonusPerRamp = 500
    static let bonusCountSeconds: TimeInterval = 1.2
    static let bonusHoldSeconds: TimeInterval = 1.0
    /// Orbit switches. Crossing the lower one going UP arms the orbit for that ball (crossing it
    /// back down disarms it); an armed ball crossing the top one going RIGHT, past the end of the
    /// inner wall, made the orbit. M7 v2: v1 scored on the lower line alone, so a ball that went
    /// partway up and fell back counted (and started a combo). A plunge moves left along the top
    /// and down the lane, so it crosses both the other way and never counts.
    static let orbitArmSwitch = RampSwitch(a: CGPoint(x: leftWallX, y: 990), b: CGPoint(x: orbitInnerX, y: 990),
                                           forward: CGVector(dx: 0, dy: 1))
    static let orbitMadeSwitch = RampSwitch(a: CGPoint(x: 200, y: 1205), b: CGPoint(x: 200, y: 1265),
                                            forward: CGVector(dx: 1, dy: 0))
    static let lockServeDelay: TimeInterval = 0.6      // after an abduction, then a new ball is served
    static let multiballReleaseInterval: TimeInterval = 0.8
    /// Mothership finale (M7 round 4): a 2-ball multiball from the Hangar with a ball save.
    static let mothershipExtraBalls = 1
    static let mothershipBallSaveSeconds: TimeInterval = 15

    // MARK: Fighter bank (milestone 4 round 4a)
    // Four drop targets in a vertical bank on the right, facing the left flipper (~11° of aim from
    // the left flipper, ~8° from the right). A wall right behind the bank (gap 6) means a ball that
    // gets round the back just rolls down into the right inlane/outlane; a cap over the top target
    // slopes down-left so nothing rests on the bank. Lowered 25 pt from the first layout so its cap
    // doesn't block the Abduction scoop. Checked in tools/render_m4d.py.
    static let dropTargetSize = CGSize(width: 12, height: 24)
    static let dropTargetX: CGFloat = 464
    static let dropTargetYs: [CGFloat] = [595, 565, 535, 505]   // top to bottom
    static let dropTargetResetDelay: TimeInterval = 1.0
    static let fighterBankBackWall = [CGPoint(x: 476, y: 487), CGPoint(x: 476, y: 621)]
    static let fighterBankCap = [CGPoint(x: 476, y: 621), CGPoint(x: 454, y: 613)]

    // MARK: Upper flipper (milestone 4 round 4b)
    // Right wall under the Tractor Beam's wire (Aaron picked candidate B over the plan's left-side
    // spot: tools/render_m4e.py). Every orbit shot rolls off the launch gate onto it, as do balls
    // coming down the right side. It shoots the Hangar (~6° of aim) and up into the lanes/bumpers
    // (~31°), blocks no existing shot, and flips with the RIGHT button. The pivot sits 10 from
    // the wall, so nothing gets behind it.
    static let upperFlipperPivot = CGPoint(x: 528, y: 800)
    static let upperFlipperLength: CGFloat = 64
    static let upperFlipperPivotRadius: CGFloat = 10
    static let upperFlipperTipRadius: CGFloat = 5
    /// Guide from the right wall down toward the top of the upper flipper's pivot, at the
    /// flipper's rest angle (the same idea as the inlane guides). M4 v11: without it a ball sliding
    /// down the wall got stuck in the V between the wall and the pivot (playtest M4 v10).
    /// M4 v13: a third shorter, trimmed from the PIVOT end as Aaron intended (v12 trimmed the wall
    /// end by mistake). It now stops ~5 pt short of the pivot: too narrow for the ball, and a ball
    /// leaving the guide comes down left of the pivot's centre, so it rolls onto the flipper.
    static let upperFlipperGuideTrim: CGFloat = 0.33
    static var upperFlipperGuide: [CGPoint] {
        let r = upperFlipperPivotRadius + 1
        let full = CGPoint(x: upperFlipperPivot.x - r * sin(flipperRestAngle),
                           y: upperFlipperPivot.y + r * cos(flipperRestAngle))      // ≈ (522.5, 809.5)
        let wall = CGPoint(x: laneWallX, y: full.y + (laneWallX - full.x) * tan(flipperRestAngle))  // ≈ (548, 824)
        let t = upperFlipperGuideTrim
        let end = CGPoint(x: full.x + (wall.x - full.x) * t, y: full.y + (wall.y - full.y) * t)    // ≈ (530.9, 814.4)
        return [wall, end]
    }

    /// One continuous wall: left wall (from below the bottom edge, with the bulge) → arched top →
    /// right wall → plunger lane floor → inner plunger lane wall (also the outside of the right
    /// outlane, with its own bulge).
    static var outerWall: [CGPoint] {
        var points: [CGPoint] = [
            CGPoint(x: drainEdgeX, y: drainLipY),        // short lip on the left side of the drain
            CGPoint(x: drainEdgeX, y: drainEdgeY),
            CGPoint(x: leftWallX, y: apronTopY),         // the apron slope, up to the left wall
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
