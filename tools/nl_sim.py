"""pymunk checks for the cell kit (coarse: static flippers at rest, no sling kicks, no player).
A) (round 2: drop-ins ride a return wire now, so they end like B; test_top_drop is the round-2 hub-base test kept for
   the record: 50% went down an outlane, which is why the return wires exist)
B) a ball released by a return wire inside the inlane, 150-800 pt/s: does it reach the flipper?
C) a ball rising up through the drain (from the cell below): does the pop land it on a flipper?
Gravity 900 pt/s^2 (CHOMP!: -6.0); ball r 15; walls restitution 0.3, friction 0.1.
"""
import math, random, sys
import pymunk
import nl_layout as L

G = 900.0           # CHOMP!: gravity -6.0 x 150 pt/m
random.seed(7)

def build(flippers="rest"):
    space = pymunk.Space()
    space.gravity = (0, -G)
    body = space.static_body
    for name, part in L.floor_parts().items():
        if part[0] == "poly":
            pts = part[1]
            for a, b in zip(pts, pts[1:]):
                s = pymunk.Segment(body, a, b, 1.0)
                s.elasticity, s.friction, s.part = 0.3, 0.1, name
                space.add(s)
        else:
            s = pymunk.Circle(body, part[2], part[1])
            s.elasticity, s.friction, s.part = 0.3, 0.1, name
            space.add(s)
    for pv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        raised = L.FLIP_TRAVEL if flippers == "up" else 0.0
        tip, poly = L.flipper_poly(pv, side, raised)
        for shape in (pymunk.Poly(body, poly), pymunk.Circle(body, L.FLIP_RP, pv), pymunk.Circle(body, L.FLIP_RT, tip)):
            shape.elasticity, shape.friction, shape.part = 0.3, 0.4, f"flipper {side}"
            space.add(shape)
    return space

def ball(space, pos, vel):
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, L.BALL_R))
    b.position, b.velocity = pos, vel
    s = pymunk.Circle(b, L.BALL_R)
    s.elasticity, s.friction = 1.0, 0.1
    space.add(b, s)
    return b, s

def first_contacts(space, bshape, b, steps, stop):
    hits, path = [], []
    for i in range(steps):
        space.step(1 / 240)
        path.append((b.position.x, b.position.y))
        for info in space.shape_query(bshape):
            nm = getattr(info.shape, "part", None)
            if nm and (not hits or hits[-1] != nm):
                hits.append(nm)
        r = stop(b, path)
        if r:
            return r, hits, path
    return "timeout", hits, path

def outcome(sp, s, b, secs=8):
    """First of: touches a flipper / enters an outlane / drains down the centre / still moving."""
    def stop(b, path):
        x, y = b.position
        for info in sp.shape_query(s):
            if getattr(info.shape, "part", "").startswith("flipper"):
                return "flipper"
        if y < 300 and (x < L.GUIDE_X or x > 2 * L.CX - L.GUIDE_X):
            return "outlane"
        if y < 130:
            return "centre drain"
    r, hits, path = first_contacts(sp, s, b, int(240 * secs), stop)
    return r, hits

def tally(rows):
    out = {}
    for r in rows:
        out[r] = out.get(r, 0) + 1
    return out

def test_top_drop(n=300):
    rows = []
    for _ in range(n):
        sp = build()
        b, s = ball(sp, (L.CX + random.uniform(-8, 8), 1005.0), (random.uniform(-20, 20), -random.uniform(0, 300)))
        rows.append(outcome(sp, s, b)[0])
    return tally(rows)

def test_entry(n=200):
    rows = []
    for _ in range(n):
        sp = build()
        b, s = ball(sp, L.ENTRY_RELEASE_L, (random.uniform(-20, 20), -random.uniform(150, 800)))
        rows.append(outcome(sp, s, b)[0])
    return tally(rows)

def test_up(n=200, side="L"):
    """The rise is scripted (collisions off) up to UP_RELEASE; from there, the pop with +-8% speed / +-25 pt/s jitter."""
    rows, firsts = [], []
    vx, vy = L.UP_POP[side]
    for _ in range(n):
        sp = build()
        b, s = ball(sp, (L.UP_RELEASE[0] + random.uniform(-3, 3), L.UP_RELEASE[1]),
                    (vx + random.uniform(-25, 25), vy * random.uniform(0.92, 1.08)))
        r, hits = outcome(sp, s, b)
        rows.append(r)
        firsts.append(hits[0] if hits else "-")
    return tally(rows), tally(firsts)

if __name__ == "__main__":
    print("B) return-wire release in the inlane:", test_entry(400))
    for sd in ("L", "R"):
        print(f"C) rise through the drain, pop {sd}:", *test_up(side=sd))
