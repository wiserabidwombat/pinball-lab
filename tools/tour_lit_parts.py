"""T6 M5 v6: grey-box parts for the normal-map lighting test (procedural, numpy).
tour_bumper.png / tour_bumper_n.png: a pop bumper cap seen from above (chrome skirt, red domed plastic cap with a white
band, chrome rivet), 150 px = 50 pt at 3 px/pt; the normal map from its height field (RGB = n/2 + 1/2, +y = image up).
tour_ball_n.png: the ball's sphere normals, 192 px to match tour_ball.png."""
import numpy as np
from PIL import Image
from scipy import ndimage as nd


def save_normals(h, px_per_unit, path, alpha):
    gy, gx = np.gradient(h)                       # rows go DOWN the image
    nx, ny, nz = -gx * px_per_unit, gy * px_per_unit, np.ones_like(h)   # +y = up the image
    n = np.stack([nx, ny, nz], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
    rgb = ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)
    Image.fromarray(np.dstack([rgb, (alpha * 255).astype(np.uint8)]), 'RGBA').save(path)


# --- bumper cap
N = 150; c = (N - 1) / 2; S = 3.0                 # px per pt
yy, xx = np.mgrid[0:N, 0:N]
r = np.hypot(xx - c, yy - c) / S                  # pt
R_SK, R_CAP, R_BAND0, R_BAND1, R_RIV = 24.5, 20.5, 13.0, 16.0, 3.2
h = np.zeros((N, N))
skirt = (r <= R_SK) & (r > R_CAP)
h = np.where(skirt, 2.5 * (R_SK - r) / (R_SK - R_CAP), h)
cap = r <= R_CAP
h = np.where(cap, 2.5 + 7.0 * np.sqrt(np.clip(1 - (r / R_CAP) ** 2, 0, 1)), h)
h = np.where(r <= R_RIV, h + 1.2 * np.sqrt(np.clip(1 - (r / R_RIV) ** 2, 0, 1)), h)
h = nd.gaussian_filter(h, 0.8)
alpha = np.clip((R_SK + 0.4 - r) * S / 1.5, 0, 1)
# albedo with gentle baked shading (lit from the upper left) so it reads at rest; live lights add on top
gy, gx = np.gradient(h); nrm = np.stack([-gx * S, gy * S, np.ones_like(h)], -1); nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
L = np.array([-0.45, 0.55, 0.70]); L /= np.linalg.norm(L)
lam = np.clip(nrm @ L, 0, 1)
red = np.array([0.86, 0.20, 0.16]); white = np.array([0.95, 0.94, 0.92]); chrome = np.array([0.72, 0.75, 0.80])
col = np.where(cap[..., None], red, chrome)
band = cap & (r >= R_BAND0) & (r <= R_BAND1)
col = np.where(band[..., None], white, col)
col = np.where((r <= R_RIV)[..., None], chrome, col)
shade = (0.62 + 0.45 * lam)[..., None]
spec = (np.clip(nrm @ (L + np.array([0, 0, 1])) / np.linalg.norm(L + np.array([0, 0, 1])), 0, 1) ** 40)[..., None]
metal = (skirt | (r <= R_RIV))[..., None]
col = col * shade + spec * np.where(metal, 0.9, 0.55)
col = np.clip(col, 0, 1)
col = np.stack([nd.gaussian_filter(col[..., k], 0.7) for k in range(3)], -1)   # soften the band's edges
Image.fromarray(np.dstack([(col * 255).round().astype(np.uint8), (alpha * 255).astype(np.uint8)]), 'RGBA').save('tour_bumper.png')
save_normals(h, S, 'tour_bumper_n.png', alpha)

# --- ball normals (a sphere filling the 192 px sprite like tour_ball.png)
B = 192; cb = (B - 1) / 2; rb = B / 2 - 1
yy, xx = np.mgrid[0:B, 0:B]
ux, uy = (xx - cb) / rb, -(yy - cb) / rb
inside = ux * ux + uy * uy <= 1
uz = np.sqrt(np.clip(1 - ux * ux - uy * uy, 0, 1))
n = np.where(inside[..., None], np.stack([ux, uy, uz], -1), np.array([0, 0, 1.0]))
rgb = ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)
ball_a = np.asarray(Image.open('GreyInvasionPinball/Tour/tour_ball.png').convert('RGBA'))[..., 3]
Image.fromarray(np.dstack([rgb, ball_a]), 'RGBA').save('tour_ball_n.png')
print('ok')
