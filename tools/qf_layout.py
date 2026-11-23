"""Quest & Flipper (Table 09) — the Haunted Forest region table, M1 round 1: layout sketch (no Swift yet).

World points, origin bottom-left. Real ball scale and physics, as proven on CHOMP! (Table 07) and Neon Labyrinth
(Table 08): ball r 15, flippers 80 (pivot r 12, tip r 6), gravity -6.0 (900 pt/s^2), 51 deg stroke.
Gap rules at this scale: closed < 30 (1 ball), passages >= 45 (1.5 balls), 30-45 = wedge risk.

The lower table (flippers, slings, inlanes, outlanes, lane guides with the r 120 bend, outlane posts, the drain
chute) is Neon Labyrinth's cell kit unchanged (nl_layout.py, checked with pymunk at these physics), centred on x 300
with walls at x 20 / 580. The shooter lane sits outside the right wall (x 580-621), so the world is 640 wide.

Region parts (proposal): an island of forest blocks across the back with three lanes cut into it (the Hollow Log
scoop, the Treant's clearing, the Old Road ramp), the Graveyard orbit up the left wall, the Old Well on the left wall
above the left outlane, a lantern on the right wall, the Witch's Glade above the island (wisps drift there), and the
mode-only parts in the lower table (ghost haunts, roots, gravestone).
"""
import math

# ---------------------------------------------------------------- scale + world
BALL_R = 15.0
D = 2 * BALL_R
CLOSED_MAX = 30.0
PASSAGE_MIN = 45.0

W, H = 640, 1360
CX = 300.0                      # the lower table is symmetric about x 300
WALL_L, WALL_R = 20.0, 580.0    # playfield walls (Neon's cell kit)
SHOOT_IN, SHOOT_OUT = 580.0, 625.0   # shooter lane (45 clear; CHOMP!'s is 41)
ARCH_START, TOP_Y = 1150.0, 1330.0
ARCH_MID_X = (WALL_L + SHOOT_OUT) / 2   # 320.5

def M(p):
    return (2 * CX - p[0], p[1])

def quad(p0, c, p1, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1])
            for t in (i / n for i in range(n + 1))]

def add(a, b, s=1.0):
    return (a[0] + b[0] * s, a[1] + b[1] * s)

def unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    return (dx / L, dy / L)

def circle_pts(c, r, a0=0, a1=360, n=24):
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

# ================================================================ LOWER TABLE: Neon Labyrinth's cell kit, unchanged
FLIP_LEN, FLIP_RP, FLIP_RT = 80.0, 12.0, 6.0
FLIP_REST = math.radians(30)
FLIP_TRAVEL = math.radians(51)
PIVOT_L = (201.0, 200.0)
PIVOT_R = M(PIVOT_L)

def flipper_tip(pivot, side, raised=0.0):
    a = FLIP_REST - raised
    sx = 1 if side == "L" else -1
    return (pivot[0] + sx * FLIP_LEN * math.cos(a), pivot[1] - FLIP_LEN * math.sin(a))

TIP_L_REST = flipper_tip(PIVOT_L, "L")
TIP_R_REST = flipper_tip(PIVOT_R, "R")

OUTLANE_W = 50.0
INLANE_W = 50.0
GUIDE_POST_R = 5.0
GUIDE_X = WALL_L + OUTLANE_W + GUIDE_POST_R            # 75
GUIDE_TOP_Y = 470.0
GUIDE_END_L = (PIVOT_L[0] + (FLIP_RP + 1) * math.sin(FLIP_REST), PIVOT_L[1] + (FLIP_RP + 1) * math.cos(FLIP_REST))
SLANT = math.radians(32)
GUIDE_BEND_L = (GUIDE_X, GUIDE_END_L[1] + (GUIDE_END_L[0] - GUIDE_X) * math.tan(SLANT))
OUTLANE_POST_L = (GUIDE_X - 3.0, GUIDE_TOP_Y + 12.0)
GUIDE_BEND_R = 120.0
def lane_guide_curve():
    u = unit(GUIDE_BEND_L, GUIDE_END_L)
    n = (-u[1], u[0])
    cx = GUIDE_X + GUIDE_BEND_R
    cy = GUIDE_END_L[1] + (GUIDE_BEND_R - (cx - GUIDE_END_L[0]) * n[0]) / n[1]
    a0, a1 = math.pi, math.atan2(-n[1], -n[0]) + 2 * math.pi
    return [(cx + GUIDE_BEND_R * math.cos(a0 + (a1 - a0) * i / 12), cy + GUIDE_BEND_R * math.sin(a0 + (a1 - a0) * i / 12)) for i in range(13)]
