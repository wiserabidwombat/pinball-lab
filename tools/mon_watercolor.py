"""Table 04 (Monsoon) look development: turns a Blender render of the table into the two layers the game mixes,
plus the region map the shader reads (see MonPaint.swift).
  color  = the render with a watercolor finish on everything that isn't metal: paper grain, pigment pooling at
           edges (darker where tones change), a slight softening. Chrome, steel and brass stay as rendered.
  sketch = the same table drawn in pencil on cream paper: a light graphite tone from the render, darker pencil
           lines along the bigger shapes, 45° pencil strokes laid in more heavily where it is darker. Metal stays grey.
  regions (1 px per point) = the region index in three bits (R=1, G=2, B=4, each 0/255) and edge noise in alpha
           (0.2…1). Lower table: the playfield is "desert" (4), the apron, cabinet and walls are "frame" (5).
Usage: python3 mon_watercolor.py <render_color.png> <render_mask.png> <out dir> <prefix>   (e.g. mon_lower)"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

COLOR, MASK, OUT, PREFIX = sys.argv[1:5]
X0, Y0, RW, RH = L.LOWER_RECT
img = np.asarray(Image.open(COLOR).convert('RGB')).astype(np.float32) / 255
H, W = img.shape[:2]
metal = np.asarray(Image.open(MASK).convert('L').resize((W, H)), np.float32) / 255
metal = ndimage.gaussian_filter(np.clip((metal - 0.3) / 0.4, 0, 1), 0.7)[..., None]
rng = np.random.default_rng(31)

def lum(a): return a @ np.array([0.299, 0.587, 0.114], np.float32)

def paper_grain(sigma=0.8, amount=0.035):
    g = ndimage.gaussian_filter(rng.standard_normal((H, W)), sigma)
    return 1 - amount * (g / g.std()).clip(-2.5, 2.5)

# ------------------------------------------------------------------ color: watercolor finish on non-metal
Lm = lum(img)
dog = ndimage.gaussian_filter(Lm, 1.2) - ndimage.gaussian_filter(Lm, 4.0)
pool = np.clip(-dog * 3.0, 0, 0.22)                              # darker just inside edges, like pooled pigment
soft = np.stack([ndimage.gaussian_filter(img[..., k], 0.7) for k in range(3)], -1)
wc = soft * (1 - pool[..., None]) * paper_grain()[..., None]
color = np.clip(img * metal + wc * (1 - metal), 0, 1)

# ------------------------------------------------------------------ sketch: pencil on cream paper
paper = np.array([0.95, 0.93, 0.88], np.float32)
smooth = ndimage.gaussian_filter(Lm, 2.2)
tone = 0.40 + 0.60 * smooth                                      # graphite shading: keeps the values readable
edges = ndimage.gaussian_filter(Lm, 2.4) - ndimage.gaussian_filter(Lm, 6.0)
lines = np.clip(np.abs(edges) * 6.0 - 0.06, 0, 0.5)             # pencil lines only along the bigger shapes
# pencil strokes: noise smeared along a 45° line, laid in more heavily where the drawing is darker
k = np.eye(15, dtype=np.float32)[::-1] / 15
strokes = ndimage.convolve(rng.standard_normal((H, W)).astype(np.float32), k)
strokes = (strokes / strokes.std()).clip(-2.5, 2.5) * 0.5 + 0.5    # ~0…1, mean 0.5
dark = 1 - tone
graphite = np.clip(1 - dark * (0.35 + 0.75 * strokes) - lines * 0.8, 0, 1) * paper_grain(0.9, 0.04)
sketch_paint = graphite[..., None] * paper
grey_metal = np.repeat(lum(img)[..., None], 3, -1)
sketch = np.clip(grey_metal * metal + sketch_paint * (1 - metal), 0, 1)

Image.fromarray((color * 255).astype(np.uint8)).save(os.path.join(OUT, PREFIX + '.png'))
Image.fromarray((sketch * 255).astype(np.uint8)).save(os.path.join(OUT, PREFIX + '_sketch.png'))

# ------------------------------------------------------------------ regions (1 px per point)
rw, rh = int(RW), int(RH)
def to_px(p): return ((p[0] - X0), (Y0 + RH - p[1]))
reg = Image.new('L', (rw, rh), 5)                               # frame everywhere…
# …the desert inside the playfield: the outer wall, then down the shooter-lane wall and along the right apron
play = L.outer_wall() + [(L.LANE_X, L.APRON_TOP_Y)] + L.right_apron()[1:]
ImageDraw.Draw(reg).polygon([to_px(p) for p in play], fill=4)
idx = np.asarray(reg)
noise = 0.65 * ndimage.gaussian_filter(rng.standard_normal((rh, rw)), 12) + 0.25 * ndimage.gaussian_filter(rng.standard_normal((rh, rw)), 3.5) \
    + 0.10 * ndimage.gaussian_filter(rng.standard_normal((rh, rw)), 0.9)
noise = (noise - noise.min()) / (noise.max() - noise.min())
rgba = np.zeros((rh, rw, 4), np.uint8)
rgba[..., 0] = ((idx & 1) > 0) * 255
rgba[..., 1] = ((idx & 2) > 0) * 255
rgba[..., 2] = ((idx & 4) > 0) * 255
rgba[..., 3] = (51 + noise * 204).astype(np.uint8)            # 0.2 … 1.0
Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, PREFIX + '_regions.png'))
print('wrote', PREFIX, W, H, 'regions', rw, rh)
