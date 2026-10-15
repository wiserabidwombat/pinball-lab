"""Table 03 milestone 3: grey-box layout of the top of the table, with gap checks and shot sweeps.
Reuses Grey Invasion's proven top (orbit + funnel, lanes, bumper nest, diverter, right ramp, target bank,
upper flipper) and adds the spinner, the Library hole + up-kicker wire, and the Lagoon.
Usage: python3 cth_render_m3.py out.png [lagoon_x lagoon_y]"""
import math, sys, os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

OUT = sys.argv[1] if len(sys.argv) > 1 else 'cth_m3.png'
LAGOON = (float(sys.argv[2]), float(sys.argv[3])) if len(sys.argv) > 3 else (440, 1030)
R = L.BALL_R

# ---------------------------------------------------------------- geometry (Grey Invasion's numbers)
ORBIT_X, FUNNEL_TIP, FUNNEL_BEND, ORBIT_END_X = 58, (112, 800), 890, 190
def orbit_inner():
    inner_top = L.TOP_Y - (ORBIT_X - L.LEFT_X)
    arc = L.quad((ORBIT_X, L.ARCH_Y), (ORBIT_X, inner_top), (L.W / 2, inner_top), 32)
    return [FUNNEL_TIP, (ORBIT_X, FUNNEL_BEND), (ORBIT_X, L.ARCH_Y)] + [p for p in arc if p[0] <= ORBIT_END_X]
DIVERTER = [(412, 1262), (365, 1160)]
LANE_POSTS = [220, 256, 292, 328]; LANE_BOTTOM, LANE_TOP = 1130, 1185
BUMPERS = [(210, 1050), (338, 1050), (274, 950)]; BUMPER_R = 28
TARGET_X, TARGET_YS = 464, [595, 565, 535, 505]; TARGET_W, TARGET_H = 12, 24
BANK_BACK = [(476, 487), (476, 621)]; BANK_CAP = [(476, 621), (454, 613)]
UPPER_PIVOT, UPPER_LEN = (528, 800), 64
RAMP_MOUTH, RAMP_HALF_MOUTH, RAMP_HALF, RAMP_FLARE, RAMP_POST = (360, 600), 30, 16, 70, 24

# new for Table 03
SPINNER = [(L.LEFT_X, 935), (ORBIT_X, 935)]           # across the orbit lane, above the funnel
LIBRARY = (284, 650)                                    # Grey Invasion's Hangar spot (robot-tuned, ~65%)
CAPTURE_R = 18


def path(start, heading, ops):
    pts = [start]; h = heading
    for op in ops:
        if op[0] == 'line':
            n = max(1, int(op[1] / 10))
            x, y = pts[-1]
            for i in range(1, n + 1):
                d = op[1] * i / n; pts.append((x + d * math.cos(h), y + d * math.sin(h)))
        else:
            rad, turn = op[1], op[2]; sign = 1 if turn > 0 else -1
            x, y = pts[-1]; cx, cy = x - sign * rad * math.sin(h), y + sign * rad * math.cos(h)
            a0 = math.atan2(y - cy, x - cx); n = max(2, int(abs(turn) * rad / 8))
            for i in range(1, n + 1):
                a = a0 + turn * i / n; pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
            h += turn
    return pts, h


def right_ramp():
    climb = math.atan2(260, 90)
    p, h = path(RAMP_MOUTH, climb, [('line', math.hypot(90, 260)), ('arc', 36, -(climb + math.pi / 2))])
    apex = len(p)
    bend = math.acos(1 - 23 / 120)
    p2, _ = path(p[-1], h, [('line', 248), ('arc', 60, -bend), ('arc', 60, bend), ('line', 40)])
    return p, p2


def library_wire():
    """The up-kicker's wire: climbs up-left from the Library, turns, runs down the left side and drops
    into the top of the left inlane (Grey Invasion's left-ramp return, started from the Library)."""
    climb = math.atan2(260, 90)
    p, h = path(LIBRARY, math.pi - climb, [('line', math.hypot(90, 260)), ('arc', 36, climb + math.pi / 2), ('line', 200)])
    shift = 69 - p[-1][0]
    bend = math.acos(1 - min(abs(shift), 119) / 120); turn = bend if shift > 0 else -bend
    p2, _ = path(p[-1], h, [('arc', 60, turn), ('arc', 60, -turn)])
    p3, _ = path(p2[-1], -math.pi / 2, [('line', max(p2[-1][1] - 490, 20))])
    return p + p2[1:] + p3[1:]


def ramp_mouth_posts():
    climb = math.atan2(260, 90); n = (-math.sin(climb), math.cos(climb)); f = (math.cos(climb), math.sin(climb))
    posts = []
    for side in (1, -1):
        pts = []
        for s in range(0, RAMP_POST + 1, 4):
            w = RAMP_HALF_MOUTH + (RAMP_HALF - RAMP_HALF_MOUTH) * min(s / RAMP_FLARE, 1)
            pts.append((RAMP_MOUTH[0] + s * f[0] + side * w * n[0], RAMP_MOUTH[1] + s * f[1] + side * w * n[1]))
        posts.append(pts)
    return posts


