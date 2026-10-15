"""Milestone 8 round 0: art concept for Grey Invasion Pinball, drawn on the real table
geometry (mirrors TableLayout.swift as of M7 v11). Night farm, goofy grey aliens.
Output: concept_m8.png (full table, Top-Down view, with the cabinet around it)."""
import math, random
import cairo

random.seed(7)
S = 2.0                                  # pixels per world point
X0, X1, Y0, Y1 = -40, 640, -75, 1330     # world area drawn (includes the cabinet)
WPX, HPX = int((X1 - X0) * S), int((Y1 - Y0) * S)

surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, WPX, HPX)
cr = cairo.Context(surf)
cr.translate(-X0 * S, Y1 * S)
cr.scale(S, -S)                          # world coordinates, y up

# ------------------------------------------------------------------ geometry
W, R = 600, 9
LEFT_X, RIGHT_X, LANE_X, LANE_FLOOR, LANE_TOP, ARCH, TOP = 20, 580, 548, 40, 955, 1000, 1270
MIRROR = 568
LP, RP = (179, 220), (389, 220)
FL_LEN, FL_R0, FL_R1, REST = 96, 12, 6, math.pi / 6
mx = lambda p: (MIRROR - p[0], p[1])


def quad(p0, c, p1, n=24):
    return [((1-t)**2*p0[0] + 2*(1-t)*t*c[0] + t*t*p1[0], (1-t)**2*p0[1] + 2*(1-t)*t*c[1] + t*t*p1[1])
            for t in [i / n for i in range(1, n + 1)]]


def guide_end(p, s):
    r = FL_R0 + 1
    return (p[0] + s * r * math.sin(REST), p[1] + r * math.cos(REST))


LGE, RGE = guide_end(LP, 1), guide_end(RP, -1)
APRON_Y, DRAIN_X, DRAIN_Y, LIP_Y = 185, 250, 105, 85
outer = [(DRAIN_X, LIP_Y), (DRAIN_X, DRAIN_Y), (LEFT_X, APRON_Y), (LEFT_X, 540)] \
    + quad((LEFT_X, 540), (LEFT_X + 36, 660), (LEFT_X, 780)) + [(LEFT_X, ARCH)] \
    + quad((LEFT_X, ARCH), (LEFT_X, TOP), (W/2, TOP), 40) + quad((W/2, TOP), (RIGHT_X, TOP), (RIGHT_X, ARCH), 40) \
    + [(RIGHT_X, LANE_FLOOR), (LANE_X, LANE_FLOOR), (LANE_X, 540)] \
    + quad((LANE_X, 540), (LANE_X - 36, 660), (LANE_X, 780)) + [(LANE_X, LANE_TOP)]
right_apron = [(LANE_X, APRON_Y), (MIRROR - DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, LIP_Y)]
left_guide = [(54, 470), (54, 330), LGE]
right_guide = [mx(q) for q in left_guide]
left_out_wall = [(54, 330), (54, 215)]
right_out_wall = [mx(q) for q in left_out_wall]
lsling = ((88, 450), (88, 347), (150, 300.4))
rsling = tuple(mx(q) for q in lsling)
ORBIT_IN_TOP = TOP - 38
inner_arc = [(58, ARCH)] + quad((58, ARCH), (58, ORBIT_IN_TOP), (W/2, ORBIT_IN_TOP), 32)
orbit_inner = [(112, 800), (58, 890)] + [q for q in inner_arc if q[0] <= 190]
DIV = [(412, 1262), (365, 1160)]
POSTS_X = [220, 256, 292, 328]
lane_cx = [(a + b) / 2 for a, b in zip(POSTS_X, POSTS_X[1:])]
BUMPERS = [(210, 1050), (338, 1050), (274, 950)]
HANGAR, ABDUCT = (284, 760), (470, 700)
BANK_X, BANK_YS = 464, [595, 565, 535, 505]
bank_back, bank_cap = [(476, 487), (476, 621)], [(476, 621), (454, 613)]
UPPER_P = (528, 800)
upper_guide_full = [(548, 824), guide_end(UPPER_P, -1)]
ug = upper_guide_full
upper_guide = [ug[0], (ug[0][0] + (ug[1][0] - ug[0][0]) * 0.67, ug[0][1] + (ug[1][1] - ug[0][1]) * 0.67)]


