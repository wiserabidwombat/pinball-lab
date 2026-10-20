"""Table 05 (The Lamplight) geometry for the art scripts, copied from LmpTableLayout.swift (world points, y up).
Keep in step with the Swift file: every number here has the same name there (snake_case).
M9 round 1: the lower table (apron to the slings)."""
import math

OBLIQUE = 0.4040                 # oblique view: a point at height z is drawn z * OBLIQUE farther up
PX_PER_PT = 3                    # the baked table
WORLD_W, WORLD_H = 600, 1300
ART_RECT = (-40, -75, 680, 1405)     # x0, y0, w, h: Tables 02-05's art rect
LOWER_RECT = (-40, -75, 680, 675)    # M9 round 1 look development: up to y 600

LEFT_X, RIGHT_X, LANE_X = 20, 580, 548
LANE_FLOOR_Y = 40
ARCH_START_Y, TOP_Y = 1000, 1270
APRON_TOP_Y = 185
DRAIN_X, DRAIN_Y, DRAIN_LIP_Y = 250, 105, 85
RIGHT_BULGE_BOTTOM, RIGHT_BULGE_TOP, RIGHT_BULGE_INSET = 540, 780, 36
LANE_WALL_TOP = 955
MIRROR = LEFT_X + LANE_X         # 568
CENTER_X = MIRROR / 2            # 284

LEFT_PIVOT, RIGHT_PIVOT = (168, 220), (400, 220)
FLIPPER_LEN, PIVOT_R, TIP_R = 96, 12, 6
REST = math.pi / 6
CENTER_POST, CENTER_POST_R = (284, 168), 8

LANE_GUIDE_X, LANE_GUIDE_TOP, LANE_GUIDE_BEND = 54, 470, 330
LEFT_DEFLECTOR_TOP = (LEFT_X, 520)
OUTLANE_WALL_BOTTOM = 215
SLING_L = dict(top=(88, 450), corner=(88, 347), tip=(150, 296.2))
SLING_TOP_POST_R, SLING_TIP_POST_R, SLING_CORNER_POST_R = 7, 6, 5.5

PLUNGER_W, PLUNGER_H, PLUNGER_REST_TOP = 24, 50, 120
CAT_FLAP_LAMP = (531, 300)
LUCKY_LAMP = (284, 330)
SHOP_LAMPS = [(62, 192), (112, 174), (162, 157), (506, 192), (456, 174), (406, 157)]
COZY_LAMPS = [(70, 148), (118, 131), (166, 114)]
COZY_LAMP_R = 10


def mirrored(p):
    return (MIRROR - p[0], p[1])


def left_guide_end():
    r = PIVOT_R + 1
    return (LEFT_PIVOT[0] + r * math.sin(REST), LEFT_PIVOT[1] + r * math.cos(REST))


def left_inlane_wall():
    return [LEFT_DEFLECTOR_TOP, (LANE_GUIDE_X, LANE_GUIDE_TOP), (LANE_GUIDE_X, LANE_GUIDE_BEND), left_guide_end()]


def left_closed_pocket():
    ge = left_guide_end()
    return [(LEFT_X, APRON_TOP_Y), LEFT_DEFLECTOR_TOP, (LANE_GUIDE_X, LANE_GUIDE_TOP), (LANE_GUIDE_X, LANE_GUIDE_BEND),
            ge, (ge[0], APRON_TOP_Y - (ge[0] - LEFT_X) / (DRAIN_X - LEFT_X) * (APRON_TOP_Y - DRAIN_Y))]


def right_lane_guide():
    return [mirrored(p) for p in [(LANE_GUIDE_X, LANE_GUIDE_TOP), (LANE_GUIDE_X, LANE_GUIDE_BEND), left_guide_end()]]


def right_outlane_wall():
    return [mirrored((LANE_GUIDE_X, LANE_GUIDE_BEND)), mirrored((LANE_GUIDE_X, OUTLANE_WALL_BOTTOM))]


def right_apron():
    return [(LANE_X, APRON_TOP_Y), (MIRROR - DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, DRAIN_LIP_Y)]


def sling_right():
    return {k: mirrored(v) for k, v in SLING_L.items()}


def quad(p0, c, p1, n=16):
    out = []
    for i in range(1, n + 1):
        t = i / n; u = 1 - t
        out.append((u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0], u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1]))
    return out


