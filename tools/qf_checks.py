"""Gap checks, the shot fan and straight-line shot clearance for the Haunted Forest (Quest & Flipper, Table 09).
Same method as nl_checks.py (Neon Labyrinth). Run alone to print the tables; the render imports it."""
import math
import qf_layout as L

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

# Pairs drawn as one part or attached by design
JOINED_OK = set()
for s in "LR":
    JOINED_OK |= J((f"sling {s}", f"sling top post {s}"), (f"sling {s}", f"sling tip post {s}"),
                   (f"lane guide {s}", f"lane guide post {s}"), (f"outlane post {s}", f"outlane post rail {s}"),
                   (f"lane guide post {s}", f"outlane post rail {s}"), (f"lane guide {s}", f"outlane post rail {s}"),
                   (f"lane guide post {s}", f"outlane post {s}"), (f"lane guide {s}", f"outlane post {s}"),
                   (f"lane guide {s}", f"outlane wall {s}"), (f"lane guide {s}", f"flipper pivot {s}"))
JOINED_OK |= J(("well lower rim", "well post lo"), ("well roof", "well post hi"), ("well lower rim", "outer wall"),
               ("well roof", "outer wall"), ("island", "orbit post"), ("island", "log post L"), ("island", "log post R"),
               ("island", "treant post L"), ("island", "treant post R"), ("island", "ramp post L"),
               ("island", "ramp post R"), ("lantern E block", "right wall"), ("launch gate", "outer wall"),
               ("launch gate", "right wall"), ("right wall", "outer wall"), ("shooter lane wall", "outer wall"),
               ("shooter lane wall", "right wall"), ("trunk", "island"),
               ("bark 1", "bark 2"), ("bark 2", "bark 3"), ("bark 1", "island"), ("bark 3", "island"),
               # across the bank / behind it: measured as the slot rows in named_passages instead
               ("bark 1", "bark 3"), ("bark 2", "island"), ("bark 1", "trunk"), ("bark 2", "trunk"), ("bark 3", "trunk"),
               # on opposite sides of the shooter lane's inner wall
               ("lantern E block", "outer wall"),
               ("roots (mode)", "sling top post R"), ("roots (mode)", "sling R"),
               ("upper flipper", "upper flipper pivot"), ("upper flipper", "upper flipper tip"),
               ("upper flipper pivot", "upper flipper tip"),
               ("diverter (mode)", "outer wall"), ("diverter (mode)", "upper flipper pivot"),
               ("diverter (mode)", "upper flipper"))

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
        add(f"outlane {s}: wall to lane guide", ("poly", [f((L.GUIDE_X, L.GUIDE_TOP_Y)), f(L.GUIDE_BEND_L)]), P[wall])
        add(f"outlane {s}: under the pivot to slope", f"flipper pivot {s}", wall)
        add(f"inlane {s}: guide post to sling top post", f"lane guide post {s}", f"sling top post {s}")
        add(f"inlane {s}: guide to sling tip post", f"sling tip post {s}", f"lane guide {s}")
    add("drain: flipper tips at rest", ("circle", L.TIP_L_REST, L.FLIP_RT), ("circle", L.TIP_R_REST, L.FLIP_RT))
    add("Old Well: mouth (rim posts)", "well post lo", "well post hi")
    add("Old Well: upper rim post to outlane post L", "well post hi", "outlane post L", "auto")
    add("Old Well: lower rim to lane guide post L", "well lower rim", "lane guide post L", "auto")
    add("Graveyard orbit: lane (wall to orbit post)", "orbit post", "outer wall")
    add("Graveyard orbit: top (island corner to arch)", ("circle", L.ROOF_L, 0.0), P["outer wall"])
    add("Graveyard orbit: well roof to orbit post", "well roof", "orbit post", "auto")
    add("Hollow Log: mouth (posts)", "log post L", "log post R")
    add("Treant: mouth (posts)", "treant post L", "treant post R")
    add("Treant: bark 1 to clearing wall", ("poly", [(L.TREANT_L_X, L.TREANT_MOUTH_Y), (L.TREANT_L_X, L.TREANT_BACK_Y)]), P["bark 1"], "auto")
    add("Treant: bark back to trunk face (closed = no pocket)", "bark 2", "trunk", "auto")
    add("Treant: slot when one bark is down (onto the trunk)", "bark 1", "bark 3", "auto")
    add("Old Road ramp: mouth (posts)", "ramp post L", "ramp post R")
    add("right lane: island edge to right wall", ("poly", [(L.ISLAND_R_X, L.RAMP_MOUTH_Y + 30), (L.ISLAND_R_X, L.ROOF_R[1])]), P["right wall"])
    add("right lane: island corner to lantern block", ("circle", (L.ISLAND_R_X, L.RAMP_MOUTH_Y + 30), 0.0), P["lantern E block"])
    add("right lane: lantern block to ramp post R", "lantern E block", "ramp post R")
    add("glade: island roof to arch (narrowest)", ("poly", [L.ROOF_L, L.ROOF_R]), P["outer wall"])
    add("shooter lane (inner to outer wall)", ("poly", [(L.SHOOT_IN, 300), (L.SHOOT_IN, 1000)]), ("poly", [(L.SHOOT_OUT, 300), (L.SHOOT_OUT, 1000)]))
    add("plunge exit: launch gate top to arch", ("circle", L.LAUNCH_GATE[1], 0.0), P["outer wall"])
    add("plunge exit: shooter wall top to island R", ("circle", (L.SHOOT_IN, L.SHOOT_IN_TOP), 0.0), ("poly", [(L.ISLAND_R_X, 900), L.ROOF_R]))
    add("ghost haunts: L to R (mode)", "ghost haunt L (mode)", "ghost haunt R (mode)")
    add("ghost haunt L to log post R (mode)", "ghost haunt L (mode)", "log post R")
    add("ghost haunt R to ramp post L (mode)", "ghost haunt R (mode)", "ramp post L")
    add("ghost haunt L to treant post L (mode)", "ghost haunt L (mode)", "treant post L")
    add("ghost haunt R to treant post R (mode)", "ghost haunt R (mode)", "treant post R")
    add("roots to sling top post R (mode, attached)", "roots (mode)", "sling top post R", "auto")
    add("inlane R with roots up: guide post to roots (mode)", "lane guide post R", "roots (mode)")
    add("roots to raised flipper R (mode)", "roots (mode)", ("poly", L.flipper_poly(L.PIVOT_R, "R", L.FLIP_TRAVEL)[1] + [L.flipper_poly(L.PIVOT_R, "R", L.FLIP_TRAVEL)[1][0]]))
    add("gravestone to raised flipper L (mode)", "gravestone (mode)", ("poly", L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1] + [L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1][0]]))
    add("sling tip post L to raised flipper", "sling tip post L",
        ("poly", L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1] + [L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1][0]]))
    # M1 round 2: the upper flipper
    uf_rest = ("poly", L.uf_poly()[1] + [L.uf_poly()[1][0]])
    uf_up = ("poly", L.uf_poly(L.UF_TRAVEL)[1] + [L.uf_poly(L.UF_TRAVEL)[1][0]])
    add("UF: pivot to the arch (orbits ride past)", "upper flipper pivot", "outer wall")
    add("UF: resting tip to the island roof", ("circle", L.uf_poly()[0], L.UF_RT), P["island"])
    add("UF: resting flipper to the island roof", uf_rest, P["island"])
    add("UF: diverter end to the pivot (closed)", "diverter (mode)", "upper flipper pivot", "auto")
    add("UF: launch gate to the flipper", "launch gate", uf_rest)
    add("UF: raised flipper to the arch", uf_up, P["outer wall"])
    for i in range(len(L.WISPS)):
        g = min(gap(uf_up, ("circle", p, L.WISP_R))[0] for p in L.wisp_path(i))
        out.append((f"UF: raised flipper to wisp {i + 1}'s loop", g, verdict(g, "passage"), None, None))
    return out

