"""Table 06 (Orbit: Grand Tour) M6 v11: the planet window's eight pictures, painted with numpy.

Each image is the window's full circle (92 pt across, 6 px/pt), transparent round the planet, centred on the window:
Mercury, Venus, Earth (NASA Blue Marble + the table's cloud map, tools/earthsrc/), Mars, Jupiter, Saturn (with its
rings), Uranus (faint, nearly upright ring) and Neptune. All lit from the upper left like the table, with a soft
terminator; the gas giants darken toward the limb, the planets with air get a thin glowing rim.
M8 v9: + Pluto (the hidden bonus stop).
Usage: python3 tour_paint_window.py earthsrc_dir out_dir"""
import sys, os, math
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = sys.argv[1]; OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
S = 6
HALF = 46.0
N = int(2 * HALF * S)
LIGHT = np.array([-0.55, 0.50, 0.67]); LIGHT /= np.linalg.norm(LIGHT)
rng = np.random.default_rng(11)

c = (np.arange(N) + 0.5) / S - HALF
X, Y = np.meshgrid(c, -c)

# a 3D noise volume, sampled on the sphere (seamless turbulence for every planet)
VOL = 48
vol = [ndimage.gaussian_filter(rng.standard_normal((VOL,) * 3), s, mode='wrap') for s in (1.5, 3.0, 6.0)]
vol = [(v - v.mean()) / v.std() for v in vol]


def noise3(p, scale, octave=1):
    q = (p * scale * VOL / 4 + VOL / 2) % VOL
    v = ndimage.map_coordinates(vol[octave], [q[..., 0].ravel(), q[..., 1].ravel(), q[..., 2].ravel()],
                                order=1, mode='wrap')
    return v.reshape(p.shape[:-1])


def sphere(R, tilt=0.35, roll=0.0, spin=0.0):
    """Normals on the disc, and the same points in the planet's own frame (y = its pole)."""
    xx, yy = X / R, Y / R
    rr2 = xx ** 2 + yy ** 2
    inside = rr2 < 1
    zz = np.sqrt(np.clip(1 - rr2, 0, None))
    n = np.dstack([xx, yy, zz])
    cr, sr = math.cos(roll), math.sin(roll)              # turn in the picture plane
    px, py = xx * cr + yy * sr, -xx * sr + yy * cr
    ct, st = math.cos(tilt), math.sin(tilt)              # pole leaning toward the viewer
    qy = py * ct + zz * st
    qz = -py * st + zz * ct
    p = np.dstack([px, qy, qz])
    lat = np.arcsin(np.clip(qy, -1, 1))
    lon = np.arctan2(px, qz) + spin
    soft = np.clip((1 - np.sqrt(rr2)) * R * S / 1.2, 0, 1)   # antialiased edge
    return n, p, lat, lon, inside, soft


def light(n, ambient=0.04, wrap=0.12):
    d = n @ LIGHT
    return ambient + np.clip((d + wrap) / (1 + wrap), 0, 1) ** 0.9


def save(name, rgb, a):
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(OUT, f'tour_window_{name}.png'))
    print('painted', name)


def atmosphere(n, R, color, width=0.10, strength=0.8):
    rr = np.hypot(X, Y) / R
    rim = np.exp(-((rr - 1.0) / width) ** 2)
    litr = np.clip((X * LIGHT[0] + Y * LIGHT[1]) / (np.hypot(X, Y) + 1e-6) + 0.3, 0, 1)
    glow = rim * litr * strength
    return glow[..., None] * np.array(color), np.clip(glow, 0, 1)


def compose(name, R, alb, n, inside, soft, shade, air=None):
    rgb = alb * shade[..., None]
    a = soft * inside
    if air is not None:
        g_rgb, g_a = atmosphere(n, R, *air)
        rgb = rgb * a[..., None] + g_rgb
        a = np.maximum(a, g_a)
        rgb = rgb / np.maximum(a[..., None], 1e-6)
    save(name, rgb, a)


