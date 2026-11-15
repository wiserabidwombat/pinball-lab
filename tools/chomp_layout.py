"""Table 07 (CHOMP!) layout in Python, milestone 1: the lower table.
Base = Table 06's lower table (tour_layout.py, Monsoon's proven walls/flippers/slings), changed to match Jaws:
  removed: the rocket post between the flippers, the O-R-B-T letters (plain lane switches stay)
  changed: the left-outlane kickback -> the inner tube save (same kicker, action button in a timed window)
  added:   inlane up-posts, the right outlane save (rubber post + one-way gate), the pier mini-flipper pocket
           (feed lane, mini-flipper, beach-ball bumper, buoy target) on the right side.
First-pass positions from Jaws photos/rulesheets; tune with renders + the Shot Lab."""
import math
from chomp_base_tour_layout import (W, H, leftWallX, rightWallX, laneWallX, laneFloorY, archStartY, topY, apronTopY,
                         drainEdgeX, drainEdgeY, drainLipY, laneWallTop, mirrorSum, ballRadius,
                         leftFlipperPivot, rightFlipperPivot, flipperLength, flipperPivotRadius, flipperTipRadius,
                         flipperRestAngle, mirrored, outer_wall, leftLaneGuide, rightLaneGuide, leftOutlaneWall,
                         rightOutlaneWall, leftOutlanePostRail, rightOutlanePostRail, rightApron, leftSling,
                         rightSling, laneRolloverY, laneRolloverXs, laneSensorSize, flipper_tip, laneGuideX, guide_end)

# ---- Inlane up-posts: one near the bottom of each inlane, in the middle of the channel between the lane guide's
# slanted leg and the sling's bottom edge. Ball sits on it; the gaps either side are < 1 ball diameter.
def _inlane_center(x):
    g0, g1 = leftLaneGuide[1], leftLaneGuide[2]          # guide's slanted leg
    s0, s1 = leftSling[1], leftSling[2]                  # sling's bottom edge
    gy = g0[1] + (g1[1] - g0[1]) * (x - g0[0]) / (g1[0] - g0[0])
    sy = s0[1] + (s1[1] - s0[1]) * (x - s0[0]) / (s1[0] - s0[0])
    return (x, (gy + sy) / 2)
upPostRadius = 5
leftUpPost = _inlane_center(128)
rightUpPost = mirrored(leftUpPost)

# ---- Left outlane: the inner tube save. Tour's kickback kicker, armed only while the action button window is open.
innerTubeLamp = (37, 300)
innerTubeWindow = 0.6          # s the insert flashes after the outlane switch (first award: grace, later shorter)

# ---- Right outlane save: a rubber post against the outer wall, and a one-way gate in the right lane guide.
outlaneSavePost = (544.5, 440)
outlaneSavePostRadius = 3.5
saveGateTopY, saveGateBottomY = 425, 393     # opening in the right lane guide (x = mirrorSum - laneGuideX)
saveGateX = mirrorSum - laneGuideX
# right lane guide with the gate opening cut out
rightLaneGuideWithGate = [[(saveGateX, rightLaneGuide[0][1]), (saveGateX, saveGateTopY)],
                          [(saveGateX, saveGateBottomY)] + rightLaneGuide[1:]]

# ---- The pier mini-flipper (M2 v2: re-placed to match the Jaws Pro drawing, p. 40): it hangs almost straight down
# from the lower-left corner of a plastic block on the right wall, so balls from above roll down the block's left edge
# onto it and off its tip into the right inlane; flipped, it shoots up-left across the table (the harpoon gate, the
# Fish Phone bank). Real flipper: pivot ~(515, 532), length ~51, ~69 deg below horizontal. Ours sits 12 pt further
# right so balls rolling off its tip fall into the right inlane, not onto the sling (tools/chomp_pier_sim.py).
miniPivot = (527, 560)
miniLength = 51
miniRestAngle = math.radians(69)
miniSwing = math.radians(84)          # up to 15 deg ABOVE horizontal, so a held-up flipper traps the ball (flip-lock)
miniPivotRadius, miniTipRadius = 9, 5
pierPlastic = [(540, 660), (laneWallX, 682), (laneWallX, 570), (529, 573), (540, 660)]   # closed; top sheds left
miniLaneSensor = (526, 620)           # on the path down the block's left edge
bumperCenter, bumperRadius = (462, 752), 22
buoyTarget = ((452, 690), 205.0)

