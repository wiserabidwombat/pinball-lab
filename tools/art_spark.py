"""M9: spark.png, a soft white glow dot with a bright centre, tinted per effect in game."""
import cairo
N = 32
s = cairo.ImageSurface(cairo.FORMAT_ARGB32, N, N); c = cairo.Context(s)
g = cairo.RadialGradient(N/2, N/2, 0, N/2, N/2, N/2)
g.add_color_stop_rgba(0, 1, 1, 1, 1); g.add_color_stop_rgba(0.25, 1, 1, 1, 0.85); g.add_color_stop_rgba(1, 1, 1, 1, 0)
c.rectangle(0, 0, N, N); c.set_source(g); c.fill()
s.write_to_png("spark.png"); print("ok")
