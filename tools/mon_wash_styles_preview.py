"""Table 04 (Monsoon) M8 v1: previews the varied washes (strokes from A toward B, per-game noise) with MonPaint's maths.
Four panels: the same three washes under two different game seeds, then a creep half-way and finished.
Usage: python3 mon_wash_styles_preview.py <dir with mon_lower.png, _sketch, _regions> <out.png>"""
import sys, os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

D, OUT = sys.argv[1], sys.argv[2]
col = np.asarray(Image.open(os.path.join(D, 'mon_lower.png')).convert('RGB'), np.float32) / 255
sk = np.asarray(Image.open(os.path.join(D, 'mon_lower_sketch.png')).convert('RGB'), np.float32) / 255
H, W = col.shape[:2]
reg = np.asarray(Image.open(os.path.join(D, 'mon_lower_regions.png')).convert('RGBA').resize((W, H), Image.BILINEAR), np.float32) / 255
index = (reg[..., 0] > 0.5) * 1 + (reg[..., 1] > 0.5) * 2 + (reg[..., 2] > 0.5) * 4
alpha = reg[..., 3]
X0, Y0, RW, RH = L.LOWER_RECT
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u = xx / W; v = 1 - yy / H
px = X0 + u * RW; py = Y0 + v * RH

def noise(seed):
    qx = 0.5 + (u - 0.5) * seed[2] + seed[0]; qy = 0.5 + (v - 0.5) * seed[3] + seed[1]
    qx = 1 - np.abs(1 - np.mod(qx, 2)); qy = 1 - np.abs(1 - np.mod(qy, 2))
    sx = np.clip((qx * W).astype(int), 0, W - 1); sy = np.clip(((1 - qy) * H).astype(int), 0, H - 1)
    return np.clip((alpha[sy, sx] - 0.2) / 0.8, 0, 1)

def shade(drops, seed):
    n = noise(seed)
    t = np.full((H, W), 9.0, np.float32)
    for (ax, ay, bx, by, w, s, r) in drops:
        abx, aby = bx - ax, by - ay
        h = np.clip(((px - ax) * abx + (py - ay) * aby) / max(abx * abx + aby * aby, 1e-4), 0, 1)
        dist = np.hypot(px - ax - abx * h, py - ay - aby * h)
        t = np.minimum(t, dist / (210 * w) * 0.75 + n * 0.55 - s * 1.35 + (index != r) * 4.0)
    m = np.clip(-t / 0.06, 0, 1)[..., None]
    rim = np.where(t < 0.04, np.exp(-(t / 0.035) ** 2), 0)[..., None]
    return sk * (1 - m) + col * (1 - 0.12 * rim) * m

washes = [(150, 300, 150, 300, 1.0, 0.6, 4),            # bloom
          (400, 420, 520, 360, 0.65, 0.5, 4),           # streak
          (260, 200, 300, 470, 0.7, 0.5, 4)]            # creep (finished)
half = [(150, 300, 150, 300, 1.0, 0.6, 4), (260, 200, 280, 335, 0.7, 0.5, 4)]
panels = [shade(washes, (0.3, 1.1, 1, 1)), shade(washes, (1.4, 0.2, -1, 1)),
          shade(half, (0.3, 1.1, 1, 1)), shade(washes[:1] + washes[2:], (0.3, 1.1, 1, 1))]
img = np.concatenate(panels, axis=1)
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((W * 4 // 3, H // 3)).save(OUT)
print('wrote', OUT)
