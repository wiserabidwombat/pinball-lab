"""Neon Labyrinth (Table 08) — the shared CELL KIT: one single-screen mini-table's walls, flippers, lanes, outlanes and
saves geometry, slings, return wires, the drain, the exit portals and the ways in. Every room is built from this kit plus
its own parts (nl_room_<name>.py). T8 M2 round A split this out of nl_layout.py with no geometry change.
World points, origin bottom-left.

Scale: real ball scale, as proven on CHOMP! (Table 07): ball r 15, flippers 80 (pivot r 12, tip r 6), 35 rad/s.
Gap rules at this scale (CHOMP!'s): closed < 30 (1 ball), passages >= 45 (1.5 balls), 30-45 = wedge risk.
"""
import math

# ---------------------------------------------------------------- scale + cell
BALL_R = 15.0
D = 2 * BALL_R
CLOSED_MAX = 30.0          # a gap the ball must never enter
PASSAGE_MIN = 45.0         # a gap the ball must use

CELL_W, CELL_H = 600, 1060  # one screen: fits 440 x ~800 pt usable at scale 1.36 (ball 22 pt on the phone)
CX = 300.0                  # the cell is symmetric about x 300 (no plunger lane: every cell is served from below)
WALL_L, WALL_R = 20.0, 580.0
ARCH_START, TOP_Y = 860.0, 1040.0

def M(p):
    """Mirror a point about the cell centre."""
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

# ---------------------------------------------------------------- KIT: flippers
FLIP_LEN, FLIP_RP, FLIP_RT = 80.0, 12.0, 6.0
FLIP_REST = math.radians(30)        # below horizontal
FLIP_TRAVEL = math.radians(51)      # CHOMP!'s stroke (VPX default): rest 30 below, stop 21 above
PIVOT_L = (201.0, 200.0)
PIVOT_R = M(PIVOT_L)

def flipper_tip(pivot, side, raised=0.0):
    a = FLIP_REST - raised
    sx = 1 if side == "L" else -1
    return (pivot[0] + sx * FLIP_LEN * math.cos(a), pivot[1] - FLIP_LEN * math.sin(a))

TIP_L_REST = flipper_tip(PIVOT_L, "L")
TIP_R_REST = flipper_tip(PIVOT_R, "R")

# ---------------------------------------------------------------- KIT: lanes (outlane | lane guide | inlane | sling)
OUTLANE_W = 50.0                    # ball-clear widths (CHOMP!: inlanes 50, outlanes 54)
INLANE_W = 50.0
GUIDE_POST_R = 5.0
GUIDE_X = WALL_L + OUTLANE_W + GUIDE_POST_R        # 75: the lane guide's straight part
GUIDE_TOP_Y = 470.0
# The guide ends just above the top edge of the pivot at rest: pivot + (r + 1) along the top edge's normal.
GUIDE_END_L = (PIVOT_L[0] + (FLIP_RP + 1) * math.sin(FLIP_REST), PIVOT_L[1] + (FLIP_RP + 1) * math.cos(FLIP_REST))
SLANT = math.radians(32)            # the guide's slant down to the pivot
GUIDE_BEND_L = (GUIDE_X, GUIDE_END_L[1] + (GUIDE_END_L[0] - GUIDE_X) * math.tan(SLANT))
# Adjustable-style outlane post (Monsoon): a rail from the guide post up and out to a second post 10 pt farther out,
# so balls falling on the guide post's outer side get turned back in rather than down the outlane.
OUTLANE_POST_L = (GUIDE_X - 3.0, GUIDE_TOP_Y + 12.0)
# The inlane side of the bend is a curve (r GUIDE_BEND_R), so a ball coming down the inlane at speed follows it onto
# the slant instead of glancing off a corner and across the flipper (a sharp corner sent 450-800 pt/s balls into the gap).
GUIDE_BEND_R = 120.0
def lane_guide_curve():
    u = unit(GUIDE_BEND_L, GUIDE_END_L)
    n = (-u[1], u[0])
    cx = GUIDE_X + GUIDE_BEND_R
    # centre at distance R from the slant line, on its playfield side
    cy = GUIDE_END_L[1] + (GUIDE_BEND_R - (cx - GUIDE_END_L[0]) * n[0]) / n[1]
    a0, a1 = math.pi, math.atan2(-n[1], -n[0]) + 2 * math.pi
    pts = [(cx + GUIDE_BEND_R * math.cos(a0 + (a1 - a0) * i / 12), cy + GUIDE_BEND_R * math.sin(a0 + (a1 - a0) * i / 12)) for i in range(13)]
    return pts
