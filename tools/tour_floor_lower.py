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
# M5 v4 sky placement: (centre x, centre y, pt per degree, rotation rad)
SKY_UMA = (150, 540, 4.6, 0.10)
SKY_CAS = (392, 560, 4.4, -0.25)
SKY_ORI = (338, 322, 1.9, 0.0)
SKY_SOMBRERO = (92, 455)


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

# ------------------------------------------------------------------ M5 v4: galaxies and real constellations
# Aaron: "in the background a few small galaxy swirls. Like Andromeda... maybe even a few real constellations. I think the
# size and brightness of the current stars is perfect." Real sky positions: Cassiopeia's W with the Andromeda galaxy
# (M31) below it where it really is; the Big Dipper with the Whirlpool (M51) just off the end of its handle; Orion.
# Stars drawn in the same style and range as the bright glint stars above; the chart lines faint and thin.
import numpy as _np
import numpy as np


def galaxy(x, y, r, incl, rot, arms=2, wind=4.0, core_col=(1.0, 0.88, 0.70), disc_col=(0.70, 0.80, 1.0), a=1.0,
           seed=0, dust=0.6):
    """A small spiral galaxy, painted additively: bulge, log-spiral arms with knots, dust lanes on the near side."""
    R = int(math.ceil(r * S * 1.25)); n = 2 * R + 1
    jj, ii = _np.meshgrid(_np.arange(n) - R, _np.arange(n) - R)
    px, py = jj / (r * S), -ii / (r * S)                          # image y down → up
    c, s_ = math.cos(rot), math.sin(rot)
    u, v = px * c + py * s_, -px * s_ + py * c                    # galaxy axes (u along the major axis)
    v = v / max(math.cos(incl), 0.08)
    rr = _np.sqrt(u * u + v * v) + 1e-6; th = _np.arctan2(v, u)
    g = _np.random.default_rng(seed)
    knots = _np.zeros_like(rr)
    for _ in range(14):
        k = g.normal(size=2) * g.uniform(6, 18)
        knots += _np.sin(u * k[0] + v * k[1] + g.uniform(0, 6.3))
    knots = knots / (knots.std() + 1e-9)
    arm = (0.5 + 0.5 * _np.cos(arms * th - wind * _np.log(rr) + 0.25 * knots)) ** 2.5
    disc = _np.exp(-rr / 0.32) * (0.25 + 0.75 * arm) * (0.85 + 0.15 * knots)
    bulge = _np.exp(-(rr / 0.10) ** 1.2)
    lane = 1 - dust * (1 - arm) * _np.exp(-rr / 0.45) * (v < 0) * min(1.0, 2 * math.sin(incl))
    lum = (disc * 0.9 * lane)[..., None] * _np.array(disc_col) + (bulge * 1.1)[..., None] * _np.array(core_col)
    lum = _np.clip(lum * a * 1.7 * _np.clip(1.2 - rr, 0, 1)[..., None], 0, 1)
    buf = _np.zeros((n, n, 4), _np.uint8)
    al = _np.clip(lum.max(-1), 0, 1)
    buf[..., 0] = (lum[..., 2] * 255).astype(_np.uint8); buf[..., 1] = (lum[..., 1] * 255).astype(_np.uint8)
    buf[..., 2] = (lum[..., 0] * 255).astype(_np.uint8); buf[..., 3] = (al * 255).astype(_np.uint8)
    img = cairo.ImageSurface.create_for_data(memoryview(buf), cairo.FORMAT_ARGB32, n, n, n * 4)
    dx_, dy_ = cr.user_to_device(x, y)
    cr.save(); cr.identity_matrix(); cr.set_operator(cairo.OPERATOR_ADD)
    cr.set_source_surface(img, dx_ - R, dy_ - R); cr.paint(); cr.restore()


