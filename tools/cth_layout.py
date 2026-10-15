"""Table 03 (Cthulhu Rising) geometry for the art tools: a Python mirror of CthTableLayout.swift.
World points, origin bottom-left, y up. Keep the numbers in step with the Swift file."""
import math

W, H = 600, 1300
LEFT_X, RIGHT_X, LANE_X = 20, 580, 548
LANE_FLOOR_Y = 40
ARCH_Y, TOP_Y = 1000, 1270
APRON_TOP_Y = 185
DRAIN_X, DRAIN_Y, DRAIN_LIP_Y = 250, 105, 85
BULGE_B, BULGE_T, BULGE_INSET = 540, 780, 36
LANE_WALL_TOP = 955
MIRROR = LEFT_X + LANE_X            # 568
BALL_R = 9

L_PIVOT, R_PIVOT = (179, 220), (389, 220)
FLIP_LEN, FLIP_R0, FLIP_R1 = 96, 12, 6
REST = math.pi / 6

LANE_GUIDE_X, LANE_GUIDE_TOP, LANE_GUIDE_BEND = 54, 470, 330
OUTLANE_WALL_BOTTOM = 215
SLING_L = dict(top=(88, 450), corner=(88, 347), tip=(150, 300.4))
SLING_TOP_POST_R, SLING_TIP_POST_R = 7, 6
SLING_KICK_FROM, SLING_KICK_TO = 0.06, 0.94

PLUNGER_SIZE = (24, 50)
PLUNGER_REST_TOP = 120
LANE_CENTER_X = (LANE_X + RIGHT_X) / 2
GATE_LOW, GATE_HIGH = (LANE_X, LANE_WALL_TOP), (RIGHT_X, LANE_WALL_TOP + 28)


def mirrored(p):
    return (MIRROR - p[0], p[1])


def guide_end_left():
    r = FLIP_R0 + 1
    return (L_PIVOT[0] + r * math.sin(REST), L_PIVOT[1] + r * math.cos(REST))


def left_lane_guide():
    return [(LANE_GUIDE_X, LANE_GUIDE_TOP), (LANE_GUIDE_X, LANE_GUIDE_BEND), guide_end_left()]


def right_lane_guide():
    return [mirrored(p) for p in left_lane_guide()]


def sling_right():
    return {k: mirrored(v) for k, v in SLING_L.items()}


def quad(p0, c, p1, n=16):
    out = []
    for i in range(1, n + 1):
        t = i / n; u = 1 - t
        out.append((u*u*p0[0] + 2*u*t*c[0] + t*t*p1[0], u*u*p0[1] + 2*u*t*c[1] + t*t*p1[1]))
    return out


def outer_wall():
    pts = [(DRAIN_X, DRAIN_LIP_Y), (DRAIN_X, DRAIN_Y), (LEFT_X, APRON_TOP_Y), (LEFT_X, BULGE_B)]
    pts += quad((LEFT_X, BULGE_B), (LEFT_X + BULGE_INSET, (BULGE_B + BULGE_T) / 2), (LEFT_X, BULGE_T))
    pts.append((LEFT_X, ARCH_Y))
    mid = W / 2
    pts += quad((LEFT_X, ARCH_Y), (LEFT_X, TOP_Y), (mid, TOP_Y))
    pts += quad((mid, TOP_Y), (RIGHT_X, TOP_Y), (RIGHT_X, ARCH_Y))
    pts += [(RIGHT_X, LANE_FLOOR_Y), (LANE_X, LANE_FLOOR_Y), (LANE_X, BULGE_B)]
    pts += quad((LANE_X, BULGE_B), (LANE_X - BULGE_INSET, (BULGE_B + BULGE_T) / 2), (LANE_X, BULGE_T))
    pts.append((LANE_X, LANE_WALL_TOP))
    return pts


def right_apron():
    return [(LANE_X, APRON_TOP_Y), (MIRROR - DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, DRAIN_LIP_Y)]


def outlane_walls():
    left = [(LANE_GUIDE_X, LANE_GUIDE_BEND), (LANE_GUIDE_X, OUTLANE_WALL_BOTTOM)]
    return left, [mirrored(p) for p in left]