# The outlane stays a channel past the bend: a wall carried straight down, stopping >= 1.5 balls above the slope.
OUTLANE_WALL_BOTTOM = 256.0
# Below the outlane the outer wall slopes under the flipper to the centre drain chute (Grey Invasion's pattern).
SLOPE_TOP = (WALL_L, 230.0)
# Side walls bulge inward above the outlanes so wall-sliders come back into play.
# T8 M1 v3 (Play Lab run 19-53-08Z: 34 of 48 drains down the outlanes): the round-2 bulge (480-760, a quad peaking 18 in
# at y 620) handed balls back to the wall on its lower half, right into the outlane's mouth. The knee now sits low and
# deep, just above the mouth: in from y 760 to 44 pt at y 539.5, then back to the wall at y 515 (nl_outlane_sim.py /
# nl_outlane_search.py: side-crossers into the outlane 113/200 -> 8/80, wall-sliders 24/200 -> 0/80; mouth 48.2).
BULGE = (515.0, 760.0, 44.0, 0.1)   # from y, to y, depth, where the peak sits (fraction of the way up)
def bulge(side="L", n=24):
    y0, y1, inset, pf = BULGE
    yp = y0 + pf * (y1 - y0)
    pts = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        t = (y - y0) / (yp - y0) if y <= yp else (y1 - y) / (y1 - yp)
        pts.append((WALL_L + inset * math.sin(t * math.pi / 2) ** 1.5, y))
    # make sure the peak itself is a vertex
    pts.append((WALL_L + inset, yp))
    pts.sort(key=lambda p: p[1])
    return pts if side == "L" else [M(p) for p in pts]

# ---------------------------------------------------------------- KIT: slingshots
SLING_POST_TOP, SLING_POST_TIP, SLING_POST_CORNER = 7.0, 6.0, 5.5
SLING_X = GUIDE_X + INLANE_W + SLING_POST_TOP      # 132: the sling's vertical side
_u = unit(GUIDE_BEND_L, GUIDE_END_L)               # down the slant
_n = (-_u[1], _u[0])                               # into the playfield (up-right)
_off = INLANE_W + SLING_POST_CORNER + 0.5
_o0 = add(GUIDE_BEND_L, _n, _off)
_t = (SLING_X - _o0[0]) / _u[0]
SLING_CORNER_L = (SLING_X, _o0[1] + _u[1] * _t)
SLING_TIP_L = add(SLING_CORNER_L, _u, 64.0)        # short of the swinging flipper
# The lane guide's bend is a r 120 curve (below), which bulges into the inlane: lift the corner so it keeps 50 clear.
SLING_CORNER_L = (SLING_X, 352.0)
SLING_TOP_L = (SLING_X, 445.0)

# ---------------------------------------------------------------- KIT: return wires (every arrival ends in an inlane)
# One light-rail per side, ridden as a scripted ride (the Lamplight's), released heading down inside the inlane:
#  - a ball dropping in through the top port (the upper cell drained) lands on the top of a return wire (sides alternate)
#    and rides it round under the arch and down the side wall;
#  - a ball arriving through a side entry portal joins its side's wire on a short stub.
# The outlane's mouth along the wall stays open to the playfield (the wire passes over it).
ENTRY_PORTAL = (594.0, 654.0)       # y range of the portal on the side wall, 60 = 2 balls
INLANE_X = (GUIDE_X + SLING_X) / 2  # 103.5
ENTRY_RELEASE_L = (INLANE_X, 470.0)
WIRE_RELEASE_SPEED = 450.0          # heading straight down; the inlane governor caps it at 800 anyway
WIRE_X = 58.0                       # the return wire's run down the side wall
def _bulge_x(y):
    pts = bulge("L")
    for a, b in zip(pts, pts[1:]):
        if a[1] <= y <= b[1]:
            t = (y - a[1]) / max(b[1] - a[1], 1e-6)
            return a[0] + (b[0] - a[0]) * t
    return WALL_L
def return_wire(side):
    pts = quad((CX, 1002.0), (WIRE_X, 1002.0), (WIRE_X, 860.0), 16)
    pts += [(WIRE_X, 720.0)]
    # S-bend over to the inlane's centre line, then straight down into it
    for i in range(1, 13):
        t = i / 12
        e = t * t * (3 - 2 * t)
        pts.append((WIRE_X + (INLANE_X - WIRE_X) * e, 720.0 - 150.0 * t))
    pts.append(ENTRY_RELEASE_L)
    return pts if side == "L" else [M(p) for p in pts]
def entry_stub(side):
    """From the entry portal to where it joins the return wire."""
    y = (ENTRY_PORTAL[0] + ENTRY_PORTAL[1]) / 2
    wire = return_wire("L")
    join = min(wire, key=lambda p: abs(p[1] - y))
    pts = [(_bulge_x(y) - 6, y), (join[0] - 18, y), join]
    return pts if side == "L" else [M(p) for p in pts]

# ---------------------------------------------------------------- KIT: drain (drops the ball to the cell below)
CHUTE_X = 255.0                     # chute lips at x 255 / 345 (90 wide)
APRON_END = (CHUTE_X, 100.0)
CHUTE_BOTTOM = 30.0
DRAIN_LINE_Y = 40.0                 # crossing it = drop to the cell below (bottom row: ball lost)

