"""The Naturalist (Table 11) — the field station, M1 round 1: layout sketch (no Swift yet).

World points, origin bottom-left. Real ball scale and physics, as on CHOMP! (07), Neon Labyrinth (08) and
Quest & Flipper (09): ball r 15, flippers 80 (pivot r 12, tip r 6), gravity 900 pt/s^2, 51 deg stroke.
Gap rules at this scale: closed < 30 (1 ball), passages >= 45 (1.5 balls), 30-45 = wedge risk.

World 640 x 1360 with a plunger, like Quest: playfield walls x 20 / 580 (centred on x 300), shooter lane x 580-625.
The lower table is Neon Labyrinth's cell kit (flippers, slings, inlanes, outlanes, lane guides with the r 120 bend,
outlane posts, the 90 pt drain chute) and its deep-knee right bulge (nl_kit.BULGE, the T8 M1 v3 outlane fix).

The field station (proposal): four habitats round the station cabin.
  POND  (left)        the Reed Bed scoop in a pocket on the left wall (right flipper, steep) and the lily-pad lane, a
                      short lane into a pond basin with three lily pads (both flippers, left of centre).
  CAVE  (upper left)  the dark tunnel orbit up the left wall (right flipper), round the arch, down the grove lane.
  CABIN (centre)      the specimen scoop at the back of the centre channel (both flippers): a catch zone; subway to
                      the right inlane.
  SKY   (top)         the sky ramp right of centre (both flippers) climbing to the top, then the sky rail (a wire)
                      across the top behind the cabin and down the left wall into the left inlane.
  GROVE (right)       the spinner lane up the right wall through the trees (left flipper): the right orbit.
  CANOPY (top)        three pop bumpers under the arch, fed by plunges and orbits that fall short.
Creature stages are mode-only (drawn dashed): they exist only while a creature is out.
"""
import math

# ---------------------------------------------------------------- scale + world
BALL_R = 15.0
D = 2 * BALL_R
CLOSED_MAX = 30.0
PASSAGE_MIN = 45.0

W, H = 640, 1360
CX = 300.0
WALL_L, WALL_R = 20.0, 580.0
SHOOT_IN, SHOOT_OUT = 580.0, 625.0
ARCH_START, TOP_Y = 1150.0, 1330.0
ARCH_MID_X = (WALL_L + SHOOT_OUT) / 2   # 322.5


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