def uf_shots():
    """Straight lines from the upper flipper's sweet spot to each wisp's loop centre: angle and clearance."""
    P = L.floor_parts(mode_parts=False)
    rows = []
    for i, (c, _, _) in enumerate(L.WISPS):
        a = math.degrees(math.atan2(c[1] - L.UF_SWEET[1], c[0] - L.UF_SWEET[0]))
        u = (c[0] - L.UF_SWEET[0], c[1] - L.UF_SWEET[1]); n = math.hypot(*u)
        end = (c[0] - u[0] / n * (L.WISP_R + L.BALL_R), c[1] - u[1] / n * (L.WISP_R + L.BALL_R))
        best = (1e9, "")
        for nm in ("island", "outer wall"):
            g, *_ = gap(("poly", [L.UF_SWEET, end]), P[nm])
            if g - L.BALL_R < best[0]:
                best = (g - L.BALL_R, nm)
        rows.append((f"wisp {i + 1}", a, best[0], best[1]))
    return rows

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

def wisp_clearance():
    """Each wisp's swept loop vs the arch and the island roof (they must leave the orbit's arch path a ball clear
    most of the time, and never pin a ball against a wall: >= 45 or touching nothing)."""
    P = L.floor_parts()
    rows = []
    for i in range(len(L.WISPS)):
        best = (1e9, "")
        for nm in ("outer wall", "island"):
            for p in L.wisp_path(i):
                g, *_ = gap(("circle", p, L.WISP_R), P[nm])
                if g < best[0]:
                    best = (g, nm)
        rows.append((f"wisp {i + 1}", best[0], best[1], verdict(best[0], "passage")))
    for i in range(len(L.WISPS)):
        for j in range(i + 1, len(L.WISPS)):
            g = min(math.dist(p, q) for p in L.wisp_path(i) for q in L.wisp_path(j)) - 2 * L.WISP_R
            rows.append((f"wisp {i + 1} to wisp {j + 1}", g, "(closest approach)", verdict(g, "passage")))
    return rows

