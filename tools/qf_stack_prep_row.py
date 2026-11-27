"""Repack a SpriteCook 2x2 model sheet (TOP, SIDE / FRONT, BACK) into the sprite-stacking skill's 1x4 row with clear
gaps: split at the middle, drop small islands (labels), crop each view to its alpha bounds. Optional: replace the BACK
with the FRONT mirrored (when SpriteCook drew the back in three-quarter view)."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def views(path, mirror_back=False):
    a = np.array(Image.open(path).convert("RGBA"))
    h, w = a.shape[:2]
    quads = [a[:h // 2, :w // 2], a[:h // 2, w // 2:], a[h // 2:, :w // 2], a[h // 2:, w // 2:]]
    out = []
    for q in quads:
        q = q.copy()
        solid = q[..., 3] >= 128
        lab, n = ndimage.label(solid)
        if n:
            sizes = ndimage.sum(solid, lab, range(1, n + 1))
            keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.12 * sizes.max()]
            mask = np.isin(lab, keep)
            q[~mask] = 0
        ys, xs = np.nonzero(q[..., 3] >= 128)
        out.append(Image.fromarray(q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]))
    if mirror_back:
        out[3] = out[2].transpose(Image.FLIP_LEFT_RIGHT)
    return out

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    vs = views(src, mirror_back="--mirror-back" in sys.argv)
    gap = 40
    W = sum(v.width for v in vs) + gap * (len(vs) + 1)
    H = max(v.height for v in vs) + 2 * gap
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = gap
    for v in vs:
        sheet.alpha_composite(v, (x, H - gap - v.height))     # bottoms aligned
        x += v.width + gap
    sheet.save(dst)
    print(dst, [v.size for v in vs])