class Path:
    def __init__(self, start, heading):
        self.pts, self.hd, self.s, self.h = [start], [heading], [0.0], heading

    def line(self, length, step=8):
        n = max(1, math.ceil(length / step)); x0, y0 = self.pts[-1]; s0 = self.s[-1]
        for i in range(1, n + 1):
            d = length * i / n
            self.pts.append((x0 + d*math.cos(self.h), y0 + d*math.sin(self.h))); self.hd.append(self.h); self.s.append(s0 + d)

    def arc(self, radius, turn, step=6):
        n = max(2, math.ceil(abs(turn) * radius / step)); sign = 1 if turn > 0 else -1
        x0, y0 = self.pts[-1]; cx, cy = x0 - sign*radius*math.sin(self.h), y0 + sign*radius*math.cos(self.h)
        a0 = math.atan2(y0 - cy, x0 - cx); s0, h0 = self.s[-1], self.h
        for i in range(1, n + 1):
            a = a0 + turn * i / n
            self.pts.append((cx + radius*math.cos(a), cy + radius*math.sin(a))); self.hd.append(h0 + turn*i/n); self.s.append(s0 + abs(turn)*radius*i/n)
        self.h = h0 + turn


def build_ramp(mouth, left):
    c = math.atan2(260, 90)
    q = Path(mouth, (math.pi - c) if left else c)
    q.line(math.hypot(90, 260)); q.arc(36, (c + math.pi/2) if left else -(c + math.pi/2)); apex = q.s[-1]
    if left:
        q.line(248)
        shift = 69 - q.pts[-1][0]
        if abs(shift) > 0.5:
            b = math.acos(1 - min(abs(shift), 119) / 120); t = b if shift > 0 else -b
            q.arc(60, t); q.arc(60, -t)
        q.line(max(q.pts[-1][1] - 490, 20))
    else:
        q.line(248); b = math.acos(1 - 23 / 120); q.arc(60, -b); q.arc(60, b); q.line(40)
    hw = lambda s: 30 + (16 - 30) * min(s / 70, 1)
    def off(i, side):
        h = q.hd[i]; w = hw(q.s[i]) * side
        return (q.pts[i][0] - w*math.sin(h), q.pts[i][1] + w*math.cos(h))
    return q, apex, [off(i, 1) for i in range(len(q.pts))], [off(i, -1) for i in range(len(q.pts))]


ramps = [build_ramp((360, 600), False), build_ramp((228, 600), True)]

# ------------------------------------------------------------------ drawing helpers
def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)


def poly(pts, close=False):
    cr.move_to(*pts[0])
    for p in pts[1:]: cr.line_to(*p)
    if close: cr.close_path()


def stroke(pts, col, w, close=False, cap=cairo.LINE_CAP_ROUND):
    poly(pts, close); cr.set_source_rgba(*col); cr.set_line_width(w); cr.set_line_cap(cap)
    cr.set_line_join(cairo.LINE_JOIN_ROUND); cr.stroke()


def fill(pts, col):
    poly(pts, True); cr.set_source_rgba(*col); cr.fill()


def circle(c, r, col, line=None, lw=1):
    cr.new_sub_path(); cr.arc(c[0], c[1], r, 0, 2*math.pi)
    cr.set_source_rgba(*col)
    if line: cr.fill_preserve(); cr.set_source_rgba(*line); cr.set_line_width(lw); cr.stroke()
    else: cr.fill()


def radial(c, r0, r1, stops):
    g = cairo.RadialGradient(c[0], c[1], r0, c[0], c[1], r1)
    for o, col in stops: g.add_color_stop_rgba(o, *col)
    return g


def ellipse(c, rx, ry, col=None, src=None):
    cr.save(); cr.translate(*c); cr.scale(rx, ry); cr.new_sub_path(); cr.arc(0, 0, 1, 0, 2*math.pi); cr.restore()
    if src: cr.set_source(src)
    else: cr.set_source_rgba(*col)
    cr.fill()


def text(s, at, size, col, weight=cairo.FONT_WEIGHT_BOLD, center=True, face="Orbitron", glow=None, angle=0):
    cr.save(); cr.translate(*at); cr.rotate(angle); cr.scale(1, -1)
    cr.select_font_face(face, cairo.FONT_SLANT_NORMAL, weight); cr.set_font_size(size)
    ext = cr.text_extents(s)
    x = -ext.width/2 - ext.x_bearing if center else 0
    y = -ext.height/2 - ext.y_bearing
    if glow:
        for k, a in [(3, 0.18), (2, 0.25), (1, 0.35)]:
            cr.set_source_rgba(glow[0], glow[1], glow[2], a)
            for dx, dy in [(-k, 0), (k, 0), (0, -k), (0, k)]:
                cr.move_to(x + dx, y + dy); cr.show_text(s)
    cr.set_source_rgba(*col); cr.move_to(x, y); cr.show_text(s); cr.restore()


