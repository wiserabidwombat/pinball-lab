"""Table 06 layout concepts after the classics: zones, shot fan and part placement (sketch, not measured)."""
import math, sys
sys.path.insert(0, '.')
import tour_layout as L
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon, FancyBboxPatch

FLIP_Y, TOP = 170, 1270
SHOT_LINE = 820          # ~59 % of the way from the flippers to the top: where the shot entrances start

def base(ax, title):
    ax.set_facecolor('#0b0f1e')
    def poly(pts, c='#9fb4ff', lw=1.6, closed=False):
        pts = list(pts) + ([pts[0]] if closed else []); xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw)
    for w in [L.outer_wall(), L.leftLaneGuide, L.rightLaneGuide, L.leftOutlaneWall, L.rightOutlaneWall,
              L.leftOutlanePostRail, L.rightOutlanePostRail]:
        poly(w)
    poly(list(L.leftSling), c='#ff9a3c', closed=True); poly(list(L.rightSling), c='#ff9a3c', closed=True)
    for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
        tip = L.flipper_tip(piv, side)
        ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=7, solid_capstyle='round')
    # zones
    ax.add_patch(Rectangle((22, 470), 524, SHOT_LINE - 470, color='#2a7fff', alpha=0.10, lw=0))
    ax.text(284, 700, 'OPEN ZONE\ninserts + art only', color='#8fb8ff', ha='center', fontsize=9, alpha=0.9)
    ax.axhline(SHOT_LINE, color='#ffd75c', lw=1, ls=':', xmin=0.04, xmax=0.9)
    ax.text(30, SHOT_LINE + 6, 'shot line', color='#ffd75c', fontsize=7)
    ax.set_xlim(-10, 610); ax.set_ylim(80, 1290); ax.set_aspect('equal'); ax.set_xticks([]); ax.set_yticks([])
    ax.set_title(title, color='k', fontsize=11)

def shot(ax, end, label, frm=None, col='#ffd75c'):
    """An arrow from the flipper that makes it (crossing shots) to the shot's entrance."""
    if frm is None: frm = (306, 200) if end[0] < 284 else (262, 200)
    ax.annotate('', xy=end, xytext=frm, arrowprops=dict(arrowstyle='->', color=col, lw=1.3, alpha=0.75))
    ax.text(end[0], end[1] + 14, label, color=col, fontsize=7, ha='center')
    # the arrow insert stack under the shot (3 lamps) in the open zone, on the line to the flipper
    for k in range(3):
        t = 0.62 - k * 0.07
        p = (frm[0] + (end[0] - frm[0]) * t, frm[1] + (end[1] - frm[1]) * t)
        ax.add_patch(Circle(p, 5, color=col, alpha=0.55))

def lane(ax, x0, x1, y0, y1, c='#9fb4ff'):
    ax.plot([x0, x0], [y0, y1], color=c, lw=1.6); ax.plot([x1, x1], [y0, y1], color=c, lw=1.6)

def box(ax, xy, w, h, c, label, fs=7, alpha=0.85):
    ax.add_patch(FancyBboxPatch(xy, w, h, boxstyle='round,pad=2', fc=c, ec='w', lw=0.6, alpha=alpha))
    ax.text(xy[0] + w / 2, xy[1] + h / 2, label, color='w', fontsize=fs, ha='center', va='center')

def planet_arc(ax):
    for i in range(9):
        a = math.radians(160 - i * 17.5); c = (284 + 150 * math.cos(a), 470 + 150 * math.sin(a))
        ax.add_patch(Circle(c, 9, fc='#b48cff', alpha=0.6))

