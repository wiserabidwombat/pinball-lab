import CoreGraphics
import SpriteKit
import UIKit
import Foundation

// Pinball Lab Table 07 (CHOMP! The Terror of Calamity Island, Nov 2026): a comedy parody of a 2024 shark-movie table,
// same rules and layout with all-original art. Every Table 07 type is prefixed "Chomp" (the app bundle is flat). Plan:
// "Pinball Lab Table 07 — CHOMP! The Terror of Calamity Island — Table Plan" (claude.ai doc).
// Milestone 1: the Lab card and a grey box of the lower table, from Table 06's M1 (e023ac3): its walls, flippers,
// slings, lanes, plunger and gates, with Table 06 M2's real-table flippers. Changed: no rocket post, no lane letters,
// no side bulges; the left-outlane kickback is the inner tube save (the action button arms it for a moment). New: the
// inlane up-posts, the right outlane save (post + one-way gate), and the pier mini-flipper pocket on the right (feed
// lane, mini-lane switch, beach-ball bumper, buoy target). Checked in tools/chomp_render_m1.py (tools/chomp_layout.py).

/// All Table 06 geometry in world points. SpriteKit's origin is bottom-left.
/// Same 600 x 1300 world, radius-9 ball and physics as Tables 02–05 (every value proven on device there).
enum ChompTableLayout {
    static let worldSize = CGSize(width: 600, height: 1300)

    // MARK: Physics
    static let gravity: CGFloat = -9.2
    static let ballRadius: CGFloat = 9
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1
    /// Table 06 M2's real-table flippers need the higher cap (35 rad/s × 96 = 3,360 pt/s at the tip).
    static let maxBallSpeed: CGFloat = 3500
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
    static let leftBulgeControlInset: CGFloat = 0     // no bulges (Table 06 removed them 7 Nov; the pier pocket sits on the right)
    static let rightBulgeBottom: CGFloat = 540
    static let rightBulgeTop: CGFloat = 780
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
    /// Table 06 M2's real-table flippers (Aaron, 7 Nov 2026: "Love it"): 35 rad/s and a 0.3 rubber bounce.
    static let flipperUpSpeed: CGFloat = 35
    static let flipperRestitution: CGFloat = 0.3
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

    // MARK: Milestone 1: lanes, up-posts, the outlane saves and the pier mini-flipper pocket
    /// One rollover in each lane, left to right: left outlane, left inlane, right inlane, right outlane (plain lane
    /// switches: no letters; the inlanes will light the flip-flop smack multiplier in the rules milestone).
    static let laneLetters = ["", "", "", ""]
    static var laneRolloverXs: [CGFloat] {
        let outlane = (leftWallX + laneGuideX) / 2, inlane = (laneGuideX + leftSling.corner.x) / 2   // 37, 71
        return [outlane, inlane, mirrorSum - inlane, mirrorSum - outlane]
    }
    static let laneRolloverY: CGFloat = 405
    static let laneLampY: CGFloat = 378
    static let laneSensorSize = CGSize(width: 24, height: 10)
    /// Inlane up-posts: one mid-channel near the bottom of each inlane (34 pt wide there), so a raised post leaves
    /// 12 pt each side and the ball sits on it — they hold the ball while a mode starts. M1: the mini-lane arms them
    /// as a test (the next inlane ball is held for upPostHoldSeconds).
    static let upPostRadius: CGFloat = 5
    static let leftUpPost = CGPoint(x: 128, y: 295.7)
    static var rightUpPost: CGPoint { mirrored(leftUpPost) }
    static let upPostHoldSeconds: TimeInterval = 1.8

