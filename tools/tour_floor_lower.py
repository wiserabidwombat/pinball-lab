"""Table 06 (Orbit: Grand Tour) M5 v1 (look development): the printed floor of the lower table (pycairo), used as the
Blender floor texture by tour_bake_lower.py. Realistic space (the plan's look): a deep navy-black field with faint
nebulae, the Milky Way and stars; Earth rising behind the flippers (the tour starts from home) with a dashed launch
path up the centre; the lamp inserts painted unlit — the arc of nine planet inserts (Mercury … Sun) in their real
colours, O-R-B-T, the kickback, the 5-4-3-2-1 countdown and an arrow with a three-lamp stack at every shot; gunmetal
aprons with a gold pinstripe and the title; Mars ground inside the rover bunker.
World points, y up; the image covers L.LOWER_RECT at L.PX_PER_PT * scale.
Usage: python3 tour_floor_lower.py out.png [scale]"""
import cairo, math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tour_look_layout as L

OUT = sys.argv[1]
SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
X0, Y0, W, H = L.LOWER_RECT
S = L.PX_PER_PT * SCALE
surf = cairo.ImageSurface(cairo.FORMAT_RGB24, int(W * S), int(H * S))
cr = cairo.Context(surf)
cr.translate(-X0 * S, (Y0 + H) * S)          # world points, y up
cr.scale(S, -S)
rnd = random.Random(6)


def poly(pts):
    cr.move_to(*pts[0])
    for p in pts[1:]:
        cr.line_to(*p)
    cr.close_path()


def rgb(c, a=1.0):
    cr.set_source_rgba(c[0], c[1], c[2], a)


def circle(x, y, r):
    cr.new_sub_path(); cr.arc(x, y, r, 0, 2 * math.pi)


def glow(x, y, r, col, a, sx=1.0, sy=1.0, rot=0.0):
    """A soft radial cloud (nebula, star glow)."""
    cr.save(); cr.translate(x, y); cr.rotate(rot); cr.scale(sx, sy)
    g = cairo.RadialGradient(0, 0, 0, 0, 0, r)
    g.add_color_stop_rgba(0, *col, a); g.add_color_stop_rgba(0.45, *col, a * 0.45); g.add_color_stop_rgba(1, *col, 0)
    cr.set_source(g); circle(0, 0, r); cr.fill(); cr.restore()


def text(x, y, s, size, col, a=1.0, angle=0.0, bold=True, spacing=0.0):
    cr.save(); cr.translate(x, y); cr.rotate(angle); cr.scale(1, -1)
    cr.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL,
                        cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size)
    widths = [cr.text_extents(ch).x_advance for ch in s]
    total = sum(widths) + spacing * (len(s) - 1)
    ext = cr.text_extents(s)
    cx = -total / 2
    rgb(col, a)
    for ch, w in zip(s, widths):
        cr.move_to(cx, -ext.y_bearing / 2 - ext.height / 2 + ext.height / 2)
        cr.show_text(ch); cx += w + spacing
    cr.restore()


# ------------------------------------------------------------------ deep space
g = cairo.LinearGradient(0, Y0, 0, Y0 + H)
g.add_color_stop_rgb(0, 0.010, 0.014, 0.035)
g.add_color_stop_rgb(0.55, 0.016, 0.022, 0.060)
g.add_color_stop_rgb(1, 0.022, 0.020, 0.075)
cr.set_source(g); cr.rectangle(X0, Y0, W, H); cr.fill()

