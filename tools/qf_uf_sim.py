"""pymunk checks for M1 round 2's upper flipper (Quest & Flipper, Table 09). CHOMP!'s physics (gravity 900, ball r 15,
walls 0.3 restitution, 1/120 s steps). The upper flipper is static at rest (feed test) or released balls are fired off
its face (shot test); slings, the main flippers and the wisps' motion aren't simulated.

1. Feed: orbit balls riding the arch clockwise from the top (x 400-460 along the arch, 500-1400 pt/s), with the
   diverter raised and lowered. Outcome: ON = ends resting on the upper flipper; OFF TIP = touched it, then rolled off
   its tip; LANE = never touched it (down the launch gate / right lane); GLADE = dropped back into the glade.
2. Shots: balls leaving the flipper's face (the line from pivot to tip, raised 0-51 deg) at 1,200-1,800 pt/s,
   perpendicular to the face; which wisp loop centre (a static r 13 disc) each meets first, or the wall it hits.
"""
import math, random
import pymunk
import qf_layout as L

G, STEP = 900.0, 1 / 120

def build(sp, diverter=True, uf_raised=0.0, wisps=False):
    P = L.floor_parts(mode_parts=False)
    P = {k: v for k, v in P.items() if not k.startswith("upper flipper")}
    if diverter:
        P["diverter"] = ("poly", [L.DIVERTER_A, L.DIVERTER_B])
    for nm, part in P.items():
        if part[0] == "poly":
            for a, b in zip(part[1], part[1][1:]):
                s = pymunk.Segment(sp.static_body, a, b, 0.5); s.elasticity, s.friction = 0.3, 0.1; sp.add(s)
        else:
            c = pymunk.Circle(sp.static_body, part[2], part[1]); c.elasticity, c.friction = 0.3, 0.1; sp.add(c)
    tip, poly = L.uf_poly(uf_raised)
    shapes = [pymunk.Poly(sp.static_body, poly), pymunk.Circle(sp.static_body, L.UF_RP, L.UF_PIVOT),
              pymunk.Circle(sp.static_body, L.UF_RT, tip)]
    for s in shapes:
        s.elasticity, s.friction, s.collision_type = 0.3, 0.4, 7
        sp.add(s)
    if wisps:
        for i, (c, _, _) in enumerate(L.WISPS):
            w = pymunk.Circle(sp.static_body, L.WISP_R, c); w.elasticity, w.collision_type = 0.6, 10 + i; sp.add(w)

def ball(sp, pos, vel):
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, L.BALL_R)); b.position, b.velocity = pos, vel
    s = pymunk.Circle(b, L.BALL_R); s.elasticity, s.friction, s.collision_type = 0.1, 0.1, 1
    sp.add(b, s); return b

def near_uf(p, tip, poly):
    def sd(p, a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        return math.dist(p, (a[0] + dx * t, a[1] + dy * t))
    d = min(sd(p, poly[i], poly[(i + 1) % 4]) for i in range(4))
    d = min(d, math.dist(p, L.UF_PIVOT) - L.UF_RP, math.dist(p, tip) - L.UF_RT)
    return d < L.BALL_R + 2

def arch_start(x):
    # a point riding the arch's inner side (16 pt in) and the clockwise tangent there
    y = L.right_arch_y(x) if x > L.ARCH_MID_X else L.TOP_Y
    x2 = x + 2; y2 = L.right_arch_y(x2) if x2 > L.ARCH_MID_X else L.TOP_Y
    t = (x2 - x, y2 - y); n = math.hypot(*t); t = (t[0] / n, t[1] / n)
    return (x - t[1] * -16, y - 16 * t[0]), t

def feed(diverter, n=40, seed=4):
    random.seed(seed)
    out = {"ON": 0, "OFF TIP": 0, "LANE": 0, "GLADE": 0}
    for _ in range(n):
        sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
        build(sp, diverter=diverter)
        x = random.uniform(400, 460); spd = random.uniform(500, 1400)
        p, t = arch_start(x)
        b = ball(sp, p, (t[0] * spd, t[1] * spd))
        touched = {"uf": False}
        tip, poly = L.uf_poly()
        res, still = "GLADE", 0.0
        for _ in range(int(5 / STEP)):
            sp.step(STEP)
            q = b.position
            if not touched["uf"] and near_uf((q.x, q.y), tip, poly):
                touched["uf"] = True
            if b.velocity.length < 15:
                still += STEP
                if still > 0.5:
                    res = "ON" if touched["uf"] and q.y > 1150 and q.x > 470 else res
                    break
            else:
                still = 0
            if q.y < 1050:
                res = ("OFF TIP" if touched["uf"] else "LANE") if q.x > 470 else ("OFF TIP" if touched["uf"] else "GLADE")
                break
        out[res] += 1
    return out

def shots():
    rows = []
    tip0, _ = L.uf_poly()
    for raised_deg in (10, 20, 30, 40, 51):
        r = math.radians(raised_deg)
        tip, _ = L.uf_poly(r)
        a = math.atan2(tip[1] - L.UF_PIVOT[1], tip[0] - L.UF_PIVOT[0])       # pivot -> tip heading
        normal = a - math.pi / 2                                            # the up-left side (heading ~120 at rest)
        for along in (0.45, 0.7):
            start = (L.UF_PIVOT[0] + (tip[0] - L.UF_PIVOT[0]) * along + math.cos(normal) * (L.BALL_R + 7),
                     L.UF_PIVOT[1] + (tip[1] - L.UF_PIVOT[1]) * along + math.sin(normal) * (L.BALL_R + 7))
            for spd in (1200, 1800):
                sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
                build(sp, diverter=False, uf_raised=r, wisps=True)
                d = normal
                b = ball(sp, start, (math.cos(d) * spd, math.sin(d) * spd))
                hit = {"w": None}
                for _ in range(int(2 / STEP)):
                    sp.step(STEP)
                    q = b.position
                    for i, (c, _, _) in enumerate(L.WISPS):
                        if math.dist((q.x, q.y), c) < L.WISP_R + L.BALL_R + 1.5 and hit["w"] is None:
                            hit["w"] = f"wisp {i + 1}"
                    if hit["w"] or b.position.y < 1050: break
                rows.append((raised_deg, along, spd, round(math.degrees(d) % 360, 1), hit["w"] or "-"))
    return rows

if __name__ == "__main__":
    print("FEED, diverter raised:", feed(True))
    print("FEED, diverter lowered:", feed(False))
    print("SHOTS (flipper raised deg, along the face, speed, heading, first wisp hit):")
    for r in shots():
        print("  ", r)