def circle_pts(c, r, n=24):
    return [(c[0] + r * math.cos(2 * math.pi * i / n), c[1] + r * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]


# ================================================================ LOWER TABLE: Neon Labyrinth's cell kit
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
# M1 r2 (Aaron 2026-11-24: "instead of curved can we have the traditional angled feeds? The curved ones make it very
# difficult to catch a ball as the ball doesn't slow down"): a straight vertical guide, a sharp (rubber-lined) corner,
# then a straight slant to just above the pivot. The slant is 20 deg (Neon's kit: 32 deg with an r 120 bend).
# nat_inlane_sim.py: balls released down the inlane at 150-800 pt/s meet the flipper at a median 342 pt/s (309-364);
# Neon's curve: 622 (423-753). CHOMP!'s measured catches: 91-98 % under 300, 32 % at 300-400, ~1 % over 500.
SLANT = math.radians(20)
GUIDE_BEND_L = (GUIDE_X, GUIDE_END_L[1] + (GUIDE_END_L[0] - GUIDE_X) * math.tan(SLANT))
OUTLANE_POST_L = (GUIDE_X - 3.0, GUIDE_TOP_Y + 12.0)
GUIDE_BEND_R = 120.0


def lane_guide_path():
    """The left lane guide: top post, straight down to the corner, straight slant to the end (no curve)."""
    return [(GUIDE_X, GUIDE_TOP_Y), GUIDE_BEND_L, GUIDE_END_L]


def lane_guide_curve():
    """Neon's r 120 bend (kept for the r1 comparison only; not used by floor_parts any more)."""
    u = unit(GUIDE_BEND_L, GUIDE_END_L)
    n = (-u[1], u[0])
    cx = GUIDE_X + GUIDE_BEND_R
    cy = GUIDE_END_L[1] + (GUIDE_BEND_R - (cx - GUIDE_END_L[0]) * n[0]) / n[1]
    a0, a1 = math.pi, math.atan2(-n[1], -n[0]) + 2 * math.pi
    return [(cx + GUIDE_BEND_R * math.cos(a0 + (a1 - a0) * i / 12), cy + GUIDE_BEND_R * math.sin(a0 + (a1 - a0) * i / 12))
            for i in range(13)]


OUTLANE_WALL_BOTTOM = 256.0
SLOPE_TOP = (WALL_L, 230.0)

# Neon's deep-knee bulge (nl_kit.BULGE): in from y 760 to 44 pt at y 539.5, back to the wall at y 515.
BULGE = (515.0, 760.0, 44.0, 0.1)


def bulge(side="L", n=24):
    y0, y1, inset, pf = BULGE
    yp = y0 + pf * (y1 - y0)
    pts = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        t = (y - y0) / (yp - y0) if y <= yp else (y1 - y) / (y1 - yp)
        pts.append((WALL_L + inset * math.sin(t * math.pi / 2) ** 1.5, y))
    pts.append((WALL_L + inset, yp))
    pts.sort(key=lambda p: p[1])
    return pts if side == "L" else [M(p) for p in pts]


SLING_POST_TOP, SLING_POST_TIP, SLING_POST_CORNER = 7.0, 6.0, 5.5
SLING_X = GUIDE_X + INLANE_W + SLING_POST_TOP          # 132
_u = unit(GUIDE_BEND_L, GUIDE_END_L)
_n = (-_u[1], _u[0])
_o0 = add(GUIDE_BEND_L, _n, INLANE_W + SLING_POST_CORNER + 0.5)
_t = (SLING_X - _o0[0]) / _u[0]
SLING_CORNER_L = (SLING_X, _o0[1] + _u[1] * _t)
SLING_TIP_L = add(SLING_CORNER_L, _u, 64.0)
SLING_CORNER_L = (SLING_X, 300.0)   # M1 r2: the lowest corner that keeps the inlane 50 clear of the angled guide
SLING_TIP_L = add(SLING_CORNER_L, _u, 64.0)
SLING_TOP_L = (SLING_X, 445.0)

INLANE_X = (GUIDE_X + SLING_X) / 2                     # 103.5
INLANE_RELEASE_L = (INLANE_X, 470.0)
INLANE_RELEASE_R = M(INLANE_RELEASE_L)

CHUTE_X = 255.0
APRON_END = (CHUTE_X, 100.0)
CHUTE_BOTTOM = 30.0

SWEET_L = (243.0, 214.0)        # where a cradled / mid-swing ball leaves (the Shot Lab measures the real ones)
SWEET_R = M(SWEET_L)

KICKBACK = (45.0, 300.0)        # left outlane: lit only by a companion (Lantern Frog) or a research reward

# ================================================================ SHOOTER LANE + ARCH (Quest's)
SHOOT_FLOOR_Y = 60.0
SHOOT_IN_TOP = 1090.0
LAUNCH_GATE = ((SHOOT_IN, SHOOT_IN_TOP), (SHOOT_OUT, SHOOT_IN_TOP + 34))   # one-way: plunges up, orbits deflected


def arch():
    left = quad((WALL_L, ARCH_START), (WALL_L, TOP_Y), (ARCH_MID_X, TOP_Y), 32)
    right = quad((ARCH_MID_X, TOP_Y), (SHOOT_OUT, TOP_Y), (SHOOT_OUT, ARCH_START), 32)
    return left + right[1:]


# ================================================================ POND (left): the Reed Bed scoop on the left wall
# Quest's Old Well pocket, re-skinned: its mouth faces the RIGHT flipper (~126 deg); a catch goes by subway to the
# left inlane. It replaces the left bulge, as the Old Well did (pymunk on Quest: in 8/33, low misses 4/33 to the
# left outlane = the risk).
REED_HOLE = (52.0, 632.0)
REED_CAPTURE_R = 18.0
_wu = unit(REED_HOLE, SWEET_R)
_wt = (-_wu[1], _wu[0])
REED_MOUTH_C = add(REED_HOLE, _wu, 28.0)
REED_POST_R = 5.0
REED_POST_HI = add(REED_MOUTH_C, _wt, -30.0)
REED_POST_LO = add(REED_MOUTH_C, _wt, 30.0)
if REED_POST_HI[1] < REED_POST_LO[1]:
    REED_POST_HI, REED_POST_LO = REED_POST_LO, REED_POST_HI
REED_WALL_LO = (WALL_L, 572.0)
REED_ROOF_TOP = (WALL_L, 722.0)

# ================================================================ the station island (one solid across the back)
# Lane mouths at y 805-880 (~55-62 % up, the shot line), the island's roof slopes down to the right so canopy balls
# roll into the grove lane and come down the right side.
CAVE_INNER_X = 72.0             # the cave orbit lane: x 20-72 (52 wide, 47 clear past the r 5 post)
CAVE_BOTTOM_Y = 790.0
CAVE_POST_R = 5.0
CAVE_TUNNEL = (880.0, 1150.0)   # the dark tunnel: a drawn rock arch over the lane from y 880 to the arch

LILY_L_X, LILY_R_X = 160.0, 222.0   # the lily-pad lane: posts 62 apart = 52 clear
LILY_MOUTH_Y = 805.0
LILY_POST_R = 5.0
LILY_NECK_Y = 880.0                 # the lane opens into the pond basin above here
POND_BASIN = dict(l=98.0, r=246.0, lo=950.0, hi=1050.0, peak=(172.0, 1080.0))
LILY_SWITCH_Y = 860.0               # rollover in the lane (going up = a pond shot)

CABIN_L_X, CABIN_R_X = 262.0, 338.0  # the centre channel: posts 76 apart = 66 clear
CABIN_MOUTH_Y = 880.0
CABIN_POST_R = 5.0
CABIN_BACK_Y = 1030.0
CABIN_CATCH_Y = 965.0                # specimen scoop: ANY ball above this line in the channel is caught
SPECIMEN_HOLE = (300.0, 995.0)
CABIN_ART = (232.0, 1040.0, 368.0, 1132.0)   # the cabin drawn behind the channel (x0, y0, x1, y1), on the island

RAMP_C_X = 432.0
RAMP_MOUTH_Y = 805.0
RAMP_MOUTH_HALF = 33.0           # posts 66 apart = 56 clear (Neon's / Quest's)
RAMP_CHANNEL_HALF = 23.0
RAMP_FLARE = 60.0
RAMP_U_LEN = 80.0
RAMP_POST_R = 5.0

GROVE_INNER_X = 520.0            # the grove lane: x 520-580 (60 wide, 55 clear past the post)
GROVE_BOTTOM_Y = 820.0
GROVE_POST_R = 5.0
GROVE_SPINNER_Y = 900.0
GROVE_SWITCH_Y = 860.0

# The grove branch: a deflector over the top of the grove lane (a big tree limb in the art). A grove shot rising along
# the right wall met the arch's flat right shoulder at ~34 deg and fell straight back down the lane (45 % in pymunk);
# the branch's underside turns it left into the canopy and the pops. Its right end leaves 47 to the outer wall, the
# way down for cave orbits (then the launch gate drops them into the grove lane) and the way up for plunges.
BRANCH = ((578.0, 1150.0), (530.0, 1185.0))

ROOF_L = (CAVE_INNER_X, 1160.0)
ROOF_R = (GROVE_INNER_X, 1110.0)


def roof_y(x):
    return ROOF_L[1] + (ROOF_R[1] - ROOF_L[1]) * (x - ROOF_L[0]) / (ROOF_R[0] - ROOF_L[0])


def ramp_half_at(y):
    f = min(1.0, max(0.0, (y - RAMP_MOUTH_Y) / RAMP_FLARE))
    return RAMP_MOUTH_HALF + (RAMP_CHANNEL_HALF - RAMP_MOUTH_HALF) * (f * f * (3 - 2 * f))


def pond_basin():
    """The lily-pad lane's walls and the pond basin, left post -> round the basin -> right post."""
    b = POND_BASIN
    back = quad((b["l"], b["hi"]), (b["peak"][0], b["peak"][1] + 42), (b["r"], b["hi"]), 12)
    return ([(LILY_L_X, LILY_MOUTH_Y), (LILY_L_X, LILY_NECK_Y), (b["l"], b["lo"])] + back +
            [(b["r"], b["lo"]), (LILY_R_X, LILY_NECK_Y), (LILY_R_X, LILY_MOUTH_Y)])


def island():
    u_top = RAMP_MOUTH_Y + RAMP_U_LEN
    pts = [(CAVE_INNER_X, CAVE_BOTTOM_Y)]
    pts += pond_basin()
    pts += [(CABIN_L_X, CABIN_MOUTH_Y), (CABIN_L_X, CABIN_BACK_Y), (CX, CABIN_BACK_Y + 18), (CABIN_R_X, CABIN_BACK_Y),
            (CABIN_R_X, CABIN_MOUTH_Y),
            (RAMP_C_X - RAMP_MOUTH_HALF, RAMP_MOUTH_Y), (RAMP_C_X - ramp_half_at(u_top), u_top), (RAMP_C_X, u_top + 16),
            (RAMP_C_X + ramp_half_at(u_top), u_top), (RAMP_C_X + RAMP_MOUTH_HALF, RAMP_MOUTH_Y),
            (GROVE_INNER_X, GROVE_BOTTOM_Y), ROOF_R, ROOF_L, (CAVE_INNER_X, CAVE_BOTTOM_Y)]
    return pts


def point_in_poly(p, poly):
    x, y = p
    inside = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


# ================================================================ SKY: the sky ramp and the sky rail (a wire)
class RampPath:
    """The path builder every table uses (TourRampPath / qf_layout.RampPath)."""
    def __init__(self, start, heading):
        self.points, self.headings, self.dist, self.h = [start], [heading], [0.0], heading
        self.pieces = []

    def line(self, L, step=10):
        self.pieces.append((0.0, L))
        n = max(1, math.ceil(L / step)); x0, y0 = self.points[-1]; s0 = self.dist[-1]
        for i in range(1, n + 1):
            d = L * i / n
            self.points.append((x0 + d * math.cos(self.h), y0 + d * math.sin(self.h)))
            self.headings.append(self.h); self.dist.append(s0 + d)

    def arc(self, r, turn, step=8):
        self.pieces.append((r, turn))
        n = max(2, math.ceil(abs(turn) * r / step)); sg = 1 if turn > 0 else -1
        x0, y0 = self.points[-1]; c = (x0 - sg * r * math.sin(self.h), y0 + sg * r * math.cos(self.h))
        a0 = math.atan2(y0 - c[1], x0 - c[0]); s0 = self.dist[-1]; h0 = self.h
        for i in range(1, n + 1):
            f = i / n; a = a0 + turn * f
            self.points.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
            self.headings.append(h0 + turn * f); self.dist.append(s0 + abs(turn) * r * f)
        self.h = h0 + turn

    def rails(self, w):
        L = [(p[0] - w * math.sin(h), p[1] + w * math.cos(h)) for p, h in zip(self.points, self.headings)]
        R = [(p[0] + w * math.sin(h), p[1] - w * math.cos(h)) for p, h in zip(self.points, self.headings)]
        return L, R


SKY_APEX_Y = 1090.0
SKY_TURN_R = 40.0
RAIL_X = 46.0                    # the sky rail's run down the left wall (raised, over the cave lane)


def sky_path():
    p = RampPath((RAMP_C_X, RAMP_MOUTH_Y), math.pi / 2)
    p.line(SKY_APEX_Y - RAMP_MOUTH_Y)              # the plastic climb
    p.arc(SKY_TURN_R, math.radians(90))            # turn left at the top: the made switch (the "lookout")
    p.line(p.points[-1][0] - SKY_TURN_R - RAIL_X)  # the sky rail across the top, behind the cabin
    p.arc(SKY_TURN_R, math.radians(90))            # turn down the left wall
    p.line(p.points[-1][1] - 720)                  # down over the cave lane
    dx = INLANE_X - RAIL_X                         # S-bend into the left inlane
    r = 60.0
    turn = math.acos(1 - dx / (2 * r))
    p.arc(r, turn); p.arc(r, -turn)
    p.line(max(0.0, p.points[-1][1] - INLANE_RELEASE_L[1]))
    return p


SKY_PLASTIC_LEN = SKY_APEX_Y - RAMP_MOUTH_Y + SKY_TURN_R * math.pi / 4   # plastic to just past the turn's middle
SKY_RISE = 110.0

# ================================================================ CANOPY: three pops under the arch
BUMPER_R = 22.0
BUMPERS = [(250.0, 1208.0), (322.0, 1262.0), (382.0, 1196.0)]   # grid search: every gap 45-48 (arch, roof, each other)

# ================================================================ creature stages (mode-only; drawn dashed)
CREATURE_R = 13.0
LILY_PADS = [(180.0, 945.0), (156.0, 987.0), (186.0, 1023.0)]       # the frog hops pad to pad (search: each >= 45 clear of the basin)
CAVE_PATROL = [(46.0, 960.0), (46.0, 1110.0)]                       # the bat swoops up and down the tunnel
GROVE_PATROL = [(550.0, 960.0), (550.0, 1070.0)]                    # the squirrel dashes between the trees
CANOPY_FLIGHT = quad((110.0, 1262.0), (300.0, 1310.0), (470.0, 1240.0), 20)   # the owl glides across the top


def rail_flight():
    """The Kite Swift races along the sky rail (ramp layer): the top run of the wire."""
    p = sky_path()
    s0 = SKY_PLASTIC_LEN + 10
    s1 = s0 + 330
    return [pt for pt, s in zip(p.points, p.dist) if s0 <= s <= s1]


def patrol_pts(a, b, n=12):
    return [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1)]