# nebulae: a few broad, faint clouds (teal low left, violet-magenta high right, a dusty rose wisp)
for (x, y, r, col, a, sx, sy, rot) in [(110, 520, 260, (0.06, 0.32, 0.42), 0.20, 1.0, 0.55, 0.6),
                                        (470, 600, 240, (0.36, 0.10, 0.42), 0.20, 1.0, 0.6, -0.5),
                                        (330, 470, 170, (0.50, 0.16, 0.30), 0.10, 1.0, 0.45, 0.3),
                                        (160, 680, 150, (0.18, 0.12, 0.45), 0.16, 1.0, 0.7, 0.0),
                                        (520, 420, 150, (0.06, 0.22, 0.40), 0.14, 1.0, 0.6, 1.0)]:
    glow(x, y, r, col, a, sx, sy, rot)
    for k in range(10):                      # break each cloud into wisps
        glow(x + rnd.gauss(0, r * 0.35), y + rnd.gauss(0, r * 0.2), r * rnd.uniform(0.2, 0.45), col,
             a * rnd.uniform(0.3, 0.8), 1.0, rnd.uniform(0.3, 0.7), rot + rnd.uniform(-0.4, 0.4))

# the Milky Way: a soft diagonal band, lower left to upper right, crowded with faint stars and dark dust lanes
band_a = math.radians(38)
bx, by = 300, 470
glow(bx, by, 520, (0.55, 0.55, 0.70), 0.10, 1.0, 0.16, band_a)
glow(bx + 40, by + 30, 380, (0.75, 0.68, 0.62), 0.07, 1.0, 0.10, band_a)
for k in range(9):                           # dust lanes
    t = rnd.uniform(-300, 300)
    glow(bx + t * math.cos(band_a), by + t * math.sin(band_a) + rnd.gauss(0, 10), rnd.uniform(30, 70),
         (0.0, 0.0, 0.0), 0.35, 1.0, 0.25, band_a + rnd.uniform(-0.2, 0.2))
for k in range(5500):
    t = rnd.uniform(-560, 560); off = rnd.gauss(0, 42)
    x = bx + t * math.cos(band_a) - off * math.sin(band_a)
    y = by + t * math.sin(band_a) + off * math.cos(band_a)
    b = rnd.uniform(0.35, 0.85)
    rgb((b, b * rnd.uniform(0.92, 1.0), b * rnd.uniform(0.95, 1.05)), rnd.uniform(0.15, 0.5))
    circle(x, y, rnd.uniform(0.18, 0.42)); cr.fill()

# stars everywhere, a few bright ones with a glint
for k in range(2600):
    x = rnd.uniform(X0, X0 + W); y = rnd.uniform(Y0, Y0 + H)
    b = rnd.random() ** 2.4
    tint = rnd.choice([(1.0, 1.0, 1.0), (0.80, 0.88, 1.0), (1.0, 0.92, 0.80), (1.0, 0.85, 0.75)])
    rgb(tint, 0.25 + 0.75 * b); circle(x, y, 0.25 + 0.75 * b); cr.fill()
for k in range(36):
    x = rnd.uniform(X0, X0 + W); y = rnd.uniform(Y0 + 150, Y0 + H)
    glow(x, y, rnd.uniform(4, 9), (0.75, 0.85, 1.0), 0.55)
    rgb((1, 1, 1), 0.9); circle(x, y, 0.9); cr.fill()
    rgb((0.85, 0.92, 1.0), 0.45); cr.set_line_width(0.35)
    ln = rnd.uniform(5, 10)
    cr.move_to(x - ln, y); cr.line_to(x + ln, y); cr.move_to(x, y - ln); cr.line_to(x, y + ln); cr.stroke()

# ------------------------------------------------------------------ Earth rising behind the flippers
# A lit sphere computed per pixel (numpy): continents and clouds from sums of random 3D sine waves on the sphere
# (organic, seamless), ocean depth shading, a soft terminator to the lower right with city lights on the night side,
# limb darkening and a thin blue atmosphere. Painted onto the cairo canvas as an image layer.
import numpy as np
EX, EY, ER = 284, -10, 290
LIGHT = np.array([-0.55, 0.62, 0.56]); LIGHT /= np.linalg.norm(LIGHT)
nrnd = np.random.default_rng(11)


def field(p, n, kmin, kmax, seed_shift=0.0):
    out = np.zeros(p.shape[:-1])
    for i in range(n):
        k = nrnd.normal(size=3); k /= np.linalg.norm(k); k *= nrnd.uniform(kmin, kmax)
        out += np.sin(p @ k + nrnd.uniform(0, 6.3) + seed_shift) / (np.linalg.norm(k) ** 0.9)
    return out / (out.std() + 1e-9)


