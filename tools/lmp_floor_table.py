"""Table 05 (The Lamplight) M9 round 2: the printed floor of the WHOLE table (pycairo), the Blender floor texture for
lmp_bake_table.py. The lower table as in round 1 (honey-oak floorboards, the tribal rug between the slings, a slate
hearth in the closed left pocket, green lacquer aprons) plus the upper table: darker runners up the orbit lanes, a
sooty brick firebox with embers inside the fireplace alcove and a stone hearth in front of it, tiled kettle lane with
an iron stove ring round the hole, a braided rug under the teacup bumpers, a brass letter plate under the mail slot,
and the loft: a sage window-nook rug with a rainy night window at the top left and a shadow along its edge.
World points, y up; the image covers L.ART_RECT at L.PX_PER_PT * scale.
Usage: python3 lmp_floor_table.py out.png [scale]"""
import cairo, math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

OUT = sys.argv[1]
SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
X0, Y0, W, H = L.ART_RECT
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
# M9 v18 (contrast review: the oak was busy, its seams and grain as strong as the parts on it): planks closer in tone,
# softer seams and grain, fewer knots, a shade darker so the ivory flippers, the ball and the cat's white read.
OAKS = [(0.58, 0.38, 0.20), (0.61, 0.40, 0.21), (0.56, 0.37, 0.19), (0.63, 0.42, 0.22), (0.59, 0.39, 0.20)]
x = X0 - rnd.uniform(0, PLANK)
while x < X0 + W:
    y = Y0 - rnd.uniform(0, 200)
    while y < Y0 + H:
        ln = rnd.uniform(140, 300)
        base = rnd.choice(OAKS)
        j = rnd.uniform(-0.015, 0.015)
        col = tuple(max(0, min(1, c + j)) for c in base)
        rgb(col); cr.rectangle(x, y, PLANK, ln); cr.fill()
        # grain: long wavy darker strokes, a few lighter ones
        cr.save(); cr.rectangle(x, y, PLANK, ln); cr.clip()
        for g in range(6):
            gx = x + rnd.uniform(1, PLANK - 1)
            amp, per, ph = rnd.uniform(0.3, 1.6), rnd.uniform(40, 120), rnd.uniform(0, 6.3)
            dark = rnd.random() < 0.75
            rgb(tuple(c * (0.86 if dark else 1.06) for c in col), rnd.uniform(0.12, 0.26))
            cr.set_line_width(rnd.uniform(0.25, 0.8))
            yy = y
            cr.move_to(gx + amp * math.sin(ph), yy)
            while yy < y + ln:
                yy += 4
                cr.line_to(gx + amp * math.sin(ph + yy / per * 6.28), yy)
            cr.stroke()
        # the odd knot
        if rnd.random() < 0.06:
            kx, ky = x + rnd.uniform(5, PLANK - 5), y + rnd.uniform(20, ln - 20)
            for r_, a in ((3.2, 0.25), (2.0, 0.35), (1.0, 0.5)):
                rgb((0.30, 0.16, 0.07), a * 0.6); cr.save(); cr.translate(kx, ky); cr.scale(1, 2.2)
                cr.arc(0, 0, r_, 0, 6.29); cr.restore(); cr.fill()
        cr.restore()
        # end joint
        rgb((0.25, 0.13, 0.06), 0.45); cr.set_line_width(0.6)
        cr.move_to(x, y); cr.line_to(x + PLANK, y); cr.stroke()
        y += ln
    # long seam between planks
    rgb((0.25, 0.13, 0.06), 0.55); cr.set_line_width(0.7)
    cr.move_to(x, Y0); cr.line_to(x, Y0 + H); cr.stroke()
    x += PLANK

# warm varnish wash: a little darker toward the edges and the bottom
g = cairo.LinearGradient(0, Y0, 0, Y0 + H)
g.add_color_stop_rgba(0, 0.18, 0.08, 0.02, 0.35)
g.add_color_stop_rgba(0.5, 0.18, 0.08, 0.02, 0.0)
g.add_color_stop_rgba(1, 0.18, 0.08, 0.02, 0.10)
cr.set_source(g); cr.rectangle(X0, Y0, W, H); cr.fill()

# ------------------------------------------------------------------ M9 v37: the worn path
# Years of customers: the varnish is a little paler and duller where they walk, from the door (the counter, bottom)
# up the middle to the fireplace, with a branch toward the stairs and one toward the bookcases on the right.
def worn(pts, width):
    for w_, a_ in ((width * 1.6, 0.025), (width * 1.2, 0.03), (width, 0.035), (width * 0.6, 0.03)):
        cr.set_source_rgba(0.86, 0.72, 0.52, a_); cr.set_line_width(w_)
        cr.set_line_cap(cairo.LINE_CAP_ROUND); cr.set_line_join(cairo.LINE_JOIN_ROUND)
        cr.move_to(*pts[0])
        for q in pts[1:]: cr.line_to(*q)
        cr.stroke()