def outer_wall():
    pts = [(DRAIN_X, DRAIN_LIP_Y), (DRAIN_X, DRAIN_Y), (LEFT_X, APRON_TOP_Y), (LEFT_X, ARCH_START_Y)]
    mid = WORLD_W / 2
    pts += quad((LEFT_X, ARCH_START_Y), (LEFT_X, TOP_Y), (mid, TOP_Y))
    pts += quad((mid, TOP_Y), (RIGHT_X, TOP_Y), (RIGHT_X, ARCH_START_Y))
    pts += [(RIGHT_X, LANE_FLOOR_Y), (LANE_X, LANE_FLOOR_Y), (LANE_X, RIGHT_BULGE_BOTTOM)]
    pts += quad((LANE_X, RIGHT_BULGE_BOTTOM), (LANE_X - RIGHT_BULGE_INSET, (RIGHT_BULGE_BOTTOM + RIGHT_BULGE_TOP) / 2),
                (LANE_X, RIGHT_BULGE_TOP))
    pts.append((LANE_X, LANE_WALL_TOP))
    return pts


def lane_wall():
    """The shooter-lane wall (x 548) with its bulge, from the lane floor to the gate."""
    return [(LANE_X, LANE_FLOOR_Y), (LANE_X, RIGHT_BULGE_BOTTOM)] + \
        quad((LANE_X, RIGHT_BULGE_BOTTOM), (LANE_X - RIGHT_BULGE_INSET, (RIGHT_BULGE_BOTTOM + RIGHT_BULGE_TOP) / 2),
             (LANE_X, RIGHT_BULGE_TOP)) + [(LANE_X, LANE_WALL_TOP)]


def playfield_polygon():
    """The floor inside the outer wall (the plunger lane included), as one closed polygon."""
    return outer_wall()[:-1]


# ---------------------------------------------------------------- M9 round 2: the upper table
UPPER_SPLIT_Y = 525                         # the baked table is cut here into two images (Table 03's split)
LOWER_ART_RECT = (-40, -75, 680, 600)
UPPER_ART_RECT = (-40, 525, 680, 805)

LEFT_ORBIT_INNER_X, LEFT_ORBIT_MOUTH_Y = 62, 900
RIGHT_ORBIT_INNER_X, RIGHT_ORBIT_MOUTH_Y = 506, 762
ORBIT_TOP_INNER_Y = 1228
RIGHT_DEFLECTOR = ((480, 700), (543, 770))

ALCOVE_LEFT_X, ALCOVE_RIGHT_X, ALCOVE_BOTTOM_Y, ALCOVE_TOP_Y, ALCOVE_ROOF_PEAK = 224, 344, 735, 850, 22
BOOK_TARGET_CENTERS = [(x, 745) for x in (240.2, 269.4, 298.6, 327.8)]
FIREPLACE_CENTER = (284, 800)
SCOOP_R = 15

KETTLE_SHOT_FROM, KETTLE_END = (330, 250), (140, 900)
KETTLE_CENTER = (141.7, 894.2)
KETTLE_HALF_W, KETTLE_LEN = 27, 120
KETTLE_LEFT_FLARE_END = (146, 752)

MAIL_SLOT_CENTER = (380, 640)
BUMPER_R = 22
BUMPER_CENTERS = [(285, 930), (350, 930), (318, 1000)]

LOFT_RIGHT_X, LOFT_BOTTOM_Y = 255, 975
LOFT_HEIGHT = 20          # M9 v3: the loft's platform (LmpTableLayout.loftHeight)
CHUTE_LOW_X = 46          # the chute's low end (LmpTableLayout.chuteLowX)
LOFT_DOOR_BOTTOM, LOFT_DOOR_TOP = 1104, 1136
LOFT_SLOPE = [(72, 1030), (162, 962)]
LOFT_FLIPPER_PIVOT, LOFT_FLIPPER_LEN, LOFT_PIVOT_R = (240, 985), 56, 10
WINDOW_SEAT_CENTER = (115, 1110)

RAMP_MOUTH = (412, 830)
RAMP_MOUTH_RIGHT_X = 470

CAT_SHELF_Y, CAT_MIN_X, CAT_MAX_X, CAT_R = 1175, 300, 440, 15


def left_orbit_wall():
    p0, c, p1 = (LEFT_X, ARCH_START_Y), (LEFT_X, TOP_Y), (WORLD_W / 2, TOP_Y)
    inset = LEFT_ORBIT_INNER_X - LEFT_X
    pts = [(LEFT_ORBIT_INNER_X, LEFT_ORBIT_MOUTH_Y)]
    for i in range(33):
        t = i / 32; u = 1 - t
        p = (u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0], u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1])
        d = (2 * u * (c[0] - p0[0]) + 2 * t * (p1[0] - c[0]), 2 * u * (c[1] - p0[1]) + 2 * t * (p1[1] - c[1]))
        l = max(math.hypot(*d), 0.001)
        q = (p[0] + d[1] / l * inset, p[1] - d[0] / l * inset)
        if q[0] > 190: break
        pts.append(q)
    return pts


