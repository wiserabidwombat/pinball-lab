"""Table 03 milestone 2: the printed playfield for the lower table (the floor texture Blender lights).
Covers cth_layout.LOWER_RECT at PX_PER_PT. Drawn y-up in world points (cairo flipped).
Usage: python3 cth_floor_lower.py out_floor.png out_apron.png"""
import cairo, math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

out_floor = sys.argv[1] if len(sys.argv) > 1 else 'cth_floor_lower.png'
out_apron = sys.argv[2] if len(sys.argv) > 2 else 'cth_apron.png'
X0, Y0, RW, RH = L.LOWER_RECT
S = L.PX_PER_PT
PW, PH = int(RW * S), int(RH * S)


def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)


def world_ctx(surf):
    c = cairo.Context(surf)
    c.translate(0, PH); c.scale(S, -S); c.translate(-X0, -Y0)     # world points, y up
    return c


def poly(c, pts, close=True):
    c.move_to(*pts[0])
    for p in pts[1:]: c.line_to(*p)
    if close: c.close_path()


def text_up(c, txt, x, y, size, color, font='Cinzel', weight=cairo.FONT_WEIGHT_BOLD, spacing=0.0, rot=0.0):
    """Centred text in world space (y up), upright on screen."""
    c.save(); c.translate(x, y); c.rotate(rot); c.scale(1, -1)
    c.select_font_face(font, cairo.FONT_SLANT_NORMAL, weight); c.set_font_size(size)
    widths = [c.text_extents(ch).x_advance for ch in txt]
    total = sum(widths) + spacing * (len(txt) - 1)
    xx = -total / 2
    ext = c.text_extents(txt)
    for ch, w in zip(txt, widths):
        c.move_to(xx, ext.height / 2); c.text_path(ch); xx += w + spacing
    c.set_source_rgba(*color); c.fill(); c.restore()


# ---------------------------------------------------------------- floor
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, PW, PH)
c = world_ctx(surf)

# base: deep sea teal, lighter in the middle above the flippers
c.rectangle(X0, Y0, RW, RH); c.set_source_rgba(*rgb('#071315')); c.fill()
g = cairo.RadialGradient(284, 330, 20, 284, 330, 420)
g.add_color_stop_rgba(0, *rgb('#1f5552')[:3], 1); g.add_color_stop_rgba(0.55, *rgb('#12302f')[:3], 1)
g.add_color_stop_rgba(1, *rgb('#081719')[:3], 1)
c.rectangle(X0, Y0, RW, RH); c.set_source(g); c.fill()

# Art Deco sunburst rising from the drain: thin gold rays, faint
for i in range(-14, 15):
    a = math.pi / 2 + i * 0.075
    c.move_to(284, 60); c.line_to(284 + 700 * math.cos(a), 60 + 700 * math.sin(a))
c.set_line_width(1.1); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.10); c.stroke()

# scalloped waves across the bottom of the playfield (the harbour), bone on teal
random.seed(4)
for row, y in enumerate([150, 175, 200]):
    off = 12 if row % 2 else 0
    for x in range(-10 + off, 600, 24):
        c.new_sub_path(); c.arc(x, y, 12, 0, math.pi)
    c.set_line_width(1.4); c.set_source_rgba(*rgb('#e8dcc0')[:3], 0.10 + 0.03 * row); c.stroke()

# double gold pinstripe just inside the walls and lane guides (printed, under the rails)
def pinstripe(pts, offset_alpha=0.55):
    poly(c, pts, close=False); c.set_line_width(5); c.set_source_rgba(*rgb('#0a1c1d')[:3], 0.9); c.stroke()
    poly(c, pts, close=False); c.set_line_width(1.2); c.set_source_rgba(*rgb('#d9b65a')[:3], offset_alpha); c.stroke()

# lane channels: slightly darker so the inlanes/outlanes read as lanes
ol, orr = L.outlane_walls()
for x0, x1 in [(L.LEFT_X, L.LANE_GUIDE_X), (L.MIRROR - L.LANE_GUIDE_X, L.LANE_X)]:
    c.rectangle(x0, 180, x1 - x0, 300); c.set_source_rgba(0, 0, 0, 0.22); c.fill()

# ---- lamp inserts (unlit): glossy coloured shapes set into the wood, with a light rim
def insert(path_fn, col, glow=0.55):
    path_fn(); c.set_source_rgba(*rgb('#000000')[:3], 0.55); c.set_line_width(4); c.stroke_preserve()
    c.save(); c.clip_preserve()
    x1, y1, x2, y2 = c.fill_extents()
    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    r = max(x2 - x1, y2 - y1) * 0.7
    gg = cairo.RadialGradient(cx - r * 0.2, cy + r * 0.25, r * 0.05, cx, cy, r)
    gg.add_color_stop_rgba(0, *rgb(col)[:3], glow); gg.add_color_stop_rgba(1, *[v * 0.35 for v in rgb(col)[:3]], 0.95)
    c.set_source(gg); c.fill(); c.restore()
    path_fn(); c.set_source_rgba(1, 1, 1, 0.35); c.set_line_width(0.8); c.stroke()


def arrow(x, y, ang, length=26, width=16):
    def f():
        c.save(); c.translate(x, y); c.rotate(ang)
        poly(c, [(length / 2, 0), (-length / 2, width / 2), (-length / 2 + 6, 0), (-length / 2, -width / 2)])
        c.restore()
    return f


