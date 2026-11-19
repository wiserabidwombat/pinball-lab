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

# ---- Milestone 2 v5: the wave ramp (the real table's Left Metal Ramp). Its mouth sits right beside the loop (the
# real wooden channel x ~150-190 behind one shared post), it runs straight up, bends right over the top-left and
# climbs as the plastic ramp toward the top centre, then a wire turns down the right side and drops the ball onto the
# pier flipper's plastic block (which rolls it onto the pier flipper). Same path builder as TourRampPath.
loopRight = [(147, 885), (147, 1180), _arch_point_at_x(157)]          # the flare is gone: the ramp's post is here now
class RampPath:
    def __init__(self, start, heading):
        self.points, self.headings, self.dist, self.h = [start], [heading], [0.0], heading
    def line(self, L, step=10):
        n = max(1, math.ceil(L / step)); x0, y0 = self.points[-1]; s0 = self.dist[-1]
        for i in range(1, n + 1):
            d = L * i / n
            self.points.append((x0 + d * math.cos(self.h), y0 + d * math.sin(self.h))); self.headings.append(self.h); self.dist.append(s0 + d)
    def arc(self, r, turn, step=8):
        n = max(2, math.ceil(abs(turn) * r / step)); sg = 1 if turn > 0 else -1
        x0, y0 = self.points[-1]; c = (x0 - sg * r * math.sin(self.h), y0 + sg * r * math.cos(self.h))
        a0 = math.atan2(y0 - c[1], x0 - c[0]); s0 = self.dist[-1]; h0 = self.h
        for i in range(1, n + 1):
            f = i / n; a = a0 + turn * f
            self.points.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a))); self.headings.append(h0 + turn * f)
            self.dist.append(s0 + abs(turn) * r * f)
        self.h = h0 + turn
    def rails(self, w):
        L = [(p[0] - w(s) * math.sin(h), p[1] + w(s) * math.cos(h)) for p, h, s in zip(self.points, self.headings, self.dist)]
        R = [(p[0] + w(s) * math.sin(h), p[1] - w(s) * math.cos(h)) for p, h, s in zip(self.points, self.headings, self.dist)]
        return L, R
    def at(self, s):
        for i in range(1, len(self.dist)):
            if self.dist[i] >= s:
                t = (s - self.dist[i-1]) / max(self.dist[i] - self.dist[i-1], 1e-3); a, b = self.points[i-1], self.points[i]
                return (a[0] + (b[0]-a[0]) * t, a[1] + (b[1]-a[1]) * t), self.headings[i]
        return self.points[-1], self.headings[-1]

waveMouth = (172, 885)
waveMouthHalfWidth, waveHalfWidth, waveFlareLength = 24, 21, 40
waveLowLength = 60                 # the floor-solid U at the low end (mouth to y ~945)
def wave_path():
    p = RampPath(waveMouth, math.pi / 2)
    p.line(215)                                  # up the channel beside the loop
    p.arc(70, -math.radians(55))                 # bend right over the top-left
    p.line(110)                                  # the plastic ramp climbing toward the top centre
    p.arc(55, -math.radians(75))                 # over the top: heading -40 deg (down-right)
    p.line(188)                                  # the wire across the upper right
    p.arc(60, -math.radians(50))                 # turn straight down the right side
    p.line(380)                                  # down to the pier block
    return p
WP = wave_path()
# apex = the top of the over-the-top arc (heading 0)
waveApexDistance = 215 + 70 * math.radians(55) + 110 + 55 * math.radians(35)

# ---- Milestone 2 v7 (Shot Lab run 1: wave ramp 0/192, loop 2/192 from the right flipper; Aaron: "Option 1 for sure"):
# wider mouths. The wave ramp's mouth flares to 66 and leans right (the right flipper's ~100-101 deg shots cross
# y 865 at x ~200-215, just right of the old 48 pt mouth); the tongue narrows to x 60-88 so loop shots (106-108 deg,
# drifting left) clear its bottom-right corner.
tongueRightX = 88
def _tongue3():
    r = (tongueRightX - harpoonX) / 2; cx = harpoonX + r
    pts = [(harpoonX, 920), (harpoonX, _tongueTop)]
    for i in range(1, 12):
        a = math.pi - math.pi * i / 12
        pts.append((cx + r * math.cos(a), _tongueTop + r * math.sin(a)))
    pts += [(tongueRightX, _tongueTop), (tongueRightX, 920), (harpoonX, 920)]
    return pts
