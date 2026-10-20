# Table 05 M9 round 2: the upper table's floor painting. Exec'd by lmp_floor_table.py (shares cr, rnd, poly, rgb, L).
# Everything here is printed on the floor; the walls, rails and raised parts are modelled in lmp_bake_table.py.

# ---- orbit lanes: a darker walnut-stained runner down each lane (the ball's path reads at a glance)
def stroke_path(pts, width, col, a=1.0):
    cr.move_to(*pts[0])
    for p in pts[1:]:
        cr.line_to(*p)
    rgb(col, a); cr.set_line_width(width); cr.set_line_cap(cairo.LINE_CAP_BUTT); cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.stroke()


lane_mid = [(L.LEFT_X + 21, L.LEFT_ORBIT_MOUTH_Y - 40)] + L.arch_offset(21, 1000)
right_arm = [(x, y) for x, y in lane_mid if x > L.WORLD_W / 2]
stroke_path([p for p in lane_mid if p[0] <= L.WORLD_W / 2 + 1], 40, (0.30, 0.16, 0.07), 0.55)
# the right lane: between the inner wall (x 506) and the lane wall (548) up to the arch
stroke_path([(527, L.RIGHT_ORBIT_MOUTH_Y - 30), (527, L.ARCH_START_Y)] +
            L.quad((527, L.ARCH_START_Y), (527, L.TOP_Y - 21), (L.WORLD_W / 2, L.TOP_Y - 21), 24), 40,
            (0.30, 0.16, 0.07), 0.55)
# brass inlay line down the middle of each runner
stroke_path([p for p in lane_mid if p[0] <= L.WORLD_W / 2 + 1], 1.0, (0.86, 0.66, 0.30), 0.55)
stroke_path([(527, L.RIGHT_ORBIT_MOUTH_Y - 30), (527, L.ARCH_START_Y)] +
            L.quad((527, L.ARCH_START_Y), (527, L.TOP_Y - 21), (L.WORLD_W / 2, L.TOP_Y - 21), 24), 1.0,
            (0.86, 0.66, 0.30), 0.55)

# ---- stone hearth in front of the fireplace
HX0, HX1, HY0, HY1 = L.ALCOVE_LEFT_X - 18, L.ALCOVE_RIGHT_X + 18, L.ALCOVE_BOTTOM_Y - 26, L.ALCOVE_BOTTOM_Y
for i in range(5):
    rgb((0.10, 0.05, 0.02), 0.08); cr.rectangle(HX0 - 2 + i * 0.4, HY0 - 3 + i * 0.4, HX1 - HX0 + 4 - i * 0.8, HY1 - HY0 + 3); cr.fill()
x = HX0
while x < HX1 - 1:
    wdt = min(rnd.uniform(18, 30), HX1 - x)
    s_ = rnd.uniform(0.42, 0.52)
    rgb((s_, s_ * 0.93, s_ * 0.85)); cr.rectangle(x + 0.6, HY0 + 0.6, wdt - 1.2, HY1 - HY0 - 1.2); cr.fill()
    x += wdt

# ---- the firebox: sooty brick inside the alcove, the fire on its floor at the front by the hearth (M9 v3, Aaron:
# "the fire is at the top of the fireplace ... it reads as upside down"), the brick darkening with soot toward the back
alcove_poly = L.alcove_wall()
cr.save(); poly(alcove_poly); cr.clip()
rgb((0.10, 0.05, 0.03)); cr.paint()
for row in range(12):
    yy = L.ALCOVE_BOTTOM_Y + row * 12
    off = 10 if row % 2 else 0
    for col in range(-1, 8):
        xx = L.ALCOVE_LEFT_X - 10 + col * 20 + off
        t = (yy - L.ALCOVE_BOTTOM_Y) / 140
        r_ = rnd.uniform(0.20, 0.30) * (1 - 0.55 * t)
        rgb((r_, r_ * 0.45, r_ * 0.30)); cr.rectangle(xx + 0.8, yy + 0.8, 18.4, 10.4); cr.fill()
