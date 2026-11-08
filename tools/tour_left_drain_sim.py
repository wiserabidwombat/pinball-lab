"""Table 06: how often balls coming down the left half reach the left outlane, per left-side variant (pymunk, 2D).
Balls start at random in the upper-left (y 650-900, x 30-300) heading down at random; no flippers, so every ball ends
in a drain: we count which. Also re-runs the kickback for each variant."""
import math, random, sys
sys.path.insert(0, '.')
import pymunk
import tour_layout as L

G = -1380
def space(walls, bulge):
    L.leftBulgeControlInset = bulge
    sp = pymunk.Space(); sp.gravity = (0, G)
    def wall(pts):
        for a, b in zip(pts, pts[1:]):
            s = pymunk.Segment(sp.static_body, a, b, 0); s.elasticity = 0.3; s.friction = 0.1; sp.add(s)
    wall(L.outer_wall())
    for w in [L.leftLaneGuide, L.leftOutlaneWall, L.leftOutlanePostRail, list(L.leftSling) + [L.leftSling[0]]] + walls:
        wall(w)
    return sp

def ball(sp, p, v):
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, 9)); b.position = p; b.velocity = v
    c = pymunk.Circle(b, 9); c.elasticity = 1.0; c.friction = 0.1; sp.add(b, c); return b

def drains(walls, bulge, n=400, seed=1):
    rnd = random.Random(seed); out = 0; inl = 0
    for i in range(n):
        sp = space(walls, bulge)
        p = (rnd.uniform(30, 300), rnd.uniform(650, 900))
        a = math.radians(rnd.uniform(-170, -10)); s = rnd.uniform(150, 900)
        b = ball(sp, p, (s * math.cos(a), s * math.sin(a)))
        for _ in range(240 * 3):
            sp.step(1 / 240)
            x, y = b.position
            if y < 440 and x < 54: out += 1; break
            if y < 330 and x < 200: inl += 1; break
            if y < 250: break
    return out / n, inl / n

def kick(walls, bulge, kx=37):
    sp = space(walls, bulge); b = ball(sp, (kx, 238), (0, 1500)); top = (0, 0); t = 0
    while t < 1.5:
        sp.step(1 / 240); t += 1 / 240
        if b.position.y > top[1]: top = (b.position.x, b.position.y)
        if b.position.y < 440 and b.position.x < 54 and t > 0.3: return f'back down the outlane at {t:.2f}s (peak {top[0]:.0f},{top[1]:.0f})'
    return f'stays in play (peak {top[0]:.0f},{top[1]:.0f}; at 1.5 s {b.position.x:.0f},{b.position.y:.0f})'

def bank(lo, line_deg, defl_deg=65, defl_to_x=50, n=3, size=26, gap=2):
    """'/' deflector from lo on the wall to x defl_to_x at defl_deg, then the bank's backboard along line_deg, then a
    roof back to the wall. Returns (structure, centres, normal_deg)."""
    hi = (defl_to_x, lo[1] + (defl_to_x - lo[0]) * math.tan(math.radians(defl_deg)))
    u = (math.cos(math.radians(line_deg)), math.sin(math.radians(line_deg)))
    nd = line_deg - 90; nv = (math.cos(math.radians(nd)), math.sin(math.radians(nd)))
    length = 4 + n * size + (n - 1) * gap
    top = (hi[0] + u[0] * length, hi[1] + u[1] * length)
    cs = [(hi[0] + u[0] * (4 + size / 2 + i * (size + gap)) + nv[0] * 4, hi[1] + u[1] * (4 + size / 2 + i * (size + gap)) + nv[1] * 4) for i in range(n)]
    roof_y = top[1] + max(20, (top[0] - 20) * 0.45)
    return [lo, hi, top, (20, roof_y)], cs, nd

if __name__ == '__main__':
    variants = {
        'v5/v6: bulge 36, no bank': ([], 36),
        'v7: deflector at 480, bank at 40 deg': ([bank((20, 480), 40)[0]], 0),
        'A: deflector at 480, bank along the wall at 65 deg': ([bank((20, 480), 65)[0]], 0),
        'B: deflector raised to 520, bank at 65 deg': ([bank((20, 520), 65)[0]], 0),
        'C: deflector raised to 540, bank at 65 deg': ([bank((20, 540), 65)[0]], 0),
        'D: straight wall, nothing': ([], 0),
    }
    for name, (w, bulge) in variants.items():
        o, i = drains(w, bulge)
        st = w[0] if w else None
        print(f'{name:52s} left outlane {o:5.1%}  left inlane {i:5.1%} | kickback: {kick(w, bulge)}' + (f' | out to x {max(p[0] for p in st):.0f}' if st else ''))