# ================================================================ the floor parts
def outer_wall():
    pts = [(CHUTE_X, CHUTE_BOTTOM), APRON_END, SLOPE_TOP, (WALL_L, ARCH_START)]
    pts += arch()[1:]
    pts += [(SHOOT_OUT, SHOOT_FLOOR_Y), (SHOOT_IN, SHOOT_FLOOR_Y)]
    return pts


def right_wall():
    return ([(SHOOT_IN, SHOOT_IN_TOP), (SHOOT_IN, BULGE[1])] + list(reversed(bulge("R")))[1:] +
            [M(SLOPE_TOP), M(APRON_END), M((CHUTE_X, CHUTE_BOTTOM))])


def flipper_poly(pivot, side, raised=0.0):
    a = FLIP_REST - raised
    sx = 1 if side == "L" else -1
    dx, dy = sx * math.cos(a), -math.sin(a)
    tip = (pivot[0] + dx * FLIP_LEN, pivot[1] + dy * FLIP_LEN)
    nx, ny = -dy, dx
    return tip, [(pivot[0] + nx * FLIP_RP, pivot[1] + ny * FLIP_RP), (tip[0] + nx * FLIP_RT, tip[1] + ny * FLIP_RT),
                 (tip[0] - nx * FLIP_RT, tip[1] - ny * FLIP_RT), (pivot[0] - nx * FLIP_RP, pivot[1] - ny * FLIP_RP)]


