"""Table 03 milestone 8: the printed playfield for the WHOLE table (the floor texture Blender lights).
Milestone 2's lower-table painting (cth_floor_lower.py, unchanged below y 525) plus the upper playfield.
Covers cth_layout.FULL_RECT at PX_PER_PT. Drawn y-up in world points (cairo flipped).
Usage: python3 cth_floor_table.py out_floor.png out_apron.png"""
import cairo, math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

out_floor = sys.argv[1] if len(sys.argv) > 1 else 'cth_floor_table.png'
out_apron = sys.argv[2] if len(sys.argv) > 2 else 'cth_apron.png'
X0, Y0, RW, RH = L.FULL_RECT
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
c.rectangle(L.LANE_X, L.LANE_FLOOR_Y, L.RIGHT_X - L.LANE_X, L.LANE_WALL_TOP - L.LANE_FLOOR_Y); c.set_source_rgba(*rgb('#0b1416')); c.fill()
c.move_to(L.LANE_CENTER_X, L.LANE_FLOOR_Y + 60); c.line_to(L.LANE_CENTER_X, L.LANE_WALL_TOP - 20)
c.set_line_width(1); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.35); c.stroke()

# drain chute: black hole between the apron pieces
c.rectangle(L.DRAIN_X, Y0, L.MIRROR - 2 * L.DRAIN_X, L.DRAIN_Y - Y0 + 4); c.set_source_rgba(0.01, 0.01, 0.015, 1); c.fill()


# ================================================================ the upper playfield (milestone 8)
# Night sea above the town: the gradient darkens up the table into the drowned city.
g = cairo.LinearGradient(0, 520, 0, 1330)
g.add_color_stop_rgba(0, *rgb('#12302f')[:3], 0.0)
g.add_color_stop_rgba(0.25, *rgb('#0d2524')[:3], 0.9)
g.add_color_stop_rgba(1, *rgb('#04090b')[:3], 1)
c.rectangle(X0, 520, RW, 820); c.set_source(g); c.fill()

# a big faint illustration: Cthulhu's head and reaching tentacles behind the middle of the table
c.save()
hx, hy = 250, 868
c.translate(hx, hy)
head = [(-62, -40), (-70, 10), (-52, 58), (-20, 82), (20, 84), (52, 60), (70, 12), (62, -40), (30, -62), (-30, -62)]
c.move_to(*head[0])
for i in range(1, len(head) + 1):
    a, b = head[i - 1], head[i % len(head)]
    c.curve_to(a[0] + (b[0] - a[0]) * 0.3, a[1] + (b[1] - a[1]) * 0.3 + 4,
               a[0] + (b[0] - a[0]) * 0.7, a[1] + (b[1] - a[1]) * 0.7 + 4, *b)
c.close_path()
gh = cairo.RadialGradient(0, 20, 10, 0, 0, 95)
gh.add_color_stop_rgba(0, *rgb('#1f4a43')[:3], 0.55); gh.add_color_stop_rgba(1, *rgb('#0b2220')[:3], 0.2)
c.set_source(gh); c.fill()
# wings, sweeping out and up
for sx in (-1, 1):
    c.move_to(sx * 55, 30); c.curve_to(sx * 120, 90, sx * 175, 120, sx * 205, 70)
    for k in range(4):
        c.curve_to(sx * (195 - k * 30), 40 - k * 6, sx * (180 - k * 30), 35 - k * 6, sx * (170 - k * 30), 55 - k * 8)
    c.curve_to(sx * 95, 40, sx * 70, 20, sx * 55, 30); c.close_path()
    c.set_source_rgba(*rgb('#123230')[:3], 0.45); c.fill()
# tentacles hanging from the face, curling out
random.seed(13)
for k in range(7):
    x = -36 + k * 12
    c.move_to(x, -40)
    sway = (k - 3) * 9
    c.curve_to(x + sway * 0.5, -90, x + sway * 1.6, -120, x + sway * 2.2 + (8 if k % 2 else -8), -150 - abs(k - 3) * 6)
    c.set_line_width(9 - abs(k - 3) * 1.2); c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.set_source_rgba(*rgb('#163a36')[:3], 0.5); c.stroke()
# the eyes: dim gold slits
for ex in (-24, 24):
    c.save(); c.translate(ex, 26); c.scale(13, 4); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
    c.set_source_rgba(*rgb('#d9b65a')[:3], 0.35); c.fill()
c.restore()