# The oblique view every Table 03 part is drawn in: a raised point at height z appears this much
# farther UP the table (y + z * OBLIQUE). 22 degrees, as in the plan's test render. The floor (z 0)
# lines up exactly with the physics.
OBLIQUE = math.tan(math.radians(22))

# Lower-table art (milestone 2): the world rectangle the baked image covers, and its resolution.
LOWER_RECT = (-40, -75, 680, 600)     # x, y, w, h  (y -75 … 525)
PX_PER_PT = 3


# ---------------------------------------------------------------- the top of the table (milestones 3–6)
# Mirrors CthTableLayout.swift "Top of the table" and "Lamps"; keep in step.
ORBIT_X, FUNNEL_TIP, FUNNEL_BEND, ORBIT_END_X = 58, (112, 800), 890, 190


def orbit_inner():
    inner_top = TOP_Y - (ORBIT_X - LEFT_X)
    arc = quad((ORBIT_X, ARCH_Y), (ORBIT_X, inner_top), (W / 2, inner_top), 32)
    return [FUNNEL_TIP, (ORBIT_X, FUNNEL_BEND), (ORBIT_X, ARCH_Y)] + [p for p in arc if p[0] <= ORBIT_END_X]


LANE_POSTS = [220, 256, 292, 328]; LANE_BOTTOM, LANE_TOP = 1130, 1185
LANE_CENTERS = [238, 274, 310]
BUMPERS = [(210, 1050), (338, 1050), (274, 950)]; BUMPER_R = 28
TARGET_X, TARGET_YS = 464, [595, 565, 535, 505]
BANK_BACK = [(476, 487), (476, 621)]; BANK_CAP = [(476, 621), (454, 613)]
UPPER_PIVOT = (528, 800)
UPPER_GUIDE = [(548, 824), (530.9, 814.4)]
SPINNER_Y = 935
LIBRARY = (284, 650)
LAGOON = (452, 1030)
SCOOP_R = 15
RITUAL = (284, 470); RITUAL_R = 40

# lamps (CthTableLayout "Lamps"): (x, y, angle degrees) arrows 24 x 18
SHOT_ARROWS = {"rightRamp": (336.3, 532, 70.8), "orbit": (121.4, 722.7, 113.8), "library": (284, 582, 90),
               "sigil": (411.1, 493.2, 54.3), "lagoon": (467, 962, 102.6)}
TOME_LAMPS = [(260, 615), (284, 615), (308, 615)]; TOME_R = 6
CANDLE_LAMPS = [(RITUAL[0] + 54 * math.cos(math.pi / 2 - i * 2 * math.pi / 5),
                 RITUAL[1] + 54 * math.sin(math.pi / 2 - i * 2 * math.pi / 5)) for i in range(5)]
CANDLE_R = 7
EYE_LAMPS = [(430, 1070), (452, 1076), (474, 1070)]; EYE_R = 5
TENTACLE_LAMPS = [(414, 996), (438, 989), (466, 989), (490, 996)]; TENTACLE_R = 5

# The whole-table art (milestone 8): one painting + one Blender render, cut into the lower image
# (LOWER_RECT, unchanged) and the upper image (UPPER_RECT) above it.
FULL_RECT = (-40, -75, 680, 1405)      # y -75 … 1330
UPPER_RECT = (-40, 525, 680, 805)      # y 525 … 1330

# T3 M8 v2: the top-right lane (curved wall 38 pt inside the arch) and its one-way gate (replaces the diverter).
TOP_LANE_W, TOP_GATE_T, TOP_LANE_T = 38, 0.187, 0.217


def arch_right(t):
    p0, c, p1 = (W / 2, TOP_Y), (RIGHT_X, TOP_Y), (RIGHT_X, ARCH_Y); u = 1 - t
    return (u*u*p0[0] + 2*u*t*c[0] + t*t*p1[0], u*u*p0[1] + 2*u*t*c[1] + t*t*p1[1])


def arch_right_inner(t, inset):
    p0, c, p1 = (W / 2, TOP_Y), (RIGHT_X, TOP_Y), (RIGHT_X, ARCH_Y); u = 1 - t
    dx = 2*u*(c[0]-p0[0]) + 2*t*(p1[0]-c[0]); dy = 2*u*(c[1]-p0[1]) + 2*t*(p1[1]-c[1]); l = math.hypot(dx, dy)
    x, y = arch_right(t); return (x + dy / l * inset, y - dx / l * inset)