def mini_tip(raised=0.0):
    a = miniRestAngle - raised
    return (miniPivot[0] - miniLength * math.cos(a), miniPivot[1] - miniLength * math.sin(a))

# Where the mini-flipper has to reach (milestone 2 parts, shown as markers only)
harpoonLaneMouth = (70, 860)
leftBankCenter = (100, 640)

# ---- Milestone 2 v1: the left side (traced over the Jaws Pro manual's top-down drawing, p. 40, registered on the
# flippers): the harpoon lane down the left wall, the left loop (orbit) beside it with a hairpin round the top of the
# tongue between them, the spinner across the loop, the quickshot gate where the pier flipper's shot enters the
# harpoon lane, the harpoon lane's bottom deflector into the left inlane, and the Fish Phone 3-bank.
harpoonX = 60                                         # the harpoon lane = x 20..60 (40 wide)
harpoonInner = [(harpoonX, 560), (harpoonX, 840)]     # below the gate
quickshotGate = ((harpoonX, 840), (harpoonX, 920))    # one-way: in from the right only (diverter, solid while dx > 0)
def _tongue():
    pts = [(harpoonX, 920), (harpoonX, 1080)]
    cx, cy, r = 80, 1080, 20
    for i in range(1, 12):
        a = math.pi - math.pi * i / 12
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts += [(100, 1080), (100, 920), (harpoonX, 920)]
    return pts
tongue = _tongue()                                    # between the harpoon lane and the loop; a closed outline
def _arch_point_at_x(x):                              # the outer wall's top-left arch: x = 20 + 280 t^2
    t = math.sqrt((x - 20) / 280); return (x, 1000 + 270 * (1 - (1 - t) ** 2))
loopRight = [(170, 862), (147, 905), (147, 1180), _arch_point_at_x(157)]
harpoonDeflector = [(20, 560), (70, 505)]             # sends harpoon-lane balls on into the left inlane
spinnerLine = ((100, 960), (147, 960))
loopEntranceSwitch = ((100, 1040), (147, 1040))
quickshotSwitches = [(40, 1000), (40, 870), (40, 600)] # top, mid, bottom (rollovers in the harpoon lane)
bankNormal = -30.0
def _bank():
    t = math.radians(bankNormal + 90); return [(72 + i * 26 * math.cos(t), 610 + i * 26 * math.sin(t)) for i in range(3)]
bankCenters = _bank()
def _bank_backboard():
    t = math.radians(bankNormal + 90); n = math.radians(bankNormal)
    a, b = bankCenters[0], bankCenters[-1]
    off = (-6 * math.cos(n), -6 * math.sin(n))
    return [(a[0] - 16 * math.cos(t) + off[0], a[1] - 16 * math.sin(t) + off[1]),
            (b[0] + 16 * math.cos(t) + off[0], b[1] + 16 * math.sin(t) + off[1])]
bankBackboard = _bank_backboard()

# ---- Milestone 2 v3: the lower table re-traced from the Jaws Pro drawing (p. 40) (Aaron: "Do it all. And match the
# left sling to the real table. Every table doesn't have to have the same slings or even drain layouts.").
# The real lower table is (nearly) mirror-symmetric about x 284 like ours, but its slings sit ~34 pt further in and
# lower, its lane guides are at x 74 / 494 (ours 54 / 514) and stop at y ~405 (ours 470). Overrides the M1 values.
laneGuideX, laneGuideTop, laneGuideBend = 74, 405, 315
leftLaneGuide = [(laneGuideX, laneGuideTop), (laneGuideX, laneGuideBend), guide_end()]
rightLaneGuide = [mirrored(p) for p in leftLaneGuide]
leftOutlaneWall = [(laneGuideX, laneGuideBend), (laneGuideX, 215)]
rightOutlaneWall = [mirrored(p) for p in leftOutlaneWall]
leftOutlanePostRail = [(laneGuideX, laneGuideTop), (64, 417)]
rightOutlanePostRail = [mirrored(p) for p in leftOutlanePostRail]
leftSling = ((124, 425), (124, 355), (160, 320))
rightSling = tuple(mirrored(p) for p in leftSling)
laneRolloverY = 370
laneRolloverXs = [(leftWallX + laneGuideX) / 2, (laneGuideX + leftSling[1][0]) / 2,
                  mirrorSum - (laneGuideX + leftSling[1][0]) / 2, mirrorSum - (leftWallX + laneGuideX) / 2]