PW, PH = surf.get_width(), surf.get_height()
jj, ii = np.meshgrid(np.arange(PW), np.arange(PH))
wx = X0 + (jj + 0.5) / S; wy = Y0 + H - (ii + 0.5) / S
dx, dy = (wx - EX) / ER, (wy - EY) / ER
rr = dx * dx + dy * dy
inside = rr < 1
dz = np.sqrt(np.clip(1 - rr, 0, 1))
P3 = np.stack([dx, dy, dz], -1)
# tilt the globe a little so the continents don't line up with the screen
c, s_ = math.cos(0.5), math.sin(0.5)
Pt = P3 @ np.array([[1, 0, 0], [0, c, -s_], [0, s_, c]])
land_f = field(Pt * 1.0, 26, 2.5, 8.0) + 0.45 * field(Pt, 40, 10, 32)
land = np.clip((land_f - 0.45) * 4, 0, 1)
warp = Pt + 0.18 * np.stack([field(Pt, 8, 3, 6), field(Pt, 8, 3, 6), field(Pt, 8, 3, 6)], -1)
cloud_f = field(warp * np.array([1.0, 2.6, 1.0]), 30, 3, 14) + 0.3 * field(warp, 30, 16, 36)
cloud = np.clip((cloud_f - 0.75) * 1.4, 0, 1) ** 1.2 * 0.8
ocean = np.stack([0.03 + 0.02 * land_f, 0.13 + 0.04 * land_f, 0.38 + 0.06 * land_f], -1)
veg = field(Pt, 12, 4, 10)
land_col = np.where(veg[..., None] > 0.0, np.array([0.20, 0.32, 0.14]), np.array([0.52, 0.44, 0.28]))
land_col = land_col * (0.9 + 0.12 * field(Pt, 10, 15, 30))[..., None]
col = ocean * (1 - land[..., None]) + land_col * land[..., None]
col = col * (1 - cloud[..., None]) + np.array([0.95, 0.96, 1.0]) * cloud[..., None]
lam = np.clip(P3 @ LIGHT, 0, 1)
day = np.clip((P3 @ LIGHT + 0.08) * 3.0, 0, 1)
shade = 0.12 + 0.95 * lam ** 0.8
col = col * shade[..., None]
cities = (land > 0.7) & (field(Pt, 20, 30, 60) > 1.6) & (cloud < 0.3)
night = (1 - day)
col = col + cities[..., None] * night[..., None] * np.array([1.0, 0.75, 0.35]) * 0.55
spec = np.clip((P3 @ (LIGHT + np.array([0, 0, 1])) / np.linalg.norm(LIGHT + np.array([0, 0, 1]))), 0, 1) ** 40
col = col + ((1 - land) * (1 - cloud) * spec)[..., None] * 0.35
rim = np.clip(1 - dz, 0, 1) ** 3
col = col * (1 - 0.35 * rim[..., None]) + np.array([0.35, 0.6, 1.0]) * (rim * (0.25 + 0.75 * day))[..., None] * 0.55
alpha = np.clip((1 - np.sqrt(rr)) * ER * S * 0.8, 0, 1) * inside
# atmosphere halo just outside the limb
dist = np.sqrt(rr)
halo = np.clip(1 - (dist - 1) * ER / 22, 0, 1) * (dist >= 1) * np.clip(0.2 + 0.8 * np.clip(np.stack([dx, dy, np.zeros_like(dx)], -1) @ LIGHT / np.maximum(dist, 1e-6), 0, 1), 0, 1)
halo = halo ** 2 * 0.6
rgb_ = np.clip(col, 0, 1) * alpha[..., None] + np.array([0.35, 0.62, 1.0]) * halo[..., None]
a_ = np.clip(alpha + halo, 0, 1)
buf = np.zeros((PH, PW, 4), np.uint8)
buf[..., 0] = (np.clip(rgb_[..., 2], 0, 1) * 255).astype(np.uint8)   # cairo ARGB32 little-endian: B G R A, premultiplied
buf[..., 1] = (np.clip(rgb_[..., 1], 0, 1) * 255).astype(np.uint8)
buf[..., 2] = (np.clip(rgb_[..., 0], 0, 1) * 255).astype(np.uint8)
buf[..., 3] = (a_ * 255).astype(np.uint8)
earth = cairo.ImageSurface.create_for_data(memoryview(buf), cairo.FORMAT_ARGB32, PW, PH, PW * 4)
cr.save(); cr.identity_matrix(); cr.set_source_surface(earth, 0, 0); cr.paint(); cr.restore()
ER_TOP = EY + ER

