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
    /// M2 v14 (Aaron: "If the ball is falling too fast but it's makeable on a real table, is the gravity too high?" →
    /// "Yes please"): a real rolling ball. A playfield tilted ~6.5° pulls along it at 9.81 × sin 6.5° ≈ 1.11 m/s²; a
    /// rolling ball speeds up at 5/7 of that (our 2D ball slides, so it gets all of it) ≈ 0.79 m/s²; at this table's
    /// real scale (28.9 pt/in ≈ 1,138 pt/m) that's ~900 pt/s², = 6.0 here (SpriteKit: 150 pt per metre). Was 9.2
    /// (1,380 pt/s², every other table's).
    static let gravity: CGFloat = -6.0
    /// M2 v4 (Aaron: "Let's scale the ball up."): real scale. The table is traced from the Jaws Pro drawing at ~28.9 pt
    /// per inch (the real playfield ~585 pt / 20.25"), so the real 1-1/16" ball is ~30 pt: radius 15 (was 9, every
    /// earlier table's). The real flipper (pivot to tip, ~59 px × 1.355 on p. 40) is ~80 pt (was 96).
    static let ballRadius: CGFloat = 15
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
    static let rightWallX: CGFloat = 584      // M2 v4: shooter lane 548–584, 36 wide for the 30 pt ball (was 32)
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
    static let flipperLength: CGFloat = 80    // M2 v4: real scale (tip gap 59.4 pt, ~2 balls)
    static let flipperPivotRadius: CGFloat = 12
    static let flipperTipRadius: CGFloat = 6
    static let flipperRestAngle: CGFloat = .pi / 6
    /// M3 v3 (Aaron: "Option 1" — check our stroke against a real flipper): Visual Pinball's standard modern flipper
    /// rests at 121° and stops at 70° (VPX StartAngle / EndAngle defaults): 31° below horizontal up to 20° above, a 51°
    /// stroke. Ours swung 60° (to 30° above), which turns every flip shot ~10° further left at the stop.
    static let flipperTravel: CGFloat = 51 * .pi / 180
    /// Table 06 M2's real-table flippers (Aaron, 7 Nov 2026: "Love it"): 35 rad/s and a 0.3 rubber bounce.
    static let flipperUpSpeed: CGFloat = 35
    /// T7 M2 v9: the flipper carry (ChompFlipper.contactLaunch): a smooth, rate-independent launch model. Its fan
    /// probe is smooth, but it sends every ball met within ~50 pt of the pivot the same way (~94°, let go at the stop)
    /// and narrowed the shots (Shot Lab run 4); off until Aaron picks a direction. false = the physics catch + flip assist.
    static let flipperCarry = false
    /// T7 M2 v10 (Aaron: "What gets us the most realistic pinball physics?" → "Let's do it!"): the flipper model,
    /// Visual Pinball's approach. On the way up the flipper is driven by a coil that builds up (it doesn't jump to full
    /// speed), and a ball within its reach is the model's for that frame, not SpriteKit's: 0.5 ms sub-steps of the
    /// moving face against the ball, a rubber bounce that weakens on harder hits, and friction that rolls the ball along
    /// the face. Holding, cradling and the way down stay SpriteKit's. Starting values, to calibrate with the fan probe
    /// and Shot Lab (VPX guides: elasticity 0.88 with a little fall-off, friction 0.9, coil ramp-up 2.5).
    static let flipperModel = true
    /// Probe round 2: with a 40 rad/s top speed the face stopped speeding up ~16 ms in, the ball ran ahead of it and
    /// was caught again or not depending on where it started (jumps of 10–15°). A real coil pulls all the way to the
    /// stop, so: no top speed; the stop in 47 ms at 49.5 rad/s (tip 3,960 pt/s; the ball's own cap is 3,500).
    static let flipperCoilAccel: CGFloat = 1200          // rad/s² once the coil is fully on
    static let flipperCoilRamp: CGFloat = 0.006          // s: the coil reaches 63 % of full pull in this time
    static let flipperMaxSpeed: CGFloat = 1000           // rad/s: no top speed in practice
    static let flipperElasticity: CGFloat = 0.85         // bounce off the rubber at low speed
    static let flipperElasticityFalloff: CGFloat = 0.35  // per 1,000 pt/s of impact: 0.85 → 0.50 at 2,000 pt/s
    /// Probe round 3 (tools/flip/flipsim.py, the Python twin, swept): friction braked the ball rolling out along the
    /// face (the model has no spin, so rolling looked like slip), it never left before the stop and half the flipper
    /// shot ~62°. 0 = the ball rolls freely along the face, as a real rolling ball does.
    static let flipperRubberFriction: CGFloat = 0
    static let flipperBounceThreshold: CGFloat = 600     // pt/s: slower contacts don't bounce (a carried ball)
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
    /// M3 v12: the real plunger lane runs up the right side to the top (was 955); the gate sits at its top, where the
    /// curved top wall turns the plunge left toward the right ramp's entrance.
    static let laneWallTop: CGFloat = 1150
    /// M3 v13 (Aaron: "Fix the lane from the drawing"): on p. 40 the lane right of the reel leans right going up (its
    /// left edge x ~505 at y 1000 → ~536 at y 1200), and the plunger lane with it. Ours bends at y 900 from x 548–584 to
    /// 562–598 at its top (y 1150); its inner wall is the reel lane's right wall.
    static let laneBendY: CGFloat = 900
    static let laneTopInnerX: CGFloat = 562
    static let laneTopOuterX: CGFloat = 598
    /// M3 v14 (drop probe: a lane shot hit the old top wall nearly head-on, 2,500 → 830 pt/s): as on the real table,
    /// the wall BETWEEN the plunger lane and the reel lane curves left over the top (centre (482, 1150), r 80), so a
    /// ball riding the reel lane's right wall follows it round into the ramp mouth; the plunger lane curves round
    /// outside it (r 116), then spirals in (r 116 → 80 between 50° and 80°) through a one-way gate — the chord from
    /// the divider's end to the spiral's end — into the top of the reel lane, just before the mouth.
    static let turnCentre = CGPoint(x: 482, y: 1150)
    static let turnInnerR: CGFloat = 80
    static let turnOuterR: CGFloat = 116
    private static func turnPoint(_ r: CGFloat, _ deg: CGFloat) -> CGPoint {
        CGPoint(x: turnCentre.x + r * cos(deg * .pi / 180), y: turnCentre.y + r * sin(deg * .pi / 180))
    }
    /// The divider's curve, 0° → 50° (it starts at the lane's top (562, 1150)).
    static var dividerArc: [CGPoint] { stride(from: 0, through: 50, by: 5).map { turnPoint(turnInnerR, CGFloat($0)) } }
    /// The plunger lane's outer curve, 0° → 50° at r 116, then the spiral in to r ~81 at 80°.
    static var plungerOuterArc: [CGPoint] {
        stride(from: 0, through: 50, by: 5).map { turnPoint(turnOuterR, CGFloat($0)) }
            + stride(from: 53, through: 80, by: 3).map { (a: Int) -> CGPoint in
                turnPoint(turnOuterR - (turnOuterR - turnInnerR) * CGFloat(a - 50) / 31, CGFloat(a))
            }
    }
    /// M3 v14b: the one-way gate is an arc along r 80 from the divider's end (50°) to 80°, so a ball riding the turn
    /// keeps curving (a straight gate left it heading ~140° into the mouth's top corner); a short r 80 piece of the
    /// outer wall finishes the turn at 90° (482, 1230), where the ramp mouth starts heading west.
    static var gateArc: [CGPoint] { stride(from: 50, through: 80, by: 5).map { turnPoint(turnInnerR, CGFloat($0)) } }
    static var turnEnd: [CGPoint] { [turnPoint(turnInnerR, 90), turnPoint(turnInnerR, 85)] }
    static var gateLow: CGPoint { gateArc[0] }
    static var gateHigh: CGPoint { gateArc[gateArc.count - 1] }

    // MARK: Lower table: inlanes, outlanes, slingshots (left shown; right mirrors about x 284)
    static let mirrorSum: CGFloat = leftWallX + laneWallX   // 568
    static func mirrored(_ p: CGPoint) -> CGPoint { CGPoint(x: mirrorSum - p.x, y: p.y) }

    /// M2 v3 (Aaron: "Do it all. And match the left sling to the real table. Every table doesn't have to have the
    /// same slings or even drain layouts."): the lane guides, slings and outlane posts re-traced from the Jaws Pro
    /// drawing (p. 40). The real lower table is near-symmetric about x 284 too, but its guides are at x 74 / 494 and
    /// stop at y 405, and its slings sit ~34 pt further in and lower. (M1: guides x 54 / 514 to y 470, slings at 88.)
    /// With our smaller ball (18 pt; the real one would be ~30 at this scale) the lanes are roomier: inlanes 50 wide,
    /// outlanes 54.
    static let laneGuideX: CGFloat = 74
    static let laneGuideTop: CGFloat = 405
    static let laneGuideBend: CGFloat = 315
    static var leftLaneGuide: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd]
    }
    static var rightLaneGuide: [CGPoint] { leftLaneGuide.map { mirrored($0) } }

    static let leftSling = (top: CGPoint(x: 124, y: 425),
                            corner: CGPoint(x: 124, y: 355),
                            tip: CGPoint(x: 160, y: 320))
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
    static let leftOutlanePostTip = CGPoint(x: 64, y: 417)
    static var leftOutlanePostRail: [CGPoint] { [CGPoint(x: laneGuideX, y: laneGuideTop), leftOutlanePostTip] }
    static var rightOutlanePostRail: [CGPoint] { leftOutlanePostRail.map { mirrored($0) } }

    // MARK: Milestone 1: lanes, up-posts, the outlane saves and the pier mini-flipper pocket
    /// One rollover in each lane, left to right: left outlane, left inlane, right inlane, right outlane (plain lane
    /// switches: no letters; the inlanes will light the flip-flop smack multiplier in the rules milestone).
    static let laneLetters = ["", "", "", ""]
    static var laneRolloverXs: [CGFloat] {
        let outlane = (leftWallX + laneGuideX) / 2, inlane = (laneGuideX + leftSling.corner.x) / 2   // 47, 99
        return [outlane, inlane, mirrorSum - inlane, mirrorSum - outlane]
    }
    static let laneRolloverY: CGFloat = 370
    static let laneLampY: CGFloat = 343
    static let laneSensorSize = CGSize(width: 36, height: 10)   // M2 v3: 36 wide so a ball anywhere in the 50 pt lanes trips it
    /// Inlane up-posts: one mid-channel near the bottom of each inlane (34 pt wide there), so a raised post leaves
    /// 12 pt each side and the ball sits on it — they hold the ball while a mode starts. M1: the mini-lane arms them
    /// as a test (the next inlane ball is held for upPostHoldSeconds).
    /// M2 v3: at the (wider) inlane's narrowest point, sling tip to the guide's slant (55.6), r 12 → 15.8 pt each side.
    static let upPostRadius: CGFloat = 6      // M2 v4: 21.8 pt each side, under the 30 pt ball
    static let leftUpPost = CGPoint(x: 143.3, y: 297.8)
    static var rightUpPost: CGPoint { mirrored(leftUpPost) }
    static let upPostHoldSeconds: TimeInterval = 1.8

    /// The right outlane save: a small rubber post on the outer wall (the ball still passes it). M2 v16: the one-way
    /// gate that was cut in the right lane guide is gone — the real table has only the post (saves with a nudge).
    static let outlaneSavePost = CGPoint(x: 544.5, y: 400)
    static let outlaneSavePostRadius: CGFloat = 3.5
    static let outlaneSavePostRestitution: CGFloat = 0.6

    /// The pier mini-flipper. M2 v3 (Aaron: "Do it all"): exactly where the real one is (Jaws Pro drawing, p. 40):
    /// pivot (517, 533), length 51, hanging 64° below horizontal from the notch of a plastic block on the right wall,
    /// swinging 79° (to 15° above horizontal, so a held-up flipper traps a ball against the block — flip-lock later).
    /// Balls land on the block's nearly flat top, roll down its left edge onto the blade and off the tip onto the right
    /// lane guide's top (into the inlane or the outlane, as on the real table). Held up, a ball sits at ~(495, 555) and
    /// drops into the right inlane when let go (tools/chomp_pier_sim.py). (M2 v2 had it 12 pt right and 27 pt higher,
    /// before the lane guides were shortened.)
    static let miniFlipperPivot = CGPoint(x: 517, y: 533)
    static let miniFlipperLength: CGFloat = 51
    static let miniFlipperPivotRadius: CGFloat = 9
    static let miniFlipperTipRadius: CGFloat = 5
    static let miniFlipperRestAngle: CGFloat = 64 * .pi / 180
    static let miniFlipperTravel: CGFloat = 79 * .pi / 180
    /// The plastic block (closed): top (548, 618)→(519, 615) sheds left gently (steeper flew balls past the flipper;
    /// flat kept them), the left edge down to (503, 547), round the pivot cap (gaps 10.8 / 6.8 / 2.4: closed) and down
    /// the blade's right side to (514, 470); the right outlane's way in is under it (53 pt over the post rail tip).
    /// M2 v15 (pier probe: at real gravity the ball let down from the held flipper sat balanced on the block's
    /// lower-left corner at (503, 547) for over a second): the corner moves in to (511, 548), still closed on the cap
    /// (6.8 pt), so the dropped ball falls clear onto the flipper.
    static let pierPlastic = [CGPoint(x: 519, y: 615), CGPoint(x: laneWallX, y: 618), CGPoint(x: laneWallX, y: 470),
                              CGPoint(x: 514, y: 470), CGPoint(x: 528, y: 530), CGPoint(x: 522, y: 548),
                              CGPoint(x: 511, y: 548), CGPoint(x: 519, y: 615)]
    /// The mini-lane switch on the way down the block's left edge (skill shot 2, fish finder and quickshots later).
    static let miniLaneSwitch = CGPoint(x: 508, y: 590)
    /// The beach-ball bumper and the buoy target above the pocket.
    /// M3 v11 (Aaron: "Yep, let's move it"): toward the real spots (p. 40: the bumper disc ~(511, 687), the buoy — a round
    /// cyan target — ~(545, 646) below-right of it). Our right wall is x 548 (the real playfield runs to ~575 here), so
    /// the bumper sits 21 pt left of the real one to keep the mid flipper lane right of it 36 wide (x 512–548), and the
    /// buoy goes below-LEFT of it (below-right would sit in that lane and under the wave wire's drop). Both now clear the
    /// left flipper's 69–70° shots (the right ramp's), which the old buoy at (452, 690) stopped (was (462, 752) / (452, 690)).
    static let bumperCenter = CGPoint(x: 490, y: 687)
    static let bumperRadius: CGFloat = 22
    static let bumperKickSpeed: CGFloat = 1150
    static let buoyCenter = CGPoint(x: 468, y: 638)
    static let buoyFacingDegrees: CGFloat = 205
    static let buoySize = CGSize(width: 26, height: 8)
    /// Two buoy hits this close together light the inner tube.
    static let buoyDoubleHitWindow: TimeInterval = 2

    // MARK: Milestone 2 v1: the left side (tools/chomp_layout.py, checked in tools/chomp_render_m2.py)
    // Traced over the Jaws Pro manual's top-down drawing (p. 40), registered on the flippers: the harpoon lane down the
    // left wall (x 20–60), the left loop beside it (x 100–147) with a hairpin round the top of the tongue between them,
    // the spinner across the loop, the one-way quickshot gate where the pier flipper's shot enters the harpoon lane, the
    // harpoon lane's bottom deflector into the left inlane, and the Fish Phone 3-bank. A loop shot goes up the loop,
    // round the hairpin and down the harpoon lane to the left inlane (the real game's "harpoon shot fed by the left
    // orbit"); the pier flipper shoots straight into the harpoon lane through the gate.
    static let harpoonX: CGFloat = 60
    /// M2 v13 (Aaron: "Yes please" — the harpoon is "a makeable shot from the right mini flipper" on the real table;
    /// ours made it 1–2 times in 96): the wall stops at y 760 and the one-way gate above it is twice as tall (760–920), so
    /// it takes the pier flipper's ~137–148° shots instead of only ~137–141°.
    /// v13b (Shot Lab run 9: 150° shots hit the wall's top at 760): down to 720, the gate 720–920.
    static var harpoonInner: [CGPoint] { [CGPoint(x: harpoonX, y: 580), CGPoint(x: harpoonX, y: 720)] }
    /// One-way (category diverter, solid while the ball moves right, like the outlane save gate): in from the right only.
    static var quickshotGate: (a: CGPoint, b: CGPoint) { (CGPoint(x: harpoonX, y: 720), CGPoint(x: harpoonX, y: 920)) }
    /// The tongue between the harpoon lane and the loop: a closed outline with a round top (centre (80, 1040), r 20;
    /// M2 v4 lowered it 40 pt so the harpoon lane beside it stays ≥ 37 wide under the arch for the 30 pt ball).
    /// M2 v7 (Shot Lab run 1: loop shots, 106–108° and drifting left, clipped the tongue's bottom-right corner at
    /// (100, 920)): the tongue is narrower, x 60–88, so the loop channel is 59 wide.
    static let tongueRightX: CGFloat = 88
    static var tongue: [CGPoint] {
        let r = (tongueRightX - harpoonX) / 2, cx = harpoonX + r
        var pts = [CGPoint(x: harpoonX, y: 920), CGPoint(x: harpoonX, y: 1040)]
        for i in 1...11 {
            let a = CGFloat.pi - CGFloat.pi * CGFloat(i) / 12
            pts.append(CGPoint(x: cx + r * cos(a), y: 1040 + r * sin(a)))
        }
        pts += [CGPoint(x: tongueRightX, y: 1040), CGPoint(x: tongueRightX, y: 920), CGPoint(x: harpoonX, y: 920)]
        return pts
    }
    /// The point of the outer wall's top-left arch at x (the arch is x = 20 + 280 t², y = 1000 + 270 (1 − (1 − t)²)).
    static func archPoint(atX x: CGFloat) -> CGPoint {
        let t = sqrt((x - leftWallX) / 280)
        return CGPoint(x: x, y: archStartY + 270 * (1 - (1 - t) * (1 - t)))
    }
    /// The loop's right wall: up x 147, closing on the arch at x 157. M2 v5: its mouth flare is gone; its bottom end at
    /// (147, 885) is the post shared with the wave ramp's mouth beside it (as on the real table).
    static var loopRight: [CGPoint] {
        [CGPoint(x: 147, y: 885), CGPoint(x: 147, y: 1180), archPoint(atX: 157)]
    }

    // MARK: Milestone 2 v5: the wave ramp (the real table's Left Metal Ramp)

    /// Ramp values from Table 06 / Monsoon (ChompRamp is their copy).
    static let rampEntryDistance: CGFloat = 12
    static let rampMadeAfterApex: CGFloat = 10
    static let rampExitBeforeEnd: CGFloat = 15
    static let rampFriction: CGFloat = 0.05
    static let rampRestitution: CGFloat = 0.1
    static let rampTopHeight: CGFloat = 40
    static let rampRiseLength: CGFloat = 110
    static let rampEndHeight: CGFloat = 12
    /// Traced over p. 40 (tools/chomp_layout.py wave_path, tools/chomp_render_m2.py): the mouth sits right beside the
    /// loop behind their shared post, the ramp runs straight up the channel, bends right over the top-left and climbs
    /// as plastic toward the top centre; past the top a wire runs down-right and then straight down the right side,
    /// dropping the ball at (524, 671) onto the pier flipper's plastic block, which rolls it onto the pier flipper
    /// (tools/chomp_wave_exit_sim.py: into the right inlane at rest, held by a raised pier flipper, at any exit speed).
    /// M2 v11 (Aaron: does the angled mouth match the real table? → "Yep, let's do it now that we have the new flipper
    /// modifications"): the real layout. The channel runs straight up between the post shared with the loop (its wall
    /// down to y 870) and a wall on its right that stops higher, at y 945, with a rounded end — a staggered opening that
    /// takes shots coming up-left from the right flipper under the right wall's end. Those floor walls guide the ball
    /// into the 42 pt lane; the plastic ramp (its entrance flap) starts at y 1000. (v7 leaned the whole mouth 10° right
    /// with its right post at (222, 871), in what is open floor on the real table.)
    /// M2 v12 (Aaron: "Option 1"; Shot Lab run 7: 2 / 0 from the right flipper with the 42 lane and a 5 pt post): the
    /// lane is 46 wide (the real channel ~45) and the right wall ends in the real table's fat rounded block, so a ball
    /// that clips it is turned into the lane instead of bouncing out.
    static let waveMouth = CGPoint(x: 174, y: 1000)
    static let waveMouthHalfWidth: CGFloat = 23        // the lane: 46 wide
    static let waveHalfWidth: CGFloat = 23
    static let waveFlareLength: CGFloat = 40
    /// The low end (y 1000–1060) is solid for floor balls: a U open only at the mouth.
    static let waveLowLength: CGFloat = 60
    static let waveLaneLeft = [CGPoint(x: 151, y: 870), CGPoint(x: 151, y: 1000)]
    /// The block right of the lane (x 197–228) up to the ramp's entrance, its bottom a half-round, centre (212.5, 950)
    /// r 15.5. M3 v2: its right edge traced at x 228 (was 233, so the center ramp's entrance is the real width).
    static let waveEndCentre = CGPoint(x: 212.5, y: 950)
    static let waveEndRadius: CGFloat = 15.5
    static var waveRightBlock: [CGPoint] {
        let c = waveEndCentre, r = waveEndRadius
        var pts = [CGPoint(x: c.x - r, y: 1000), CGPoint(x: c.x - r, y: c.y)]
        for i in 1...11 {
            let a = CGFloat.pi + CGFloat.pi * CGFloat(i) / 12
            pts.append(CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        pts += [CGPoint(x: c.x + r, y: c.y), CGPoint(x: c.x + r, y: 1000), CGPoint(x: c.x - r, y: 1000)]
        return pts
    }
    /// The path up to the top of the channel (y 1100).
    private static var waveChannel: ChompRampPath {
        var p = ChompRampPath(start: waveMouth, heading: .pi / 2)
        p.line(100)
        return p
    }
    static var wavePath: ChompRampPath {
        var p = waveChannel
        p.arc(radius: 70, turn: -55 * .pi / 180)     // bend right over the top-left
        p.line(110)                                  // the plastic ramp climbing toward the top centre
        p.arc(radius: 55, turn: -75 * .pi / 180)     // over the top: heading −40° (down-right)
        p.line(185)                                  // the wire across the upper right
        p.arc(radius: 60, turn: -50 * .pi / 180)     // turn straight down the right side
        p.line(412.6)                                // down to the pier block (M3 v11: to y 640, below the moved bumper)
        return p
    }
    /// The top of the over-the-top bend (heading 0): plastic up to here, wire after; made 10 pt past it.
    static var waveApexDistance: CGFloat { waveChannel.length + 70 * 55 * .pi / 180 + 110 + 55 * 35 * .pi / 180 }

    // MARK: Milestone 3 v1: the center ramp
    /// Traced over p. 40 (tools/chomp_layout.py center_path, tools/chomp_render_m3.py): a lane x ~236–282 right of the
    /// wave ramp's block, entrance y 1000; the ramp climbs the lane, turns round at the top and its wire comes back
    /// down the left side into the left inlane ("the easiest shot in the game", U-turn → left flipper). The real return
    /// wire is stacked over the climb; in 2D the U-turn (r 24) sets it beside it, 48 pt left, then it bends down-left
    /// and runs straight down over the left inlane (x 99), ending at y 440 above the guide's top (405).
    /// Its own wire level (lowWire categories), so it never touches the wave ramp's rails where they cross.
    /// M3 v2 (Aaron: "Is it flared on the actual table?" → "Yes please!" to tracing it): the real entrance flap is at
    /// y ~1020 and ~52 wide (x 228–280); below it a short funnel — the block's edge on the left (x 228) and a rubber post
    /// at (300, 1000) on the right with the wall slanting in from it — 66 pt across where the ball arrives at y 1000.
    static let centerMouth = CGPoint(x: 254, y: 1020)
    static let centerMouthHalfWidth: CGFloat = 26        // the flap: 52 wide
    static let centerHalfWidth: CGFloat = 20             // narrows to 40 by the top (the U-turn and the wire)
    static let centerFlareLength: CGFloat = 110
    static let centerLowLength: CGFloat = 60             // the floor-solid U at the low end (y 1020–1080)
    static let centerJamb = [CGPoint(x: 228, y: 1000), CGPoint(x: 228, y: 1020)]       // the block's edge up to the flap
    static let centerPost = CGPoint(x: 300, y: 1000)
    static let centerPostRadius: CGFloat = 6
    static let centerFunnel = [CGPoint(x: 296, y: 1004.5), CGPoint(x: 280, y: 1020)]   // post → the ramp's right rail
    static let centerClimb: CGFloat = 110
    static let centerTurnRadius: CGFloat = 24
    static var centerPath: ChompRampPath {
        var p = ChompRampPath(start: centerMouth, heading: .pi / 2)
        p.line(centerClimb)                                  // up the lane (the plastic)
        p.arc(radius: centerTurnRadius, turn: .pi)           // the U-turn to the left: apex at its top
        p.line(p.points[p.points.count - 1].y - 870)         // the wire straight down beside the climb
        p.arc(radius: 80, turn: -40 * .pi / 180)             // bend down-left
        p.line(108)
        p.arc(radius: 80, turn: 40 * .pi / 180)              // straight down again, over the left inlane
        let end = p.points[p.points.count - 1]
        p.line(end.y - 440)                                  // down to y 440, over the inlane's mouth
        return p
    }
    /// The top of the U-turn (heading 180°): plastic up to here, wire after; made 10 pt past it.
    static var centerApexDistance: CGFloat { centerClimb + centerTurnRadius * .pi / 2 }

    // MARK: Milestone 3 v10: the right ramp
    /// p. 40 part 9 ("Wire Ramp Right") and p. 60's Right Ramp Assembly (a riveted J-hook with a made opto): the entrance
    /// is the tight wooden lane right of the reel's block (real x ~505–545); the ramp climbs straight up, hooks 180° to
    /// the left (apex = made) and its wire comes straight back down over the reel and the right side into the right
    /// inlane (x 469 = the center ramp's x 99 mirrored), ending at y 440 → the right flipper. Its own wire level.
    /// M3 v12 (Aaron: "as realistic as possible"; p. 17's switch map: the made opto is at the very top): the ramp's
    /// entrance is at the TOP of the reel lane (x 510–548). A shot up that lane, or a strong plunge, follows the curved
    /// top wall left into the mouth heading west at (494, 1211); the ramp climbs up-left, hooks right over its own
    /// climb (made at the hook's top) and runs east along the top, then down the right side (x 552, over the plunger
    /// lane) and jogs left over the pier block into the right inlane (469, 440) → the right flipper.
    static let outerArcCentre = CGPoint(x: 518, y: 1150)     // M3 v13: moved right with the leaning lanes (was 504)
    static let outerArcRadius: CGFloat = 80
    static let outerTopY: CGFloat = 1230
    static let rightMouth = CGPoint(x: 480, y: 1211)     // M3 v14b: at the turn's end (was 494); upper rail y 1230
    static let rightMouthHalfWidth: CGFloat = 19
    static let rightHalfWidth: CGFloat = 19
    static let rightFlareLength: CGFloat = 40
    /// The floor-solid U at the mouth (8 pt over a ball on the roof). M3 v14d: 60 (was 30) — a ball at ~1,900 pt/s moves
    /// 16 pt per 120 Hz step, so with 30 its front hit the U's back before the entry switch (s 12) put it on the ramp.
    static let rightLowLength: CGFloat = 60
    static var rightPath: ChompRampPath {
        var p = ChompRampPath(start: rightMouth, heading: .pi)
        p.line(10)
        p.arc(radius: 60, turn: -50 * .pi / 180)             // up-left (M3 v14c: r 60, was r 30 / 60°, which stopped a
                                                             // ball arriving at ~1,600 pt/s dead on its rail)
        p.arc(radius: 28, turn: -130 * .pi / 180)            // the hook over the top: heading east
        p.line(552 - 30 - p.points[p.points.count - 1].x)
        p.arc(radius: 30, turn: -.pi / 2)                    // straight down the right side, x 552
        p.line(p.points[p.points.count - 1].y - 598)        // (598: the jog drops 157.2, so the last line stays positive)
        p.arc(radius: 80, turn: -40 * .pi / 180)             // jog left over the pier block
        p.line(71)
        p.arc(radius: 80, turn: 40 * .pi / 180)
        p.line(max(0, p.points[p.points.count - 1].y - 440))  // into the right inlane
        return p
    }
    /// The hook's top (heading 90°): made 10 pt past it.
    static var rightApexDistance: CGFloat { 10 + 60 * 50 * .pi / 180 + 28 * 40 * .pi / 180 }
    /// (M3 v10b: the plastic over the ramp's base is part of `reelRightBlock`.)

    // MARK: Milestone 3 v4: the boat captive ball
    /// p. 40: the boat's housing is x ~305–395, from the playfield at y ~985 up to ~1130, open at the bottom; a steel
    /// captive ball sits in its mouth at ~(350, 1005) under the shark/boat target (the silver cone, tip at y ~1020).
    /// Ours: Monsoon's captive ball (ChompCaptiveBall) in a 34 pt channel up the middle of the housing — mouth posts
    /// 26 pt apart, so the captive ball shows through and a player ball can't get in; driven 41 pt up it hits the
    /// boat target at the top. The housing's outline wraps the channel; its lower-left corner is the center ramp's
    /// rubber post (300, 1000).
    static let boatMouth = CGPoint(x: 350, y: 1000)
    /// M3 v5 (Aaron: "Do option 1"): the target moved down to the real cone's tip — the slot ends 42 pt up, so the
    /// captive ball (resting 10 pt up) scores after ~13 pt of travel (reachedTop: travel > length − r − 4) and stops
    /// against the cone, as on the real table, instead of needing 41 pt (glancing hits now count).
    static let boatChannelLength: CGFloat = 42
    /// M3 v7 (Aaron: "Widen the mouth to match the real table"): the real cradle — rubber posts r 5 at the mouth's
    /// corners (x 318 / 382, 54 pt apart inside), a 64 pt cradle up to the cone, and a curved wire lip dipping to
    /// y 993 that holds the captive ball in (only the captive ball meets it; it rests at ~(350, 1008), as on p. 40).
    static let boatHalfWidth: CGFloat = 32
    static let boatPostRadius: CGFloat = 5
    static let boatLip = [CGPoint(x: 318, y: 1000), CGPoint(x: 334, y: 995), CGPoint(x: 350, y: 993),
                          CGPoint(x: 366, y: 995), CGPoint(x: 382, y: 1000)]
    /// M3 v9: its top lies on the shared roof (`roofY`), so a ball landing on it rolls on to the right.
    static var boatHousing: [CGPoint] {
        [CGPoint(x: 318, y: 1000), CGPoint(x: 305, y: 1000), CGPoint(x: 305, y: roofY(305)),
         CGPoint(x: 395, y: roofY(395)), CGPoint(x: 395, y: 1000), CGPoint(x: 382, y: 1000)]
    }

    // MARK: Milestone 3 v8: the real plastics that close the stuck-ball traps
    /// Aaron's stuck-ball test (Shot Lab scatter) found balls resting for good where the real table has solid blue
    /// plastic (p. 40). The island behind the ramp entrances: from the loop's right wall over the wave ramp's low U,
    /// the gap between the ramps (21 of 48 stuck drops), the center ramp's low U and its corner by the boat housing,
    /// its top a roof sloping from the loop wall's top (147, 1180) down to the housing (12.5°), so nothing rests on it.
    static var rampIsland: [CGPoint] {
        [CGPoint(x: 147, y: 1060), CGPoint(x: 197, y: 1060), CGPoint(x: 197, y: 1000), CGPoint(x: 228, y: 1000),
         CGPoint(x: 228, y: 1020), CGPoint(x: 231, y: 1080), CGPoint(x: 282, y: 1080), CGPoint(x: 305, y: 1100),
         CGPoint(x: 305, y: roofY(305)), CGPoint(x: 147, y: roofY(147)), CGPoint(x: 147, y: 1060)]
    }

    // MARK: Milestone 3 v9: the fishing reel
    /// One roof over the island, the boat housing and the reel's blocks (M3 v9): from the loop wall's top (147, 1185)
    /// down to (510, 1150) at 5.5°, where a ball rolls off into the open right side (the real mid flipper lane).
    static func roofY(_ x: CGFloat) -> CGFloat { 1185 - 35 * (x - 147) / 363 }
    /// p. 40 (and the manual's "Fishing Reel Spinner Top Assembly"): a keyhole lane right of the boat — mouth x 426–500
    /// at y ~980, sides to x 433 / 499, a round end centre (466, 1100) r 48 — under a spinning disc (r 42) the passing
    /// ball turns ("stronger shots to the reel mean more spins"). The blue plastic either side is solid.
    static let reelCentre = CGPoint(x: 466, y: 1100)
    static let reelRadius: CGFloat = 48
    static let reelDiscRadius: CGFloat = 42
    private static func reelArc(_ a0: CGFloat, _ a1: CGFloat, n: Int = 16) -> [CGPoint] {
        (0...n).map { i in
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)) * .pi / 180
            return CGPoint(x: reelCentre.x + reelRadius * cos(a), y: reelCentre.y + reelRadius * sin(a))
        }
    }
    private static var reelLeftAngle: CGFloat { atan2(1065 - reelCentre.y, 433 - reelCentre.x) * 180 / .pi + 360 }   // 226.7
    private static var reelRightAngle: CGFloat { atan2(1065 - reelCentre.y, 499 - reelCentre.x) * 180 / .pi }       // −46.7
    static var reelLeftBlock: [CGPoint] {
        [CGPoint(x: 395, y: 1000), CGPoint(x: 395, y: 978), CGPoint(x: 426, y: 978), CGPoint(x: 433, y: 1043),
         CGPoint(x: 433, y: 1065)] + reelArc(reelLeftAngle, 120)     // M3 v10b: stops at the drain hole's left edge
            + [CGPoint(x: 442, y: roofY(442)), CGPoint(x: 395, y: roofY(395)), CGPoint(x: 395, y: 1000)]
    }
    /// M3 v10b (stuck test: 10 drops rested at (524, 1165), in the V between the roof over the right ramp's base and the
    /// arch): the right block now also covers the right ramp's base (x 510–548 above its low U), and its roof slopes
    /// DOWN TO THE LEFT from the arch (548, 1150) to the drain hole over the reel's round end (x 442–490, 48 wide), so
    /// every ball on the roof drops into the reel's keyhole and rolls out of its lane.
    /// M3 v11b (stuck test: 2 balls from the top ended INSIDE this block, squeezed past its corner (548, 1150) through
    /// the 4 pt gap to the arch): the corner is now at (548, 1164), above where the arch crosses x 548 (y ~1158), so the roof and the block's
    /// edge both cross the arch and leave no gap and no corner inside the playfield.
    static var reelRightBlock: [CGPoint] {
        let arc = reelArc(60, reelRightAngle)
        return arc + [CGPoint(x: 499, y: 1043), CGPoint(x: 500, y: 983), CGPoint(x: 505, y: 983),
                      CGPoint(x: 522, y: 1150), arc[0]]       // M3 v13: the lane's left wall leans (x 505 → 522)      // M3 v12: the reel lane is open again (x 510–548)
    }
    /// Into the round end, going up: the ball reaches the disc.
    static let reelSwitch = ChompSwitch(a: CGPoint(x: 433, y: 1065), b: CGPoint(x: 499, y: 1065), forward: CGVector(dx: 0, dy: 1))
    /// The plastic behind the Fish Phone bank, between the harpoon lane's inner wall and the bank's backboard
    /// (7 stuck drops in the V), its top sloping down-right (26°).
    static let bankWedge = [CGPoint(x: 58.8, y: 599.1), CGPoint(x: 100.8, y: 671.9), CGPoint(x: 100.8, y: 700),
                            CGPoint(x: 60, y: 720), CGPoint(x: 58.8, y: 599.1)]
    /// Sends harpoon-lane balls on into the left inlane (M2 v3: ends over the wider inlane, 96 pt above the guide's
    /// top); balls from the playfield still reach the left outlane under it.
    static let harpoonDeflector = [CGPoint(x: 20, y: 560), CGPoint(x: 90, y: 500)]
    static let spinnerLine = (a: CGPoint(x: tongueRightX, y: 960), b: CGPoint(x: 147, y: 960))
    static let spinnerSwitch = ChompSwitch(a: spinnerLine.a, b: spinnerLine.b, forward: CGVector(dx: 0, dy: 1))
    static let loopEntranceSwitch = ChompSwitch(a: CGPoint(x: tongueRightX, y: 1020), b: CGPoint(x: 147, y: 1020),
                                                forward: CGVector(dx: 0, dy: 1))
    /// The quickshot rollovers in the harpoon lane: top, mid, bottom.
    static let quickshotSwitches = [CGPoint(x: 40, y: 1000), CGPoint(x: 40, y: 870), CGPoint(x: 40, y: 600)]
    /// The Fish Phone 3-bank: standups on a backboard against the harpoon lane wall, facing down-right (−30°) toward the
    /// right flipper and the pier flipper.
    static let bankNormalDegrees: CGFloat = -30
    static let bankTargetSize = CGSize(width: 26, height: 8)
    static var bankCenters: [CGPoint] {
        let t = (bankNormalDegrees + 90) * .pi / 180
        return (0..<3).map { CGPoint(x: 72 + CGFloat($0) * 26 * cos(t), y: 610 + CGFloat($0) * 26 * sin(t)) }
    }
    static var bankBackboard: [CGPoint] {
        let t = (bankNormalDegrees + 90) * .pi / 180, n = bankNormalDegrees * .pi / 180
        let a = bankCenters[0], b = bankCenters[2]
        let off = CGVector(dx: -6 * cos(n), dy: -6 * sin(n))
        return [CGPoint(x: a.x - 16 * cos(t) + off.dx, y: a.y - 16 * sin(t) + off.dy),
                CGPoint(x: b.x + 16 * cos(t) + off.dx, y: b.y + 16 * sin(t) + off.dy)]
    }
    /// The spinner's rendered frames, when the art comes (none yet: ChompSpinner draws its blade).
    static let spinnerArtBox = CGRect(x: -22, y: -10, width: 44, height: 32)
    static let spinnerFrames = (columns: 6, rows: 4)

    // MARK: Rules (milestone 1: slings and lanes score; the tour comes in milestone 7)
    static let ballsPerGame = 3
    static let bannerSeconds: TimeInterval = 1.6
    /// The inner tube save (the kickback's kicker): lit = qualified; the action button arms it for innerTubeArmSeconds,
    /// and a ball falling past the trigger while armed is fired back up. One press per innerTubeCooldown.
    /// M1 scaffolding: lit at the start of every ball (the rules qualify it with the buoy).
    static let kickbackLamp = CGPoint(x: 47, y: 300)
    static let innerTubeArmSeconds: TimeInterval = 0.6
    static let innerTubeCooldown: TimeInterval = 1.5
    static let kickbackMaxX: CGFloat = 74          // M2 v3: the left outlane is x 20–74
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
        // M3 v12: the arch's right half is cut where it crosses y 1230; a straight top wall and a curve (centre
        // outerArcCentre, r 80) turn the plunger lane and the reel lane left into the right ramp's entrance.
        let rightArch = quadCurve(from: CGPoint(x: midX, y: topY), control: CGPoint(x: rightWallX, y: topY),
                                  to: CGPoint(x: rightWallX, y: archStartY), segments: 64)
        var previous = CGPoint(x: midX, y: topY)
        for p in rightArch {
            if p.y < outerTopY {
                let t = (previous.y - outerTopY) / (previous.y - p.y)
                points.append(CGPoint(x: previous.x + t * (p.x - previous.x), y: outerTopY))
                break
            }
            points.append(p)
            previous = p
        }
        points += turnEnd                                        // M3 v14b: the turn's end, 90° → 85°
        points += plungerOuterArc.reversed()                    // M3 v14: the spiral, then the plunger lane's curve
        points.append(CGPoint(x: rightWallX, y: laneBendY))   // M3 v13: the plunger lane's outer wall leans out to x 598
        points += [
            CGPoint(x: rightWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: rightBulgeBottom),
        ]
        points += quadCurve(from: CGPoint(x: laneWallX, y: rightBulgeBottom),
                            control: CGPoint(x: laneWallX - rightBulgeControlInset,
                                             y: (rightBulgeBottom + rightBulgeTop) / 2),
                            to: CGPoint(x: laneWallX, y: rightBulgeTop))
        points.append(CGPoint(x: laneWallX, y: laneBendY))      // M3 v13: the inner wall leans out to x 562 at its top
        points.append(CGPoint(x: laneTopInnerX, y: laneWallTop))
        points += dividerArc.dropFirst()                       // M3 v14: the divider curves left over the top
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

