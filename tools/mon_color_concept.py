"""Table 04 (Monsoon) concept: how color builds on the table. Takes Aaron's watercolor and shows four stages: the grey
sketch, then washes of color blooming outward from where goals were made, with a ragged watercolor edge (noise
threshold), to full color. Same maths the game's shader would use: per pixel, colored when
progress(region) > noise + distance-from-bloom-origin.
Usage: python3 mon_color_concept.py <painting.jpg> <out.png>"""
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont
from scipy import ndimage

SRC, OUT = sys.argv[1], sys.argv[2]
im = Image.open(SRC).convert('RGB')
W = 900
im = im.resize((W, int(im.height * W / im.width)), Image.LANCZOS)
H = im.height
col = np.asarray(im).astype(np.float32) / 255

# --- the sketch: luminance on warm paper, contrast lifted, pencil edges darkened
lum = col @ np.array([0.299, 0.587, 0.114], np.float32)
lum = np.clip((lum - 0.5) * 1.15 + 0.55, 0, 1)
edges = np.asarray(im.convert('L').filter(ImageFilter.FIND_EDGES), np.float32) / 255
edges = ndimage.gaussian_filter(edges, 0.6)
lum = np.clip(lum - edges * 0.9, 0, 1)
paper = np.array([0.96, 0.94, 0.90], np.float32)
sketch = lum[..., None] * paper

# --- watercolor bloom mask: low-frequency + grain noise
rng = np.random.default_rng(4)
def smooth_noise(sigma):
    n = ndimage.gaussian_filter(rng.standard_normal((H, W)), sigma)
    return (n - n.min()) / (n.max() - n.min())
noise = 0.65 * smooth_noise(18) + 0.25 * smooth_noise(5) + 0.10 * smooth_noise(1.2)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

def bloom(cx, cy, reach):
    """0 at the origin rising to 1 at `reach` px, plus the watercolor noise."""
    d = np.hypot(xx - cx * W, yy - cy * H) / reach
    return d * 0.75 + noise * 0.55

# goals bloom from these points (fractions of the image): the sky from the light, the mesas, the left saguaro, the floor
origins = [(0.20, 0.25, 520), (0.70, 0.45, 520), (0.08, 0.40, 380), (0.45, 0.85, 560)]

def stage(progress):
    """progress per origin, 0..1 → mixed image with a darker wet edge where the wash stops."""
    m = np.zeros((H, W), np.float32)
    edge = np.zeros((H, W), np.float32)
    for (cx, cy, r), p in zip(origins, progress):
        if p <= 0: continue
        t = bloom(cx, cy, r) - p * 1.35
        a = np.clip(-t / 0.06, 0, 1)                         # soft but ragged boundary
        e = np.exp(-(t / 0.035) ** 2) * (t < 0.04)           # pigment pools at the wash's edge
        m = np.maximum(m, a); edge = np.maximum(edge, e)
    out = sketch * (1 - m[..., None]) + col * m[..., None]
    out = out * (1 - 0.18 * edge[..., None])
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))

stages = [((0, 0, 0, 0), 'Start: the sketch'),
          ((0.55, 0, 0.25, 0), 'Two goals: sky and a saguaro'),
          ((1, 0.7, 0.8, 0.35), 'Most washes laid'),
          ((2, 2, 2, 2), 'Superbloom: full color')]
tw, th = W // 2, H // 2
pad, cap = 14, 30
sheet = Image.new('RGB', (2 * tw + 3 * pad, 2 * (th + cap) + 3 * pad - 4), (250, 248, 244))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
except OSError:
    font = ImageFont.load_default()
for i, (p, label) in enumerate(stages):
    x = pad + (i % 2) * (tw + pad); y = pad + (i // 2) * (th + cap + pad)
    sheet.paste(stage(p).resize((tw, th), Image.LANCZOS), (x, y))
    d.text((x + 2, y + th + 7), f'{i + 1}. {label}', fill=(40, 40, 40), font=font)
sheet.save(OUT)
print('wrote', OUT, sheet.size)
