import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as nd
shot = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(np.float32)
paint = np.asarray(Image.open('floor_upper.png').convert('RGBA')).astype(np.float32)
H, W = paint.shape[:2]; S = 2.25; X0, Y0, WW, HH = -40, 640, 680, 700
yy, xx = np.mgrid[0:H, 0:W]
wx = X0 + (xx + 0.5) / S; wy = Y0 + HH - (yy + 0.5) / S
px = 629.2 + (wx - 284) * 1.890; py = 1901.8 - (wy - 500) * 1.890
samp = np.stack([nd.map_coordinates(shot[..., k], [py, px], order=1, mode='nearest') for k in range(3)], -1)
floor = np.array([12, 17, 35], np.float32); bg = np.array([5, 8, 15], np.float32)
d = np.minimum(np.linalg.norm(samp - floor, axis=-1), np.linalg.norm(samp - bg, axis=-1))
a = np.clip((d - 10) / 18, 0, 1); a[wy > 1290] = 0; a = nd.gaussian_filter(a, 0.5)
out = Image.fromarray((paint[..., :3] * (1 - a[..., None]) + samp * a[..., None]).clip(0, 255).astype(np.uint8))
def q(p0, c, p1, n=24):
    return [((1-t)**2*p0[0]+2*(1-t)*t*c[0]+t*t*p1[0], (1-t)**2*p0[1]+2*(1-t)*t*c[1]+t*t*p1[1]) for t in [i/n for i in range(n+1)]]
wall = [(20, 600)] + q((20, 1000), (20, 1270), (300, 1270)) + q((300, 1270), (580, 1270), (580, 1000)) + [(580, 600)]
mask = Image.new('L', (W, H), 0); ImageDraw.Draw(mask).polygon([((x - X0) * S, (Y0 + HH - y) * S) for x, y in wall], fill=255)
out = Image.composite(out, Image.new('RGB', (W, H), (14, 20, 44)), mask.filter(ImageFilter.GaussianBlur(1.2)))
out.save('/mnt/user-data/outputs/grandtour_look_upper.jpg', quality=90)
out.resize((W // 2, H // 2)).save('upper_small.png')
