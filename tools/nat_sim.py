"""pymunk checks for The Naturalist's field station sketch (Table 11). Real-scale physics as on CHOMP!/Neon/Quest:
gravity 900 pt/s^2, ball r 15 (restitution 0.1, friction 0.1), walls restitution 0.3 (SpriteKit takes the higher of
the pair), 1/120 s steps. Flippers are static at rest, slings passive, the launch gate solid (only orbits meet it
here), bumpers kick 900 pt/s outward on contact. The sky ramp's climb is not simulated: crossing its entry switch
going up counts as a ramp shot.

  fan      the curved shot fan: launches from each sweet spot at 40-130 deg (0.25 deg steps) at 1,200 and 1,600 pt/s;
           what each shot does first (the switch rules of the future scene).
  orbits   every cave / grove shot in its window followed on: does it go round, and where does it come down?
  lily     every lily-pad shot followed back out of the pond: where does it land?
  reed     the Reed Bed's risk (Quest's Old Well test): in / left outlane / back in play.
  stuck    1,000 balls dropped anywhere in the upper table at 0-600 pt/s: any that come to rest outside a catch zone.
"""
import math, random, sys, json
import pymunk
import nat_layout as L

G = 900.0
STEP = 1 / 120
BUMPER_KICK = 900.0


def build(space, mode_parts=False, pads=None):
    P = L.floor_parts(mode_parts=False)
    for nm, part in P.items():
        if part[0] == "poly":
            for a, b in zip(part[1], part[1][1:]):
                s = pymunk.Segment(space.static_body, a, b, 0.5)
                s.elasticity, s.friction = 0.3, 0.1
                space.add(s)
        elif part[0] == "circle":
            c = pymunk.Circle(space.static_body, part[2], part[1])
            c.elasticity, c.friction = 0.3, 0.1
            space.add(c)
    for piv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, poly = L.flipper_poly(piv, side)
        s = pymunk.Poly(space.static_body, poly)
        s.elasticity, s.friction = 0.3, 0.4
        space.add(s, pymunk.Circle(space.static_body, L.FLIP_RP, piv), pymunk.Circle(space.static_body, L.FLIP_RT, tip))
    for p in pads or []:
        c = pymunk.Circle(space.static_body, L.CREATURE_R, p)
        c.elasticity, c.friction = 0.3, 0.1
        space.add(c)


def new_space(**kw):
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
    build(sp, **kw)
    return sp


def ball(space, pos, vel):
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, L.BALL_R))
    b.position, b.velocity = pos, vel
    s = pymunk.Circle(b, L.BALL_R)
    s.elasticity, s.friction = 0.1, 0.1
    space.add(b, s)
    return b


def bump(b):
    for c in L.BUMPERS:
        d = math.dist(b.position, c)
        if d < L.BUMPER_R + L.BALL_R + 1.0:
            u = ((b.position.x - c[0]) / d, (b.position.y - c[1]) / d)
            b.velocity = (u[0] * BUMPER_KICK, u[1] * BUMPER_KICK)
            return True
    return False


def crossed_up(prev, p, y):
    return prev[1] < y <= p[1]


def event(prev, p):
    """The future scene's switch rules, first one hit."""
    ax, ay = prev; dx, dy = p[0] - ax, p[1] - ay
    t = 0 if dx == dy == 0 else max(0, min(1, ((L.REED_HOLE[0] - ax) * dx + (L.REED_HOLE[1] - ay) * dy) / (dx * dx + dy * dy)))
    if math.dist((ax + dx * t, ay + dy * t), L.REED_HOLE) < L.REED_CAPTURE_R:
        return "Reed Bed scoop"
    if crossed_up(prev, p, 830) and p[0] < L.CAVE_INNER_X:
        return "Cave orbit"
    if crossed_up(prev, p, L.LILY_SWITCH_Y) and L.LILY_L_X < p[0] < L.LILY_R_X:
        return "Lily-pad lane"
    if crossed_up(prev, p, L.CABIN_CATCH_Y) and L.CABIN_L_X < p[0] < L.CABIN_R_X:
        return "Specimen scoop"
    if crossed_up(prev, p, L.RAMP_MOUTH_Y + 12) and abs(p[0] - L.RAMP_C_X) < L.RAMP_MOUTH_HALF:
        return "Sky ramp"
    if crossed_up(prev, p, L.GROVE_SWITCH_Y) and p[0] > L.GROVE_INNER_X:
        return "Grove lane"
    return None


def launch(sp_pt, ang, spd, space=None):
    space = space or new_space()
    u = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
    b = ball(space, sp_pt, (spd * u[0], spd * u[1]))
    return space, b


def fly(space, b, seconds=3.0, stop_on_event=True, track=None):
    prev = (b.position.x, b.position.y)
    risen = False
    for _ in range(int(seconds / STEP)):
        space.step(STEP)
        bump(b)
        p = (b.position.x, b.position.y)
        if track is not None:
            track.append(p)
        e = event(prev, p)
        if e and stop_on_event:
            return e, p
        risen = risen or p[1] > 500
        if risen and p[1] < 330:
            return None, p
        prev = p
    return None, (b.position.x, b.position.y)


