"""Table 06 M5 v5: the hero pieces of the floor painting, procedural (Aaron's reference photos were looks to aim for,
not images we use): a satellite-photo hurricane and the Andromeda galaxy (M31 with M32 and M110).
hurricane(n)  → (n, n) cloud cover 0..1 + (n, n) shade, in the storm's tangent plane, x/y in −1..1 (storm radius 1).
andromeda(n, ratio) → (h, n, 4) RGBA float image, premultiplied, major axis horizontal."""
import numpy as np
from scipy import ndimage as nd
from scipy.spatial import cKDTree


def _vnoise(shape, cells, rng):
    h, w = shape
    g = rng.random((cells + 3, cells + 3))
    return nd.zoom(g, ((h + 2) / (cells + 1), (w + 2) / (cells + 1)), order=3)[:h, :w]


def fbm(shape, c0, octs, rng, gain=0.55):
    out = np.zeros(shape); a = 1.0; t = 0
    for i in range(octs):
        out += a * _vnoise(shape, c0 * 2 ** i, rng); t += a; a *= gain
    out /= t
    return (out - out.mean()) / out.std()


def cells(shape, count, rng, jitter=None):
    """Worley F1 'popcorn': 1 at each cell centre falling to 0 at its edge (cumulus clumps)."""
    h, w = shape
    pts = rng.random((count, 2)) * [h, w]
    tree = cKDTree(pts)
    yy, xx = np.mgrid[0:h, 0:w]
    d, _ = tree.query(np.stack([yy.ravel(), xx.ravel()], -1), k=1)
    d = d.reshape(shape)
    rad = np.sqrt(h * w / count) * 0.62
    return np.clip(1 - d / rad, 0, 1)


def hurricane(n=1024, seed=4):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:n, 0:n]
    x = (xx + 0.5) / n * 2 - 1; y = 1 - (yy + 0.5) / n * 2
    r = np.hypot(x, y) + 1e-6; th = np.arctan2(y, x)
    K = 2.2                                            # spiral tightness (northern hemisphere: counter-clockwise inflow)
    phi = th + K * np.log(r)
    # swirl streak texture: fine noise warped round the spiral (sample it at (log r, phi) so streaks follow the wind)
    S = 512
    tex = fbm((S, S), 6, 5, rng, 0.6)
    # spiral streamlines are phi = const: vary the texture fast ACROSS phi and slowly along log r → streaks along the wind
    across = (phi / (2 * np.pi)) * S * 6.0; along = (np.log(r) + 4.0) * S * 0.08
    swirl = nd.map_coordinates(tex, [along % S, across % S], order=1, mode='wrap')
    tex2 = fbm((S, S), 24, 3, rng, 0.55)
    swirl2 = nd.map_coordinates(tex2, [(along * 2.5) % S, (across * 2.2) % S], order=1, mode='wrap')
    # central dense overcast, its edge ragged; then the outer rain bands, 4 arms thinning outward
    r_eff = r * (1 - 0.22 * np.cos(2 * phi + 0.4))                  # the dense core trails off into two arms
    cdo = np.clip((0.46 - r_eff) / 0.14 + 0.18 * swirl, 0, 1)
    arms = 0.5 + 0.5 * np.cos(3 * phi + 0.7 * fbm((n, n), 4, 3, rng))
    arms = np.clip((arms - 0.05) / 0.95, 0, 1) ** 0.8
    env = np.exp(-((r / 0.95) ** 3)) * np.clip((r - 0.2) / 0.1, 0, 1)
    pop = nd.gaussian_filter(0.6 * cells((n, n), 2500, rng) + 0.4 * cells((n, n), 9000, rng), 1.6)
    breakup = np.clip(fbm((n, n), 10, 3, rng) * 0.5 + 0.6, 0, 1)
    band = np.clip(arms * env * (0.7 + pop * 1.3 + 0.15 * swirl) * breakup * 1.25, 0, 1)
    # scattered popcorn cumulus in the gaps between bands, fading out
    scatter = np.clip(nd.gaussian_filter(cells((n, n), 3500, rng), 1.6) * 1.6 - 0.55, 0, 1) * np.exp(-((r / 1.0) ** 4)) * 0.6 \
        * np.clip(fbm((n, n), 8, 3, rng) * 0.5 + 0.4, 0, 1)
    cover = np.clip(np.maximum(nd.gaussian_filter(cdo, 2.0) * (0.97 + 0.03 * swirl), band) + scatter * (1 - arms) * 0.8, 0, 1)
    # the eye: small, clear, ragged edge, its western wall in shadow
    eye_r = 0.045 + 0.006 * np.cos(5 * th)
    eye = np.clip((r - eye_r) / 0.025, 0, 1)
    cover = cover * eye
    # shading: puffy relief from the cover's own height, lit from the upper left
    hgt = nd.gaussian_filter(cover + 0.35 * pop * (cover > 0.05), 1.2)
    gy, gx = np.gradient(hgt)
    shade = np.clip(0.94 + (-gx * 0.7 + gy * 0.7) * 4, 0.7, 1.08)
    shade = shade * (1 - 0.35 * np.exp(-((r - eye_r - 0.01) / 0.03) ** 2) * (np.cos(th - 2.4) > 0))   # the eye's shadowed wall
    return np.clip(cover, 0, 1), shade