def star(x, y, mag):
    """A named star, in the same look as the field's bright glint stars (brighter for a lower magnitude)."""
    t = max(0.0, min(1.0, (3.6 - mag) / 3.5))                     # 0 = faint (mag 3.6) .. 1 = brightest
    glow(x, y, 3.5 + 5.5 * t, (0.75, 0.85, 1.0), 0.30 + 0.25 * t)
    rgb((1, 1, 1), 0.65 + 0.3 * t); circle(x, y, 0.55 + 0.4 * t); cr.fill()
    if t > 0.55:
        rgb((0.85, 0.92, 1.0), 0.45); cr.set_line_width(0.35)
        ln = 4 + 6 * (t - 0.55) / 0.45
        cr.move_to(x - ln, y); cr.line_to(x + ln, y); cr.move_to(x, y - ln); cr.line_to(x, y + ln); cr.stroke()


def constellation(stars, lines, cx, cy, scale, rot, extra=None):
    """stars: name → (RA hours, Dec degrees, magnitude). Projected round their mean (east to the left, as on the sky),
    scaled (pt per degree), rotated and placed at (cx, cy). Returns the projector for extras (galaxies)."""
    ra0 = sum(v[0] for v in stars.values()) / len(stars); de0 = sum(v[1] for v in stars.values()) / len(stars)
    cr0, sr0 = math.cos(rot), math.sin(rot)

    def proj(ra, de):
        X = -(ra - ra0) * 15 * math.cos(math.radians(de0)); Y = de - de0
        return (cx + scale * (X * cr0 - Y * sr0), cy + scale * (X * sr0 + Y * cr0))
    pts = {k: proj(v[0], v[1]) for k, v in stars.items()}
    rgb((0.62, 0.74, 1.0), 0.17); cr.set_line_width(0.45)
    for a_, b_ in lines:
        (x1, y1), (x2, y2) = pts[a_], pts[b_]
        L_ = math.hypot(x2 - x1, y2 - y1); ux, uy = (x2 - x1) / L_, (y2 - y1) / L_
        cr.move_to(x1 + ux * 4, y1 + uy * 4); cr.line_to(x2 - ux * 4, y2 - uy * 4)   # stop short of the stars
    cr.stroke()
    for k, v in stars.items():
        star(*pts[k], v[2])
    return proj


CAS = {'Caph': (0.153, 59.15, 2.3), 'Schedar': (0.675, 56.54, 2.2), 'Gamma': (0.945, 60.72, 2.4),
       'Ruchbah': (1.430, 60.24, 2.7), 'Segin': (1.907, 63.67, 3.4)}
UMA = {'Dubhe': (11.062, 61.75, 1.8), 'Merak': (11.031, 56.38, 2.4), 'Phecda': (11.897, 53.69, 2.4),
       'Megrez': (12.257, 57.03, 3.3), 'Alioth': (12.900, 55.96, 1.8), 'Mizar': (13.399, 54.93, 2.2),
       'Alkaid': (13.792, 49.31, 1.9)}
ORI = {'Betelgeuse': (5.919, 7.41, 0.5), 'Rigel': (5.242, -8.20, 0.1), 'Bellatrix': (5.418, 6.35, 1.6),
       'Saiph': (5.796, -9.67, 2.1), 'Alnitak': (5.679, -1.94, 1.8), 'Alnilam': (5.603, -1.20, 1.7),
       'Mintaka': (5.533, -0.30, 2.2), 'Meissa': (5.585, 9.93, 3.4)}
p = constellation(UMA, [('Dubhe', 'Merak'), ('Merak', 'Phecda'), ('Phecda', 'Megrez'), ('Megrez', 'Dubhe'),
                        ('Megrez', 'Alioth'), ('Alioth', 'Mizar'), ('Mizar', 'Alkaid')], *SKY_UMA)