def upper_flipper(raised):
    ang = math.pi + (math.radians(30) if raised else -math.radians(30))   # points left; raised = 30° up
    tip = (UPPER_PIVOT[0] + UPPER_LEN * math.cos(ang), UPPER_PIVOT[1] + UPPER_LEN * math.sin(ang))
    return UPPER_PIVOT, tip


def main_flipper_tip(left, raised):
    piv = L.L_PIVOT if left else L.R_PIVOT
    a = math.radians(30) if raised else -math.radians(30)
    if not left: a = math.pi - a
    return piv, (piv[0] + L.FLIP_LEN * math.cos(a), piv[1] + L.FLIP_LEN * math.sin(a))


# ---------------------------------------------------------------- obstacles for the sweeps (floor layer only)
def segs(pts):
    return list(zip(pts, pts[1:]))
WALL_SEGS = segs(L.outer_wall()) + segs(orbit_inner()) + segs(L.left_lane_guide()) + segs(L.right_lane_guide())
for s in (L.SLING_L, L.sling_right()):
    WALL_SEGS += segs([s['top'], s['corner'], s['tip'], s['top']])
for x in LANE_POSTS: WALL_SEGS.append(((x, LANE_BOTTOM), (x, LANE_TOP)))
for y in TARGET_YS:
    x0, x1, y0, y1 = TARGET_X - TARGET_W / 2, TARGET_X + TARGET_W / 2, y - TARGET_H / 2, y + TARGET_H / 2
    WALL_SEGS += segs([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)])
WALL_SEGS += segs(BANK_BACK) + segs(BANK_CAP) + [tuple(UPPER_PIVOT_SEG) for UPPER_PIVOT_SEG in []]
for post in ramp_mouth_posts(): WALL_SEGS += segs(post)
CIRCLES = [(b, BUMPER_R) for b in BUMPERS]


def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay; ll = dx * dx + dy * dy
    t = 0 if ll == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / ll))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def sweep(origin, target, extra_walls=(), a0=0, a1=180, step=0.1, ignore_ramp_entry=False):
    """Fraction of launch angles (degrees, from origin) whose straight path reaches within CAPTURE_R
    of target before touching a wall/bumper (ball radius included). Returns (degrees ok, list of ok angles)."""
    ok = []
    walls = WALL_SEGS + list(extra_walls)
    a = a0
    while a <= a1:
        th = math.radians(a); dx, dy = math.cos(th), math.sin(th)
        x, y = origin
        hit = False
        for _ in range(1800):
            x += dx; y += dy
            if math.hypot(x - target[0], y - target[1]) <= CAPTURE_R:
                ok.append(a); break
            if any(seg_dist((x, y), s[0], s[1]) < R for s in walls) or any(math.hypot(x - c[0], y - c[1]) < r + R for c, r in CIRCLES):
                hit = True; break
            if y > 1300 or y < 0: break
        a += step
    return len(ok) * step, ok


# ---------------------------------------------------------------- shot sweeps
results = []
# the Lagoon from the upper flipper's raised tip (it shoots up-left), and from just along its face
up_piv, up_tip = upper_flipper(True)
for frac in (1.0, 0.75):
    o = (up_piv[0] + (up_tip[0] - up_piv[0]) * frac, up_piv[1] + (up_tip[1] - up_piv[1]) * frac + 10)
    deg, _ = sweep(o, LAGOON, a0=60, a1=170)
    results.append((f'Lagoon from upper flipper ({int(frac*100)}% along)', deg, o))
# the Lagoon from each main flipper tip (floor balls roll under the ramp; only its mouth posts block)
for left in (True, False):
    piv, tip = main_flipper_tip(left, True)
    o = (tip[0], tip[1] + 12)
    deg, _ = sweep(o, LAGOON, a0=40, a1=140)
    results.append((f'Lagoon from {"left" if left else "right"} flipper tip', deg, o))
# the Library from each main flipper (Grey Invasion measured ~65% here with the robot; this is the straight-line view)
for left in (True, False):
    piv, tip = main_flipper_tip(left, True)
    o = (piv[0] + (tip[0] - piv[0]) * 0.6, piv[1] + (tip[1] - piv[1]) * 0.6 + 14)
    deg, _ = sweep(o, LIBRARY, a0=30, a1=150)
    results.append((f'Library from {"left" if left else "right"} flipper (60% along)', deg, o))
# the orbit funnel from the right flipper (target = a point inside the funnel mouth)
piv, tip = main_flipper_tip(False, True)
o = (tip[0], tip[1] + 12)
deg, _ = sweep(o, (80, 880), a0=95, a1=140)
results.append(('Orbit funnel from right flipper tip', deg, o))
# the right ramp mouth from the left flipper
piv, tip = main_flipper_tip(True, True)
o = (tip[0], tip[1] + 12)
deg, _ = sweep(o, (RAMP_MOUTH[0] + 12 * math.cos(math.atan2(260, 90)), RAMP_MOUTH[1] + 12 * math.sin(math.atan2(260, 90))), a0=45, a1=100)
results.append(('Right ramp mouth from left flipper tip', deg, o))

