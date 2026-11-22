"""Gap checks for the Neon Labyrinth cell (kit + Switchyard). Imported by the render; run alone for the table."""
import math
import nl_layout as L

def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    q = (ax + dx * t, ay + dy * t)
    return math.dist(p, q), q

def segseg(a, b, c, d):
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
    """(clear distance, point on a, point on b) between two parts, radii subtracted."""
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

# Pairs that are allowed to touch or are drawn as one part (attachments by design)
JOINED_OK = {
    frozenset(("sling L", "sling top post L")), frozenset(("sling R", "sling top post R")),
    frozenset(("sling L", "sling tip post L")), frozenset(("sling R", "sling tip post R")),
    frozenset(("lane guide L", "lane guide post L")), frozenset(("lane guide R", "lane guide post R")),
    frozenset(("outlane post L", "outlane post rail L")), frozenset(("outlane post R", "outlane post rail R")),
    frozenset(("lane guide post L", "outlane post rail L")), frozenset(("lane guide post R", "outlane post rail R")),
    frozenset(("lane guide L", "outlane post rail L")), frozenset(("lane guide R", "outlane post rail R")),
    frozenset(("lane guide post L", "outlane post L")), frozenset(("lane guide post R", "outlane post R")),
    frozenset(("lane guide L", "outlane post L")), frozenset(("lane guide R", "outlane post R")),
    frozenset(("lane guide L", "outlane wall L")), frozenset(("lane guide R", "outlane wall R")),
    frozenset(("switch block L", "ramp mouth post L")), frozenset(("switch block R", "ramp mouth post R")),
    frozenset(("switch block L", "ramp U (floor-solid)")), frozenset(("switch block R", "ramp U (floor-solid)")),
    frozenset(("ramp U (floor-solid)", "ramp mouth post L")), frozenset(("ramp U (floor-solid)", "ramp mouth post R")),
    frozenset(("top lane wall L", "outer wall")), frozenset(("top lane wall R", "outer wall")),
    frozenset(("top lane wall L", "top lane post L")), frozenset(("top lane wall R", "top lane post R")),
    frozenset(("RAILS block", "outer wall")),
    frozenset(("lane guide L", "flipper pivot L")), frozenset(("lane guide R", "flipper pivot R")),
}

def named_passages():
    """The passages the ball must use, measured the way it uses them."""
    P = L.floor_parts()
    out = []
    def add(name, a, b, kind="passage"):
        g, p, q = gap(P[a] if isinstance(a, str) else a, P[b] if isinstance(b, str) else b)
        out.append((name, g, verdict(g, kind), p, q))
    for s in ("L", "R"):
        f = (lambda p: p) if s == "L" else L.M
        add(f"outlane {s}: mouth (bulge to outlane post)", f"outlane post {s}", "outer wall")
        add(f"outlane {s}: wall to lane guide", ("poly", [f((L.GUIDE_X, L.GUIDE_TOP_Y)), f(L.GUIDE_BEND_L)]), P["outer wall"])
        add(f"outlane {s}: channel wall to slope", f"outlane wall {s}", "outer wall")
        add(f"outlane {s}: under the pivot to slope", f"flipper pivot {s}", "outer wall")
        add(f"inlane {s}: guide post to sling top post", f"lane guide post {s}", f"sling top post {s}")
        add(f"inlane {s}: guide to sling corner", ("circle", f(L.SLING_CORNER_L), L.SLING_POST_CORNER), P[f"lane guide {s}"])
        add(f"inlane {s}: guide to sling tip post", f"sling tip post {s}", f"lane guide {s}")
    tipL, tipR = L.TIP_L_REST, L.TIP_R_REST
    add("drain: flipper tips at rest", ("circle", tipL, L.FLIP_RT), ("circle", tipR, L.FLIP_RT))
    add("drain chute", ("poly", [(L.CHUTE_X, L.CHUTE_BOTTOM), L.APRON_END]), ("poly", [L.M((L.CHUTE_X, L.CHUTE_BOTTOM)), L.M(L.APRON_END)]))
    add("ramp mouth (posts)", "ramp mouth post L", "ramp mouth post R")
    add("top lane", "top lane post L", "top lane post R")
    add("RAILS block to lane guide post R", P["RAILS block"], P["lane guide post R"], "auto")
    add("sling tip post L to raised flipper", "sling tip post L",
        ("poly", L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1] + [L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL)[1][0]]))
    add("sling tip post L to resting flipper", "sling tip post L",
        ("poly", L.flipper_poly(L.PIVOT_L, "L")[1] + [L.flipper_poly(L.PIVOT_L, "L")[1][0]]))
    return out

def scan_pairs(limit=80.0):
    """Every other pair of floor parts closer than `limit`."""
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
    """Aim angles (deg, from the flipper's sweet spot) to every room shot."""
    shots = {"SWITCH <": L.SWITCH_L_C, "ramp": (L.CX, L.RAMP_MOUTH_Y + 8), "SWITCH >": L.SWITCH_R_C, "RAILS": L.RAILS_C}
    out = {}
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        out[fl] = {k: math.degrees(math.atan2(v[1] - sp[1], v[0] - sp[0])) for k, v in shots.items()}
    return out

SHOT_OWN = {"SWITCH <": "switch block L", "SWITCH >": "switch block R", "RAILS": "RAILS block", "ramp": None}

def shot_clearance():
    """For each shot from each flipper: the nearest floor part to the straight ball path (radius subtracted), stopping
    at the target's face (or 20 pt into the ramp mouth). A straight line is optimistic: the real path curves ~10 pt
    over 700 pt (Grand Tour K-E-T) — the Shot Lab decides."""
    P = L.floor_parts()
    shots = {"SWITCH <": L.SWITCH_L_C, "ramp": (L.CX, L.RAMP_MOUTH_Y + 20), "SWITCH >": L.SWITCH_R_C, "RAILS": L.RAILS_C}
    rows = []
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        for k, tgt in shots.items():
            u = (tgt[0] - sp[0], tgt[1] - sp[1]); Ln = math.hypot(*u)
            end = (tgt[0] - u[0] / Ln * (L.BALL_R + 6), tgt[1] - u[1] / Ln * (L.BALL_R + 6)) if k != "ramp" else tgt
            path = ("poly", [sp, end])
            best = (1e9, "")
            for nm, part in P.items():
                if nm == SHOT_OWN[k] or nm.startswith("flipper") or nm.startswith("lane guide"):
                    continue
                g, *_ = gap(path, part)
                if g - L.BALL_R < best[0]:
                    best = (g - L.BALL_R, nm)
            rows.append((fl, k, best[0], best[1]))
    return rows

if __name__ == "__main__":
    print("NAMED PASSAGES")
    for name, g, v, *_ in named_passages():
        print(f"  {name:42s} {g:7.1f}  {v}")
    print("OTHER PAIRS < 80 pt")
    for a, b, g, v, *_ in scan_pairs():
        print(f"  {a:26s} | {b:26s} {g:7.1f}  {v}")
    print("SHOT FAN")
    for fl, d in shot_fan().items():
        print("  " + fl + ": " + ", ".join(f"{k} {a:.1f}" for k, a in sorted(d.items(), key=lambda kv: kv[1])))
    print("SHOT LINES (clearance of the ball's straight path to the nearest other part)")
    for fl, k, c, nm in shot_clearance():
        print(f"  {fl:5s} -> {k:9s} {c:7.1f}  ({nm})  {'clear' if c > 0 else 'BLOCKED'}")
