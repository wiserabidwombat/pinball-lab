"""Table 05 (The Lamplight) M9 round 1: the printed floor of the lower table (pycairo), used as the Blender floor
texture by lmp_bake_lower.py. Honey-oak floorboards running up the table, an oval rug between the slingshots, a slate
hearth in the closed pocket on the left, and lacquered green apron plates with gold pinstripes.
World points, y up; the image covers L.LOWER_RECT at L.PX_PER_PT * scale.
Usage: python3 lmp_floor_lower.py out.png [scale]"""
import cairo, math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

OUT = sys.argv[1]
SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
X0, Y0, W, H = L.LOWER_RECT
S = L.PX_PER_PT * SCALE
surf = cairo.ImageSurface(cairo.FORMAT_RGB24, int(W * S), int(H * S))
cr = cairo.Context(surf)
# world points, y up
cr.translate(-X0 * S, (Y0 + H) * S)
cr.scale(S, -S)
rnd = random.Random(5)


def poly(pts):
    cr.move_to(*pts[0])
    for p in pts[1:]:
        cr.line_to(*p)
    cr.close_path()


def rgb(c, a=1.0):
    cr.set_source_rgba(c[0], c[1], c[2], a)


# ------------------------------------------------------------------ floorboards
PLANK = 26.0
OAKS = [(0.62, 0.40, 0.20), (0.68, 0.45, 0.23), (0.57, 0.36, 0.18), (0.72, 0.49, 0.26), (0.64, 0.42, 0.22)]
x = X0 - rnd.uniform(0, PLANK)
while x < X0 + W:
    y = Y0 - rnd.uniform(0, 200)
    while y < Y0 + H:
        ln = rnd.uniform(140, 300)
        base = rnd.choice(OAKS)
        j = rnd.uniform(-0.04, 0.04)
        col = tuple(max(0, min(1, c + j)) for c in base)
        rgb(col); cr.rectangle(x, y, PLANK, ln); cr.fill()
        # grain: long wavy darker strokes, a few lighter ones
        cr.save(); cr.rectangle(x, y, PLANK, ln); cr.clip()
        for g in range(9):
            gx = x + rnd.uniform(1, PLANK - 1)
            amp, per, ph = rnd.uniform(0.3, 1.6), rnd.uniform(40, 120), rnd.uniform(0, 6.3)
            dark = rnd.random() < 0.75
            rgb(tuple(c * (0.78 if dark else 1.12) for c in col), rnd.uniform(0.25, 0.55))
            cr.set_line_width(rnd.uniform(0.25, 0.8))
            yy = y
            cr.move_to(gx + amp * math.sin(ph), yy)
            while yy < y + ln:
                yy += 4
                cr.line_to(gx + amp * math.sin(ph + yy / per * 6.28), yy)
            cr.stroke()
        # the odd knot
        if rnd.random() < 0.18:
            kx, ky = x + rnd.uniform(5, PLANK - 5), y + rnd.uniform(20, ln - 20)
            for r_, a in ((3.2, 0.25), (2.0, 0.35), (1.0, 0.5)):
                rgb((0.30, 0.16, 0.07), a); cr.save(); cr.translate(kx, ky); cr.scale(1, 2.2)
                cr.arc(0, 0, r_, 0, 6.29); cr.restore(); cr.fill()
        cr.restore()
        # end joint
        rgb((0.16, 0.08, 0.03), 0.9); cr.set_line_width(0.7)
        cr.move_to(x, y); cr.line_to(x + PLANK, y); cr.stroke()
        y += ln
    # long seam between planks
    rgb((0.14, 0.07, 0.03), 0.95); cr.set_line_width(0.9)
    cr.move_to(x, Y0); cr.line_to(x, Y0 + H); cr.stroke()
    x += PLANK

# warm varnish wash: a little darker toward the edges and the bottom
g = cairo.LinearGradient(0, Y0, 0, Y0 + H)
g.add_color_stop_rgba(0, 0.18, 0.08, 0.02, 0.35)
g.add_color_stop_rgba(0.5, 0.18, 0.08, 0.02, 0.0)
g.add_color_stop_rgba(1, 0.18, 0.08, 0.02, 0.10)
cr.set_source(g); cr.rectangle(X0, Y0, W, H); cr.fill()