def shot_fan():
    out = {}
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        out[fl] = {k: math.degrees(math.atan2(v[1] - sp[1], v[0] - sp[0])) for k, v in L.SHOTS.items() if fl in L.SHOT_FLIPPERS[k]}
    return out

SHOT_OWN = {"Old Well": ("well",), "Graveyard orbit": ("orbit",), "Hollow Log": ("log",), "Treant": ("treant", "bark"),
            "Old Road (exit)": ("ramp",), "East lantern": ("lantern",)}

def shot_clearance(mode_parts=False):
    """Nearest other floor part to each shot's straight ball path, ball radius subtracted (> 0 = clear). Paths stop at
    the lane mouth / target face. Straight lines are optimistic (Grand Tour K-E-T: ~10 pt of curve over 700 pt);
    the Shot Lab decides."""
    P = L.floor_parts(mode_parts=mode_parts)
    rows = []
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        for k, tgt in L.SHOTS.items():
            if fl not in L.SHOT_FLIPPERS[k]:
                continue
            u = (tgt[0] - sp[0], tgt[1] - sp[1]); Ln = math.hypot(*u)
            stop = L.BALL_R + 8 if k in ("East lantern", "Old Well") else 0
            end = (tgt[0] - u[0] / Ln * stop, tgt[1] - u[1] / Ln * stop)
            path = ("poly", [sp, end])
            best = (1e9, "")
            for nm, part in P.items():
                if any(w in nm for w in SHOT_OWN[k]) or nm.startswith("flipper") or nm.startswith("lane guide"):
                    continue
                if k in ("Hollow Log", "Treant", "Old Road (exit)", "Graveyard orbit") and nm == "island":
                    continue   # the path ends in the island's mouth; its posts are checked
                g, *_ = gap(path, part)
                if g - L.BALL_R < best[0]:
                    best = (g - L.BALL_R, nm)
            rows.append((fl, k, best[0], best[1]))
    return rows

def placement():
    """Heights as a share of the distance from the flipper tips to the top (the open-table rule)."""
    tip_y = L.TIP_L_REST[1]
    span = L.TOP_Y - tip_y
    sh = lambda y: (y - tip_y) / span * 100
    return [("sling tops", sh(L.SLING_TOP_L[1])), ("ghost haunts (mode)", sh(L.GHOST_HAUNTS[0][1])),
            ("lane mouths (log, ramp)", sh(L.LOG_MOUTH_Y)), ("Treant mouth", sh(L.TREANT_MOUTH_Y)),
            ("bark drops", sh(L.BARK_Y)), ("trunk", sh(L.TRUNK_Y)), ("Old Well hole (side wall)", sh(L.WELL_HOLE[1])),
            ("East lantern (side wall)", sh(L.LANTERN_E_C[1])), ("roots (mode)", sh(L.ROOTS[1])),
            ("gravestone (mode)", sh(L.GRAVESTONE[0][1]))]

if __name__ == "__main__":
    print("NAMED PASSAGES")
    for name, g, v, *_ in named_passages():
        print(f"  {name:48s} {g:7.1f}  {v}")
    print("OTHER PAIRS < 60 pt")
    for a, b, g, v, *_ in scan_pairs():
        print(f"  {a:26s} | {b:26s} {g:7.1f}  {v}")
    print("WISPS")
    for name, g, nm, v in wisp_clearance():
        print(f"  {name:20s} {g:7.1f}  {nm}  {v}")
    print("SHOT FAN (deg from the sweet spot)")
    for fl, d in shot_fan().items():
        print("  " + fl + ": " + ", ".join(f"{k} {a:.1f}" for k, a in sorted(d.items(), key=lambda kv: kv[1])))
    print("SHOT LINES, base table (clearance of the straight ball path)")
    for fl, k, c, nm in shot_clearance():
        print(f"  {fl:5s} -> {k:16s} {c:7.1f}  ({nm})  {'clear' if c > 0 else 'BLOCKED'}")
    print("SHOT LINES, with every mode part up")
    for fl, k, c, nm in shot_clearance(True):
        print(f"  {fl:5s} -> {k:16s} {c:7.1f}  ({nm})  {'clear' if c > 0 else 'BLOCKED'}")
    print("UPPER FLIPPER SHOTS (from its sweet spot)")
    for nm, a, c, w in uf_shots():
        print(f"  {nm:8s} {a:6.1f} deg  clearance {c:6.1f} ({w})  {'clear' if c > 0 else 'BLOCKED'}")
    print("PLACEMENT (% of flipper tips -> top)")
    for nm, v in placement():
        print(f"  {nm:28s} {v:5.1f}%")