# the drowned city, R'lyeh: angled spires along the top under the arch, dark on the darker sea
random.seed(21)
for k in range(15):
    x = 70 + k * 33 + random.uniform(-8, 8)
    base = 1196 + random.uniform(-6, 6)
    h = random.uniform(38, 80) * (1.0 if 3 < k < 12 else 0.75)
    lean = random.uniform(-0.25, 0.25)
    w = random.uniform(14, 26)
    c.move_to(x - w / 2, base); c.line_to(x - w * 0.15 + lean * h, base + h)
    c.line_to(x + w * 0.25 + lean * h, base + h * 0.92); c.line_to(x + w / 2, base); c.close_path()
    c.set_source_rgba(*rgb('#0f2a28')[:3], 0.75); c.fill_preserve()
    c.set_line_width(0.8); c.set_source_rgba(*rgb('#2f6a5f')[:3], 0.5); c.stroke()
    for wy in range(int(base + 14), int(base + h * 0.75), 17):
        if random.random() < 0.35:
            c.rectangle(x - 2 + lean * (wy - base), wy, 3, 5)
            c.set_source_rgba(*rgb('#6fe0b0')[:3], random.uniform(0.25, 0.55)); c.fill()

# the orbit lane: a darker channel along the left wall and round the arch
inner = L.orbit_inner()
outer_side = [(L.LEFT_X, 800), (L.LEFT_X, L.ARCH_Y)] + L.quad((L.LEFT_X, L.ARCH_Y), (L.LEFT_X, L.TOP_Y), (L.W / 2, L.TOP_Y), 32)
lane = [p for p in outer_side if p[0] <= L.ORBIT_END_X + 6] + list(reversed(inner))
poly(c, lane); c.set_source_rgba(0, 0, 0, 0.30); c.fill()
# the top-right lane (M8 v2): a darker channel between the arch and its curved inner wall
outer_r = [L.arch_right(L.TOP_GATE_T + (1 - L.TOP_GATE_T) * k / 30) for k in range(31)]
poly(c, outer_r + list(reversed(L.TOP_LANE_WALL))); c.set_source_rgba(0, 0, 0, 0.30); c.fill()
# spinner plate across the lane
c.rectangle(L.LEFT_X, L.SPINNER_Y - 9, L.ORBIT_X - L.LEFT_X, 18); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.18); c.fill()

# the Candle lanes: a lit candle printed under each lane, and a band behind the posts
c.rectangle(212, 1124, 124, 70); c.set_source_rgba(0, 0, 0, 0.25); c.fill()
for x in L.LANE_CENTERS:
    c.rectangle(x - 3, 1136, 6, 14); c.set_source_rgba(*rgb('#e8dcc0')[:3], 0.45); c.fill()
    c.save(); c.translate(x, 1156); c.scale(3, 5); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
    c.set_source_rgba(*rgb('#ffb547')[:3], 0.55); c.fill()
text_up(c, 'CANDLES', 274, 1112, 7, rgb('#e8dcc0', 0.6), spacing=1.5)

# the bumper nest: a faint ring of runes round each pop bumper
for (bx, by) in L.BUMPERS:
    c.new_sub_path(); c.arc(bx, by, L.BUMPER_R + 9, 0, 2 * math.pi)
    c.set_line_width(1.4); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.28); c.stroke()
    for k in range(12):
        a = k * math.pi / 6
        c.move_to(bx + (L.BUMPER_R + 6) * math.cos(a), by + (L.BUMPER_R + 6) * math.sin(a))
        c.line_to(bx + (L.BUMPER_R + 12) * math.cos(a + 0.12), by + (L.BUMPER_R + 12) * math.sin(a + 0.12))
    c.set_line_width(1); c.stroke()

# the Lagoon: dark water with rings, the hole in its centre
lx, ly = L.LAGOON
gl = cairo.RadialGradient(lx, ly, 4, lx, ly, 44)
gl.add_color_stop_rgba(0, *rgb('#2a8f7a')[:3], 0.85); gl.add_color_stop_rgba(0.6, *rgb('#124a40')[:3], 0.7)
gl.add_color_stop_rgba(1, *rgb('#0a1c1d')[:3], 0.0)
c.new_sub_path(); c.arc(lx, ly, 44, 0, 2 * math.pi); c.set_source(gl); c.fill()
for r, a in ((22, 0.5), (29, 0.35), (37, 0.2)):
    c.new_sub_path(); c.arc(lx, ly, r, 0, 2 * math.pi); c.set_line_width(1); c.set_source_rgba(*rgb('#8ff0d4')[:3], a); c.stroke()

