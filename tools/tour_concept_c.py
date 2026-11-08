"""Table 06, Concept C: the whole table patterned on Attack from Mars (the pure Williams fan). NOTHING in the middle
from the slings to the back of the table: the centre shot is an open channel between the two ramp entrances that runs
all the way to Mission Control at the back (AFM's saucer behind its forcefield drop; Medieval Madness's castle at ~79%).
Lower-middle: lamps only. Sketch for Aaron's OK before any code (7 Nov 2026, after v9's walled lane was rejected)."""
import math, sys
sys.path.insert(0, '.')
import tour_layout as L
import tour_layout_a as A
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Polygon, FancyBboxPatch, Wedge

fig, ax = plt.subplots(figsize=(7.5, 14))
ax.set_facecolor('#0b0f1e')
def poly(pts, c='#9fb4ff', lw=1.6, closed=False, ls='-'):
    pts = list(pts) + ([pts[0]] if closed else []); xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw, ls=ls)
for w in [L.outer_wall(), L.leftLaneGuide, L.rightLaneGuide, L.leftOutlaneWall, L.rightOutlaneWall,
          L.leftOutlanePostRail, L.rightOutlanePostRail]:
    poly(w)
poly(list(L.leftSling), c='#ff9a3c', closed=True); poly(list(L.rightSling), c='#ff9a3c', closed=True)
for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
    tip = L.flipper_tip(piv, side); ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=7, solid_capstyle='round')
ax.add_patch(Circle(L.rocketPost, L.rocketPostRadius, color='#ff4d4d'))
def face(c, deg, w=26, col='#7cc4ff', label=None):
    t = math.radians(deg); ux, uy = math.cos(t + math.pi / 2), math.sin(t + math.pi / 2)
    nx, ny = math.cos(t), math.sin(t)
    pts = [(c[0] - ux * w/2, c[1] - uy * w/2), (c[0] + ux * w/2, c[1] + uy * w/2),
           (c[0] + ux * w/2 - nx * 8, c[1] + uy * w/2 - ny * 8), (c[0] - ux * w/2 - nx * 8, c[1] - uy * w/2 - ny * 8)]
    ax.add_patch(Polygon(pts, fc=col, ec='w', lw=0.5))
    if label: ax.text(c[0] + nx * 14, c[1] + ny * 14, label, color='w', fontsize=6, ha='center', va='center')
def scoop(c, label): ax.add_patch(Circle(c, 14, fc='#111', ec='#ddd', lw=2)); ax.text(c[0] + 20, c[1], label, color='#ddd', fontsize=7, va='center')
def text(x, y, s, c='#ffd75c', fs=7, ha='center'): ax.text(x, y, s, color=c, fontsize=fs, ha=ha)

# --- what's already built (v8): R-O-C over the '/' on the left, Mars bunker on the right ---
poly(A.ROC_STRUCT)
for (p, a), lab in zip(A.roc_targets(), 'ROC'): face(p, a, label=lab)
poly(A.bunkerRoof); poly(A.bunkerFloor)
for i, (p, a) in enumerate(A.sample_targets()): face(p, a, 24, '#e86b4a', str(i + 1))
scoop(A.roverScoop, 'rover')

# --- the open middle: lamps only, slings to the back ---
ax.add_patch(Polygon([(150, 470), (418, 470), (418, 600), (150, 600)], fc='#2a7fff', alpha=0.08, lw=0))
ax.add_patch(Polygon([(214, 600), (354, 600), (354, 960), (214, 960)], fc='#2a7fff', alpha=0.08, lw=0))
text(284, 520, 'OPEN\nlamps + art only', '#8fb8ff', 8)
text(284, 780, 'open channel\nto the back', '#8fb8ff', 7)
ax.axhline(600, color='#ffd75c', lw=0.8, ls=':', xmin=0.05, xmax=0.9); text(60, 606, 'shot line', fs=6)

