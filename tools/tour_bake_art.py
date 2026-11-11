"""T6 M6 v3: turns the lower Blender bake (tour_bake_lower.py ... game) into the game's lower art, tour_lower.png: the
whole lower table — floor painting under its clear coat, cabinet, walls, rails, posts, sling plastics, the R-O-C hull, the
Mars bunker, aprons — over LOWER_RECT (−40, −75, 680, 775) at 3 px/pt, with its top 30 pt (y 670–700) fading out onto the
upper floor painting so the two meet without a seam. Usage: python3 tour_bake_art.py bake.png out.png"""
import sys
import numpy as np
from PIL import Image
src, out = sys.argv[1:3]
im = np.asarray(Image.open(src).convert('RGB'))
H = im.shape[0]; S = 3.0; Y_TOP = 700.0
wy = Y_TOP - (np.arange(H) + 0.5) / S
a = np.clip((Y_TOP - wy) / 30.0, 0, 1)
alpha = np.repeat((a * 255).round().astype(np.uint8)[:, None], im.shape[1], 1)
Image.fromarray(np.dstack([im, alpha]), 'RGBA').save(out, optimize=True)
print('wrote', out, im.shape)
