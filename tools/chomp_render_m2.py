"""Table 07 M2 v1 render: the left side over the Jaws Pro top-down drawing (if present), with gap checks."""
import math, sys, os
sys.path.insert(0, '.')
import chomp_layout as C
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
from PIL import Image

def seg_dist(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]; l2 = dx*dx+dy*dy
    t = 0 if l2 == 0 else max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/l2))
    return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)
def poly_dist(p, pts): return min(seg_dist(p, pts[i], pts[i+1]) for i in range(len(pts)-1))

XL, YL = eval(sys.argv[2]) if len(sys.argv) > 2 else ((-20, 640), (380, 1300))
fig, ax = plt.subplots(figsize=(9 * (XL[1]-XL[0]) / 660, 9 * (YL[1]-YL[0]) / 660))
ref = 'build/jaws_ref/p40-000.jpg'
if os.path.exists(ref):
    im = Image.open(ref); w, h = im.size; S, OX, OY = 1.355, 227.5, 870
    ax.imshow(im, extent=(284 - OX*S, 284 + (w-OX)*S, 220 + (OY-h)*S, 220 + OY*S), alpha=0.45)
def poly(pts, c='#0033cc', lw=2.2, ls='-'):
    xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw, ls=ls)
poly(C.outer_wall())
for w in [C.leftLaneGuide, *C.rightLaneGuideWithGate, C.leftOutlaneWall, C.rightOutlaneWall, C.leftOutlanePostRail,
          C.rightOutlanePostRail, C.rightApron, C.pierPlastic,
          C.harpoonInner, C.tongue, C.loopRight, C.harpoonDeflector, C.bankBackboard]:
    poly(w)
poly(list(C.quickshotGate), c='#ff7a00', ls='--')
for s in [C.leftSling, C.rightSling]: poly(list(s) + [s[0]], c='#ff3333')
for piv, side in [(C.leftFlipperPivot, 'left'), (C.rightFlipperPivot, 'right')]:
    t = C.flipper_tip(piv, side); ax.plot([piv[0], t[0]], [piv[1], t[1]], color='#cc00cc', lw=5)
mt = C.mini_tip(); ax.plot([C.miniPivot[0], mt[0]], [C.miniPivot[1], mt[1]], color='#cc00cc', lw=4)
ax.add_patch(plt.Circle(C.bumperCenter, C.bumperRadius, color='#ff8070'))
poly(list(C.spinnerLine), c='#d4a017', lw=4); ax.text(150, 955, 'spinner', fontsize=7)
poly(list(C.loopEntranceSwitch), c='#00aacc', lw=2)
for i, p in enumerate(C.quickshotSwitches):
    ax.add_patch(plt.Rectangle((p[0]-12, p[1]-5), 24, 10, color='#00aacc'))
n = math.radians(C.bankNormal); tg = (-math.sin(n), math.cos(n))
for c in C.bankCenters:
    ax.plot([c[0]-13*tg[0], c[0]+13*tg[0]], [c[1]-13*tg[1], c[1]+13*tg[1]], color='#ffcc00', lw=6, solid_capstyle='butt')
# shot lines: right flipper -> loop mouth, pier flipper -> quickshot gate
for a, b, col in [((330, 255), (123, 900), '#008800'), ((500, 585), (60, 880), '#008800')]:
    ax.annotate('', xy=b, xytext=a, arrowprops=dict(arrowstyle='->', color=col, lw=1.5, ls=':'))
# M2 v5: the wave ramp: rails (purple dashed = up on the ramp), the low end's floor-solid U (blue), switches
_w = lambda s: C.waveMouthHalfWidth + (C.waveHalfWidth - C.waveMouthHalfWidth) * min(s / C.waveFlareLength, 1)
WL, WR = C.WP.rails(_w)
poly(WL, c='#9933cc', lw=1.6, ls='--'); poly(WR, c='#9933cc', lw=1.6, ls='--')
_low = [i for i, d in enumerate(C.WP.dist) if d < C.waveLowLength]
_bp, _bh = C.WP.at(C.waveLowLength); _bw = _w(C.waveLowLength)
waveU = [WL[i] for i in _low] + [(_bp[0] - _bw*math.sin(_bh), _bp[1] + _bw*math.cos(_bh)), (_bp[0] + _bw*math.sin(_bh), _bp[1] - _bw*math.cos(_bh))] + [WR[i] for i in reversed(_low)]
poly(waveU)
_ap = C.WP.at(C.waveApexDistance)[0]; ax.plot(*_ap, 'o', color='#9933cc'); ax.text(_ap[0]+5, _ap[1]-18, 'made', fontsize=7)
ax.annotate('', xy=(172, 900), xytext=(370, 255), arrowprops=dict(arrowstyle='->', color='#008800', lw=1.5, ls=':'))
ax.set_xlim(*XL); ax.set_ylim(*YL); ax.set_aspect('equal')
ax.set_title('Table 07 CHOMP! M2 v1: left side over the reference drawing (p.40)', fontsize=9)
fig.savefig(sys.argv[1] if len(sys.argv) > 1 else 'build/chomp_m2_left.png', dpi=110, bbox_inches='tight')

D = 2 * C.ballRadius
def report(name, gap, kind):
    ok = gap >= 1.5 * D if kind == 'pass' else gap >= 1.2 * D if kind == 'lane' else gap < D
    print(f"{'OK ' if ok else 'BAD'} {name}: {gap:.1f} pt ({kind})")