def right_orbit_wall():
    return [(RIGHT_ORBIT_INNER_X, RIGHT_ORBIT_MOUTH_Y), (RIGHT_ORBIT_INNER_X, ARCH_START_Y)] + \
        quad((RIGHT_ORBIT_INNER_X, ARCH_START_Y), (RIGHT_ORBIT_INNER_X, ORBIT_TOP_INNER_Y), (380, ORBIT_TOP_INNER_Y))


def alcove_wall():
    return [(ALCOVE_LEFT_X, ALCOVE_BOTTOM_Y), (ALCOVE_LEFT_X, ALCOVE_TOP_Y),
            ((ALCOVE_LEFT_X + ALCOVE_RIGHT_X) / 2, ALCOVE_TOP_Y + ALCOVE_ROOF_PEAK),
            (ALCOVE_RIGHT_X, ALCOVE_TOP_Y), (ALCOVE_RIGHT_X, ALCOVE_BOTTOM_Y)]


def kettle_axis():
    dx, dy = KETTLE_END[0] - KETTLE_SHOT_FROM[0], KETTLE_END[1] - KETTLE_SHOT_FROM[1]
    l = math.hypot(dx, dy)
    return (dx / l, dy / l)


def kettle_point(t, side):
    u = kettle_axis()
    return (KETTLE_END[0] + u[0] * t - u[1] * side, KETTLE_END[1] + u[1] * t + u[0] * side)


def kettle_lane_wall():
    h = KETTLE_HALF_W
    pts = [KETTLE_LEFT_FLARE_END, kettle_point(-KETTLE_LEN, h)]
    for i in range(13):
        a = i * math.pi / 12
        pts.append(kettle_point(h * math.sin(a), h * math.cos(a)))
    pts.append(kettle_point(-KETTLE_LEN, -h))
    return pts


def arch_offset(inset, max_x):
    p0, c, p1 = (LEFT_X, ARCH_START_Y), (LEFT_X, TOP_Y), (WORLD_W / 2, TOP_Y)
    pts = []
    for i in range(65):
        t = i / 64; u = 1 - t
        p = (u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0], u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1])
        d = (2 * u * (c[0] - p0[0]) + 2 * t * (p1[0] - c[0]), 2 * u * (c[1] - p0[1]) + 2 * t * (p1[1] - c[1]))
        l = max(math.hypot(*d), 0.001)
        q = (p[0] + d[1] / l * inset, p[1] - d[0] / l * inset)
        if q[0] > max_x: break
        pts.append(q)
    return pts


def loft_outline():
    return arch_offset(52, LOFT_RIGHT_X)


def loft_top_right():
    o = loft_outline()
    return (LOFT_RIGHT_X, o[-1][1] if o else 1215)


def loft_flipper_guide():
    r = LOFT_PIVOT_R + 1
    top = (LOFT_FLIPPER_PIVOT[0] - r * math.sin(REST), LOFT_FLIPPER_PIVOT[1] + r * math.cos(REST))
    return [(LOFT_RIGHT_X, top[1] + 30), top]


def loft_walls():
    o = loft_outline(); tr = loft_top_right()
    return [[LOFT_SLOPE[0]] + [p for p in o if p[1] > LOFT_SLOPE[0][1]] + [tr],
            [tr, (LOFT_RIGHT_X, LOFT_DOOR_TOP)],
            [(LOFT_RIGHT_X, LOFT_DOOR_BOTTOM), (LOFT_RIGHT_X, LOFT_BOTTOM_Y)],
            LOFT_SLOPE,
            loft_flipper_guide()]


def loft_chute():
    return [(LOFT_RIGHT_X, LOFT_BOTTOM_Y), (40, 880)]


def loft_floor():
    o = loft_outline()
    return [LOFT_SLOPE[1], LOFT_SLOPE[0]] + [p for p in o if p[1] > LOFT_SLOPE[0][1]] + \
        [loft_top_right(), (LOFT_RIGHT_X, LOFT_BOTTOM_Y), (200, LOFT_BOTTOM_Y - 25)]


