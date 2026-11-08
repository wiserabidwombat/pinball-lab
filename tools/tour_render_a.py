"""Render + checks for Concept A: the open band, the shot fan's angles, gaps, eject paths with gravity."""
import math, sys
sys.path.insert(0, '.')
import tour_layout as L, tour_layout_a as A
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    from tour_render_m2 import seg_dist, seg_seg, poly_edges, shape_gap
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon

walls = [(L.outer_wall(), False), (L.leftLaneGuide, False), (L.rightLaneGuide, False), (L.leftOutlaneWall, False),
         (L.rightOutlaneWall, False), (L.leftOutlanePostRail, False), (L.rightOutlanePostRail, False),
         (list(L.leftSling), True), (list(L.rightSling), True),
         (A.rocketPad, False), ([(0, -100), (1, -100)], False),
         (A.bunkerRoof, False), (A.bunkerFloor, False), (A.ROC_STRUCT, False)]
parts = {}
parts['blast door'] = L.face(A.blastDoor, -90, A.dropFace, 8)
for i, (p, a) in enumerate(A.roc_targets()):
    parts['standup ' + 'ROCKET'[i]] = L.face(p, a, 26, 8)
for i, (p, a) in enumerate(A.sample_targets()):
    parts['sample %d' % (i + 1)] = L.face(p, a, 24, 8)
NEIGH = lambda a, b: a.split()[0] == b.split()[0] and abs(ord(a[-1]) - ord(b[-1])) > 1

fig, ax = plt.subplots(figsize=(8, 15)); ax.set_facecolor('#0b0f1e')
def poly(pts, c='#9fb4ff', lw=2, closed=False):
    pts = list(pts) + ([pts[0]] if closed else []); xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw)
for w, closed in walls: poly(w, closed=closed, c='#ff9a3c' if closed else '#9fb4ff')
for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
    tip = L.flipper_tip(piv, side); ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=8, solid_capstyle='round')
ax.add_patch(Circle(L.rocketPost, L.rocketPostRadius, color='#ff4d4d'))
for c in A.countdownLamps: ax.add_patch(Circle(c, 6, color='#ffb347', alpha=0.8))
ax.add_patch(Polygon([(284, 1022), (295, 978), (273, 978)], fc='#e6e9f2', ec='#ff8c33'))
ax.add_patch(Rectangle((22, A.OPEN_BAND[0]), 526, A.OPEN_BAND[1] - A.OPEN_BAND[0], color='#2a7fff', alpha=0.08))
ax.add_patch(Rectangle((A.CENTRE_OPEN[0], A.OPEN_BAND[0]), A.CENTRE_OPEN[1] - A.CENTRE_OPEN[0],
                       A.OPEN_BAND[1] - A.OPEN_BAND[0], fill=False, ec='#2a7fff', ls='--'))
ax.axhline(A.SHOT_LINE, color='#ffd75c', lw=1, ls=':')
for name, pts in parts.items():
    col = '#ffb347' if name.startswith('drop') else '#7cf' if name.startswith('standup') else '#e86a4a'
    ax.add_patch(Polygon(pts, closed=True, color=col))
    cx = sum(p[0] for p in pts) / 4; cy = sum(p[1] for p in pts) / 4
    ax.text(cx, cy, name.split()[-1], color='w', fontsize=7, ha='center', va='center')
for c, lab in [(A.missionScoop, 'Mission Control'), (A.roverScoop, 'rover')]:
    ax.add_patch(Circle(c, 14, fc='#111', ec='#ccc', lw=2)); ax.text(c[0] + 18, c[1] + 6, lab, color='#ccc', fontsize=7)
print('The fan (degrees from the flipper that makes it; neighbours should be ~6-15 apart):')
prev = None
for name, m, who in A.SHOTS:
    frm = A.TIP_R if who == 'R' else A.TIP_L
    a = A.ang(frm, m) if who != 'both' else A.ang(A.TIP_R, m)
    a2 = A.ang(A.TIP_L, m)
    ax.annotate('', xy=m, xytext=frm if who != 'both' else (284, 180),
                arrowprops=dict(arrowstyle='->', color='#ffd75c', lw=1, alpha=0.7))
    ax.text(m[0], m[1] + 12, name, color='#ffd75c', fontsize=7, ha='center')
    print(f'  {name:10s} at {m}  from R {A.ang(A.TIP_R, m):6.1f}°  from L {a2:6.1f}°')
