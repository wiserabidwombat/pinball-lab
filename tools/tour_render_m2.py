"""Table 06 M2 layout render: the lower half's targets and scoops, shot lines and gap checks."""
import math, sys
sys.path.insert(0, '.')
import tour_layout as L
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon

def seg_dist(p, a, b):
    ax_, ay = a; bx, by = b; px, py = p
    dx, dy = bx-ax_, by-ay; l2 = dx*dx+dy*dy
    t = 0 if l2 == 0 else max(0, min(1, ((px-ax_)*dx+(py-ay)*dy)/l2))
    return math.hypot(px-ax_-t*dx, py-ay-t*dy)
def seg_seg(a, b, c, d):
    def inter(p1,p2,p3,p4):
        def cr(o,a,b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
        d1,d2,d3,d4=cr(p3,p4,p1),cr(p3,p4,p2),cr(p1,p2,p3),cr(p1,p2,p4)
        return d1*d2<0 and d3*d4<0
    if inter(a,b,c,d): return 0
    return min(seg_dist(a,c,d),seg_dist(b,c,d),seg_dist(c,a,b),seg_dist(d,a,b))
def poly_edges(pts, closed):
    n = len(pts); return [(pts[i], pts[(i+1) % n]) for i in range(n if closed else n-1)]
def shape_gap(A, Ac, B, Bc):
    return min(seg_seg(a, b, c, d) for a, b in poly_edges(A, Ac) for c, d in poly_edges(B, Bc))

walls = [(L.outer_wall(), False), (L.leftLaneGuide, False), (L.rightLaneGuide, False), (L.leftOutlaneWall, False),
         (L.rightOutlaneWall, False), (L.leftOutlanePostRail, False), (L.rightOutlanePostRail, False),
         (list(L.leftSling), True), (list(L.rightSling), True),
         (L.missionLeftWall, False), (L.missionRightWall, False)]
parts = {}
for i, x in enumerate(L.countdownXs):
    parts['drop ' + L.countdownLabels[i]] = L.face((x, L.countdownY), -90, *L.dropSize)
for i, (p, a) in enumerate(L.rocket_targets()):
    parts['standup ' + L.rocketLabels[i]] = L.face(p, a, *L.standupSize)
for i, (p, a) in enumerate(L.sample_targets()):
    parts['sample %d' % (i + 1)] = L.face(p, a, *L.dropSize)

fig, ax = plt.subplots(figsize=(8, 11))
ax.set_facecolor('#0b0f1e')
def poly(pts, c='#9fb4ff', lw=2, closed=False):
    pts = list(pts) + ([pts[0]] if closed else []); xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw)
for w, closed in walls: poly(w, closed=closed, c='#ff9a3c' if closed else '#9fb4ff')
for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
    tip = L.flipper_tip(piv, side)
    ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=8, solid_capstyle='round')
ax.add_patch(Circle(L.rocketPost, L.rocketPostRadius, color='#ff4d4d'))
for name, pts in parts.items():
    col = '#ffb347' if name.startswith('drop') else '#7cf' if name.startswith('standup') else '#e86a4a'
    ax.add_patch(Polygon(pts, closed=True, color=col))
    cx = sum(p[0] for p in pts) / 4; cy = sum(p[1] for p in pts) / 4
    ax.text(cx, cy - 16 if name.startswith('drop') else cy, name.split()[-1], color='w', fontsize=8, ha='center', va='center')
for c, lab in [(L.missionScoop, 'Mission\nControl'), (L.roverScoop, 'Rover')]:
    ax.add_patch(Circle(c, L.scoopRadius, fc='#111', ec='#ccc', lw=2))
    ax.text(c[0], c[1] + 26, lab, color='#ccc', fontsize=8, ha='center')
# Shot / eject lines with the ball's width
def path(p0, v, length, col):
    n = math.hypot(*v); p1 = (p0[0] + v[0] / n * length, p0[1] + v[1] / n * length)
    ax.plot([p0[0], p1[0]], [p0[1], p1[1]], color=col, lw=2 * L.ballRadius, alpha=0.18, solid_capstyle='round')
    ax.plot([p0[0], p1[0]], [p0[1], p1[1]], color=col, lw=1, ls='--')
    return p1
rover_end = path(L.roverScoop, L.roverEject, 640, '#e86a4a')
mission_end = path(L.missionScoop, L.missionEject, 560, '#ffd75c')
ax.set_xlim(-10, 610); ax.set_ylim(60, 900); ax.set_aspect('equal')
ax.set_title('Table 06 M2 v1: lower half — countdown bank, Mission Control, ROCKET, sample bank, rover')
fig.savefig(sys.argv[1] if len(sys.argv) > 1 else 'm2_lower.png', dpi=110, bbox_inches='tight')

# --- gap checks (ball diameter 18): passages ≥ 27 (1.5 d), closed gaps < 18 ---
D = 2 * L.ballRadius
print('Gaps between neighbouring parts (pt):')
names = list(parts)
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        g = shape_gap(parts[names[i]], True, parts[names[j]], True)
        if g < 60: print(f'  {names[i]:10s} – {names[j]:10s} {g:5.1f}', '' if g < D or g >= 1.5 * D else '  <-- WEDGE RISK')
for name, pts in parts.items():
    for k, (w, closed) in enumerate(walls):
        g = shape_gap(pts, True, w, closed)
        if g < 60: print(f'  {name:10s} – wall{k:<2d}    {g:5.1f}', '' if g < D or g >= 1.5 * D else '  <-- WEDGE RISK')
def path_clear(p0, v, length, label):
    n = math.hypot(*v); p1 = (p0[0] + v[0] / n * length, p0[1] + v[1] / n * length)
    worst = min([(shape_gap([p0, p1], False, pts, True), nm) for nm, pts in parts.items() if not (label == 'mission' and nm.startswith('drop'))] +
                [(shape_gap([p0, p1], False, w, c), 'wall%d' % k) for k, (w, c) in enumerate(walls)
                 if not (label == 'mission' and k >= 9)])
    print(f'{label} path: nearest {worst[1]} {worst[0] - L.ballRadius:.1f} pt beyond the ball edge (must be > 0)')
path_clear(L.roverScoop, L.roverEject, 560, 'rover')
path_clear((L.missionScoop[0] - 12, L.missionScoop[1] - 70), L.missionEject, 470, 'mission')
# With gravity (1,380 pt/s² down): the ejects as they really fly, to y 230.
def path_clear_g(p, v, label, skip):
    pts, t = [], 0.0
    while t < 0.8:
        q = (p[0] + v[0] * t, p[1] + v[1] * t - 690 * t * t)
        if q[1] < 230: break
        pts.append(q); t += 0.002
    worst = min([(shape_gap(pts, False, pp, True), n) for n, pp in parts.items() if not skip(n)] +
                [(shape_gap(pts, False, w, c), 'wall%d' % k) for k, (w, c) in enumerate(walls)
                 if not (label == 'mission' and k >= 9)])
    print(f'{label} eject with gravity: nearest {worst[1]} {worst[0] - L.ballRadius:.1f} pt beyond the ball edge')
path_clear_g(L.roverScoop, L.roverEject, 'rover', lambda n: False)
path_clear_g(L.missionScoop, L.missionEject, 'mission', lambda n: n.startswith('drop'))   # the eject clears the bank
