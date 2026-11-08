"""Render + checks for M3 v1 (the orbits): gaps, the aim window of each orbit from the opposite flipper (a radius-9 ball
on a straight line; it must get into the lane past the funnel tip without touching a wall), and where a ball coming
DOWN each lane lands."""
import math, sys
sys.path.insert(0, '.')
import tour_layout as L, tour_layout_a as A, tour_layout_m3 as M
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    from tour_render_m2 import seg_dist, shape_gap
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Polygon
R = 9
gate = [(548, 955), (580, 983)]
walls = {'outer': L.outer_wall(), 'L lane guide': L.leftLaneGuide, 'R lane guide': L.rightLaneGuide,
         'L sling': list(L.leftSling) + [L.leftSling[0]], 'R sling': list(L.rightSling) + [L.rightSling[0]],
         'rocket pad': M.rocketPad, 'rocket hull': M.rocketHull,
         'bunker roof': A.bunkerRoof, 'bunker floor': A.bunkerFloor, 'ROC': A.ROC_STRUCT,
         'L orbit inner': M.leftOrbitInner, 'R orbit inner': M.rightOrbitInner, 'launch gate': gate}
for i, x in enumerate(M.lanePostXs): walls['post %d' % i] = [(x, M.lanePostBottom), (x, M.lanePostTop)]
circ = lambda c, r: [(c[0] + r * math.cos(k / 16 * math.pi), c[1] + r * math.sin(k / 16 * math.pi)) for k in range(33)]
bumpers = {'bumper %d' % i: circ(c, M.bumperRadius) for i, c in enumerate(M.bumperCenters)}
hull = M.rocketHull
samples = [L.face(p, a, 24, 8) for p, a in A.sample_targets()]
rocs = [L.face(p, a, 26, 8) for p, a in A.roc_targets()]

fig, ax = plt.subplots(figsize=(8, 15)); ax.set_facecolor('#0b0f1e')
for n, w in walls.items():
    xs, ys = zip(*w); ax.plot(xs, ys, color='#ff9a3c' if 'orbit' in n else '#9fb4ff', lw=2.4 if 'orbit' in n else 1.6)
xs, ys = zip(*hull); ax.plot(xs, ys, color='#cfd6e6', lw=4)
for f in samples + rocs: ax.add_patch(Polygon(f, color='#e86a4a'))
for c in M.bumperCenters: ax.add_patch(Circle(c, M.bumperRadius, fc='#e0785f', ec='#ffd2c0', lw=1.5))
for i, x in enumerate(M.laneCenters):
    ax.add_patch(Circle((x, M.laneLampY), 7, fc='#ffcc4d', ec='w', lw=0.5)); ax.text(x, M.laneLampY, 'STAR'[i], fontsize=6, ha='center', va='center')
    ax.plot([x - 11, x + 11], [M.laneRolloverY] * 2, color='#ccc', lw=2)
for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
    tip = L.flipper_tip(piv, side); ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=8, solid_capstyle='round')
for (a, b), c in [(M.leftSpinner, '#ffd75c'), (M.rightSpinner, '#ffd75c'), (M.leftArm, '#7f7'), (M.rightArm, '#7f7'), (M.madeLine, '#7f7')]:
    ax.plot([a[0], b[0]], [a[1], b[1]], color=c, lw=2, ls='-' if c == '#ffd75c' else ':')

print('Gaps (pt; passages >= 27, closed < 18):')
def g(a, b, ca=False, cb=False): return shape_gap(a, ca, b, cb)
checks = [('L funnel tip', [M.L_TIP, M.L_BEND], 'ROC', A.ROC_STRUCT), ('L funnel tip', [M.L_TIP, M.L_BEND], 'outer', L.outer_wall()),
          ('R funnel tip', [M.R_TIP, M.R_BEND], 'bunker roof', A.bunkerRoof), ('R funnel tip', [M.R_TIP, M.R_BEND], 'lane wall', [(548, 470), (548, 955)]),
          ('R inner', M.rightOrbitInner, 'launch gate', gate), ('R inner', M.rightOrbitInner, 'rocket pad', walls['rocket pad']),
          ('L inner', M.leftOrbitInner, 'rocket pad', walls['rocket pad'])]
for a, pa, b, pb in checks:
    v = g(pa, pb); print(f'  {a:14s} – {b:12s} {v:6.1f}', '<-- WEDGE' if 18 <= v < 27 else '')
print('M3 v2 — bumpers and lanes:')
for bn, bp in bumpers.items():
    for n, w in walls.items():
        if n in ('outer',) or n.startswith(('L sling', 'R sling', 'L lane', 'R lane')): continue
        v = shape_gap(bp, True, w, False)
        if v < 45: print(f'  {bn:9s} – {n:13s} {v:6.1f}', '<-- WEDGE' if 18 <= v < 27 else '')
    v = shape_gap(bp, True, L.outer_wall(), False)
    if v < 45: print(f'  {bn:9s} – outer         {v:6.1f}', '<-- WEDGE' if 18 <= v < 27 else '')
bl = list(bumpers.values())
for i in range(3):
    for j in range(i + 1, 3): print(f'  bumper {i} – bumper {j} {math.dist(M.bumperCenters[i], M.bumperCenters[j]) - 2 * M.bumperRadius:6.1f}')
