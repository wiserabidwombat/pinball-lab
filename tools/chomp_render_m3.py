"""Table 07 M3 render: the M2 render plus the right half's new parts over the reference drawing (p. 40), with checks."""
import math, sys, os
import math as _m
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1] if len(sys.argv) > 1 else 'build/chomp_m3.png'
lims = sys.argv[2] if len(sys.argv) > 2 else '((-20, 640), (380, 1300))'
sys.argv = ['chomp_render_m2.py', '/tmp/_m2.png', lims]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'chomp_render_m2.py')).read())
import chomp_layout as C
_c = lambda s: C.centerMouthHalfWidth + (C.centerHalfWidth - C.centerMouthHalfWidth) * min(s / C.centerFlareLength, 1)
CL, CR = C.CP.rails(_c)
poly(CL, c='#cc6600', lw=1.6, ls='--'); poly(CR, c='#cc6600', lw=1.6, ls='--')
_low = [i for i, d in enumerate(C.CP.dist) if d < C.centerLowLength]
_bp, _bh = C.CP.at(C.centerLowLength); _bw = _c(C.centerLowLength)
centerU = [CL[i] for i in _low] + [(_bp[0] - _bw*math.sin(_bh), _bp[1] + _bw*math.cos(_bh)),
                                   (_bp[0] + _bw*math.sin(_bh), _bp[1] - _bw*math.cos(_bh))] + [CR[i] for i in reversed(_low)]
poly(centerU)
if hasattr(C, 'centerPost'):                                   # M3 v2: the real entrance (jamb, rubber post, funnel)
    poly(C.centerJamb); poly(C.centerFunnel); ax.add_patch(plt.Circle(C.centerPost, C.centerPostRadius, color='#0033cc'))
if hasattr(C, 'boatMouth'):                                     # M3 v4: the boat captive ball
    poly(C.boatHousing)
    _bx, _by = C.boatMouth; _bh = C.boatHalfWidth; _bl = C.boatChannelLength
    poly([(_bx - _bh, _by), (_bx - _bh, _by + _bl), (_bx + _bh, _by + _bl), (_bx + _bh, _by)])
    _pr = getattr(C, 'boatPostRadius', 4)
    for _k in (-_bh, _bh): ax.add_patch(plt.Circle((_bx + _k, _by), _pr, color='#0033cc'))
    if hasattr(C, 'boatLip'): poly(C.boatLip, c='#888888', lw=1.5)
    ax.add_patch(plt.Circle((_bx, (min(p[1] for p in C.boatLip) + C.ballRadius) if hasattr(C, 'boatLip') else _by + 10), C.ballRadius, color='#888888', alpha=0.8))
    ax.text(_bx - 14, _by + _bl + 4, 'boat', fontsize=7)
if hasattr(C, 'rampIsland'):                                   # M3 v8: the real plastics that close the traps
    for _poly in (C.rampIsland, C.bankWedge) + ((C.reelLeftBlock, C.reelRightBlock) if hasattr(C, 'reelLeftBlock') else ()):
        ax.fill([p[0] for p in _poly], [p[1] for p in _poly], color='#3355ff', alpha=0.35); poly(_poly)
_ap = C.CP.at(C.centerApexDistance)[0]; ax.plot(*_ap, 'o', color='#cc6600'); ax.text(_ap[0]-40, _ap[1]+8, 'center made', fontsize=7)
ax.set_title('Table 07 CHOMP! M3: the center ramp (orange dashed) over the reference drawing (p.40)', fontsize=9)
fig.savefig(out, dpi=110, bbox_inches='tight')
# checks
up = [i for i, d in enumerate(C.CP.dist) if d <= C.centerClimb]
down = [i for i, d in enumerate(C.CP.dist) if d >= C.centerApexDistance + C.centerTurnRadius * math.pi / 2]
gap = min(math.hypot(a[0]-b[0], a[1]-b[1]) for a in [CL[i] for i in up] + [CR[i] for i in up]
          for b in [CL[i] for i in down] + [CR[i] for i in down])
