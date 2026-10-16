"""Table 04 (Monsoon) milestone 9: pencil versions of rendered part sprites (transparent PNGs), the same pencil-on-cream
maths as mon_watercolor.py's sketch, keeping each sprite's alpha (and its baked shadow, which stays a soft grey).
For each <name>.png writes <name>_sketch.png beside it.
Usage: python3 mon_parts_sketch.py <part.png> [...]"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

rng = np.random.default_rng(51)
for path in sys.argv[1:]:
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32) / 255
    rgb, a = im[..., :3], im[..., 3]
    H, W = a.shape
    # premultiplied → straight colour where there's any coverage
    L = (rgb @ np.array([0.299, 0.587, 0.114], np.float32))
    smooth = ndimage.gaussian_filter(L, 1.2)
    tone = 0.45 + 0.55 * smooth
    edges = ndimage.gaussian_filter(L, 1.4) - ndimage.gaussian_filter(L, 3.5)
    lines = np.clip(np.abs(edges) * 5.0 - 0.04, 0, 0.5)
    k = np.eye(9, dtype=np.float32)[::-1] / 9
    strokes = ndimage.convolve(rng.standard_normal((H, W)).astype(np.float32), k)
    strokes = (strokes / strokes.std()).clip(-2.5, 2.5) * 0.5 + 0.5
    g = np.clip(1 - (1 - tone) * (0.35 + 0.75 * strokes) - lines * 0.8, 0, 1)
    paper = np.array([0.95, 0.93, 0.88], np.float32)
    out = np.concatenate([g[..., None] * paper, a[..., None]], -1)
    name = os.path.splitext(path)[0] + '_sketch.png'
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGBA').save(name)
    print('wrote', name, W, H)
