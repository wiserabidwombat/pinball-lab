"""Table 06 (Orbit: Grand Tour) M5 look development: the lower table's geometry, copied from TourTableLayout.swift
(commit 18a11fa). Same names where they exist. World points, y up; 1 Blender unit = 1 point."""
import math

W, H = 600, 1300
OBLIQUE = 0.4040            # a point at height z is drawn z * OBLIQUE farther up the table
PX_PER_PT = 3               # the baked table
LOWER_RECT = (-40, -75, 680, 775)    # M5 v1: the lower table up to y 700 (R-O-C bank, Mars bunker, ramp mouths' feet)

LEFT_X, RIGHT_X, LANE_X = 20, 580, 548
LANE_FLOOR_Y, ARCH_START_Y, TOP_Y = 40, 1000, 1270
APRON_TOP_Y, DRAIN_X, DRAIN_Y, DRAIN_LIP_Y = 185, 250, 105, 85
MIRROR = LEFT_X + LANE_X            # 568: the right side mirrors the left about x 284
LANE_WALL_TOP = 955


def mirrored(p): return (MIRROR - p[0], p[1])


# flippers
LEFT_PIVOT, RIGHT_PIVOT = (179, 220), (389, 220)
FLIPPER_LEN, PIVOT_R, TIP_R = 96, 12, 6
REST = math.pi / 6


def left_guide_end():
    r = PIVOT_R + 1
    return (LEFT_PIVOT[0] + r * math.sin(REST), LEFT_PIVOT[1] + r * math.cos(REST))


# lane guides, outlanes, slings
LANE_GUIDE_X, LANE_GUIDE_TOP, LANE_GUIDE_BEND = 54, 470, 330
OUTLANE_WALL_BOTTOM = 215


def left_lane_guide(): return [(LANE_GUIDE_X, LANE_GUIDE_TOP), (LANE_GUIDE_X, LANE_GUIDE_BEND), left_guide_end()]
def right_lane_guide(): return [mirrored(p) for p in left_lane_guide()]
def left_outlane_wall(): return [(LANE_GUIDE_X, LANE_GUIDE_BEND), (LANE_GUIDE_X, OUTLANE_WALL_BOTTOM)]
def right_outlane_wall(): return [mirrored(p) for p in left_outlane_wall()]
def left_outlane_post_rail(): return [(LANE_GUIDE_X, LANE_GUIDE_TOP), (44, 482)]
def right_outlane_post_rail(): return [mirrored(p) for p in left_outlane_post_rail()]


SLING_L = {'top': (88, 450), 'corner': (88, 347), 'tip': (150, 300.4)}
def sling_right(): return {k: mirrored(v) for k, v in SLING_L.items()}
SLING_TOP_POST_R, SLING_TIP_POST_R, SLING_CORNER_POST_R = 7, 6, 5.5


def left_apron(): return [(DRAIN_X, DRAIN_LIP_Y), (DRAIN_X, DRAIN_Y), (LEFT_X, APRON_TOP_Y)]
def right_apron(): return [(LANE_X, APRON_TOP_Y), (MIRROR - DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, DRAIN_LIP_Y)]


# O-R-B-T lanes, kickback, rocket post, countdown
LANE_LETTERS = "ORBT"
LANE_ROLLOVER_Y, LANE_LAMP_Y = 405, 378
LANE_XS = [(LEFT_X + LANE_GUIDE_X) / 2, (LANE_GUIDE_X + 88) / 2,
           MIRROR - (LANE_GUIDE_X + 88) / 2, MIRROR - (LEFT_X + LANE_GUIDE_X) / 2]
KICKBACK_LAMP = (37, 300)
ROCKET_POST, ROCKET_POST_R = (284, 162), 7
COUNTDOWN_LAMPS = [(284, 500 + 18 * i) for i in range(5)]

# R-O-C bank on the left wall (the '/' deflector, backboard and roof) and its standups
ROC_STRUCTURE = [(20, 530), (50, 594.3), (86.3, 672.3), (20, 714.3)]
ROCKET_NORMAL = -0.4363
ROCKET_CENTERS = [(60.8, 608.1), (72.6, 633.4), (84.5, 658.8)]
STANDUP = (26, 8)

# Mars bunker on the right wall: sample bank (three drops), the rover scoop, floor V and roof
SAMPLE_NORMAL = 3.3510
SAMPLE_CENTERS = [(508.0, 522.0), (502.4, 548.4), (496.8, 574.8)]
DROP = (24, 8)
ROVER_SCOOP = (532, 530)
BUNKER_FLOOR = [(507.0, 509.5), (532, 514), (548, 522)]
BUNKER_ROOF = [(489.9, 585.7), (516, 606), (548, 623.3)]
SCOOP_R = 14

# shot entrances that start inside the rect (for the arrow inserts): ramp mouths and orbit funnel tips
MOON_MOUTH, MOON_HEADING = (200, 760), 100
SATURN_MOUTH, SATURN_HEADING = (420.5, 700), 72
LEFT_ORBIT_TIP, RIGHT_ORBIT_TIP = (85.05, 871.73), (477.20, 688.85)


def quad(p0, c, p1, n=16):
    out = []
    for i in range(1, n + 1):
        t = i / n; u = 1 - t
        out.append((u*u*p0[0] + 2*u*t*c[0] + t*t*p1[0], u*u*p0[1] + 2*u*t*c[1] + t*t*p1[1]))
    return out


def lane_wall():
    """The shooter-lane wall (straight: the right bulge inset is 0)."""
    return [(LANE_X, LANE_FLOOR_Y), (LANE_X, LANE_WALL_TOP)]


def plate(center, normal, size):
    """A thin target plate's four corners: face toward `normal` (radians), width along the face, depth across."""
    nx, ny = math.cos(normal), math.sin(normal); tx, ty = -ny, nx
    cx, cy = center; w, d = size[0] / 2, size[1] / 2
    return [(cx + tx*w + nx*d, cy + ty*w + ny*d), (cx - tx*w + nx*d, cy - ty*w + ny*d),
            (cx - tx*w - nx*d, cy - ty*w - ny*d), (cx + tx*w - nx*d, cy + ty*w - ny*d)]
