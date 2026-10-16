"""Table 04 (Monsoon): previews MonPaint's shader in Python with the same maths, so a look can be judged before a
build. Renders the lower table as the sketch, after a few washes (drops), and fully filled, side by side.
Usage: python3 mon_wash_preview.py <dir with mon_lower.png, _sketch, _regions> <out.png>"""
import sys, os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

D, OUT = sys.argv[1], sys.argv[2]
col = np.asarray(Image.open(os.path.join(D, 'mon_lower.png')).convert('RGB'), np.float32) / 255
sk = np.asarray(Image.open(os.path.join(D, 'mon_lower_sketch.png')).convert('RGB'), np.float32) / 255
H, W = col.shape[:2]
reg = Image.open(os.path.join(D, 'mon_lower_regions.png')).convert('RGBA').resize((W, H), Image.BILINEAR)
reg = np.asarray(reg, np.float32) / 255
index = (reg[..., 0] > 0.5) * 1 + (reg[..., 1] > 0.5) * 2 + (reg[..., 2] > 0.5) * 4
n = np.clip((reg[..., 3] - 0.2) / 0.8, 0, 1)
X0, Y0, RW, RH = L.LOWER_RECT
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
px = X0 + xx / W * RW; py = Y0 + RH - yy / H * RH
REACH = 210

def shade(drops, fills):
    t = np.full((H, W), 9.0, np.float32)
    f = np.zeros((H, W), np.float32)
    for r, lvl in fills.items(): f += lvl * np.clip(1 - np.abs(index - r) * 2, 0, 1)
    t = np.where(f > 0, n * 0.55 + 0.5 - f * 1.1, t)
    for (x, y, s, r) in drops:
        w = np.clip(1 - np.abs(index - r) * 2, 0, 1)
        t = np.minimum(t, np.hypot(px - x, py - y) / REACH * 0.75 + n * 0.55 - s * 1.35 + (1 - w) * 4)
    m = np.clip(-t / 0.06, 0, 1)[..., None]
    rim = np.where(t < 0.04, np.exp(-(t / 0.035) ** 2), 0)[..., None]
    return sk * (1 - m) + col * (1 - 0.12 * rim) * m

frames = [shade([], {}),
          shade([(150, 330, 0.36, 4), (420, 330, 0.24, 4)], {}),          # three sling kicks and a wash
          shade([(150, 330, 0.6, 4), (420, 330, 0.5, 4), (284, 450, 0.6, 4)], {}),
          shade([], {4: 1.0, 5: 1.0})]
w2 = W // 3; h2 = H // 3
sheet = Image.new('RGB', (w2 * 4 + 30, h2), (250, 248, 244))
for i, fimg in enumerate(frames):
    sheet.paste(Image.fromarray((np.clip(fimg, 0, 1) * 255).astype(np.uint8)).resize((w2, h2), Image.LANCZOS), (i * (w2 + 10), 0))
sheet.save(OUT)
print('wrote', OUT)