TOP_GATE_HINGE = arch_right(TOP_GATE_T)
TOP_GATE_END = arch_right_inner(TOP_LANE_T, TOP_LANE_W)
TOP_LANE_WALL = [arch_right_inner(TOP_LANE_T + (1 - TOP_LANE_T) * k / 24, TOP_LANE_W) for k in range(25)]


# ---------------------------------------------------------------- T3 M8 art round 3: the ramps (CthTableLayout "Right ramp")
# Ports of CthRampPath and the two paths, and the height profile both the render and the game's ball use:
# rises from the floor over RAMP_RISE (a quarter sine) to RAMP_TOP_H, holds to the apex, then falls in a
# straight line to the end height.
RAMP_MOUTH, RAMP_HALF_MOUTH, RAMP_HALF, RAMP_FLARE, RAMP_LOW = (360, 600), 30, 16, 70, 80
RAMP_TOP_H, RAMP_RISE, RAMP_END_H, WIRE_END_H = 40, 110, 12, 10
LEFT_INLANE_X, WIRE_RELEASE_Y = 69, 490


class RampPath:
    def __init__(self, start, heading):
        self.pts, self.hd, self.ds, self.h = [start], [heading], [0.0], heading

    @property
    def length(self): return self.ds[-1]

    def line(self, length, step=10):
        n = max(1, math.ceil(length / step)); sx, sy = self.pts[-1]; s0 = self.length
        for i in range(1, n + 1):
            d = length * i / n
            self.pts.append((sx + d * math.cos(self.h), sy + d * math.sin(self.h))); self.hd.append(self.h); self.ds.append(s0 + d)

    def arc(self, radius, turn, step=8):
        n = max(2, math.ceil(abs(turn) * radius / step)); sign = 1 if turn > 0 else -1
        sx, sy = self.pts[-1]; cx, cy = sx - sign * radius * math.sin(self.h), sy + sign * radius * math.cos(self.h)
        a0 = math.atan2(sy - cy, sx - cx); s0 = self.length; h0 = self.h
        for i in range(1, n + 1):
            f = i / n; a = a0 + turn * f
            self.pts.append((cx + radius * math.cos(a), cy + radius * math.sin(a))); self.hd.append(h0 + turn * f)
            self.ds.append(s0 + abs(turn) * radius * f)
        self.h = h0 + turn

    def sample(self, s):
        for i in range(1, len(self.pts)):
            if self.ds[i] >= s:
                t = (s - self.ds[i - 1]) / max(self.ds[i] - self.ds[i - 1], 0.001)
                a, b = self.pts[i - 1], self.pts[i]
                return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), self.hd[i]
        return self.pts[-1], self.hd[-1]


def right_ramp_path():
    climb = math.atan2(260, 90)
    p = RampPath(RAMP_MOUTH, climb); p.line(math.hypot(90, 260)); p.arc(36, -(climb + math.pi / 2))
    apex = p.length
    p.line(248); bend = math.acos(1 - 23 / 120); p.arc(60, -bend); p.arc(60, bend); p.line(40)
    return p, apex


def library_wire_path():
    climb = math.atan2(260, 90)
    p = RampPath(LIBRARY, math.pi - climb); p.line(math.hypot(90, 260)); p.arc(36, climb + math.pi / 2)
    apex = p.length
    p.line(200)
    shift = LEFT_INLANE_X - p.pts[-1][0]
    if abs(shift) > 0.5:
        bend = math.acos(1 - min(abs(shift), 119) / 120); turn = bend if shift > 0 else -bend
        p.arc(60, turn); p.arc(60, -turn)
    p.line(max(p.pts[-1][1] - WIRE_RELEASE_Y, 20))
    return p, apex


def ramp_height(s, apex, length, end_h):
    """Height of the ramp's running surface (where the ball's bottom rides) at distance s."""
    if s <= apex:
        return RAMP_TOP_H * math.sin(min(max(s, 0) / RAMP_RISE, 1) * math.pi / 2)
    return RAMP_TOP_H + (end_h - RAMP_TOP_H) * min((s - apex) / max(length - apex, 1), 1)


def ramp_half_width(s):
    return RAMP_HALF_MOUTH + (RAMP_HALF - RAMP_HALF_MOUTH) * min(s / RAMP_FLARE, 1)
