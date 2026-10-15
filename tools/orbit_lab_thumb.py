"""Pinball Lab: the Table 01 (Orbit Pinball) card picture, orbit_lab_thumb.png (420 x 750, the card's 84:150).
Orbit has no baked table art: the game draws its walls, slings, flippers and lights in code over Kenney sprites. This
script redraws the table the same way (OrbitTableLayout's numbers, OrbitTableScene's colours and widths, the same
sprites) with pycairo, with a ball in play and two lanes lit.
Usage: python3 orbit_lab_thumb.py <dir with the orbit_*.png sprites> <out.png>"""
import sys, math, os, random
import cairo
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
S = 3.0                                    # pixels per scene point while drawing (downsampled at the end)
# region drawn: x -17..407, y 80..837 = 424 x 757 points (84:150), the whole table from the flippers to the arch
X0, X1, Y0, Y1 = -17.0, 407.0, 80.0, 837.0
W, H = int((X1 - X0) * S), int((Y1 - Y0) * S)
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
c = cairo.Context(surf)
# scene coordinates (y up) → pixels
c.translate(-X0 * S, Y1 * S); c.scale(S, -S)

BLUE = (0.45, 0.75, 1.0)
ORANGE = (1.0, 0.55, 0.25)


def sprite(name, cx, cy, w, h, rot=0.0, alpha=1.0, tint=None, add=False):
    path = os.path.join(SRC, name + '.png')
    im = Image.open(path).convert('RGBA')
    if tint:
        r, g, b, a = im.split()
        lum = Image.merge('RGB', (r, g, b)).convert('L')
        im = Image.merge('RGBA', tuple(lum.point(lambda v, k=k: int(v * k)) for k in tint) + (a,))
    tmp = os.path.join(os.path.dirname(OUT) or '.', '_s.png'); im.save(tmp)
    img = cairo.ImageSurface.create_from_png(tmp); os.remove(tmp)
    c.save()
    c.translate(cx, cy); c.rotate(rot)
    c.scale(w / img.get_width(), -h / img.get_height())       # flip back to image y-down
    c.set_source_surface(img, -img.get_width() / 2, -img.get_height() / 2)
    if add: c.set_operator(cairo.OPERATOR_ADD)
    c.paint_with_alpha(alpha)
    c.restore()


def polyline(pts, color, width, glow=True, alpha=1.0):
    def path():
        c.move_to(*pts[0])
        for p in pts[1:]: c.line_to(*p)
    c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND)
    if glow:                                               # SKShapeNode glowWidth 2: a soft wider halo
        for wmul, a in ((4.0, 0.10), (2.4, 0.22)):
            path(); c.set_source_rgba(*color, a * alpha); c.set_line_width(width * wmul); c.stroke()
    path(); c.set_source_rgba(*color, alpha); c.set_line_width(width); c.stroke()


def quad(p0, ctl, p1, n=16):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * ctl[0] + t * t * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * ctl[1] + t * t * p1[1]) for t in (i / n for i in range(1, n + 1))]


# ------------------------------------------------------------------ layout (OrbitTableLayout)
LW, RW, LANE, FLOOR = 16, 374, 338, 30
LP, RP = (110, 180), (280, 180)
FL, R0, R1, REST = 72, 9, 5, math.pi / 6
lge = (LP[0] + (R0 + 1) * math.sin(REST), LP[1] + (R0 + 1) * math.cos(REST))
rge = (RP[0] - (R0 + 1) * math.sin(REST), RP[1] + (R0 + 1) * math.cos(REST))
outer = [lge, (LW, 260), (LW, 700)] + quad((LW, 700), (LW, 820), (195, 820)) + quad((195, 820), (RW, 820), (RW, 700)) \
        + [(RW, FLOOR), (LANE, FLOOR), (LANE, 620)]
right_guide = [(LANE, 260), rge]
LANE_POSTS = [110, 160, 210, 260]

# ------------------------------------------------------------------ background: nebula + stars
sprite('orbit_nebula', 195, 422, 390 * 1.15, 844 * 1.15)
rng = random.Random(7)
for i in range(110):
    bright = i % 9 == 0
    s = rng.uniform(5, 8) if bright else rng.uniform(1.5, 3.5)
    sprite('orbit_starBright' if bright else 'orbit_star', rng.uniform(X0, X1), rng.uniform(Y0, Y1), s, s,
           alpha=rng.uniform(0.35, 0.9))