# the launch path: a dashed gold trajectory from Earth up the centre toward the rocket
rgb((0.98, 0.78, 0.36), 0.55); cr.set_line_width(1.6); cr.set_dash([6, 5])
cr.move_to(284, ER_TOP + 4)
cr.curve_to(300, 380, 268, 440, 284, 488); cr.stroke(); cr.set_dash([])

# ------------------------------------------------------------------ lamp inserts (unlit)
def insert_round(x, y, r, col, label=None, label_col=(1, 1, 1)):
    """A jewel insert: a dark socket ring, coloured plastic (dim, a hot spot where the bulb sits) and a thin bevel."""
    rgb((0.0, 0.0, 0.0), 0.75); circle(x, y, r + 1.6); cr.fill()
    g = cairo.RadialGradient(x - r * 0.25, y + r * 0.3, 0, x, y, r)
    g.add_color_stop_rgb(0, *(min(1, c * 0.75 + 0.06) for c in col))
    g.add_color_stop_rgb(1, *(c * 0.30 for c in col))
    cr.set_source(g); circle(x, y, r); cr.fill()
    rgb((1, 1, 1), 0.22); cr.set_line_width(0.6); cr.arc(x, y, r - 0.7, math.radians(100), math.radians(200)); cr.stroke()
    if label:
        text(x, y, label, r * 1.05, label_col, 0.85)


def planet(x, y, r, col, band=None, rings=False):
    """A small planet in its real colours, lit from the upper left, on a dark insert."""
    rgb((0, 0, 0), 0.8); circle(x, y, r + 3.2); cr.fill()
    rgb((0.55, 0.60, 0.70), 0.7); cr.set_line_width(0.9); circle(x, y, r + 2.6); cr.stroke()
    if rings:
        cr.save(); cr.translate(x, y); cr.rotate(-0.35); cr.scale(1, 0.32)
        rgb((0.85, 0.76, 0.55), 0.85); cr.set_line_width(1.8); circle(0, 0, r * 1.7); cr.stroke(); cr.restore()
    cr.save(); circle(x, y, r); cr.clip()
    g = cairo.RadialGradient(x - r * 0.4, y + r * 0.4, 0, x, y, r * 1.1)
    g.add_color_stop_rgb(0, *(min(1, c * 1.25) for c in col)); g.add_color_stop_rgb(1, *(c * 0.25 for c in col))
    cr.set_source(g); circle(x, y, r); cr.fill()
    if band:
        for i, bc in enumerate(band):
            rgb(bc, 0.45); cr.rectangle(x - r, y - r + (i + 0.6) * 2 * r / (len(band) + 0.6), 2 * r, r * 0.22); cr.fill()
    cr.restore()


# the planet arc: nine inserts, Mercury to the Sun, across the insert field above Earth
PLANETS = [('MERCURY', (0.60, 0.57, 0.53), None, False),
           ('VENUS', (0.90, 0.78, 0.52), None, False),
           ('MARS', (0.78, 0.34, 0.18), None, False),
           ('MOON', (0.72, 0.72, 0.74), None, False),
           ('JUPITER', (0.84, 0.70, 0.52), [(0.65, 0.42, 0.26), (0.92, 0.86, 0.74), (0.62, 0.38, 0.22)], False),
           ('SATURN', (0.88, 0.78, 0.55), [(0.78, 0.66, 0.42)], True),
           ('URANUS', (0.58, 0.86, 0.88), None, False),
           ('NEPTUNE', (0.25, 0.42, 0.90), None, False),
           ('SUN', (1.0, 0.72, 0.22), None, False)]