// MARK: - Milestone 3 v15: the fin
extension ChompTableLayout {
    /// The fin's slot, traced off p. 40 (the white slot in the cyan kidney right of centre): from its upper-left end
    /// over the top and down to its lower-right end above the bumper.
    static let finSlot: [CGPoint] = [
        CGPoint(x: 313, y: 841), CGPoint(x: 329, y: 848), CGPoint(x: 349.5, y: 854.6), CGPoint(x: 369.7, y: 858.7),
        CGPoint(x: 394, y: 860), CGPoint(x: 407.6, y: 857), CGPoint(x: 421, y: 853), CGPoint(x: 445, y: 843.7),
        CGPoint(x: 459, y: 833), CGPoint(x: 472, y: 818), CGPoint(x: 483, y: 802), CGPoint(x: 490, y: 785),
        CGPoint(x: 494.6, y: 769),
    ]
    /// The fin's centre travels s 15…215 of the slot's 229.5 (tools/fin_geom.py: the blade stays ≥ 53 off the bumper's
    /// rubber and ≥ 46 off the plunger lane's wall, so a ball passes it everywhere).
    static let finMinS: CGFloat = 15
    static let finMaxS: CGFloat = 215
    /// The blade (top view), along the slot: about the real carriage's size.
    static let finLength: CGFloat = 40
    static let finThickness: CGFloat = 10
    /// Placeholders until the rules (M4): roams 35 pt/s (~6 s end to end); a hit drops it, up again after 6 s.
    static let finRoamSpeed: CGFloat = 35
    static let finRelightTime: TimeInterval = 6
}

// MARK: - Milestone 3 v16: the chum bucket
extension ChompTableLayout {
    /// Over the rounded nose of the block between the wave and center ramps (the Pro's hanging bucket target, p. 40's
    /// ring at ~(213, 963)); 1 pt wider than the nose so a ball meets the target, not the wall under it.
    static let chumBucketCentre = waveEndCentre
    static let chumBucketRadius: CGFloat = waveEndRadius + 1
}
