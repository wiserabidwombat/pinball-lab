"""T6 M6 v1: the floor paintings as game art. Renders tour_floor_lower.py and tour_floor_upper.py at 3 px/pt, trims each
to the playfield's outer wall (transparent outside: the cabinet comes with the hardware bake), and fades the upper
painting's bottom 60 pt (y 640-700, its overlap with the lower one) so the two meet without a seam.
Writes tour_floor_lower.png (LOWER_RECT) and tour_floor_upper.png (UPPER_RECT) for GreyInvasionPinball/Tour/.
Usage: python3 tour_floor_art.py outdir"""
import subprocess, sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
S = 3.0
W_, leftWallX, rightWallX, laneWallX = 600, 20, 580, 548
laneFloorY, archStartY, topY = 40, 1000, 1270
apronTopY, drainEdgeX, drainEdgeY, drainLipY = 185, 250, 105, 85


def quad(p0, c, p1, n=32):
    return [((1-t)**2*p0[0]+2*(1-t)*t*c[0]+t*t*p1[0], (1-t)**2*p0[1]+2*(1-t)*t*c[1]+t*t*p1[1])
            for t in [i / n for i in range(1, n + 1)]]


def outer_wall():          # TourTableLayout.outerWall (tools/tour_layout.py), with the plunger lane
    pts = [(drainEdgeX, drainLipY), (drainEdgeX, drainEdgeY), (leftWallX, apronTopY), (leftWallX, archStartY)]
    pts += quad((leftWallX, archStartY), (leftWallX, topY), (W_ / 2, topY))
    pts += quad((W_ / 2, topY), (rightWallX, topY), (rightWallX, archStartY))
    pts += [(rightWallX, laneFloorY), (laneWallX, laneFloorY), (laneWallX, apronTopY),
            (2 * 284 - drainEdgeX, drainEdgeY), (2 * 284 - drainEdgeX, drainLipY)]
    return pts


def trimmed(src, rect, feather_bottom=0.0):
    x0, y0, w, h = rect
    im = Image.open(src).convert('RGB')
    assert im.size == (int(w * S), int(h * S)), (im.size, rect)
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).polygon([((x - x0) * S, (y0 + h - y) * S) for x, y in outer_wall()], fill=255)
    m = np.asarray(mask.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    if feather_bottom:
        rows = np.arange(im.size[1])
        wy = y0 + h - (rows + 0.5) / S
        m = m * np.clip((wy - y0) / feather_bottom, 0, 1)[:, None]
    return Image.fromarray(np.dstack([np.asarray(im), (m * 255).round().astype(np.uint8)]), 'RGBA')


os.makedirs(OUT, exist_ok=True)
subprocess.run([sys.executable, os.path.join(HERE, 'tour_floor_lower.py'), '/tmp/tfl.png', '1'], check=True)
subprocess.run([sys.executable, os.path.join(HERE, 'tour_floor_upper.py'), '/tmp/tfu.png', '1'], check=True)
trimmed('/tmp/tfl.png', (-40, -75, 680, 775)).save(os.path.join(OUT, 'tour_floor_lower.png'), optimize=True)
# M6 v3: the lower hardware bake (tour_lower.png) now fades out over y 670-700 onto the upper painting, so the upper one
# stays opaque at its bottom (a feathered edge under a fading edge left a dark seam).
trimmed('/tmp/tfu.png', (-40, 640, 680, 700), feather_bottom=0).save(os.path.join(OUT, 'tour_floor_upper.png'), optimize=True)
print('ok')