# ------------------------------------------------------------------ cabinet + sky around the table
g = cairo.LinearGradient(0, Y0, 0, Y1)
g.add_color_stop_rgba(0, *rgb('#0b0a14')); g.add_color_stop_rgba(1, *rgb('#151432'))
cr.set_source(g); cr.paint()
for _ in range(220):                      # stars outside the cabinet
    x, y = random.uniform(X0, X1), random.uniform(Y0, Y1)
    circle((x, y), random.uniform(0.3, 1.1), (1, 1, 1, random.uniform(0.2, 0.7)))

# cabinet: dark painted wood with a chrome edge, following the table outline
cab = [(LEFT_X - 18, -70)] + [(LEFT_X - 18, ARCH)] + quad((LEFT_X - 18, ARCH), (LEFT_X - 18, TOP + 22), (W/2, TOP + 22), 40) \
    + quad((W/2, TOP + 22), (RIGHT_X + 18, TOP + 22), (RIGHT_X + 18, ARCH), 40) + [(RIGHT_X + 18, -70)]
fill(cab, rgb('#2a1d3a'))
stroke(cab, rgb('#8f86a8'), 3)
# side art: little green UFO silhouettes on the cabinet rails
for y in range(80, 1000, 160):
    for xx in (LEFT_X - 9, RIGHT_X + 9):
        ellipse((xx, y), 7, 2.6, rgb('#58f08a', 0.55)); ellipse((xx, y + 2), 3.2, 2.4, rgb('#58f08a', 0.45))

# ------------------------------------------------------------------ playfield (clipped to the table)
field = [(DRAIN_X, LIP_Y), (DRAIN_X, DRAIN_Y), (LEFT_X, APRON_Y)] + [p for p in outer[3:] if True] \
    + [(RIGHT_X, LANE_FLOOR), (LANE_X, LANE_FLOOR)]
# the playfield shape: outer wall from the left apron round to the plunger lane, then the right apron
pf = [(DRAIN_X, DRAIN_Y), (LEFT_X, APRON_Y)] + outer[3:outer.index((RIGHT_X, LANE_FLOOR)) + 1] \
    + [(LANE_X, LANE_FLOOR), (LANE_X, APRON_Y), (MIRROR - DRAIN_X, DRAIN_Y)]
cr.save(); poly(pf, True); cr.clip()

HORIZON = 905
# night sky (top of the table)
g = cairo.LinearGradient(0, HORIZON, 0, TOP)
g.add_color_stop_rgba(0, *rgb('#3a2a6e')); g.add_color_stop_rgba(0.35, *rgb('#1d1d52')); g.add_color_stop_rgba(1, *rgb('#0b0d2a'))
cr.set_source(g); cr.rectangle(0, HORIZON - 5, 600, 400); cr.fill()
for _ in range(140):
    x, y = random.uniform(20, 580), random.uniform(HORIZON + 20, TOP)
    circle((x, y), random.uniform(0.4, 1.3), (1, 1, 0.92, random.uniform(0.35, 0.9)))
# moon
cr.set_source(radial((95, 1150), 0, 70, [(0, rgb('#fffbe0', 0.35)), (1, rgb('#fffbe0', 0))])); cr.new_sub_path(); cr.arc(95, 1150, 70, 0, 7); cr.fill()
circle((95, 1150), 26, rgb('#f6f0c8')); circle((104, 1158), 22, rgb('#2a2560'))   # crescent

# fields (bottom of the table): dark green with crop rows running to the horizon
g = cairo.LinearGradient(0, 0, 0, HORIZON)
g.add_color_stop_rgba(0, *rgb('#0f2a1a')); g.add_color_stop_rgba(0.7, *rgb('#173d24')); g.add_color_stop_rgba(1, *rgb('#24502e'))
cr.set_source(g); cr.rectangle(0, 0, 600, HORIZON); cr.fill()
VP = (284, HORIZON + 60)
for k in range(-14, 15):
    x = 284 + k * 46
    stroke([(x, 0), (VP[0] + (x - VP[0]) * 0.08, HORIZON - 4)], rgb('#2f6a3a', 0.55), 2.2)
# rolling hills + farm silhouettes on the horizon
hill = [(0, HORIZON - 10)] + [(x, HORIZON + 14 * math.sin(x / 70) + 10) for x in range(0, 601, 10)] + [(600, HORIZON - 10)]
fill(hill, rgb('#122a1f'))
# barn (left) and water tower (right) as horizon silhouettes with warm windows
fill([(118, HORIZON + 10), (118, HORIZON + 48), (138, HORIZON + 66), (158, HORIZON + 48), (158, HORIZON + 10)], rgb('#6e1f24'))
fill([(130, HORIZON + 10), (146, HORIZON + 10), (146, HORIZON + 30), (130, HORIZON + 30)], rgb('#ffcf6a', 0.9))
stroke([(118, HORIZON + 48), (138, HORIZON + 66), (158, HORIZON + 48)], rgb('#e9e3d0'), 2)
for x in (404, 432):
    stroke([(x, HORIZON + 12), (418, HORIZON + 60)], rgb('#3a3a4a'), 2)
