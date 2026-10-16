"""Pinball Lab: the Table 04 (Monsoon) card picture, mon_lab_thumb.png (420 x 750, the card's 84:150), until the table
has its own art. A tall slice of Aaron's desert-storm watercolor (the big saguaro, the light breaking through), half
sketch and half color: the wash blooms from the gold light and the saguaro, with a ragged watercolor edge, the way
color builds on the table. Same bloom maths as mon_color_concept.py.
Usage: python3 mon_lab_thumb.py <painting.jpg> <out.png>"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC, OUT = sys.argv[1], sys.argv[2]
im = Image.open(SRC).convert('RGB')
H0 = im.height
w0 = round(H0 * 420 / 750)
x0 = 40                                   # the slice: the big saguaro and the light on the left of the painting
im = im.crop((x0, 0, x0 + w0, H0)).resize((840, 1500), Image.LANCZOS)   # 2x, downsampled at the end
W, H = im.size
col = np.asarray(im).astype(np.float32) / 255

lum = col @ np.array([0.299, 0.587, 0.114], np.float32)
lum = np.clip((lum - 0.5) * 1.1 + 0.6, 0, 1)
edges = np.asarray(im.convert('L').filter(ImageFilter.FIND_EDGES), np.float32) / 255
lum = np.clip(lum - ndimage.gaussian_filter(edges, 0.8) * 0.8, 0, 1)
sketch = lum[..., None] * np.array([0.96, 0.94, 0.90], np.float32)

rng = np.random.default_rng(9)
def smooth_noise(sigma):
    n = ndimage.gaussian_filter(rng.standard_normal((H, W)), sigma)
    return (n - n.min()) / (n.max() - n.min())
noise = 0.65 * smooth_noise(36) + 0.25 * smooth_noise(10) + 0.10 * smooth_noise(2.4)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

m = np.zeros((H, W), np.float32); edge = np.zeros((H, W), np.float32)
for cx, cy, reach, p in ((0.28, 0.30, 640, 0.62), (0.22, 0.60, 480, 0.55)):   # the light, the saguaro
    t = np.hypot(xx - cx * W, yy - cy * H) / reach * 0.75 + noise * 0.55 - p * 1.0
    m = np.maximum(m, np.clip(-t / 0.06, 0, 1))
    edge = np.maximum(edge, np.exp(-(t / 0.035) ** 2) * (t < 0.04))
out = sketch * (1 - m[..., None]) + col * m[..., None]
out = out * (1 - 0.18 * edge[..., None])
Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize((420, 750), Image.LANCZOS).save(OUT)
print('wrote', OUT)