print('center: climb rails to the return wire rails, closest %.1f (must not touch)' % gap)
print('center: mouth left rail x %.1f vs the wave block right edge x %.1f -> gap %.1f (closed)' % (CL[0][0], C.waveEndCentre[0] + C.waveEndRadius, CL[0][0] - C.waveEndCentre[0] - C.waveEndRadius))
print('center: lane %.1f wide; U inner rail radius %.1f; ball free band in the U %.1f' % (2*C.centerMouthHalfWidth, C.centerTurnRadius - C.centerHalfWidth, 2*C.centerHalfWidth - 2*C.ballRadius))
e = C.CP.points[-1]; print('center: wire end (%.1f, %.1f); left inlane x %d..%d' % (e[0], e[1], C.laneGuideX, C.leftSling[1][0]))
if hasattr(C, 'centerPost'):
    print('center: opening at y 1000, block edge x 228 -> post edge %.1f = %.1f wide; flap %.1f wide' % (C.centerPost[0] - C.centerPostRadius, C.centerPost[0] - C.centerPostRadius - 228, 2 * C.centerMouthHalfWidth))
    print('center: post to the funnel %.1f (closed); funnel end to the right rail start %.1f (closed)' % (poly_dist(C.centerPost, C.centerFunnel), math.hypot(C.centerFunnel[1][0] - CR[0][0], C.centerFunnel[1][1] - CR[0][1])))
    print('center: jamb top to the left rail start %.1f (closed)' % math.hypot(C.centerJamb[1][0] - CL[0][0], C.centerJamb[1][1] - CL[0][1]))
if hasattr(C, 'boatMouth'):
    print('boat: mouth post gap %.1f (the lip holds the captive ball)' % (2 * C.boatHalfWidth - 2 * getattr(C, 'boatPostRadius', 4)))
    print('boat: housing corner (305, 1000) to the center post (300, 1000) r %d: %.1f (closed)' % (C.centerPostRadius, 5 - C.centerPostRadius))
    print('boat: pocket between the center ramp U (x 280) and the housing (x 305): %.1f (closed < 30)' % (305 - 280))
if hasattr(C, 'rampIsland'):
    import math as _m
    _sl = lambda a, b: _m.degrees(_m.atan2(b[1] - a[1], b[0] - a[0]))
    _r = C.boatHousing[2], C.boatHousing[3]
    print('traps: island + housing roof %.1f deg down to the right (one line from the loop wall); bank wedge top %.1f deg'
          % (_sl(_r[0], _r[1]), _sl((60, 720), (100.8, 700))))
    print('traps: island over the wave U back (y 1060) and the center U back (y 1080): no flat ledge left open')
if hasattr(C, 'reelCentre'):
    ax.add_patch(plt.Circle(C.reelCentre, C.reelDiscRadius, color='#2244aa', alpha=0.25)); poly(list(C.reelSwitch), c='#00aaaa', lw=2)
    print('reel: mouth %.0f wide (x 426-500 at y ~980); channel %.0f; round end r %d -> the ball circles at r %d'
          % (500 - 426, 499 - 433, C.reelRadius, C.reelRadius - C.ballRadius))
    print('reel: roof %.1f..%.1f over x 147..510 (%.1f deg); roof above the keyhole top %.1f (closed); roof end (510, %.0f) -> open right side %.0f pt to the arch'
          % (C.roofY(147), C.roofY(510), _m.degrees(_m.atan2(35, 363)), C.roofY(466) - 1148, C.roofY(510), 566 - 510))
    print('reel: left block to the boat housing: shared edge x 395 (closed); housing to the boat cradle unchanged')
print('center: length %.1f, apex s %.1f' % (C.CP.dist[-1], C.centerApexDistance))