ellipse((418, HORIZON + 66), 18, 10, rgb('#5b6378')); fill([(400, HORIZON + 66), (436, HORIZON + 66), (418, HORIZON + 82)], rgb('#4a5164'))
text("GREYVILLE", (418, HORIZON + 66), 5.5, rgb('#d9dde8'))

# crop circle between the ramp mouths, glowing faintly alien green
CC = (284, 590)
for r_, w_ in [(78, 5), (62, 3), (46, 6), (28, 3), (14, 4)]:
    cr.new_sub_path(); cr.arc(CC[0], CC[1], r_, 0, 2*math.pi); cr.set_source_rgba(*rgb('#7dff9e', 0.22)); cr.set_line_width(w_); cr.stroke()
for a in range(0, 360, 60):
    t = math.radians(a)
    circle((CC[0] + 62*math.cos(t), CC[1] + 62*math.sin(t)), 6, rgb('#7dff9e', 0.25))
# fence posts along the bottom of the field
for x in range(30, 560, 22):
    stroke([(x, 255), (x, 270)], rgb('#5a4630', 0.6), 2)
stroke([(26, 266), (548, 266)], rgb('#5a4630', 0.45), 1.5)


def cow(c, s=1.0, flip=1, look_up=False):
    x, y = c
    cr.save(); cr.translate(x, y); cr.scale(s * flip, s)
    ellipse((0, 0), 15, 9, rgb('#f4f1ea'))
    ellipse((-5, 2), 5, 4, rgb('#2b2b2b')); ellipse((6, -3), 4, 3, rgb('#2b2b2b'))
    for lx in (-9, -3, 4, 10): stroke([(lx, -7), (lx, -14)], rgb('#e8e4da'), 3)
    ellipse((16, 6 if look_up else 3), 7, 6, rgb('#f4f1ea')); ellipse((21, 4 if look_up else 1), 4, 3.2, rgb('#f2a7b5'))
    circle((15, 9 if look_up else 6), 1.4, rgb('#111111'))
    stroke([(12, 11), (10, 15)], rgb('#cfc7b2'), 1.6); stroke([(16, 11), (18, 15)], rgb('#cfc7b2'), 1.6)
    stroke([(-15, 2), (-20, -3)], rgb('#e8e4da'), 1.4)
    cr.restore()


cow((150, 525), 1.0, 1)
cow((392, 420), 0.9, -1)
cow((330, 655), 0.75, 1, look_up=True)
cr.restore()   # end playfield clip

# ------------------------------------------------------------------ apron (below the flippers)
apron_l = [(LEFT_X, APRON_Y), (DRAIN_X, DRAIN_Y), (DRAIN_X, -60), (LEFT_X - 18, -60), (LEFT_X - 18, APRON_Y)]
apron_r = [(LANE_X, APRON_Y), (MIRROR - DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, -60), (RIGHT_X + 18, -60), (RIGHT_X + 18, LANE_FLOOR), (LANE_X, LANE_FLOOR)]
for ap in (apron_l, apron_r):
    g = cairo.LinearGradient(0, -60, 0, APRON_Y)
    g.add_color_stop_rgba(0, *rgb('#1c1430')); g.add_color_stop_rgba(1, *rgb('#2c2150'))
    poly(ap, True); cr.set_source(g); cr.fill()
fill([(DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, DRAIN_Y), (MIRROR - DRAIN_X, -60), (DRAIN_X, -60)], rgb('#050508'))
# title card on the left apron, a grey peeking over the right
text("GREY", (135, 52), 28, rgb('#cfd3dc'), weight=cairo.FONT_WEIGHT_BOLD, glow=rgb('#58f08a'))
text("INVASION", (135, 22), 17, rgb('#58f08a'), glow=rgb('#58f08a'))
text("SHOOT THE HANGAR TO START A WAVE", (135, -8), 5.6, rgb('#b9b2d6'))
text("LOCK 3 IN THE ABDUCTION SCOOP", (135, -20), 5.6, rgb('#b9b2d6'))


