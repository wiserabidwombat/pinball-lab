"""Gap checks, the straight shot fan and straight-line clearance for The Naturalist's field station (Table 11).
Same method as qf_checks.py / nl_checks.py. Run alone to print the tables; the render imports it."""
import math
import nat_layout as L


def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    q = (ax + dx * t, ay + dy * t)
    return math.dist(p, q), q


def _cross(a, b, c, d):
    def o(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    return o(a, b, c) * o(a, b, d) < 0 and o(c, d, a) * o(c, d, b) < 0


def segseg(a, b, c, d):
    if _cross(a, b, c, d):
        return (0.0, a, a)
    best = (1e9, None, None)
    for p, (s0, s1), other in ((a, (c, d), 0), (b, (c, d), 0), (c, (a, b), 1), (d, (a, b), 1)):
        dist, q = seg_dist(p, s0, s1)
        if dist < best[0]:
            best = (dist, p, q) if other == 0 else (dist, q, p)
    return best


def segments(part):
    if part[0] == "poly":
        pts = part[1]
        return [(pts[i], pts[i + 1]) for i in range(len(pts) - 1)], 0.0
    if part[0] == "capsule":
        a, b = part[1]
        return [(a, b)], part[2]
    c, r = part[1], part[2]
    return [(c, c)], r


def gap(pa, pb):
    sa, ra = segments(pa)
    sb, rb = segments(pb)
    best = (1e9, None, None)
    for a, b in sa:
        for c, d in sb:
            dist, p, q = segseg(a, b, c, d)
            if dist < best[0]:
                best = (dist, p, q)
    dist, p, q = best
    if p is not None and dist > 0:
        ux, uy = (q[0] - p[0]) / dist, (q[1] - p[1]) / dist
        p = (p[0] + ux * ra, p[1] + uy * ra)
        q = (q[0] - ux * rb, q[1] - uy * rb)
    return dist - ra - rb, p, q


def verdict(g, kind="auto"):
    if g <= 1.0:
        return "joined"
    if kind == "passage":
        return "OK" if g >= L.PASSAGE_MIN else ("WEDGE RISK" if g >= L.CLOSED_MAX else "TOO NARROW")
    if g < L.CLOSED_MAX:
        return "closed"
    if g < L.PASSAGE_MIN:
        return "WEDGE RISK"
    return "open"


def J(*pairs):
    return {frozenset(p) for p in pairs}


JOINED_OK = set()
for s in "LR":
    JOINED_OK |= J((f"sling {s}", f"sling top post {s}"), (f"sling {s}", f"sling tip post {s}"),
                   (f"lane guide {s}", f"lane guide post {s}"), (f"outlane post {s}", f"outlane post rail {s}"),
                   (f"lane guide post {s}", f"outlane post rail {s}"), (f"lane guide {s}", f"outlane post rail {s}"),
                   (f"lane guide post {s}", f"outlane post {s}"), (f"lane guide {s}", f"outlane post {s}"),
                   (f"lane guide {s}", f"outlane wall {s}"), (f"lane guide {s}", f"flipper pivot {s}"))
JOINED_OK |= J(("reed bed lower rim", "reed post lo"), ("reed bed roof", "reed post hi"), ("reed bed lower rim", "outer wall"),
               ("reed bed roof", "outer wall"), ("island", "cave post"), ("island", "lily post L"), ("island", "lily post R"),
               ("island", "cabin post L"), ("island", "cabin post R"), ("island", "ramp post L"), ("island", "ramp post R"),
               ("island", "grove post"), ("launch gate", "outer wall"), ("launch gate", "right wall"),
               ("right wall", "outer wall"), ("shooter lane wall", "outer wall"), ("shooter lane wall", "right wall"),
               # on opposite sides of the shooter lane's inner wall
               ("launch gate", "island"))
# the frog's pads are one creature in three places, never all at once
JOINED_OK |= J(("frog on pad 1 (mode)", "frog on pad 2 (mode)"), ("frog on pad 2 (mode)", "frog on pad 3 (mode)"),
               ("frog on pad 1 (mode)", "frog on pad 3 (mode)"))


def named_passages():
    P = L.floor_parts()
    out = []

    def add(name, a, b, kind="passage"):
        g, p, q = gap(P[a] if isinstance(a, str) else a, P[b] if isinstance(b, str) else b)
        out.append((name, g, verdict(g, kind), p, q))

    for s in ("L", "R"):
        f = (lambda p: p) if s == "L" else L.M
        wall = "outer wall" if s == "L" else "right wall"
        add(f"outlane {s}: mouth (outlane post to wall)", f"outlane post {s}", wall)
        add(f"outlane {s}: under the pivot to slope", f"flipper pivot {s}", wall)
        add(f"outlane {s}: guide corner to slope", ("circle", f(L.GUIDE_BEND_L), 0.0), P[wall])
        add(f"outlane {s}: guide slant to slope (narrowest)", ("poly", [f(L.GUIDE_BEND_L), f(L.GUIDE_END_L)]), P[wall])
        add(f"inlane {s}: guide post to sling top post", f"lane guide post {s}", f"sling top post {s}")
        add(f"inlane {s}: guide to sling tip post", f"sling tip post {s}", f"lane guide {s}")
    add("drain: flipper tips at rest", ("circle", L.TIP_L_REST, L.FLIP_RT), ("circle", L.TIP_R_REST, L.FLIP_RT))
    add("Reed Bed: mouth (rim posts)", "reed post lo", "reed post hi")
    add("Reed Bed: upper rim post to outlane post L", "reed post hi", "outlane post L", "auto")
    add("Reed Bed: lower rim to lane guide post L", "reed bed lower rim", "lane guide post L", "auto")
    add("Cave orbit: lane (wall to cave post)", "cave post", "outer wall")
    add("Cave orbit: lane (island edge to wall)", ("poly", [(L.CAVE_INNER_X, 800), (L.CAVE_INNER_X, 1140)]), P["outer wall"])
    add("Cave orbit: top (island corner to arch)", ("circle", L.ROOF_L, 0.0), P["outer wall"])
    add("Cave orbit: reed roof to cave post", "reed bed roof", "cave post", "auto")
    add("Lily-pad lane: mouth (posts)", "lily post L", "lily post R")
    add("Lily-pad lane: neck", ("poly", [(L.LILY_L_X, 810), (L.LILY_L_X, L.LILY_NECK_Y)]),
        ("poly", [(L.LILY_R_X, 810), (L.LILY_R_X, L.LILY_NECK_Y)]))
    add("Lily post R to cabin post L", "lily post R", "cabin post L", "auto")
    add("Specimen channel: mouth (posts)", "cabin post L", "cabin post R")
    add("Cabin post R to ramp post L", "cabin post R", "ramp post L", "auto")
    add("Sky ramp: mouth (posts)", "ramp post L", "ramp post R")
    add("Ramp post R to grove post", "ramp post R", "grove post", "auto")
    add("Grove lane: mouth (post to right wall)", "grove post", "right wall")
    add("Grove lane: island edge to right wall", ("poly", [(L.GROVE_INNER_X, 830), (L.GROVE_INNER_X, 1090)]), P["right wall"])
    add("Grove lane top: island corner to launch gate", ("circle", L.ROOF_R, 0.0), P["launch gate"])
    add("Grove branch: right end to outer wall (orbits down, plunges up)", ("circle", L.BRANCH[0], 0.0), P["outer wall"])
    add("Grove branch: right end to launch gate", "grove branch", "launch gate")
    add("Grove branch: left end to island roof corner", ("circle", L.BRANCH[1], 0.0), P["island"])
    add("Grove branch to bumper 3", "grove branch", "bumper 3")
    add("Canopy: island roof to arch (narrowest)", ("poly", [L.ROOF_L, L.ROOF_R]), P["outer wall"])
    add("shooter lane (inner to outer wall)", ("poly", [(L.SHOOT_IN, 300), (L.SHOOT_IN, 1000)]),
        ("poly", [(L.SHOOT_OUT, 300), (L.SHOOT_OUT, 1000)]))
    add("plunge exit: launch gate top to arch", ("circle", L.LAUNCH_GATE[1], 0.0), P["outer wall"])
    for i in range(3):
        add(f"bumper {i + 1} to arch", f"bumper {i + 1}", "outer wall")
        add(f"bumper {i + 1} to island roof", f"bumper {i + 1}", "island")
    add("bumpers 1-2", "bumper 1", "bumper 2")
    add("bumpers 1-3", "bumper 1", "bumper 3")
    add("bumpers 2-3", "bumper 2", "bumper 3")
    # creature stages
    for i in range(3):
        add(f"frog on pad {i + 1} to the basin (mode)", f"frog on pad {i + 1} (mode)", "island")
    add("bat patrol to the cave lane walls (mode; must block it)", "bat patrol (mode)", "island", "auto")
    add("bat patrol to the outer wall (mode; must block it)", "bat patrol (mode)", "outer wall", "auto")
    add("squirrel patrol to the grove lane (mode; must block it)", "squirrel patrol (mode)", "island", "auto")
    add("squirrel patrol to the right wall (mode; must block it)", "squirrel patrol (mode)", "right wall", "auto")
    add("sling tip post L to raised flipper", "sling tip post L",
        ("poly", L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1] + [L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1][0]]))
    return out


