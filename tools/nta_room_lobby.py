"""9 to Alive (Table 10) — the LOBBY floor, round 1 layout sketch (no Swift yet).

A room on Neon Labyrinth's shared cell kit (nl_kit.py, unchanged): the kit's lower half (flippers, slings, inlanes,
outlanes with the v3 knee, kickback/save, drain chute) plus the Lobby's own parts:
  - STAIRS: the centre ramp, the floor's one exit. Its low end is floor-solid (a U with a gable back), so while the stairs
    are shut a ball shot in rolls back out. Open, the ramp entry takes the ball up a scripted ride to the top port.
  - REVOLVING DOOR: a short lane up the left side, aimed along the right flipper's curved shot, with a spinner (the door)
    across it. A ball that reaches the end rides the kit's left return wire to the left inlane. Spins open the stairs.
  - BARRICADE: the reception desk in the upper right, with three targets (B-A-R) on its front, square to the left
    flipper's line of sight. All three shove the desk against the stairwell door below and stall the horde.
World points, origin bottom-left. Prefix proposal for the table: Nta / nta_.
"""
import math
from nl_kit import *

NAME = "lobby"
EXITS = ("top",)                    # stairs only: no side portals, no side entries, no entry stubs

SWEET_L = (243.0, 214.0)            # the Switchyard's sweet spots (the Shot Lab measures the real ones)
SWEET_R = M(SWEET_L)

# ---------------------------------------------------------------- STAIRS (centre ramp -> top port)
STAIR_MOUTH_Y = 580.0               # ~45% of the way from the flippers to the top (the shot line)
STAIR_MOUTH_HALF = 33.0             # 66 wide (the Switchyard's ramp mouth)
STAIR_CHANNEL_HALF = 23.0           # 46 channel
STAIR_FLARE = 60.0
STAIR_U_LEN = 80.0                  # floor-solid low end
STAIR_U_TOP = STAIR_MOUTH_Y + STAIR_U_LEN   # 660: the stair door is drawn here while shut
STAIR_TOP_Y = TOP_LANE_BOTTOM       # the ramp's drawn top; the ride carries on into the top port
STAIR_POST_R = 5.0
STAIR_RIDE = [(CX, STAIR_MOUTH_Y + 12), (CX, STAIR_TOP_Y), (CX, TOP_Y - 4)]

def stair_half_at(y):
    f = min(1.0, max(0.0, (y - STAIR_MOUTH_Y) / STAIR_FLARE))
    return STAIR_MOUTH_HALF + (STAIR_CHANNEL_HALF - STAIR_MOUTH_HALF) * (f * f * (3 - 2 * f))

def stair_outline():
    ys = [STAIR_MOUTH_Y + (STAIR_TOP_Y - STAIR_MOUTH_Y) * i / 24 for i in range(25)]
    return [(CX - stair_half_at(y), y) for y in ys], [(CX + stair_half_at(y), y) for y in ys]

# ---------------------------------------------------------------- REVOLVING DOOR (left lane, right flipper's shot)
# Round 1a (a 200-long lane aimed along the straight line from the sweet spot, rubber cap at the end) failed the curved
# fan: gravity bends a 1,200-1,600 pt/s shot 40-80 pt, so only 1-2 deg of aim got in, and half the balls coming back
# down it fell between the flipper tips. Now: shorter and wider, aimed along the CURVED path at 1,400 pt/s, and a ball
# that reaches the end hops onto the kit's left return wire (a scripted ride, like an arrival from above) and is
# released in the left inlane. Too slow to reach the end, it rolls back down through the spinner (two passes).
DOOR_END = (112.0, 862.0)           # the lane's end: the ride onto the return wire starts here
DOOR_LEN = 150.0                    # mouth -> end along the lane's axis
DOOR_HALF = 30.0                    # 60 clear (2 balls)
DOOR_FLARE_HALF = 44.0              # the mouth flares to 88 clear over the first 50 pt
DOOR_FLARE_LEN = 50.0
DOOR_SPINNER_T = 75.0               # spinner line, measured from the mouth
DOOR_POST_R = 5.0
DOOR_AIM_SPEED = 1400.0             # the shot speed the lane is aimed for