def loft_block():
    roof = arch_offset(LEFT_ORBIT_INNER_X - LEFT_X, LOFT_RIGHT_X)
    roof_right = (LOFT_RIGHT_X, roof[-1][1] if roof else 1225)
    return [(LEFT_ORBIT_INNER_X, ARCH_START_Y), (LEFT_ORBIT_INNER_X, LOFT_BOTTOM_Y), (LOFT_RIGHT_X, LOFT_BOTTOM_Y),
            roof_right] + list(reversed(roof))


def loft_front():
    """M9 v3: the raised loft platform's front edge, left to right (under the slope, then round the flipper's drain)."""
    return [(LEFT_ORBIT_INNER_X, LOFT_BOTTOM_Y), (162, 962), (200, 950), (LOFT_RIGHT_X, LOFT_BOTTOM_Y)]


def loft_platform():
    """M9 v3: the raised loft's platform: the block under it with the front edge dipping round the flipper."""
    blk = loft_block()
    return [blk[0]] + loft_front() + blk[3:]


def arch():
    """The outer wall's arch from the left wall's top round to the right wall's top."""
    mid = WORLD_W / 2
    return [(LEFT_X, ARCH_START_Y)] + quad((LEFT_X, ARCH_START_Y), (LEFT_X, TOP_Y), (mid, TOP_Y), 32) + \
        quad((mid, TOP_Y), (RIGHT_X, TOP_Y), (RIGHT_X, ARCH_START_Y), 32)


# ---- M9 v6: the loft ramp (LmpTableLayout.rampCenterline / rampRail / upperHeight), for its rendered sprite
RAMP_HALF_W, RAMP_HEADING, RAMP_FLARE_LEN, RAMP_STRAIGHT_LEN, RAMP_TURN_R = 16, math.radians(75), 82, 209, 70
RAMP_ART_RECT = (232, 800, 272, 372)          # LmpTableLayout.rampArtRect


def ramp_centerline():
    u = (math.cos(RAMP_HEADING), math.sin(RAMP_HEADING))
    end = (RAMP_MOUTH[0] + u[0] * RAMP_STRAIGHT_LEN, RAMP_MOUTH[1] + u[1] * RAMP_STRAIGHT_LEN)
    c = (end[0] - u[1] * RAMP_TURN_R, end[1] + u[0] * RAMP_TURN_R)
    pts = [RAMP_MOUTH, end]
    a0 = RAMP_HEADING - math.pi / 2
    for i in range(1, 15):
        a = a0 + i / 14 * (math.pi / 2 - a0)
        pts.append((c[0] + RAMP_TURN_R * math.cos(a), c[1] + RAMP_TURN_R * math.sin(a)))
    pts.append((LOFT_RIGHT_X, pts[-1][1]))
    return pts


def ramp_offset(side, pts=None):
    """The centreline offset by `side` (+ = left of travel), without the mouth's flare."""
    cl = pts or ramp_centerline()
    out = []
    for i in range(len(cl)):
        a, b = cl[max(i - 1, 0)], cl[min(i + 1, len(cl) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = max(math.hypot(dx, dy), 1e-3)
        out.append((cl[i][0] - dy / ln * side, cl[i][1] + dx / ln * side))
    return out


def ramp_rail(side):
    """LmpTableLayout.rampRail: the physics rail, with the mouth's flare."""
    cl = ramp_centerline(); u = (math.cos(RAMP_HEADING), math.sin(RAMP_HEADING))
    out = [(ALCOVE_RIGHT_X if side > 0 else RAMP_MOUTH_RIGHT_X, RAMP_MOUTH[1]),
           (RAMP_MOUTH[0] + u[0] * RAMP_FLARE_LEN - u[1] * side, RAMP_MOUTH[1] + u[1] * RAMP_FLARE_LEN + u[0] * side)]
    for i in range(1, len(cl)):
        a, b = cl[i - 1], cl[min(i + 1, len(cl) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = max(math.hypot(dx, dy), 1e-3)
        out.append((cl[i][0] - dy / ln * side, cl[i][1] + dx / ln * side))
    return out


def densify(pts, step=4.0):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        out += [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(1, n + 1)]
    return out


def ramp_height(p):
    """LmpTableLayout.upperHeight on the ramp: climbs along the first straight, level from the turn to the loft."""
    if p[0] <= LOFT_RIGHT_X + 4:
        return LOFT_HEIGHT
    along = (p[0] - RAMP_MOUTH[0]) * math.cos(RAMP_HEADING) + (p[1] - RAMP_MOUTH[1]) * math.sin(RAMP_HEADING)
    return LOFT_HEIGHT * min(max(along / RAMP_STRAIGHT_LEN, 0), 1)
