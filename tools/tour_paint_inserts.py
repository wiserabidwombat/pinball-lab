"""Table 06 (Orbit: Grand Tour) M7 v2: the lamp inserts as real pinball inserts, painted with numpy.

A real insert is a plastic lens set flush in the playfield: a printed black ink border round it, coloured transparent
plastic with a faceted (prismatic) underside, the clear-coat gloss on top, and a bulb under it. Unlit, the plastic is
deep and dark but still glassy — the facets and the gloss catch the room's light. Lit, it glows from a white-hot spot
where the bulb sits, out to the saturated colour at the edge, and the facets sparkle.

Writes, for every lamp, tour_insert_<key>_off.png and _on.png (6 px/pt, centred on the lamp):
  round inserts (ORBT, S-T-A-R, kickback, countdown, the arrow stacks), the five shot arrows (each in its own
  heading, so the gloss stays upper-left), and the planet arc: there the painted planet IS the print on a clear
  insert, so _off is only the glass (rim + gloss, see-through) and _on an ADDITIVE backlight (white-hot centre, the
  planet's colour round it) the game lays over the painting.
Usage: python3 tour_paint_inserts.py out_dir"""
import sys, os, math
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else 'ins'
os.makedirs(OUT, exist_ok=True)
S = 6


def grid(half_w, half_h=None):
    half_h = half_w if half_h is None else half_h
    nx, ny = int(round(2 * half_w * S)), int(round(2 * half_h * S))
    x = (np.arange(nx) + 0.5) / S - half_w
    y = -((np.arange(ny) + 0.5) / S - half_h)
    return np.meshgrid(x, y)


def save(name, rgb, a):
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name))


def smooth(edge, d, w=0.6):
    """1 inside (d < edge) fading to 0 over w pt: antialiased edges."""
    return np.clip((edge - d) / w + 0.5, 0, 1)


def gloss(X, Y, inside, scale):
    """The clear coat: a soft crescent highlight up-left, a small sharp glint, a faint window reflection."""
    cres = np.exp(-(((X + 0.32 * scale) / (0.42 * scale)) ** 2 + ((Y - 0.38 * scale) / (0.20 * scale)) ** 2))
    glint = np.exp(-(((X + 0.38 * scale) ** 2 + (Y - 0.42 * scale) ** 2) / (0.07 * scale) ** 2))
    return (0.28 * cres + 0.65 * glint) * inside


def body(col, facet, hot, lit, rim_t):
    """Plastic colour. facet: −1…1 prism pattern; hot: 0…1 nearness to the bulb; rim_t: 0 centre … 1 edge."""
    col = np.array(col)
    if not lit:
        base = col * 0.30 + 0.015
        rgb = base[None, None, :] * (1 + 0.38 * facet[..., None]) * (1 - 0.35 * rim_t[..., None])
        # a little light the bulb's cavity throws back up through the plastic
        rgb += col * 0.05 * hot[..., None]
        return rgb
    sat = np.clip(col * 1.05, 0, 1)
    pale = np.clip(col * 0.45 + 0.55, 0, 1)
    white = np.array([1.0, 0.99, 0.94])
    t = hot[..., None]
    rgb = sat * (1 - t) + pale * t
    rgb = rgb * (1 - np.clip(t - 0.6, 0, 1) * 2.2) + white * np.clip(t - 0.6, 0, 1) * 2.2
    rgb = rgb * (1 + 0.20 * facet[..., None]) * (1 - 0.22 * rim_t[..., None] ** 2)
    return rgb


def round_insert(key, r, col, facets=24):
    half = r + 2.2
    X, Y = grid(half)
    d = np.hypot(X, Y)
    inside = smooth(r, d)
    ink = smooth(r + 1.5, d) * (1 - inside)
    th = np.arctan2(Y, X)
    ridge = np.abs(((th / (2 * math.pi) * facets) % 1) - 0.5) * 2          # 0 at a facet edge … 1 at its middle
    ring = np.abs(((d / max(r, 1) * 2.2) % 1) - 0.5) * 2                   # concentric steps of the underside
    facet = (ridge - 0.5) * 0.9 + (ring - 0.5) * 0.35
    rim_t = np.clip(d / r, 0, 1)
    bx, by = -0.12 * r, 0.10 * r                                            # the bulb, a touch up-left
    hot = np.exp(-((X - bx) ** 2 + (Y - by) ** 2) / (0.55 * r) ** 2)
    for lit in (False, True):
        rgb = body(col, facet, hot, lit, rim_t)
        rgb = rgb + gloss(X, Y, inside, r)[..., None] * (0.6 if lit else 1.0)
        a = inside * (0.97 if not lit else 1.0) + ink
        out = rgb * inside[..., None] / np.maximum(a, 1e-6)[..., None]     # the ink is black
        save(f'tour_insert_{key}_{"on" if lit else "off"}.png', out, a)