worn([(284, 150), (290, 330), (280, 520), (284, 700)], 46)
worn([(282, 600), (220, 760), (150, 930)], 30)
worn([(286, 560), (400, 640), (520, 700)], 28)

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

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lmp_floor_upper.py')).read())

# ------------------------------------------------------------------ M9 v37: lamplight and rainy window light
# Warm pools from the wall sconces (modelled in lmp_bake_table.py) on the side bookcases, and the cool light of the
# rainy night falling in through the window in the right-hand bookcase, with the glazing bars' shadow and rain streaks.
for side, sy in L.SHOP_SCONCES:
    px = L.LEFT_X + 26 if side == 'L' else L.RIGHT_X - 26
    for rr_, aa_ in ((100, 0.12), (62, 0.18), (32, 0.16)):
        g = cairo.RadialGradient(px, sy - 8, 0, px, sy - 8, rr_)
        g.add_color_stop_rgba(0, 1.0, 0.74, 0.38, aa_); g.add_color_stop_rgba(1, 1.0, 0.74, 0.38, 0.0)
        cr.set_source(g); cr.paint()
wy0, wy1 = L.SHOP_WINDOW_Y0 + 6, L.SHOP_WINDOW_Y1 - 6
def wpool(grow):
    cr.move_to(L.RIGHT_X + 4, wy0 - grow); cr.line_to(L.RIGHT_X + 4, wy1 + grow)
    cr.line_to(452 - grow, wy1 - 52 + grow); cr.line_to(470 - grow, wy0 - 70 - grow); cr.close_path()
for grow, a in ((8, 0.05), (4, 0.06), (0, 0.10)):
    wpool(grow); cr.set_source_rgba(0.68, 0.78, 1.0, a); cr.fill()
cr.save(); wpool(0); cr.clip()
cr.set_source_rgba(0.04, 0.06, 0.12, 0.20); cr.set_line_width(3.2)          # glazing bars: a cross, slanting with the light
ym = (wy0 + wy1) / 2
cr.move_to(L.RIGHT_X + 4, ym); cr.line_to(455, ym - 62); cr.stroke()
cr.move_to((L.RIGHT_X + 470) / 2 + 6, wy0 - 34); cr.line_to((L.RIGHT_X + 452) / 2 + 6, wy1 - 26); cr.stroke()
for i in range(60):                                                            # rain running down the panes
    rx_, ry_ = rnd.uniform(455, 580), rnd.uniform(wy0 - 70, wy1)
    cr.set_source_rgba(0.10, 0.14, 0.24, rnd.uniform(0.10, 0.25)); cr.set_line_width(0.7)
    cr.move_to(rx_, ry_); cr.line_to(rx_ - 3, ry_ - rnd.uniform(5, 10)); cr.stroke()
cr.restore()

# ------------------------------------------------------------------ M9 v38 (bookstore round 4): little things on the floor
# Flat, painted (the ball rolls over them): a brass compass rose let into the boards left of the fireplace, a coir
# "MIND THE CAT" doormat right of it, a ribbon bookmark someone dropped, and the cat's dusty paw prints from the hearth.
def text_at(t, x, y, size, col, a=1.0, bold=True, ang=0.0):
    cr.save(); cr.translate(x, y); cr.rotate(ang); cr.scale(1, -1)
    cr.select_font_face('DejaVu Serif', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size); e = cr.text_extents(t)
    cr.move_to(-e.x_advance / 2, e.height / 2); rgb(col, a); cr.show_text(t); cr.restore()


# the compass rose: brass rings and an eight-point star of brass and dark walnut, N to the top of the table
ccx, ccy = 122, 655
for r_, w_, c_ in ((29, 2.2, (0.30, 0.16, 0.07)), (28, 1.6, (0.86, 0.66, 0.30)), (23.5, 0.8, (0.86, 0.66, 0.30))):
    rgb(c_); cr.set_line_width(w_); cr.arc(ccx, ccy, r_, 0, 2 * math.pi); cr.stroke()
for k in range(8):
    a = k * math.pi / 4 + math.pi / 2
    ln_ = 22 if k % 2 == 0 else 13
    for half, col in ((-1, (0.90, 0.72, 0.36)), (1, (0.25, 0.13, 0.06))):
        cr.move_to(ccx, ccy)
        cr.line_to(ccx + ln_ * math.cos(a), ccy + ln_ * math.sin(a))
        cr.line_to(ccx + 4.2 * math.cos(a + half * math.pi / 4), ccy + 4.2 * math.sin(a + half * math.pi / 4))
        cr.close_path(); rgb(col if k % 2 == 0 else tuple(c * 0.85 for c in col)); cr.fill()