tongue = _tongue3()
spinnerLine = ((tongueRightX, 960), (147, 960))
loopEntranceSwitch = ((tongueRightX, 1020), (147, 1020))
waveMouth = (190, 865)
waveMouthHalfWidth, waveHalfWidth, waveFlareLength = 33, 21, 70
waveLowLength = 70
def wave_path():
    p = RampPath(waveMouth, math.radians(100))
    p.line(80)                                   # the leaning mouth
    p.arc(120, -math.radians(10))                # straighten up the channel
    p.line(1100 - p.points[-1][1])               # up the channel beside the loop
    p.arc(70, -math.radians(55))
    p.line(110)
    p.arc(55, -math.radians(75))
    p.line(185)
    p.arc(60, -math.radians(50))
    p.line(380)
    return p
WP = wave_path()

_p = RampPath(waveMouth, math.radians(100)); _p.line(80); _p.arc(120, -math.radians(10)); waveChannelStart = _p.points[-1]
waveApexDistance = 80 + 120 * math.radians(10) + (1100 - waveChannelStart[1]) + 70 * math.radians(55) + 110 + 55 * math.radians(35)

# ---- Milestone 2 v11 (Aaron: does the angled mouth match the real table? → "Yep, let's do it"): the real layout.
# The real channel runs straight up (x ~150-195) between the post shared with the loop (down to y ~870) and a wall on
# its right that stops higher, at y ~940, with a rounded end: a staggered opening that takes shots coming up-left
# from the right flipper under the right wall's end. The plastic ramp (its entrance flap) starts higher, at y 1000.
waveMouth = (172, 1000)
waveMouthHalfWidth, waveHalfWidth, waveFlareLength = 21, 21, 40
waveLowLength = 60
waveLaneLeft = [(151, 870), (151, 1000)]
waveLaneRight = [(193, 945), (193, 1000)]
waveLaneRightEndRadius = 5          # the rounded end (a rubber post)
def wave_path():
    p = RampPath(waveMouth, math.pi / 2)
    p.line(100)
    p.arc(70, -math.radians(55))
    p.line(110)
    p.arc(55, -math.radians(75))
    p.line(185)
    p.arc(60, -math.radians(50))
    p.line(380)
    return p
WP = wave_path()
waveApexDistance = 100 + 70 * math.radians(55) + 110 + 55 * math.radians(35)

# ---- Milestone 2 v12 (Aaron: "Option 1"): the real table's fat rounded end on the lane's right wall (the blue block
# right of the channel ends at y ~940 in a round ~40 pt across), and the channel 46 wide.
waveMouth = (174, 1000)
waveMouthHalfWidth, waveHalfWidth, waveFlareLength = 23, 23, 40
waveEndCentre, waveEndRadius = (215, 950), 18
def _right_block():
    cx, cy = waveEndCentre; r = waveEndRadius
    pts = [(cx - r, 1000), (cx - r, cy)]
    for i in range(1, 12):
        a = math.pi + math.pi * i / 12
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts += [(cx + r, cy), (cx + r, 1000), (cx - r, 1000)]
    return pts
waveRightBlock = _right_block()
waveLaneRight = [(197, 950), (197, 1000)]
waveLaneRightEndRadius = 0
WP = wave_path()

# ---- Milestone 2 v13 (Aaron: "Yes please" — the harpoon shot from the pier flipper, "a makeable shot from the right
# mini flipper" on the real table; ours made it 1-2 times in 96): the gate opening is taller, down to y 760 (was 840),
# so it takes the pier flipper's ~137-148 deg shots instead of ~137-141.
harpoonInner = [(harpoonX, 580), (harpoonX, 760)]
quickshotGate = ((harpoonX, 760), (harpoonX, 920))
# v13b: 150 deg pier shots hit the wall's top at 760 -> the gate 720-920
harpoonInner = [(harpoonX, 580), (harpoonX, 720)]
quickshotGate = ((harpoonX, 720), (harpoonX, 920))

# ---- Milestone 2 v15: real gravity (-6.0, v14) left the ball let down from the held pier flipper balanced on the
# block's lower-left corner (503, 547); the corner moves in to (511, 548), still closed on the pivot cap (7.2 pt).
pierPlastic = [(519, 615), (548, 618), (548, 470), (514, 470), (528, 530), (522, 548), (511, 548), (519, 615)]