galaxy(*p(13.498, 47.2), 12, math.radians(20), math.radians(30), wind=3.2, a=0.9, seed=3)          # M51 Whirlpool
p = constellation(CAS, [('Caph', 'Schedar'), ('Schedar', 'Gamma'), ('Gamma', 'Ruchbah'), ('Ruchbah', 'Segin')], *SKY_CAS)
# M5 v5 (Aaron, with a photo of M31: "same for andromeda"): tools/tour_sky_fx.andromeda — long tilted disc, warm bulge,
# dust lanes along the near side, a faint blue outer ring with star-forming knots, M32 and M110 — added onto the sky.
import tour_sky_fx as FX
def paint_add(img, x, y, width_pt, rot_deg):
    from PIL import Image as _I
    px = int(width_pt * S); h = int(px * img.shape[0] / img.shape[1])
    im = _I.fromarray((np.clip(img[..., :3], 0, 1) * 255).astype(np.uint8)).resize((px, h), _I.LANCZOS)
    im = im.rotate(rot_deg, resample=_I.BICUBIC, expand=True)
    a = np.asarray(im).astype(np.uint8); hh, ww = a.shape[:2]
    buf = np.zeros((hh, ww, 4), np.uint8); buf[..., 0] = a[..., 2]; buf[..., 1] = a[..., 1]; buf[..., 2] = a[..., 0]
    buf[..., 3] = a.max(-1)
    sf = cairo.ImageSurface.create_for_data(memoryview(buf), cairo.FORMAT_ARGB32, ww, hh, ww * 4)
    dx_, dy_ = cr.user_to_device(x, y)
    cr.save(); cr.identity_matrix(); cr.set_operator(cairo.OPERATOR_ADD)
    cr.set_source_surface(sf, dx_ - ww / 2, dy_ - hh / 2); cr.paint(); cr.restore()
paint_add(FX.andromeda(1400), *p(0.712, 41.27), 84, 38)                                             # M31
constellation(ORI, [('Meissa', 'Betelgeuse'), ('Meissa', 'Bellatrix'), ('Betelgeuse', 'Alnitak'),
                    ('Bellatrix', 'Mintaka'), ('Mintaka', 'Alnilam'), ('Alnilam', 'Alnitak'), ('Alnitak', 'Saiph'),
                    ('Mintaka', 'Rigel')], *SKY_ORI)
galaxy(*SKY_SOMBRERO, 12, math.radians(80), math.radians(-12), wind=3.0, a=1.2, seed=5, dust=1.0)   # a far edge-on one

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
# M5 v2 (Aaron: "I would like to see the earth look more real"): the real Earth — NASA's Blue Marble Next Generation
# (public domain, earthsrc/bmng.jpg, 5400 x 2700 equirectangular, from the basemap-data package) projected
# orthographically, centred on the North Atlantic so the visible cap shows the Americas, Europe and Africa.
from PIL import Image as _Img
BM = np.asarray(_Img.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'earthsrc', 'bmng.jpg')).convert('RGB'),
                np.float32) / 255.0
