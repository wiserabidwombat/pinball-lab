"""Table 06 M3: what the top of the table does with a ball (pymunk, real walls, bumpers kicking at 1,150 pt/s away from
their centre, 50 ms cooldown). Reports, per start: bumper hits, S-T-A-R lanes crossed going UP (bumper re-feeds) and
going DOWN, and where the ball leaves the top (left/right side, down the middle, rocket pad...).
Usage: python3 tools/tour_nest_sim.py [bumper layout name]"""
import sys, math, random, collections
sys.path.insert(0, '.')
import pymunk, tour_plunge_sim as P, tour_layout_m3 as M
R = 9
def arch_y(x):
    for u, v in zip(M.ARCH, M.ARCH[1:]):
        if u[0] <= x <= v[0] and v[0] > u[0]: return u[1] + (x - u[0]) * (v[1] - u[1]) / (v[0] - u[0])
def sim(start, vel, bumpers, br=24, kick=1150, plunge=False, T=4.0):
    space, lgate = P.build('x')
    # P.build adds M.bumperCenters as plain circles; remove them and add ours
    for s in list(space.shapes):
        if isinstance(s, pymunk.Circle) and s.body.body_type == pymunk.Body.STATIC: space.remove(s)
    for c in bumpers:
        s = pymunk.Circle(space.static_body, br, c); s.elasticity = 0.0; s.friction = 0.0; space.add(s)
    flap = pymunk.Segment(space.static_body, (395, 1259.5), (330, 1214), 2); flap.elasticity = 0.2
    og = pymunk.Segment(space.static_body, (352, 1266.4), (352, 1214), 2); og.elasticity = 0.1
    body = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, R)); body.position = start; body.velocity = vel
    sh = pymunk.Circle(body, R); sh.elasticity = 0.1; sh.friction = 0.1; space.add(body, sh)
    st = {'g': False, 'f': False, 'o': False}; t = 0; dt = 1 / 240; prev = body.position; last = {}
    hits = 0; up = []; down = []
    while t < T:
        x, y = body.position; vx, vy = body.velocity
        isP = plunge and not (y < 900 and x < 548)
        for key, seg, want in (('g', lgate, (32 * (y - 955) - 28 * (x - 548)) > 0 and vy < 0), ('f', flap, isP),
                               ('o', og, vx > 0 and not isP)):
            if want != st[key]: (space.add if want else space.remove)(seg); st[key] = want
        space.step(dt); t += dt; p = body.position
        for i, c in enumerate(bumpers):
            d = math.dist(p, c)
            if d < br + R + 0.8 and t - last.get(i, -1) > 0.05:
                last[i] = t; hits += 1
                body.velocity = ((p[0] - c[0]) / d * kick, (p[1] - c[1]) / d * kick)
        if 214 < p.x < 358:
            lane = 'STAR'[min(3, int((p.x - 214) // 36))]
            if prev.y < M.laneRolloverY <= p.y: up.append(lane)
            if prev.y >= M.laneRolloverY > p.y: down.append(lane)
        if p.y < 760:
            side = 'left' if p.x < 200 else 'right' if p.x > 370 else 'middle'
            return hits, up, down, side
        prev = pymunk.Vec2d(p.x, p.y)
    return hits, up, down, 'still up top'
def report(name, bumpers):
    print(f'== {name}: bumpers {bumpers}')
    for i, x in enumerate([232, 268, 304, 340]):
        h, u, d, side = sim((x, 1190), (0, -60), bumpers)
        print(f'  ball dropped down lane {"STAR"[i]}: bumper hits {h}, lanes up {u}, leaves {side}')
    h, u, d, side = sim((40, 930), (0, 2400), bumpers)
    print(f'  left orbit (2400): down {d}, bumper hits {h}, lanes up {u}, leaves {side}')
    random.seed(1); agg = collections.Counter(); ups = 0; hs = 0; n = 60
    for k in range(n):
        st = (random.uniform(80, 260), random.uniform(1000, 1150)); v = (random.uniform(-300, 300), random.uniform(-300, 300))
        h, u, d, side = sim(st, v, bumpers)
        agg[side] += 1; ups += len(u); hs += h
    print(f'  {n} random balls in the nest: avg bumper hits {hs / n:.1f}, lane crossings going up {ups} ({ups / n:.2f}/ball), leave {dict(agg)}')
if __name__ == '__main__':
    report('v2 nest', M.bumperCenters)
