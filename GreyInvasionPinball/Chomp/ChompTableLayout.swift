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
    static let flipperTravel: CGFloat = .pi / 3
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
    static let laneWallTop: CGFloat = 955
    static var gateLow: CGPoint { CGPoint(x: laneWallX, y: laneWallTop) }
    static var gateHigh: CGPoint { CGPoint(x: rightWallX, y: laneWallTop + 28) }

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
    static let bumperCenter = CGPoint(x: 462, y: 752)
    static let bumperRadius: CGFloat = 22
    static let bumperKickSpeed: CGFloat = 1150
    static let buoyCenter = CGPoint(x: 452, y: 690)
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
    /// The block right of the lane (x 197–233) up to the ramp's entrance, its bottom a half-round, centre (215, 950) r 18.
    static let waveEndCentre = CGPoint(x: 215, y: 950)
    static let waveEndRadius: CGFloat = 18
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
        p.line(380)                                  // down to the pier block
        return p
    }
    /// The top of the over-the-top bend (heading 0): plastic up to here, wire after; made 10 pt past it.
    static var waveApexDistance: CGFloat { waveChannel.length + 70 * 55 * .pi / 180 + 110 + 55 * 35 * .pi / 180 }
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