    /// The right outlane save: a small rubber post on the outer wall (27 pt to the lane guide, so the ball still
    /// passes) and a 32 pt one-way gate cut in the right lane guide: a ball the post turns back can roll through it into
    /// the inlane; nothing goes out that way (category diverter, solid while the ball moves right).
    static let outlaneSavePost = CGPoint(x: 544.5, y: 440)
    static let outlaneSavePostRadius: CGFloat = 3.5
    static let outlaneSavePostRestitution: CGFloat = 0.6
    static var saveGateX: CGFloat { mirrorSum - laneGuideX }          // 514
    static let saveGateTop: CGFloat = 425
    static let saveGateBottom: CGFloat = 393
    static var rightLaneGuideUpper: [CGPoint] { [CGPoint(x: saveGateX, y: laneGuideTop), CGPoint(x: saveGateX, y: saveGateTop)] }
    static var rightLaneGuideLower: [CGPoint] {
        [CGPoint(x: saveGateX, y: saveGateBottom)] + Array(rightLaneGuide.dropFirst())
    }

    /// The pier mini-flipper pocket on the right wall, above the right sling: the feed lane (x 514–548) comes down the
    /// wall onto the flipper's base; the flipper (on the right button) shoots up-left across the table, to the harpoon
    /// lane and the left bank (milestone 2). Same rest angle and travel as the main flippers.
    /// The pivot cap touches the wall (review, T7 M1 v1): at x 534 its 5 pt gap to the wall made a V a ball could rest in.
    static let miniFlipperPivot = CGPoint(x: 539, y: 596)
    static let miniFlipperLength: CGFloat = 56
    static let miniFlipperPivotRadius: CGFloat = 9
    static let miniFlipperTipRadius: CGFloat = 5
    static let feedLaneInner = [CGPoint(x: 514, y: 790), CGPoint(x: 514, y: 660)]
    static let pocketFloor = [CGPoint(x: laneWallX, y: 575), CGPoint(x: 541, y: 585)]
    /// M1 v2 (Aaron: "The ball got stuck in the corner of the mini flipper"): a ball coming down the wall landed on
    /// the very top of the pivot cap, against the wall, and balanced there. M1 v3 (Aaron: v2's long deflector "feels
    /// excessive… smaller like the one underneath"): a 17 pt cap over the corner, from the wall down onto the pivot
    /// cap's surface at 120° (its left shoulder), so wall → cap → blade is one slope with no top to balance on. At rest
    /// a ball rolls off the tip; held up it sits at ~(536, 617) on this cap and the blade, and rolls off when the
    /// button is let go (tools/chomp_pocket_sim.py).
    static let pocketDeflector = [CGPoint(x: laneWallX, y: 614), CGPoint(x: 534.5, y: 603.8)]
    /// The mini-lane switch in the feed lane (skill shot 2, fish finder and quickshots later).
    static let miniLaneSwitch = CGPoint(x: 531, y: 700)
    /// The beach-ball bumper and the buoy target above the pocket.
    static let bumperCenter = CGPoint(x: 462, y: 752)
    static let bumperRadius: CGFloat = 22
    static let bumperKickSpeed: CGFloat = 1150
    static let buoyCenter = CGPoint(x: 452, y: 690)
    static let buoyFacingDegrees: CGFloat = 205
    static let buoySize = CGSize(width: 26, height: 8)
    /// Two buoy hits this close together light the inner tube.
    static let buoyDoubleHitWindow: TimeInterval = 2

    // MARK: Rules (milestone 1: slings and lanes score; the tour comes in milestone 7)
    static let ballsPerGame = 3
    static let bannerSeconds: TimeInterval = 1.6
    /// The inner tube save (the kickback's kicker): lit = qualified; the action button arms it for innerTubeArmSeconds,
    /// and a ball falling past the trigger while armed is fired back up. One press per innerTubeCooldown.
    /// M1 scaffolding: lit at the start of every ball (the rules qualify it with the buoy).
    static let kickbackLamp = CGPoint(x: 37, y: 300)
    static let innerTubeArmSeconds: TimeInterval = 0.6
    static let innerTubeCooldown: TimeInterval = 1.5
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
