"""M8 art round 2: the steel ball and its soft shadow (ball.png, ballshadow.png).
Drawn at 64 px for an 18-point ball (~3.5x), highlight top-left (the sprite is counter-rotated
in game so the light stays put)."""
import cairo, math
N = 64
s = cairo.ImageSurface(cairo.FORMAT_ARGB32, N, N); c = cairo.Context(s)
c.translate(N/2, N/2)
r = N/2 - 1
g = cairo.RadialGradient(-r*0.35, -r*0.4, r*0.05, 0, 0, r)
for o, col in [(0, (1, 1, 1)), (0.3, (0.92, 0.94, 0.97)), (0.7, (0.74, 0.77, 0.83)), (1, (0.5, 0.53, 0.6))]:   # M8 v3: brighter edge
    g.add_color_stop_rgb(o, *col)
c.arc(0, 0, r, 0, 2*math.pi); c.set_source(g); c.fill()
# a warm reflection of the playfield along the bottom edge and a crisp rim
g2 = cairo.RadialGradient(r*0.2, r*0.55, 1, r*0.2, r*0.55, r*0.6)
g2.add_color_stop_rgba(0, 0.55, 0.85, 0.6, 0.35); g2.add_color_stop_rgba(1, 0.55, 0.85, 0.6, 0)
c.arc(0, 0, r, 0, 2*math.pi); c.set_source(g2); c.fill()
c.arc(0, 0, r - 0.5, 0, 2*math.pi); c.set_source_rgba(0.95, 0.97, 1.0, 0.9); c.set_line_width(1.5); c.stroke()   # light rim reads on the dark field
c.arc(-r*0.38, -r*0.42, r*0.16, 0, 2*math.pi); c.set_source_rgba(1, 1, 1, 0.95); c.fill()
s.write_to_png("ball.png")

s = cairo.ImageSurface(cairo.FORMAT_ARGB32, N, N); c = cairo.Context(s)
g = cairo.RadialGradient(N/2, N/2, 2, N/2, N/2, N/2)
g.add_color_stop_rgba(0, 0, 0, 0, 0.55); g.add_color_stop_rgba(0.55, 0, 0, 0, 0.35); g.add_color_stop_rgba(1, 0, 0, 0, 0)
c.rectangle(0, 0, N, N); c.set_source(g); c.fill()
s.write_to_png("ballshadow.png")
print("ok")