def scan_pairs(limit=60.0):
    P = L.floor_parts()
    names = list(P)
    rows = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if frozenset((a, b)) in JOINED_OK:
                continue
            g, p, q = gap(P[a], P[b])
            if g < limit:
                rows.append((a, b, g, verdict(g), p, q))
    return sorted(rows, key=lambda r: r[2])


def shot_fan():
    out = {}
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        out[fl] = {k: math.degrees(math.atan2(v[1] - sp[1], v[0] - sp[0])) for k, v in L.SHOTS.items()
                   if fl in L.SHOT_FLIPPERS[k]}
    return out


SHOT_OWN = {"Reed Bed scoop": ("reed",), "Cave orbit": ("cave",), "Lily-pad lane": ("lily",),
            "Specimen scoop": ("cabin",), "Sky ramp": ("ramp",), "Grove lane": ("grove",)}


def shot_clearance(mode_parts=False):
    P = L.floor_parts(mode_parts=mode_parts)
    rows = []
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        for k, tgt in L.SHOTS.items():
            if fl not in L.SHOT_FLIPPERS[k]:
                continue
            u = (tgt[0] - sp[0], tgt[1] - sp[1]); Ln = math.hypot(*u)
            stop = L.BALL_R + 8 if k == "Reed Bed scoop" else 0
            end = (tgt[0] - u[0] / Ln * stop, tgt[1] - u[1] / Ln * stop)
            path = ("poly", [sp, end])
            best = (1e9, "")
            for nm, part in P.items():
                if any(w in nm for w in SHOT_OWN[k]) or nm.startswith("flipper") or nm.startswith("lane guide"):
                    continue
                if nm == "island" and k != "Reed Bed scoop":
                    continue
                if k == "Grove lane" and nm == "right wall":
                    continue
                if k == "Cave orbit" and nm == "outer wall":
                    continue
                g, *_ = gap(path, part)
                if g - L.BALL_R < best[0]:
                    best = (g - L.BALL_R, nm)
            rows.append((fl, k, best[0], best[1]))
    return rows


