"""Pier pocket drop sim (pymunk): balls down the feed lane onto the mini-flipper, at rest and raised-then-released.
Reports where each ball ends: OFF (left the pocket below y 560) or STUCK (still, inside the pocket)."""
import math, sys, pymunk
G = 9.2 * 150; R = 9; DAMP = 0.9
PIV = (539, 596); L = 56; R0, R1 = 9, 5
def flipper(space, raised):
    a = math.radians(30 if not raised else -30)        # right flipper: rest = tip 30 deg below horizontal
    tip = (PIV[0] - L*math.cos(a), PIV[1] - L*math.sin(a))
    b = space.static_body
    shapes = [pymunk.Circle(b, R0, PIV), pymunk.Circle(b, R1, tip)]
    nx, ny = -(tip[1]-PIV[1]), tip[0]-PIV[0]; n = math.hypot(nx, ny); nx, ny = nx/n, ny/n
    quad = [(PIV[0]+nx*R0, PIV[1]+ny*R0), (tip[0]+nx*R1, tip[1]+ny*R1), (tip[0]-nx*R1, tip[1]-ny*R1), (PIV[0]-nx*R0, PIV[1]-ny*R0)]
    shapes.append(pymunk.Poly(b, quad))
    for s in shapes: s.friction = 0.4; s.elasticity = 0.3
    space.add(*shapes); return shapes
def run(x0, deflector, mode):
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.damping = DAMP
    segs = [((548, 470), (548, 955)), ((514, 790), (514, 660)), ((548, 575), (541, 585))]
    if deflector: segs.append(deflector)
    for a, b in segs:
        s = pymunk.Segment(sp.static_body, a, b, 1); s.friction = 0.1; s.elasticity = 0.3; sp.add(s)
    fl = flipper(sp, mode == 'raised')
    body = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, R)); body.position = (x0, 800); body.velocity = (0, -300)
    c = pymunk.Circle(body, R); c.friction = 0.1; c.elasticity = 0.1; sp.add(body, c)
    dt = 1/120
    for i in range(int(3/dt)): sp.step(dt)
    if mode == 'raised':
        held = body.position
        sp.remove(*fl); flipper(sp, False)
        for i in range(int(2/dt)): sp.step(dt)
        p = body.position
        return f"held at ({held.x:.1f},{held.y:.1f}) -> " + ("OFF" if p.y < 560 else f"STUCK ({p.x:.1f},{p.y:.1f})")
    p = body.position
    return "OFF" if p.y < 560 else f"STUCK ({p.x:.1f},{p.y:.1f}) v={body.velocity.length:.0f}"
for name, d in [("v1 (no deflector)", None), ("v3 short cap (548,614)->(534.5,603.8)", ((548, 614), (534.5, 603.8)))]:
    print("==", name)
    for mode in ['rest', 'raised']:
        res = [f"x{x}:{run(x, d, mode)}" for x in [524, 528, 532, 536, 538.9]]
        print(mode, *res, sep="\n  ")