def arrow_insert(key, heading, col):
    a = math.radians(heading)
    ux, uy = math.cos(a), math.sin(a)
    vx, vy = -uy, ux
    half = 24
    X, Y = grid(half)
    F = X * ux + Y * uy                                                     # along the arrow
    G = X * vx + Y * vy                                                     # across
    # the arrowhead (tools/tour_floor_lower.py arrow()): tip (18, 0), wings (−8, ±13), notch (−3, 0)
    def inside_head(f, g, grow=0.0):
        tip, wing_f, wing_g, notch = 18 + grow * 1.6, -8 - grow, 13 + grow * 1.2, -3 - grow
        # front edges: from the tip to each wing; back edges: from each wing to the notch
        g = np.abs(g)
        front = (tip - f) * wing_g - g * (tip - wing_f)                     # > 0 on the inner side
        back = (f - notch) * wing_g + g * (notch - wing_f)                  # > 0 on the inner side
        return np.minimum(front / math.hypot(wing_g, tip - wing_f), back / math.hypot(wing_g, notch - wing_f))
    sd = inside_head(F, G)                                                  # signed distance-ish, pt
    inside = np.clip(sd / 0.6 + 0.5, 0, 1)
    ink = np.clip(inside_head(F, G, 1.8) / 0.6 + 0.5, 0, 1) * (1 - inside)
    # chevron facets parallel to the edges, and a ridge down the middle
    chev = np.abs(((sd / 2.2) % 1) - 0.5) * 2
    spine = np.exp(-(G / 1.2) ** 2)
    facet = (chev - 0.5) * 0.8 + spine * 0.4
    rim_t = np.clip(1 - sd / 6.0, 0, 1)
    hot = np.exp(-(((F - 3) / 9) ** 2 + (G / 6) ** 2))
    for lit in (False, True):
        rgb = body(col, facet, hot, lit, rim_t)
        rgb = rgb + gloss(X, Y, inside, 12)[..., None] * (0.6 if lit else 1.0)
        al = inside * (0.97 if not lit else 1.0) + ink
        out = rgb * inside[..., None] / np.maximum(al, 1e-6)[..., None]
        save(f'tour_insert_{key}_{"on" if lit else "off"}.png', out, al)


def planet_insert(key, r, col):
    """Over a painted planet: _off is clear glass (rim + gloss); _on an additive backlight."""
    half = r + 3.2
    X, Y = grid(half)
    d = np.hypot(X, Y)
    inside = smooth(r + 2.6, d)
    rim = np.clip(1 - np.abs(d - (r + 2.6)) / 0.7, 0, 1) * 0.6
    g = gloss(X, Y, inside, r + 2.6)
    a_off = np.clip(rim + g * 0.9, 0, 1)
    rgb_off = np.where(rim[..., None] > g[..., None], 0.0, 1.0) * np.ones(3)
    save(f'tour_insert_{key}_off.png', rgb_off, a_off)
    # v2b: gentler, so the printed planet still reads through its backlight (full strength washed it to white)
    hot = np.exp(-(d / (0.6 * r)) ** 2)
    col = np.array(col)
    light = col * (1 - 0.5 * hot[..., None]) + np.array([1.0, 0.98, 0.92]) * 0.5 * hot[..., None]
    k = inside * (0.22 + 0.22 * hot)
    save(f'tour_insert_{key}_on.png', light * k[..., None], np.ones_like(k))   # additive: alpha unused


AMBER = (1.0, 0.62, 0.12)
round_insert('orbt', 8.5, AMBER)
round_insert('star', 8.0, AMBER)
round_insert('kickback', 8.0, (1.0, 0.16, 0.10))
round_insert('countdown', 7.2, (1.0, 0.40, 0.10))
round_insert('stack_gold', 4.0, (1.0, 0.80, 0.20), facets=12)
round_insert('stack_red', 4.0, (1.0, 0.18, 0.16), facets=12)
round_insert('stack_blue', 4.0, (0.20, 0.60, 1.0), facets=12)
for name, heading, col in [('leftOrbit', 108, (0.20, 0.70, 1.0)), ('moon', 100, (0.85, 0.88, 1.0)),
                           ('rocket', 90, (1.0, 0.42, 0.10)), ('saturn', 72, (1.0, 0.80, 0.38)),
                           ('rightOrbit', 66, (0.20, 0.70, 1.0))]:
    arrow_insert('arrow_' + name, heading, col)
for name, r, col in [('mercury', 8, (0.80, 0.76, 0.70)), ('venus', 8, (1.0, 0.86, 0.55)), ('mars', 8, (1.0, 0.45, 0.25)),
                     ('moon', 8, (0.85, 0.88, 0.95)), ('jupiter', 8, (1.0, 0.80, 0.55)), ('saturn', 8, (1.0, 0.88, 0.55)),
                     ('uranus', 8, (0.55, 0.95, 1.0)), ('neptune', 8, (0.40, 0.60, 1.0)), ('sun', 10.5, (1.0, 0.72, 0.25))]:
    planet_insert('planet_' + name, r, col)
print('painted', len(os.listdir(OUT)), 'images')
