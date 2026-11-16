"""M2 v5: the wave ramp's wire drops the ball near (524, 671) heading straight down. Where does it go at different
exit speeds (the wire speed cap), with the pier flipper at rest and held up? Reuses chomp_pier_sim's walls."""
import math, sys, pymunk
sys.path.insert(0, '.')
import chomp_layout as C
import chomp_pier_sim as P
def run(x0, y0, vy, mode):
    sp = pymunk.Space(); sp.gravity = (0, -P.G); sp.damping = P.DAMP
    for w in [C.pierPlastic, C.rightLaneGuide, C.rightOutlanePostRail, [(548, 300), (548, 955)], list(C.rightSling) + [C.rightSling[0]]]:
        for a, b in zip(w, w[1:]):
            s = pymunk.Segment(sp.static_body, a, b, 1); s.friction = 0.1; s.elasticity = 0.3; sp.add(s)
    fl = P.flipper(sp, mode == 'raised')
    body = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, P.R)); body.position = (x0, y0); body.velocity = (0, -vy)
    c = pymunk.Circle(body, P.R); c.friction = 0.1; c.elasticity = 0.1; sp.add(body, c)
    dt = 1/120; cross = None; maxx = 0; peak = 0; minx = 999
    for k in range(int(4/dt)):
        sp.step(dt)
        if k > 5: peak = max(peak, body.position.y if body.position.y < y0 else 0)
        minx = min(minx, body.position.x)
        if cross is None and body.position.y < 400: cross = tuple(body.position)
    held = tuple(body.position)
    if mode == 'raised' and cross is None:
        sp.remove(*fl); P.flipper(sp, False)
        for _ in range(int(2/dt)):
            sp.step(dt)
            if cross is None and body.position.y < 400: cross = tuple(body.position)
    gx = C.mirrorSum - C.laneGuideX; sx = C.rightSling[0][0]
    if not cross: return f'STILL UP {held}'
    x = cross[0]
    w = 'right inlane' if sx < x < gx else 'right outlane' if x > gx else 'playfield'
    return (f'held ({held[0]:.0f},{held[1]:.0f}) -> ' if mode == 'raised' else '') + f'{w} x{x:.0f} (min x {minx:.0f})'
if __name__ == '__main__':
    end = C.WP.points[-1]
    for vy in [400, 650, 900, 1250]:
        for mode in ['rest', 'raised']:
            print(f'exit {vy} pt/s, {mode}: ' + ', '.join(run(end[0] + dx, end[1], vy, mode) for dx in [-4, 0, 4]))
