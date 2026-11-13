"""Table 06 (Orbit: Grand Tour) M6 v8: the raised Moon and Saturn platforms as painted sprites with normal maps.

Both are flat platforms at the ramps' top height, so a top-down picture moved up by h·K is exact (no shear).
6 px/pt, image centred on the platform centre (TourTableLayout.moonCenter / saturnCenter).

tour_moon: the Moon printed on CLEAR plastic (alpha ~0.6, so a ball rolling beneath stays visible): maria,
craters lit from the upper left, a ray crater, and the ball's crater cup at the made switch (CRATER_MOON); a frosted
rim and a gleam. No normal map (a flat print; one made the craters read as bubbles under SpriteKit's lights).
tour_saturn (+_n): banded Saturn with its tilted ring (in front of the planet below, behind it above), the Cassini
division, and the crater cup at CRATER_SATURN. Normal map: the sphere; the ring flat.

Usage: python3 tour_paint_planets.py out_dir"""
import sys, os, math
import numpy as np
from PIL import Image
from scipy import ndimage

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
os.makedirs(OUT, exist_ok=True)
S = 6                                  # px per pt
LIGHT = np.array([-0.45, 0.55, 0.70]); LIGHT /= np.linalg.norm(LIGHT)
CRATER_MOON = (24.3, 29.05)            # the made switch, from the moon's centre (TOURCRATER, -tourDumpWalls)
CRATER_SATURN = (-37.7, 3.3)
CUP_R = 13.0
rng = np.random.default_rng(6)


def grid(half):
    n = int(round(2 * half * S))
    c = (np.arange(n) + 0.5) / S - half
    x, y = np.meshgrid(c, -c)          # +y up
    return x, y


def noise(shape, sigma):
    n = ndimage.gaussian_filter(rng.standard_normal(shape), sigma)
    return (n - n.mean()) / (n.std() + 1e-9)


def save(name, rgb, a):
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name))


