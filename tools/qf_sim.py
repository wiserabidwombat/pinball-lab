"""pymunk checks for the Haunted Forest sketch (Quest & Flipper, Table 09). CHOMP!'s physics: gravity 900 pt/s^2,
ball r 15, walls restitution 0.3 (SpriteKit takes the higher of the pair), friction 0.1, 1/120 s steps.
Flippers and slings are not simulated (passive walls); targets are walls.

1. Old Well risk: shots from the right flipper's sweet spot at the well, 116-136 deg, 1,600-2,400 pt/s.
   In = the ball's path passes within the capture radius of the hole. Outlane = it crosses into the left outlane
   (x < 70 below y 470). Otherwise it comes back into play.
2. Bark slots: balls fired into the Treant's clearing with one drop down (each of the three in turn); stuck = still
   moving < 5 pt/s after 4 s anywhere in the clearing.
"""
import math, random
import pymunk
import qf_layout as L

G = 900.0
STEP = 1 / 120

def build(space, bark_down=None, mode_parts=False):
    P = L.floor_parts(mode_parts=mode_parts)
    for nm, part in P.items():
        if nm.startswith("flipper pivot"):
            pass
        if bark_down is not None and nm == f"bark {bark_down}":
            continue
        if part[0] == "poly":
            pts = part[1]
            for a, b in zip(pts, pts[1:]):
                s = pymunk.Segment(space.static_body, a, b, 0.5)
                s.elasticity, s.friction = 0.3, 0.1
                space.add(s)
        else:
            c = pymunk.Circle(space.static_body, part[2], part[1])
            c.elasticity, c.friction = 0.3, 0.1
            space.add(c)
    # the flippers at rest, as static shapes
    for piv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, poly = L.flipper_poly(piv, side)
        s = pymunk.Poly(space.static_body, poly)
        s.elasticity, s.friction = 0.3, 0.4
        space.add(s, pymunk.Circle(space.static_body, L.FLIP_RP, piv), pymunk.Circle(space.static_body, L.FLIP_RT, tip))

def ball(space, pos, vel):
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, L.BALL_R))
    b.position, b.velocity = pos, vel
    s = pymunk.Circle(b, L.BALL_R)
    s.elasticity, s.friction = 0.1, 0.1
    space.add(b, s)
    return b

def well_trials():
    out = {"in": 0, "outlane L": 0, "play": 0}
    by_angle = {}
    for ang in range(116, 137, 2):
        for spd in (1600, 2000, 2400):
            sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
            build(sp)
            v = (spd * math.cos(math.radians(ang)), spd * math.sin(math.radians(ang)))
            u = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
            b = ball(sp, (L.SWEET_R[0] + 30 * u[0], L.SWEET_R[1] + 30 * u[1]), v)
            res = "play"
            prev = b.position
            risen = False
            for _ in range(int(4 / STEP)):
                sp.step(STEP)
                p = b.position
                # path test (the scoop rule)
                ax, ay = prev; bx, by = p
                dx, dy = bx - ax, by - ay
                t = 0 if dx == dy == 0 else max(0, min(1, ((L.WELL_HOLE[0] - ax) * dx + (L.WELL_HOLE[1] - ay) * dy) / (dx * dx + dy * dy)))
                if math.dist((ax + dx * t, ay + dy * t), L.WELL_HOLE) < L.WELL_CAPTURE_R:
                    res = "in"; break
                if p.x < 70 and p.y < 470:
                    res = "outlane L"; break
                risen = risen or p.y > 500
                if risen and p.y < 300:
                    break
                prev = (p.x, p.y)
            out[res] += 1
            by_angle.setdefault(ang, []).append(res[0].upper() if res != "outlane L" else "X")
    return out, by_angle

def bark_trials(n=60, seed=3):
    random.seed(seed)
    rows = {}
    for down in (1, 2, 3):
        stuck = 0
        for _ in range(n):
            sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
            build(sp, bark_down=down)
            x = random.uniform(L.TREANT_L_X + 20, L.TREANT_R_X - 20)
            ang = math.radians(random.uniform(70, 110)); spd = random.uniform(500, 1600)
            b = ball(sp, (x, L.TREANT_MOUTH_Y - 10), (spd * math.cos(ang), spd * math.sin(ang)))
            slow = 0.0
            for _ in range(int(6 / STEP)):
                sp.step(STEP)
                if b.velocity.length < 5 and b.position.y > L.TREANT_MOUTH_Y:
                    slow += STEP
                    if slow > 2.0:
                        stuck += 1; break
                else:
                    slow = 0.0
                if b.position.y < 700:
                    break
        rows[down] = (stuck, n)
    return rows

if __name__ == "__main__":
    out, by = well_trials()
    print("OLD WELL from the right flipper (33 shots, 116-136 deg x 1600/2000/2400 pt/s):", out)
    for a, r in by.items():
        print(f"  {a} deg: {' '.join(r)}   (I = in, X = left outlane, P = back in play)")
    print("BARK SLOTS (one drop down, 60 balls each, stuck = resting > 2 s in the clearing):")
    for d, (s, n) in bark_trials().items():
        print(f"  bark {d} down: {s}/{n} stuck")

def orbit_drops(n=60, seed=5):
    """Balls coming back DOWN the Graveyard lane (a weak orbit shot that falls back): where do they end up?"""
    random.seed(seed)
    out = {"left outlane": 0, "left inlane / flipper": 0, "well": 0, "other": 0}
    for _ in range(n):
        sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
        build(sp)
        b = ball(sp, (random.uniform(36, 56), 1000), (random.uniform(-40, 40), -random.uniform(0, 700)))
        res, prev = "other", b.position
        for _ in range(int(5 / STEP)):
            sp.step(STEP)
            p = b.position
            ax, ay = prev; dx, dy = p.x - ax, p.y - ay
            t = 0 if dx == dy == 0 else max(0, min(1, ((L.WELL_HOLE[0] - ax) * dx + (L.WELL_HOLE[1] - ay) * dy) / (dx * dx + dy * dy)))
            if math.dist((ax + dx * t, ay + dy * t), L.WELL_HOLE) < L.WELL_CAPTURE_R:
                res = "well"; break
            if p.y < 460:
                res = "left outlane" if p.x < 72 else ("left inlane / flipper" if p.x < 140 else "other")
                break
            prev = (p.x, p.y)
        out[res] += 1
    return out

if __name__ == "__main__":
    print("GRAVEYARD LANE fall-backs (60 balls dropped down the lane from y 1000):", orbit_drops())