def _curved_axis():
    a = None
    # bisect the launch angle so the path passes through DOOR_END; between 100 and 130 deg the height reached at the
    # lane's x falls as the angle grows (the flatter, more direct of the two arcs)
    lo, hi = math.radians(100), math.radians(130)
    for _ in range(60):
        mid = (lo + hi) / 2
        vx, vy = DOOR_AIM_SPEED * math.cos(mid), DOOR_AIM_SPEED * math.sin(mid)
        t = (DOOR_END[0] - SWEET_R[0]) / vx
        y = SWEET_R[1] + vy * t - 450.0 * t * t
        if y > DOOR_END[1]:
            lo = mid
        else:
            hi = mid
    a = (lo + hi) / 2
    vx, vy = DOOR_AIM_SPEED * math.cos(a), DOOR_AIM_SPEED * math.sin(a)
    t_end = (DOOR_END[0] - SWEET_R[0]) / vx
    # the lane's axis = the chord of the path over the lane's length (mouth -> end)
    t = t_end
    while True:
        t -= 0.001
        px, py = SWEET_R[0] + vx * t, SWEET_R[1] + vy * t - 450.0 * t * t
        if math.dist((px, py), DOOR_END) >= DOOR_LEN:
            break
    return unit((px, py), DOOR_END), math.degrees(a)

DOOR_U, DOOR_AIM_DEG = _curved_axis()
_NO = (-DOOR_U[1], DOOR_U[0])       # outer side (toward the left wall)
_NI = (DOOR_U[1], -DOOR_U[0])       # inner side (toward the playfield)

def door_pt(t, side, half=None):
    """A point t along the lane from the mouth, on the 'in' or 'out' side, at the lane's half width there."""
    if half is None:
        half = DOOR_HALF if t >= DOOR_FLARE_LEN else DOOR_FLARE_HALF + (DOOR_HALF - DOOR_FLARE_HALF) * (t / DOOR_FLARE_LEN)
    c = add(DOOR_END, DOOR_U, t - DOOR_LEN)
    return add(c, _NI if side == "in" else _NO, half)

DOOR_MOUTH = add(DOOR_END, DOOR_U, -DOOR_LEN)
DOOR_SPINNER = (door_pt(DOOR_SPINNER_T, "out"), door_pt(DOOR_SPINNER_T, "in"))
DOOR_TRIGGER_T = DOOR_LEN - 20.0     # crossing this line going up starts the ride onto the wire

def door_cap():
    """The lane's round end (solid: a ball that doesn't trigger the ride bounces off it)."""
    a_in = math.atan2(_NI[1], _NI[0])
    return [add(DOOR_END, (math.cos(a_in + math.pi * i / 16), math.sin(a_in + math.pi * i / 16)), DOOR_HALF)
            for i in range(17)]

def door_ride():
    """From the lane's end onto the left return wire, then down the rest of it to the inlane release."""
    wire = return_wire("L")
    j = min(range(len(wire)), key=lambda i: math.dist(wire[i], DOOR_END) if wire[i][1] <= DOOR_END[1] + 10 else 1e9)
    return [add(DOOR_END, DOOR_U, -10.0), DOOR_END, wire[j]] + wire[j + 1:]

ARCH_JOIN_X = 80.0                  # where the block's sloped top meets the arch