OUTLANE_WALL_BOTTOM = 256.0
SLOPE_TOP = (WALL_L, 230.0)
BULGE = (480.0, 760.0, 36.0)
def bulge(side="L"):
    y0, y1, inset = BULGE
    pts = quad((WALL_L, y0), (WALL_L + inset, (y0 + y1) / 2), (WALL_L, y1), 24)
    return pts if side == "L" else [M(p) for p in pts]
def bulge_x_right(y):
    y0, y1, inset = BULGE
    if not y0 <= y <= y1:
        return WALL_R
    t = (y - y0) / (y1 - y0)
    return WALL_R - 2 * (1 - t) * t * inset

SLING_POST_TOP, SLING_POST_TIP, SLING_POST_CORNER = 7.0, 6.0, 5.5
SLING_X = GUIDE_X + INLANE_W + SLING_POST_TOP          # 132
_u = unit(GUIDE_BEND_L, GUIDE_END_L)
_n = (-_u[1], _u[0])
_o0 = add(GUIDE_BEND_L, _n, INLANE_W + SLING_POST_CORNER + 0.5)
_t = (SLING_X - _o0[0]) / _u[0]
SLING_CORNER_L = (SLING_X, _o0[1] + _u[1] * _t)
SLING_TIP_L = add(SLING_CORNER_L, _u, 64.0)
SLING_CORNER_L = (SLING_X, 352.0)
SLING_TOP_L = (SLING_X, 445.0)

INLANE_X = (GUIDE_X + SLING_X) / 2                     # 103.5
INLANE_RELEASE_L = (INLANE_X, 470.0)
INLANE_RELEASE_R = M(INLANE_RELEASE_L)

CHUTE_X = 255.0
APRON_END = (CHUTE_X, 100.0)
CHUTE_BOTTOM = 30.0

SWEET_L = (243.0, 214.0)        # where a cradled / mid-swing ball leaves the flipper (Shot Lab will measure)
SWEET_R = M(SWEET_L)

# ================================================================ SHOOTER LANE + ARCH
SHOOT_FLOOR_Y = 60.0
SHOOT_IN_TOP = 1090.0
LAUNCH_GATE = ((SHOOT_IN, SHOOT_IN_TOP), (SHOOT_OUT, SHOOT_IN_TOP + 34))   # one-way flap: plunges pass up, orbits can't go down

def arch():
    left = quad((WALL_L, ARCH_START), (WALL_L, TOP_Y), (ARCH_MID_X, TOP_Y), 32)
    right = quad((ARCH_MID_X, TOP_Y), (SHOOT_OUT, TOP_Y), (SHOOT_OUT, ARCH_START), 32)
    return left + right[1:]

def arch_x_left(y):
    """x of the arch's left side at height y (y >= ARCH_START)."""
    if y <= ARCH_START:
        return WALL_L
    pts = arch()[:33]
    for a, b in zip(pts, pts[1:]):
        if a[1] <= y <= b[1]:
            return a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])
    return pts[-1][0]