# ---- Milestone 2 v16: the right outlane's one-way gate is gone (the real table has only the post, which saves with a
# nudge); the right lane guide is solid again.
rightLaneGuideWithGate = [rightLaneGuide]

# ---- Milestone 3 v1: the center ramp (p. 40: a lane x ~235-285 right of the wave ramp's block, entrance ~y 1000; the
# ramp climbs the lane, turns round at the top and its wire comes back down over the left side into the left inlane,
# "the easiest shot in the game"). On the real table the return wire is stacked over the climb; in 2D the U-turn sets it
# beside it (the down leg 48 pt left of the climb), then it bends down-left and runs straight down into the left inlane.
centerMouth = (259, 1000)
centerMouthHalfWidth, centerHalfWidth, centerFlareLength = 23, 20, 110
centerLowLength = 60
centerClimb = 110
centerTurnRadius = 24
def center_path():
    p = RampPath(centerMouth, math.pi / 2)
    p.line(centerClimb)                          # up the lane (the plastic)
    p.arc(centerTurnRadius, math.pi)             # the U-turn, to the left: apex at its top (heading 180)
    p.line(1110 - 870)                           # the wire straight down beside the climb
    p.arc(80, -math.radians(40))                 # bend down-left
    p.line(116)
    p.arc(80, math.radians(40))                  # straight down again, over the left inlane (x 99)
    p.line(p.points[-1][1] - 440)                # down to the inlane
    return p
CP = center_path()
centerApexDistance = centerClimb + centerTurnRadius * math.pi / 2

# ---- Milestone 3 v2 (Aaron: is it flared on the real table? -> "Yes please!" to tracing the real entrance): p. 40 shows
# the block left of the lane with its right edge at x ~228 (ours was 233), a rubber post at ~(300, 1000) with the wall
# slanting in from it to the ramp's entrance flap at y ~1020, which is ~52 wide (x ~228-280): a short funnel, ~66 pt
# across where the ball arrives at y 1000.
waveEndCentre, waveEndRadius = (212.5, 950), 15.5     # the block x 197-228 (its left side, the wave lane, unchanged)
waveRightBlock = _right_block()
centerMouth = (254, 1020)
centerMouthHalfWidth, centerHalfWidth, centerFlareLength = 26, 20, 110
centerJamb = [(228, 1000), (228, 1020)]              # the block's edge up to the flap
centerPost, centerPostRadius = (300, 1000), 6        # the rubber post
centerFunnel = [(296.0, 1004.5), (280, 1020)]        # from the post up-left to the ramp's right rail
def center_path():
    p = RampPath(centerMouth, math.pi / 2)
    p.line(centerClimb)
    p.arc(centerTurnRadius, math.pi)
    p.line(p.points[-1][1] - 870)
    p.arc(80, -math.radians(40))
    p.line(108)
    p.arc(80, math.radians(40))
    p.line(p.points[-1][1] - 440)
    return p
CP = center_path()

# ---- Milestone 3 v4: the boat captive ball (p. 40: housing x ~305-395, y ~985-1130, open at the bottom; a steel captive
# ball at ~(350, 1005) under the shark/boat target). Monsoon's captive ball: a 34 pt channel up the housing's middle,
# mouth posts r 4 at its ends (26 pt gap < the 30 pt ball), the target 70 pt up.
boatMouth, boatChannelLength, boatHalfWidth = (350, 1000), 70, 17
boatHousing = [(333, 1000), (305, 1000), (305, 1130), (395, 1130), (395, 1000), (367, 1000)]

# ---- Milestone 3 v5 (Aaron: "Do option 1"): the boat target down to the real cone tip -- the slot ends 42 pt up, so the
# captive ball scores after ~13 pt of travel (was 41).
boatChannelLength = 42

# ---- Milestone 3 v7 (Aaron: "Widen the mouth to match the real table and then commit."): the real cradle -- rubber
# posts r 5 at x 318 / 382 (54 pt apart inside), a 64 pt cradle up to the cone, a curved wire lip (captive ball only)
# dipping to y 993, so the captive ball rests at ~(350, 1008).
boatHalfWidth, boatPostRadius = 32, 5
boatLip = [(318, 1000), (334, 995), (350, 993), (366, 995), (382, 1000)]
boatHousing = [(318, 1000), (305, 1000), (305, 1130), (395, 1130), (395, 1000), (382, 1000)]