# ------------------------------------------------------------------ walls, guides, gate, plunger
polyline(outer, BLUE, 3)
polyline(right_guide, BLUE, 3)
for x in LANE_POSTS: polyline([(x, 690), (x, 745)], BLUE, 3)
polyline([(338, 530), (312.5, 519.5)], BLUE, 3)                    # deflector above the asteroids
polyline([(LANE, 620), (RW, 652)], ORANGE, 3)                      # the launch gate, closed
c.save(); c.set_source_rgb(0.65, 0.65, 0.65)                       # plunger at rest
x, y, w, h = (LANE + RW) / 2 - 13, 90 - 40, 26, 40
r = 4
c.new_sub_path(); c.arc(x + w - r, y + r, r, -math.pi / 2, 0); c.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
c.arc(x + r, y + h - r, r, math.pi / 2, math.pi); c.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2); c.close_path(); c.fill()
c.restore()

# ------------------------------------------------------------------ slingshots
for top, corner, tip in (((60, 330), (60, 262), (102, 238)), ((308, 330), (308, 262), (268, 240))):
    c.move_to(*top); c.line_to(*corner); c.line_to(*tip); c.close_path()
    c.set_source_rgba(*BLUE, 0.12); c.fill_preserve()
    c.set_source_rgba(*BLUE, 1); c.set_line_width(3); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke()
    polyline([tip, top], ORANGE, 4, glow=False)

# ------------------------------------------------------------------ rollover lights (two lit), skill ring on one
for i, x in enumerate([(a + b) / 2 for a, b in zip(LANE_POSTS, LANE_POSTS[1:])]):
    lit = i != 1
    c.arc(x, 730, 5, 0, 2 * math.pi)
    c.set_source_rgb(*((1.0, 0.85, 0.3) if lit else (0.25, 0.25, 0.25))); c.fill()
    if lit:
        c.arc(x, 730, 9, 0, 2 * math.pi); c.set_source_rgba(1.0, 0.85, 0.3, 0.25); c.fill()
    if i == 1:
        c.arc(x, 730, 10, 0, 2 * math.pi); c.set_source_rgb(0.3, 0.95, 1.0); c.set_line_width(2); c.stroke()

# ------------------------------------------------------------------ planet bumpers
for (bx, by), name, glow in (((135, 590), 'orbit_planetGreen', (0.35, 0.85, 0.75)),
                             ((235, 590), 'orbit_planetRed', (1.0, 0.45, 0.35)),
                             ((185, 510), 'orbit_planetPurple', (0.70, 0.45, 1.0))):
    c.arc(bx, by, 27, 0, 2 * math.pi); c.set_source_rgba(*glow, 0.18); c.fill_preserve()
    c.set_source_rgba(*glow, 0.8); c.set_line_width(2); c.stroke()
    sprite(name, bx, by, 48, 48, rot=rng.uniform(0, 2 * math.pi))

# ------------------------------------------------------------------ asteroid drop targets (one down)
for i, ty in enumerate([500, 468, 436, 404]):
    if i == 2: continue
    sprite(f'orbit_asteroid{i % 4 + 1}', 326, ty, 30, 20, rot=math.pi / 2)

# ------------------------------------------------------------------ the wormhole
c.arc(58, 615, 16, 0, 2 * math.pi); c.set_source_rgb(0.02, 0.0, 0.06); c.fill()
for scale, a, rot in ((1.25, 0.9, 0.4), (0.85, 0.6, 1.9)):
    sprite('orbit_wormholeRing', 58, 615, 32 * scale, 32 * scale, rot=rot, alpha=a, tint=(0.7, 0.4, 1.0), add=True)

# ------------------------------------------------------------------ flippers at rest
for pivot, d in ((LP, 1), (RP, -1)):
    c.save(); c.translate(*pivot); c.rotate(-d * REST)
    c.new_sub_path()
    a = math.asin((R0 - R1) / FL)
    if d > 0:
        c.arc(0, 0, R0, math.pi / 2 + a, 3 * math.pi / 2 - a); c.arc(FL, 0, R1, -math.pi / 2 - a, math.pi / 2 + a)
    else:
        c.arc(0, 0, R0, -math.pi / 2 + a, math.pi / 2 - a); c.arc(-FL, 0, R1, math.pi / 2 - a, 3 * math.pi / 2 + a)
    c.close_path()
    c.set_source_rgb(0.30, 0.55, 1.0); c.fill_preserve()
    c.set_source_rgb(1, 1, 1); c.set_line_width(1.5); c.stroke()
    c.restore()

# ------------------------------------------------------------------ a ball in play, with a short trail
for k in range(6):
    c.arc(205 - k * 5, 395 - k * 9, 8 - k, 0, 2 * math.pi); c.set_source_rgba(0.6, 1.0, 0.85, 0.18 - k * 0.025); c.fill()
sprite('orbit_ball', 205, 395, 20, 20)

surf.write_to_png(OUT + '.full.png')
Image.open(OUT + '.full.png').convert('RGB').resize((420, 750), Image.LANCZOS).save(OUT)
os.remove(OUT + '.full.png')
print('wrote', OUT)