def layer_over(rgb, a, col, dens, mask):
    """Put a ring layer (colour col, coverage dens) over (rgb, a) where mask; straight (not premultiplied) colours."""
    d = np.where(mask, dens, 0)
    A = d + a * (1 - d)
    out = (col * d[..., None] + rgb * (a * (1 - d))[..., None]) / np.maximum(A, 1e-6)[..., None]
    return out, A


def craters(p, count, seed, rmin, rmax):
    r = np.random.default_rng(seed)
    h = np.zeros(p.shape[:-1])
    for _ in range(count):
        v = r.standard_normal(3); v /= np.linalg.norm(v)
        ang = rmin + (rmax - rmin) * r.random() ** 2.5
        d = np.arccos(np.clip(p @ v, -1, 1)) / ang
        h += np.where(d < 1, -(1 - d ** 2), 0) + 0.5 * np.exp(-((d - 1) / 0.25) ** 2)
    return h


def mercury():
    R = 15
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.1)
    h = craters(p, 160, 3, 0.04, 0.32)
    gy, gx = np.gradient(h)
    nn = n + np.dstack([-gx, gy, np.zeros_like(gx)]) * 0.9
    nn /= np.linalg.norm(nn, axis=2, keepdims=True)
    g = 0.50 + 0.06 * noise3(p, 1.0, 1) + 0.04 * noise3(p, 2.5, 0) - 0.05 * np.clip(-h, 0, 1)
    alb = g[..., None] * np.array([1.0, 0.95, 0.88])
    compose('mercury', R, alb, n, inside, soft, light(nn, 0.02, 0.0))


def venus():
    R = 21
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.25)
    sw = noise3(p, 0.8, 2) * 0.6 + noise3(p, 1.6, 1) * 0.4
    band = np.sin(lat * 5 + 1.6 * sw)
    v = 0.86 + 0.05 * band + 0.04 * sw
    alb = v[..., None] * np.array([0.98, 0.88, 0.66])
    compose('venus', R, alb, n, inside, soft, light(n, 0.03) * (0.8 + 0.2 * n[..., 2]),
            air=((1.0, 0.92, 0.70), 0.07, 0.55))


def earth():
    R = 22
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.30, spin=math.radians(-95))
    img = np.asarray(Image.open(os.path.join(SRC, 'bmng.jpg')).convert('RGB')).astype(float) / 255
    H, W = img.shape[:2]
    u = ((lon / (2 * math.pi) + 0.5) % 1) * (W - 1)
    v = (0.5 - lat / math.pi) * (H - 1)
    alb = np.dstack([ndimage.map_coordinates(img[..., k], [v.ravel(), u.ravel()], order=1).reshape(v.shape)
                     for k in range(3)])
    cl = np.asarray(Image.open(os.path.join(SRC, 'clouds.png')).convert('L')).astype(float) / 255
    Hc, Wc = cl.shape
    cu = ((lon / (2 * math.pi) + 0.5 + 0.13) % 1) * (Wc - 1)
    cv = (0.5 - lat / math.pi) * (Hc - 1)
    clouds = ndimage.map_coordinates(cl, [cv.ravel(), cu.ravel()], order=1).reshape(cv.shape)
    clouds = np.clip(ndimage.gaussian_filter(clouds, 1.2) * 0.85, 0, 1)
    alb = alb * (1 - clouds[..., None]) + clouds[..., None] * 0.97
    ocean = (alb[..., 2] > alb[..., 0] + 0.04) & (clouds < 0.3)
    shade = light(n, 0.02, 0.05)
    refl = 2 * (n @ LIGHT)[..., None] * n - LIGHT
    glint = np.clip(refl[..., 2], 0, 1) ** 40 * ocean * 0.6
    alb = alb + glint[..., None] * np.array([1.0, 0.95, 0.85])
    compose('earth', R, alb, n, inside, soft, shade, air=((0.45, 0.68, 1.0), 0.08, 0.9))


