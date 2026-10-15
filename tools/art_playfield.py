"""Milestone 8 art round 1: the baked playfield background (scenery, apron, cabinet,
labels and every FIXED rail). Everything that moves, lights or kicks is drawn in code.
Based on the round 0 concept for Grey Invasion Pinball, drawn on the real table
geometry (mirrors TableLayout.swift as of M7 v11). Night farm, goofy grey aliens.
Output: concept_m8.png (full table, Top-Down view, with the cabinet around it)."""
import math, random
import cairo

random.seed(7)
S = 2.9                                  # pixels per world point (keeps the image under 4096 px tall)
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
HANGAR, ABDUCT = (284, 650), (470, 700)   # Hangar moved down from 760 (M10 v16, Shot Lab)
BANK_X, BANK_YS = 464, [595, 565, 535, 505]
bank_back, bank_cap = [(476, 487), (476, 621)], [(476, 621), (454, 613)]
UPPER_P = (528, 800)
_full = (UPPER_P[0] - 11 * math.sin(REST), UPPER_P[1] + 11 * math.cos(REST))
_wall = (LANE_X, _full[1] + (LANE_X - _full[0]) * math.tan(REST))
upper_guide = [_wall, (_full[0] + (_wall[0] - _full[0]) * 0.33, _full[1] + (_wall[1] - _full[1]) * 0.33)]


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
cow((296, 770), 0.75, 1, look_up=True)   # moved from (330,655) when the Hangar came down (M10 v16)
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

# ------------------------------------------------------------------ printed labels beside the lamps
# M10 v5: EARTH DEFENSE, SHIPS DOWN, SHIELDS UP, KICKBACK, SAVE and LOCKS are live labels now
# (TableLabels.swift) that grow with the camera zoom so they stay readable in Top-Down.

# ------------------------------------------------------------------ scoop surrounds + labels (scoops are drawn in code)
cr.save(); cr.new_sub_path(); cr.arc(HANGAR[0], HANGAR[1], 21, 0, 7); cr.set_line_width(5)
cr.set_dash([4, 4]); cr.set_source_rgba(*rgb('#f2c230')); cr.stroke(); cr.set_dash([]); cr.restore()
for c, _label, glow in [(HANGAR, "HANGAR", rgb('#ff8c40')), (ABDUCT, "ABDUCTION", rgb('#58f08a'))]:
    cr.set_source(radial(c, 4, 34, [(0, (*glow[:3], 0.45)), (1, (*glow[:3], 0))])); cr.new_sub_path(); cr.arc(c[0], c[1], 34, 0, 7); cr.fill()
    # (the HANGAR / ABDUCTION names are live labels too, M10 v5)

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

# U-F-O lanes: chrome posts, lights and letters
for x in POSTS_X: rail([(x, 1130), (x, 1185)], 3.5)
for i, (cx, letter) in enumerate(zip(lane_cx, "UFO")):
    text(letter, (cx, 1160), 11, rgb('#e9fff0', 0.55), glow=rgb('#58f08a'))

surf.write_to_png("/home/claude/gi-src/tools/playfield.png")
print("wrote playfield.png", WPX, HPX, "world", X0, Y0, X1, Y1)