def grey_alien(c, s=1.0, wave=False, surprised=False):
    """A goofy classic grey: big head, almond eyes, thin neck."""
    cr.save(); cr.translate(*c); cr.scale(s, s)
    if wave:
        stroke([(-9, -20), (-24, -2)], rgb('#a7b0b9'), 3.5); circle((-25, 0), 3.5, rgb('#a7b0b9'))
    stroke([(0, -10), (0, -16)], rgb('#9aa3ad'), 5)
    poly([(-9, -16), (9, -16), (11, -40), (-11, -40)], True); cr.set_source_rgba(*rgb('#9aa3ad')); cr.fill()
    stroke([(9, -20), (20, -34)], rgb('#a7b0b9'), 3.5)
    stroke([(-6, -40), (-8, -56)], rgb('#9aa3ad'), 4); stroke([(6, -40), (8, -56)], rgb('#9aa3ad'), 4)
    cr.save(); cr.scale(1, 1)
    poly([(-22, 6), (-24, 22), (-14, 38), (0, 42), (14, 38), (24, 22), (22, 6), (12, -8), (0, -12), (-12, -8)], True)
    cr.set_source(radial((-6, 26), 2, 40, [(0, rgb('#d4dbe2')), (1, rgb('#8e98a3'))])); cr.fill()
    cr.restore()
    for sx in (-1, 1):
        cr.save(); cr.translate(sx * 10, 14); cr.rotate(sx * 0.45); cr.scale(9, 5.2)
        cr.new_sub_path(); cr.arc(0, 0, 1, 0, 2*math.pi); cr.restore(); cr.set_source_rgba(*rgb('#0c0c12')); cr.fill()
        circle((sx * 8 + 2, 16), 1.8, rgb('#ffffff', 0.9))
    if surprised: circle((0, -1), 3, rgb('#3a3f46'))
    else: stroke([(-4, -1), (0, -3), (4, -1)], rgb('#3a3f46'), 1.4)
    cr.restore()


grey_alien((420, 70), 0.95, wave=True)
text("WE COME IN PEACE*", (500, 40), 5.2, rgb('#b9b2d6'))
text("*FOR YOUR COWS", (500, 30), 4.4, rgb('#8d86ad'))

# ------------------------------------------------------------------ lamp inserts (some lit, as mid-game)
def arrow_lamp(cx, cy, ang, col, lit):
    a = math.radians(ang); ca, sa = math.cos(a), math.sin(a)
    pts = [(12, 0), (-12, 9), (-6, 0), (-12, -9)]
    P = [(cx + x*ca - y*sa, cy + x*sa + y*ca) for x, y in pts]
    if lit:
        cr.set_source(radial((cx, cy), 2, 26, [(0, (*col[:3], 0.55)), (1, (*col[:3], 0))])); cr.new_sub_path(); cr.arc(cx, cy, 26, 0, 7); cr.fill()
    fill(P, (*col[:3], 0.95 if lit else 0.22)); stroke(P, (*col[:3], 0.8), 1, close=True)


ARROWS = [(336.3, 532.0, 70.8, '#58f08a', True), (248.0, 530.8, 106.2, '#58f08a', False),
          (121.4, 722.7, 113.8, '#40e6d6', True), (284.0, 692.0, 90.0, '#ff8c40', True),
          (444.3, 650.3, 62.7, '#ff8c40', False), (411.1, 493.2, 54.3, '#ff5a4d', False)]
for x, y, a, c, lit in ARROWS: arrow_lamp(x, y, a, rgb(c), lit)
for i, p in enumerate([(239, 455), (269, 455), (299, 455), (329, 455)]):
    lit = i < 1
    if lit: cr.set_source(radial(p, 2, 20, [(0, rgb('#4d9bff', 0.6)), (1, rgb('#4d9bff', 0))])); cr.new_sub_path(); cr.arc(p[0], p[1], 20, 0, 7); cr.fill()
    circle(p, 9, rgb('#4d9bff', 0.95 if lit else 0.25), line=rgb('#4d9bff', 0.8))
text("EARTH DEFENSE", (284, 472), 5.5, rgb('#9cc4ff'))
for i in range(10):
    p = (284 + (i - 4.5) * 16, 410); lit = i < 4
    circle(p, 5, rgb('#ffd84d', 0.95 if lit else 0.22), line=rgb('#ffd84d', 0.7))
text("SHIPS DOWN", (284, 396), 5.0, rgb('#ffe58a'))
cr.set_source(radial((284, 300), 2, 34, [(0, rgb('#b673ff', 0.5)), (1, rgb('#b673ff', 0))])); cr.new_sub_path(); cr.arc(284, 300, 34, 0, 7); cr.fill()
fill([(262, 293), (306, 293), (306, 307), (262, 307)], rgb('#b673ff', 0.95))
text("SHIELDS UP", (284, 300), 5.4, rgb('#2a1048'))
fill([(23, 250), (51, 250), (51, 260), (23, 260)], rgb('#ff8c40', 0.95))
fill([(517, 250), (545, 250), (545, 260), (517, 260)], rgb('#40e6d6', 0.3))
circle((312, 760), 6, rgb('#ff5a4d', 0.3), line=rgb('#ff5a4d', 0.8))
for i, p in enumerate([(452, 738), (470, 738), (488, 738)]):
    circle(p, 5, rgb('#58f08a', 0.95 if i < 1 else 0.25), line=rgb('#58f08a', 0.8))

