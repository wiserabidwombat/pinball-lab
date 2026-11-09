"""Table 06 M3 v1: the two orbits with spinners (8 Nov 2026). Builds on tour_layout.py / tour_layout_a.py.
Left orbit: a 40 pt lane up the left wall (x 20-60) following the arch, its mouth a funnel facing the right flipper above
the R-O-C bank. Right orbit: a 44 pt lane inside the plunger-lane wall (x 504-548), its mouth a funnel facing the left
flipper above the Mars bunker; above the launch gate it shares the arch with the plunger lane (76 pt to the right wall).
Inner walls are OFFSETS of the arch (the skill: never a second guessed curve). A shot up one orbit rides the arch round
and comes down the other: onto the R-O-C roof (left) or the bunker roof (right), which shed it toward the flippers."""
import math
import tour_layout as L
import tour_layout_a as A

W = 600
LEFT_X, RIGHT_X, LANE_X = 20, 580, 548
ARCH_Y, TOP = 1000, 1270

def arch_points(n=64):
    """The outer arch as one polyline, left (20,1000) over the top to right (580,1000)."""
    left = [(LEFT_X, ARCH_Y)] + L.quad((LEFT_X, ARCH_Y), (LEFT_X, TOP), (W / 2, TOP), n)
    right = L.quad((W / 2, TOP), (RIGHT_X, TOP), (RIGHT_X, ARCH_Y), n)
    return left + right