# the Library on its hill, behind its hole: a gothic front with lit windows
bx0, by0 = 284, 668
c.move_to(bx0 - 52, by0); c.line_to(bx0 - 52, by0 + 46); c.line_to(bx0 - 30, by0 + 46); c.line_to(bx0 - 30, by0 + 62)
c.line_to(bx0 - 14, by0 + 62); c.line_to(bx0, by0 + 88); c.line_to(bx0 + 14, by0 + 62); c.line_to(bx0 + 30, by0 + 62)
c.line_to(bx0 + 30, by0 + 46); c.line_to(bx0 + 52, by0 + 46); c.line_to(bx0 + 52, by0); c.close_path()
c.set_source_rgba(*rgb('#0d2321')[:3], 0.9); c.fill_preserve(); c.set_line_width(1.2)
c.set_source_rgba(*rgb('#d9b65a')[:3], 0.45); c.stroke()
for wx in (-40, -22, 22, 40):
    c.rectangle(bx0 + wx - 3, by0 + 22, 6, 13); c.set_source_rgba(*rgb('#ffcf6a')[:3], 0.45); c.fill()
c.rectangle(bx0 - 5, by0 + 40, 10, 16); c.set_source_rgba(*rgb('#ffcf6a')[:3], 0.55); c.fill()
text_up(c, 'MISKATONIC LIBRARY', 284, 770, 7.5, rgb('#e8dcc0', 0.7), spacing=1.4)
# hill line
c.move_to(170, 664); c.curve_to(220, 680, 350, 680, 400, 662)
c.set_line_width(1.2); c.set_source_rgba(*rgb('#2f6a5f')[:3], 0.45); c.stroke()

# holes: a gold ring printed round each (the hole itself is a recess in the render)
for (hx2, hy2) in (L.LIBRARY, L.LAGOON):
    c.new_sub_path(); c.arc(hx2, hy2, L.SCOOP_R + 6, 0, 2 * math.pi)
    c.set_line_width(2); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.65); c.stroke()

# the ritual circle: rings, a pentagram through the five candles, runes between the rings
rx, ry = L.RITUAL
for r, w, a in ((L.RITUAL_R, 1.6, 0.7), (64, 1.6, 0.6), (68, 0.8, 0.4)):
    c.new_sub_path(); c.arc(rx, ry, r, 0, 2 * math.pi); c.set_line_width(w); c.set_source_rgba(*rgb('#d9b65a')[:3], a); c.stroke()
cand = L.CANDLE_LAMPS
order = [0, 2, 4, 1, 3]
c.move_to(*cand[order[0]])
for i in order[1:]: c.line_to(*cand[i])
c.close_path(); c.set_line_width(1.3); c.set_source_rgba(*rgb('#7cf0a8')[:3], 0.35); c.stroke()
random.seed(5)
for k in range(30):
    a = k * 2 * math.pi / 30
    r0 = 59
    c.move_to(rx + r0 * math.cos(a), ry + r0 * math.sin(a))
    c.line_to(rx + (r0 + random.uniform(2, 4)) * math.cos(a + 0.05), ry + (r0 + random.uniform(2, 4)) * math.sin(a + 0.05))
c.set_line_width(0.9); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.5); c.stroke()
text_up(c, 'THE RITUAL', 284, 400, 7.5, rgb('#e8dcc0', 0.7), spacing=1.6)

# Sigil bank: a glyph panel behind the targets, in the pocket by the shooter lane
for k, y in enumerate(L.TARGET_YS):
    c.new_sub_path(); c.arc(512, y, 7, 0, 2 * math.pi); c.set_line_width(1); c.set_source_rgba(*rgb('#d9b65a')[:3], 0.35); c.stroke()
    c.move_to(512 - 4, y - 3); c.line_to(512 + 4, y + 3); c.move_to(512 - 4, y + 3); c.line_to(512, y - 4); c.stroke()
text_up(c, 'SIGILS', 512, 650, 6.5, rgb('#e8dcc0', 0.6), spacing=1.2, rot=math.pi / 2)

# ---- the lamp inserts (unlit, glossy); the lamps light them in the game
SEA = '#4de8cc'; PARCH = '#f7cc66'; FLAME = '#ff8c33'; ELD = '#b86bff'; TENT = '#66f273'
for name, (x, y, ang) in L.SHOT_ARROWS.items():
    insert(arrow(x, y, math.radians(ang), 24, 18), SEA)
for (x, y) in L.TOME_LAMPS: insert(circle(x, y, L.TOME_R), PARCH)
text_up(c, 'TOMES', 232, 615, 5.5, rgb('#e8dcc0', 0.6), spacing=1.2)
for (x, y) in L.CANDLE_LAMPS: insert(circle(x, y, L.CANDLE_R), FLAME)
for (x, y) in L.EYE_LAMPS: insert(circle(x, y, L.EYE_R), ELD)
for (x, y) in L.TENTACLE_LAMPS: insert(circle(x, y, L.TENTACLE_R), TENT)
text_up(c, "R'LYEH", 274, 1238, 8, rgb('#8ff0d4', 0.45), spacing=3)

# fine grain + speckle so the print doesn't look flat
random.seed(9)
for _ in range(21000):
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