# ------------------------------------------------------------------ scoops
def scoop(c, label, glow):
    cr.set_source(radial(c, 4, 34, [(0, (*glow[:3], 0.55)), (1, (*glow[:3], 0))])); cr.new_sub_path(); cr.arc(c[0], c[1], 34, 0, 7); cr.fill()
    circle(c, 17, rgb('#1a1a22'), line=rgb('#c9ccd6'), lw=2.5)
    circle(c, 11, rgb('#050507'))
    text(label, (c[0], c[1] + 26), 6, rgb('#e9e6f5'), glow=glow)


# Hangar: hazard stripes around a dark door
cr.save(); cr.new_sub_path(); cr.arc(HANGAR[0], HANGAR[1], 21, 0, 7); cr.set_line_width(5)
cr.set_dash([4, 4]); cr.set_source_rgba(*rgb('#f2c230')); cr.stroke(); cr.set_dash([]); cr.restore()
scoop(HANGAR, "HANGAR", rgb('#ff8c40'))
scoop(ABDUCT, "ABDUCTION", rgb('#58f08a'))

# ------------------------------------------------------------------ ramps (plastic) and wires
def draw_ramp(q, apex, L, Rr):
    pi = [i for i in range(len(q.s)) if q.s[i] <= apex + 4]
    band = [L[i] for i in pi] + [Rr[i] for i in reversed(pi)]
    poly(band, True); cr.set_source_rgba(*rgb('#3cff7a', 0.20)); cr.fill()
    for rail in (L, Rr):
        stroke([rail[i] for i in pi], rgb('#bfffd2', 0.85), 2.4)
        stroke([rail[i] for i in pi], rgb('#ffffff', 0.5), 0.8)
    # ribs across the plastic
    for i in pi[::6]:
        stroke([L[i], Rr[i]], rgb('#bfffd2', 0.18), 1)
    wi = [i for i in range(len(q.s)) if q.s[i] >= apex]
    for rail in (L, Rr):
        stroke([rail[i] for i in wi], rgb('#6c7280'), 2.6)
        stroke([rail[i] for i in wi], rgb('#e7ebf2'), 1.2)


# ------------------------------------------------------------------ walls, guides, posts (chrome)
def rail(pts, w=5):
    stroke(pts, rgb('#3b3f52'), w + 2.5)
    stroke(pts, rgb('#c9ced8'), w)
    stroke(pts, rgb('#ffffff', 0.7), w * 0.35)


rail(outer, 5)
rail(right_apron, 5)
for ch in (left_guide, right_guide, left_out_wall, right_out_wall, orbit_inner, bank_back, bank_cap, upper_guide):
    rail(ch, 4)
# ramp mouth posts
for q, apex, L, Rr in ramps:
    idx = [i for i in range(len(q.s)) if q.s[i] <= 24]
    rail([L[i] for i in idx], 4); rail([Rr[i] for i in idx], 4)
# launch gate + diverter (orange one-way plastics)
stroke([(LANE_X, LANE_TOP), (RIGHT_X, LANE_TOP + 28)], rgb('#ff8c40'), 3.5)
stroke(DIV, rgb('#ff8c40', 0.55), 3.5)

# U-F-O lanes: chrome posts, lights and letters
for x in POSTS_X: rail([(x, 1130), (x, 1185)], 3.5)
for i, (cx, letter) in enumerate(zip(lane_cx, "UFO")):
    lit = i != 1
    if lit: cr.set_source(radial((cx, 1205), 1, 16, [(0, rgb('#58f08a', 0.6)), (1, rgb('#58f08a', 0))])); cr.new_sub_path(); cr.arc(cx, 1205, 16, 0, 7); cr.fill()
    circle((cx, 1205), 6, rgb('#58f08a', 0.95 if lit else 0.25))
    text(letter, (cx, 1160), 11, rgb('#e9fff0', 0.9 if lit else 0.35), glow=rgb('#58f08a') if lit else None)

