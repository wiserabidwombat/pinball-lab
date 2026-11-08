"""Table 06: where each plunge strength goes (pymunk, the real walls from tour_layout*.py). The plunger fires the ball
straight up the shooter lane at 1,080 + power x 1,230 pt/s (TourTableLayout min/max launch), g = 1,380 pt/s^2, r 9.
Outcomes: 'fell back' (to the plunger), 'gate -> R lane' (back onto the launch gate and down the right orbit lane),
'S-T-A-R n' (down through a top lane), 'L lane' (round the top and down the left orbit lane), 'bumpers'/'other'.
Usage: python3 tools/tour_plunge_sim.py [v2|v3]   (v3 = with the M3 v3 plunge flap)
Results 8 Nov 2026: v2 lanes only at 0.58-0.62 power; v3 lanes from 0.60 to 1.00 (all S-T-A-R R)."""
import math, sys
sys.path.insert(0, '.')
import pymunk
import tour_layout as L, tour_layout_m3 as M

VARIANT = sys.argv[1] if len(sys.argv) > 1 else 'v2'
R, G = 9, 1380
def build(variant):
    space = pymunk.Space(); space.gravity = (0, -G)
    def wall(pts, e=0.3, f=0.1):
        for a, b in zip(pts, pts[1:]):
            s = pymunk.Segment(space.static_body, a, b, 1.5); s.elasticity = e; s.friction = f; space.add(s)
    wall(L.outer_wall(), 0.15, 0.02)
    wall([(548, 955), (548, 40)], 0.15, 0.02)                  # shooter-lane wall (in outer_wall too; harmless)
    wall(M.leftOrbitInner, 0.15, 0.02)
    rinner = [M.R_TIP, M.R_BEND] + list(reversed([p for p in M._ro if p[0] >= 400]))
    wall(rinner, 0.15, 0.02)
    for x in M.lanePostXs: wall([(x, M.lanePostBottom), (x, M.lanePostTop)])
    for c in M.bumperCenters:
        s = pymunk.Circle(space.static_body, M.bumperRadius, c); s.elasticity = 0.6; s.friction = 0.1; space.add(s)
    wall(getattr(M, "rocketPad", [(222.0, 960.0), (266, 980), (284, 998), (302, 980), (346.0, 960.0)]))
    gate = pymunk.Segment(space.static_body, (548, 955), (580, 983), 1.5); gate.elasticity = 0.2; gate.friction = 0.05
    if variant == 'v3':   # M3 v3: the plunge flap (closed for the plunge; every ball here is a plunge)
        f = pymunk.Segment(space.static_body, (395, 1259.5), (330, 1214), 2); f.elasticity = 0.2; f.friction = 0.1
        space.add(f)
    return space, gate
def run(power, variant=VARIANT):
    space, gate = build(variant)
    v0 = 1080 + power * 1230
    body = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, R)); body.position = (564, 139); body.velocity = (0, v0)
    shape = pymunk.Circle(body, R); shape.elasticity = 0.1; shape.friction = 0.1; space.add(body, shape)
    gate_in = False; t = 0; dt = 1 / 240; prev = body.position; maxy = 0; top_v = None
    while t < 6:
        # one-way launch gate: solid only for a ball above it moving down
        x, y = body.position; vx, vy = body.velocity
        above = (32 * (y - 955) - 28 * (x - 548)) > 0
        want = above and vy < 0
        if want != gate_in:
            (space.add if want else space.remove)(gate); gate_in = want
        space.step(dt); t += dt
        p = body.position; maxy = max(maxy, p.y)
        if p.y > 1240 and top_v is None: top_v = round(math.hypot(*body.velocity))
        # outcomes
        if p.y < 150 and p.x > 548 and body.velocity.y < 0 and t > 0.2: return 'fell back', maxy, top_v
        if prev.y >= M.laneRolloverY > p.y and 214 < p.x < 358:
            return 'S-T-A-R %s' % 'STAR'[min(3, int((p.x - 214) // 36))], maxy, top_v
        if p.x < 60 and p.y < 900: return 'L lane', maxy, top_v
        if 504 < p.x < 548 and p.y < 760: return 'gate -> R lane', maxy, top_v
        if p.y < 700 and 60 < p.x < 504: return 'down the middle', maxy, top_v
        prev = pymunk.Vec2d(p.x, p.y)
    return 'other', maxy, top_v
if __name__ == '__main__':
    import collections
    res = collections.OrderedDict()
    for k in range(0, 101, 2):
        pw = k / 100; o, my, tv = run(pw)
        res[pw] = o
        print(f'  power {pw:.2f} ({1080 + pw * 1230:4.0f} pt/s): {o:16s} peak y {my:6.0f}  speed at y 1240: {tv}')
    print('tap (0.60):', run(0.6)[0])