def mars():
    R = 17
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.35, spin=1.2)
    dark = noise3(p, 0.45, 2) * 0.8 + noise3(p, 1.0, 1) * 0.2
    alb = np.array([0.82, 0.46, 0.26]) * (0.96 + 0.04 * noise3(p, 2.0, 0))[..., None]
    alb = alb * (1 - 0.45 * np.clip((dark - 0.3) * 1.5, 0, 1))[..., None]
    cap = np.clip((lat - 1.18) / 0.12, 0, 1)
    alb = alb * (1 - cap[..., None]) + cap[..., None] * np.array([0.97, 0.96, 0.95])
    compose('mars', R, alb, n, inside, soft, light(n, 0.02), air=((1.0, 0.65, 0.45), 0.05, 0.35))


def jupiter():
    R = 27
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.12)
    turb = noise3(p, 1.4, 1) * 0.6 + noise3(p * np.array([3.0, 0.5, 3.0]), 1.0, 0) * 0.4
    b = np.degrees(lat) + 2.2 * turb                                    # latitude, wobbled along the bands
    # zones (pale) and belts (brown) by latitude, north to south, as (top latitude, colour)
    table = [(90, (0.60, 0.58, 0.56)), (48, (0.72, 0.62, 0.52)), (38, (0.90, 0.84, 0.72)), (30, (0.70, 0.50, 0.36)),
             (22, (0.94, 0.90, 0.80)), (17, (0.62, 0.42, 0.30)), (8, (0.97, 0.93, 0.84)), (-6, (0.80, 0.66, 0.50)),
             (-9, (0.66, 0.44, 0.30)), (-18, (0.95, 0.90, 0.80)), (-27, (0.74, 0.56, 0.42)), (-36, (0.90, 0.85, 0.74)),
             (-46, (0.66, 0.58, 0.52)), (-90, (0.60, 0.58, 0.56))]
    lats = np.array([t for t, _ in table])[::-1]; cols = np.array([c for _, c in table])[::-1]
    alb = np.dstack([np.interp(b, lats, cols[:, k]) for k in range(3)])
    alb = alb * (1 + 0.05 * noise3(p, 4.0, 0))[..., None]
    grey = np.array([0.60, 0.58, 0.56])
    polar = np.clip((np.abs(lat) - 1.0) / 0.4, 0, 1)
    alb = alb * (1 - polar[..., None]) + grey * polar[..., None]
    # the Great Red Spot
    gl, gn = math.radians(-22), -0.35
    d = np.hypot((lon - gn) / 0.30, (lat - gl) / 0.12)
    spot = np.clip(1.2 - d, 0, 1) ** 0.8
    alb = alb * (1 - spot[..., None] * 0.8) + spot[..., None] * 0.8 * np.array([0.80, 0.38, 0.24])
    shade = light(n, 0.02) * (0.65 + 0.35 * n[..., 2])
    compose('jupiter', R, alb, n, inside, soft, shade)


def ringed(name, R, base, bands, tilt, roll, ring_in, ring_out, ring_col, ring_alpha, ring_ratio, gaps=()):
    n, p, lat, lon, inside, soft = sphere(R, tilt=tilt, roll=roll)
    turb = noise3(p, 1.0, 1) * 0.3
    alb = np.array(base) * (1 + bands * np.sin(lat * 9 + turb))[..., None]
    shade = light(n, 0.02) * (0.65 + 0.35 * n[..., 2])
    rgb = alb * shade[..., None]
    a = soft * inside
    # the ring: an ellipse in the picture, turned by `roll`
    cr, sr = math.cos(roll), math.sin(roll)
    u = X * cr + Y * sr; v = -X * sr + Y * cr
    q = np.hypot(u / (R * ring_out), v / (R * ring_out * ring_ratio)) * ring_out     # radius in planet radii
    dens = ((q > ring_in) & (q < ring_out)).astype(float) * ring_alpha
    for g0, g1 in gaps:
        dens *= ~((q > g0) & (q < g1))
    dens *= 0.85 + 0.15 * np.sin(q * 50)
    front = v < 0
    planet = inside
    over = (dens > 0) & (front | ~planet)
    # the planet's shadow on the far ring (light from the upper left: falls behind, lower right)
    shadowed = (v > 0) & ((X + 0.55 * R) ** 2 + (Y - 0.5 * R) ** 2 > 0) & \
               (np.hypot(X - R * 0.45, Y + R * 0.40) < R * 0.95) & (dens > 0) & ~planet
    lit_ring = np.where(shadowed, 0.25, 1.0)
    rc = np.array(ring_col) * lit_ring[..., None]
    rgb, a = layer_over(rgb, a, rc, dens, over)
    save(name, rgb, a)


