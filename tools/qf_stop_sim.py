"""pymunk check for M1 v6's orbit stop (Quest & Flipper, Table 09): shots from the main flippers' sweet spots and plunges,
with the diverter and the orbit stop raised and one-way per ball as in QfTableScene (solid once a ball is clear on its
solid side, kept while it stays there). Outcomes: UPPER FLIPPER (reaches it; unflipped it rolls off the tip), ROUND (crossed the top to the far
side and came down), BACK (came down without either). Slings and the main flippers aren't simulated."""
import math, pymunk
import qf_layout as L
G, STEP, R = 900.0, 1 / 120, L.BALL_R

def segd(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(p, (a[0] + dx * t, a[1] + dy * t))
def side(p, a, b): return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
# solid sides: the diverter's glade side (cross < 0); the stop's right side (same sign as a point right of it)
ONEWAY = [(L.DIVERTER_A, L.DIVERTER_B, -1, 2), (L.STOP_A, L.STOP_B, 1 if side((560, 1290), L.STOP_A, L.STOP_B) > 0 else -1, 4)]

def run(pos, vel, raised=True, launch_gate=True):
    sp = pymunk.Space(); sp.gravity = (0, -G)
    P = {k: v for k, v in L.floor_parts(mode_parts=False).items()
         if "upper flipper" not in k and "diverter" not in k and "stop" not in k and "flipper pivot" not in k
         and (launch_gate or k != "launch gate")}
    for part in P.values():
        if part[0] == "poly":
            for a, b in zip(part[1], part[1][1:]):
                s = pymunk.Segment(sp.static_body, a, b, 0.5); s.elasticity, s.friction = 0.3, 0.1; sp.add(s)
        else:
            c = pymunk.Circle(sp.static_body, part[2], part[1]); c.elasticity, c.friction = 0.3, 0.1; sp.add(c)
    tip, poly = L.uf_poly(0)
    for s in [pymunk.Poly(sp.static_body, poly), pymunk.Circle(sp.static_body, L.UF_RP, L.UF_PIVOT),
              pymunk.Circle(sp.static_body, L.UF_RT, tip)]:
        s.elasticity, s.friction = 0.3, 0.4; sp.add(s)
    if raised:
        for a, b, sg, cat in ONEWAY:
            s = pymunk.Segment(sp.static_body, a, b, 0.5); s.elasticity, s.friction = 0.2, 0.05
            s.filter = pymunk.ShapeFilter(categories=cat); sp.add(s)
    body = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, R)); body.position, body.velocity = pos, vel
    ball = pymunk.Circle(body, R); ball.elasticity, ball.friction = 0.1, 0.1; sp.add(body, ball)
    solid = {2: False, 4: False}; xs = []; settle = 0
    for i in range(int(10 / STEP)):
        p = tuple(body.position)
        for a, b, sg, cat in ONEWAY:
            on = side(p, a, b) * sg > 0
            if not on: solid[cat] = False
            elif not solid[cat] and segd(p, a, b) > R + 1: solid[cat] = True
        mask = 0xffffffff & ~sum(c for c, v in solid.items() if not v)
        ball.filter = pymunk.ShapeFilter(categories=1, mask=mask)
        sp.step(STEP)
        if p[1] > 1240: xs.append(p[0])
        if segd(p, L.UF_PIVOT, tip) < R + 14:
            return "UPPER FLIPPER"
        if p[1] < 600 and i > 60:
            return "ROUND" if xs and min(xs) < 150 and max(xs) > 450 else "BACK"
    return "STILL UP"

def tally(cases, **kw):
    out = {}
    for pos, vel in cases:
        r = run(pos, vel, **kw); out[r] = out.get(r, 0) + 1
    return out

def shots(sweet, heads, speeds=(1500, 1800, 2100)):
    return [(sweet, (v * math.cos(math.radians(h)), v * math.sin(math.radians(h)))) for h in heads for v in speeds]

if __name__ == "__main__":
    left = shots((243.0, 214.0), range(60, 72, 2))           # up the right lane (counterclockwise)
    right = shots((357.0, 214.0), range(112, 124, 2))        # the Graveyard lane (clockwise)
    plunge = [((602.5, 200.0), (0, v)) for v in range(1300, 2400, 100)]
    for name, cases, kw in [("left flipper, right lane", left, {}), ("right flipper, Graveyard", right, {}),
                            ("plunges", plunge, {"launch_gate": False})]:
        print(f"{name:26s} raised: {tally(cases, **kw)}   lowered: {tally(cases, raised=False, **kw)}")
