"""Table 07 (CHOMP!) M4 render: the whole table as built (chomp_layout.py, caught up to M4 v5) over the Jaws Pro top
view (p. 40), plus gap checks on every passage and pocket. Run from the repo root:
    python3 tools/chomp_render_m4.py [out.png] ["((x0, x1), (y0, y1))"]
Rules (D = the ball's diameter, 30): a passage the ball uses must be >= 1.5 D ('pass') or >= 1.2 D for a lane
('lane'); a gap it must never enter < D ('closed'). 'info' lines just report a number."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chomp_layout as C
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else 'build/chomp_m4.png'
XL, YL = eval(sys.argv[2]) if len(sys.argv) > 2 else ((-10, 610), (0, 1360))
D = 2 * C.ballRadius

def seg_dist(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]; l2 = dx * dx + dy * dy
    t = 0 if l2 == 0 else max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)
def dense(pts, step=1.0):
    outp = []
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.dist(a, b) / step))
        outp += [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n)]
    return outp + [pts[-1]]
def poly_dist(p, pts): return min(seg_dist(p, pts[i], pts[i + 1]) for i in range(len(pts) - 1))
def gap(A, B): return min(poly_dist(p, B) for p in dense(A))
def circle_gap(c, r, pts): return poly_dist(c, pts) - r

fig, ax = plt.subplots(figsize=(9 * (XL[1] - XL[0]) / 660, 9 * (YL[1] - YL[0]) / 660))
ref = 'build/jaws_ref/p40-000.jpg'
if os.path.exists(ref):
    im = Image.open(ref); w, h = im.size; S, OX, OY = 1.355, 227.5, 870
    ax.imshow(im, extent=(284 - OX * S, 284 + (w - OX) * S, 220 + (OY - h) * S, 220 + OY * S), alpha=0.45)
def poly(pts, c='#0033cc', lw=1.8, ls='-'):
    xs, ys = zip(*pts); ax.plot(xs, ys, color=c, lw=lw, ls=ls)
def solid(pts, c='#3355ff'):
    ax.fill([p[0] for p in pts], [p[1] for p in pts], color=c, alpha=0.35); poly(pts, c=c)
def circ(c, r, col='#0033cc', a=1.0): ax.add_patch(plt.Circle(c, r, color=col, alpha=a))

ow = C.outer_wall()
ax.add_patch(plt.Rectangle((C.leftWallX, 40), C.laneTopOuterX - C.leftWallX, C.topEdgeY - 40, fill=False, ec='#777', lw=1, ls=':'))
poly(ow, lw=2.4)
for wl in [C.leftLaneGuide, C.rightLaneGuide, C.leftOutlaneWall, C.rightOutlaneWall, C.leftOutlanePostRail,
           C.rightOutlanePostRail, C.rightApron, C.harpoonInner, C.harpoonDeflector, C.bankBackboard, C.waveLaneLeft,
           C.centerJamb, C.centerFunnel]:
    poly(wl)
for sp in [C.pierPlastic, C.tongue, C.loopRight, C.waveRightBlock, C.rampIsland, C.bankWedge, C.boatHousing + [C.boatHousing[0]],
           C.reelLeftBlock, C.reelRightBlock, C.barrelEnd] + C.sharkBacks:
    solid(sp)
poly(list(C.quickshotGate), c='#ff7a00', ls='--')
for s in [C.leftSling, C.rightSling]: poly(list(s) + [s[0]], c='#ff3333')
for piv, side in [(C.leftFlipperPivot, 'left'), (C.rightFlipperPivot, 'right')]:
    t = C.flipper_tip(piv, side); ax.plot([piv[0], t[0]], [piv[1], t[1]], color='#cc00cc', lw=5)
mt = C.mini_tip(); ax.plot([C.miniPivot[0], mt[0]], [C.miniPivot[1], mt[1]], color='#cc00cc', lw=4)
circ(C.bumperCenter, C.bumperRadius, '#ff8070'); circ(C.plungePin, C.plungePinRadius, '#ffcc00')
circ(C.centerPost, C.centerPostRadius); circ(C.chumBucketCentre, C.chumBucketRadius, '#999999', 0.8)
for k in (-C.boatHalfWidth, C.boatHalfWidth): circ((C.boatMouth[0] + k, C.boatMouth[1]), C.boatPostRadius)
poly(C.boatLip, c='#888888', lw=1.5)
circ(C.reelCentre, C.reelDiscRadius, '#2244aa', 0.2)
for i in range(3):
    a, b = C.shark_target_face(i); ax.plot([a[0], b[0]], [a[1], b[1]], color='#ffcc00', lw=5, solid_capstyle='butt')
n = math.radians(C.bankNormal); tg = (-math.sin(n), math.cos(n))
for c in C.bankCenters: ax.plot([c[0] - 13 * tg[0], c[0] + 13 * tg[0]], [c[1] - 13 * tg[1], c[1] + 13 * tg[1]], color='#ffcc00', lw=5, solid_capstyle='butt')
(bx, by), bh = C.buoyTarget; bt = math.radians(bh + 90)
ax.plot([bx - 13 * math.cos(bt), bx + 13 * math.cos(bt)], [by - 13 * math.sin(bt), by + 13 * math.sin(bt)], color='#00cccc', lw=5)
poly(C.finSlot, c='#ffffff', lw=3); poly(C.finSlot, c='#888888', lw=1)
for s in (C.finMinS, C.finMaxS):
    (fx, fy), fh = C.fin_at(s); L = C.finLength / 2
    ax.plot([fx - L * math.cos(fh), fx + L * math.cos(fh)], [fy - L * math.sin(fh), fy + L * math.sin(fh)], color='#555', lw=4)
for seg, col in [(C.spinnerLine, '#d4a017'), (C.loopEntranceSwitch, '#00aacc'), (C.reelSwitch, '#00aacc')]: poly(list(seg), c=col, lw=2)
ax.add_patch(plt.Rectangle((C.miniLaneSensor[0] - 18, C.miniLaneSensor[1] - 5), 36, 10, color='#00aacc'))
for P, half, col in [(C.WP, lambda s: C.waveMouthHalfWidth, '#9933cc'), (C.CP, lambda s: C.centerMouthHalfWidth + (C.centerHalfWidth - C.centerMouthHalfWidth) * min(s / C.centerFlareLength, 1), '#cc6600'),
                     (C.RP, lambda s: C.rightMouthHalfWidth, '#00aa44')]:
    L_, R_ = P.rails(half); poly(L_, c=col, lw=1.2, ls='--'); poly(R_, c=col, lw=1.2, ls='--')
ax.set_xlim(*XL); ax.set_ylim(*YL); ax.set_aspect('equal')
ax.set_title('Table 07 CHOMP! as built (M4 v5) over the reference drawing (p. 40)', fontsize=9)
os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
fig.savefig(out, dpi=110, bbox_inches='tight')

# ---------------------------------------------------------------------------------------------------- checks
bad = 0
def report(name, g, kind):
    global bad
    ok = {'pass': g >= 1.5 * D, 'lane': g >= 1.2 * D, 'closed': g < D, 'info': True}[kind]
    bad += not ok
    print('%s %-70s %6.1f pt (%s)' % ('OK ' if ok else 'BAD', name, g, kind))
print('ball diameter %d; pass >= %.0f, lane >= %.0f, closed < %d' % (D, 1.5 * D, 1.2 * D, D))
# the left side: harpoon lane, tongue, loop, U-turn
report('harpoon lane (left wall x 20 to its inner wall / tongue x 60)', C.harpoonX - C.leftWallX, 'lane')
report('loop channel at y 960 (tongue x 70 to the post)', C.loopPostLeftX(960) - C.tongueRightX, 'lane')
report('loop channel from y 1060 up (to x 106)', C.loopPostLeftX(1060) - C.tongueRightX, 'lane')
_ut = [p for p in ow if p[1] > C.loopUCentre[1] - 1 and p[0] < 120]
report('hairpin: the tongue top to the U-turn wall', gap(C.tongue, _ut), 'lane')
report('loop mouth: tongue bottom cap to Tgt1 face (the loop shot passes between)', min(poly_dist(p, list(C.shark_target_face(0))) for p in dense(C.tongue)), 'info')
report('Tgt1 backing to the post tip (closed)', gap(C.sharkBacks[0], C.loopRight), 'closed')
report('quickshot gate opening (720 -> tongue bottom)', C.quickshotGate[1][1] - C.quickshotGate[0][1], 'pass')
report('bank backboard to the harpoon wall (closed)', max(0, C.bankBackboard[0][0] - C.harpoonX), 'closed')
# the ramp entrances, boat, reel
report('wave lane (x 151 to the block x 197)', C.waveEndCentre[0] - C.waveEndRadius - C.waveLaneLeft[0][0], 'lane')
report('chum bucket to the wave lane wall', circle_gap(C.chumBucketCentre, C.chumBucketRadius, C.waveLaneLeft), 'lane')
report('center ramp opening at y 1000 (block x 228 to the post)', C.centerPost[0] - C.centerPostRadius - 228, 'pass')
report('boat cradle between its posts', 2 * C.boatHalfWidth - 2 * C.boatPostRadius, 'lane')
report('reel keyhole (x 433 to 499)', 499 - 433, 'pass')
report('Tgt2 face to Tgt3 face (the reel gap)', math.dist(C.shark_target_face(1)[1], C.shark_target_face(2)[0]), 'lane')
report('Tgt3 backing to the reel-right block (closed)', gap(C.sharkBacks[2], C.reelRightBlock), 'closed')
# the right side (M4 v4-v5)
_lane_r = dense(C.rightLaneCurve)
report('reel-right lane at its foot (block x 505 to the wall x 548, y 983)', 548 - 505, 'lane')
report('reel-right lane at its top (522 -> 562, y 1200)', C.laneTopInnerX - 522, 'lane')
report('shooter lane (x 548 to 589)', C.rightWallX - C.laneWallX, 'lane')
report('plunge pin to the barrel end (closed)', circle_gap(C.plungePin, C.plungePinRadius, C.barrelEnd), 'closed')
report('plunge pin to the lane wall / curve (closed)', circle_gap(C.plungePin, C.plungePinRadius, C.rightLaneCurve), 'closed')
report('plunge pin to Tgt3 backing (the plunge passes left of the pin)', circle_gap(C.plungePin, C.plungePinRadius, C.sharkBacks[2]), 'pass')
report('barrel end to the curve (closed)', gap(C.barrelEnd[:-3], C.rightLaneCurve), 'closed')
report('bumper rubber to the curve beside it (the lane past the bumper)', circle_gap(C.bumperCenter, C.bumperRadius, C.rightLaneCurve), 'lane')
report('bumper to the shooter wall top (548, 645): the way into the mid lane (traced, ~1 ball)', math.dist(C.bumperCenter, (C.laneWallX, C.shooterInnerTopY)) - C.bumperRadius, 'info')
report('bumper rubber to the pier block (the mid lane beside it)', circle_gap(C.bumperCenter, C.bumperRadius, C.pierPlastic), 'lane')
report('bumper rubber to the buoy target', math.dist(C.bumperCenter, C.buoyTarget[0]) - C.bumperRadius - 4, 'lane')
report('mid lane switch inside the lane (bumper edge to the switch centre)', math.dist(C.bumperCenter, C.miniLaneSensor) - C.bumperRadius, 'info')
# the fin over its whole travel
finmin = {'bumper': 1e9, 'curve': 1e9, 'pin': 1e9, 'Tgt3 backing': 1e9}
s = C.finMinS
while s <= C.finMaxS:
    (fx, fy), fh = C.fin_at(s); L = C.finLength / 2
    blade = [(fx - L * math.cos(fh), fy - L * math.sin(fh)), (fx + L * math.cos(fh), fy + L * math.sin(fh))]
    finmin['bumper'] = min(finmin['bumper'], seg_dist(C.bumperCenter, *blade) - C.bumperRadius - C.finThickness / 2)
    finmin['curve'] = min(finmin['curve'], gap(blade, C.rightLaneCurve) - C.finThickness / 2)
    finmin['pin'] = min(finmin['pin'], seg_dist(C.plungePin, *blade) - C.plungePinRadius - C.finThickness / 2)
    finmin['Tgt3 backing'] = min(finmin['Tgt3 backing'], gap(blade, C.sharkBacks[2]) - C.finThickness / 2)
    s += 2
for k, v in finmin.items(): report('fin blade (whole travel) to the %s' % k, v, 'pass')
# lower table
lt0 = C.flipper_tip(C.leftFlipperPivot, 'left'); rt0 = C.flipper_tip(C.rightFlipperPivot, 'right')
report('flipper tip gap (centre drain)', math.dist(lt0, rt0) - 2 * C.flipperTipRadius, 'lane')
report('left inlane (guide to sling corner)', C.leftSling[1][0] - C.laneGuideX, 'lane')
report('left outlane', C.laneGuideX - C.leftWallX, 'lane')
# the plunger
print('plunger: pull 0 -> %.0f, 0.13 -> %.0f, tap %.1f -> %.0f, full -> %.0f pt/s; the bumper band (1,060-1,120) = pull %.3f-%.3f'
      % (C.launch_speed(0), C.launch_speed(0.13), C.tapLaunchPower, C.launch_speed(C.tapLaunchPower), C.launch_speed(1),
         ((1060 - C.minLaunchSpeed) / (C.maxLaunchSpeed - C.minLaunchSpeed)) ** (1 / C.plungePowerExponent),
         ((1120 - C.minLaunchSpeed) / (C.maxLaunchSpeed - C.minLaunchSpeed)) ** (1 / C.plungePowerExponent)))
print('%d BAD' % bad); print('render:', out)