def saturn():
    ringed('saturn', 16, (0.92, 0.82, 0.60), 0.07, tilt=0.42, roll=-0.30, ring_in=1.24, ring_out=2.27,
           ring_col=(0.90, 0.82, 0.64), ring_alpha=0.85, ring_ratio=0.40, gaps=((1.95, 2.03), (1.52, 1.55)))


def uranus():
    R = 19
    n, p, lat, lon, inside, soft = sphere(R, tilt=1.3, roll=0.25)
    v = 0.92 + 0.03 * np.sin(lat * 6) + 0.02 * noise3(p, 1.0, 2)
    alb = v[..., None] * np.array([0.62, 0.86, 0.90])
    shade = light(n, 0.02) * (0.7 + 0.3 * n[..., 2])
    rgb = alb * shade[..., None]
    a = soft * inside
    # a thin dark ring, nearly upright (the planet lies on its side)
    roll = 1.40
    cr, sr = math.cos(roll), math.sin(roll)
    u = X * cr + Y * sr; w = -X * sr + Y * cr
    q = np.hypot(u / (R * 1.7), w / (R * 1.7 * 0.32)) * 1.7
    dens = (np.abs(q - 1.65) < 0.03).astype(float) * 0.35
    over = (dens > 0) & ((w < 0) | ~inside)
    rgb, a = layer_over(rgb, a, np.array([0.75, 0.82, 0.86]), dens, over)
    g_rgb, g_a = atmosphere(n, R, (0.6, 0.95, 1.0), 0.06, 0.5)
    rgb = rgb * a[..., None] + g_rgb; a2 = np.maximum(a, g_a)
    save('uranus', rgb / np.maximum(a2[..., None], 1e-6), a2)


def neptune():
    R = 19
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.35, spin=0.4)
    turb = noise3(p, 1.3, 1) * 0.4
    v = 0.88 + 0.06 * np.sin(lat * 8 + turb)
    alb = v[..., None] * np.array([0.26, 0.45, 0.92])
    d = np.hypot((lon - 0.3) / 0.28, (lat - math.radians(-20)) / 0.11)       # the Great Dark Spot
    spot = np.clip(1.1 - d, 0, 1)
    alb = alb * (1 - 0.45 * spot[..., None])
    streak = np.clip(noise3(p * np.array([3.0, 0.4, 3.0]), 1.0, 0) - 1.4, 0, 1) * (np.abs(lat - 0.35) < 0.25)
    alb = alb + streak[..., None] * 0.6
    shade = light(n, 0.02) * (0.7 + 0.3 * n[..., 2])
    compose('neptune', R, alb, n, inside, soft, shade, air=((0.5, 0.7, 1.0), 0.06, 0.6))


def moon():
    """M8 v1: Earth's Moon: grey highlands, dark maria, bright young craters."""
    R = 19
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.15, spin=math.radians(20))
    h = craters(p, 220, 7, 0.03, 0.26)
    gy, gx = np.gradient(h)
    nn = n + np.dstack([-gx, gy, np.zeros_like(gx)]) * 0.7
    nn /= np.linalg.norm(nn, axis=2, keepdims=True)
    mare = np.clip((noise3(p, 0.7, 2) * 0.7 + noise3(p, 1.4, 1) * 0.3 - 0.15) * 2.2, 0, 1)
    g = 0.70 - 0.36 * mare + 0.04 * noise3(p, 3.0, 0) - 0.04 * np.clip(-h, 0, 1)
    alb = g[..., None] * np.array([0.97, 0.97, 1.0])
    compose('moon', R, alb, n, inside, soft, light(nn, 0.02, 0.0))