# soot darkening upward
g = cairo.LinearGradient(0, L.ALCOVE_BOTTOM_Y, 0, L.ALCOVE_TOP_Y + L.ALCOVE_ROOF_PEAK)
g.add_color_stop_rgba(0, 0, 0, 0, 0.0); g.add_color_stop_rgba(1, 0, 0, 0, 0.75)
cr.set_source(g); cr.paint()
# ember glow from the fire at the front of the firebox, just inside the mouth
gx, gy = L.FIREPLACE_CENTER[0], L.ALCOVE_BOTTOM_Y + 30
g = cairo.RadialGradient(gx, gy, 0, gx, gy, 62)
g.add_color_stop_rgba(0, 1.0, 0.55, 0.15, 0.85); g.add_color_stop_rgba(0.5, 0.85, 0.25, 0.05, 0.35)
g.add_color_stop_rgba(1, 0.4, 0.08, 0.0, 0.0)
cr.set_source(g); cr.paint()
# an iron grate under the logs
rgb((0.05, 0.04, 0.04)); cr.set_line_width(2.2)
cr.move_to(246, 757); cr.line_to(322, 757); cr.stroke()
for bx in range(250, 322, 9):
    cr.move_to(bx, 755); cr.line_to(bx, 781); cr.stroke()
for (lx0, ly0, lx1, ly1) in ((250, 762, 318, 776), (256, 776, 314, 764)):      # two crossed logs on the grate
    rgb((0.24, 0.13, 0.06)); cr.set_line_width(9); cr.set_line_cap(cairo.LINE_CAP_ROUND)
    cr.move_to(lx0, ly0); cr.line_to(lx1, ly1); cr.stroke()
    rgb((1.0, 0.45, 0.12), 0.7); cr.set_line_width(2)
    cr.move_to(lx0 + 3, ly0 - 3); cr.line_to(lx1 - 3, ly1 - 3); cr.stroke()
for i in range(70):                                                              # embers
    ex, ey = rnd.uniform(244, 324), rnd.uniform(752, 788)
    rgb((1.0, rnd.uniform(0.4, 0.75), 0.1), rnd.uniform(0.5, 1.0)); cr.arc(ex, ey, rnd.uniform(0.6, 1.6), 0, 6.29); cr.fill()
# a few flame tongues licking up from the logs toward the back
for fx in (262, 274, 286, 298, 308):
    h_ = rnd.uniform(14, 24)
    g = cairo.LinearGradient(0, 772, 0, 772 + h_)
    g.add_color_stop_rgba(0, 1.0, 0.78, 0.30, 0.9); g.add_color_stop_rgba(1, 1.0, 0.35, 0.05, 0.0)
    cr.set_source(g)
    cr.move_to(fx - 5, 772); cr.curve_to(fx - 6, 772 + h_ * 0.5, fx + 2, 772 + h_ * 0.7, fx, 772 + h_)
    cr.curve_to(fx + 4, 772 + h_ * 0.6, fx + 6, 772 + h_ * 0.4, fx + 5, 772); cr.close_path(); cr.fill()
cr.restore()

# ---- kettle lane: cream and teal kitchen tiles up the lane, an iron stove ring round the hole
ax_ = L.kettle_axis()
lane_poly = [L.kettle_point(-L.KETTLE_LEN - 10, L.KETTLE_HALF_W), L.kettle_point(L.KETTLE_HALF_W, L.KETTLE_HALF_W),
             L.kettle_point(L.KETTLE_HALF_W, -L.KETTLE_HALF_W), L.kettle_point(-L.KETTLE_LEN - 10, -L.KETTLE_HALF_W)]
cr.save(); poly(lane_poly); cr.clip()
ang = math.atan2(ax_[1], ax_[0])
cr.translate(*L.KETTLE_END); cr.rotate(ang)
T = 9.0
for i in range(-20, 6):
    for j in range(-5, 6):
        rgb((0.88, 0.84, 0.74) if (i + j) % 2 else (0.20, 0.42, 0.40))
        cr.rectangle(i * T, j * T - T / 2, T - 0.5, T - 0.5); cr.fill()