# open-band check: no part centre inside the middle of the open band
bad = [n for n, pts in parts.items()
       if any(A.OPEN_BAND[0] < p[1] < A.OPEN_BAND[1] and A.CENTRE_OPEN[0] < p[0] < A.CENTRE_OPEN[1] for p in pts)]
print('Open band, middle half: ' + ('CLEAR' if not bad else 'BLOCKED by ' + ', '.join(bad)))
D = 18
print('Gaps (pt; passages >= 27, closed < 18):')
names = list(parts)
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        g = shape_gap(parts[names[i]], True, parts[names[j]], True)
        if NEIGH(names[i], names[j]) and names[i].startswith(('drop', 'sample')): continue
        if g < 40: print(f'  {names[i]:10s} – {names[j]:10s} {g:5.1f}', '' if g < D or g >= 1.5 * D else '<-- WEDGE')
for n, pts in parts.items():
    for k, (w, c) in enumerate(walls):
        g = shape_gap(pts, True, w, c)
        if g < 40: print(f'  {n:10s} – wall{k:<2d}    {g:5.1f}', '' if g < D or g >= 1.5 * D else '<-- WEDGE')
for c in [A.missionScoop, A.roverScoop]:
    g = min(shape_gap([c, c], False, pts, True) for pts in parts.values()) - 14
    print(f'  scoop {c} nearest part {g:.1f} beyond its rim')
def eject(p, v, label, skip=lambda n: False, until=260):
    pts, t = [], 0.0
    while t < 1.5:
        q = (p[0] + v[0] * t, p[1] + v[1] * t - 690 * t * t)
        if q[1] < until: break
        pts.append(q); t += 0.002
    xs, ys = zip(*pts); ax.plot(xs, ys, color='#e8e', lw=1, ls='--')
    worst = min([(shape_gap(pts, False, pp, True), n) for n, pp in parts.items() if not skip(n)] +
                [(shape_gap(pts, False, w, c), 'wall%d' % k) for k, (w, c) in enumerate(walls) if k < 9 or k >= 11])
    print(f'{label} eject: lands near x {pts[-1][0]:.0f} at y {until}; nearest {worst[1]} {worst[0] - 9:.1f} pt beyond the ball')
eject(A.missionSubwayExit, A.missionEject, 'Mission Control subway', skip=lambda n: False, until=230)
ax.plot([A.missionScoop[0], A.missionSubwayExit[0]], [A.missionScoop[1], A.missionSubwayExit[1]], color='#888', lw=1, ls=':')
eject(A.roverScoop, A.roverEject, 'rover', skip=lambda n: n.startswith('sample'), until=230)
ax.set_xlim(-10, 610); ax.set_ylim(60, 1290); ax.set_aspect('equal')
ax.set_title('Table 06 Concept A (T6 M2 v15): the open band, the shot fan, the centrepiece, side-wall banks', fontsize=9)
fig.savefig(sys.argv[1], dpi=100, bbox_inches='tight')
# Every planned shot line must clear every part and wall by the ball's radius (the banks must not shadow a shot).
print('Shot lines (ball edge to the nearest part/wall, must be > 0):')
for name, m, who in A.SHOTS:
    frm = (284, 180) if who == 'both' else (A.TIP_R if who == 'R' else A.TIP_L)
    seg = [frm, m]
    cand = [(shape_gap(seg, False, pp, True), n) for n, pp in parts.items() if not (name == 'centre' and n in ('blast door',))]
    cand += [(shape_gap(seg, False, w, c), 'wall%d' % k) for k, (w, c) in enumerate(walls) if k not in (1, 2, 7, 8) and k != 0]
    g, n = min(cand); print(f'  {name:10s} {g - 9:6.1f}  ({n})')