# ================================================================ REGION: the Old Well (left wall, above the left outlane)
# A stone well in a pocket on the left wall, its mouth facing the RIGHT flipper (~126 deg). A clean shot drops in;
# a miss rattles off the rim and falls to the left outlane's mouth below (the risk). Caught balls go by subway to the
# left inlane (the Grand Tour rocket's pattern), so the eject never crosses the open table.
WELL_HOLE = (52.0, 632.0)
WELL_CAPTURE_R = 18.0
_wu = unit(WELL_HOLE, SWEET_R)
_wt = (-_wu[1], _wu[0])
WELL_MOUTH_C = add(WELL_HOLE, _wu, 28.0)
WELL_POST_R = 5.0
WELL_POST_HI = add(WELL_MOUTH_C, _wt, -30.0)           # upper rim post
WELL_POST_LO = add(WELL_MOUTH_C, _wt, 30.0)            # lower rim post
if WELL_POST_HI[1] < WELL_POST_LO[1]:
    WELL_POST_HI, WELL_POST_LO = WELL_POST_LO, WELL_POST_HI
WELL_WALL_LO = (WALL_L, 572.0)
WELL_ROOF_TOP = (WALL_L, 722.0)
def well_block():
    """Closed outline: lower rim (wall -> lower post), the open mouth, upper rim post -> the roof back to the wall.
    The cavity behind the mouth is a catch zone (no ball rests on the rim's back)."""
    return [WELL_WALL_LO, WELL_POST_LO]   # the lower rim
def well_roof():
    return [WELL_POST_HI, WELL_ROOF_TOP]  # upper rim / roof, sloping down-right so wall-sliders come back into play

# ================================================================ REGION: the forest island (blocks across the back)
ROOF_L = (72.0, 1040.0)          # the island's roof: round 2b lowers its left end (misses roll left, down the Graveyard lane)
ROOF_R = (482.0, 1106.0)         # ... down to the right lane, so glade balls roll right and down the right lane
def roof_y(x):
    return ROOF_L[1] + (ROOF_R[1] - ROOF_L[1]) * (x - ROOF_L[0]) / (ROOF_R[0] - ROOF_L[0])

# --- the Graveyard orbit: a lane up the left wall (spinner = "digging"), round the arch, down the right lane
ORBIT_INNER_X = 72.0
ORBIT_BOTTOM_Y = 790.0
ORBIT_POST_R = 5.0
SPINNER_Y = 900.0                # the graveyard spinner across the orbit lane

# --- the Hollow Log (scoop at the back of a short lane, kicks out down the lane onto the left flipper)
LOG_L_X, LOG_R_X = 160.0, 222.0
LOG_MOUTH_Y = 805.0
LOG_HOLE = ((LOG_L_X + LOG_R_X) / 2, 905.0)
LOG_BACK_Y = 935.0
LOG_POST_R = 5.0

# --- the Treant's clearing: an alcove whose mouth is the centre shot; bark = 3 drops, then the trunk (bash target)
TREANT_L_X, TREANT_R_X = 250.0, 350.0
TREANT_MOUTH_Y = 880.0
TREANT_POST_R = 5.0
BARK_Y = 990.0                   # the bark row sits just in front of the trunk: a fallen drop opens a slot
                                 # straight onto the trunk face 12 pt behind (no pocket behind the bank)
BARK_W, BARK_DEPTH = 28.0, 10.0
BARK_XS = [267.0, 300.0, 333.0]
TRUNK_Y = 1012.0                 # trunk face (bash plate) at the back of the clearing
TRUNK_HALF = 36.0
TREANT_BACK_Y = 1030.0

# --- the Old Road ramp (the exit shot): mouth right of centre, climbs up, hooks right, wire down the right lane
RAMP_C_X = 432.0
RAMP_MOUTH_Y = 805.0
RAMP_MOUTH_HALF = 33.0           # posts 66 apart, 56 clear (Neon's)
RAMP_CHANNEL_HALF = 23.0
RAMP_FLARE = 60.0
RAMP_U_LEN = 80.0
RAMP_POST_R = 5.0
ISLAND_R_X = 482.0               # the island's right edge = the right lane's left side