# ------------------------------------------------------------------ the rug (between the slings): lmp_rug.py
# M9 round 1b (Aaron: "more of this style of rug"): a worn tribal/Persian-style rug, navy field, rust and cream.
import lmp_rug
lmp_rug.draw_rug(cr, 152, 232, 264, 376)

# ------------------------------------------------------------------ hearth: slate in the closed pocket
cr.save(); poly(L.left_closed_pocket()); cr.clip()
rgb((0.17, 0.17, 0.19)); cr.paint()
for row in range(0, 30):
    yy = L.APRON_TOP_Y - 20 + row * 16
    off = 9 if row % 2 else 0
    for col in range(-1, 8):
        xx = L.LEFT_X - 10 + col * 18 + off
        shade = rnd.uniform(0.18, 0.27)
        rgb((shade, shade, shade + 0.02)); cr.rectangle(xx + 0.8, yy + 0.8, 16.4, 14.4); cr.fill()
cr.restore()

# ------------------------------------------------------------------ aprons: lacquered green with gold pinstripes
GREEN, GREEN_DARK, GOLD = (0.09, 0.22, 0.17), (0.05, 0.13, 0.10), (0.86, 0.66, 0.30)
left_apron = [(X0, L.APRON_TOP_Y + 3), (L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, Y0), (X0, Y0)]
right_apron = [(L.LANE_X, L.APRON_TOP_Y), (L.MIRROR - L.DRAIN_X, L.DRAIN_Y), (L.MIRROR - L.DRAIN_X, Y0),
               (X0 + W, Y0), (X0 + W, L.LANE_FLOOR_Y), (L.LANE_X, L.LANE_FLOOR_Y)]
for ap in (left_apron, right_apron):
    g = cairo.LinearGradient(0, L.APRON_TOP_Y, 0, Y0)
    g.add_color_stop_rgb(0, *GREEN); g.add_color_stop_rgb(1, *GREEN_DARK)
    cr.set_source(g); poly(ap); cr.fill()
# pinstripes following each apron's top edge, 9 pt in, and a small scroll at the inner corner
for top, inner, flip in (((L.LEFT_X + 6, L.APRON_TOP_Y - 9), (L.DRAIN_X - 9, L.DRAIN_Y - 12), 1),
                         ((L.LANE_X - 6, L.APRON_TOP_Y - 9), (L.MIRROR - L.DRAIN_X + 9, L.DRAIN_Y - 12), -1)):
    rgb(GOLD, 0.9); cr.set_line_width(1.1)
    cr.move_to(*top); cr.line_to(*inner); cr.line_to(inner[0], Y0 + 30); cr.stroke()
    rgb(GOLD, 0.55); cr.set_line_width(0.6)
    cr.move_to(top[0], top[1] - 4); cr.line_to(inner[0] - 4 * flip, inner[1] - 4); cr.line_to(inner[0] - 4 * flip, Y0 + 30)
    cr.stroke()
    # scroll
    cx, cy = inner[0] - 12 * flip, inner[1] - 22
    rgb(GOLD, 0.85); cr.set_line_width(1.0)
    for k in range(3):
        cr.arc(cx, cy, 3 + k * 2.2, 0, 2 * math.pi * 0.75); cr.stroke()
# drain: dark well between the aprons
g = cairo.LinearGradient(0, L.DRAIN_LIP_Y, 0, Y0)
g.add_color_stop_rgb(0, 0.05, 0.03, 0.02); g.add_color_stop_rgb(1, 0.0, 0.0, 0.0)
cr.set_source(g); cr.rectangle(L.DRAIN_X, Y0, L.MIRROR - 2 * L.DRAIN_X, L.DRAIN_LIP_Y - Y0); cr.fill()

surf.write_to_png(OUT)
print('wrote', OUT, surf.get_width(), surf.get_height())
