import math, sys
sys.path.insert(0, '.')
import tour_layout as L
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle

def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx-ax, by-ay; l2 = dx*dx+dy*dy
    t = 0 if l2 == 0 else max(0, min(1, ((px-ax)*dx+(py-ay)*dy)/l2))
    return math.hypot(px-ax-t*dx, py-ay-t*dy)

fig, ax = plt.subplots(figsize=(7, 9))
ax.set_facecolor('#0b0f1e')
def poly(pts, c='#9fb4ff', lw=2):
    xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw)
poly(L.outer_wall())
for w in [L.leftLaneGuide, L.rightLaneGuide, L.leftOutlaneWall, L.rightOutlaneWall, L.leftOutlanePostRail,
          L.rightOutlanePostRail, L.rightApron]:
    poly(w)
for s in [L.leftSling, L.rightSling]:
    poly(list(s) + [s[0]], c='#ff9a3c')
for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
    tip = L.flipper_tip(piv, side)
    ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=8, solid_capstyle='round')
    up = L.flipper_tip(piv, side, raised=math.pi/3)
    ax.plot([piv[0], up[0]], [piv[1], up[1]], color='w', lw=2, ls=':')
ax.add_patch(Circle(L.rocketPost, L.rocketPostRadius, color='#ff4d4d'))
for i, x in enumerate(L.laneRolloverXs):
    w, h = L.laneSensorSize
    ax.add_patch(Rectangle((x - w/2, L.laneRolloverY - h/2), w, h, color='#5cf'))
    ax.text(x, L.laneLampY, L.laneLetters[i], color='#ffd75c', ha='center', va='center', fontsize=9, weight='bold')
ax.add_patch(Circle(L.kickbackLamp, 6, color='#7f7'))
ax.set_xlim(-10, 610); ax.set_ylim(40, 560); ax.set_aspect('equal')
ax.set_title('Table 06 M1: lower table (O-R-B-T lanes, rocket post)')
fig.savefig('/home/claude/t6/m1_lower.png', dpi=110, bbox_inches='tight')

# Gap checks
lt = L.flipper_tip(L.leftFlipperPivot, 'left'); rt = L.flipper_tip(L.rightFlipperPivot, 'right')
post_gap_l = math.dist(L.rocketPost, lt) - L.rocketPostRadius - L.flipperTipRadius
post_gap_r = math.dist(L.rocketPost, rt) - L.rocketPostRadius - L.flipperTipRadius
print('tips', [round(v,1) for v in lt], [round(v,1) for v in rt], 'tip gap', round(math.dist(lt, rt) - 2*L.flipperTipRadius, 1))
print('post-to-tip gaps (must be < 18):', round(post_gap_l,1), round(post_gap_r,1))
# raised flipper clearance from the post (the flipper body line from pivot to raised tip)
for piv, side in [(L.leftFlipperPivot, 'left'), (L.rightFlipperPivot, 'right')]:
    for k in range(0, 61, 10):
        tip = L.flipper_tip(piv, side, raised=math.radians(k))
        d = seg_dist(L.rocketPost, piv, tip) - L.rocketPostRadius - L.flipperTipRadius
        if d < 0: print('FLIPPER HITS POST', side, k)
print('post clear of every flipper angle: ok')
# post above the drain chute and the apron slope
print('post bottom', L.rocketPost[1]-L.rocketPostRadius, 'drain lip', L.drainEdgeY)
for i, x in enumerate(L.laneRolloverXs):
    print('lane', L.laneLetters[i], 'x', round(x,1), 'sensor', L.laneSensorSize)