fig, axs = plt.subplots(1, 2, figsize=(13, 13))
# --- Concept A: the Grand Fan (Attack from Mars / Medieval Madness) ---
ax = axs[0]; base(ax, 'A · The Grand Fan  (AFM / Medieval Madness)')
planet_arc(ax)
lane(ax, 22, 64, SHOT_LINE, 1150)                       # left orbit
box(ax, (26, 900), 34, 10, '#7cf', 'spin', 6)
box(ax, (98, 860), 44, 70, '#5a7', 'MOON\nramp', 7)    # Moon ramp entrance
box(ax, (40, 1120), 140, 110, '#556', 'raised Moon\n(lock, mini flipper)', 7, 0.7)
box(ax, (166, 880), 38, 60, '#c96', 'Saturn\nloop', 6)
ax.add_patch(Circle((185, 1010), 34, fc='#c9a26a', alpha=0.6)); ax.text(185, 1010, 'Saturn', color='w', fontsize=7, ha='center')
for i in range(5): box(ax, (230 + i * 22, 930), 18, 6, '#ffb347', '', 5)   # countdown bank at the top centre
ax.text(284, 915, '5 4 3 2 1', color='#ffb347', fontsize=7, ha='center')
ax.add_patch(Circle((284, 1000), 14, fc='#111', ec='#ccc')); ax.text(284, 1022, 'Mission\nControl', color='#ccc', fontsize=7, ha='center')
for i in range(3): box(ax, (214, 860 - i * 0 + i * 0, ), 0, 0, '#000', '')    # (spacer)
for i, (x, y) in enumerate([(214, 890), (214, 925), (214, 960)]): box(ax, (x - 4, y), 8, 24, '#4aa', 'ROC'[i], 6)
for i, (x, y) in enumerate([(350, 890), (350, 925), (350, 960)]): box(ax, (x - 4, y), 8, 24, '#4aa', 'KET'[i], 6)
box(ax, (378, 860), 40, 70, '#5a7', 'wire\nramp', 7)
lane(ax, 440, 480, SHOT_LINE + 40, 1020)
for i in range(3): box(ax, (444, 900 + i * 30), 32, 6, '#e86a4a', '', 5)
ax.text(460, 1030, 'asteroids\n→ wormhole', color='#e86a4a', fontsize=6, ha='center')
lane(ax, 504, 546, SHOT_LINE, 1150)                     # right orbit
box(ax, (508, 900), 34, 10, '#7cf', 'spin', 6)
for c in [(370, 1150), (430, 1190), (440, 1110)]: ax.add_patch(Circle(c, 22, fc='#d55', alpha=0.7))
ax.text(400, 1240, 'S T A R  lanes', color='#ddd', fontsize=7, ha='center')
ax.plot([546, 520], [800, 830], color='w', lw=5); ax.text(500, 790, 'upper\nflipper', color='w', fontsize=6)
for i in range(3): box(ax, (66 + i * 2, 740 + i * 26), 6, 20, '#e86a4a', '', 5)
ax.text(100, 760, 'samples', color='#e86a4a', fontsize=6)
ax.add_patch(Circle((80, 830), 11, fc='#111', ec='#ccc')); ax.text(100, 838, 'rover', color='#ccc', fontsize=6)
shot(ax, (43, 860), 'L orbit'); shot(ax, (120, 900), 'Moon'); shot(ax, (185, 900), 'Saturn')
shot(ax, (284, 920), 'centre', frm=(284, 190), col='#ffb347'); shot(ax, (398, 900), 'wire')
shot(ax, (460, 880), 'asteroids'); shot(ax, (525, 860), 'R orbit')

# --- Concept B: the Centrepiece (Medieval Madness castle / Godzilla building) ---
ax = axs[1]; base(ax, 'B · The Centrepiece Moon  (MM castle / Godzilla)')
planet_arc(ax)
lane(ax, 22, 64, SHOT_LINE, 1150); box(ax, (26, 900), 34, 10, '#7cf', 'spin', 6)
lane(ax, 504, 546, SHOT_LINE, 1150); box(ax, (508, 900), 34, 10, '#7cf', 'spin', 6)
box(ax, (200, 1000), 168, 170, '#556', 'the MOON\n(raised centrepiece:\nlock, craters,\nmini flipper)', 8, 0.75)
for i in range(5): box(ax, (230 + i * 22, 940), 18, 6, '#ffb347', '', 5)
ax.text(284, 925, 'countdown gantry 5-4-3-2-1', color='#ffb347', fontsize=6, ha='center')
ax.add_patch(Circle((284, 975), 13, fc='#111', ec='#ccc')); ax.text(330, 970, 'launch\npad', color='#ccc', fontsize=6)
box(ax, (96, 860), 44, 70, '#5a7', 'Moon\nramp L', 7); box(ax, (428, 860), 44, 70, '#5a7', 'Moon\nramp R', 7)
box(ax, (160, 870), 34, 60, '#c96', 'Saturn\nloop', 6)
ax.add_patch(Circle((120, 1060), 34, fc='#c9a26a', alpha=0.6)); ax.text(120, 1060, 'Saturn', color='w', fontsize=7, ha='center')
for i in range(3): box(ax, (380 + i * 0, 880 + i * 30), 30, 6, '#e86a4a', '', 5)
ax.text(395, 860, 'asteroids', color='#e86a4a', fontsize=6, ha='center')
for c in [(440, 1150), (490, 1200), (480, 1100)]: ax.add_patch(Circle(c, 20, fc='#d55', alpha=0.7))
for i, (x, y) in enumerate([(200, 860), (222, 860), (244, 860)]): box(ax, (x, y - 6), 18, 8, '#4aa', 'ROC'[i], 6)
for i, (x, y) in enumerate([(324, 860), (346, 860), (368, 860)]): box(ax, (x - 18, y - 6), 18, 8, '#4aa', 'KET'[i], 6)
ax.plot([546, 520], [800, 830], color='w', lw=5)
shot(ax, (43, 860), 'L orbit'); shot(ax, (118, 900), 'Moon L'); shot(ax, (177, 900), 'Saturn')
shot(ax, (284, 930), 'launch pad', frm=(284, 190), col='#ffb347'); shot(ax, (395, 890), 'asteroids')
shot(ax, (450, 900), 'Moon R'); shot(ax, (525, 860), 'R orbit')
fig.tight_layout()
fig.savefig(sys.argv[1], dpi=100, bbox_inches='tight')
