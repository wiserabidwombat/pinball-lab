"""Neon Labyrinth (Table 08) — the SWITCHYARD room: the ramp to the turntable, the light-rail ring and its three
light-rails to the exits, the SWITCH < / > and RAILS targets on their blocks. Built on the cell kit (nl_kit.py).
T8 M2 round A split this out of nl_layout.py with no geometry change."""
import math
from nl_kit import *

NAME = "switchyard"
EXITS = ("left", "top", "right")     # which exits this room has (a side exit comes with that side's entry portal)

# ---------------------------------------------------------------- ROOM: the Switchyard
HUB = (CX, 790.0)                   # the turntable (raised, height 40)
HUB_TRACK_R = 42.0                  # drawn turntable
HUB_BASE_R = 36.0                   # floor-solid base under it: also splits balls dropping in from the top port
RAIL_RING_R = (50.0, 64.0)          # the light-rail ring round the turntable (drawn)
RAMP_MOUTH_Y = 560.0
RAMP_MOUTH_HALF = 33.0              # 66 wide (2.2 balls, Medieval Madness 2.1-2.3)
RAMP_CHANNEL_HALF = 23.0            # 46 channel (1.5 balls)
RAMP_FLARE = 60.0
RAMP_U_LEN = 80.0                   # low end solid for floor balls
RAMP_TOP_Y = HUB[1] - HUB_TRACK_R   # 748: ramp meets the turntable
RAMP_POST_R = 5.0

# the three headings the turntable and the rail ring can point (degrees)
HEADINGS = {"W": 180.0, "N": 90.0, "E": 0.0}

def rail_path(key):
    """Centreline of each light-rail, from the rail ring to its exit portal (rail layer, height 40)."""
    if key == "N":
        return [(CX, HUB[1] + RAIL_RING_R[1]), (CX, 975.0), (CX, TOP_Y + 6)]
    y_exit = (SIDE_EXIT[0] + SIDE_EXIT[1]) / 2
    start = (CX - RAIL_RING_R[1], HUB[1])
    pts = [start, (150.0, HUB[1]), (70.0, y_exit - 8), (WALL_L - 6, y_exit)]
    return pts if key == "W" else [M(p) for p in pts]

RAIL_HALF = 21.0                    # light-rail channel 42 (1.4 balls, a wire habitrail)

def _standup(center, aim_at, width=40.0, depth=10.0):
    """A standup facing aim_at: returns (face_a, face_b, back_a, back_b, normal)."""
    n = unit(center, aim_at)
    t = (-n[1], n[0])
    a = add(center, t, width / 2)
    b = add(center, t, -width / 2)
    return a, b, add(a, n, -depth), add(b, n, -depth), n

SWEET_L = (243.0, 214.0)            # ~ where a cradled / mid-swing ball leaves the left flipper (Shot Lab will measure)
SWEET_R = M(SWEET_L)

# SWITCH targets flank the ramp mouth on the shot line; each faces the OPPOSITE flipper.
SWITCH_L_C = (214.0, 600.0)         # "<" turns the turntable anticlockwise (W <- N <- E)
SWITCH_R_C = M(SWITCH_L_C)          # ">" turns it clockwise
SWITCH_L = _standup(SWITCH_L_C, SWEET_R)
SWITCH_R = _standup(SWITCH_R_C, SWEET_L)

# RAILS target hugs the right wall above the right entry tube, facing the left flipper.
RAILS_C = (556.0, 752.0)
RAILS = _standup(RAILS_C, SWEET_L, width=38.0)

def ramp_outline():
    """Left and right rails of the ramp from the mouth to the turntable (drawn; the first RAMP_U_LEN are floor-solid)."""
    y0 = RAMP_MOUTH_Y
    left, right = [], []
    n = 20
    for i in range(n + 1):
        y = y0 + (RAMP_TOP_Y - y0) * i / n
        f = min(1.0, (y - y0) / RAMP_FLARE)
        half = RAMP_MOUTH_HALF + (RAMP_CHANNEL_HALF - RAMP_MOUTH_HALF) * (f * f * (3 - 2 * f))
        left.append((CX - half, y))
        right.append((CX + half, y))
    return left, right

def ramp_half_at(y):
    f = min(1.0, max(0.0, (y - RAMP_MOUTH_Y) / RAMP_FLARE))
    return RAMP_MOUTH_HALF + (RAMP_CHANNEL_HALF - RAMP_MOUTH_HALF) * (f * f * (3 - 2 * f))

RAMP_U_TOP = RAMP_MOUTH_Y + RAMP_U_LEN     # 640

def switch_block(side):
    """The SWITCH target's closed block: mouth post -> face -> back -> onto the ramp's U wall (all floor-solid)."""
    fa, fb, ba, bb, nrm = SWITCH_L if side == "L" else SWITCH_R
    # order the face so the point nearer the ramp comes first
    near, far = (fa, fb) if abs(fa[0] - CX) < abs(fb[0] - CX) else (fb, fa)
    sx = -1 if side == "L" else 1
    post = (CX + sx * RAMP_MOUTH_HALF, RAMP_MOUTH_Y)
    u_join = (CX + sx * ramp_half_at(RAMP_U_TOP - 10), RAMP_U_TOP - 10)
    back_far = add(far, nrm, -12)
    u_corner = (CX + sx * ramp_half_at(RAMP_U_TOP), RAMP_U_TOP)   # one cap sloping down-out from the U's top corner
    return [post, near, far, back_far, u_corner, post]


def room_parts():
    """name -> part: the Switchyard's own floor-solid parts (added to the kit's)."""
    P = {}
    for s in ("L", "R"):
        P[f"switch block {s}"] = ("poly", switch_block(s))
        P[f"ramp mouth post {s}"] = ("circle", (CX + (-1 if s == "L" else 1) * RAMP_MOUTH_HALF, RAMP_MOUTH_Y), RAMP_POST_R)
    left, right = ramp_outline()
    u_top = RAMP_U_TOP
    # the U's back is a gable (peak 16 up) so a floor ball falling from behind can't rest on it
    P["ramp U (floor-solid)"] = ("poly", [p for p in left if p[1] < u_top] + [(CX - ramp_half_at(u_top), u_top),
                                         (CX, u_top + 16), (CX + ramp_half_at(u_top), u_top)]
                                 + list(reversed([p for p in right if p[1] < u_top])))
    P["hub base"] = ("circle", HUB, HUB_BASE_R)
    fa, fb, ba, bb, _ = RAILS
    wall_a = (WALL_R, fa[1] + 6) if fa[1] > fb[1] else (WALL_R, fb[1] + 6)
    hi, lo = (fa, fb) if fa[1] > fb[1] else (fb, fa)
    P["RAILS block"] = ("poly", [(WALL_R, lo[1] - 4), lo, hi, (WALL_R, hi[1] + 18)])
    return P

# The room's shots for the checks' shot fan: name -> where the shot aims.
SHOTS = {"SWITCH <": SWITCH_L_C, "ramp": (CX, RAMP_MOUTH_Y + 8), "SWITCH >": SWITCH_R_C, "RAILS": RAILS_C}