arch = [p for p in C.outer_wall() if p[0] < 300 and p[1] >= 1000]
for y in [940, 1000, 1030, 1050]:
    ax_ = C._arch_point_at_x  # noqa
    xs = [p for p in arch]
    # arch x at height y (y = 1000 + 270(1-(1-t)^2))
    t = 1 - math.sqrt(max(0, 1 - (y - 1000) / 270)); x_arch = 20 + 280 * t * t if y >= 1000 else 20
    report(f'harpoon lane width at y {y}', C.harpoonX - x_arch, 'lane')
top = (80, 1060)
report('tongue top to the arch', poly_dist(top, arch) , 'pass')
report('loop channel width', 147 - 100, 'lane')
report('harpoon inner wall end to its deflector', seg_dist(C.harpoonInner[0], *C.harpoonDeflector), 'lane')
report('deflector end to the left outlane post rail tip', math.dist(C.harpoonDeflector[1], C.leftOutlanePostRail[1]), 'pass')
report('deflector end to the left sling top', math.dist(C.harpoonDeflector[1], C.leftSling[0]), 'pass')
report('quickshot gate opening', C.quickshotGate[1][1] - C.quickshotGate[0][1], 'pass')
report('bank backboard start to the harpoon wall', C.bankBackboard[0][0] - C.harpoonX if C.bankBackboard[0][0] > C.harpoonX else 0, 'closed')
report('loop mouth (shared post to tongue corner)', math.dist(C.loopRight[0], (100, 920)), 'pass')
report('wave ramp U left side to the loop wall (closed)', min(abs(p[0] - 147) for p in waveU[:len(_low)]), 'closed')
report('wave ramp mouth width', 2 * C.waveMouthHalfWidth, 'pass')
report('wave ramp channel width', 2 * C.waveHalfWidth, 'lane')
_ow = C.outer_wall()
print('wave rails: closest to the outer wall %.1f pt, rightmost x %.1f (lane wall 548)' % (min(poly_dist(q, _ow) for q in WL + WR if q[1] > 700), max(q[0] for q in WL + WR)))
# pier flipper (M2 v2)
mt, mu = C.mini_tip(), C.mini_tip(C.miniSwing)
ax.plot([C.miniPivot[0], mu[0]], [C.miniPivot[1], mu[1]], color='#cc00cc', lw=1.5, ls=':')
fig.savefig(sys.argv[1] if len(sys.argv) > 1 else 'build/chomp_m2_left.png', dpi=110, bbox_inches='tight')
for q in [(528, 530), (522, 548), (503, 547)]:
    report(f'pivot cap to the plastic at {q}', math.dist(C.miniPivot, q) - C.miniPivotRadius, 'closed')
report("pier tip (rest) to the right lane guide top (the right outlane's way in)", poly_dist(mt, C.rightOutlanePostRail) - C.miniTipRadius, 'pass')
report('pier tip (rest) to the right sling top post', math.dist(mt, C.rightSling[0]) - C.miniTipRadius - 7, 'pass')
report('plastic bottom over the outlane post rail tip', 470 - C.rightOutlanePostRail[1][1], 'pass')
# lower table (M2 v3)
for name, post, guide, sling in [('left', C.leftUpPost, C.leftLaneGuide, C.leftSling), ('right', C.rightUpPost, C.rightLaneGuide, C.rightSling)]:
    report(f'{name} up-post to the guide', poly_dist(post, guide[1:]) - C.upPostRadius, 'closed')
    report(f'{name} up-post to the sling bottom edge', seg_dist(post, sling[1], sling[2]) - C.upPostRadius, 'closed')
report('left inlane width (guide to sling corner side)', C.leftSling[1][0] - C.laneGuideX, 'lane')
report('left outlane width', C.laneGuideX - 20, 'lane')
report('right save gate opening', C.saveGateTop - C.saveGateBottom, 'lane')
lt0 = C.flipper_tip(C.leftFlipperPivot, 'left'); rt0 = C.flipper_tip(C.rightFlipperPivot, 'right')
report('flipper tip gap (centre drain)', math.dist(lt0, rt0) - 2 * C.flipperTipRadius, 'lane')
report('shooter lane width', C.rightWallX - C.laneWallX, 'closed' if False else 'lane')
report('harpoon inner wall end to its deflector', seg_dist(C.harpoonInner[0], *C.harpoonDeflector), 'lane')
report('harpoon deflector end to the left sling top', math.dist(C.harpoonDeflector[1], C.leftSling[0]), 'pass')
report('harpoon deflector end to the left lane guide top', math.dist(C.harpoonDeflector[1], C.leftLaneGuide[0]), 'pass')
report('right save post to the lane guide', C.outlaneSavePost[0] - C.outlaneSavePostRadius - C.saveGateX, 'pass')
lt = C.flipper_tip(C.leftFlipperPivot, 'left', raised=math.pi/3)
for name, post in [('left', C.leftUpPost)]:
    d = min(seg_dist(post, C.leftFlipperPivot, C.flipper_tip(C.leftFlipperPivot, 'left', raised=math.radians(k))) for k in range(0, 61, 5))
    report(f'{name} up-post clear of the swinging flipper', d - C.upPostRadius - 12, 'pass')
report('raised pier tip to the buoy', math.dist(mu, C.buoyTarget[0]) - C.miniTipRadius - 4, 'pass')
print('pier tips: rest', [round(v, 1) for v in mt], 'raised', [round(v, 1) for v in mu])
print('loop right wall meets the arch at', [round(v, 1) for v in C.loopRight[-1]])
