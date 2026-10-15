"""M8 art round 3: saucer bumper (bumper.png) and fighter drop target (fighter.png), from the concept.
Drawn in y-up world units (like the concept) at K px per point."""
import cairo, math

def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)

def canvas(w_pt, h_pt, K):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(w_pt*K), int(h_pt*K)); c = cairo.Context(s)
    c.translate(w_pt*K/2, h_pt*K/2); c.scale(K, -K); return s, c

def circle(c, p, r, col, line=None, lw=1):
    c.new_sub_path(); c.arc(p[0], p[1], r, 0, 2*math.pi); c.set_source_rgba(*col)
    if line: c.fill_preserve(); c.set_source_rgba(*line); c.set_line_width(lw); c.stroke()
    else: c.fill()

def ellipse(c, p, rx, ry, col):
    c.save(); c.translate(*p); c.scale(rx, ry); c.new_sub_path(); c.arc(0, 0, 1, 0, 2*math.pi); c.restore()
    c.set_source_rgba(*col); c.fill()

# ---- saucer bumper: 60 x 60 pt sprite for an r 28 bumper
K = 4
s, c = canvas(60, 60, K)
circle(c, (0, 0), 28, rgb('#707a88'), line=rgb('#2c3038'), lw=2)
g = cairo.RadialGradient(-8, 8, 2, 0, 0, 30)
g.add_color_stop_rgba(0, *rgb('#d9dee6')); g.add_color_stop_rgba(1, *rgb('#6c7684'))
c.new_sub_path(); c.arc(0, 0, 26, 0, 7); c.set_source(g); c.fill()
for k in range(12):
    a = k * math.pi / 6
    circle(c, (22*math.cos(a), 22*math.sin(a)), 2.4, rgb('#ffd84d' if k % 2 else '#ff6a3d'))
circle(c, (0, 0), 14, rgb('#a9f6ff', 0.55), line=rgb('#e6ffff', 0.9), lw=1.2)
ellipse(c, (0, 1), 7.5, 8.5, rgb('#b8c0c8'))
for sx in (-1, 1):
    c.save(); c.translate(sx*3.4, 3.6); c.rotate(sx*0.5); c.scale(3.4, 2.0)
    c.new_sub_path(); c.arc(0, 0, 1, 0, 2*math.pi); c.restore(); c.set_source_rgba(*rgb('#0c0c12')); c.fill()
ellipse(c, (-4, 9), 3, 1.6, rgb('#ffffff', 0.7))
s.write_to_png("bumper.png")

# ---- fighter drop target: 12 x 24 pt, the face (hit side) on the LEFT
K = 4
s, c = canvas(12, 24, K)
c.rectangle(-6, -12, 12, 24); c.set_source_rgba(*rgb('#3a3f4e')); c.fill()
c.move_to(-6, 0); c.line_to(2, 9); c.line_to(2, -9); c.close_path(); c.set_source_rgba(*rgb('#ff5a4d')); c.fill()
for y in (7, -7):                                     # little wing stripes
    c.rectangle(2, y - 1, 3, 2); c.set_source_rgba(*rgb('#ffb0a8')); c.fill()
circle(c, (-1, 0), 2.2, rgb('#9ff7ff'))
c.move_to(-6, -12); c.line_to(-6, 12); c.set_source_rgba(*rgb('#ffb0a8')); c.set_line_width(1.2); c.stroke()
c.rectangle(-6, -12, 12, 24); c.set_source_rgba(*rgb('#16181f')); c.set_line_width(0.8); c.stroke()
s.write_to_png("fighter.png")
print("ok")
