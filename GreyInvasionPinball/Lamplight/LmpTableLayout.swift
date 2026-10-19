import CoreGraphics
import SpriteKit
import UIKit
import Foundation

// Pinball Lab Table 05 (The Lamplight, Oct 2026), a cozy bookshop-café table. Every Table 05 type is prefixed "Lmp"
// (the app bundle is flat).
// Milestone 1: the card and a NEW lower table in grey box (Aaron chose "center post + one outlane"): the flippers sit
// 11 pt farther apart with a rubber post between their tips, and only the right side has an outlane (the left side is
// closed: a deflector off the left wall feeds the left inlane).
// Milestone 2: the upper table in grey box (tools/lmp_render_m2.py): a loop pair joined over the top, the upper flipper (removed in M6 v6)
// low on the LEFT wall, the bookshelf bank across the middle guarding the fireplace hole, the kettle scoop with its
// spinner up a lane on the left, the mail slot on the right, three teacup bumpers top right.
// Milestone 3 round 1 (tools/lmp_render_m3.py): the loft, a raised mini-playfield at the top left with its own flipper
// and the window seat, reached by a ramp from the left flipper; a ball that drains off it rolls down a chute into the
// left lane. The bumpers move under the ramp's turn. The dumbwaiter and the plunge to the loft are round 2.
// Milestone 4: the shop cat on her shelf at the top right (LmpCat).
// Milestone 7 round 1: lamps (LmpLamp): shot arrows, the lucky-evening star, and six shop lamps on the apron that come
// on one by one through the evening while the whole table warms and dims toward closing.

/// All Table 05 geometry in world points. SpriteKit's origin is bottom-left.
/// Same 600 x 1300 world, radius-9 ball and physics as Tables 02–04 (every physics value proven on device there).
enum LmpTableLayout {
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
    static let ballsPerGame = 3

    // MARK: Art
    /// The oblique view the art will be drawn in (Tables 03–04's 22°): a point at height z appears z × this farther up.
    static let oblique: CGFloat = 0.4040
    /// Rendered part boxes (none yet: the parts fall back to their grey-box shapes). Kept so the copied parts build.
    static let upperFlipperArtBox = CGRect(x: -76, y: -15, width: 91, height: 30)
    static let launchGateArtBox = CGRect(x: -35, y: -37, width: 47, height: 48)

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
    /// The right (plunger-lane) wall keeps Tables 02–04's inward bulge: without it a ball hit into the right wall
    /// slides straight down the right outlane (Grey Invasion M4 v6). The left side no longer needs one: its deflector
    /// (below) turns a ball sliding down the left wall into the inlane.
    static let rightBulgeBottom: CGFloat = 540
    static let rightBulgeTop: CGFloat = 780
    static let rightBulgeControlInset: CGFloat = 36
    static var laneCenterX: CGFloat { (laneWallX + rightWallX) / 2 }
    static var playfieldCenterX: CGFloat { (leftWallX + laneWallX) / 2 }     // 284

    // MARK: Flippers (T5 M1: 11 pt farther apart than Tables 02–04, for the center post)
    static let leftFlipperPivot = CGPoint(x: 168, y: 220)
    static let rightFlipperPivot = CGPoint(x: 400, y: 220)
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

    // MARK: Center post
    /// A rubber post between the flipper tips: tips at rest are 53.8 apart edge to edge, so the r 7 post leaves two
    /// gaps of 19.9 (a ball is 18): a ball dropping straight down the middle usually bounces onto a flipper.
    static let centerPost = CGPoint(x: 284, y: 168)
    static let centerPostRadius: CGFloat = 7
    static let centerPostRestitution: CGFloat = 0.5

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

    // MARK: Lower table
    static let mirrorSum: CGFloat = leftWallX + laneWallX   // 568
    static func mirrored(_ p: CGPoint) -> CGPoint { CGPoint(x: mirrorSum - p.x, y: p.y) }