# the stone blocks between the lanes (floor-solid), named for the art
def island():
    """The island's outline as one closed polygon, left to right along its bottom faces (the lane mouths are cut in),
    then back along the roof."""
    lp, rp = (LOG_L_X, LOG_MOUTH_Y), (LOG_R_X, LOG_MOUTH_Y)
    tl, tr = (TREANT_L_X, TREANT_MOUTH_Y), (TREANT_R_X, TREANT_MOUTH_Y)
    rml = (RAMP_C_X - RAMP_MOUTH_HALF, RAMP_MOUTH_Y)
    rmr = (RAMP_C_X + RAMP_MOUTH_HALF, RAMP_MOUTH_Y)
    u_top = RAMP_MOUTH_Y + RAMP_U_LEN
    pts = [(ORBIT_INNER_X, ORBIT_BOTTOM_Y), lp,
           # the log lane: left wall up, the back with a gable, right wall down
           (LOG_L_X, LOG_BACK_Y), (LOG_HOLE[0], LOG_BACK_Y + 14), (LOG_R_X, LOG_BACK_Y), rp,
           # connector face down-right to the clearing's left post
           tl,
           # the clearing: up the left wall, across the back (the trunk sits on it), down the right wall
           (TREANT_L_X, TREANT_BACK_Y), (TREANT_R_X, TREANT_BACK_Y), tr,
           # the stone face up-right to the ramp's left post; the ramp's U (floor-solid) with its gable back
           rml, (RAMP_C_X - ramp_half_at(u_top), u_top), (RAMP_C_X, u_top + 16), (RAMP_C_X + ramp_half_at(u_top), u_top), rmr,
           # the right flank of the ramp out to the island's right edge, then up it
           (ISLAND_R_X, RAMP_MOUTH_Y + 30), (ISLAND_R_X, ROOF_R[1])] + island_top() + [
           ROOF_L, (ORBIT_INNER_X, ORBIT_BOTTOM_Y)]
    return pts

def island_top():
    """Round 2b: the island's top between its right corner and ROOF_L, round the upper flipper — the roof right of the
    pivot slopes down to the right lane; under the flipper it runs 2-8 pt below its underside (closed); from under the
    tip it slopes down-left to the Graveyard lane, so a ball rolling off the tip rolls on left."""
    p = UF_PIVOT
    tip = flipper_tip_len(p, UF_LEN)
    a = FLIP_REST
    under = lambda q, off: (q[0] + math.sin(a) * off, q[1] - math.cos(a) * off)   # below the centreline (right-hand normal)
    return [(p[0] + UF_RP * math.cos(math.radians(-35)), p[1] + UF_RP * math.sin(math.radians(-35)) - 2),
            under(p, UF_RP + 2), under(tip, UF_RT + 7)]

def flipper_tip_len(pivot, length, raised=0.0):
    a = FLIP_REST - raised
    return (pivot[0] - length * math.cos(a), pivot[1] - length * math.sin(a))

def ramp_half_at(y):
    f = min(1.0, max(0.0, (y - RAMP_MOUTH_Y) / RAMP_FLARE))
    return RAMP_MOUTH_HALF + (RAMP_CHANNEL_HALF - RAMP_MOUTH_HALF) * (f * f * (3 - 2 * f))

class RampPath:
    """The path builder every table uses (TourRampPath)."""
    def __init__(self, start, heading):
        self.points, self.headings, self.dist, self.h = [start], [heading], [0.0], heading
        self.start, self.heading0, self.pieces = start, heading, []   # (radius, value): radius 0 = a line of length value
    def line(self, L, step=10):
        self.pieces.append((0.0, L))
        n = max(1, math.ceil(L / step)); x0, y0 = self.points[-1]; s0 = self.dist[-1]
        for i in range(1, n + 1):
            d = L * i / n
            self.points.append((x0 + d * math.cos(self.h), y0 + d * math.sin(self.h))); self.headings.append(self.h); self.dist.append(s0 + d)
    def arc(self, r, turn, step=8):
        self.pieces.append((r, turn))
        n = max(2, math.ceil(abs(turn) * r / step)); sg = 1 if turn > 0 else -1
        x0, y0 = self.points[-1]; c = (x0 - sg * r * math.sin(self.h), y0 + sg * r * math.cos(self.h))
        a0 = math.atan2(y0 - c[1], x0 - c[0]); s0 = self.dist[-1]; h0 = self.h
        for i in range(1, n + 1):
            f = i / n; a = a0 + turn * f
            self.points.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a))); self.headings.append(h0 + turn * f)
            self.dist.append(s0 + abs(turn) * r * f)
        self.h = h0 + turn
    def rails(self, w):
        L = [(p[0] - w * math.sin(h), p[1] + w * math.cos(h)) for p, h in zip(self.points, self.headings)]
        R = [(p[0] + w * math.sin(h), p[1] - w * math.cos(h)) for p, h in zip(self.points, self.headings)]
        return L, R