AC, AR = (284, 300), 135
for i, (name, col, band, rings) in enumerate(PLANETS):
    a = math.radians(158 - i * (136 / 8))
    x, y = AC[0] + AR * math.cos(a), AC[1] + AR * math.sin(a)
    r = 10.5 if name == 'SUN' else 8.0
    if name == 'SUN':
        glow(x, y, 26, (1.0, 0.6, 0.15), 0.25)
    planet(x, y, r, col, band, rings)
    text(x, y - r - 9, name, 4.2, (0.80, 0.86, 1.0), 0.75, spacing=0.4)

# O-R-B-T lane inserts (amber) and the kickback (red)
for x, ch in zip(L.LANE_XS, L.LANE_LETTERS):
    insert_round(x, L.LANE_LAMP_Y, 8.5, (1.0, 0.62, 0.15), ch, (0.1, 0.05, 0.0))
insert_round(*L.KICKBACK_LAMP, 8, (0.95, 0.15, 0.12))
text(L.KICKBACK_LAMP[0], L.KICKBACK_LAMP[1] - 15, 'KICKBACK', 4.0, (1.0, 0.55, 0.5), 0.8, spacing=0.3)

# the countdown column: 5-4-3-2-1 (5 at the top), under the centre arrow
for i, (x, y) in enumerate(L.COUNTDOWN_LAMPS):
    insert_round(x, y, 7.2, (1.0, 0.42, 0.12), str(i + 1), (0.12, 0.03, 0.0))


# shot arrows: an arrowhead insert pointing at each shot, with its three-lamp stack (goal, jackpot, combo) behind it
def arrow(x, y, heading, col):
    a = math.radians(heading); ux, uy = math.cos(a), math.sin(a); vx, vy = -uy, ux
    def p(f, s): return (x + ux * f + vx * s, y + uy * f + vy * s)
    shape = [p(18, 0), p(-8, 13), p(-3, 0), p(-8, -13)]
    rgb((0, 0, 0), 0.8); poly([(px + ux * 0 , py) for px, py in [p(21, 0), p(-10, 16), p(-5, 0), p(-10, -16)]]); cr.fill()
    g = cairo.LinearGradient(*p(18, 0), *p(-8, 0))
    g.add_color_stop_rgb(0, *(c * 0.75 for c in col)); g.add_color_stop_rgb(1, *(c * 0.3 for c in col))
    cr.set_source(g); poly(shape); cr.fill()
    for k, lc in enumerate([(1.0, 0.85, 0.3), (0.95, 0.25, 0.25), (0.3, 0.7, 1.0)]):
        insert_round(*p(-17 - k * 11, 0), 4.0, lc)


arrow(150, 655, 108, (0.30, 0.75, 1.0))      # left orbit
arrow(208, 655, 100, (0.85, 0.85, 0.95))     # Moon ramp
arrow(284, 650, 90, (1.0, 0.45, 0.15))       # the rocket
arrow(392, 640, 72, (0.95, 0.80, 0.45))      # Saturn ramp
arrow(452, 666, 66, (0.30, 0.75, 1.0))       # right orbit

# the rocket post: a dark socket ring between the flippers (the post rises through it)
rgb((0, 0, 0), 0.85); circle(*L.ROCKET_POST, L.ROCKET_POST_R + 3); cr.fill()

