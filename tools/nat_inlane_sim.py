"""Inlane feeds: Neon's curved lane guide (r 120 bend) vs traditional angled guides (Aaron, 2026-11-24: "instead of
curved can we have the traditional angled feeds? The curved ones make it very difficult to catch a ball as the ball
doesn't slow down").

The guide stays a straight vertical (x 75) down to the bend, then a straight slant (32 deg) to just above the pivot.
The bend is a corner rounded by radius R (R 120 = Neon's kit today; small R = a traditional angled guide; 0 = sharp).
The sling's lower side is parallel to the slant, 50 clear; its corner drops to where the inlane is still 50 wide.

Tests (left side; the right mirrors it), pymunk at real scale, the governor as in the scenes (inlane balls going down
held to 800 pt/s):
  catch   flipper HELD UP: balls come down the inlane at 300-1000 pt/s (x jitter, from the wire release / the top of
          the inlane); trapped = at rest in the crook for 0.5 s; also the speed the ball meets the flipper with.
  rest    flipper DOWN: the same balls; where they go (along the flipper / into the guide-pivot gap / stuck).
"""
import math, random, sys
import pymunk
import nat_layout as L

G, STEP = 900.0, 1 / 120


def guide(R):
    """Left lane guide polyline: top post -> down x 75 -> bend rounded by R -> slant -> end above the pivot."""
    top = (L.GUIDE_X, L.GUIDE_TOP_Y)
    B, E = L.GUIDE_BEND_L, L.GUIDE_END_L
    if R <= 0.5:
        return [top, B, E]
    u = L.unit(B, E)                         # down the slant
    turn = math.acos(-u[1])                  # angle between straight down (0,-1) and u
    d = R * math.tan(turn / 2)               # tangent length from the corner
    p0 = (B[0], B[1] + d)                    # leaves the vertical
    p1 = (B[0] + u[0] * d, B[1] + u[1] * d)  # joins the slant
    c = (B[0] + R, p0[1])                    # centre to the right of the vertical
    a0 = math.pi
    a1 = math.atan2(p1[1] - c[1], p1[0] - c[0])
    if a1 < a0:
        a1 += 2 * math.pi
    n = max(2, int(abs(a1 - a0) * R / 6))
    arc = [(c[0] + R * math.cos(a0 + (a1 - a0) * i / n), c[1] + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    return [top] + arc + [E]


def seg_d(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(p, (a[0] + dx * t, a[1] + dy * t))


def sling_for(R):
    """Sling corner on x = SLING_X: the lowest y where the corner post keeps the inlane 50 clear of the guide."""
    g = guide(R)
    u = L.unit(L.GUIDE_BEND_L, L.GUIDE_END_L)

    def clearance(y):
        corner = (L.SLING_X, y)
        tip = L.add(corner, u, 64.0)
        # the sling's inlane-facing sides: vertical side (top -> corner) and lower side (corner -> tip), posts included
        sides = [(L.SLING_TOP_L, corner), (corner, tip)]
        best = 1e9
        for a, b in zip(g, g[1:]):
            for k in range(0, 41):
                p = (a[0] + (b[0] - a[0]) * k / 40, a[1] + (b[1] - a[1]) * k / 40)
                for c0, c1 in sides:
                    best = min(best, seg_d(p, c0, c1))
                best = min(best, math.dist(p, corner) - L.SLING_POST_CORNER, math.dist(p, tip) - L.SLING_POST_TIP)
        return best, corner, tip

    y = 300.0
    while True:
        clear, corner, tip = clearance(y)
        if clear >= L.INLANE_W:
            return corner, tip, clear
        y += 0.5


def build(sp, R, raised):
    def seg(a, b, e=0.3, f=0.1):
        s = pymunk.Segment(sp.static_body, a, b, 0.5); s.elasticity, s.friction = e, f; sp.add(s)
    def circ(c, r, e=0.3, f=0.1):
        s = pymunk.Circle(sp.static_body, r, c); s.elasticity, s.friction = e, f; sp.add(s)
    ow = [(L.CHUTE_X, L.CHUTE_BOTTOM), L.APRON_END, L.SLOPE_TOP, (L.WALL_L, 900)]
    for a, b in zip(ow, ow[1:]):
        seg(a, b)
    g = guide(R)
    for a, b in zip(g, g[1:]):
        seg(a, b)
    circ((L.GUIDE_X, L.GUIDE_TOP_Y), L.GUIDE_POST_R)
    seg((L.GUIDE_X, L.GUIDE_TOP_Y), L.OUTLANE_POST_L); circ(L.OUTLANE_POST_L, L.GUIDE_POST_R)
    corner, tip, _ = sling_for(R)
    for a, b in ((L.SLING_TOP_L, corner), (corner, tip), (tip, L.SLING_TOP_L)):
        seg(a, b)
    circ(L.SLING_TOP_L, L.SLING_POST_TOP); circ(tip, L.SLING_POST_TIP)
    ftip, poly = L.flipper_poly(L.PIVOT_L, "L", L.FLIP_TRAVEL if raised else 0.0)
    s = pymunk.Poly(sp.static_body, poly); s.elasticity, s.friction = 0.3, 0.4; sp.add(s)
    circ(L.PIVOT_L, L.FLIP_RP, 0.3, 0.4); circ(ftip, L.FLIP_RT, 0.3, 0.4)
    return ftip, poly


def in_inlane(p, R):
    return L.GUIDE_X < p[0] < L.SLING_X + 10 and p[1] < L.GUIDE_TOP_Y and p[1] > 200


def trial(R, raised, x, v, governor=True, seconds=4.0):
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 30
    ftip, poly = build(sp, R, raised)
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, L.BALL_R))
    b.position, b.velocity = (x, 480.0), (0, -v)
    s = pymunk.Circle(b, L.BALL_R); s.elasticity, s.friction = 0.1, 0.1
    sp.add(b, s)
    meet, slow, maxy_after = None, 0.0, 0.0
    fl_seg = (poly[0], poly[1])     # the flipper's upper face (pivot top -> tip top)
    for i in range(int(seconds / STEP)):
        sp.step(STEP)
        p = (b.position.x, b.position.y)
        if governor and b.velocity.y < 0 and in_inlane(p, R) and b.velocity.length > 800:
            b.velocity = b.velocity * (800 / b.velocity.length)
        dface = seg_d(p, *fl_seg) - L.BALL_R
        if meet is None and (dface < 2.5 or math.dist(p, L.PIVOT_L) < L.FLIP_RP + L.BALL_R + 2.5):
            meet = b.velocity.length
        if meet is not None:
            maxy_after = max(maxy_after, p[1])
        if p[1] < 140 or p[0] > L.CX + 20:
            return "lost", meet, p
        if raised and b.velocity.length < 12 and dface < 4:
            slow += STEP
            if slow > 0.5:
                return "trapped", meet, p
        else:
            slow = 0.0
        if not raised and b.velocity.length < 3:
            slow += STEP
            if slow > 1.0:
                return "stuck", meet, p
    if raised:
        return ("bounced" if maxy_after > 330 else "rattling"), meet, (b.position.x, b.position.y)
    return "moving", meet, (b.position.x, b.position.y)


def run(R, raised, speeds=(300, 450, 600, 800, 1000), n=8, seed=1):
    rng = random.Random(seed)
    res, meets = {}, []
    for v in speeds:
        for k in range(n):
            x = L.INLANE_X + rng.uniform(-9, 9)
            o, m, p = trial(R, raised, x, v)
            res[o] = res.get(o, 0) + 1
            if m:
                meets.append(m)
    meets.sort()
    med = meets[len(meets) // 2] if meets else 0
    return res, med


E0 = L.GUIDE_END_L


def set_slant(deg):
    """Point the module at a slant angle (the guide end stays just above the pivot)."""
    L.SLANT = math.radians(deg)
    L.GUIDE_BEND_L = (L.GUIDE_X, E0[1] + (E0[0] - L.GUIDE_X) * math.tan(L.SLANT))


VARIANTS = {"r1 curved (Neon kit: 32 deg, r 120 bend)": (32, 120), "r2 angled (20 deg, sharp corner)": (20, 0)}


def onto_flipper(R, v, x, track=None):
    """Flipper held up; the speed when the ball reaches the flipper (x > 183), and its path."""
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 30
    build(sp, R, True)
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, L.BALL_R))
    b.position, b.velocity = (x, 480.0), (0, -v)
    s = pymunk.Circle(b, L.BALL_R); s.elasticity, s.friction = 0.1, 0.1
    sp.add(b, s)
    for _ in range(int(1.2 / STEP)):
        sp.step(STEP)
        p = (b.position.x, b.position.y)
        if b.velocity.y < 0 and in_inlane(p, R) and b.velocity.length > 800:
            b.velocity = b.velocity * (800 / b.velocity.length)
        if track is not None:
            track.append(p)
        if p[0] > 183:
            return b.velocity.length
    return None


def compare(speeds=(150, 300, 450, 600, 800), dxs=(-8, -4, 0, 4, 8)):
    out = {}
    for name, (deg, R) in VARIANTS.items():
        set_slant(deg)
        vs = sorted(v for v in (onto_flipper(R, s, L.INLANE_X + d) for s in speeds for d in dxs) if v)
        out[name] = (vs[len(vs) // 2], vs[0], vs[-1], sling_for(R)[0][1], L.GUIDE_BEND_L[1])
    set_slant(20)
    return out


if __name__ == "__main__":
    for name, (med, lo, hi, cy, by) in compare().items():
        print(f"{name:42s} meets the held-up flipper at median {med:.0f} pt/s ({lo:.0f}-{hi:.0f}); corner y {by:.0f}, sling corner y {cy:.0f}")
    print("CHOMP!'s measured catches (Play Lab, 740 raises): 91-98 % under 300 pt/s, 32 % at 300-400, ~1 % over 500")