RAMP_HOOK_R = 34.0
WIRE_X = 531.0                   # the return wire's run down the right lane (raised)
def ramp_path():
    p = RampPath((RAMP_C_X, RAMP_MOUTH_Y), math.pi / 2)
    p.line(1100 - RAMP_MOUTH_Y)                    # up through the island (plastic, climbing)
    p.arc(RAMP_HOOK_R, -math.radians(90))          # hook right: the apex (made switch, Forest Gate diverter)
    p.line(WIRE_X - RAMP_HOOK_R - p.points[-1][0]) # across to the right lane
    p.arc(RAMP_HOOK_R, -math.radians(90))          # turn straight down
    p.line(p.points[-1][1] - 640)                  # the wire down the right lane, over the lantern
    # S-bend into the right inlane, then straight down
    dx = WIRE_X - INLANE_RELEASE_R[0]
    r = 60.0
    turn = math.acos(1 - dx / (2 * r))
    p.arc(r, -turn); p.arc(r, turn)
    p.line(max(0.0, p.points[-1][1] - INLANE_RELEASE_R[1]))
    return p
RAMP_APEX_S = (1100 - RAMP_MOUTH_Y) + RAMP_HOOK_R * math.radians(45)
FOREST_GATE = (520.0, 1185.0)    # where the ball goes when the exit is lit (a hold; the visit ends)

# ================================================================ REGION: the right lane + the lantern on the right wall
LANTERN_E_C = (548.0, 712.0)
LANTERN_W, LANTERN_DEPTH = 32.0, 10.0
def standup(center, aim_at, width, depth=10.0):
    n = unit(center, aim_at)
    t = (-n[1], n[0])
    a = add(center, t, width / 2)
    b = add(center, t, -width / 2)
    return a, b, add(a, n, -depth), add(b, n, -depth), n
LANTERN_E = standup(LANTERN_E_C, SWEET_L, LANTERN_W)
def lantern_block():
    """The east lantern's block: wall -> face (lower end) ... face (upper end) -> sloping cap back to the wall."""
    fa, fb, ba, bb, n = LANTERN_E
    lo, hi = (fa, fb) if fa[1] < fb[1] else (fb, fa)
    return [(bulge_x_right(lo[1] - 30), lo[1] - 30), lo, hi, (bulge_x_right(hi[1] + 40), hi[1] + 40)]

# ================================================================ REGION: the Witch's Glade (above the island)
# Wisps drift here on slow loops; plunges (over the launch gate) and Graveyard orbits pass through it.
WISPS = [((110.0, 1122.0), (18.0, 8.0), 7.0), ((280.0, 1246.0), (18.0, 8.0), 9.0), ((400.0, 1230.0), (18.0, 8.0), 8.0)]
# (M1 round 2b: re-placed by a search: two in the upper flipper's shot fan (121 deg and 72 deg from its sweet spot),
#  one low in the glade's left; every loop >= 46 clear of the arch, the island, the diverter, the upper flipper at
#  rest and raised, and the next loop)
WISP_R = 13.0                    # (centre, (ax, ay), period s): x = cx + ax sin(2 pi t / P), y = cy + ay sin(4 pi t / P)
def wisp_path(i, n=48):
    (cx, cy), (ax, ay), _ = WISPS[i]
    return [(cx + ax * math.sin(2 * math.pi * k / n), cy + ay * math.sin(4 * math.pi * k / n)) for k in range(n + 1)]