# ------------------------------------------------------------------ Mars ground inside the rover bunker
face = [(507.0, 507.5), (489.9, 587.7)]
bunker = [face[0], face[1], (516, 606), (548, 623.3), (548, 522), (532, 514), (507.0, 509.5)]
cr.save(); poly(bunker); cr.clip()
g = cairo.LinearGradient(490, 510, 548, 620)
g.add_color_stop_rgb(0, 0.46, 0.20, 0.10); g.add_color_stop_rgb(1, 0.30, 0.12, 0.06)
cr.set_source(g); cr.rectangle(480, 500, 80, 130); cr.fill()
for k in range(160):
    rgb(rnd.choice([(0.6, 0.3, 0.16), (0.25, 0.10, 0.05), (0.7, 0.42, 0.25)]), rnd.uniform(0.3, 0.7))
    circle(rnd.uniform(485, 550), rnd.uniform(505, 625), rnd.uniform(0.4, 1.8)); cr.fill()
cr.restore()

# ------------------------------------------------------------------ the shooter lane: a darker strip
rgb((0.01, 0.012, 0.03), 0.85); cr.rectangle(L.LANE_X, Y0, L.RIGHT_X - L.LANE_X + 8, H); cr.fill()

# ------------------------------------------------------------------ aprons: gunmetal with a gold pinstripe and the title
left_apron = [(12, L.APRON_TOP_Y + 3), (L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, Y0), (12, Y0)]
right_apron = [(L.LANE_X, L.APRON_TOP_Y), (L.MIRROR - L.DRAIN_X, L.DRAIN_Y), (L.MIRROR - L.DRAIN_X, Y0),
               (588, Y0), (588, L.LANE_FLOOR_Y), (L.LANE_X, L.LANE_FLOOR_Y)]
for pts in (left_apron, right_apron):
    g = cairo.LinearGradient(0, Y0, 0, L.APRON_TOP_Y)
    g.add_color_stop_rgb(0, 0.05, 0.06, 0.10); g.add_color_stop_rgb(1, 0.10, 0.12, 0.18)
    cr.set_source(g); poly(pts); cr.fill()
    for k in range(260):                     # brushed metal streaks
        x = rnd.uniform(0, 600); y = rnd.uniform(Y0, L.APRON_TOP_Y)
        rgb((0.55, 0.6, 0.75), rnd.uniform(0.02, 0.06)); cr.set_line_width(0.4)
        cr.move_to(x, y); cr.line_to(x + rnd.uniform(15, 50), y); cr.stroke()
GOLD = (0.88, 0.70, 0.36)
rgb(GOLD, 0.85); cr.set_line_width(0.9)
cr.move_to(26, L.APRON_TOP_Y - 8); cr.line_to(L.DRAIN_X - 6, L.DRAIN_Y - 8); cr.line_to(L.DRAIN_X - 6, Y0 + 30); cr.stroke()
cr.move_to(L.LANE_X - 6, L.APRON_TOP_Y - 8); cr.line_to(L.MIRROR - L.DRAIN_X + 6, L.DRAIN_Y - 8)
cr.line_to(L.MIRROR - L.DRAIN_X + 6, Y0 + 30); cr.stroke()
text(140, 50, 'ORBIT', 17, GOLD, 0.95, spacing=3)
text(140, 26, 'TABLE 06 · PINBALL LAB', 5.5, (0.75, 0.80, 0.92), 0.8, spacing=1)
text(430, 50, 'GRAND TOUR', 13, GOLD, 0.95, spacing=1.5)
for i, (name, col, band, rings) in enumerate(PLANETS[:8]):   # a small row of planets under the title
    planet(372 + i * 16, 22, 4.2, col, None, rings)
# drain: dark well between the aprons
g = cairo.LinearGradient(0, L.DRAIN_LIP_Y, 0, Y0)
g.add_color_stop_rgb(0, 0.02, 0.02, 0.04); g.add_color_stop_rgb(1, 0.0, 0.0, 0.0)
cr.set_source(g); cr.rectangle(L.DRAIN_X, Y0, L.MIRROR - 2 * L.DRAIN_X, L.DRAIN_LIP_Y - Y0); cr.fill()

surf.write_to_png(OUT)
print('wrote', OUT, surf.get_width(), surf.get_height())
