"""M10 round 2: the app icon. AppIcon.png, 1024 x 1024, no alpha (App Store rule).
A grey alien in a saucer beaming a steel pinball up off a moonlit field, in the playfield's colours.
Drawn y-down in pixels. iOS rounds the corners itself, so the art fills the whole square."""
import cairo, math, random

S = 1024
def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)

surf = cairo.ImageSurface(cairo.FORMAT_RGB24, S, S)   # RGB24: no alpha channel in the PNG
c = cairo.Context(surf)

def ellipse(cx, cy, rx, ry):
    c.save(); c.translate(cx, cy); c.scale(rx, ry); c.new_sub_path(); c.arc(0, 0, 1, 0, 2*math.pi); c.restore()

def glow(cx, cy, r, col, a):
    g = cairo.RadialGradient(cx, cy, 0, cx, cy, r)
    g.add_color_stop_rgba(0, *col[:3], a); g.add_color_stop_rgba(1, *col[:3], 0)
    c.new_sub_path(); c.arc(cx, cy, r, 0, 2*math.pi); c.set_source(g); c.fill()

# ---- night sky
g = cairo.LinearGradient(0, 0, 0, S)
g.add_color_stop_rgb(0, *rgb('#3a2a6e')[:3]); g.add_color_stop_rgb(0.45, *rgb('#1d1d52')[:3]); g.add_color_stop_rgb(1, *rgb('#0b0d2a')[:3])
c.rectangle(0, 0, S, S); c.set_source(g); c.fill()
random.seed(7)
for _ in range(90):
    x, y, r = random.uniform(0, S), random.uniform(0, 700), random.uniform(1.2, 3.4)
    c.new_sub_path(); c.arc(x, y, r, 0, 2*math.pi); c.set_source_rgba(1, 1, 0.92, random.uniform(0.35, 0.9)); c.fill()
# crescent moon, top left
glow(170, 170, 150, rgb('#fffbe0'), 0.30)
c.save(); c.new_sub_path(); c.arc(170, 170, 70, 0, 2*math.pi); c.clip()      # crescent = disc minus disc
c.rectangle(0, 0, S, S); c.new_sub_path(); c.arc(198, 148, 62, 0, 2*math.pi)
c.set_fill_rule(cairo.FILL_RULE_EVEN_ODD); c.set_source_rgba(*rgb('#f6f0c8')); c.fill(); c.restore()

# ---- field and hills
c.move_to(0, 800); c.curve_to(260, 730, 520, 790, 760, 740); c.curve_to(880, 715, 970, 730, S, 745)
c.line_to(S, S); c.line_to(0, S); c.close_path(); c.set_source_rgba(*rgb('#122a1f')); c.fill()
c.move_to(0, 860); c.curve_to(300, 820, 700, 850, S, 820); c.line_to(S, S); c.line_to(0, S); c.close_path()
g = cairo.LinearGradient(0, 820, 0, S); g.add_color_stop_rgb(0, *rgb('#1d4a2a')[:3]); g.add_color_stop_rgb(1, *rgb('#0f2a1a')[:3])
c.set_source(g); c.fill()

# ---- tractor beam
bx, top, bot = 512, 545, 900
g = cairo.LinearGradient(0, top, 0, bot)
g.add_color_stop_rgba(0, *rgb('#c8ffd8', 0.70)); g.add_color_stop_rgba(1, *rgb('#7dff9e', 0.12))
c.move_to(bx - 70, top); c.line_to(bx + 70, top); c.line_to(bx + 240, bot); c.line_to(bx - 240, bot); c.close_path()
c.set_source(g); c.fill()
ellipse(bx, bot, 240, 34); c.set_source_rgba(*rgb('#7dff9e', 0.28)); c.fill()
for k in range(4):                                       # scan rings
    t = (k + 0.5) / 4; y = top + (bot - top) * t; hw = 70 + 170 * t
    ellipse(bx, y, hw, 10 + 14 * t); c.set_source_rgba(*rgb('#eaffd8', 0.22)); c.set_line_width(4); c.stroke()