rgb((0.86, 0.66, 0.30)); cr.arc(ccx, ccy, 2.0, 0, 2 * math.pi); cr.fill()
for k in range(32):                                                     # tick marks between the rings
    a = k * math.pi / 16
    cr.set_line_width(0.5); rgb((0.86, 0.66, 0.30), 0.8)
    cr.move_to(ccx + 24 * math.cos(a), ccy + 24 * math.sin(a)); cr.line_to(ccx + 27 * math.cos(a), ccy + 27 * math.sin(a)); cr.stroke()
text_at('N', ccx, ccy + 34.5, 7, (0.86, 0.66, 0.30))

# the doormat: coir, a dark border, MIND THE CAT stencilled with a paw print
cr.save(); cr.translate(432, 748); cr.rotate(math.radians(-4))
mw, mh = 74, 36
rgb((0.10, 0.05, 0.02), 0.35); cr.rectangle(-mw / 2 + 1.2, -mh / 2 - 1.5, mw, mh); cr.fill()          # its shadow
rgb((0.60, 0.44, 0.24)); cr.rectangle(-mw / 2, -mh / 2, mw, mh); cr.fill()
for i in range(900):                                                                                  # coir bristles
    x_, y_ = rnd.uniform(-mw / 2, mw / 2), rnd.uniform(-mh / 2, mh / 2)
    sh = rnd.uniform(0.75, 1.2)
    rgb((0.60 * sh, 0.44 * sh, 0.24 * sh), 0.6); cr.set_line_width(0.45)
    cr.move_to(x_, y_); cr.line_to(x_ + rnd.uniform(-0.8, 0.8), y_ + rnd.uniform(-1.2, 1.2)); cr.stroke()
rgb((0.22, 0.12, 0.06), 0.85); cr.set_line_width(2.4); cr.rectangle(-mw / 2 + 2.5, -mh / 2 + 2.5, mw - 5, mh - 5); cr.stroke()
text_at('MIND THE CAT', 0, 3.6, 6.0, (0.20, 0.10, 0.05), 0.88)
def paw(x, y, s, ang, col, a):
    cr.save(); cr.translate(x, y); cr.rotate(ang); cr.scale(s, s); rgb(col, a)
    cr.save(); cr.scale(1.25, 1.0); cr.arc(0, 0, 1.6, 0, 2 * math.pi); cr.restore(); cr.fill()
    for tx, ty in ((-1.9, 1.9), (-0.7, 2.9), (0.7, 2.9), (1.9, 1.9)):
        cr.arc(tx, ty, 0.62, 0, 2 * math.pi); cr.fill()
    cr.restore()
paw(0, -8.5, 1.5, 0, (0.20, 0.10, 0.05), 0.85)
cr.restore()

# a dropped ribbon bookmark with a gold tassel
cr.save(); cr.translate(476, 545); cr.rotate(math.radians(28)); cr.scale(1.4, 1.4)
rgb((0.10, 0.05, 0.02), 0.3); cr.rectangle(-17 + 0.8, -2.6 - 1.0, 34, 5.2); cr.fill()
rgb((0.50, 0.07, 0.10)); cr.rectangle(-17, -2.6, 34, 5.2); cr.fill()
cr.move_to(-17, -2.6); cr.line_to(-20.5, 0); cr.line_to(-17, 2.6); cr.close_path(); rgb((0.10, 0.05, 0.02), 0); cr.fill()
rgb((0.86, 0.66, 0.30), 0.9); cr.set_line_width(0.4)
for yy in (-1.8, 1.8):
    cr.move_to(-16, yy); cr.line_to(16, yy); cr.stroke()
for k in range(6):
    rgb((0.95, 0.80, 0.45), 0.9); cr.arc(-13 + k * 5.2, 0, 0.7, 0, 2 * math.pi); cr.fill()
rgb((0.86, 0.66, 0.30)); cr.set_line_width(0.6)
cr.move_to(17, 0); cr.line_to(21, 0); cr.stroke()
for k in range(9):                                                      # the tassel
    a = math.radians(-35 + k * 9)
    cr.move_to(21, 0); cr.line_to(21 + 6 * math.cos(a), 6 * math.sin(a)); cr.stroke()
cr.arc(21, 0, 1.2, 0, 2 * math.pi); cr.fill()
cr.restore()

