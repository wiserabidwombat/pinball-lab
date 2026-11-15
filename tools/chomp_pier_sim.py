"""M2 v2 pier flipper drop sim (pymunk): balls dropped from y 760 at x 470-546 onto the plastic block / flipper,
flipper at rest and held up (then released). Reports where each ball ends up."""
import math, sys, pymunk
sys.path.insert(0, '.')
import chomp_layout as C
G = 9.2 * 150; R = C.ballRadius; DAMP = 0.9
def flipper(space, raised):
    a = C.miniRestAngle - (C.miniSwing if raised else 0)
    piv = C.miniPivot; tip = (piv[0] - C.miniLength*math.cos(a), piv[1] - C.miniLength*math.sin(a))
    b = space.static_body; r0, r1 = C.miniPivotRadius, C.miniTipRadius
    nx, ny = -(tip[1]-piv[1]), tip[0]-piv[0]; n = math.hypot(nx, ny); nx, ny = nx/n, ny/n
    quad = [(piv[0]+nx*r0, piv[1]+ny*r0), (tip[0]+nx*r1, tip[1]+ny*r1), (tip[0]-nx*r1, tip[1]-ny*r1), (piv[0]-nx*r0, piv[1]-ny*r0)]
    sh = [pymunk.Circle(b, r0, piv), pymunk.Circle(b, r1, tip), pymunk.Poly(b, quad)]
    for s in sh: s.friction = 0.4; s.elasticity = 0.3
    space.add(*sh); return sh
def run(x0, mode):
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.damping = DAMP
    walls = [C.pierPlastic, C.rightLaneGuide, C.rightOutlanePostRail, [(548, 300), (548, 955)], list(C.rightSling) + [C.rightSling[0]]]
    for w in walls:
        for a, b in zip(w, w[1:]):
            s = pymunk.Segment(sp.static_body, a, b, 1); s.friction = 0.1; s.elasticity = 0.3; sp.add(s)
    fl = flipper(sp, mode == 'raised')
    body = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, R)); body.position = (x0, 760); body.velocity = (0, -200)
    c = pymunk.Circle(body, R); c.friction = 0.1; c.elasticity = 0.1; sp.add(body, c)
    dt = 1/120
    cross = None
    def step(n):
        nonlocal cross
        for _ in range(n):
            sp.step(dt)
            if cross is None and body.position.y < 400: cross = tuple(body.position)
    step(int(3/dt))
    held = body.position
    if mode == 'raised' and cross is None:
        sp.remove(*fl); flipper(sp, False)
        step(int(2/dt))
    p = pymunk.Vec2d(*cross) if cross else body.position
    gx = C.mirrorSum - C.laneGuideX; sx = C.rightSling[0][0]
    where = (f'right inlane x{p.x:.0f}' if sx < p.x < gx else f'right outlane x{p.x:.0f}' if p.x > gx else f'playfield x{p.x:.0f}') if cross else f'STILL UP ({p.x:.0f},{p.y:.0f})'
    return (f'held ({held.x:.0f},{held.y:.0f}) -> ' if mode == 'raised' and held.y > 465 else '') + where
for mode in ['rest', 'raised']:
    print(mode); [print(f'  x{x}: {run(x, mode)}') for x in [470, 490, 505, 515, 525, 535, 546]]
