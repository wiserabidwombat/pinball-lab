"""M8 art round 4: invaders. scout.png (Wave 1 scouts and the Wave 3 abductor), cow.png,
beam.png (tractor beam), mothership.png. Drawn y-up in world points at K px per point."""
import cairo, math

def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)

def canvas(w, h, K):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(w*K), int(h*K)); c = cairo.Context(s)
    c.translate(w*K/2, h*K/2); c.scale(K, -K); return s, c

def circle(c, p, r, col, line=None, lw=1):
    c.new_sub_path(); c.arc(p[0], p[1], r, 0, 2*math.pi); c.set_source_rgba(*col)
    if line: c.fill_preserve(); c.set_source_rgba(*line); c.set_line_width(lw); c.stroke()
    else: c.fill()

def ellipse(c, p, rx, ry, col=None, src=None):
    c.save(); c.translate(*p); c.scale(rx, ry); c.new_sub_path(); c.arc(0, 0, 1, 0, 2*math.pi); c.restore()
    if src: c.set_source(src)
    else: c.set_source_rgba(*col)
    c.fill()

def glow(c, p, r, col):
    g = cairo.RadialGradient(p[0], p[1], 1, p[0], p[1], r)
    g.add_color_stop_rgba(0, *col[:3], col[3]); g.add_color_stop_rgba(1, *col[:3], 0)
    c.new_sub_path(); c.arc(p[0], p[1], r, 0, 7); c.set_source(g); c.fill()

# ---- scout saucer: 44 x 26 pt
s, c = canvas(44, 26, 5)
glow(c, (0, 0), 20, rgb('#9ff7ff', 0.35))
ellipse(c, (0, 0), 18, 5.5, rgb('#8a94a3')); ellipse(c, (0, 1), 16, 3.5, rgb('#c8ced8'))
ellipse(c, (0, 4), 7, 5.5, rgb('#9ff7ff', 0.85))
ellipse(c, (0, 4.5), 3, 3.4, rgb('#b8c0c8'))
for sx in (-1, 1):
    c.save(); c.translate(sx*1.3, 5.2); c.rotate(sx*0.5); c.scale(1.3, 0.75)
    c.new_sub_path(); c.arc(0, 0, 1, 0, 7); c.restore(); c.set_source_rgba(*rgb('#0c0c12')); c.fill()
for k in (-12, -6, 0, 6, 12): circle(c, (k, -1.5), 1.3, rgb('#ffd84d'))
s.write_to_png("scout.png")

# ---- cow (side view, facing right): 34 x 26 pt
s, c = canvas(34, 26, 5)
c.translate(-3, 2)
ellipse(c, (0, 0), 11, 6.5, rgb('#f4f1ea'))
ellipse(c, (-4, 1.5), 3.6, 3, rgb('#2b2b2b')); ellipse(c, (4.5, -2), 3, 2.2, rgb('#2b2b2b'))
for lx in (-7, -2.5, 3, 7.5):
    c.move_to(lx, -5); c.line_to(lx, -10.5); c.set_source_rgba(*rgb('#e8e4da')); c.set_line_width(2.2); c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke()
ellipse(c, (12, 4), 5.2, 4.5, rgb('#f4f1ea')); ellipse(c, (15.5, 2.6), 3, 2.4, rgb('#f2a7b5'))
circle(c, (11, 6.2), 1.05, rgb('#111111'))
for x0, x1 in ((9, 7.5), (12, 13.5)):
    c.move_to(x0, 8); c.line_to(x1, 11); c.set_source_rgba(*rgb('#cfc7b2')); c.set_line_width(1.2); c.stroke()
c.move_to(-11, 1.5); c.line_to(-14.5, -2.5); c.set_source_rgba(*rgb('#e8e4da')); c.set_line_width(1.1); c.stroke()
s.write_to_png("cow.png")

# ---- tractor beam: 64 x 128 pt trapezoid, narrow at the top, fading downward
s, c = canvas(64, 128, 3)
g = cairo.LinearGradient(0, -64, 0, 64)
g.add_color_stop_rgba(0, *rgb('#eaffd8', 0.05)); g.add_color_stop_rgba(1, *rgb('#eaffd8', 0.55))
c.move_to(-8, 64); c.line_to(8, 64); c.line_to(30, -64); c.line_to(-30, -64); c.close_path(); c.set_source(g); c.fill()
for k in range(-2, 3):                               # faint scan lines
    y = k * 24
    w = 8 + (64 - y) / 128 * 22
    c.move_to(-w, y); c.line_to(w, y); c.set_source_rgba(1, 1, 1, 0.12); c.set_line_width(1); c.stroke()
s.write_to_png("beam.png")

# ---- mothership: 300 x 110 pt (glow included); core light is a separate node in game
s, c = canvas(300, 110, 4)
c.save(); c.scale(1, 0.34); glow(c, (0, 0), 148, rgb('#58f08a', 0.25)); c.restore()   # oval glow, fits the canvas
ellipse(c, (0, 0), 128, 26, rgb('#3e4553'))
g = cairo.LinearGradient(0, -26, 0, 26)
g.add_color_stop_rgba(0, *rgb('#59606f')); g.add_color_stop_rgba(1, *rgb('#c3c9d4'))
ellipse(c, (0, 4), 120, 20, src=g)
ellipse(c, (0, 18), 46, 18, rgb('#9ff7ff', 0.55))
for sx in (-1, 1):                                   # a big goofy grey peering out of the dome
    pass
ellipse(c, (0, 22), 11, 12, rgb('#b8c0c8'))
for sx in (-1, 1):
    c.save(); c.translate(sx*5, 24); c.rotate(sx*0.5); c.scale(5, 2.9)
    c.new_sub_path(); c.arc(0, 0, 1, 0, 7); c.restore(); c.set_source_rgba(*rgb('#0c0c12')); c.fill()
for k in range(17):
    x = -112 + k * 14
    circle(c, (x, -2 - 6 * math.sin(k / 16 * math.pi)), 2.6, rgb('#ffd84d' if k % 3 else '#58f08a'))
circle(c, (0, -12), 9, rgb('#1d2a22'), line=rgb('#8a94a3'), lw=1.5)    # closed core hatch
s.write_to_png("mothership.png")
print("ok")
