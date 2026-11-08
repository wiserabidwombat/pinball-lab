"""A 2D rig for one flipper hitting a ball (pymunk): the left flipper pinned at the origin, arm along +x, rest -30°,
60° of travel at omega rad/s (set each step like TourFlipper.step), a ball resting on the top face `a` pt from the
pivot. Prints the ball's launch speed, direction and how high it would rise (gravity 1380) — our units."""
import math, sys
sys.path.insert(0, '.')
import pymunk

G = 1380.0
def run(a, omega=25.5, length=96, r0=12, r1=6, e=0.1, mu=0.2, ball_r=9, ball_m=0.08, dt=1/120, travel=math.radians(60),
        rest=-math.radians(30), flip_mass=None, extra=None):
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 30
    fb = pymunk.Body(body_type=pymunk.Body.KINEMATIC)
    fb.angle = rest
    quad = [(0, r0), (length, r1), (length, -r1), (0, -r0)]
    shapes = [pymunk.Circle(fb, r0), pymunk.Circle(fb, r1, (length, 0)), pymunk.Poly(fb, quad)]
    sp.add(fb)
    for s in shapes: s.elasticity = 1.0; s.friction = mu; sp.add(s)
    # the ball on the top face at distance a (face line (0,r0)->(length,r1)), in the flipper's frame, then rotated
    t = a / length; hy = r0 + (r1 - r0) * t
    nx, ny = (r0 - r1), length; nl = math.hypot(nx, ny); nx, ny = nx / nl, ny / nl
    lx, ly = a + nx * ball_r, hy + ny * ball_r
    c, s_ = math.cos(rest), math.sin(rest)
    bx, by = lx * c - ly * s_, lx * s_ + ly * c
    b = pymunk.Body(ball_m, pymunk.moment_for_circle(ball_m, 0, ball_r)); b.position = (bx, by)
    bs = pymunk.Circle(b, ball_r); bs.elasticity = e; bs.friction = 1.0; sp.add(b, bs)
    if extra: extra(sp)
    tmax = 0.3; tt = 0; last_touch = 0; best = None
    while tt < tmax:
        raised = fb.angle - rest
        want = (travel - raised) / dt
        fb.angular_velocity = max(0, min(want, omega))
        sp.step(dt); tt += dt
        # touching?
        # touching: the ball's centre within r+1 of the arm (in the arm's frame)
        dx, dy = b.position.x, b.position.y; c2, s2 = math.cos(fb.angle), math.sin(fb.angle)
        ax, ay = dx * c2 + dy * s2, -dx * s2 + dy * c2
        tt_ = min(max(ax / length, 0), 1); half = r0 + (r1 - r0) * tt_
        touching = -r0 - 1 < ax < length + r1 + 1 and abs(ay) < half + ball_r + 1
        if touching: last_touch = tt
        if tt - last_touch > 0.02 and best is None:
            v = b.velocity; sp_ = math.hypot(*v); ang = math.degrees(math.atan2(v.y, v.x))
            apex = b.position.y + (v.y ** 2) / (2 * G) if v.y > 0 else b.position.y
            best = (tt - 0.02, sp_, ang, apex, b.position)
    return best

if __name__ == '__main__':
    print('ball at a pt from the pivot → launch speed, direction, apex above the pivot (left flipper; the centre of the table is at ~73° from the left pivot)')
    for omega in (25.5, 30, 35):
        for e in (0.1, 0.3, 0.5):
            row = []
            for a in (22, 28, 32, 36, 40, 50, 60, 80):
                r = run(a, omega=omega, e=e)
                row.append(f'a{a:>2}: {r[1]:5.0f}pt/s {r[2]:4.0f}° apex {r[3]:5.0f}' if r else f'a{a}: stuck')
            print(f'omega {omega:4.1f} e {e}: ' + ' | '.join(row))