# Up-posts: mid-channel at the inlane's narrowest point (sling tip to the guide's diagonal, 55.6 wide), r 12, so the
# ball (18) can't pass either side (15.8 pt).
upPostRadius = 12
leftUpPost = (143.3, 297.8)
rightUpPost = mirrored(leftUpPost)
# Right outlane save: post on the wall above a 32 pt one-way gate in the (now shorter) right lane guide.
outlaneSavePost = (544.5, 390); outlaneSavePostRadius = 3.5
saveGateX = mirrorSum - laneGuideX                    # 494
saveGateTop, saveGateBottom = 372, 340
rightLaneGuideWithGate = [[(saveGateX, laneGuideTop), (saveGateX, saveGateTop)],
                          [(saveGateX, saveGateBottom)] + rightLaneGuide[1:]]
innerTubeLamp = (47, 300)
# The harpoon lane's inner wall now stops at 570 and its deflector ends over the (wider) left inlane.
harpoonInner = [(harpoonX, 570), (harpoonX, 840)]
harpoonDeflector = [(20, 560), (90, 500)]
# The pier flipper exactly where the real one is: pivot (517, 533), length 51, 64 deg below horizontal; it swings 79 deg
# (to 15 deg above). The plastic block wraps its pivot (gaps 2 / 6.8 / 10.8 pt: closed) and runs down its right side
# to y 470; balls roll down the block's left edge onto the blade and off the tip onto the right lane guide's top.
miniPivot = (517, 533)
miniLength = 51
miniRestAngle = math.radians(64)
miniSwing = math.radians(79)
pierPlastic = [(519, 615), (laneWallX, 618), (laneWallX, 470), (514, 470), (528, 530), (522, 548), (503, 547), (519, 615)]
miniLaneSensor = (508, 590)

# ---- Milestone 2 v4: real scale (Aaron: "Let's scale the ball up."). At this registration a real 1-1/16" ball is
# ~30 pt (the real playfield is ~585 pt / 20.25"), and the real flipper (pivot to tip) ~80 pt (drawing: 59 px x 1.355).
ballRadius = 15
flipperLength = 80
def flipper_tip(pivot, side, raised=0.0):
    a = math.pi / 6 - raised
    dx = flipperLength * math.cos(a) * (1 if side == 'left' else -1)
    return (pivot[0] + dx, pivot[1] - flipperLength * math.sin(a))
# Lanes that a 30 pt ball must still fit through:
_tongueTop = 1040                                     # the tongue's round top drops 40 pt (the lane beside it was 32.7)
def _tongue2():
    pts = [(harpoonX, 920), (harpoonX, _tongueTop)]
    for i in range(1, 12):
        a = math.pi - math.pi * i / 12
        pts.append((80 + 20 * math.cos(a), _tongueTop + 20 * math.sin(a)))
    pts += [(100, _tongueTop), (100, 920), (harpoonX, 920)]
    return pts
tongue = _tongue2()
loopEntranceSwitch = ((100, 1020), (147, 1020))
harpoonInner = [(harpoonX, 580), (harpoonX, 840)]
saveGateTop, saveGateBottom = 380, 335                # 45 pt opening
rightLaneGuideWithGate = [[(saveGateX, laneGuideTop), (saveGateX, saveGateTop)],
                          [(saveGateX, saveGateBottom)] + rightLaneGuide[1:]]
outlaneSavePost = (544.5, 400)
upPostRadius = 6                                       # 55.6 channel: 21.8 pt each side, under the ball's 30
rightWallX = 584                                       # the shooter lane 548..584 (36 wide) for the 30 pt ball
def outer_wall():
    import chomp_base_tour_layout as T
    T.rightWallX = rightWallX
    return T.outer_wall()