# ---- steel pinball rising in the beam
px, py, pr = 512, 720, 78
glow(px, py, 150, rgb('#9ff7ff'), 0.35)
g = cairo.RadialGradient(px - 28, py - 32, 6, px, py, pr)
g.add_color_stop_rgb(0, 1, 1, 1); g.add_color_stop_rgb(0.25, *rgb('#d9dee8')[:3])
g.add_color_stop_rgb(0.75, *rgb('#6c7486')[:3]); g.add_color_stop_rgb(1, *rgb('#2b3040')[:3])
c.new_sub_path(); c.arc(px, py, pr, 0, 2*math.pi); c.set_source(g); c.fill()
ellipse(px + 10, py + 40, 44, 14); c.set_source_rgba(*rgb('#7dff9e', 0.35)); c.fill()   # green reflection of the beam
c.new_sub_path(); c.arc(px, py, pr, 0, 2*math.pi); c.set_source_rgba(1, 1, 1, 0.6); c.set_line_width(3); c.stroke()

# ---- saucer
sx, sy = 512, 470
glow(sx, sy, 400, rgb('#7dff9e'), 0.22)
# dome glass with the grey alien inside
ellipse(sx, sy - 100, 165, 160); c.set_source_rgba(*rgb('#9ff7ff', 0.30)); c.fill()
# alien head
c.save(); c.translate(sx, sy - 150)
c.move_to(0, -88); c.curve_to(70, -88, 84, -20, 54, 22); c.curve_to(34, 54, 14, 72, 0, 74)
c.curve_to(-14, 72, -34, 54, -54, 22); c.curve_to(-84, -20, -70, -88, 0, -88); c.close_path()
g = cairo.LinearGradient(-60, -80, 60, 70); g.add_color_stop_rgb(0, *rgb('#c9cfd8')[:3]); g.add_color_stop_rgb(1, *rgb('#7d8696')[:3])
c.set_source(g); c.fill()
for side in (-1, 1):                                       # big black almond eyes
    c.save(); c.translate(side * 30, 6); c.rotate(side * 0.55); c.scale(30, 15)
    c.new_sub_path(); c.arc(0, 0, 1, 0, 2*math.pi); c.restore(); c.set_source_rgb(*rgb('#07070c')[:3]); c.fill()
    c.new_sub_path(); c.arc(side * 24, -1, 5, 0, 2*math.pi); c.set_source_rgba(*rgb('#7dff9e', 0.9)); c.fill()
c.restore()
# dome highlight and rim
ellipse(sx - 80, sy - 170, 30, 52); c.set_source_rgba(1, 1, 1, 0.22); c.fill()
ellipse(sx, sy - 100, 165, 160); c.set_source_rgba(*rgb('#d8ffff', 0.6)); c.set_line_width(5); c.stroke()
# hull
ellipse(sx, sy + 8, 380, 92)
g = cairo.LinearGradient(0, sy - 80, 0, sy + 100)
g.add_color_stop_rgb(0, *rgb('#e3e7ee')[:3]); g.add_color_stop_rgb(0.5, *rgb('#9aa3b2')[:3]); g.add_color_stop_rgb(1, *rgb('#4b5263')[:3])
c.set_source(g); c.fill()
ellipse(sx, sy - 12, 330, 46); c.set_source_rgba(1, 1, 1, 0.28); c.fill()
ellipse(sx, sy + 8, 380, 92); c.set_source_rgba(*rgb('#2b3040')); c.set_line_width(5); c.stroke()
# underside and lamps
ellipse(sx, sy + 70, 120, 26); c.set_source_rgba(*rgb('#c8ffd8')); c.fill()
for i in (0, 1, 2, 4, 5, 6):
    a = math.pi * (i + 0.5) / 7
    lx, ly = sx - 300 * math.cos(a), sy + 38 + 30 * math.sin(a) - 10
    glow(lx, ly, 34, rgb('#ffd84d'), 0.7)
    c.new_sub_path(); c.arc(lx, ly, 14, 0, 2*math.pi); c.set_source_rgba(*rgb('#ffd84d')); c.fill()

surf.write_to_png("AppIcon.png")
print("AppIcon.png", S, "x", S)