# --- the fan, left to right (shot entrances on the shot line, the centre runs to the back) ---
# left orbit: a lane along the left wall from above the R-O-C bank round the top
poly([(64, 900), (64, 1080)], c='#9fb4ff'); ax.add_patch(Wedge((284, 1030), 240, 90, 168, width=0, fc='none', ec='#9fb4ff', lw=1.6))
text(42, 880, 'L orbit\n(spinner)', fs=6)
# Moon ramp: entrance x 150-190 at the shot line, climbing up-left to the raised Moon over the bumpers
poly([(150, 600), (150, 700), (120, 820)], c='#5fd38a'); poly([(188, 600), (188, 700), (158, 820)], c='#5fd38a')
text(169, 585, 'MOON ramp', '#5fd38a', 6)
ax.add_patch(Circle((140, 1000), 70, fc='#4a5568', ec='#cbd5e0', lw=1.5, alpha=0.8)); text(140, 1000, 'raised MOON\n(lock, bumpers under)', '#e2e8f0', 6)
# wire ramp: entrance x 380-418 at the shot line, climbing up-right
poly([(380, 600), (380, 700), (410, 820)], c='#5fd38a'); poly([(418, 600), (418, 700), (448, 820)], c='#5fd38a')
text(399, 585, 'ASTEROID\nwire ramp', '#5fd38a', 6)
# right orbit above the Mars bunker along the right wall
poly([(504, 700), (504, 1080)], c='#9fb4ff'); ax.add_patch(Wedge((284, 1030), 240, 12, 90, width=0, fc='none', ec='#9fb4ff', lw=1.6))
text(526, 680, 'R orbit\n(spinner)', fs=6)
# Saturn loop: the upper flipper's shot, a ring through a raised Saturn on the right
ax.add_patch(Circle((430, 1000), 46, fc='#c9a86a', ec='#f6e3b4', lw=1.5, alpha=0.8)); text(430, 1000, 'SATURN\nloop', '#2d1b00', 6)
ax.plot([500, 470], [860, 880], color='w', lw=5, solid_capstyle='round'); text(486, 845, 'upper flipper', fs=6)

# --- Mission Control at the BACK of the centre channel (AFM: forcefield drop + saucer; MM: castle gate) ---
face((284, 968), -90, 28, '#ffb347', 'GATE')
scoop((284, 1004), 'MISSION\nCONTROL')
for i, (x, y) in enumerate([(218, 1030), (248, 1048), (284, 1056), (320, 1048), (350, 1030)]):
    face((x, y), -90 + (i - 2) * -14, 22, '#7cc4ff', '54321'[i])
text(284, 1090, 'countdown 5-4-3-2-1\n(standups round the saucer)', fs=6)
poly([(284, 1004), (284, 1004)]); ax.plot([284, 110], [1004, 490], color='#888', lw=1, ls=':'); text(130, 500, 'subway out\nto the left inlane', '#aaa', 6, ha='left')

# STAR lanes + bumpers top left, K-E-T in front of the bumpers
for i, x in enumerate([90, 125, 160, 195]):
    poly([(x - 14, 1150), (x - 14, 1200)], c='#9fb4ff'); text(x, 1210, 'STAR'[i], fs=7)
for c in [(110, 1095), (170, 1095), (140, 1050)]:
    ax.add_patch(Circle(c, 20, fc='#2d3748', ec='#f6ad55', lw=1.5, alpha=0.7))
for i, x in enumerate([190, 216, 242]): face((x, 930), -90, 22, '#7cc4ff', 'KET'[i])
text(216, 905, 'K-E-T', fs=6)

# shot arrows from the opposite flipper
for end, lab in [((40, 900), ''), ((169, 612), ''), ((284, 968), ''), ((399, 612), ''), ((526, 700), '')]:
    frm = (306, 200) if end[0] <= 284 else (262, 200)
    ax.annotate('', xy=end, xytext=frm, arrowprops=dict(arrowstyle='->', color='#ffd75c', lw=1, alpha=0.5))
ax.set_xlim(-10, 610); ax.set_ylim(60, 1290); ax.set_aspect('equal'); ax.set_xticks([]); ax.set_yticks([])
ax.set_title('Concept C · the AFM pattern: open middle, Mission Control at the BACK of the centre channel', fontsize=9)
fig.savefig(sys.argv[1], dpi=110, bbox_inches='tight')
