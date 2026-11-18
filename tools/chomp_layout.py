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