def normals_from_height(h, strength):
    gy, gx = np.gradient(h * strength * S)   # rows run down: flip y
    n = np.dstack([-gx, gy, np.ones_like(h)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def crater_field(x, y, craters):
    """Height: a bowl inside r, a raised rim just outside, fading out."""
    h = np.zeros_like(x)
    for cx, cy, r, depth in craters:
        d = np.hypot(x - cx, y - cy) / r
        bowl = np.where(d < 1, -depth * (1 - d ** 2), 0)
        rim = depth * 0.40 * np.exp(-((d - 1.0) / 0.22) ** 2)
        h += bowl + rim
    return h


# ------------------------------------------------------------------ the Moon
def moon():
    R = 56.0; half = R + 4
    x, y = grid(half)
    r = np.hypot(x, y)
    inside = r < R
    craters = [(*CRATER_MOON, CUP_R, 3.2)]
    for _ in range(85):                       # small ones, more of them
        rr = 1.0 + 5.0 * rng.random() ** 2.6
        a = rng.random() * 2 * math.pi; d = (R - rr - 2) * math.sqrt(rng.random())
        cx, cy = d * math.cos(a), d * math.sin(a)
        if math.hypot(cx - CRATER_MOON[0], cy - CRATER_MOON[1]) < CUP_R + rr + 2:
            continue
        craters.append((cx, cy, rr, rr * 0.28))
    ray = (-24.0, -20.0, 5.0, 1.6)           # a young crater with rays (like Tycho)
    craters.append(ray)
    h = crater_field(x, y, craters)
    n = normals_from_height(h, 0.65)
    # albedo: highlands, darker maria (low-frequency blobs), fine grit
    big = noise(x.shape, 9 * S)
    maria = np.clip((big - 0.1) * 1.4, 0, 1)
    alb = 0.74 - 0.34 * maria + 0.035 * noise(x.shape, 0.6 * S) + 0.03 * noise(x.shape, 2.5 * S)
    # rays from the young crater
    ang = np.arctan2(y - ray[1], x - ray[0]); dist = np.hypot(x - ray[0], y - ray[1])
    spokes = np.clip(np.cos(ang * 6 + 0.9 * noise(x.shape, 6 * S)), 0, 1) ** 3
    spokes = ndimage.gaussian_filter(spokes * np.exp(-dist / 26), 1.2 * S)
    alb += 0.45 * spokes + 0.12 * np.exp(-(dist / 9) ** 2)
    # the cup's floor a little darker (worn by the ball)
    dc = np.hypot(x - CRATER_MOON[0], y - CRATER_MOON[1])
    alb -= 0.10 * (dc < CUP_R * 0.85)
    shade = np.clip(n @ LIGHT, 0, 1) * 0.85 + 0.25
    tint = np.array([0.93, 0.95, 1.0])
    rgb = (alb * shade)[..., None] * tint
    # clear plastic: printed at ~60%, a frosted rim, a soft gleam (upper left)
    a = np.where(inside, 0.58, 0.0)
    a = np.where(dc < CUP_R * 1.1, 0.82, a)               # the cup reads solid
    edge = np.clip(1 - np.abs(r - (R - 2.0)) / 2.2, 0, 1) * (r < R + 0.5)
    rgb = rgb * (1 - edge[..., None] * 0.6) + edge[..., None] * np.array([0.88, 0.93, 1.0]) * 0.6
    a = np.maximum(a, edge * 0.9)
    g = np.exp(-(((x + 18) / 22) ** 2 + ((y - 20) / 14) ** 2))
    rgb = rgb + (g * 0.10 * inside)[..., None]
    soft = np.clip((R + 0.5 - r) * S / 1.5, 0, 1)         # antialiased outer edge
    a = a * soft
    save('tour_moon.png', rgb, a)
    # no normal map: the Moon is a print on flat clear plastic (v8b — with one, SpriteKit's lights made the craters
    # read as glossy bubbles)
    print('moon', x.shape, 'pt', 2 * half)


# ------------------------------------------------------------------ Saturn
def saturn():
    R = 46.0
    A, B, ROT = R * 1.35, R * 0.45, -0.35        # the ring's outer semi-axes (2.7 r × 0.9 r) and turn, as before
    half = A + 6
    x, y = grid(half)
    # the planet frame: turned so the ring plane is horizontal
    c, s = math.cos(-ROT), math.sin(-ROT)
    u = x * c - y * s; v = x * s + y * c
    r = np.hypot(x, y)
    planet = r < R
    zs = np.sqrt(np.clip(R ** 2 - x ** 2 - y ** 2, 0, None))
    nx, ny, nz = x / R, y / R, zs / R
    # latitude on a planet whose pole tips toward the viewer by the ring's tilt
    tilt = math.asin(B / A)
    nv = (v / R) * math.cos(tilt) + nz * math.sin(tilt)      # sin(latitude) in the planet's frame
    lat = np.arcsin(np.clip(nv, -1, 1))
    band = np.sin(lat * 7.0 + 0.6 * np.sin(lat * 3.1)) * 0.5 + 0.5
    fine = np.sin(lat * 31 + 0.8 * noise(x.shape, 3 * S)) * 0.5 + 0.5
    pale = np.array([0.92, 0.84, 0.62]); tan = np.array([0.78, 0.60, 0.36]); cream = np.array([0.96, 0.92, 0.80])
    col = pale + (tan - pale) * (band[..., None] * 0.75) + (cream - pale) * (fine[..., None] * 0.25)
    polar = np.clip((np.abs(lat) - 1.05) / 0.4, 0, 1)
    col = col * (1 - polar[..., None] * 0.35) + np.array([0.55, 0.62, 0.70]) * polar[..., None] * 0.35
    n_planet = np.dstack([nx, ny, nz])
    lam = np.clip(n_planet @ LIGHT, 0, 1)
    limb = 0.55 + 0.45 * nz
    pshade = (0.22 + 0.9 * lam) * limb
    rgb = col * pshade[..., None]
    alpha = planet.astype(float)
    # the ring: radial profile in the ring plane (ellipse radius q: 1 at the outer edge)
    q = np.hypot(u / A, v / B)
    rr = q * 2.27                                             # in Saturn radii (outer A ring 2.27)
    dens = np.zeros_like(rr)
    dens += 0.25 * ((rr > 1.24) & (rr < 1.53))                # C ring
    dens += 0.95 * ((rr > 1.53) & (rr < 1.95))                # B ring
    dens += 0.70 * ((rr > 2.03) & (rr < 2.27))                # A ring
    dens *= 1 - 0.8 * ((rr > 2.20) & (rr < 2.215))            # Encke gap
    dens *= 0.85 + 0.15 * np.sin(rr * 60)
    ringcol = np.array([0.90, 0.82, 0.64]) * (0.85 + 0.25 * np.clip((rr - 1.5) / 0.5, 0, 1))[..., None]
    ring_lit = 0.95
    front = v < 0                                             # the near half crosses in front of the planet
    over = (dens > 0) & (front | ~planet)
    rd = dens[..., None]
    rgb = np.where(over[..., None], rgb * (1 - rd * 0.9) + ringcol * ring_lit * rd * 0.9, rgb)
    alpha = np.where(over, np.maximum(alpha, dens * 0.9), alpha)
    # the crater cup where the ball pauses: a dark bowl with a chrome rim, drawn over everything
    dc = np.hypot(x - CRATER_SATURN[0], y - CRATER_SATURN[1])
    cupn = np.dstack([(x - CRATER_SATURN[0]) / CUP_R, (y - CRATER_SATURN[1]) / CUP_R, np.ones_like(x)])
    bowl = dc < CUP_R
    inner = np.clip(1 - dc / CUP_R, 0, 1)
    cupcol = np.array([0.20, 0.17, 0.13]) * (0.6 + 0.6 * (1 - inner))[..., None]
    rim = np.clip(1 - np.abs(dc - CUP_R) / 1.4, 0, 1)
    rgb = np.where(bowl[..., None], cupcol, rgb)
    rgb = rgb * (1 - rim[..., None]) + np.array([0.85, 0.86, 0.90]) * rim[..., None]
    alpha = np.maximum(alpha, np.maximum(bowl * 1.0, rim))
    # antialias the planet's edge
    soft = np.clip((R + 0.5 - r) * S / 1.5, 0, 1)
    alpha = np.where(planet | (r < R + 0.5), np.maximum(alpha * np.where(over, 1, soft), np.where(over, alpha, 0)), alpha)
    # normal map: the sphere on the planet, flat on the ring, the cup's bowl
    nmap = np.where(planet[..., None] & ~over[..., None], n_planet, np.array([0, 0, 1.0]))
    nmap = np.where(bowl[..., None], -cupn * np.array([1, 1, -1]) / np.linalg.norm(cupn, axis=2, keepdims=True), nmap)
    save('tour_saturn.png', rgb, alpha)
    save('tour_saturn_n.png', nmap * 0.5 + 0.5, (alpha > 0.01).astype(float))
    print('saturn', x.shape, 'pt', 2 * half)


moon(); saturn()