def floor_parts(mode_parts=True):
    P = {}
    P["outer wall"] = ("poly", outer_wall())
    P["right wall"] = ("poly", right_wall())
    P["shooter lane wall"] = ("poly", [(SHOOT_IN, SHOOT_FLOOR_Y), (SHOOT_IN, 232.0)])
    for s, f in (("L", lambda p: p), ("R", M)):
        P[f"lane guide {s}"] = ("poly", [f(p) for p in lane_guide_path()])
        P[f"lane guide post {s}"] = ("circle", f((GUIDE_X, GUIDE_TOP_Y)), GUIDE_POST_R)
        P[f"outlane post {s}"] = ("circle", f(OUTLANE_POST_L), GUIDE_POST_R)
        P[f"outlane post rail {s}"] = ("poly", [f((GUIDE_X, GUIDE_TOP_Y)), f(OUTLANE_POST_L)])
        P[f"sling {s}"] = ("poly", [f(SLING_TOP_L), f(SLING_CORNER_L), f(SLING_TIP_L), f(SLING_TOP_L)])
        P[f"sling top post {s}"] = ("circle", f(SLING_TOP_L), SLING_POST_TOP)
        P[f"sling tip post {s}"] = ("circle", f(SLING_TIP_L), SLING_POST_TIP)
        P[f"flipper pivot {s}"] = ("circle", PIVOT_L if s == "L" else PIVOT_R, FLIP_RP)
    P["reed bed lower rim"] = ("poly", [REED_WALL_LO, REED_POST_LO])
    P["reed bed roof"] = ("poly", [REED_POST_HI, REED_ROOF_TOP])
    P["reed post lo"] = ("circle", REED_POST_LO, REED_POST_R)
    P["reed post hi"] = ("circle", REED_POST_HI, REED_POST_R)
    P["island"] = ("poly", island())
    P["cave post"] = ("circle", (CAVE_INNER_X, CAVE_BOTTOM_Y), CAVE_POST_R)
    P["lily post L"] = ("circle", (LILY_L_X, LILY_MOUTH_Y), LILY_POST_R)
    P["lily post R"] = ("circle", (LILY_R_X, LILY_MOUTH_Y), LILY_POST_R)
    P["cabin post L"] = ("circle", (CABIN_L_X, CABIN_MOUTH_Y), CABIN_POST_R)
    P["cabin post R"] = ("circle", (CABIN_R_X, CABIN_MOUTH_Y), CABIN_POST_R)
    P["ramp post L"] = ("circle", (RAMP_C_X - RAMP_MOUTH_HALF, RAMP_MOUTH_Y), RAMP_POST_R)
    P["ramp post R"] = ("circle", (RAMP_C_X + RAMP_MOUTH_HALF, RAMP_MOUTH_Y), RAMP_POST_R)
    P["grove post"] = ("circle", (GROVE_INNER_X, GROVE_BOTTOM_Y), GROVE_POST_R)
    P["launch gate"] = ("poly", list(LAUNCH_GATE))
    P["grove branch"] = ("poly", list(BRANCH))
    for i, b in enumerate(BUMPERS):
        P[f"bumper {i + 1}"] = ("circle", b, BUMPER_R)
    if mode_parts:
        for i, p in enumerate(LILY_PADS):
            P[f"frog on pad {i + 1} (mode)"] = ("circle", p, CREATURE_R)
        P["bat patrol (mode)"] = ("capsule", CAVE_PATROL, CREATURE_R)
        P["squirrel patrol (mode)"] = ("capsule", GROVE_PATROL, CREATURE_R)
    return P


# the shots, and where each is aimed (for the fan and the straight-line clearance)
SHOTS = {
    "Reed Bed scoop": REED_HOLE,
    "Cave orbit": ((WALL_L + CAVE_INNER_X) / 2, CAVE_BOTTOM_Y + 10),
    "Lily-pad lane": ((LILY_L_X + LILY_R_X) / 2, LILY_MOUTH_Y + 10),
    "Specimen scoop": (CX, CABIN_MOUTH_Y + 10),
    "Sky ramp": (RAMP_C_X, RAMP_MOUTH_Y + 10),
    "Grove lane": ((GROVE_INNER_X + WALL_R) / 2, GROVE_BOTTOM_Y + 10),
}
SHOT_FLIPPERS = {
    "Reed Bed scoop": ["right"], "Cave orbit": ["right"], "Lily-pad lane": ["left", "right"],
    "Specimen scoop": ["left", "right"], "Sky ramp": ["left", "right"], "Grove lane": ["left"],
}
HABITAT_OF = {"Reed Bed scoop": "pond", "Lily-pad lane": "pond", "Cave orbit": "cave", "Sky ramp": "sky",
              "Grove lane": "grove", "Specimen scoop": "cabin"}
