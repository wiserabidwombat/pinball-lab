import math, sys
sys.path.insert(0, '.')
import chomp_layout as C
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon

def seg_dist(p, a, b):
    ax_, ay = a; bx, by = b; px, py = p
    dx, dy = bx-ax_, by-ay; l2 = dx*dx+dy*dy
    t = 0 if l2 == 0 else max(0, min(1, ((px-ax_)*dx+(py-ay)*dy)/l2))
    return math.hypot(px-ax_-t*dx, py-ay-t*dy)
def poly_dist(p, pts): return min(seg_dist(p, pts[i], pts[i+1]) for i in range(len(pts)-1))

fig, ax = plt.subplots(figsize=(8, 11))
ax.set_facecolor('#0b0f1e')
def poly(pts, c='#9fb4ff', lw=2, ls='-'):
    xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw, ls=ls)
poly(C.outer_wall())
walls = [C.leftLaneGuide, *C.rightLaneGuideWithGate, C.leftOutlaneWall, C.rightOutlaneWall, C.leftOutlanePostRail,
         C.rightOutlanePostRail, C.rightApron, C.feedLaneInner, C.pocketFloor, C.pocketDeflector]
for w in walls: poly(w)
# one-way gate flap (swings into the inlane only)
poly([(C.saveGateX, C.saveGateTopY), (C.saveGateX - 22, C.saveGateTopY - 22)], c='#ffd75c', lw=2, ls='--')
ax.text(C.saveGateX - 6, C.saveGateTopY + 14, 'one-way gate', color='#ffd75c', fontsize=7, ha='right')
for s in [C.leftSling, C.rightSling]:
    poly(list(s) + [s[0]], c='#ff9a3c')
for piv, side in [(C.leftFlipperPivot, 'left'), (C.rightFlipperPivot, 'right')]:
    tip = C.flipper_tip(piv, side)
    ax.plot([piv[0], tip[0]], [piv[1], tip[1]], color='w', lw=8, solid_capstyle='round')
    up = C.flipper_tip(piv, side, raised=math.pi/3)
    ax.plot([piv[0], up[0]], [piv[1], up[1]], color='w', lw=2, ls=':')
# mini-flipper
mt = C.mini_tip(); mu = C.mini_tip(C.miniSwing)
ax.plot([C.miniPivot[0], mt[0]], [C.miniPivot[1], mt[1]], color='w', lw=6, solid_capstyle='round')
ax.plot([C.miniPivot[0], mu[0]], [C.miniPivot[1], mu[1]], color='w', lw=2, ls=':')
ax.text(C.miniPivot[0] + 4, C.miniPivot[1] - 34, 'pier\nmini-flipper', color='w', fontsize=7, ha='center')
# shot fan from the mini-flipper (rough: launch 100..155 deg from 2/3 along the blade at rest)
cp = (C.miniPivot[0] + (mt[0]-C.miniPivot[0])*0.66, C.miniPivot[1] + (mt[1]-C.miniPivot[1])*0.66)
for a in [100, 115, 130, 145, 155]:
    r = math.radians(a); ax.plot([cp[0], cp[0] + 520*math.cos(r)], [cp[1], cp[1] + 520*math.sin(r)], color='#5cf', lw=0.8, ls=':')
ax.add_patch(Circle(C.harpoonLaneMouth, 10, fill=False, ec='#f6f', lw=1.5)); ax.text(C.harpoonLaneMouth[0]+14, C.harpoonLaneMouth[1], 'harpoon lane (M2)', color='#f6f', fontsize=7)
ax.add_patch(Circle(C.leftBankCenter, 10, fill=False, ec='#f6f', lw=1.5)); ax.text(C.leftBankCenter[0]+14, C.leftBankCenter[1], 'Fish Phone bank (M2)', color='#f6f', fontsize=7)
# parts
for p in [C.leftUpPost, C.rightUpPost]:
    ax.add_patch(Circle(p, C.upPostRadius, color='#ff4d4d'))
