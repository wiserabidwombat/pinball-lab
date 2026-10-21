"""Table 05 (The Lamplight) M9 v34: the fire in the fireplace as a looping animation (Aaron: "make the fire animated").
FRAMES frames, lmp_fire_<i>.png, drawn over the baked logs with additive blending, so black = nothing. Image box =
LmpTableLayout.fireArtBox round fireAnchor (284, 770): x -42...42, y -6...46 (the flames rise up the screen, toward the
back of the firebox, as the oblique view shows height). 3 px per pt.
Two layers of tiling noise scroll upward through flame tongues anchored on the logs; each layer moves a whole number of
tile periods over the loop, so the last frame runs into the first without a seam.
Usage: python3 lmp_bake_fire.py out_dir [frames]"""
import sys, os
import numpy as np
from PIL import Image

OUT = os.path.abspath(sys.argv[1])
FRAMES = int(sys.argv[2]) if len(sys.argv) > 2 else 24
PX = 3
BX0, BY0, BW, BH = -42.0, -6.0, 84.0, 52.0
W, H = int(BW * PX), int(BH * PX)
rng = np.random.default_rng(7)


def tiling_noise(w, h, beta, stretch):
    """Periodic 1/f^beta noise, tiling in both directions, normalised to 0...1; stretch > 1 draws it out upward."""
    fx = np.fft.fftfreq(w)[None, :]; fy = np.fft.fftfreq(h)[:, None]
    f = np.sqrt(fx * fx + (fy * stretch) ** 2); f[0, 0] = 1
    spec = (rng.normal(size=(h, w)) + 1j * rng.normal(size=(h, w))) / f ** beta
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min())


# two noise tiles, stretched tall (flames are streaky)
P1, P2 = H, H                                  # vertical periods (px)
n1 = tiling_noise(W, P1, 1.7, 2.2)
n2 = tiling_noise(W, P2, 1.3, 1.6)

xs = (np.arange(W) + 0.5) / PX + BX0           # pt, relative to the anchor
ys = BY0 + BH - (np.arange(H) + 0.5) / PX      # pt, image row 0 is the top (highest y)
X, Y = np.meshgrid(xs, ys)

# the bed of flame along the logs (y ~ -4...4), and tongues of different heights along it
tongues = [(-27, 19), (-17, 30), (-7, 36), (3, 38), (12, 33), (21, 27), (29, 17)]
height = np.zeros_like(X)
for cx, hh in tongues:
    height = np.maximum(height, hh * np.exp(-((X - cx) / 6.5) ** 2))
bed = np.clip(1 - (np.abs(X) / 35) ** 2, 0, 1)                           # the fire's width across the grate
height = np.maximum(height, 10 * bed) * bed

frames = []
for f in range(FRAMES):
    t = f / FRAMES
    s1 = int(round(t * P1 * 2))                                            # 2 periods per loop
    s2 = int(round(t * P2 * 3))                                            # 3 periods, quicker flicker
    a = np.roll(n1, -s1, axis=0)                                           # scroll the noise upward
    b = np.roll(n2, -s2, axis=0)
    turb = 0.62 * a + 0.38 * b
    wobble = (turb - 0.5) * 7.0                                            # ragged, licking edges
    hy = np.clip(Y + wobble, 0, None)
    v = 1 - hy / np.maximum(height * (0.75 + 0.6 * turb), 1e-3)            # 1 at the logs, 0 at the tongue tips
    v = np.clip(v, 0, 1)
    base = np.clip((Y + 4 + (turb - 0.5) * 6) / 6, 0, 1) * np.clip(bed * 1.6, 0, 1)   # ragged bottom among the logs
    v = v * base * (0.55 + 0.85 * turb)                                    # holes and bright licks
    v = np.clip(v, 0, 1) ** 1.1
    # colour: deep red at the edges, orange, yellow, a pale core at the logs
    r = np.clip(v * 2.2, 0, 1)
    g = np.clip((v - 0.22) * 1.5, 0, 1) * 0.85
    bl = np.clip((v - 0.7) * 2.0, 0, 1) * 0.45
    alpha = np.clip(v * 2.0, 0, 1)
    img = np.dstack([r, g, bl, alpha])
    img = (img * 255).astype(np.uint8)
    frames.append(img)

os.makedirs(OUT, exist_ok=True)
for i, img in enumerate(frames):
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, f'lmp_fire_{i}.png'), optimize=True)
print('wrote', FRAMES, 'frames', W, 'x', H, 'to', OUT)
