"""Gap checks for the 9 to Alive Lobby (Neon's cell kit + the Lobby room). The gap helpers are nl_checks.py's."""
import math
import nl_kit as K
import nta_room_lobby as R

# ---------------------------------------------------------------- nl_checks.py's helpers
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
    return [(part[1], part[1])], part[2]

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
        return "OK" if g >= K.PASSAGE_MIN else ("WEDGE RISK" if g >= K.CLOSED_MAX else "TOO NARROW")
    if g < K.CLOSED_MAX:
        return "closed"
    if g < K.PASSAGE_MIN:
        return "WEDGE RISK"
    return "open"

# ---------------------------------------------------------------- the cell
def floor_parts():
    P = K.kit_parts(R.EXITS)
    P.update(R.room_parts())
    return P

KIT_JOINED = [("sling", "sling top post"), ("sling", "sling tip post"), ("lane guide", "lane guide post"),
              ("outlane post", "outlane post rail"), ("lane guide post", "outlane post rail"),
              ("lane guide", "outlane post rail"), ("lane guide post", "outlane post"), ("lane guide", "outlane post"),
              ("lane guide", "outlane wall"), ("top lane wall", "top lane post"), ("lane guide", "flipper pivot")]
JOINED_OK = {frozenset((f"{a} {s}", f"{b} {s}")) for a, b in KIT_JOINED for s in "LR"}
JOINED_OK |= {frozenset((f"top lane wall {s}", "outer wall")) for s in "LR"}
JOINED_OK |= {frozenset(p) for p in R.JOINED}

def named_passages():
    P = floor_parts()
    out = []
    def add(name, a, b, kind="passage"):
        g, p, q = gap(P[a] if isinstance(a, str) else a, P[b] if isinstance(b, str) else b)
        out.append((name, g, verdict(g, kind), p, q))
    # the kit's (unchanged; re-measured because the Lobby's parts sit near some of them)
    for s in ("L", "R"):
        f = (lambda p: p) if s == "L" else K.M
        add(f"outlane {s}: mouth (knee to outlane post)", f"outlane post {s}", "outer wall")
        add(f"inlane {s}: guide post to sling top post", f"lane guide post {s}", f"sling top post {s}")
        add(f"inlane {s}: guide to sling corner", ("circle", f(K.SLING_CORNER_L), K.SLING_POST_CORNER), P[f"lane guide {s}"])
    add("drain: flipper tips at rest", ("circle", K.TIP_L_REST, K.FLIP_RT), ("circle", K.TIP_R_REST, K.FLIP_RT))
    add("top lane (posts)", "top lane post L", "top lane post R")
    # the Lobby's
    add("stairs mouth (posts)", "stairs mouth post L", "stairs mouth post R")
    add("door lane: mouth (post to block)", "door mouth post", "door block")
    a = ("circle", R.door_pt(R.DOOR_FLARE_LEN + 1, "in", R.DOOR_HALF), 0.0)
    b = ("circle", R.door_pt(R.DOOR_FLARE_LEN + 1, "out", R.DOOR_HALF), 0.0)
    add("door lane: channel", a, b)
    add("door mouth post to stairs mouth post L", "door mouth post", "stairs mouth post L")
    add("door mouth post to stairs U", "door mouth post", "stairs U (floor-solid)")
    add("door inner wall to stairs U", "door inner wall", "stairs U (floor-solid)")
    add("door block to lane guide post L (above the knee)", "door block", "lane guide post L", "auto")
    add("door block to the knee's pocket (block to outlane post L)", "door block", "outlane post L")
    add("door block's top to top lane wall L", "door block", "top lane wall L")
    add("reception desk to top lane post R", "reception desk", "top lane post R")
    add("reception desk to top lane wall R", "reception desk", "top lane wall R")
    add("reception desk to stairs U", "reception desk", "stairs U (floor-solid)")
    add("reception desk to lane guide post R", "reception desk", "lane guide post R")
    return out

def scan_pairs(limit=60.0):
    P = floor_parts()
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
    for fl, sp in (("left", R.SWEET_L), ("right", R.SWEET_R)):
        out[fl] = {k: math.degrees(math.atan2(v[1] - sp[1], v[0] - sp[0])) for k, (v, who) in R.SHOTS.items()}
    return out