# the cat's dusty paw prints from the hearth, wandering off up-left toward the kettle lane
trail = [(212, 700), (190, 712), (166, 726), (146, 744), (128, 762), (108, 776), (88, 792)]
for i in range(len(trail) - 1):
    (x0_, y0_), (x1_, y1_) = trail[i], trail[i + 1]
    ang_ = math.atan2(y1_ - y0_, x1_ - x0_) - math.pi / 2
    nx_, ny_ = -(y1_ - y0_), (x1_ - x0_); nl_ = math.hypot(nx_, ny_)
    for k, side in ((0.25, 1), (0.75, -1)):
        px_, py_ = x0_ + (x1_ - x0_) * k + side * 2.6 * nx_ / nl_, y0_ + (y1_ - y0_) * k + side * 2.6 * ny_ / nl_
        paw(px_, py_, 1.1, ang_, (0.18, 0.10, 0.05), 0.36 * (1 - i / 9))

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

# ------------------------------------------------------------------ M9 v36 (bookstore round 2): the shop counter
def gilt_text(text, cx, cy, size, italic=False, bold=True, spacing=0.0):
    """Gold-leaf sign lettering centred on (cx, cy), world points: a dark drop shadow, a gold gradient and a bright edge."""
    cr.save()
    cr.select_font_face('DejaVu Serif', cairo.FONT_SLANT_ITALIC if italic else cairo.FONT_SLANT_NORMAL,
                        cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size)
    widths = [cr.text_extents(ch).x_advance + spacing for ch in text]
    tw = sum(widths) - spacing
    ext = cr.text_extents(text)

    def path(dx, dy):
        cr.new_path()
        x = cx - tw / 2 + dx
        for ch, w in zip(text, widths):
            cr.save(); cr.translate(x, cy - ext.height / 2 + dy); cr.scale(1, -1)
            cr.move_to(0, 0); cr.text_path(ch); cr.restore()
            x += w
    path(0.5, -0.6); rgb((0.02, 0.05, 0.04), 0.75); cr.fill()                       # shadow, down-right
    path(0, 0)
    g = cairo.LinearGradient(0, cy + size * 0.5, 0, cy - size * 0.5)
    g.add_color_stop_rgb(0, 0.98, 0.86, 0.52); g.add_color_stop_rgb(0.5, 0.86, 0.64, 0.28)
    g.add_color_stop_rgb(1, 0.62, 0.42, 0.16)
    cr.set_source(g); cr.fill_preserve()
    rgb((1.0, 0.92, 0.66), 0.5); cr.set_line_width(0.18); cr.stroke()
    cr.restore()


# the shop's name in gold leaf on the right apron, like a shop window
gilt_text('The Lamplight', 440, 86, 21, italic=True)
gilt_text('BOOKS  \u00b7  TEA  \u00b7  EST. 1924', 440, 64, 6.4, spacing=0.5)
rgb((0.86, 0.66, 0.30), 0.8); cr.set_line_width(0.7)
for dx in (-1, 1):                                                                   # flourishes either side
    cr.move_to(440 + dx * 58, 64); cr.curve_to(440 + dx * 66, 70, 440 + dx * 72, 58, 440 + dx * 78, 64); cr.stroke()
# BOOK RETURNS: a brass plate across the drain with engraved letters
bx0, bx1, by0, by1 = L.DRAIN_X + 4, L.MIRROR - L.DRAIN_X - 4, -42, -26
g = cairo.LinearGradient(0, by1, 0, by0)
g.add_color_stop_rgb(0, 0.92, 0.74, 0.40); g.add_color_stop_rgb(1, 0.58, 0.40, 0.16)
cr.set_source(g); cr.rectangle(bx0, by0, bx1 - bx0, by1 - by0); cr.fill()
rgb((0.35, 0.22, 0.08)); cr.set_line_width(0.6); cr.rectangle(bx0 + 1.2, by0 + 1.2, bx1 - bx0 - 2.4, by1 - by0 - 2.4); cr.stroke()
for sx in (bx0 + 3, bx1 - 3):                                                        # screws
    for sy in (by0 + 3, by1 - 3):
        rgb((0.45, 0.30, 0.12)); cr.arc(sx, sy, 0.9, 0, 6.29); cr.fill()
cr.save()
cr.select_font_face('DejaVu Serif', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); cr.set_font_size(5.2)
for line, yy in (('BOOK', -31.5), ('RETURNS', -38.5)):
    e = cr.text_extents(line)
    cr.save(); cr.translate((bx0 + bx1) / 2 - e.x_advance / 2, yy); cr.scale(1, -1)
    cr.move_to(0.3, 0.3); rgb((1.0, 0.9, 0.6), 0.6); cr.show_text(line)
    cr.move_to(0, 0); rgb((0.30, 0.18, 0.06)); cr.show_text(line); cr.restore()
cr.restore()

surf.write_to_png(OUT)
print('wrote', OUT, surf.get_width(), surf.get_height())