def andromeda(n=1024, ratio=0.24, seed=2):
    """M31 seen at ~77°: a long disc, warm bulge, dust lanes on the near (lower-left) side, a blue star-forming ring,
    companions M32 (tight, bright, just above the disc) and M110 (fuzzy oval below)."""
    rng = np.random.default_rng(seed)
    h = int(n * 0.62)
    yy, xx = np.mgrid[0:h, 0:n]
    x = (xx + 0.5 - n / 2) / (n / 2); y = (h / 2 - yy - 0.5) / (n / 2)
    u, v = x, y / ratio                                   # into the galaxy's plane
    r = np.hypot(u, v) + 1e-6; th = np.arctan2(v, u)
    noise = fbm((h, n), 12, 5, rng)
    fine = fbm((h, n), 120, 2, rng)
    mid = fbm((h, n), 50, 3, rng)
    # light
    bulge = np.exp(-(np.hypot(x / 0.13, y / 0.06)) ** 1.0)
    disc = np.exp(-r / 0.40) * (0.9 + 0.1 * noise)
    halo = np.exp(-(r / 0.95) ** 2) * 0.12
    ring = np.exp(-((r - 0.74) / 0.16) ** 2) * np.clip(0.6 + 0.4 * mid, 0, 1)
    knots = nd.gaussian_filter(np.clip(fine * 0.7 - 0.6, 0, 1), 1.5) * np.exp(-((r - 0.75) / 0.22) ** 2) * 1.6
    warm = np.array([1.0, 0.86, 0.62]); cream = np.array([0.93, 0.88, 0.78]); blue = np.array([0.55, 0.70, 1.0])
    col = bulge[..., None] * warm * 1.5 + disc[..., None] * (cream * np.clip(1.35 - r, 0, 1)[..., None]
                                                              + blue * np.clip(r - 0.45, 0, 1)[..., None] * 1.3) * 1.15
    col += halo[..., None] * np.array([0.6, 0.66, 0.8]) + ring[..., None] * blue * 0.18 + knots[..., None] * np.array([0.7, 0.82, 1.0]) * 0.35
    # dust: wound rings (a slightly spiral pattern) in the disc, dark brown, strongest on the near side and outward of the bulge
    ph = r * 13.0 + 0.35 * th + 0.35 * noise + 0.08 * mid
    lanes = np.clip((np.cos(ph * 2 * np.pi / 3.0) - 0.45) / 0.55, 0, 1) ** 2.5
    lanes *= np.clip((r - 0.16) / 0.12, 0, 1) * np.exp(-((r / 0.92) ** 4))
    near = 0.25 + 0.75 * (v < 0) * np.clip(-v * 4, 0, 1) + 0.15 * (v >= 0)
    lanes *= near * np.clip(0.55 + 0.5 * mid + 0.3 * fine, 0, 1)
    col = col * (1 - 0.85 * lanes[..., None]) + lanes[..., None] * np.array([0.10, 0.06, 0.03]) * 0.4
    # companions
    def blob(cx, cy, sx, sy, amp, rot=0.0):
        c, s = np.cos(rot), np.sin(rot)
        a = ((x - cx) * c + (y - cy) * s) / sx; b = (-(x - cx) * s + (y - cy) * c) / sy
        return amp * np.exp(-(a * a + b * b) ** 0.8)
    col += blob(-0.05, 0.13, 0.035, 0.03, 1.2)[..., None] * np.array([1.0, 0.92, 0.8])            # M32
    col += blob(0.22, -0.36, 0.07, 0.035, 0.55, 0.5)[..., None] * np.array([0.85, 0.85, 0.9])      # M110
    edge = np.clip((1.0 - np.hypot(x * 0.97, y / 0.55)) / 0.3, 0, 1) ** 1.5    # fades to nothing inside the sprite
    col = np.clip(col * edge[..., None], 0, 1)
    a = np.clip(col.max(-1) * 1.1, 0, 1)
    return np.concatenate([col, a[..., None]], -1)


if __name__ == '__main__':
    from PIL import Image
    c, sh = hurricane(900)
    ocean = np.zeros((900, 900, 3)) + np.array([0.04, 0.08, 0.20])
    img = ocean * (1 - c[..., None]) + (np.array([0.97, 0.97, 1.0]) * sh[..., None]) * c[..., None]
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save('fx/hurricane_test.png')
    m = andromeda(1000)
    bg = np.zeros(m.shape[:2] + (3,)) + np.array([0.02, 0.025, 0.05])
    Image.fromarray((np.clip(bg + m[..., :3], 0, 1) * 255).astype(np.uint8)).save('fx/andromeda_test.png')
    print('ok')