# ------------------------------------------------------------------ slingshots (white plastic, orange rubber)
for s_ in (lsling, rsling):
    top, corner, tip = s_
    fill([top, corner, tip], rgb('#f3f1fb', 0.92))
    inset = [(top[0] + (corner[0] + tip[0] - 2*top[0]) * 0.12, top[1] + (corner[1] + tip[1] - 2*top[1]) * 0.12),
             (corner[0] + (top[0] + tip[0] - 2*corner[0]) * 0.18, corner[1] + (top[1] + tip[1] - 2*corner[1]) * 0.18),
             (tip[0] + (top[0] + corner[0] - 2*tip[0]) * 0.18, tip[1] + (top[1] + corner[1] - 2*tip[1]) * 0.18)]
    fill(inset, rgb('#58f08a', 0.35))
    stroke([tip, top], rgb('#ff7a2e'), 5)
    stroke([top, corner, tip], rgb('#2b2b2b'), 2.5)
    circle(top, 7, rgb('#d8dbe2'), line=rgb('#40434d'), lw=1.5)
    circle(tip, 6, rgb('#d8dbe2'), line=rgb('#40434d'), lw=1.5)
    # a tiny saucer decal on each sling plastic
    cxs = (top[0] + corner[0] + tip[0]) / 3; cys = (top[1] + corner[1] + tip[1]) / 3
    ellipse((cxs, cys), 9, 3.2, rgb('#7c8796')); ellipse((cxs, cys + 2.5), 4, 3, rgb('#9ff7ff', 0.9))

# ------------------------------------------------------------------ fighter bank (drop targets as little fighters)
for y in BANK_YS:
    fill([(BANK_X - 6, y - 12), (BANK_X + 6, y - 12), (BANK_X + 6, y + 12), (BANK_X - 6, y + 12)], rgb('#3a3f4e'))
    fill([(BANK_X - 6, y), (BANK_X + 2, y + 9), (BANK_X + 2, y - 9)], rgb('#ff5a4d'))
    circle((BANK_X - 1, y), 2.2, rgb('#9ff7ff'))
    stroke([(BANK_X - 6, y - 12), (BANK_X - 6, y + 12)], rgb('#ffb0a8'), 1.2)

# ------------------------------------------------------------------ saucer bumpers: hovering saucers with a grey in the dome
def saucer_bumper(c):
    x, y = c
    cr.set_source(radial(c, 20, 44, [(0, rgb('#ff6a3d', 0.35)), (1, rgb('#ff6a3d', 0))])); cr.new_sub_path(); cr.arc(x, y, 44, 0, 7); cr.fill()
    circle(c, 28, rgb('#707a88'), line=rgb('#2c3038'), lw=2)
    cr.set_source(radial((x - 8, y + 8), 2, 30, [(0, rgb('#d9dee6')), (1, rgb('#6c7684'))])); cr.new_sub_path(); cr.arc(x, y, 26, 0, 7); cr.fill()
    for k in range(12):                     # rim lights
        a = k * math.pi / 6
        circle((x + 22 * math.cos(a), y + 22 * math.sin(a)), 2.4, rgb('#ffd84d' if k % 2 else '#ff6a3d'))
    circle(c, 14, rgb('#a9f6ff', 0.55), line=rgb('#e6ffff', 0.9), lw=1.2)   # glass dome
    # the pilot: a tiny grey head with big eyes
    ellipse((x, y + 1), 7.5, 8.5, rgb('#b8c0c8'))
    for sx in (-1, 1):
        cr.save(); cr.translate(x + sx * 3.4, y + 3.6); cr.rotate(sx * 0.5); cr.scale(3.4, 2.0)
        cr.new_sub_path(); cr.arc(0, 0, 1, 0, 2*math.pi); cr.restore(); cr.set_source_rgba(*rgb('#0c0c12')); cr.fill()
    ellipse((x - 4, y + 9), 3, 1.6, rgb('#ffffff', 0.7))


for b in BUMPERS: saucer_bumper(b)

# ------------------------------------------------------------------ flippers (white with red rubber), upper flipper
def flipper(piv, sgn, length=96, r0=12, r1=6, raised=0.0):
    rot = -sgn * REST + sgn * raised; ca, sa = math.cos(rot), math.sin(rot)
    shape = [(r0*math.cos(math.pi/2 + k*math.pi/24), r0*math.sin(math.pi/2 + k*math.pi/24)) for k in range(25)]
    shape += [(length + r1*math.cos(-math.pi/2 + k*math.pi/24), r1*math.sin(-math.pi/2 + k*math.pi/24)) for k in range(25)]
    P = [(piv[0] + sgn*x*ca - y*sa, piv[1] + sgn*x*sa + y*ca) for x, y in shape]
    fill(P, rgb('#f6f6fa')); stroke(P, rgb('#e2342b'), 2.6, close=True)
    circle(piv, 4, rgb('#9aa0ad'))


flipper(LP, 1); flipper(RP, -1, raised=math.radians(40))
flipper(UPPER_P, -1, 64, 10, 5)

# ------------------------------------------------------------------ ramps on top of the floor art
for q, apex, L, Rr in ramps: draw_ramp(q, apex, L, Rr)
text("TRACTOR BEAM", (420, 760), 6.5, rgb('#d8ffe4'), glow=rgb('#3cff7a'), angle=math.radians(70.9))
text("DEFENSE CANNON", (172, 770), 6.5, rgb('#d8ffe4'), glow=rgb('#3cff7a'), angle=math.radians(109.1 - 180))