cr.restore()
kx, ky = L.KETTLE_CENTER
for r_, c_ in ((L.SCOOP_R + 7, (0.10, 0.09, 0.09)), (L.SCOOP_R + 5, (0.28, 0.27, 0.27)), (L.SCOOP_R + 2.5, (0.12, 0.11, 0.11))):
    rgb(c_); cr.arc(kx, ky, r_, 0, 2 * math.pi); cr.fill()
for i in range(8):                                                                # the ring's spokes
    a = i * math.pi / 4
    rgb((0.30, 0.29, 0.29)); cr.set_line_width(1.6)
    cr.move_to(kx + (L.SCOOP_R + 2.5) * math.cos(a), ky + (L.SCOOP_R + 2.5) * math.sin(a))
    cr.line_to(kx + (L.SCOOP_R + 7) * math.cos(a), ky + (L.SCOOP_R + 7) * math.sin(a)); cr.stroke()

# ---- a braided rag rug under the teacup bumpers
bx, by = 318, 955
for i in range(5):
    rgb((0.10, 0.05, 0.02), 0.07); cr.arc(bx + 1, by - 2, 82 - i, 0, 2 * math.pi); cr.fill()
BRAIDS = [(0.62, 0.30, 0.16), (0.90, 0.82, 0.65), (0.25, 0.32, 0.45), (0.70, 0.54, 0.36), (0.50, 0.14, 0.09)]
r_ = 80
k = 0
while r_ > 4:
    rgb(BRAIDS[k % len(BRAIDS)]); cr.arc(bx, by, r_, 0, 2 * math.pi); cr.fill()
    # the braid's stitches
    n = int(r_ * 1.4)
    rgb((0, 0, 0), 0.12); cr.set_line_width(0.6)
    for s_ in range(n):
        a = s_ / n * 2 * math.pi
        cr.move_to(bx + (r_ - 0.5) * math.cos(a), by + (r_ - 0.5) * math.sin(a))
        cr.line_to(bx + (r_ - 4.5) * math.cos(a + 0.05), by + (r_ - 4.5) * math.sin(a + 0.05)); cr.stroke()
    r_ -= 5; k += 1

# ---- brass letter plate under the mail slot
mx, my = L.MAIL_SLOT_CENTER
rgb((0.10, 0.05, 0.02), 0.25); cr.rectangle(mx - 21, my - 15, 44, 30); cr.fill()
g = cairo.LinearGradient(mx - 20, my + 13, mx + 20, my - 13)
g.add_color_stop_rgb(0, 0.95, 0.78, 0.42); g.add_color_stop_rgb(0.5, 0.74, 0.54, 0.24); g.add_color_stop_rgb(1, 0.92, 0.72, 0.36)
cr.set_source(g); cr.rectangle(mx - 20, my - 13, 40, 26); cr.fill()
rgb((0.45, 0.30, 0.12)); cr.set_line_width(0.8); cr.rectangle(mx - 18, my - 11, 36, 22); cr.stroke()
for sx, sy in ((-16, 9), (16, 9), (-16, -9), (16, -9)):
    rgb((0.40, 0.27, 0.10)); cr.arc(mx + sx, my + sy, 1.1, 0, 6.29); cr.fill()

# ---- the loft: a sage window-nook rug over the loft (block and floor), a rainy window at the top left
loft_area = L.loft_platform()                     # M9 v3: the raised platform's top
cr.save(); poly(loft_area); cr.clip()
# M9 v32 (loft round 3): the loft has its own floor: warm boards running across (the shop's run up the table), a
# smaller sage rug in the middle with a gold border, and the pool of light from the lamp hanging over it.
rnd_l = random.Random(31)
yb = 940.0
while yb < 1240:
    xb = 50 - rnd_l.uniform(0, 80)
    while xb < 270:
        ln_ = rnd_l.uniform(60, 130)
        c_ = rnd_l.choice([(0.33, 0.19, 0.10), (0.36, 0.21, 0.11), (0.31, 0.18, 0.09), (0.38, 0.22, 0.12)])   # darker than the shop's oak
        rgb(c_); cr.rectangle(xb, yb, ln_, 9); cr.fill()
        rgb((0.22, 0.12, 0.05), 0.5); cr.set_line_width(0.6); cr.move_to(xb, yb); cr.line_to(xb, yb + 9); cr.stroke()
        xb += ln_
    rgb((0.22, 0.12, 0.05), 0.55); cr.set_line_width(0.7); cr.move_to(40, yb); cr.line_to(270, yb); cr.stroke()
    yb += 9