def door_block():
    """Closed outline: everything left of the lane, from the knee up to the arch, so there is no slot behind the lane.
    Its top edge slopes from the arch down onto the lane's inner wall, so balls coming down the arch roll back in."""
    cap = door_cap()                                  # inner -> far end -> outer
    outer = [door_pt(t, "out") for t in (DOOR_LEN, DOOR_FLARE_LEN, 0.0)]
    knee = (_knee_x(700.0), 700.0)
    arch = (ARCH_JOIN_X, arch_y(ARCH_JOIN_X) - 1)
    fa, fb = ZOMBIE_DOOR[1], ZOMBIE_DOOR[2]
    pts = [cap[0]] + [arch] + [(WALL_L, ARCH_START), (WALL_L, 760.0), knee, fa, fb] + list(reversed(outer)) + list(reversed(cap))
    return pts + [pts[0]]

def door_inner_wall():
    return [door_pt(DOOR_LEN, "in"), door_pt(DOOR_FLARE_LEN, "in"), door_pt(0.0, "in")]

def _knee_x(y):
    pts = bulge("L")
    for a, b in zip(pts, pts[1:]):
        if a[1] <= y <= b[1]:
            return a[0] + (b[0] - a[0]) * (y - a[1]) / max(b[1] - a[1], 1e-6)
    return WALL_L

# ---------------------------------------------------------------- BARRICADE (the reception desk, upper right)
# Round 1a (three standups stacked up the right wall) failed the curved fan: seen from the left flipper the lowest one
# hid the other two (B 4.5 deg, A and R 0.5-1.5 deg). Now the three targets are faces of the reception desk, a block in
# the upper right whose front runs square to the left flipper's line of sight, so each target shows its full width.
# The desk's top slopes down to the left, so a ball landing on it rolls back into play.
DESK_AIM_DEG = 66.0                 # the bank's centre as seen from the left sweet spot
DESK_DIST = 640.0
DESK_TARGET_W = 34.0
DESK_TARGET_GAP = 6.0               # plain desk front between the targets
BAR_LETTERS = ("B", "A", "R")

def _right_wall_x(y):
    return 2 * CX - _knee_x(y)

def desk():
    """(front line left->right, [(letter, face a, face b, centre, normal)], closed block outline)."""
    a = math.radians(DESK_AIM_DEG)
    c = (SWEET_L[0] + math.cos(a) * DESK_DIST, SWEET_L[1] + math.sin(a) * DESK_DIST)
    n = (-math.cos(a), -math.sin(a))                  # faces the left sweet spot
    t = (math.sin(a), -math.cos(a))                   # along the front, left -> right (down-right)
    half = (3 * DESK_TARGET_W + 2 * DESK_TARGET_GAP) / 2 + 8
    left, right = add(c, t, -half), add(c, t, half)
    targets = []
    for i, letter in enumerate(BAR_LETTERS):
        off = (i - 1) * (DESK_TARGET_W + DESK_TARGET_GAP)
        fa, fb = add(c, t, off - DESK_TARGET_W / 2), add(c, t, off + DESK_TARGET_W / 2)
        targets.append((letter, fa, fb, add(c, t, off), n))
    wall_lo = (_right_wall_x(right[1] - 6), right[1] - 6)
    roof_top = (WALL_R, right[1] + 120)
    block = [left, right, wall_lo, roof_top, left]
    return (left, right), targets, block

def barricade():
    return [(l, c, n, [fa, fb]) for l, fa, fb, c, n in desk()[1]]

# ---------------------------------------------------------------- ZOMBIES (T10 M2 v2: the two dead zones)
# The Lobby's Shot Lab (shotlab-alive-2026-11-23T14-00-48Z) found a span of each flipper's sweep that hit nothing:
#  - right flipper, launched 110-117 deg from (~290-303, ~250-265): first contact the door block's flat underside,
#    x 53-134, y ~705-712;
#  - left flipper, launched 61-63 deg from (~309, ~250): the right wall, y ~630-700 (the knee's upper slope).
# A zombie standup goes where each lands, facing the flipper that makes the shot (aimed at the measured launch point).
ZOMBIE_AIM_R = (296.0, 258.0)       # the right flipper's launch point for these shots (measured)
ZOMBIE_AIM_L = (309.0, 250.0)       # the left flipper's
ZOMBIE_W = 40.0