    static let laneGuideX: CGFloat = 54
    static let laneGuideTop: CGFloat = 470
    static let laneGuideBend: CGFloat = 330
    /// The left deflector: from the left wall at y 520 down to the top of the lane guide (55° slope), so a ball
    /// coming down the left wall rolls into the inlane. There is no left outlane.
    static let leftDeflectorTop = CGPoint(x: leftWallX, y: 520)
    static var leftInlaneWall: [CGPoint] {
        [leftDeflectorTop, CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd]
    }
    /// The closed pocket left of the inlane (drawn as a darker floor; no ball can reach it).
    static var leftClosedPocket: [CGPoint] {
        [CGPoint(x: leftWallX, y: apronTopY), leftDeflectorTop, CGPoint(x: laneGuideX, y: laneGuideTop),
         CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd,
         CGPoint(x: leftGuideEnd.x, y: apronTopY - (leftGuideEnd.x - leftWallX) / (drainEdgeX - leftWallX) * (apronTopY - drainEdgeY))]
    }
    static var rightLaneGuide: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd].map { mirrored($0) }
    }

    /// Slings: Tables 02–04's shape, with the bottom side re-angled to run parallel to the new lane-guide slant
    /// (the flippers moved out), keeping the inlane 34.7 wide.
    static let leftSling = (top: CGPoint(x: 88, y: 450),
                            corner: CGPoint(x: 88, y: 347),
                            tip: CGPoint(x: 150, y: 296.2))
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
    static var rightOutlaneWall: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideBend), CGPoint(x: laneGuideX, y: outlaneWallBottom)].map { mirrored($0) }
    }
    /// Crossed going down: the ball is draining down the right outlane (for the cat-flap save in the rules milestone).
    static let rightOutlaneLine = (a: CGPoint(x: 514, y: 240), b: CGPoint(x: laneWallX, y: 240))
    /// T5 M8 v11: the cat flap (the plan's outlane save). Lit at the start of each ball; a ball going down the right
    /// outlane while it's lit is carried back up (no collisions, like the dumbwaiter) and dropped into the right inlane
    /// above the sling's top post (gap 487–514 at y 505), once per ball. Play Lab: the right outlane was the biggest
    /// single drain (4–6 of 11–17 per run).
    static let catFlapExit = CGPoint(x: 498, y: 505)
    static let catFlapSeconds: TimeInterval = 0.45
    static let catFlapExitVelocity = CGVector(dx: -15, dy: -120)
    static let catFlapLamp = CGPoint(x: 531, y: 300)

    // MARK: Upper table (milestone 2, grey box). Shot lines checked in tools/lmp_render_m2.py.

    /// The loop pair: an orbit lane up each side, 42 wide, joined over the top by the arch. A ball shot up one side
    /// comes round the top and down the other. The left lane's mouth is at y 780 (shot by the right flipper); the
    /// right lane's at y 762 (shot by the left flipper).
    static let leftOrbitInnerX: CGFloat = 62
    /// T5 M6 v7 (Aaron: the right flipper can't really get up the left loop, its wall comes down too far): the inner
    /// wall now starts at y 900 (was 780), so shots a few degrees right of the old line still get into the lane.
    static let leftOrbitMouthY: CGFloat = 900
    static let rightOrbitInnerX: CGFloat = 506
    static let rightOrbitMouthY: CGFloat = 762      // T5 M2 v2: was 720
    static let orbitTopInnerY: CGFloat = 1228
    /// T5 M2 v3 (Aaron: the ball stuck at the top left): the inner wall's curve wasn't parallel to the arch and
    /// pinched the lane to 18 pt, exactly a ball. It now follows the arch at the lane's full 42 pt, ending at x ~180.
    static var leftOrbitWall: [CGPoint] {
        let p0 = CGPoint(x: leftWallX, y: archStartY), c = CGPoint(x: leftWallX, y: topY)
        let p1 = CGPoint(x: worldSize.width / 2, y: topY)
        let inset = leftOrbitInnerX - leftWallX
        var points = [CGPoint(x: leftOrbitInnerX, y: leftOrbitMouthY)]
        for i in 0...32 {
            let t = CGFloat(i) / 32, u = 1 - t
            let p = CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                            y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
            let d = CGVector(dx: 2 * u * (c.x - p0.x) + 2 * t * (p1.x - c.x),
                             dy: 2 * u * (c.y - p0.y) + 2 * t * (p1.y - c.y))
            let l = max(hypot(d.dx, d.dy), 0.001)
            let q = CGPoint(x: p.x + d.dy / l * inset, y: p.y - d.dx / l * inset)
            if q.x > 190 { break }
            points.append(q)
        }
        return points
    }
    static var rightOrbitWall: [CGPoint] {
        [CGPoint(x: rightOrbitInnerX, y: rightOrbitMouthY), CGPoint(x: rightOrbitInnerX, y: archStartY)]
            + quadCurve(from: CGPoint(x: rightOrbitInnerX, y: archStartY),
                        control: CGPoint(x: rightOrbitInnerX, y: orbitTopInnerY),
                        to: CGPoint(x: 380, y: orbitTopInnerY))
    }
    /// A ball coming back down the right lane (a loop from the left, or a weak plunge off the launch gate) meets
    /// this deflector across the lane's mouth and rolls off it into the table instead of falling into the right
    /// outlane. It's one-way, like the launch gate: solid only for a ball above it moving down, so shots going up
    /// the lane pass straight through it.
    /// T5 M2 v2 (Aaron: the ball got trapped on the right): its low end met the bottom of the lane's inner wall, a
    /// V the ball sat in. Now it runs on past the wall into the table, 22 pt clear of the wall's end (a ball is 18).
    static let rightDeflectorLow = CGPoint(x: 480, y: 700)
    static let rightDeflectorHigh = CGPoint(x: 543, y: 770)
    /// Solid for a ball above it that isn't climbing faster than this (a ball resting on it has dy ≈ 0).
    static let deflectorClimbSpeed: CGFloat = 20
    /// Crossed over the top of the arch: a loop. Forward = right to left.
    static let loopSwitch = LmpSwitch(a: CGPoint(x: 284, y: orbitTopInnerY - 4), b: CGPoint(x: 284, y: topY + 4),
                                      forward: CGVector(dx: -1, dy: 0))
    static let loopPoints = 500
    static let loopComboPoints = 1_000
    static let loopComboWindow: TimeInterval = 5
    /// A plunged ball is marked until it first comes back down below this height (so its trip over the top isn't a loop).
    static let launchedClearY: CGFloat = 700

    /// T5 M6 v6 (Aaron: "we can just lose that flipper altogether"): no upper flipper. A ball coming back down the
    /// left lane falls to the left deflector and into the left inlane. The loft flipper's size lives here now.
    static let loftFlipperPivotRadius: CGFloat = 10
    static let loftFlipperTipRadius: CGFloat = 5

    /// The bookshelf bank: four book drop targets across the mouth of the fireplace alcove. All four down opens the
    /// fireplace hole behind them; the bank comes back up once the ball has left the alcove.
    static let alcoveLeftX: CGFloat = 224
    static let alcoveRightX: CGFloat = 344
    static let alcoveBottomY: CGFloat = 735
    static let alcoveTopY: CGFloat = 850
    /// T5 M5 v4: a peaked roof (22 pt high) instead of a flat top, so a ball that drops onto the alcove from the
    /// bumpers rolls off one side or the other instead of resting there.
    static let alcoveRoofPeak: CGFloat = 22
    static var alcoveWall: [CGPoint] {
        [CGPoint(x: alcoveLeftX, y: alcoveBottomY), CGPoint(x: alcoveLeftX, y: alcoveTopY),
         CGPoint(x: (alcoveLeftX + alcoveRightX) / 2, y: alcoveTopY + alcoveRoofPeak),
         CGPoint(x: alcoveRightX, y: alcoveTopY), CGPoint(x: alcoveRightX, y: alcoveBottomY)]
    }
    static let dropTargetSize = CGSize(width: 26, height: 12)
    static let targetArtBox = CGRect(x: -15, y: -8, width: 30, height: 24)
    static let bookTargetCenters: [CGPoint] = [240.2, 269.4, 298.6, 327.8].map { CGPoint(x: $0, y: 745) }
    static let bookTargetPoints = 100
    static let bankCompletePoints = 1_000
    static let bankResetDelay: TimeInterval = 0.8
    static let fireplaceCenter = CGPoint(x: 284, y: 800)
    static let fireplaceEject = CGVector(dx: -130, dy: -520)
    /// T5 M8 v11 (Play Lab, runs 5–9: 66 of 118 balls that got into the alcove came straight back down the middle,
    /// off the roof and down the far wall, out of the mouth above the drain): a ball that gets deep into the alcove,
    /// above the bank's line, drops into the fireplace wherever it is. With the bank down the open alcove is the shot.
    static var alcoveCatchBottomY: CGFloat { bookTargetCenters[0].y + dropTargetSize.height / 2 + ballRadius + 2 }
    static let fireplacePoints = 2_500

    /// The kettle: a hole at the top of a short lane on the left, angled along the shot from the right flipper, with
    /// the teapot spinner across the lane. It kicks the ball back down the lane.
    static let kettleShotFrom = CGPoint(x: 330, y: 250)
    static let kettleCenter = CGPoint(x: 141.7, y: 894.2)
    static let kettleLaneHalfWidth: CGFloat = 27
    static let kettleLaneLength: CGFloat = 120
    /// Unit vector up the lane.
    static var kettleAxis: CGVector {
        let end = CGPoint(x: 140, y: 900)
        let dx = end.x - kettleShotFrom.x, dy = end.y - kettleShotFrom.y
        let l = hypot(dx, dy)
        return CGVector(dx: dx / l, dy: dy / l)
    }
    private static func kettlePoint(along t: CGFloat, side: CGFloat) -> CGPoint {
        let u = kettleAxis, end = CGPoint(x: 140, y: 900)
        return CGPoint(x: end.x + u.dx * t - u.dy * side, y: end.y + u.dy * t + u.dx * side)
    }
    /// Left wall, the round cap over the hole, right wall.
    /// T5 M5 v4 (Shot Lab run 2: the lane only took shots within ~2° of its axis, too narrow to hit on a 60 Hz
    /// phone): a flare at the mouth's left side, out to (120, 745), catches shots a little too far left. (No flare on
    /// the right: it would leave the slot beside the alcove as a dead-end pocket a ball could sit in. Shots a little
    /// too far right go up that slot into the bumpers.)
    /// T5 M5 v5 (run 3: 60 Hz kettle shots, ~4° left of the lane, bounced off v4's 49° flare out to the right):
    /// the flare now runs almost straight down from the lane's mouth (20° out from the lane's line), so those shots
    /// glance off it into the lane.
    /// T5 M6 v7 (Aaron: shorten the part that comes straight down below the kettle): 25 pt long (was 52).
    static let kettleLeftFlareEnd = CGPoint(x: 146, y: 752)
    static var kettleLaneWall: [CGPoint] {
        let h = kettleLaneHalfWidth
        var pts = [kettleLeftFlareEnd, kettlePoint(along: -kettleLaneLength, side: h)]
        for i in 0...12 {
            let a = CGFloat(i) * .pi / 12
            pts.append(kettlePoint(along: h * sin(a), side: h * cos(a)))
        }
        pts.append(kettlePoint(along: -kettleLaneLength, side: -h))
        return pts
    }
    static var kettleSpinnerLine: (a: CGPoint, b: CGPoint) {
        (kettlePoint(along: -kettleLaneLength + 30, side: kettleLaneHalfWidth),
         kettlePoint(along: -kettleLaneLength + 30, side: -kettleLaneHalfWidth))
    }
    static var kettleSpinnerSwitch: LmpSwitch {
        LmpSwitch(a: kettleSpinnerLine.a, b: kettleSpinnerLine.b, forward: kettleAxis)
    }
    static var kettleEject: CGVector { CGVector(dx: -kettleAxis.dx * 480, dy: -kettleAxis.dy * 480) }
    static let kettlePoints = 1_500
    static let spinnerArtBox = CGRect(x: -22, y: -10, width: 44, height: 32)
    static let spinnerFrames = (columns: 6, rows: 4)
    static let spinnerPoints = 20

    /// The mail slot: a narrow saucer on the right, a precise shot from the left flipper between the ramp and the
    /// right loop.
    static let mailSlotCenter = CGPoint(x: 380, y: 640)
    /// T5 M8 v3: 14 (was 12). Still clear of the ramp and right-loop shot lines by about 15 pt (Shot Lab crossings).
    static let mailCaptureRadius: CGFloat = 14
    /// T5 M8 v3: no speed gate any more (was 900, earlier 650). The soft-shot rule was for the upper flipper; the left
    /// flipper's shots cross the slot at 1450-2200 pt/s, so every one was refused.
    static let mailMaxSpeed: CGFloat = maxBallSpeed
    static let mailEject = CGVector(dx: -60, dy: -320)
    static let mailPoints = 2_000

    /// Holes (Table 03's scoop numbers).
    static let scoopRadius: CGFloat = 15
    static let scoopCaptureRadius: CGFloat = 18
    static let scoopHold: TimeInterval = 1.0
    static let scoopRecapture: TimeInterval = 0.6

    /// Three teacup pop bumpers at the top right (the cat's shelf goes above them in milestone 4).
    /// T5 M3: moved down into the space inside the ramp's turn (the ramp now runs where they were), r 24 → 22.
    static let bumperRadius: CGFloat = 22
    static let bumperCenters: [CGPoint] = [CGPoint(x: 285, y: 930), CGPoint(x: 350, y: 930), CGPoint(x: 318, y: 1000)]
    static let bumperKickSpeed: CGFloat = 1150
    static let bumperArtBox = CGRect(x: -34, y: -40, width: 82, height: 86)
    static let bumperPoints = 100

    // MARK: The loft (milestone 3). A raised mini-playfield: a ball up here is on the upper layer (category rampBall),
    // which touches only rampWall walls and the loft flipper; floor balls pass under the ramp. Underneath, the loft is
    // a solid block on the floor, so no floor ball rolls out of sight beneath it.

    /// The arch offset inward by `inset`, from (leftWallX + inset, archStartY) round the top until x passes maxX.
    static func archOffset(inset: CGFloat, maxX: CGFloat) -> [CGPoint] {
        let p0 = CGPoint(x: leftWallX, y: archStartY), c = CGPoint(x: leftWallX, y: topY)
        let p1 = CGPoint(x: worldSize.width / 2, y: topY)
        var points: [CGPoint] = []
        for i in 0...64 {
            let t = CGFloat(i) / 64, u = 1 - t
            let p = CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                            y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
            let d = CGVector(dx: 2 * u * (c.x - p0.x) + 2 * t * (p1.x - c.x),
                             dy: 2 * u * (c.y - p0.y) + 2 * t * (p1.y - c.y))
            let l = max(hypot(d.dx, d.dy), 0.001)
            let q = CGPoint(x: p.x + d.dy / l * inset, y: p.y - d.dx / l * inset)
            if q.x > maxX { break }
            points.append(q)
        }
        return points
    }

    static let loftRightX: CGFloat = 255
    static let loftBottomY: CGFloat = 975
    /// The loft's left side and top: 52 in from the arch (10 inside the left lane's inner wall), across to x 255.
    static var loftOutline: [CGPoint] { archOffset(inset: 52, maxX: loftRightX) }
    static var loftTopRight: CGPoint { CGPoint(x: loftRightX, y: loftOutline.last?.y ?? 1215) }
    /// Where the ramp comes in through the loft's right wall.
    static let loftDoorBottom: CGFloat = 1104
    static let loftDoorTop: CGFloat = 1136

    /// Upper-layer walls: the left side and top, the right wall above and below the ramp's door, the drain slope
    /// and the chute under the loft that carries a drained ball down into the left lane.
    static let loftSlope = [CGPoint(x: 72, y: 1030), CGPoint(x: 162, y: 962)]
    static var loftWalls: [[CGPoint]] {
        [[loftSlope[0]] + loftOutline.filter { $0.y > loftSlope[0].y } + [loftTopRight],
         [loftTopRight, CGPoint(x: loftRightX, y: loftDoorTop)],
         [CGPoint(x: loftRightX, y: loftDoorBottom), CGPoint(x: loftRightX, y: loftBottomY)],
         loftSlope,
         [CGPoint(x: loftRightX, y: loftBottomY), CGPoint(x: 40, y: 880)],
         loftFlipperGuide]
    }
    /// The loft's floor, for drawing.
    static var loftFloor: [CGPoint] {
        [loftSlope[1], loftSlope[0]] + loftOutline.filter { $0.y > loftSlope[0].y }
            + [loftTopRight, CGPoint(x: loftRightX, y: loftBottomY),
                                                      CGPoint(x: 200, y: loftBottomY - 25)]
    }
    /// The block under the loft on the floor layer (its outline is a floor wall).
    /// T5 M8 v7 (Play Lab: balls stuck at (189, 1213)): the block's roof is now the arch offset by the left lane's 42
    /// (the inner wall's line) instead of the loft's 52. With 52 there was a 10 pt slot between the end of the lane's
    /// inner wall (x ~190) and the roof, and a slow ball dropping off the arch onto the roof rolled left into it and
    /// wedged. Now the roof carries on from the inner wall, so the ball rolls into the lane.
    static var loftBlock: [CGPoint] {
        let roof = archOffset(inset: leftOrbitInnerX - leftWallX, maxX: loftRightX)
        let roofRight = CGPoint(x: loftRightX, y: roof.last?.y ?? 1225)
        return [CGPoint(x: leftOrbitInnerX, y: archStartY), CGPoint(x: leftOrbitInnerX, y: loftBottomY),
                CGPoint(x: loftRightX, y: loftBottomY), roofRight] + Array(roof.reversed())   // ends at the start point
    }

    /// The loft flipper: right-hand, at the loft's bottom right, on the RIGHT button. A ball falls onto it from the
    /// ramp's door above; the drain is the gap left of its tip (24.9 pt), down to the chute.
    static let loftFlipperPivot = CGPoint(x: 240, y: 985)
    static let loftFlipperLength: CGFloat = 56
    /// T5 M3 v2 (Aaron: stuck in the loft): a ball dropping down the right wall from the ramp's door sat in the 5 pt
    /// crevice between the wall and the pivot. This guide runs from the wall to the top of the pivot (as the upper
    /// flipper's does), so the ball rolls on down the flipper.
    /// T5 M3 v3 (still stuck): v2 ended the guide at the pivot's top-RIGHT, the right point for a left-hand flipper.
    /// This flipper is right-hand (it points down-left), so its top edge leaves the pivot at the top-LEFT; the ball
    /// sat on the pivot's crown between it and the guide. The guide now ends there, covering the crown.
    static var loftFlipperGuide: [CGPoint] {
        let r = loftFlipperPivotRadius + 1
        let top = CGPoint(x: loftFlipperPivot.x - r * sin(flipperRestAngle),
                          y: loftFlipperPivot.y + r * cos(flipperRestAngle))
        return [CGPoint(x: loftRightX, y: top.y + 30), top]
    }

    /// The window seat: a hole at the loft's top left, shot from the loft flipper. It kicks the ball out to the right,
    /// so it drops back onto the flipper's pivot end.
    static let windowSeatCenter = CGPoint(x: 115, y: 1110)
    static let windowSeatCapture: CGFloat = 16
    static let windowSeatEject = CGVector(dx: 300, dy: -80)
    static let windowSeatPoints = 5_000
    /// T5 M8 v7 (Play Lab: the loft was a farm, good players never came down): one window seat per loft visit. A
    /// second catch on the same visit scores this little, finds nothing, and kicks the ball at the drain gap left of
    /// the loft flipper's tip (through (177, 960) about 0.3 s later), so it rolls down the chute to the lower table.
    static let windowSeatRepeatPoints = 500
    static let windowSeatDownEject = CGVector(dx: 207, dy: -293)

    /// A drained loft ball rolling left down the chute crosses this line inside the left lane and drops to the floor.
    static let loftExitSwitch = LmpSwitch(a: CGPoint(x: 46, y: 850), b: CGPoint(x: 46, y: 960),
                                          forward: CGVector(dx: -1, dy: 0))

    /// M3 round 2: the dumbwaiter. Every other kettle shot, the kettle sends the ball up a shaft into the loft
    /// (until the rules milestone decides when it's lit). It comes out at the loft's lower left moving right, and
    /// falls onto the loft flipper's pivot end.
    static let dumbwaiterExit = CGPoint(x: 150, y: 1080)
    static let dumbwaiterSeconds: TimeInterval = 0.6
    static let dumbwaiterExitVelocity = CGVector(dx: 250, dy: 0)
    static let dumbwaiterPoints = 1_000

    /// M3 round 2: a full plunge (a plunged ball still this fast as it comes over the top, about 85% pull or more)
    /// drops through a hatch into the loft instead of running down the left lane.
    static let plungeToLoftSpeed: CGFloat = 1200
    static let loftHatch = CGPoint(x: 215, y: 1185)
    static let loftHatchSeconds: TimeInterval = 0.2
    static let loftHatchExitVelocity = CGVector(dx: -120, dy: -60)
    static let fullPlungePoints = 2_500

    // MARK: The loft ramp (milestone 3): from the left flipper, mouth at (400, 830), straight up, a left turn of
    // radius 70, then west through the loft's door. Shot line clear of the mail slot by 20 pt (tools/lmp_render_m3.py).
    /// T5 M5 v4 (Shot Lab run 2: shots within ~3° of the line made it; the rest hit the mouth's posts, one bouncing
    /// off the left post into the right orbit): the mouth opens from the bookshelf alcove's right wall (x 344, so no
    /// dead slot beside it), flaring down to the 32 pt channel.
    /// T5 M5 v5 (run 3: 60% at 120 Hz, still 0 at 60 Hz, where the frames give headings of ~71–72° that hit the
    /// right post): the ramp's first straight now leans along the shot (75°, the line from the left flipper) instead
    /// of going straight up, the mouth's centre moves to x 412 and its right edge to x 470 (was 446).
    static let rampMouth = CGPoint(x: 412, y: 830)
    static let rampMouthLeftX: CGFloat = alcoveRightX
    static let rampMouthRightX: CGFloat = 470
    static let rampHalfWidth: CGFloat = 16
    static let rampHeading: CGFloat = 75 * .pi / 180
    static let rampFlareLength: CGFloat = 82
    static let rampStraightLength: CGFloat = 209
    static let rampTurnRadius: CGFloat = 70
    /// Up the straight at rampHeading, a left turn of radius 70 round to heading west at y 1120, then west to the
    /// loft's door.
    static var rampCenterline: [CGPoint] {
        let u = CGVector(dx: cos(rampHeading), dy: sin(rampHeading))
        let end = CGPoint(x: rampMouth.x + u.dx * rampStraightLength, y: rampMouth.y + u.dy * rampStraightLength)
        let c = CGPoint(x: end.x - u.dy * rampTurnRadius, y: end.y + u.dx * rampTurnRadius)
        var points = [rampMouth, end]
        let a0 = rampHeading - .pi / 2
        for i in 1...14 {
            let a = a0 + CGFloat(i) / 14 * (.pi / 2 - a0)
            points.append(CGPoint(x: c.x + rampTurnRadius * cos(a), y: c.y + rampTurnRadius * sin(a)))
        }
        points.append(CGPoint(x: loftRightX, y: points.last?.y ?? 1120))
        return points
    }
    /// One rail: the centreline offset by `side` (+ = left of travel), with the mouth's flare.
    static func rampRail(side: CGFloat) -> [CGPoint] {
        let cl = rampCenterline
        let u = CGVector(dx: cos(rampHeading), dy: sin(rampHeading))
        var out: [CGPoint] = [CGPoint(x: side > 0 ? rampMouthLeftX : rampMouthRightX, y: rampMouth.y),
                              CGPoint(x: rampMouth.x + u.dx * rampFlareLength - u.dy * side,
                                      y: rampMouth.y + u.dy * rampFlareLength + u.dx * side)]
        for i in 1..<cl.count {
            let a = cl[i - 1], b = cl[min(i + 1, cl.count - 1)]
            let d = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            let l = max(hypot(d.dx, d.dy), 0.001)
            out.append(CGPoint(x: cl[i].x - d.dy / l * side, y: cl[i].y + d.dx / l * side))
        }
        return out
    }
    /// A floor post at the mouth's right edge, so a missed shot bounces off the entrance (the alcove's wall is the
    /// left edge).
    static var rampMouthPosts: [[CGPoint]] {
        [[CGPoint(x: rampMouthRightX, y: rampMouth.y), CGPoint(x: rampMouthRightX, y: rampMouth.y - 24)]]
    }
    static var rampEntrySwitch: LmpSwitch {
        // T5 M6 v2 (Aaron: a ball went up the ramp and off the table): with the usual 25% slack this 126-wide line
        // also caught balls 31 pt past the right post, in the right loop's path, and put them on the ramp layer
        // outside the ramp, where no floor wall stops them. No slack: only balls between the edges go up.
        LmpSwitch(a: CGPoint(x: rampMouthLeftX, y: rampMouth.y + 12),
                  b: CGPoint(x: rampMouthRightX, y: rampMouth.y + 12), forward: CGVector(dx: 0, dy: 1), slack: 0)
    }
    /// Through the loft's door: the ramp is made.
    static let rampMadeSwitch = LmpSwitch(a: CGPoint(x: 262, y: 1100), b: CGPoint(x: 262, y: 1140),
                                          forward: CGVector(dx: -1, dy: 0))
    static let rampPoints = 1_000
    /// T5 M8 v18 (Play Lab: a ball sat still at (323, 1114) for 5 s): the ramp's last run, from the end of the turn
    /// (x ~398) west to the loft's door, is flat on a top-down table, so a ball that runs out of speed there rests on the
    /// lower rail. A ball that slow on the top run is helped on into the loft at this speed (it's over the hump).
    static var rampTopEastX: CGFloat { rampCenterline[rampCenterline.count - 2].x }
    static let rampTopNudgeSpeed: CGFloat = 150

    // MARK: The cat (milestone 4). Her shelf runs along the top right, above the ramp's turn and below the gap at
    // the top of the arch; she walks it, naps, and swats balls that come within reach back down the table.
    static let catRadius: CGFloat = 15
    static let catShelfY: CGFloat = 1175
    static let catMinX: CGFloat = 300
    static let catMaxX: CGFloat = 440
    static let catHomeX: CGFloat = 370
    static let catWalkSpeed: CGFloat = 45
    static let catNapSeconds: ClosedRange<Double> = 4...8
    static let catSwatCooldown: TimeInterval = 1.5
    /// Centre to centre: her radius + a ball + about a paw.
    static let catReach: CGFloat = 46
    static let catSwatSpeedX: CGFloat = 260
    static let catSwatSpeedY: CGFloat = -680
    static let catPetPoints = 250
    static let catWakePoints = 500
    static let catSwatPoints = 100
    /// M6 round 3: with more than one perch owned, she moves to another one this often (seconds).
    static let catRoamSeconds: ClosedRange<Double> = 35...55

    /// M6: how long a find shows under the score.
    static let findToastSeconds: TimeInterval = 3.0

    // MARK: Lamps (milestone 7). Shot arrows sit on each shot's line in front of it, pointing along the shot
    // (headings from the Shot Lab's probes).
    static let shotArrows: [String: (CGPoint, CGFloat)] = [
        "ramp": (CGPoint(x: 328, y: 585), 76 * .pi / 180),          // left flipper → the loft ramp
        "rightLoop": (CGPoint(x: 428, y: 580), 60 * .pi / 180),     // left flipper → up the right lane
        "leftLoop": (CGPoint(x: 128, y: 560), 117 * .pi / 180),     // right flipper → up the left lane
        "kettle": (CGPoint(x: 238, y: 585), 104 * .pi / 180),       // right flipper → the kettle lane
        "fireplace": (CGPoint(x: 284, y: 690), .pi / 2),            // straight up at the bookshelf
        "windowSeat": (CGPoint(x: 185, y: 1030), 125 * .pi / 180),  // in the loft: loft flipper → the window seat
    ]
    static let arrowLength: CGFloat = 30
    static let arrowWidth: CGFloat = 16
    /// Lit for a lucky evening.
    static let luckyLamp = CGPoint(x: 284, y: 330)
    /// Six shop lamps on the apron (three each side, under the flippers), lit one by one as the evening goes on.
    static let shopLamps: [CGPoint] = [CGPoint(x: 62, y: 192), CGPoint(x: 112, y: 174), CGPoint(x: 162, y: 157),
                                       CGPoint(x: 506, y: 192), CGPoint(x: 456, y: 174), CGPoint(x: 406, y: 157)]
    /// An evening is about this long: one more shop lamp every eveningSeconds / 6, and the warm dim reaches its
    /// deepest (eveningDimMax) at the end.
    static let eveningSeconds: TimeInterval = 300
    static let eveningDimMax: CGFloat = 0.22

    // MARK: Requests (milestone 8)
    static let requestPoints = 5_000
    /// The first regular comes in this long after the evening starts; the next, this long after one is helped.
    static let firstRequestDelay: TimeInterval = 4
    static let nextRequestDelay: TimeInterval = 6
    /// How long a regular's card (who, what they'd like, the shots) shows as they come in.
    static let visitorCardSeconds: TimeInterval = 4
    /// A lamp ring round the mail slot, lit when a request wants it.
    static let mailLampRadius: CGFloat = 17

    // MARK: The Evening Rush (milestone 8 round 2)
    /// Every rushEvery-th request finished in an evening opens the Rush: a second ball is plunged in for you, and every
    /// request finished pays double until you're back to one ball. Balls lost in the first rushSaveSeconds after the
    /// Rush ball goes in come straight back.
    static let rushEvery = 3
    static let rushSaveSeconds: TimeInterval = 10
    static let rushLaunchDelay: TimeInterval = 1.2
    /// The Rush ball's plunge: a little under a tap's 0.6, well short of a full plunge into the loft.
    static let rushLaunchPower: CGFloat = 0.55
    /// During the Rush the next regular comes in this quickly.
    static let rushRequestDelay: TimeInterval = 2

    // MARK: Cozy spots (milestone 8 round 3)
    /// Three lamps on the left apron, under the slope and below the shop lamps, one per cozy spot.
    static let cozyLamps: [CGPoint] = [CGPoint(x: 70, y: 148), CGPoint(x: 118, y: 131), CGPoint(x: 166, y: 114)]
    static let cozyLampRadius: CGFloat = 10
    /// The grandfather clock's ball save at the start of each ball.
    /// T5 M8 v8: 8 (was 3). In two Play Lab runs a 3 s save never fired: a ball almost never drains that soon after a
    /// plunge. 8 s is a real ball save you can feel.
    static let clockSaveSeconds: TimeInterval = 8
    /// What the clock adds to the Rush's ball save (unchanged at 3).
    static let clockRushBonus: TimeInterval = 3

    // MARK: Festival Night (milestone 8 round 5)
    /// Once the season's festival is lit (LmpSeason.festivalGoal regulars helped, or its last evening), the fireplace
    /// starts it: the whole village comes in for a multiball of this many balls, plunged in for you like the Rush's,
    /// with a longer save. Every shot is lit and pays festivalShotPoints on top; requests pay double; finds are rare or
    /// better. Back to one ball ends it. Once a season.
    static let festivalBalls = 3
    static let festivalSaveSeconds: TimeInterval = 15
    static let festivalShotPoints = 25_000
    /// The library ladder brings the last book down this long after the third falls.
    static let ladderDelay: TimeInterval = 0.7

    // MARK: Rules placeholders
    static let slingPoints = 10
    static let centerPostPoints = 50
    static let bannerSeconds: TimeInterval = 1.6

    /// The outer wall: the drain chute's left lip, the left apron slope, the straight left wall (no bulge: the
    /// deflector does its job), the arch, then the right side with its bulge down to the plunger lane.
    static var outerWall: [CGPoint] {
        var points: [CGPoint] = [
            CGPoint(x: drainEdgeX, y: drainLipY),
            CGPoint(x: drainEdgeX, y: drainEdgeY),
            CGPoint(x: leftWallX, y: apronTopY),
            CGPoint(x: leftWallX, y: archStartY),
        ]
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

/// A line the ball can cross (a switch), from Table 03's ramp switch: which way it was crossed, if at all.
struct LmpSwitch {
    enum Crossing { case none, forward, backward }

    let a: CGPoint
    let b: CGPoint
    let forward: CGVector
    /// How far past each end (as a fraction of its length) a crossing still counts. T5 M6 v2: the ramp's entry uses 0.
    var slack: CGFloat = 0.25

    func crossing(from p0: CGPoint, to p1: CGPoint) -> Crossing {
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let side0 = ab.dx * (p0.y - a.y) - ab.dy * (p0.x - a.x)
        let side1 = ab.dx * (p1.y - a.y) - ab.dy * (p1.x - a.x)
        guard (side0 > 0) != (side1 > 0) else { return .none }
        let t = side0 / (side0 - side1)
        let q = CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
        let u = ((q.x - a.x) * ab.dx + (q.y - a.y) * ab.dy) / max(ab.dx * ab.dx + ab.dy * ab.dy, 0.001)
        guard u >= -slack, u <= 1 + slack else { return .none }
        let along = (p1.x - p0.x) * forward.dx + (p1.y - p0.y) * forward.dy
        return along >= 0 ? .forward : .backward
    }
}