BM = BM ** 1.15                                                  # slightly deeper oceans / richer land
LAT0, LON0, ROLL = math.radians(-8), math.radians(-38), math.radians(-14)
cr_, sr_ = math.cos(ROLL), math.sin(ROLL)
ox, oy = dx * cr_ - dy * sr_, dx * sr_ + dy * cr_               # roll the globe so the coastlines don't sit square
rho = np.sqrt(np.clip(ox * ox + oy * oy, 1e-12, 1)); cc = np.arcsin(np.clip(rho, 0, 1))
lat = np.arcsin(np.clip(np.cos(cc) * math.sin(LAT0) + oy * np.sin(cc) * math.cos(LAT0) / rho, -1, 1))
lon = LON0 + np.arctan2(ox * np.sin(cc), rho * np.cos(cc) * math.cos(LAT0) - oy * np.sin(cc) * math.sin(LAT0))
u = ((lon / (2 * math.pi) + 0.5) % 1.0) * (BM.shape[1] - 1)
v = (0.5 - lat / math.pi) * (BM.shape[0] - 1)
u0 = np.floor(u).astype(int); v0 = np.clip(np.floor(v).astype(int), 0, BM.shape[0] - 2); fu = (u - u0)[..., None]; fv = (v - v0)[..., None]
u1 = (u0 + 1) % BM.shape[1]
col = (BM[v0, u0] * (1 - fu) + BM[v0, u1] * fu) * (1 - fv) + (BM[v0 + 1, u0] * (1 - fu) + BM[v0 + 1, u1] * fu) * fv
# land / water from the image itself (water is blue-dominant and dark), for the sun glint and city lights
land = np.clip((col[..., 1] + col[..., 0] * 0.8 - col[..., 2] * 1.1 + 0.05) * 6, 0, 1)
# clouds: thin, swirling weather — domain-warped noise in lat/lon so bands run east-west, sparse at the subtropics
E3 = np.stack([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)], -1)
# M5 v3 (Aaron: "the clouds should be a bit more whispy"): a wispy cloud map made by tools/tour_cloud_map.py
# (earthsrc/clouds.png, equirectangular 4096 x 2048, 8-bit), sampled at the same lat / lon as the Blue Marble.
CM = np.asarray(_Img.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'earthsrc', 'clouds.png')), np.float32) / 255.0
cu = ((lon / (2 * math.pi) + 0.5) % 1.0) * (CM.shape[1] - 1) + 64   # busiest weather over the view
cv = (0.5 - lat / math.pi) * (CM.shape[0] - 1)
from scipy import ndimage as _nd
cloud = _nd.map_coordinates(CM, [cv, cu], order=1, mode='wrap') * 0.8
ctex = np.ones_like(cloud)
# M5 v5 (Aaron, with a satellite photo: "make the hurricane look more realistic"): tools/tour_sky_fx.hurricane — a big
# bright central overcast with streaks along the wind, a small clear eye, popcorn-cumulus rain bands — sampled in the
# storm's tangent plane (off Nova Scotia, left of the left flipper), its relief shading kept.
import tour_sky_fx as FX
SLAT, SLON, SR = math.radians(45), math.radians(-56), math.radians(16.0)
C = np.array([math.cos(SLAT) * math.cos(SLON), math.cos(SLAT) * math.sin(SLON), math.sin(SLAT)])
east = np.array([-math.sin(SLON), math.cos(SLON), 0.0]); north = np.cross(C, east)
HC, HS = FX.hurricane(1024)
tx = (E3 @ east) / math.sin(SR); ty = (E3 @ north) / math.sin(SR)
front = (E3 @ C) > 0
hx = (tx + 1) / 2 * 1023; hy = (1 - ty) / 2 * 1023
inside_h = front & (np.abs(tx) < 1) & (np.abs(ty) < 1)
d = np.hypot(tx, ty)
fade = np.clip((1.0 - d) / 0.3, 0, 1)                                            # round, soft edge
storm = _nd.map_coordinates(HC, [np.clip(hy, 0, 1023), np.clip(hx, 0, 1023)], order=1) * inside_h * fade
hshade = _nd.map_coordinates(HS, [np.clip(hy, 0, 1023), np.clip(hx, 0, 1023)], order=1)
cloud = np.maximum(cloud * np.clip(d / 1.1, 0.25, 1), storm * 0.97)              # it clears its own neighbourhood
ctex = np.where(storm > 0.02, hshade, ctex)
col = col * (1 - cloud[..., None]) + (np.array([0.97, 0.97, 1.0]) * ctex[..., None]) * cloud[..., None]
lam = np.clip(P3 @ LIGHT, 0, 1)
day = np.clip((P3 @ LIGHT + 0.08) * 3.0, 0, 1)
shade = 0.12 + 0.95 * lam ** 0.8
col = col * shade[..., None]
cities = (land > 0.7) & (field(E3, 20, 30, 60) > 1.6) & (cloud < 0.3)
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