print(f"  L inner end – first post {g(M.leftOrbitInner[-4:], walls['post 0']):.1f}   R inner end – last post {g(M.rightOrbitInner[-4:], walls['post 4']):.1f}")
for x in M.lanePostXs:
    ay = next(u[1] + (x - u[0]) * (v[1] - u[1]) / (v[0] - u[0]) for u, v in zip(M.ARCH, M.ARCH[1:]) if u[0] <= x <= v[0] and v[0] > u[0])
    print(f'  post x {x}: a ball on the arch passes {ay - 9 - 9 - M.lanePostTop:.0f} pt over it')
for s in samples: print(f'  R funnel tip – sample      {g([M.R_TIP, M.R_BEND], s, False, True):6.1f}')
# lane widths along each lane (inner wall to the outer arch)
def lane_min(inner, lo_y):
    pts = [p for p in inner if p[1] >= lo_y]
    return min(min(seg_dist(p, a, b) for a, b in zip(L.outer_wall(), L.outer_wall()[1:])) for p in pts)
print(f'  left lane narrowest {lane_min(M.leftOrbitInner, 915):.1f}   right lane narrowest (above the gate) {lane_min([p for p in M.rightOrbitInner if p[1] > 990], 990):.1f}')

def blocked(frm, ang, until_y, skip=()):
    t = math.radians(ang); dx, dy = math.cos(t), math.sin(t)
    k = (until_y - frm[1]) / dy; end = (frm[0] + dx * k, frm[1] + dy * k)
    for n, w in walls.items():
        if n in skip: continue
        if shape_gap([frm, end], False, w, n in ('L sling', 'R sling')) < R: return True, end
    for f in samples + rocs:
        if shape_gap([frm, end], False, f, True) < R: return True, end
    return False, end
def window(frm, lo, hi, until_y, lane):
    ok = []
    for a10 in range(int(lo * 10), int(hi * 10)):
        a = a10 / 10; b, end = blocked(frm, a, until_y)
        if not b and lane[0] + R <= end[0] <= lane[1] - R: ok.append(a)
    return ok
# Grey Invasion's test (render_m6a): the ball is in the funnel's mouth at the funnel tip's height (between the outer wall
# and the tip) with nothing touched on the way; the funnel's walls, near-parallel to the shot, then steer it in.
lw = window(A.TIP_R, 95, 130, M.L_TIP[1], (20, M.L_TIP[0])); rw = window(A.TIP_L, 50, 80, M.R_TIP[1], (M.R_TIP[0], 548))
# ...or the ball reaches the outer wall (a smooth rail: restitution 0.15, friction 0.02) below the mouth but above the
# bank roof, with nothing touched first, and slides up it into the lane.
def wall_window(frm, lo, hi, wall_x, y_lo, y_hi):
    ok = []
    for a10 in range(int(lo * 10), int(hi * 10)):
        a = a10 / 10; t = math.radians(a); dx, dy = math.cos(t), math.sin(t)
        k = (wall_x - frm[0]) / dx; y = frm[1] + dy * k
        if not (y_lo <= y <= y_hi): continue
        b, _ = blocked(frm, a, y - 1, skip=('outer',))
        if not b: ok.append(a)
    return ok
lw2 = wall_window(A.TIP_R, 95, 130, 20 + R, max(p[1] for p in A.ROC_STRUCT) + R, M.L_TIP[1])
rw2 = wall_window(A.TIP_L, 50, 80, 548 - R, max(p[1] for p in A.bunkerRoof) + R, M.R_TIP[1])
print(f'  (mouth only: left {min(lw) if lw else 0:.1f}–{max(lw) if lw else 0:.1f}, right {min(rw) if rw else 0:.1f}–{max(rw) if rw else 0:.1f}; off the wall: left {min(lw2) if lw2 else 0:.1f}–{max(lw2) if lw2 else 0:.1f}, right {min(rw2) if rw2 else 0:.1f}–{max(rw2) if rw2 else 0:.1f})')
lw = sorted(set(lw) | set(lw2)); rw = sorted(set(rw) | set(rw2))
print(f'Left orbit from the right flipper tip: {min(lw):.1f}–{max(lw):.1f}° ({max(lw)-min(lw):.1f}° wide)' if lw else 'Left orbit: NO clean line')
print(f'Right orbit from the left flipper tip: {min(rw):.1f}–{max(rw):.1f}° ({max(rw)-min(rw):.1f}° wide)' if rw else 'Right orbit: NO clean line')
for w, frm in [(lw, A.TIP_R), (rw, A.TIP_L)]:
    if not w: continue
    for a in (min(w), max(w)):
        t = math.radians(a); ax.plot([frm[0], frm[0] + math.cos(t) * 900], [frm[1], frm[1] + math.sin(t) * 900], color='#ffd75c', lw=0.6, alpha=0.6)
print(f'Shot-fan neighbours: Moon ramp from R {A.ang(A.TIP_R, (200, 612)):.1f}°, asteroids from L {A.ang(A.TIP_L, (458, 600)):.1f}°')
ax.set_xlim(-10, 610); ax.set_ylim(60, 1290); ax.set_aspect('equal')
ax.set_title('T6 M3 v2: orbits (orange), spinners (gold), S-T-A-R lanes + bumpers, switches (green dotted), aim windows', fontsize=9)
fig.savefig(sys.argv[1], dpi=100, bbox_inches='tight')
