"""Table 06 M5 v1: puts stand-in flippers, lit lamps, the plunger and a ball over the baked lower table, so the look
can be judged with the moving parts in place (they're still the code-drawn grey-box ones in the game). Flippers: white
with a red rubber (NASA white and insignia red). Lamps lit as in a game in progress: Mercury to Mars visited, O and R
lit, the kickback lit, the countdown at 3, the rocket arrow flashing.
Usage: python3 tour_look_preview.py bake.png ball.png out.png scale"""
import math, sys, os
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tour_look_layout as L

BAKE, BALL, OUT, SCALE = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
X0, Y0, W, H = L.LOWER_RECT
S = L.PX_PER_PT * SCALE
im = Image.open(BAKE).convert('RGBA')


def P(x, y, z=0):
    return ((x - X0) * S, (Y0 + H - (y + z * L.OBLIQUE)) * S)


def layer():
    return Image.new('RGBA', im.size, (0, 0, 0, 0))


def lamp(c, r, col, core=(255, 248, 230)):
    """A lit insert: a soft additive-looking halo, the coloured lens and a near-white hot core."""
    x, y = P(*c)
    g = layer(); gd = ImageDraw.Draw(g)
    rr = r * S
    gd.ellipse([x - rr * 2.6, y - rr * 2.6, x + rr * 2.6, y + rr * 2.6], fill=(*col, 120))
    im.alpha_composite(g.filter(ImageFilter.GaussianBlur(rr * 1.1)))
    d = ImageDraw.Draw(im)
    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(*col, 170))
    d.ellipse([x - rr * 0.45, y - rr * 0.45, x + rr * 0.45, y + rr * 0.45], fill=(*core, 200))


def flipper(pivot, left):
    a = -L.REST if left else math.pi + L.REST
    tip = (pivot[0] + L.FLIPPER_LEN * math.cos(a), pivot[1] + L.FLIPPER_LEN * math.sin(a))
    pts = [(pivot, L.PIVOT_R), (tip, L.TIP_R)]

    def body(dd, dx, dy, z, fill, grow=0.0):
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
    sh = layer(); body(ImageDraw.Draw(sh), 5, -6, 0, (0, 0, 8, 150))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3 * S)))
    d = ImageDraw.Draw(im)
    body(d, 0, 0, 8, (196, 30, 36, 255), grow=0.6)          # red rubber
    body(d, 0, 0, 10, (238, 240, 244, 255), grow=-2.2)      # white top
    hl = layer(); body(ImageDraw.Draw(hl), -0.8, 0.8, 10.5, (255, 255, 255, 120), grow=-3.6)
    im.alpha_composite(hl.filter(ImageFilter.GaussianBlur(1.2 * S)))
    x, y = P(*pivot, 12); rr = 4.5 * S
    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(205, 210, 220, 255))
    d.ellipse([x - rr * 0.5, y - rr * 0.5, x + rr * 0.5, y + rr * 0.5], fill=(250, 252, 255, 255))


flipper(L.LEFT_PIVOT, True)
flipper(L.RIGHT_PIVOT, False)

# planet arc: Mercury, Venus, Mars visited (lit in their colours), the Moon next (white)
AC, AR = (284, 300), 135
for i, col in enumerate([(200, 195, 185), (250, 225, 160), (255, 120, 70), (240, 240, 255)]):
    a = math.radians(158 - i * (136 / 8))
    lamp((AC[0] + AR * math.cos(a), AC[1] + AR * math.sin(a)), 8, col)
AMBER, RED, ORANGE = (255, 170, 60), (255, 70, 60), (255, 120, 40)
for x in L.LANE_XS[:2]:
    lamp((x, L.LANE_LAMP_Y), 8.5, AMBER)
lamp(L.KICKBACK_LAMP, 8, RED)
for x, y in L.COUNTDOWN_LAMPS[:3]:                         # 1, 2, 3 still to go
    lamp((x, y), 7, ORANGE)
lamp((284, 650 + 5), 9, ORANGE)                             # the rocket arrow
lamp((284, 650 - 17), 4, (255, 220, 90))                    # its goal lamp

# plunger: a steel rod with a red knob
lx = (L.LANE_X + L.RIGHT_X) / 2
x0, y0 = P(lx - 12, 120); x1, y1 = P(lx + 12, 70)
d = ImageDraw.Draw(im)
d.rectangle([x0 + 8 * S, y0, x1 - 8 * S, y1], fill=(190, 195, 205, 255))
d.rounded_rectangle([x0, y0 - 2 * S, x1, y0 + 8 * S], radius=3 * S, fill=(196, 30, 36, 255))

# a ball rolling down the left inlane, with its shadow
bx, by = 71, 330
sh = layer(); sd = ImageDraw.Draw(sh)
x, y = P(bx + 5, by - 6); r = 9 * S
sd.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(0, 0, 8, 160))
im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3 * S)))
ball = Image.open(BALL).convert('RGBA')
br = int(2 * 9 * 1.2 * S)
ball = ball.resize((br, br), Image.LANCZOS)
x, y = P(bx, by, 9)
im.alpha_composite(ball, (int(x - br / 2), int(y - br / 2)))
im.convert('RGB').save(OUT, quality=92)
print('wrote', OUT, im.size)