def _face(c, aim, w=ZOMBIE_W):
    n = unit(c, aim)
    t = (-n[1], n[0])
    return add(c, t, w / 2), add(c, t, -w / 2), n

def _zombie_door():
    """On the door block's underside: (name, a, b, normal, centre). a is the end nearer the wall."""
    c = (105.0, 705.0)               # placed with the measured launches (/tmp search, T10 M2 v2): catches 111-116 deg
    a, b, n = _face(c, ZOMBIE_AIM_R, 50.0)
    if a[0] > b[0]:
        a, b = b, a
    return ("GARY", a, b, n, c)

def _zombie_wall():
    """On a small block on the right wall below the desk, facing the left flipper. a = lower end (on the wall)."""
    # on the 61 deg ray from the left flipper's launch point, its lower end ~4 pt off the wall: catches 61-64 deg and
    # leaves the desk's R (65.7 deg) clear (placed with the measured launches, T10 M2 v2)
    r = 455.0
    c = (ZOMBIE_AIM_L[0] + math.cos(math.radians(61)) * r, ZOMBIE_AIM_L[1] + math.sin(math.radians(61)) * r)
    a, b, n = _face(c, ZOMBIE_AIM_L)
    lo, hi = (a, b) if a[1] < b[1] else (b, a)
    return ("PAM", lo, hi, n, c)

ZOMBIE_DOOR = _zombie_door()
ZOMBIE_WALL = _zombie_wall()

def zombie_wall_block():
    """Closed: the face's lower end onto the wall, the face, then a roof sloping down to the left from the wall."""
    _, lo, hi, n, c = ZOMBIE_WALL
    wall_lo = (_right_wall_x(lo[1] - 4) + 2, lo[1] - 4)
    roof = (_right_wall_x(hi[1] + 30) + 2, hi[1] + 30)
    return [wall_lo, lo, hi, roof, wall_lo]

# ---------------------------------------------------------------- parts for the checks
def room_parts():
    P = {}
    left, right = stair_outline()
    u = STAIR_U_TOP
    P["stairs U (floor-solid)"] = ("poly", [p for p in left if p[1] < u] + [(CX - stair_half_at(u), u), (CX, u + 16),
                                   (CX + stair_half_at(u), u)] + list(reversed([p for p in right if p[1] < u])))
    for s, sx in (("L", -1), ("R", 1)):
        P[f"stairs mouth post {s}"] = ("circle", (CX + sx * STAIR_MOUTH_HALF, STAIR_MOUTH_Y), STAIR_POST_R)
    P["door block"] = ("poly", door_block())
    P["door inner wall"] = ("poly", door_inner_wall())
    P["door mouth post"] = ("circle", door_pt(0.0, "in"), DOOR_POST_R)
    P["reception desk"] = ("poly", desk()[2])
    P["zombie wall block"] = ("poly", zombie_wall_block())
    return P

JOINED = [("stairs U (floor-solid)", "stairs mouth post L"), ("stairs U (floor-solid)", "stairs mouth post R"),
          ("reception desk", "outer wall"), ("zombie wall block", "outer wall"),
          ("door block", "door inner wall"), ("door inner wall", "door mouth post"), ("door block", "outer wall")]

# The room's shots, aimed at: name -> (point, which flipper makes it)
SHOTS = {"STAIRS": ((CX, STAIR_MOUTH_Y + 20), "both"),
         "REVOLVING DOOR": (door_pt(DOOR_SPINNER_T + 10, "in", 0.0), "right"),
         "GARY": (ZOMBIE_DOOR[4], "right"), "PAM": (ZOMBIE_WALL[4], "left"),
         "B": (barricade()[0][1], "left"), "A": (barricade()[1][1], "left"), "R": (barricade()[2][1], "left")}