# ================================================================ M1 round 2 (Aaron, voice 2026-11-22): the upper flipper
# Orbits rode the arch round the top and never met a wisp. Aaron: "something that would knock the ball down, and then
# another flipper up there that you then use to attack the wisp" — the drop only "sometimes".
# A right-hand upper flipper in the glade's top-right, under the Old Road's raised hook (ramp balls pass over it). Its
# feed: a one-way DIVERTER flap from the arch's right side down-left to just above the pivot — solid only for a ball
# coming DOWN the arch (an orbit), never for a plunge going up, and only while it's raised (a mode: "sometimes").
# Lowered, orbits ride on past the flipper (71 pt between the pivot and the arch) to the launch gate and the right lane.
# The flipper shoots up-left across the glade at the wisps (and later the Witch's lanterns); a missed ball rolls off
# its tip onto the island's roof and down the right lane.
UF_PIVOT = (400.0, 1125.0)          # round 2b (Aaron's red mark): on the forest block's top, under the glade
UF_LEN, UF_RP, UF_RT = 64.0, 10.0, 5.0
def right_arch_y(x):
    """y of the arch's right side at x (x between the top's middle and the shooter lane's outer wall)."""
    f = (x - ARCH_MID_X) / (SHOOT_OUT - ARCH_MID_X)
    one_minus_t = math.sqrt(max(0.0, 1 - f))
    t = 1 - one_minus_t
    return TOP_Y - (TOP_Y - ARCH_START) * t * t
DIVERTER_A = (606.0, right_arch_y(606.0))
DIVERTER_B = (UF_PIVOT[0] - (UF_RP + 1) * math.sin(FLIP_REST), UF_PIVOT[1] + (UF_RP + 1) * math.cos(FLIP_REST))
def uf_poly(raised=0.0):
    return flipper_poly_len(UF_PIVOT, "R", UF_LEN, UF_RP, UF_RT, raised)
def flipper_poly_len(pivot, side, length, rp, rt, raised=0.0):
    a = FLIP_REST - raised
    sx = 1 if side == "L" else -1
    dx, dy = sx * math.cos(a), -math.sin(a)
    tip = (pivot[0] + dx * length, pivot[1] + dy * length)
    nx, ny = -dy, dx
    return tip, [(pivot[0] + nx * rp, pivot[1] + ny * rp), (tip[0] + nx * rt, tip[1] + ny * rt),
                 (tip[0] - nx * rt, tip[1] - ny * rt), (pivot[0] - nx * rp, pivot[1] - ny * rp)]
UF_SWEET = (364.0, 1126.0)       # where a cradled / mid-swing ball leaves the upper flipper (estimate)

# M1 v6 (Aaron: a left-flipper shot up the right lane "just goes all the way around"; fix 1): a one-way ORBIT STOP, a
# short flap hanging radially from the arch just right of the top. Raised with the diverter (any wisp alive), it's solid
# only for a ball on its right side, i.e. one riding the arch counterclockwise (up the right lane, or a plunge): the ball
# stops and drops onto the diverter, then rolls onto the upper flipper. Clockwise orbits (the Graveyard lane) pass it.
STOP_X, STOP_LEN = 500.0, 40.0
def _stop():
    y = right_arch_y(STOP_X); y2 = right_arch_y(STOP_X + 1)
    t = (1.0, y2 - y); n = math.hypot(*t); t = (t[0] / n, t[1] / n)
    nin = (t[1], -t[0])                       # inward (down-left) normal
    return (STOP_X, y), (STOP_X + nin[0] * STOP_LEN, y + nin[1] * STOP_LEN)
STOP_A, STOP_B = _stop()

# ================================================================ MODE-ONLY parts in the lower table (pop-ups / drifters)
GHOST_HAUNTS = [(250.0, 738.0), (360.0, 738.0)]   # ghosts fade in at one of these, in the gaps between the shot paths
GHOST_R = 16.0                                    # solid only while visible; a light ball hits them any time
ROOTS = (454.0, 474.0)                            # Treant fight: a root knot rises on the RIGHT sling's top, grabs a slow ball
                                                  # (on the left it stood in the right flipper's Old Well line)