RX0, RY0, RX1, RY1 = 128.0, 1012.0, 238.0, 1172.0
def rug_path(i):
    r = 6
    cr.new_sub_path()
    cr.arc(RX1 - r - i, RY1 - r - i, r, 0, math.pi / 2); cr.arc(RX0 + r + i, RY1 - r - i, r, math.pi / 2, math.pi)
    cr.arc(RX0 + r + i, RY0 + r + i, r, math.pi, 1.5 * math.pi); cr.arc(RX1 - r - i, RY0 + r + i, r, 1.5 * math.pi, 2 * math.pi)
    cr.close_path()
rug_path(-1.5); rgb((0.10, 0.05, 0.02), 0.35); cr.fill()                        # its edge shadow
rug_path(0); rgb((0.36, 0.42, 0.33)); cr.fill()
cr.save(); rug_path(0); cr.clip()
for i in range(-60, 60):                          # a woven twill: fine diagonal threads
    rgb((0.30, 0.36, 0.27) if i % 2 else (0.42, 0.48, 0.38), 0.6); cr.set_line_width(1.2)
    cr.move_to(40 + i * 4, 950); cr.line_to(40 + i * 4 + 300, 1250); cr.stroke()
cr.restore()
rug_path(7); rgb((0.80, 0.62, 0.30), 0.85); cr.set_line_width(1.4); cr.stroke()   # gold border
# M9 v33: the wall sconces' pools of light (the hanging lamp is gone): warm, falling into the loft from the curved wall
_ol = L.loft_outline()
for yy in L.LOFT_SCONCE_YS:
    i = min(range(len(_ol)), key=lambda j: abs(_ol[j][1] - yy))
    p, q, o_ = _ol[i], _ol[min(i + 1, len(_ol) - 1)], _ol[max(i - 1, 0)]
    tx, ty = q[0] - o_[0], q[1] - o_[1]; ln = math.hypot(tx, ty) or 1
    cx_l, cy_l = p[0] + ty / ln * 16, p[1] - tx / ln * 16
    g = cairo.RadialGradient(cx_l, cy_l, 0, cx_l, cy_l, 38)
    g.add_color_stop_rgba(0, 1.0, 0.76, 0.40, 0.40); g.add_color_stop_rgba(1, 1.0, 0.76, 0.40, 0.0)
    cr.set_source(g); cr.paint()
cr.restore()
# M9 v5 (Aaron: the window ran into the loft's outer rail, the cushion too): the window is in the loft's wall, so what
# shows on the floor is its light - a cool pool of rainy night light with the glazing bars' shadow and rain-streak
# shadows, falling from the wall into the loft, clipped to the loft. The cushion lies along the wall under it.
wall = (0.37, 0.93)                                   # the loft's wall direction at the window seat (up the curve)
inward = (0.93, -0.37)                                # into the loft
cx_, cy_ = L.WINDOW_SEAT_CENTER
ang = math.atan2(wall[1], wall[0])
cr.save(); poly(loft_area); cr.clip()
ox, oy = cx_ + wall[0] * 34 - inward[0] * 22, cy_ + wall[1] * 34 - inward[1] * 22    # where the pool meets the wall
cr.translate(ox, oy); cr.rotate(ang)                  # x along the wall, y into the loft (negative side = inward)
def pool_path(grow):
    cr.move_to(-26 - grow, 0); cr.line_to(26 + grow, 0); cr.line_to(34 + grow, -58 - grow); cr.line_to(-14 - grow, -58 - grow)
    cr.close_path()
for grow, a in ((6, 0.05), (3, 0.07), (0, 0.12)):
    pool_path(grow); cr.set_source_rgba(0.70, 0.80, 1.0, a); cr.fill()
