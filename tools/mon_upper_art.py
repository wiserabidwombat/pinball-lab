"""Table 04 (Monsoon) milestone 9 round 1: the painted regions across the whole painting, and the upper playfield.
1. Regions (1 px per point over FULL_RECT) from the playfield painting (mon_playfield_full.png, 3 px/pt):
   sky above the mesa ridge, the mesas (sunlit hills and the blue range) between the ridge and where the scrub starts,
   the saguaros = every cactus (the two saguaros and the prickly pear, found by their green inside hand-drawn
   boxes), the arroyo = the pale rocky wash and sandy bed of the foreground (found by tone below the mesas), the
   desert = the rest of the foreground. Outside the playfield = frame.
   Writes mon_lower_regions.png (LOWER_RECT; frame taken from the current lower map, which matches the lower render)
   and mon_upper_regions.png (UPPER_RECT; frame = outside the outer wall).
2. The upper playfield's two layers from the painting (UPPER_RECT, 3 px/pt): color = the painting with the same
   watercolor finish as the lower table, sketch = the same pencil-on-cream pass (mon_watercolor.py's maths).
   With a Blender render of the upper table (mon_render_table.py, color + metal mask), the layers are made from the
   render instead, exactly as mon_watercolor.py does for the lower table (metal stays as rendered / grey).
Usage: python3 mon_upper_art.py <mon_playfield_full.png> <current mon_lower_regions.png> <out dir> [preview.png|-]
       [render_upper_color.png render_upper_mask.png]"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

FULL, OLD_LOWER, OUT = sys.argv[1:4]
PREVIEW = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != '-' else None
RENDER = sys.argv[5:7] if len(sys.argv) > 6 else None
FX0, FY0, FW, FH = L.FULL_RECT
S = L.PX_PER_PT
art = Image.open(FULL).convert('RGB')
small = np.asarray(art.resize((FW, FH), Image.LANCZOS)).astype(np.float32) / 255     # 1 px per point
H, W = small.shape[:2]
rng = np.random.default_rng(41)

def px(p): return (p[0] - FX0, FY0 + FH - p[1])             # world → region-map pixel
def poly_mask(pts):
    m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).polygon([px(p) for p in pts], fill=1)
    return np.asarray(m, bool)

# ------------------------------------------------------------------ bands from hand-traced lines (world points)
RIDGE = [(-40, 622), (40, 612), (113, 603), (180, 588), (200, 581), (240, 570), (280, 557), (307, 543), (333, 540),
         (427, 541), (467, 543), (533, 537), (613, 550), (640, 557)]
SCRUB = [(-40, 530), (27, 520), (113, 500), (180, 462), (260, 455), (360, 480), (460, 493), (560, 467), (640, 440)]
above_ridge = poly_mask(RIDGE + [(640, 1400), (-40, 1400)])
below_scrub = poly_mask(SCRUB + [(640, -100), (-40, -100)])
mesas = ~above_ridge & ~below_scrub

r, g, b = small[..., 0], small[..., 1], small[..., 2]
lum = 0.299 * r + 0.587 * g + 0.114 * b
mx, mn = small.max(-1), small.min(-1)
sat = (mx - mn) / np.maximum(mx, 1e-3)

# cacti: olive-to-green hue, not pale, inside boxes round each cactus (the saguaros are olive against a violet sky)
hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
olive = (hue > 48) & (hue < 150) & (sat > 0.10) & (lum < 0.50)
boxes = [(-40, 380, 215, 1045), (335, 395, 425, 635), (585, 380, 640, 470), (215, 130, 475, 345)]
inbox = np.zeros((H, W), bool)
for x0, y0, x1, y1 in boxes: inbox |= poly_mask([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
# against the sky, anything not violet and not a pale cloud is cactus (catches the saguaros' sunlit edges too)
sky_side = above_ridge & ((hue > 15) & (hue < 200) & (lum < 0.52) & (sat > 0.12))
cactus = ndimage.binary_opening((olive | sky_side) & inbox, iterations=1)
cactus = ndimage.binary_closing(cactus, iterations=4)
cactus = ndimage.binary_fill_holes(cactus)
lab, n = ndimage.label(cactus)
sizes = ndimage.sum(cactus, lab, range(1, n + 1))
cactus = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 300])        # drop specks

# arroyo: the pale rocks and sand of the foreground (below the scrub line, under y 380), smoothed into a bed
pale = (lum > 0.43) & (sat < 0.55) & below_scrub & poly_mask([(-40, -100), (640, -100), (640, 380), (-40, 380)])
bed = ndimage.gaussian_filter(pale.astype(np.float32), 4) > 0.35
bed = ndimage.binary_opening(bed, iterations=2)
bed = ndimage.binary_closing(bed, iterations=4)
lab, n = ndimage.label(bed)
sizes = ndimage.sum(bed, lab, range(1, n + 1))
arroyo = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 300]) & ~cactus

idx = np.full((H, W), 4, np.uint8)                     # desert
idx[mesas] = 1
idx[above_ridge] = 0                                   # sky
idx[arroyo] = 3
idx[cactus] = 2                                        # saguaros (cacti) on top of everything

# playfield / frame
upper_play = L.outer_wall()
i_arch_end = max(i for i, p in enumerate(upper_play) if p[0] == L.RIGHT_X and p[1] > 600)
upper_play = upper_play[2:i_arch_end + 1] + [(L.RIGHT_X, 400), (L.LEFT_X, 400)]
inside = poly_mask(upper_play)

noise = 0.65 * ndimage.gaussian_filter(rng.standard_normal((H, W)), 12) + 0.25 * ndimage.gaussian_filter(rng.standard_normal((H, W)), 3.5) \
    + 0.10 * ndimage.gaussian_filter(rng.standard_normal((H, W)), 0.9)
noise = (noise - noise.min()) / (noise.max() - noise.min())

def write(index, rows, name):
    rgba = np.zeros((rows.stop - rows.start, W, 4), np.uint8)
    sub = index[rows]
    rgba[..., 0] = ((sub & 1) > 0) * 255
    rgba[..., 1] = ((sub & 2) > 0) * 255
    rgba[..., 2] = ((sub & 4) > 0) * 255
    rgba[..., 3] = (51 + noise[rows] * 204).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, name))

# lower: rows for y -75 … 525 (the bottom 600 rows); keep the old map's frame exactly
LX0, LY0, LW, LH = L.LOWER_RECT
lower_rows = slice(H - LH, H)
old = np.asarray(Image.open(OLD_LOWER).convert('RGBA'))
oa = np.maximum(old[..., 3].astype(int), 1)
old_idx = (old[..., 0] * 2 > oa) * 1 + (old[..., 1] * 2 > oa) * 2 + (old[..., 2] * 2 > oa) * 4
low = idx.copy()
low[lower_rows][old_idx == 5] = 5
write(low, lower_rows, 'mon_lower_regions.png')
# upper: rows for y 525 … 1330
UX0, UY0, UW, UH = L.UPPER_RECT
upper_rows = slice(0, UH)
up = idx.copy()
up[~inside] = 5
write(up, upper_rows, 'mon_upper_regions.png')
counts = {n: int((up[upper_rows] == k).sum() + (low[lower_rows] == k).sum()) for k, n in enumerate(['sky', 'mesas', 'saguaros', 'arroyo', 'desert', 'frame'])}
print('region pixels (pt²):', counts)

# ------------------------------------------------------------------ upper color + sketch (3 px/pt)
if RENDER:
    img = np.asarray(Image.open(RENDER[0]).convert('RGB')).astype(np.float32) / 255
else:
    img = np.asarray(art.crop((0, 0, int(UW * S), int(UH * S)))).astype(np.float32) / 255
Hh, Ww = img.shape[:2]
metal = np.zeros((Hh, Ww, 1), np.float32)
if RENDER:
    mk = np.asarray(Image.open(RENDER[1]).convert('L').resize((Ww, Hh)), np.float32) / 255
    metal = ndimage.gaussian_filter(np.clip((mk - 0.3) / 0.4, 0, 1), 0.7)[..., None]
def lumf(a): return a @ np.array([0.299, 0.587, 0.114], np.float32)
def paper_grain(sigma=0.8, amount=0.035):
    gq = ndimage.gaussian_filter(rng.standard_normal((Hh, Ww)), sigma)
    return 1 - amount * (gq / gq.std()).clip(-2.5, 2.5)
Lm = lumf(img)
dog = ndimage.gaussian_filter(Lm, 1.2) - ndimage.gaussian_filter(Lm, 4.0)
pool = np.clip(-dog * 3.0, 0, 0.22)
soft = np.stack([ndimage.gaussian_filter(img[..., k], 0.7) for k in range(3)], -1)
wc = soft * (1 - pool[..., None]) * paper_grain()[..., None]
color = np.clip(img * metal + wc * (1 - metal), 0, 1)
paper = np.array([0.95, 0.93, 0.88], np.float32)
smooth = ndimage.gaussian_filter(Lm, 2.2)
tone = 0.40 + 0.60 * smooth
edges = ndimage.gaussian_filter(Lm, 2.4) - ndimage.gaussian_filter(Lm, 6.0)
lines = np.clip(np.abs(edges) * 6.0 - 0.06, 0, 0.5)
k = np.eye(15, dtype=np.float32)[::-1] / 15
strokes = ndimage.convolve(rng.standard_normal((Hh, Ww)).astype(np.float32), k)
strokes = (strokes / strokes.std()).clip(-2.5, 2.5) * 0.5 + 0.5
graphite = np.clip(1 - (1 - tone) * (0.35 + 0.75 * strokes) - lines * 0.8, 0, 1) * paper_grain(0.9, 0.04)
grey_metal = np.repeat(lumf(img)[..., None], 3, -1)
sketch = np.clip(grey_metal * metal + graphite[..., None] * paper * (1 - metal), 0, 1)
Image.fromarray((color * 255).astype(np.uint8)).save(os.path.join(OUT, 'mon_upper.jpg'), quality=90)
Image.fromarray((sketch * 255).astype(np.uint8)).save(os.path.join(OUT, 'mon_upper_sketch.jpg'), quality=90)
print('upper art', Ww, Hh)

if PREVIEW:
    pal = np.array([[150, 120, 230], [235, 120, 80], [90, 210, 90], [250, 190, 60], [240, 225, 170], [40, 40, 40]], np.uint8)
    full = idx.copy(); full[:UH][~inside[:UH]] = 5; full[lower_rows] = low[lower_rows]
    over = (small * 255 * 0.55 + pal[full] * 0.45).astype(np.uint8)
    Image.fromarray(over).save(PREVIEW)