ROOTS_R = 14.0
GRAVESTONE = [(284.0, 548.0), (316.0, 548.0), (316.0, 574.0), (308.0, 584.0), (300.0, 587.0), (292.0, 584.0), (284.0, 574.0), (284.0, 548.0)]
def drifter_path(n=40):
    """The lower-table ghost (a sensor: the ball passes through; a touch while visible = bonus damage)."""
    return [(70 + 460 * k / n, 600 + 40 * math.sin(2.5 * math.pi * k / n)) for k in range(n + 1)]

KICKBACK = (45.0, 300.0)         # left outlane: armour gear lights it (not lit by default)

# ================================================================ the floor parts (every solid on the floor layer)
def outer_wall():
    """Chute lip -> left slope -> left wall -> (the well is its own part) -> arch -> shooter lane outer wall -> lane floor
    -> shooter lane inner wall (x 580) down to the right slope -> chute lip."""
    pts = [(CHUTE_X, CHUTE_BOTTOM), APRON_END, SLOPE_TOP, (WALL_L, ARCH_START)]
    pts += arch()[1:]
    pts += [(SHOOT_OUT, SHOOT_FLOOR_Y), (SHOOT_IN, SHOOT_FLOOR_Y)]
    return pts

def right_wall():
    """The playfield's right wall (the shooter lane's inner wall seen from the table), with the bulge."""
    pts = [(SHOOT_IN, SHOOT_IN_TOP), (SHOOT_IN, BULGE[1])] + list(reversed(bulge("R")))[1:] + [M(SLOPE_TOP), M(APRON_END), M((CHUTE_X, CHUTE_BOTTOM))]
    return pts