cr.set_source_rgba(0.04, 0.06, 0.10, 0.22); cr.set_line_width(3.0)        # glazing bars' shadow: a cross
cr.move_to(4, -2); cr.line_to(10, -56); cr.stroke()
cr.move_to(-22, -27); cr.line_to(30, -27); cr.stroke()
for i in range(26):                                                          # rain streaks running down the light
    rx_, ry_ = rnd.uniform(-20, 28), rnd.uniform(-54, -6)
    cr.set_source_rgba(0.10, 0.14, 0.22, rnd.uniform(0.10, 0.22)); cr.set_line_width(0.6)
    cr.move_to(rx_, ry_); cr.line_to(rx_ + 0.8, ry_ - rnd.uniform(4, 8)); cr.stroke()
cr.restore()
# a cushion along the wall under the window (the window seat), turned to follow the curve
def cushion(hw, hh, r, dx=0, dy=0):
    cr.save(); cr.translate(cx_ + dx, cy_ + dy); cr.rotate(ang)
    cr.new_sub_path()
    cr.arc(hw - r, hh - r, r, 0, math.pi / 2); cr.arc(-hw + r, hh - r, r, math.pi / 2, math.pi)
    cr.arc(-hw + r, -hh + r, r, math.pi, 1.5 * math.pi); cr.arc(hw - r, -hh + r, r, 1.5 * math.pi, 2 * math.pi)
    cr.close_path(); cr.restore()
# M9 v31 (loft round 2): the shade the raised loft throws on the shop floor beside it: a soft dark band down its
# right-hand side (the only floor next to it that isn't under the stairs).
g = cairo.LinearGradient(L.LOFT_RIGHT_X, 0, L.LOFT_RIGHT_X + 24, 0)
g.add_color_stop_rgba(0, 0.06, 0.03, 0.01, 0.55); g.add_color_stop_rgba(1, 0.06, 0.03, 0.01, 0.0)
cr.set_source(g); cr.rectangle(L.LOFT_RIGHT_X, L.LOFT_BOTTOM_Y, 24, 1226 - L.LOFT_BOTTOM_Y); cr.fill()
# M9 v30: no painted cushion under the hole any more: it's a wicker book basket now, and the bench is modelled along the
# wall above it (lmp_bake_table.py).

# ---- M9 v13: the four scoop holes, painted as real pits (the bake adds a ring round each). In the oblique view the
# far (upper) inside wall of a hole shows, so it gets a lit crescent; the near side falls into shadow.
def hole(cx, cy, r, wall_col):
    cr.save(); cr.arc(cx, cy, r, 0, 6.29); cr.clip()
    rgb((0.02, 0.015, 0.01)); cr.paint()
    g = cairo.LinearGradient(0, cy + r, 0, cy - r * 0.2)                          # the far wall, lit from above
    g.add_color_stop_rgba(0, *wall_col, 0.95); g.add_color_stop_rgba(1, *wall_col, 0.0)
    cr.set_source(g); cr.arc(cx, cy + r * 0.55, r * 0.95, 0, 6.29); cr.fill()
    g = cairo.RadialGradient(cx, cy - r * 0.25, 0, cx, cy - r * 0.25, r * 0.7)      # the dark bottom of the pit
    g.add_color_stop_rgba(0, 0, 0, 0, 0.9); g.add_color_stop_rgba(1, 0, 0, 0, 0.0)
    cr.set_source(g); cr.paint()
    cr.restore()
hole(*L.FIREPLACE_CENTER, L.SCOOP_R, (0.30, 0.12, 0.06))       # sooty brick inside
hole(*L.KETTLE_CENTER, L.SCOOP_R, (0.22, 0.20, 0.19))          # iron
hole(*L.MAIL_SLOT_CENTER, L.SCOOP_R * 0.8, (0.45, 0.33, 0.14))  # brass-lined
hole(*L.WINDOW_SEAT_CENTER, L.SCOOP_R, (0.55, 0.38, 0.18))     # M9 v30: into the wicker basket

# ---- the shooter lane above the gate area and the dark corners outside the arch are covered by the cabinet