def sun():
    """M8 v1: the Sun, the tour's last stop: a hot disc with granulation and limb darkening, a corona round it."""
    R = 30
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.2)
    mu = n[..., 2]
    gran = 1 + 0.10 * noise3(p, 3.5, 0) + 0.06 * noise3(p, 1.5, 1)
    spots = np.clip(noise3(p, 1.1, 1) - 1.9, 0, 1)
    limb = 0.40 + 0.60 * mu ** 0.7
    t = np.clip(limb * gran, 0, 1.2)[..., None]
    deep = np.array([0.85, 0.30, 0.05]); mid = np.array([1.0, 0.66, 0.20]); hot = np.array([1.0, 0.95, 0.72])
    disc = np.where(t < 0.75, deep + (mid - deep) * (t / 0.75), mid + (hot - mid) * np.clip((t - 0.75) / 0.4, 0, 1))
    sp = np.clip(spots * 1.5, 0, 1)[..., None]
    disc = np.clip(disc * (1 - sp) + np.array([0.45, 0.14, 0.02]) * sp, 0, 1)
    rr = np.hypot(X, Y) / R
    ang = np.arctan2(Y, X)
    streak = 0.75 + 0.25 * np.sin(ang * 9 + 1.3) * np.sin(ang * 4 - 0.4)
    cor = np.exp(-np.clip(rr - 0.98, 0, None) / 0.22) * streak
    a_disc = soft * inside
    a_cor = np.clip(cor * 0.9, 0, 1)
    a = a_disc + a_cor * (1 - a_disc)
    col_cor = np.array([1.0, 0.62, 0.22])
    rgb = (disc * a_disc[..., None] + col_cor * (a_cor * (1 - a_disc))[..., None]) / np.maximum(a, 1e-6)[..., None]
    save('sun', rgb, a)


def pluto():
    """M8 v9: Pluto, the hidden bonus stop: small and icy, tan and rust plains, the bright smooth heart (Tombaugh Regio)
    facing us, a dark rust band (Cthulhu) to its left, a faint blue haze at the limb."""
    R = 12
    n, p, lat, lon, inside, soft = sphere(R, tilt=0.2, spin=0.0)
    tex = noise3(p, 1.2, 1) * 0.6 + noise3(p, 2.8, 0) * 0.4
    # the heart: the classic implicit heart (x² + y² − 1)³ − x²y³ < 0, leaning a little, its edge roughened
    x = (lon - 0.32) / 0.50
    y = (lat - 0.02) / 0.48 + 0.12
    ca, sa = math.cos(0.25), math.sin(0.25)
    x, y = x * ca - y * sa, x * sa + y * ca
    f = (x ** 2 + y ** 2 - 1) ** 3 - x ** 2 * y ** 3 + 0.12 * noise3(p, 3.0, 0)
    heart = np.clip(-f * 6, 0, 1) * (np.abs(lon) < 1.6)
    h = craters(p, 40, 13, 0.03, 0.16) * (1 - heart)          # the heart is a smooth ice plain
    gy, gx = np.gradient(h)
    nn = n + np.dstack([-gx, gy, np.zeros_like(gx)]) * 0.4
    nn /= np.linalg.norm(nn, axis=2, keepdims=True)
    base = np.array([0.80, 0.67, 0.52]) * (0.90 + 0.10 * tex)[..., None]
    band = np.clip(1.2 - np.hypot((lon + 0.85) / 0.70, (lat + 0.15) / 0.24), 0, 1)
    band = np.clip(band * 1.8 + 0.25 * tex, 0, 1)
    alb = base * (1 - 0.6 * band[..., None]) + np.array([0.28, 0.12, 0.06]) * (0.6 * band[..., None])
    alb = alb * (1 - heart[..., None]) + np.array([1.0, 0.98, 0.94]) * heart[..., None]
    compose('pluto', R, alb, n, inside, soft, light(nn, 0.03, 0.05), air=((0.55, 0.70, 1.0), 0.07, 0.35))

only = sys.argv[3] if len(sys.argv) > 3 else ''
for name, fn in [('mercury', mercury), ('venus', venus), ('earth', earth), ('mars', mars), ('jupiter', jupiter),
                 ('saturn', saturn), ('uranus', uranus), ('neptune', neptune), ('moon', moon), ('sun', sun), ('pluto', pluto)]:
    if not only or only == name:
        fn()