# ---------------------------------------------------------------- gap checks
def min_gap(c, r, others):
    best = 1e9
    for s in others:
        best = min(best, seg_dist(c, s[0], s[1]) - r)
    return best
gaps = []
gaps.append(('Lagoon (r15) to nearest wall', min_gap(LAGOON, 15, WALL_SEGS)))
gaps.append(('Lagoon to nearest bumper edge', min(math.hypot(LAGOON[0] - b[0], LAGOON[1] - b[1]) - BUMPER_R - 15 for b in BUMPERS)))
gaps.append(('Library (r15) to nearest wall', min_gap(LIBRARY, 15, WALL_SEGS)))

# ---------------------------------------------------------------- draw
fig, ax = plt.subplots(figsize=(8.4, 15.6), dpi=110)
ax.set_facecolor('#0b1214'); fig.patch.set_facecolor('#0b1214')
def line(pts, col, lw=2, ls='-', alpha=1):
    ax.plot([p[0] for p in pts], [p[1] for p in pts], color=col, lw=lw, ls=ls, alpha=alpha, solid_capstyle='round')
GREEN, ORANGE, GREY, GOLD, TEAL = '#4dd9bf', '#ff8c40', '#9aa0a8', '#e7c35a', '#7cf0a8'
line(L.outer_wall(), GREEN); line(orbit_inner(), GREEN)
line(L.left_lane_guide(), GREEN); line(L.right_lane_guide(), GREEN)
ol, orr = L.outlane_walls(); line(ol, GREEN); line(orr, GREEN); line(L.right_apron(), GREEN)
for s in (L.SLING_L, L.sling_right()):
    line([s['top'], s['corner'], s['tip'], s['top']], GREEN); line([s['tip'], s['top']], ORANGE, 3)
for x in LANE_POSTS: line([(x, LANE_BOTTOM), (x, LANE_TOP)], GREEN)
for b in BUMPERS: ax.add_patch(plt.Circle(b, BUMPER_R, color='#e07a6a', alpha=0.85))
line(DIVERTER, ORANGE, 3)
for y in TARGET_YS:
    ax.add_patch(plt.Rectangle((TARGET_X - 6, y - 12), 12, 24, color=ORANGE))
line(BANK_BACK, GREEN); line(BANK_CAP, GREEN)
rp, rw = right_ramp()
line(rp, '#3fbf8f', 14, alpha=0.35); line(rw, '#c8ccd2', 2.5)
for post in ramp_mouth_posts(): line(post, GREY, 4)
lw = library_wire(); line(lw, GOLD, 2.5, '--')
ax.add_patch(plt.Circle(LIBRARY, 15, color='#1a1a22', ec=GOLD, lw=2))
ax.add_patch(plt.Circle(LAGOON, 15, color='#08302c', ec=TEAL, lw=2))
ax.add_patch(plt.Circle(LAGOON, 60, fill=False, ec=TEAL, lw=1, ls=':'))          # Cthulhu's sway zone
line(SPINNER, ORANGE, 5)
for left in (True, False):
    piv, tip = main_flipper_tip(left, False); line([piv, tip], '#f2efe6', 6)
upv, upt = upper_flipper(False); line([upv, upt], '#f2efe6', 5)
ax.add_patch(plt.Circle((284, 470), 40, fill=False, ec=GOLD, lw=1, ls=':'))       # ritual circle + magnet
ax.plot([284], [470], 'o', color=GOLD)
# shot fans
for name, deg, o in results:
    tgt = LAGOON if 'Lagoon' in name else LIBRARY if 'Library' in name else (80, 880) if 'Orbit' in name else RAMP_MOUTH
    if deg > 0:
        ax.plot([o[0], tgt[0]], [o[1], tgt[1]], color='#ffffff', lw=0.8, alpha=0.5, ls=':')
labels = {'Library': (LIBRARY, 'LIBRARY\n(up-kicker)'), 'Lagoon': (LAGOON, 'LAGOON\n(Cthulhu)')}
for k, (p, t) in labels.items():
    ax.text(p[0] + 20, p[1] + 18, t, color='white', fontsize=8)
ax.text(24, 940, 'spinner', color=ORANGE, fontsize=7, rotation=90)
ax.text(300, 462, 'ritual circle\n+ magnet', color=GOLD, fontsize=7)
ax.text(472, 470, 'SIGIL\nbank', color=ORANGE, fontsize=7)
ax.text(60, 560, 'up-kicker wire\n→ left inlane', color=GOLD, fontsize=7)
ax.set_xlim(-10, 610); ax.set_ylim(150, 1290); ax.set_aspect('equal'); ax.axis('off')
txt = '\n'.join([f'{n}: {d:.1f}° of aim' for n, d, _ in results] + [f'{n}: {g:.1f} pt' for n, g in gaps])
ax.text(0.01, 0.005, txt, transform=ax.transAxes, color='white', fontsize=7.2, va='bottom', family='monospace',
        bbox=dict(facecolor='black', alpha=0.6, edgecolor='none'))
plt.savefig(OUT, bbox_inches='tight', facecolor=fig.get_facecolor())
print(txt)