SWEETS = {"left": L.SWEET_L, "right": L.SWEET_R}


def fan(speeds=(1600, 2000), lo=40.0, hi=130.0, step=0.25):
    res = {}
    for fl, spt in SWEETS.items():
        for spd in speeds:
            row = []
            a = lo
            while a <= hi + 1e-9:
                sp, b = launch(spt, a, spd)
                e, _ = fly(sp, b)
                row.append((round(a, 2), e))
                a += step
            res[(fl, spd)] = row
    return res


def windows(row):
    """Contiguous angle runs per event -> {event: [(a0, a1), ...]}."""
    out = {}
    cur, start, last = None, None, None
    for a, e in row + [(999, "_end")]:
        if e != cur:
            if cur:
                out.setdefault(cur, []).append((start, last))
            cur, start = e, a
        last = a
    return out


def follow(fl, ang, spd, seconds=7.0):
    """Follow a shot past its first event (orbit round the top, pond back out): where does it come down?"""
    sp, b = launch(SWEETS[fl], ang, spd)
    first = None
    prev = (b.position.x, b.position.y)
    path = []
    for _ in range(int(seconds / STEP)):
        sp.step(STEP)
        bump(b)
        p = (b.position.x, b.position.y)
        path.append(p)
        e = event(prev, p)
        if e and not first:
            first = e
        if first and p[1] < 440:
            x = p[0]
            where = ("left outlane" if x < L.GUIDE_X else "left inlane" if x < L.SLING_X else
                     "right outlane" if x > L.M((L.GUIDE_X, 0))[0] else "right inlane" if x > L.M((L.SLING_X, 0))[0]
                     else "left half" if x < L.CX else "right half")
            return first, where, path
        prev = p
    return first, "still up", path


