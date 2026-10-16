"""Pinball Lab: Table 04 (Monsoon) card picture from the finished table (polish round 2), mon_lab_thumb.png 420x750.
Two renders of the whole table by tools/mon_howto_map.py — in color (mon_upper/mon_lower + color parts) and in pencil
(the _sketch art and parts) — mixed by a ragged watercolor bloom spreading from the arroyo, the way color builds as you
play. Crop world x -25…625, y 140…1300 (the card's 84:150), like Table 03's card.
Usage: python3 mon_lab_thumb_table.py <color map.png> <sketch map.png> <out.png>"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

col = np.asarray(Image.open(sys.argv[1]).convert('RGB'), np.float32) / 255
sk = np.asarray(Image.open(sys.argv[2]).convert('RGB'), np.float32) / 255
H, W = col.shape[:2]                                  # 1.5 px per point over world (-40,-75)-(640,1330)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
wx = xx / 1.5 - 40; wy = 1330 - yy / 1.5
rng = np.random.default_rng(4)
def sn(s):
    n = ndimage.gaussian_filter(rng.standard_normal((H, W)), s); return (n - n.min()) / (n.max() - n.min())
noise = 0.6 * sn(40) + 0.3 * sn(12) + 0.1 * sn(3)
# two blooms: from the arroyo up into the sky, and from the lower left flipper area; color where t < 0
d1 = np.hypot((wx - 300) / 1.0, (wy - 760) / 1.25)
d2 = np.hypot(wx - 120, wy - 380)
t = np.minimum(d1 / 470, d2 / 300) * 0.8 + noise * 0.55 - 0.72
m = np.clip(-t / 0.05, 0, 1)[..., None]
rim = np.where(t < 0.04, np.exp(-(t / 0.035) ** 2), 0)[..., None]
out = sk * (1 - m) + col * (1 - 0.14 * rim) * m
img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
x0, x1 = (-25 + 40) * 1.5, (625 + 40) * 1.5
y0, y1 = (1330 - 1300) * 1.5, (1330 - 140) * 1.5
img.crop((round(x0), round(y0), round(x1), round(y1))).resize((420, 750), Image.LANCZOS).save(sys.argv[3])
print('wrote', sys.argv[3])