ax.text(C.leftUpPost[0]+8, C.leftUpPost[1]+8, 'up-post', color='#ff8080', fontsize=7)
ax.add_patch(Circle(C.outlaneSavePost, C.outlaneSavePostRadius, color='#ff9a3c'))
ax.text(C.outlaneSavePost[0]-8, C.outlaneSavePost[1]+12, 'save post', color='#ffb070', fontsize=7, ha='right')
ax.add_patch(Circle(C.innerTubeLamp, 7, color='#7f7')); ax.text(C.innerTubeLamp[0]+10, C.innerTubeLamp[1]-14, 'inner tube', color='#7f7', fontsize=7)
ax.add_patch(Circle(C.bumperCenter, C.bumperRadius, color='#e33', alpha=0.85)); ax.text(*C.bumperCenter, 'bumper', color='w', fontsize=7, ha='center', va='center')
(bc, bn) = C.buoyTarget; a = math.radians(bn); tx, ty = -math.sin(a), math.cos(a)
ax.plot([bc[0]-13*tx, bc[0]+13*tx], [bc[1]-13*ty, bc[1]+13*ty], color='#ffd75c', lw=5); ax.text(bc[0]-24, bc[1]-14, 'buoy', color='#ffd75c', fontsize=7)
ax.add_patch(Rectangle((C.miniLaneSensor[0]-12, C.miniLaneSensor[1]-5), 24, 10, color='#5cf')); ax.text(C.miniLaneSensor[0], C.miniLaneSensor[1]+12, 'mini-lane', color='#5cf', fontsize=7, ha='center')
for x in C.laneRolloverXs:
    w, h = C.laneSensorSize; ax.add_patch(Rectangle((x - w/2, C.laneRolloverY - h/2), w, h, color='#5cf'))
ax.set_xlim(-10, 610); ax.set_ylim(40, 900); ax.set_aspect('equal')
ax.set_title('Table 07 CHOMP! M1 v1: lower table (grey box)', color='k')
fig.savefig('build/chomp_m1_lower.png', dpi=110, bbox_inches='tight')

# ---- gap checks (ball diameter 18: passages >= 27, closed gaps < 18)
D = 2 * C.ballRadius
def report(name, gap, kind):
    ok = gap >= 27 if kind == 'pass' else gap < D
    print(f"{'OK ' if ok else 'BAD'} {name}: {gap:.1f} pt ({kind})")
lt = C.flipper_tip(C.leftFlipperPivot, 'left'); rt = C.flipper_tip(C.rightFlipperPivot, 'right')
print('main tip gap (drain)', round(math.dist(lt, rt) - 2*C.flipperTipRadius, 1))
# up-posts: gaps to the guide leg and the sling edge (closed: ball rests on the post)
for name, p, guide, sling in [('left', C.leftUpPost, C.leftLaneGuide, C.leftSling), ('right', C.rightUpPost, C.rightLaneGuide, C.rightSling)]:
    g = poly_dist(p, guide[1:]) - C.upPostRadius; s = seg_dist(p, sling[1], sling[2]) - C.upPostRadius
    report(f'{name} up-post to lane guide', g, 'closed'); report(f'{name} up-post to sling', s, 'closed')
    report(f'{name} inlane width (guide to sling)', g + s + 2*C.upPostRadius, 'pass')
# save post: gap toward the guide must pass, to the outer wall closed
report('save post to right lane guide', C.outlaneSavePost[0] - C.outlaneSavePostRadius - C.saveGateX, 'pass')
report('save post to outer wall', C.laneWallX - C.outlaneSavePost[0] - C.outlaneSavePostRadius, 'closed')
report('save gate opening', C.saveGateTopY - C.saveGateBottomY, 'pass')
report('feed lane width', C.laneWallX - C.feedLaneInnerX, 'pass')
up = C.mini_tip(C.miniSwing)
def mini_top_y(x, raised):
    t = C.mini_tip(raised); px, py = C.miniPivot
    return py + (t[1]-py) * (px - x) / (px - t[0])
report('feed wall end over raised mini-flipper', C.feedLaneInner[-1][1] - (mini_top_y(C.feedLaneInnerX, C.miniSwing) + C.miniPivotRadius), 'pass')
report('bumper to feed lane wall', C.feedLaneInnerX - C.bumperCenter[0] - C.bumperRadius, 'pass')
report('bumper to buoy', math.dist(C.bumperCenter, C.buoyTarget[0]) - C.bumperRadius - 4, 'pass')
report('raised mini tip to buoy', math.dist(up, C.buoyTarget[0]) - C.miniTipRadius - 4, 'pass')
report('mini tip (rest) to right sling top', math.dist(C.mini_tip(), C.rightSling[0]) - C.miniTipRadius, 'pass')

report('pivot to outer wall', C.laneWallX - C.miniPivot[0] - C.miniPivotRadius, 'closed')
print('mini tips: rest', [round(v,1) for v in C.mini_tip()], 'raised', [round(v,1) for v in up])
print('up-posts', [round(v,1) for v in C.leftUpPost], [round(v,1) for v in C.rightUpPost])