# ---------------------------------------------------------------- KIT: exit portals (rail layer in the Switchyard)
SIDE_EXIT = (800.0, 870.0)          # y range on each side wall
TOP_PORT = (270.0, 330.0)           # x range at the top of the arch
TOP_LANE_BOTTOM = 975.0             # the top lane's walls hang from the arch down to here
TOP_LANE_POST_R = 5.0

# ---------------------------------------------------------------- KIT: vertical arrivals
# From BELOW (the lower cell's top exit): the ball rises up through this cell's drain chute and the flipper gap
# (a scripted rise with collisions off), released at UP_RELEASE with a gentle pop that peaks in the open lower table
# and drops onto a flipper (sides alternate).
UP_RELEASE = (CX, 265.0)
UP_POP = {"L": (-38.0, 450.0), "R": (38.0, 450.0)}   # release velocity (pt/s) at gravity 900: peaks ~y 380, lands on the flipper
# From ABOVE (the upper cell's drain): the ball falls in through the top port onto the top of a return wire.

# ---------------------------------------------------------------- the floor walls of a cell (polylines)
def outer_wall():
    """The bottom slope, left wall, arch, right wall and right slope (floor-solid)."""
    pts = [(CHUTE_X, CHUTE_BOTTOM), APRON_END, SLOPE_TOP] + bulge("L") + [(WALL_L, ARCH_START)]
    pts += quad((WALL_L, ARCH_START), (WALL_L, TOP_Y), (CX, TOP_Y), 32)[1:]
    pts += quad((CX, TOP_Y), (WALL_R, TOP_Y), (WALL_R, ARCH_START), 32)[1:]
    pts += list(reversed(bulge("R"))) + [M(SLOPE_TOP), M(APRON_END), M((CHUTE_X, CHUTE_BOTTOM))]
    return pts

def arch_y(x):
    """y of the arch's inner line at x (for the top lane walls)."""
    best = None
    for a, b in zip(outer_wall(), outer_wall()[1:]):
        if a[1] < ARCH_START or b[1] < ARCH_START:
            continue
        if min(a[0], b[0]) <= x <= max(a[0], b[0]) and a[0] != b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            y = a[1] + (b[1] - a[1]) * t
            best = y if best is None else max(best, y)
    return best


ALL_EXITS = ("left", "top", "right")

def kit_parts(exits=ALL_EXITS):
    """name -> ("poly", points) | ("circle", centre, r): the kit's floor-solid parts. The kit's floor is the same
    whichever exits a room has (closed side portals are just wall); `exits` is here for the parts that depend on them."""
    P = {}
    P["outer wall"] = ("poly", outer_wall())
    for s, f in (("L", lambda p: p), ("R", M)):
        P[f"lane guide {s}"] = ("poly", [f((GUIDE_X, GUIDE_TOP_Y))] + [f(p) for p in lane_guide_curve()] + [f(GUIDE_END_L)])
        P[f"lane guide post {s}"] = ("circle", f((GUIDE_X, GUIDE_TOP_Y)), GUIDE_POST_R)
        P[f"outlane post {s}"] = ("circle", f(OUTLANE_POST_L), GUIDE_POST_R)
        P[f"outlane post rail {s}"] = ("poly", [f((GUIDE_X, GUIDE_TOP_Y)), f(OUTLANE_POST_L)])
        P[f"outlane wall {s}"] = ("poly", [f(lane_guide_curve()[0]), f((GUIDE_X, OUTLANE_WALL_BOTTOM))])
        P[f"sling {s}"] = ("poly", [f(SLING_TOP_L), f(SLING_CORNER_L), f(SLING_TIP_L), f(SLING_TOP_L)])
        P[f"sling top post {s}"] = ("circle", f(SLING_TOP_L), SLING_POST_TOP)
        P[f"sling tip post {s}"] = ("circle", f(SLING_TIP_L), SLING_POST_TIP)
        P[f"flipper pivot {s}"] = ("circle", f(PIVOT_L) if s == "L" else PIVOT_R, FLIP_RP)
        x = TOP_PORT[0] if s == "L" else TOP_PORT[1]
        P[f"top lane wall {s}"] = ("poly", [(x, TOP_LANE_BOTTOM), (x, arch_y(x) + 1)])
        P[f"top lane post {s}"] = ("circle", (x, TOP_LANE_BOTTOM), TOP_LANE_POST_R)
    return P

def flipper_poly(pivot, side, raised=0.0):
    a = FLIP_REST - raised
    sx = 1 if side == "L" else -1
    dx, dy = sx * math.cos(a), -math.sin(a)
    tip = (pivot[0] + dx * FLIP_LEN, pivot[1] + dy * FLIP_LEN)
    nx, ny = -dy, dx
    return tip, [(pivot[0] + nx * FLIP_RP, pivot[1] + ny * FLIP_RP), (tip[0] + nx * FLIP_RT, tip[1] + ny * FLIP_RT),
                 (tip[0] - nx * FLIP_RT, tip[1] - ny * FLIP_RT), (pivot[0] - nx * FLIP_RP, pivot[1] - ny * FLIP_RP)]