def floor_parts(mode_parts=True):
    P = {}
    P["outer wall"] = ("poly", outer_wall())
    P["right wall"] = ("poly", right_wall())
    P["shooter lane wall"] = ("poly", [(SHOOT_IN, SHOOT_FLOOR_Y), (SHOOT_IN, 232.0)])
    for s, f in (("L", lambda p: p), ("R", M)):
        P[f"lane guide {s}"] = ("poly", [f((GUIDE_X, GUIDE_TOP_Y))] + [f(p) for p in lane_guide_curve()] + [f(GUIDE_END_L)])
        P[f"lane guide post {s}"] = ("circle", f((GUIDE_X, GUIDE_TOP_Y)), GUIDE_POST_R)
        P[f"outlane post {s}"] = ("circle", f(OUTLANE_POST_L), GUIDE_POST_R)
        P[f"outlane post rail {s}"] = ("poly", [f((GUIDE_X, GUIDE_TOP_Y)), f(OUTLANE_POST_L)])
        P[f"outlane wall {s}"] = ("poly", [f(lane_guide_curve()[0]), f((GUIDE_X, OUTLANE_WALL_BOTTOM))])
        P[f"sling {s}"] = ("poly", [f(SLING_TOP_L), f(SLING_CORNER_L), f(SLING_TIP_L), f(SLING_TOP_L)])
        P[f"sling top post {s}"] = ("circle", f(SLING_TOP_L), SLING_POST_TOP)
        P[f"sling tip post {s}"] = ("circle", f(SLING_TIP_L), SLING_POST_TIP)
        P[f"flipper pivot {s}"] = ("circle", PIVOT_L if s == "L" else PIVOT_R, FLIP_RP)
    P["well lower rim"] = ("poly", well_block())
    P["well roof"] = ("poly", well_roof())
    P["well post lo"] = ("circle", WELL_POST_LO, WELL_POST_R)
    P["well post hi"] = ("circle", WELL_POST_HI, WELL_POST_R)
    P["island"] = ("poly", island())
    P["orbit post"] = ("circle", (ORBIT_INNER_X, ORBIT_BOTTOM_Y), ORBIT_POST_R)
    P["log post L"] = ("circle", (LOG_L_X, LOG_MOUTH_Y), LOG_POST_R)
    P["log post R"] = ("circle", (LOG_R_X, LOG_MOUTH_Y), LOG_POST_R)
    P["treant post L"] = ("circle", (TREANT_L_X, TREANT_MOUTH_Y), TREANT_POST_R)
    P["treant post R"] = ("circle", (TREANT_R_X, TREANT_MOUTH_Y), TREANT_POST_R)
    P["ramp post L"] = ("circle", (RAMP_C_X - RAMP_MOUTH_HALF, RAMP_MOUTH_Y), RAMP_POST_R)
    P["ramp post R"] = ("circle", (RAMP_C_X + RAMP_MOUTH_HALF, RAMP_MOUTH_Y), RAMP_POST_R)
    P["lantern E block"] = ("poly", lantern_block())
    P["launch gate"] = ("poly", list(LAUNCH_GATE))
    for i, x in enumerate(BARK_XS):
        P[f"bark {i + 1}"] = ("poly", [(x - BARK_W / 2, BARK_Y), (x + BARK_W / 2, BARK_Y), (x + BARK_W / 2, BARK_Y + BARK_DEPTH),
                                        (x - BARK_W / 2, BARK_Y + BARK_DEPTH), (x - BARK_W / 2, BARK_Y)])
    P["trunk"] = ("poly", [(CX - TRUNK_HALF, TRUNK_Y), (CX + TRUNK_HALF, TRUNK_Y)])
    tip, poly = uf_poly()
    P["upper flipper"] = ("poly", poly + [poly[0]])
    P["upper flipper pivot"] = ("circle", UF_PIVOT, UF_RP)
    P["upper flipper tip"] = ("circle", tip, UF_RT)
    if mode_parts:
        P["diverter (mode)"] = ("poly", [DIVERTER_A, DIVERTER_B])
        P["orbit stop (mode)"] = ("poly", [STOP_A, STOP_B])
        for i, h in enumerate(GHOST_HAUNTS):
            P[f"ghost haunt {'LR'[i]} (mode)"] = ("circle", h, GHOST_R)
        P["roots (mode)"] = ("circle", ROOTS, ROOTS_R)
        P["gravestone (mode)"] = ("poly", GRAVESTONE)
    return P

def flipper_poly(pivot, side, raised=0.0):
    a = FLIP_REST - raised
    sx = 1 if side == "L" else -1
    dx, dy = sx * math.cos(a), -math.sin(a)
    tip = (pivot[0] + dx * FLIP_LEN, pivot[1] + dy * FLIP_LEN)
    nx, ny = -dy, dx
    return tip, [(pivot[0] + nx * FLIP_RP, pivot[1] + ny * FLIP_RP), (tip[0] + nx * FLIP_RT, tip[1] + ny * FLIP_RT),
                 (tip[0] - nx * FLIP_RT, tip[1] - ny * FLIP_RT), (pivot[0] - nx * FLIP_RP, pivot[1] - ny * FLIP_RP)]

# the shots, and where each is aimed (for the fan and the straight-line clearance)
SHOTS = {
    "Old Well": WELL_HOLE,
    "Graveyard orbit": ((WALL_L + ORBIT_INNER_X) / 2, ORBIT_BOTTOM_Y + 10),
    "Hollow Log": (LOG_HOLE[0], LOG_MOUTH_Y + 10),
    "Treant": (CX, TREANT_MOUTH_Y + 10),
    "Old Road (exit)": (RAMP_C_X, RAMP_MOUTH_Y + 10),
    "East lantern": LANTERN_E_C,
}
SHOT_FLIPPERS = {   # which flipper makes each shot (the opposite one, as on real tables); both for the centre
    "Old Well": ["right"], "Graveyard orbit": ["right"], "Hollow Log": ["left", "right"],
    "Treant": ["left", "right"], "Old Road (exit)": ["left", "right"], "East lantern": ["left"],
}