# ---- Milestone 3 v8 (Aaron: "Let's do option 1 and fix it like the real deal."): the stuck-ball test found four traps
# where the real table has solid blue plastic (p. 40). (1) The island behind the ramp entrances: from the loop's right
# wall (x 147) over the wave ramp's low U, the gap between the ramps, the center ramp's low U and up to the boat
# housing, its top a roof sloping from the loop wall's top (147, 1180) down to the housing (305, 1145); (2) the boat
# housing's top slopes too, (305, 1145) -> (395, 1115), so a ball rolls off its right end into play; (3) the wedge
# behind the Fish Phone bank between the harpoon lane wall and the backboard, its top sloping down-right.
rampIsland = [(147, 1060), (197, 1060), (197, 1000), (228, 1000), (228, 1020), (231, 1080), (282, 1080),
              (305, 1100), (305, 1145), (147, 1180), (147, 1060)]
boatHousing = [(318, 1000), (305, 1000), (305, 1145), (395, 1115), (395, 1000), (382, 1000)]
bankWedge = [(58.8, 599.1), (100.8, 671.9), (100.8, 700), (60, 720), (58.8, 599.1)]

# ---- Milestone 3 v9 (Aaron: "kick off m3"): the fishing reel (p. 40 crop x 380-570, y 940-1190; the manual's
# "Fishing Reel Spinner Top Assembly"): a keyhole lane right of the boat -- its mouth x 426-500 at y ~980, straight sides
# to x 433 / 499, a round end centre (466, 1100) r 48 -- under a spinning disc (r 42) that the passing ball turns.
# The blue plastic either side is solid. To leave no ledge, the island, the boat housing and the reel's blocks now
# share ONE roof line from the loop wall's top (147, 1185) down to (510, 1150), where a ball rolls off into the open
# right side (the real mid flipper lane).
import math as _m
def roofY(x): return 1185 - 35 * (x - 147) / 363
reelCentre, reelRadius, reelDiscRadius = (466, 1100), 48, 42
def _reel_arc(a0, a1, n=16):
    return [(reelCentre[0] + reelRadius * _m.cos(_m.radians(a0 + (a1 - a0) * i / n)),
             reelCentre[1] + reelRadius * _m.sin(_m.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
_aL = _m.degrees(_m.atan2(1065 - 1100, 433 - 466)) % 360            # 226.7
_aR = _m.degrees(_m.atan2(1065 - 1100, 499 - 466))                  # -46.7
rampIsland = [(147, 1060), (197, 1060), (197, 1000), (228, 1000), (228, 1020), (231, 1080), (282, 1080),
              (305, 1100), (305, roofY(305)), (147, roofY(147)), (147, 1060)]
boatHousing = [(318, 1000), (305, 1000), (305, roofY(305)), (395, roofY(395)), (395, 1000), (382, 1000)]
reelLeftBlock = ([(395, 1000), (395, 978), (426, 978), (433, 1043), (433, 1065)] + _reel_arc(_aL, 90)
                 + [(466, roofY(466)), (395, roofY(395)), (395, 1000)])
reelRightBlock = (_reel_arc(90, _aR) + [(499, 1043), (500, 983), (510, 983), (510, roofY(510)), (466, roofY(466)),
                                        (466, 1148)])
reelSwitch = ((433, 1065), (499, 1065))          # into the round end, going up: the ball reaches the disc

# ---- Milestone 3 v10 (Aaron: "Let's do the ramp."): the right ramp (p. 40 parts 9 "Wire Ramp Right" + p. 60 "Right
# Ramp Assembly", a riveted J-hook with a made opto). Its entrance is the tight wooden lane right of the reel's block
# (real x ~505-545 = ~40 wide); the ramp climbs straight up, hooks 180 deg to the left (its apex = the made switch) and
# its wire comes straight back down over the reel and the right side into the right inlane (x 469 = the center ramp's
# x 99 mirrored), ending at y 440 -> the right flipper. Its own (third) wire level. The space between the reel block
# and the right wall above the ramp's low U is solid plastic, its top on the shared roof, so nothing rests on the U.
rightMouth = (529, 1000)
rightMouthHalfWidth, rightHalfWidth, rightFlareLength = 19, 19, 40
rightLowLength = 60
rightClimb = 110
rightTurnRadius = 30
def right_path():
    p = RampPath(rightMouth, math.pi / 2)
    p.line(rightClimb)
    p.arc(rightTurnRadius, math.pi)              # the J-hook to the left: apex at its top
    p.line(p.points[-1][1] - 440)                # the wire straight down (x 469) over the right inlane
    return p
RP = right_path()
rightApexDistance = rightClimb + rightTurnRadius * math.pi / 2
rightRampBase = [(510, 1060), (548, 1060), (548, roofY(548)), (510, roofY(510)), (510, 1060)]

# ---- Milestone 3 v10b (stuck test: 10 drops rested at (524, 1165), in the V between the roof over the ramp's base and
# the arch): the reel's right block now also covers the ramp's base, its roof slopes DOWN TO THE LEFT from the arch
# (548, 1150) to a drain hole over the reel's round end (x 442-490, 48 wide); the left roof ends at the hole's left edge.
_a60 = _reel_arc(60, _aR)
reelLeftBlock = ([(395, 1000), (395, 978), (426, 978), (433, 1043), (433, 1065)] + _reel_arc(_aL, 120)
                 + [(442, roofY(442)), (395, roofY(395)), (395, 1000)])
reelRightBlock = _a60 + [(499, 1043), (500, 983), (510, 983), (510, 1060), (548, 1060), (548, 1150), _a60[0]]
rightRampBase = reelRightBlock

# ---- Milestone 3 v11 (Aaron: "Yep, let's move it"): the pop bumper and the buoy target toward the real spots (p. 40:
# bumper disc centre ~(511, 687); the buoy, a round cyan target, ~(545, 646) below-right of it). Our right wall is x 548
# (the real playfield runs to ~575 here), so the bumper sits 21 pt left of the real one to keep the mid flipper lane
# right of it 36 wide (x 512-548), and the buoy goes below-LEFT of the bumper (below-right would sit in that lane and
# under the wave wire's drop). Both clear the left flipper's 66-70 deg shots (the right ramp's), which the old buoy at
# (452, 690) stopped. The wave wire now ends at y 640, below the bumper, so its ball drops onto the pier block, not the
# bumper.
bumperCenter, bumperRadius = (490, 687), 22
buoyTarget = ((468, 638), 205.0)
def wave_path():
    p = RampPath(waveMouth, math.pi / 2)
    p.line(100); p.arc(70, -math.radians(55)); p.line(110); p.arc(55, -math.radians(75))
    p.line(185); p.arc(60, -math.radians(50))
    p.line(380 + (WP.points[-1][1] - 640))
    return p
WP = wave_path()

# ---- Milestone 3 v11b (stuck test 4: 2 balls from the top ended INSIDE the right block, squeezed past its corner
# (548, 1150) through the 4 pt gap to the arch): the corner is now (548, 1164), above the arch (which crosses
# x 548 at y ~1158), so no gap and no corner is left inside the playfield.
reelRightBlock = _a60 + [(499, 1043), (500, 983), (510, 983), (510, 1060), (548, 1060), (548, 1164), _a60[0]]
rightRampBase = reelRightBlock

# ---- Milestone 3 v12 (Aaron: "as realistic as possible"; p. 17 switch map + p. 40): the real right side. The plunger
# lane runs up the right side (its inner wall x 548 now to y 1150, the launch gate at its top); a curved top wall
# (centre (504, 1150), r 80) turns both the plunger lane and the lane right of the reel (x 510-548) to the left at the
# top, into the right ramp's entrance heading west at (494, 1211). The ramp climbs up-left, hooks right over its own
# climb along the top and comes down the right side (x 552) into the right inlane. A plunge that clears the gate either
# carries round into the ramp (-> right flipper) or drops down the reel lane to the bumper / the lane beside it; the
# region above the roof is closed (its balls drain through the hole into the reel).
laneWallTop = 1150
outerArcCentre, outerArcRadius, outerTopY = (504, 1150), 80, 1230
def outer_wall():
    import tour_layout as T
    T.rightWallX = rightWallX
    pts = T.outer_wall()
    # cut the right half of the arch where it crosses y 1230 and add the new top line + arc down to the lane's outer wall
    out = []; i = 0
    while not (pts[i][0] > 300 and pts[i][1] < outerTopY): out.append(pts[i]); i += 1
    a, b = pts[i-1], pts[i]; t = (a[1] - outerTopY) / (a[1] - b[1]); out.append((a[0] + t * (b[0] - a[0]), outerTopY))
    out += [(outerArcCentre[0] + outerArcRadius * math.cos(math.radians(ang)), outerArcCentre[1] + outerArcRadius * math.sin(math.radians(ang))) for ang in range(90, -1, -6)]
    j = [k for k, p in enumerate(pts) if p == (rightWallX, T.laneFloorY)][0]
    out += pts[j:-1] + [(548, laneWallTop)]
    return out
rightMouth = (494, 1211)
rightMouthHalfWidth, rightHalfWidth, rightFlareLength, rightLowLength = 19, 19, 40, 30
def right_path():
    p = RampPath(rightMouth, math.pi)
    p.line(15); p.arc(30, -math.radians(60)); p.line(10)          # up-left
    p.arc(28, -math.radians(120))                                  # the hook over the top: heading east
    p.line(552 - 30 - p.points[-1][0]); p.arc(30, -math.radians(90))   # straight down the right side, x 552
    p.line(p.points[-1][1] - 597)
    p.arc(80, -math.radians(40)); p.line(71); p.arc(80, math.radians(40))   # jog left over the pier block
    p.line(p.points[-1][1] - 440)                                  # into the right inlane
    return p
RP = right_path()
rightApexDistance = 15 + 30 * math.radians(60) + 10 + 28 * math.radians(30)
rightClimb, rightTurnRadius = 0, 0
reelRightBlock = _a60 + [(499, 1043), (500, 983), (510, 983), (510, 1150), _a60[0]]
rightRampBase = reelRightBlock

# ---- Milestone 3 v13 (Aaron: "Fix the lane from the drawing"): the reel lane and the plunger lane lean right going up,
# as on p. 40 (the real lane's left edge x ~505 at y 1000 -> ~536 at y 1200, its right side ~565 -> ~578). Ours: the
# lane's left wall (the reel block) (505, 983) -> (522, 1150); the plunger lane bends at y 900 from x 548..584 to
# 562..598 at y 1150 (its inner wall is the lane's right wall), so the lane is 43 wide at the bottom, 40 at the top,
# its axis ~84 deg -- 14 deg off the left flipper's ~70 deg shots instead of 20. The top arc moves right with it.
laneBendY, laneTopInnerX, laneTopOuterX = 900, 562, 598
outerArcCentre = (518, 1150)
def outer_wall():
    import tour_layout as T
    T.rightWallX = rightWallX
    pts = T.outer_wall()
    out = []; i = 0
    while not (pts[i][0] > 300 and pts[i][1] < outerTopY): out.append(pts[i]); i += 1
    a, b = pts[i-1], pts[i]; t = (a[1] - outerTopY) / (a[1] - b[1]); out.append((a[0] + t * (b[0] - a[0]), outerTopY))
    out += [(outerArcCentre[0] + outerArcRadius * math.cos(math.radians(ang)), outerArcCentre[1] + outerArcRadius * math.sin(math.radians(ang))) for ang in range(90, -1, -6)]
    out += [(rightWallX, laneBendY)]
    j = [k for k, p in enumerate(pts) if p == (rightWallX, T.laneFloorY)][0]
    out += pts[j:-1] + [(548, laneBendY), (laneTopInnerX, laneWallTop)]
    return out
reelRightBlock = _a60 + [(499, 1043), (500, 983), (505, 983), (522, 1150), _a60[0]]
rightRampBase = reelRightBlock

# M3 v13 review fix: the jog drops 157.2, so start it at y 598 (the last line stays positive)
def right_path():
    p = RampPath(rightMouth, math.pi)
    p.line(15); p.arc(30, -math.radians(60)); p.line(10)
    p.arc(28, -math.radians(120))
    p.line(552 - 30 - p.points[-1][0]); p.arc(30, -math.radians(90))
    p.line(p.points[-1][1] - 598)
    p.arc(80, -math.radians(40)); p.line(71); p.arc(80, math.radians(40))
    p.line(max(0, p.points[-1][1] - 440))
    return p
RP = right_path()

# ---- Milestone 3 v14 (drop probe: a lane shot reaches the top at ~2,500 pt/s and leaves the old curved top wall at ~830
# -- it met that wall nearly head-on, because the curve started out at the plunger lane's outer wall). As on the real
# table (p. 40: the blue plastic between the plunger lane and the reel lane curves over the top, and the plunge comes
# through a gate in it at the lane's top end): the wall BETWEEN the two lanes curves left (centre (482, 1150), r 80),
# so a ball riding the reel lane's right wall follows it round without losing speed into the ramp mouth; the plunger
# lane curves round outside it (r 116) and then spirals in (r 116 -> 80 between 50 and 81 deg) through a one-way gate
# (the chord from the divider's end to the mouth's upper rail) into the top of the reel lane, just before the mouth.
turnCentre, turnInnerR, turnOuterR = (482, 1150), 80, 116
dividerEndDeg, spiralStartDeg, spiralEndDeg = 50, 50, 81
def _pt(r, deg): return (turnCentre[0] + r * math.cos(math.radians(deg)), turnCentre[1] + r * math.sin(math.radians(deg)))
dividerArc = [_pt(turnInnerR, a) for a in range(0, dividerEndDeg + 1, 5)]
plungerOuterArc = [_pt(turnOuterR, a) for a in range(0, spiralStartDeg + 1, 5)] + \
    [_pt(turnOuterR - (turnOuterR - turnInnerR) * (a - spiralStartDeg) / (spiralEndDeg - spiralStartDeg), a) for a in range(spiralStartDeg + 3, spiralEndDeg + 1, 3)]
gateA, gateB = dividerArc[-1], plungerOuterArc[-1]
def outer_wall():
    import tour_layout as T
    T.rightWallX = rightWallX
    pts = T.outer_wall()
    out = []; i = 0
    while not (pts[i][0] > 300 and pts[i][1] < outerTopY): out.append(pts[i]); i += 1
    a, b = pts[i-1], pts[i]; t = (a[1] - outerTopY) / (a[1] - b[1]); out.append((a[0] + t * (b[0] - a[0]), outerTopY))
    out += list(reversed(plungerOuterArc)) + [(rightWallX, laneBendY)]
    j = [k for k, p in enumerate(pts) if p == (rightWallX, T.laneFloorY)][0]
    out += pts[j:-1] + [(548, laneBendY), (laneTopInnerX, laneWallTop)] + dividerArc[1:]
    return out

# ---- Milestone 3 v14b (drop probe: the lane ball left the divider's end at 50 deg heading ~140 and hit the mouth's
# top corner): the gate is now an arc along r 80 (50 -> 80 deg), a short r 80 piece of the outer wall finishes the
# turn at 90 deg (482, 1230), and the ramp mouth moves left to (480, 1211), so the ball is heading west when it gets there.
gateArc = [_pt(turnInnerR, a) for a in range(dividerEndDeg, 81, 5)]
turnEnd = [_pt(turnInnerR, 85), _pt(turnInnerR, 90)]
def outer_wall():
    import tour_layout as T
    T.rightWallX = rightWallX
    pts = T.outer_wall()
    out = []; i = 0
    while not (pts[i][0] > 300 and pts[i][1] < outerTopY): out.append(pts[i]); i += 1
    a, b = pts[i-1], pts[i]; t = (a[1] - outerTopY) / (a[1] - b[1]); out.append((a[0] + t * (b[0] - a[0]), outerTopY))
    out += list(reversed(turnEnd)) + list(reversed(plungerOuterArc)) + [(rightWallX, laneBendY)]
    j = [k for k, p in enumerate(pts) if p == (rightWallX, T.laneFloorY)][0]
    out += pts[j:-1] + [(548, laneBendY), (laneTopInnerX, laneWallTop)] + dividerArc[1:]
    return out
rightMouth = (480, 1211)
RP = right_path()

# ---- Milestone 3 v14c (drop probe: a ball reaching the mouth at ~1,600 pt/s stopped dead on the r 30 / 60 deg bend): the
# first bend is r 60 / 50 deg, the hook r 28 / 130 deg.
def right_path():
    p = RampPath(rightMouth, math.pi)
    p.line(10); p.arc(60, -math.radians(50))
    p.arc(28, -math.radians(130))
    p.line(552 - 30 - p.points[-1][0]); p.arc(30, -math.radians(90))
    p.line(p.points[-1][1] - 598)
    p.arc(80, -math.radians(40)); p.line(71); p.arc(80, math.radians(40))
    p.line(max(0, p.points[-1][1] - 440))
    return p
RP = right_path()
rightApexDistance = 10 + 60 * math.radians(50) + 28 * math.radians(40)
rightLowLength = 60   # M3 v14d