def offset(pts, d):
    """Offset a polyline d pt to its right-hand side going left→right over the arch (= inward), by averaged normals."""
    out = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]; b = pts[min(i + 1, len(pts) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]; l = math.hypot(tx, ty); tx, ty = tx / l, ty / l
        out.append((p[0] + ty * d, p[1] - tx * d))
    return out

ARCH = arch_points()
L_W, R_W = 40, RIGHT_X - 504          # lane widths: left 40; right 76 above the gate (the plunger lane shares it)
L_INNER_X, R_INNER_X = LEFT_X + L_W, RIGHT_X - R_W     # 60, 504
L_END_X, R_END_X = 190, 400           # where the inner walls stop (v2: right 384 -> 400, 46 pt clear of the last lane post)

def side_offset(d, side):
    """The arch offset by d, from its foot on one side to the top centre."""
    o = offset(ARCH, d)
    mid = len(ARCH) // 2
    return o[:mid + 1] if side == 'L' else o[mid:]

_lo = side_offset(L_W, 'L'); _ro = side_offset(R_W, 'R')
L_ARC = [p for p in _lo if p[0] <= L_END_X]
R_ARC = [p for p in _ro if p[0] >= R_END_X]

# Funnels: the bottom of each inner wall slants out along the shot from the opposite flipper (near-parallel, so the ball
# isn't bounced out: the skill's funnel rule), giving a ~3-ball mouth.
def unit(deg): t = math.radians(deg); return (math.cos(t), math.sin(t))
L_SHOT = A.ang(A.TIP_R, (40, 900))          # ~110°
R_SHOT = A.ang(A.TIP_L, (526, 700))         # ~63°
# Flared 10° flatter than the shot (Grey Invasion's proven funnel was 7°; parallel left a ~3° window, because the R-O-C
# bank caps the left orbit at 112° and the bunker roof caps the right at 62°): left 90 pt long, right 75 (its tip stays
# clear of where the asteroid lane will go).
FLARE = 10
L_BEND = (L_INNER_X, 915)
L_FUNNEL, R_FUNNEL = 50, 45          # M3 v7 (Aaron: the orange funnel walls don't need to reach out so far): 90/75 → 50/45
ux, uy = unit(L_SHOT + FLARE + 180); L_TIP = (L_BEND[0] + ux * L_FUNNEL, L_BEND[1] + uy * L_FUNNEL)
R_BEND = (R_INNER_X, 725)
ux, uy = unit(R_SHOT - FLARE + 180); R_TIP = (R_BEND[0] + ux * R_FUNNEL, R_BEND[1] + uy * R_FUNNEL)
leftOrbitInner = [L_TIP, L_BEND] + L_ARC
rightOrbitInner = [R_TIP, R_BEND] + list(reversed(R_ARC))   # from the tip up and over (right to left)

# Spinners: across each lane above its mouth (either direction spins).
L_SPIN_Y, R_SPIN_Y = 960, 800
leftSpinner = ((LEFT_X, L_SPIN_Y), (L_INNER_X, L_SPIN_Y))
rightSpinner = ((R_INNER_X, R_SPIN_Y), (LANE_X, R_SPIN_Y))
# Arm switches low in each lane (going up arms that orbit; going down disarms) — the right one stops at the lane wall,
# so plunges up the shooter lane never arm it; made = crossing the top centre line (x 284) the right way.
leftArm = ((LEFT_X, 990), (L_INNER_X, 990))
rightArm = ((R_INNER_X, 900), (LANE_X, 900))
madeLine = ((284, 1215), (284, 1275))      # v2: above the S-T-A-R posts (top 1200); a ball riding the arch is at ~1261

# --- M3 v2 (8 Nov 2026): the S-T-A-R top lanes and the bumper nest. ---
# The lanes sit in the gap between the two inner walls under the arch, the only place a ball drops off the arch (a weak
# orbit or plunge, or a centre shot that misses the rocket): four 36 pt lanes between five posts. The leftmost post is
# 28.5 pt from the left inner wall's end (a passage, not a wedge), the rightmost 46 from the right one. A ball on the
# arch passes 53-61 pt over the post tops. The bumpers fill the open floor top-left between the left orbit's inner wall,
# the lanes and the rocket pad (the raised Moon goes over them in a later round): an even nest, gaps ~79 pt, every wall
# and part >= 27 pt away (tools search: maximise the smallest gap). The leftmost lane drops onto the top bumper.
lanePostXs = [214, 250, 286, 322, 358]
lanePostBottom, lanePostTop = 1150, 1200
laneCenters = [(a + b) / 2 for a, b in zip(lanePostXs, lanePostXs[1:])]    # 232, 268, 304, 340
laneRolloverY, laneLampY = 1178, 1132
bumperRadius = 24
bumperCenters = [(115, 985), (140, 1110), (235, 1025)]
# --- M3 v5 (8 Nov 2026): pops under the lanes, the rocket 60 pt down. Aaron on v4's lane guide: "doesn't feel like
# what a real table would do"; "a real table would move the rocket down a bit and move the bumpers under the lanes".
# The classic top: the lanes drop straight onto a triangle of pops (two under the lane exits, one below between them).
# The rocket (pad, wings, door, scoop, toy) comes down ROCKET_DROP so the lower pop has room above the pad's peak.
ROCKET_DROP = 60
rocketPad = [(x, y - ROCKET_DROP) for x, y in [(222.0, 960.0), (266, 980), (284, 998), (302, 980), (346.0, 960.0)]]
rocketHull = [(x, y - ROCKET_DROP) for x, y in [(222.0, 960.0), (267, 934), (301, 934), (346.0, 960.0)]]
bumperCenters = [(232, 1088), (340, 1088), (286, 1030)]   # a pop under each outer lane, one below between (search: every lane >= 7 hits)

# --- M3 v7 (8 Nov 2026): the Moon ramp. Mouth 60 wide at (200, 760) heading 100° (Aaron: the ramp needn't reach so far
# into the middle; v7a's mouth was at y 640), climb line 120 + arc r120 25° + line 40 to the crater; round it r38 145°;
# wire down the left side, S-bend 2 x r60 14.433° to x 71, line 85 into the left inlane (ends y 440; Aaron: the wire's
# drop missed the inlane when it ended at y 505). Floor U: first 80 pt.
MOON_MOUTH, MOON_HEADING, MOON_MOUTH_HALF, MOON_HALF, MOON_FLARE, MOON_LOW = (200, 760), 100, 30, 16, 70, 80
# centreline: line 120, arc(120, +25), line 40 [apex 212.36], arc(38, +145), line 382.23, arc(60, +14.433), arc(60, -14.433),
# line 85 -> ends (71, 440) heading 270. Crater-turn centre (105.2, 937.1). Mirrors TourTableLayout.moonRampPath.