# ------------------------------------------------------------------ invaders: mothership, scouts, abductor
# Mothership hovering over the top of the table, with rim lights and an open core
MS = (284, 1238)
cr.set_source(radial(MS, 30, 160, [(0, rgb('#58f08a', 0.25)), (1, rgb('#58f08a', 0))])); cr.new_sub_path(); cr.arc(MS[0], MS[1], 160, 0, 7); cr.fill()
ellipse(MS, 128, 26, rgb('#3e4553'))
g = cairo.LinearGradient(0, MS[1] - 26, 0, MS[1] + 26)
g.add_color_stop_rgba(0, *rgb('#59606f')); g.add_color_stop_rgba(1, *rgb('#c3c9d4'))
ellipse((MS[0], MS[1] + 4), 120, 20, src=g)
ellipse((MS[0], MS[1] + 18), 46, 18, rgb('#9ff7ff', 0.55))
for k in range(17):
    x = MS[0] - 112 + k * 14
    circle((x, MS[1] - 2 - 6 * math.sin(k / 16 * math.pi)), 2.6, rgb('#ffd84d' if k % 3 else '#58f08a'))
circle((MS[0], MS[1] - 12), 8, rgb('#58f08a', 0.9), line=rgb('#eafff0'), lw=1.5)
text("CORE", (MS[0], MS[1] - 12), 3.5, rgb('#0b2a14'))


def scout(c, s=1.0, tilt=0.0):
    cr.save(); cr.translate(*c); cr.rotate(tilt); cr.scale(s, s)
    cr.set_source(radial((0, 0), 2, 26, [(0, rgb('#9ff7ff', 0.35)), (1, rgb('#9ff7ff', 0))])); cr.new_sub_path(); cr.arc(0, 0, 26, 0, 7); cr.fill()
    ellipse((0, 0), 18, 5.5, rgb('#8a94a3')); ellipse((0, 1), 16, 3.5, rgb('#c8ced8'))
    ellipse((0, 4), 7, 5.5, rgb('#9ff7ff', 0.85))
    ellipse((0, 4), 3, 3.4, rgb('#b8c0c8'))
    for k in (-12, -6, 0, 6, 12): circle((k, -1.5), 1.3, rgb('#ffd84d'))
    cr.restore()


scout((96, 790), 1.0, 0.15)            # over the orbit (lit)
scout((326, 820), 0.9, -0.1)           # near the Hangar (lit)
scout((300, 560), 0.85, 0.08)          # over the right ramp's arrow (lit)
# abductor beaming a cow up out of the Abduction scoop
AB = (486, 822)
beam = [(AB[0] - 8, AB[1] - 4), (AB[0] + 8, AB[1] - 4), (ABDUCT[0] + 30, ABDUCT[1] - 6), (ABDUCT[0] - 30, ABDUCT[1] - 6)]
g = cairo.LinearGradient(0, ABDUCT[1], 0, AB[1])
g.add_color_stop_rgba(0, *rgb('#eaffd8', 0.05)); g.add_color_stop_rgba(1, *rgb('#eaffd8', 0.45))
poly(beam, True); cr.set_source(g); cr.fill()
cow((ABDUCT[0] - 3, ABDUCT[1] + 52), 0.55, -1, look_up=True)
scout(AB, 1.25, 0.05)

# ------------------------------------------------------------------ ball (shaded steel) with a shadow, on the left flipper
B = (225, 214)
ellipse((B[0] + 4, B[1] - 4), 10, 8, rgb('#000000', 0.35))
cr.set_source(radial((B[0] - 3, B[1] + 3), 1, 11, [(0, rgb('#ffffff')), (0.45, rgb('#c3c8d2')), (1, rgb('#4d5260'))]))
cr.new_sub_path(); cr.arc(B[0], B[1], R, 0, 7); cr.fill()
# a second ball on the Tractor Beam wire, slightly bigger (ramp layer)
B2 = ramps[0][0].pts[60]
ellipse((B2[0] + 6, B2[1] - 6), 10, 8, rgb('#000000', 0.3))
cr.set_source(radial((B2[0] - 3, B2[1] + 3), 1, 12, [(0, rgb('#ffffff')), (0.45, rgb('#c3c8d2')), (1, rgb('#4d5260'))]))
cr.new_sub_path(); cr.arc(B2[0], B2[1], R * 1.08, 0, 7); cr.fill()

# plunger + lane
fill([(552, 70), (576, 70), (576, 120), (552, 120)], rgb('#c9ced8'))
fill([(552, 112), (576, 112), (576, 120), (552, 120)], rgb('#e2342b'))

surf.write_to_png("/home/claude/gi-src/tools/concept_m8.png")
print("wrote concept_m8.png", WPX, HPX)
