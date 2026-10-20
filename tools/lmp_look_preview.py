"""Table 05 M9 round 1: puts stand-in flippers, lamps, the plunger and a ball over the baked lower table, so the look
can be judged with the moving parts in place (they're still the code-drawn grey-box ones in the game).
Usage: python3 lmp_look_preview.py bake.png out.png scale"""
import math, sys, os
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

BAKE, OUT, SCALE = sys.argv[1], sys.argv[2], float(sys.argv[3])
X0, Y0, W, H = L.LOWER_RECT
S = L.PX_PER_PT * SCALE
im = Image.open(BAKE).convert('RGBA')


def P(x, y, z=0):
    return ((x - X0) * S, (Y0 + H - (y + z * L.OBLIQUE)) * S)


over = Image.new('RGBA', im.size, (0, 0, 0, 0))
d = ImageDraw.Draw(over)


def flipper(pivot, left):
    a = -L.REST if left else math.pi + L.REST
    tip = (pivot[0] + L.FLIPPER_LEN * math.cos(a), pivot[1] + L.FLIPPER_LEN * math.sin(a))
    shadow = Image.new('RGBA', im.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(shadow)
    pts = []
    for (cx, cy), r in ((pivot, L.PIVOT_R), (tip, L.TIP_R)):
        pts.append(((cx, cy), r))
    def body(dd, dx, dy, z, fill, grow=0):
        (p0, r0), (p1, r1) = pts
        ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0]); n = (-math.sin(ang), math.cos(ang))
        poly = [P(p0[0] + n[0] * (r0 + grow) + dx, p0[1] + n[1] * (r0 + grow) + dy, z),
                P(p1[0] + n[0] * (r1 + grow) + dx, p1[1] + n[1] * (r1 + grow) + dy, z),
                P(p1[0] - n[0] * (r1 + grow) + dx, p1[1] - n[1] * (r1 + grow) + dy, z),
                P(p0[0] - n[0] * (r0 + grow) + dx, p0[1] - n[1] * (r0 + grow) + dy, z)]
        dd.polygon(poly, fill=fill)
        for (c, r) in pts:
            x, y = P(c[0] + dx, c[1] + dy, z); rr = (r + grow) * S
            dd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=fill)
    body(sd, 5, -6, 0, (20, 8, 2, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(3 * S))
    over.alpha_composite(shadow)
    body(d, 0, 0, 8, (235, 226, 205, 255), grow=0.6)       # cream rubber
    body(d, 0, 0, 10, (96, 44, 22, 255), grow=-2.2)        # walnut top
    x, y = P(*pivot, 12); rr = 4.5 * S
    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(222, 170, 84, 255))


def lamp(c, r, col, lit):
    x, y = P(*c)
    rr = r * S * 1.25
    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(25, 14, 6, 230))
    rr = r * S
    if lit:
        glow = Image.new('RGBA', im.size, (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
        gd.ellipse([x - rr * 2.2, y - rr * 2.2, x + rr * 2.2, y + rr * 2.2], fill=(*col, 110))
        over.alpha_composite(glow.filter(ImageFilter.GaussianBlur(rr)))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(*col, 255))
        d.ellipse([x - rr * 0.45, y - rr * 0.45, x + rr * 0.45, y + rr * 0.45], fill=(255, 246, 225, 255))
    else:
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(tuple(int(v * 0.35) for v in col)) + (255,))


flipper(L.LEFT_PIVOT, True)
flipper(L.RIGHT_PIVOT, False)
WARM, ORANGE, GREEN = (255, 199, 107), (250, 158, 97), (140, 217, 140)
for i, p in enumerate(L.SHOP_LAMPS):
    lamp(p, 7, WARM, i in (0, 1, 3))
for i, p in enumerate(L.COZY_LAMPS):
    lamp(p, L.COZY_LAMP_R, ORANGE, True)
lamp(L.CAT_FLAP_LAMP, 8, GREEN, True)
lamp(L.LUCKY_LAMP, 9, GREEN, False)
# plunger: a steel rod with a walnut knob
x0, y0 = P(L.LANE_X + 16 - L.PLUNGER_W / 2, L.PLUNGER_REST_TOP)
x1, y1 = P(L.LANE_X + 16 + L.PLUNGER_W / 2, L.PLUNGER_REST_TOP - L.PLUNGER_H)
d.rectangle([x0 + 6 * S, y0, x1 - 6 * S, y1], fill=(190, 190, 195, 255))
d.rounded_rectangle([x0, y0 - 2 * S, x1, y0 + 8 * S], radius=3 * S, fill=(150, 70, 30, 255))
im.alpha_composite(over)
# a ball in the right inlane, with its shadow
bx, by = 497, 415
sh = Image.new('RGBA', im.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(sh)
x, y = P(bx + 5, by - 6); r = 9 * S
sd.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(20, 8, 2, 140))
im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3 * S)))
ball = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ball.png')).convert('RGBA')
br = int(2 * 9 * 1.2 * S)
ball = ball.resize((br, br), Image.LANCZOS)
x, y = P(bx, by, 9)
im.alpha_composite(ball, (int(x - br / 2), int(y - br / 2)))
im.convert('RGB').save(OUT)
print('wrote', OUT, im.size)