def circle(x, y, r):
    def f():
        c.new_sub_path(); c.arc(x, y, r, 0, 2 * math.pi)
    return f


def star(x, y, r_out, r_in, n=5):
    def f():
        pts = []
        for i in range(2 * n):
            rr = r_out if i % 2 == 0 else r_in
            a = math.pi / 2 + i * math.pi / n
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
        poly(c, pts)
    return f


# inlane arrows pointing up the lanes, outlane round inserts (kickback left, save right)
insert(arrow(71, 410, math.pi / 2), '#e7c35a')
insert(arrow(L.MIRROR - 71, 410, math.pi / 2), '#e7c35a')
insert(circle(37, 300, 9), '#ff8a3c')
insert(circle(L.MIRROR - 37, 300, 9), '#48e0c8')
# Elder Sign (ball save) between the flippers: a five-pointed star in a ring
c.new_sub_path(); c.arc(284, 312, 25, 0, 2 * math.pi); c.set_line_width(2.2); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.7); c.stroke()
insert(star(284, 312, 20, 8.5), '#7cf0a8')
# little arrows toward each flipper from the inlanes
insert(arrow(118, 286, -math.radians(36), 18, 11), '#e7c35a', 0.4)
insert(arrow(L.MIRROR - 118, 286, -math.pi + math.radians(36), 18, 11), '#e7c35a', 0.4)

# small printed captions (they're art; the live labels for big names come later)
text_up(c, 'ELDER SIGN', 284, 274, 7.5, rgb('#e8dcc0', 0.75), spacing=1.2)
text_up(c, 'KICKBACK', 37, 345, 6, rgb('#ffc9a0', 0.8), spacing=0.8, rot=math.pi / 2)
text_up(c, 'SAVE', L.MIRROR - 37, 345, 6, rgb('#a8fff4', 0.8), spacing=0.8, rot=math.pi / 2)

# plunger lane floor: plain dark wood with a stripe
c.rectangle(L.LANE_X, L.LANE_FLOOR_Y, L.RIGHT_X - L.LANE_X, RH); c.set_source_rgba(*rgb('#0b1416')); c.fill()
c.move_to(L.LANE_CENTER_X, L.LANE_FLOOR_Y + 60); c.line_to(L.LANE_CENTER_X, 525)
c.set_line_width(1); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.35); c.stroke()

# drain chute: black hole between the apron pieces
c.rectangle(L.DRAIN_X, Y0, L.MIRROR - 2 * L.DRAIN_X, L.DRAIN_Y - Y0 + 4); c.set_source_rgba(0.01, 0.01, 0.015, 1); c.fill()

# fine grain + speckle so the print doesn't look flat
random.seed(9)
for _ in range(9000):
    x, y = random.uniform(X0, X0 + RW), random.uniform(Y0, Y0 + RH)
    c.rectangle(x, y, 0.6, 0.6); c.set_source_rgba(1, 1, 1, random.uniform(0.01, 0.04)); c.fill()

surf.write_to_png(out_floor)

# ---------------------------------------------------------------- apron plates (bone, with the title)
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, PW, PH)
c = world_ctx(surf)
c.rectangle(X0, Y0, RW, RH)
g = cairo.LinearGradient(0, 190, 0, -75)
g.add_color_stop_rgb(0, *rgb('#e9dfc4')[:3]); g.add_color_stop_rgb(1, *rgb('#cdbf9c')[:3])
c.set_source(g); c.fill()
# deco border bands near the slope edges
for side in (0, 1):
    pts = [(L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y)]
    if side: pts = [L.mirrored(p) for p in pts]
    for k, (w, col, a) in enumerate([(10, '#1b3b3a', 1), (2, '#b8902f', 1)]):
        c.save(); c.translate(0, -7 - k * 7); poly(c, pts, close=False); c.restore()
        c.set_line_width(w); c.set_source_rgba(*rgb(col)[:3], a); c.stroke()
# the title, split over the two plates
text_up(c, 'CTHULHU', 120, 70, 26, rgb('#16302f'), spacing=2.5, rot=-math.atan2(80, 230) * 0.0)
text_up(c, 'RISING', L.MIRROR - 120, 70, 26, rgb('#16302f'), spacing=4)
text_up(c, 'PINBALL LAB  ·  TABLE 03', 120, 32, 7, rgb('#6c5a34'), spacing=1.5)
text_up(c, 'READ  ·  SUMMON  ·  BANISH', L.MIRROR - 120, 32, 7, rgb('#6c5a34'), spacing=1.5)
# eye motif under each title
for x in (120, L.MIRROR - 120):
    c.save(); c.translate(x, 0); c.scale(26, 10); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
    c.set_line_width(1.6); c.set_source_rgba(*rgb('#b8902f')); c.stroke()
    c.new_sub_path(); c.arc(x, 0, 6, 0, 2 * math.pi); c.set_source_rgba(*rgb('#1b3b3a')); c.fill()
    c.new_sub_path(); c.arc(x, 0, 2, 0, 2 * math.pi); c.set_source_rgba(*rgb('#7cf0a8')); c.fill()
surf.write_to_png(out_apron)
print('wrote', out_floor, out_apron, PW, PH)