def orbit_round(fl, ang, spd):
    """Did an orbit shot go round? cave: came back down the grove lane; grove: came down the cave lane."""
    first, where, path = follow(fl, ang, spd)
    top = max(p[1] for p in path) if path else 0
    if first == "Cave orbit":
        made = any(p[0] > L.GROVE_INNER_X and p[1] < 1000 for p in path[len(path) // 4:]) and top > 1250
    elif first == "Grove lane":
        made = any(p[0] < L.CAVE_INNER_X and p[1] < 1000 for p in path[len(path) // 4:]) and top > 1250
    else:
        made = False
    return first, made, where


def reed_trials():
    out = {"in": 0, "outlane L": 0, "play": 0}
    by = {}
    for ang in range(116, 137, 2):
        for spd in (1600, 2000, 2400):
            sp, b = launch(L.SWEET_R, ang, spd)
            res, prev, risen = "play", (b.position.x, b.position.y), False
            for _ in range(int(4 / STEP)):
                sp.step(STEP)
                p = (b.position.x, b.position.y)
                if event(prev, p) == "Reed Bed scoop":
                    res = "in"; break
                if p[0] < 70 and p[1] < 470:
                    res = "outlane L"; break
                risen = risen or p[1] > 500
                if risen and p[1] < 300:
                    break
                prev = p
            out[res] += 1
            by.setdefault(ang, []).append({"in": "I", "outlane L": "X", "play": "P"}[res])
    return out, by


def in_table(p):
    x, y = p
    if not (L.WALL_L + L.BALL_R < x < L.WALL_R - L.BALL_R):
        return False
    if y > 1150:
        # under the arch: keep a ball clear of it (rough: the arch's x at this y)
        t = (y - 1150) / 180
        inset = 180 * (1 - math.sqrt(max(0, 1 - t)))
        if x < L.WALL_L + inset + 20 or x > L.SHOOT_OUT - inset - 20 or y > 1312:
            return False
    if L.point_in_poly(p, L.island()):
        return False
    for b in L.BUMPERS:
        if math.dist(p, b) < L.BUMPER_R + L.BALL_R + 2:
            return False
    if math.dist(p, L.REED_HOLE) < 60:
        return False
    # start a ball clear of every wall (a ball dropped overlapping a wall can be pushed inside a solid)
    for nm, part in _PARTS.items():
        if part[0] == "poly":
            for a, b in zip(part[1], part[1][1:]):
                if _seg_d(p, a, b) < L.BALL_R + 1.5:
                    return False
        elif part[0] == "circle" and math.dist(p, part[1]) < part[2] + L.BALL_R + 1.5:
            return False
    return True


_PARTS = L.floor_parts(mode_parts=False)


def _seg_d(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(p, (a[0] + dx * t, a[1] + dy * t))


def catch_zone(p):
    x, y = p
    if L.CABIN_L_X < x < L.CABIN_R_X and L.CABIN_CATCH_Y < y < L.CABIN_BACK_Y + 20:
        return "specimen scoop"
    if x < 70 and 560 < y < 720:
        return "reed bed"
    return None


def stuck_test(n=1000, seed=11, pads=None):
    random.seed(seed)
    stuck, caught, rows = 0, 0, []
    for i in range(n):
        while True:
            p = (random.uniform(30, 570), random.uniform(480, 1310))
            if in_table(p) and not (pads and any(math.dist(p, q) < L.CREATURE_R + L.BALL_R + 2 for q in pads)):
                break
        sp = new_space(pads=pads)
        a = random.uniform(0, 2 * math.pi); s = random.uniform(0, 600)
        b = ball(sp, p, (s * math.cos(a), s * math.sin(a)))
        slow = 0.0
        for _ in range(int(8 / STEP)):
            sp.step(STEP)
            bump(b)
            q = (b.position.x, b.position.y)
            if catch_zone(q):
                caught += 1; break
            if q[1] < 330:
                break
            if b.velocity.length < 5:
                slow += STEP
                if slow > 2.0:
                    stuck += 1; rows.append((p, q)); break
            else:
                slow = 0.0
    return stuck, caught, n, rows


if __name__ == "__main__":
    what = sys.argv[1:] or ["fan", "orbits", "lily", "reed", "stuck"]
    report = {}
    if "fan" in what or "orbits" in what or "lily" in what:
        F = fan()
        report["fan"] = {f"{fl} {spd}": windows(row) for (fl, spd), row in F.items()}
        print("CURVED FAN (first event by launch angle, deg)")
        for (fl, spd), row in F.items():
            w = windows(row)
            print(f"  {fl} @ {spd}:")
            for e, runs in sorted(w.items(), key=lambda kv: kv[1][0][0]):
                if e is None:
                    continue
                tot = sum(b - a + 0.25 for a, b in runs)
                print(f"     {e:16s} {', '.join(f'{a:.2f}-{b:.2f}' for a, b in runs)}   ({tot:.2f} deg)")
    if "orbits" in what:
        print("ORBITS followed on (every launch in the cave / grove windows)")
        res = {}
        for (fl, spd), row in F.items():
            for a, e in row:
                if e in ("Cave orbit", "Grove lane"):
                    first, made, where = orbit_round(fl, a, spd)
                    k = (e, fl, spd)
                    r = res.setdefault(k, {"n": 0, "round": 0, "fell back": 0, "lands": {}})
                    r["n"] += 1
                    r["round" if made else "fell back"] += 1
                    r["lands"][where] = r["lands"].get(where, 0) + 1
        for k, r in res.items():
            print(f"  {k[0]:11s} from {k[1]:5s} @ {k[2]}: {r['round']}/{r['n']} round the top; lands {r['lands']}")
        report["orbits"] = {f"{k[0]} {k[1]} {k[2]}": r for k, r in res.items()}
    if "lily" in what:
        print("LILY-PAD LANE shots followed back out (pads empty / frog on each pad)")
        for pads, lab in ((None, "no frog"), ([L.LILY_PADS[0]], "frog on pad 1"), ([L.LILY_PADS[1]], "frog on pad 2"),
                          ([L.LILY_PADS[2]], "frog on pad 3")):
            lands, n, hits = {}, 0, 0
            for (fl, spd), row in F.items():
                for a, e in row:
                    if e != "Lily-pad lane":
                        continue
                    sp = new_space(pads=pads)
                    u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
                    b = ball(sp, SWEETS[fl], (spd * u[0], spd * u[1]))
                    where, hit = "still up", False
                    for _ in range(int(7 / STEP)):
                        sp.step(STEP)
                        q = (b.position.x, b.position.y)
                        if pads and math.dist(q, pads[0]) < L.CREATURE_R + L.BALL_R + 2:
                            hit = True
                        if q[1] > 900:
                            pass
                        if q[1] < 440 and b.velocity.y < 0:
                            x = q[0]
                            where = ("left outlane" if x < L.GUIDE_X else "left inlane" if x < L.SLING_X else
                                     "left flipper side" if x < L.CX else "right flipper side")
                            break
                    n += 1; hits += hit
                    lands[where] = lands.get(where, 0) + 1
            print(f"  {lab:14s}: {n} shots; lands {lands}" + (f"; frog hit {hits}/{n}" if pads else ""))
    if "reed" in what:
        out, by = reed_trials()
        print("REED BED from the right flipper (33 shots, 116-136 deg x 1600/2000/2400):", out)
        for a, r in by.items():
            print(f"  {a} deg: {' '.join(r)}   (I = in, X = left outlane, P = back in play)")
        report["reed"] = out
    if "stuck" in what:
        s, c, n, rows = stuck_test()
        print(f"STUCK TEST: {s}/{n} came to rest outside a catch zone ({c} caught by a scoop)")
        for p, q in rows[:20]:
            print(f"   dropped ({p[0]:.0f}, {p[1]:.0f}) -> rests ({q[0]:.0f}, {q[1]:.0f})")
        s2, c2, n2, rows2 = stuck_test(500, seed=12, pads=[L.LILY_PADS[1]])
        print(f"STUCK TEST with the frog on pad 2: {s2}/{n2}")
        for p, q in rows2[:10]:
            print(f"   dropped ({p[0]:.0f}, {p[1]:.0f}) -> rests ({q[0]:.0f}, {q[1]:.0f})")
        report["stuck"] = [s, n, [list(q) for _, q in rows]]
    json.dump(report, open("/home/claude/nat/out/nat_sim_report.json", "w"), indent=1, default=str)
