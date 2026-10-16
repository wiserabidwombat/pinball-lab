"""Table 04 (Monsoon): previews MonLamp inserts over the table art (pencil sketch and full color), off and lit, with the
same drawing rules as MonLamp.swift (insert fill alpha, stroke, additive or normal halo). STYLE=old|new.
Writes /tmp/claude-0/s/lamps_<style>.png"""
import os, math
import numpy as np
from PIL import Image, ImageDraw
STYLE = os.environ.get('STYLE', 'old')
S = 3
R = '/home/claude/gi-src/mon/'
def full(kind):
    up = Image.open(R + f'm9/mon_upper{"_sketch" if kind=="sketch" else ""}.jpg').convert('RGB')
    lo = Image.open(R + f'm2/mon_lower{"_sketch" if kind=="sketch" else ""}.png').convert('RGB')
    im = Image.new('RGB', (2040, 2415 + 1800)); im.paste(up, (0, 0)); im.paste(lo, (0, 2415)); return im
gold = (1.0, 0.82, 0.45)
drops = [(0.66, 0.48, 1.0), (0.96, 0.50, 0.32), (0.52, 0.90, 0.46), (0.98, 0.74, 0.30), (1.0, 0.90, 0.62)]
def arrow(L, Wd):
    return [(L/2, 0), (-L/2, Wd/2), (-L/2 + 6, 0), (-L/2, -Wd/2)]
def circle(r, n=28): return [(r*math.cos(2*math.pi*k/n), r*math.sin(2*math.pi*k/n)) for k in range(n)]
def star(o, i): return [((o if k % 2 == 0 else i)*math.cos(math.pi/2 + k*math.pi/5), (o if k % 2 == 0 else i)*math.sin(math.pi/2 + k*math.pi/5)) for k in range(10)]
CM = 568
lamps = [('arrow', (336.3, 532), 70.8, gold), ('arrow', (121.4, 722.7), 113.8, gold), ('arrow', (284, 582), 90, gold),
         ('arrow', (411.1, 493.2), 54.3, gold), ('arrow', (100 - 50*math.cos(math.radians(120)), 592 - 50*math.sin(math.radians(120))), 120, gold)]
for k in range(5):
    a = math.pi/2 - k*2*math.pi/5
    lamps.append(('drop', (284 + 60*math.cos(a), 470 + 60*math.sin(a)), 0, drops[k]))
lamps += [('helix', (364, 550), 0, (1.0, 0.62, 0.25)), ('shoot', (284, 150), 0, (0.55, 0.80, 1.0)),
          ('star', (284, 335), 0, (1.0, 0.52, 0.76)), ('kick', (37, 300), 0, (1.0, 0.54, 0.24)), ('save', (CM - 37, 300), 0, (0.28, 0.88, 0.78))]
def shape(kind):
    return {'arrow': arrow(24, 18), 'drop': circle(7), 'helix': circle(6), 'shoot': circle(9), 'star': star(20, 8.5),
            'kick': circle(9), 'save': circle(9)}[kind]
def px(x, y): return ((x + 40) * S, (1330 - y) * S)
def render(kind, b):
    base = np.asarray(full(kind)).astype(np.float32) / 255
    for k, c, ang, col in lamps:
        pts = shape(k); a = math.radians(ang)
        rot = [(x*math.cos(a) - y*math.sin(a), x*math.sin(a) + y*math.cos(a)) for x, y in pts]
        def layer(scale, fill_alpha, rgb, stroke=None, width=0):
            m = Image.new('L', (base.shape[1], base.shape[0]), 0); d = ImageDraw.Draw(m)
            poly = [px(c[0] + x*scale, c[1] + y*scale) for x, y in rot]
            d.polygon(poly, fill=int(255*fill_alpha))
            return np.asarray(m, np.float32)[..., None] / 255
        col = np.array(col, np.float32)
        if STYLE == 'old':
            glow = layer(1.6, 0.35*b, col)
            base = np.clip(base + glow * col, 0, 1)                      # additive halo
            ins = layer(1.0, 0.16 + 0.84*b, col)
            base = base * (1 - ins) + col * ins
        else:
            sock = layer(1.25, 0.55, None)                                  # dark socket (normal blend)
            base = base * (1 - sock) + np.array([0.06, 0.05, 0.10]) * sock
            glow = layer(1.9, 0.45*b, col)                                  # halo, normal blend so it shows on light paper
            base = base * (1 - glow) + col * glow
            ins = layer(1.0, 0.30 + 0.70*b, col)
            dim = col * (0.45 + 0.55*b)
            base = base * (1 - ins) + dim * ins
            core = layer(0.45, 0.9*b, col)
            base = base * (1 - core) + np.array([1, 1, 0.95]) * core
    return Image.fromarray((np.clip(base, 0, 1)*255).astype(np.uint8))
tiles = []
for kind in ('sketch', 'color'):
    for b in (0, 1):
        im = render(kind, b)
        x0, y0 = px(-40, 760); x1, y1 = px(640, 120)
        tiles.append(im.crop((int(x0), int(y0), int(x1), int(y1))).resize((340, 320)))
out = Image.new('RGB', (4*340 + 30, 320), (20, 20, 20))
for i, t in enumerate(tiles): out.paste(t, (i*350, 0))
out.save(f'/tmp/claude-0/s/lamps_{STYLE}.png'); print('ok')