def shot_clearance():
    """Straight ball path from the sweet spot to each shot, clearance to the nearest part not belonging to the shot."""
    P = floor_parts()
    own = {"STAIRS": ("stairs",), "REVOLVING DOOR": ("door",), "B": ("reception",), "A": ("reception",), "R": ("reception",)}
    rows = []
    for k, (tgt, who) in R.SHOTS.items():
        for fl, sp in (("left", R.SWEET_L), ("right", R.SWEET_R)):
            if who not in (fl, "both"):
                continue
            u = (tgt[0] - sp[0], tgt[1] - sp[1]); Ln = math.hypot(*u)
            end = tgt if k in ("STAIRS", "REVOLVING DOOR") else (tgt[0] - u[0] / Ln * (K.BALL_R + 6), tgt[1] - u[1] / Ln * (K.BALL_R + 6))
            path = ("poly", [sp, end])
            best = (1e9, "")
            for nm, part in P.items():
                if nm.startswith(own[k]) or nm.startswith("flipper") or nm.startswith("lane guide"):
                    continue
                g, *_ = gap(path, part)
                if g - K.BALL_R < best[0]:
                    best = (g - K.BALL_R, nm)
            rows.append((fl, k, best[0], best[1]))
    return rows

def door_window(step=0.05):
    """Straight shots from the right sweet spot: the range of aim angles whose ball (r 15) crosses the spinner line
    inside the lane without touching the mouth post or the block on the way (glancing off the lane's parallel walls
    after the spinner still counts). A first look only: the Shot Lab measures the real window."""
    P = floor_parts()
    sp = R.SWEET_R
    s0, s1 = R.DOOR_SPINNER
    base = math.degrees(math.atan2(R.DOOR_U[1], R.DOOR_U[0]))
    ok = []
    a = base - 8
    while a <= base + 8:
        d = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        # where the path crosses the spinner line
        ex, ey = s1[0] - s0[0], s1[1] - s0[1]
        den = d[0] * ey - d[1] * ex
        t = ((s0[0] - sp[0]) * ey - (s0[1] - sp[1]) * ex) / den
        hit = (sp[0] + d[0] * t, sp[1] + d[1] * t)
        path = ("poly", [sp, hit])
        clear = min(gap(path, P[n])[0] for n in ("door mouth post", "door block", "door inner wall", "stairs U (floor-solid)",
                                                  "stairs mouth post L"))
        if clear >= K.BALL_R:
            ok.append(a)
        a += step
    return (min(ok), max(ok), base) if ok else (None, None, base)

if __name__ == "__main__":
    print("NAMED PASSAGES")
    for name, g, v, *_ in named_passages():
        print(f"  {name:52s} {g:7.1f}  {v}")
    print("OTHER PAIRS < 60 pt")
    for a, b, g, v, *_ in scan_pairs():
        print(f"  {a:24s} | {b:24s} {g:7.1f}  {v}")
    print("SHOT FAN")
    for fl, d in shot_fan().items():
        print("  " + fl + ": " + ", ".join(f"{k} {a:.1f}" for k, a in sorted(d.items(), key=lambda kv: kv[1])))
    print("SHOT LINES")
    for fl, k, c, nm in shot_clearance():
        print(f"  {fl:5s} -> {k:15s} {c:7.1f}  ({nm})  {'clear' if c > 0 else 'BLOCKED'}")
    lo, hi, base = door_window()
    print(f"DOOR WINDOW (right flipper, straight shots): {lo:.2f}..{hi:.2f} deg (axis {base:.2f}), {hi - lo:.2f} deg wide")
    for letter, c, n, face in R.barricade():
        print(f"  barricade {letter}: centre ({c[0]:.1f}, {c[1]:.1f}) normal ({n[0]:.3f}, {n[1]:.3f})")
    print("  desk outline", [tuple(round(v, 1) for v in p) for p in R.desk()[2]])
    print("  door mouth", tuple(round(v, 1) for v in R.DOOR_MOUTH), "spinner", [tuple(round(v, 1) for v in p) for p in R.DOOR_SPINNER])