def placement():
    tip_y = L.TIP_L_REST[1]
    span = L.TOP_Y - tip_y
    sh = lambda y: (y - tip_y) / span * 100
    return [("sling tops", sh(L.SLING_TOP_L[1])), ("Reed Bed hole (side wall)", sh(L.REED_HOLE[1])),
            ("lane mouths (lily, ramp)", sh(L.LILY_MOUTH_Y)), ("grove lane mouth (side wall)", sh(L.GROVE_BOTTOM_Y)),
            ("cave lane mouth (side wall)", sh(L.CAVE_BOTTOM_Y)), ("specimen channel mouth", sh(L.CABIN_MOUTH_Y)),
            ("specimen catch line", sh(L.CABIN_CATCH_Y)), ("lily pads", sh(L.LILY_PADS[0][1])),
            ("bumpers", sh(L.BUMPERS[2][1]))]


if __name__ == "__main__":
    print("NAMED PASSAGES")
    for name, g, v, *_ in named_passages():
        print(f"  {name:58s} {g:7.1f}  {v}")
    print("OTHER PAIRS < 60 pt")
    for a, b, g, v, *_ in scan_pairs():
        print(f"  {a:28s} | {b:28s} {g:7.1f}  {v}")
    print("STRAIGHT SHOT FAN (deg from the sweet spot)")
    for fl, d in shot_fan().items():
        print("  " + fl + ": " + ", ".join(f"{k} {a:.1f}" for k, a in sorted(d.items(), key=lambda kv: kv[1])))
    print("SHOT LINES (clearance of the straight ball path)")
    for fl, k, c, nm in shot_clearance():
        print(f"  {fl:5s} -> {k:16s} {c:7.1f}  ({nm})  {'clear' if c > 0 else 'BLOCKED'}")
    print("PLACEMENT (% of flipper tips -> top)")
    for nm, v in placement():
        print(f"  {nm:30s} {v:5.1f}%")
