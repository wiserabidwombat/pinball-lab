"""Pinball Lab round 3: the app icon. AppIcon.png, 1024 x 1024, no alpha (App Store rule).
A glass lab flask with a steel pinball resting in glowing liquid that runs from Grey Invasion's alien
green up into Orbit's purple, under a ring of light. iOS rounds the corners itself, so the art fills
the square. Drawn y-down in pixels."""
import cairo, math, random, sys

S = 1024
out = sys.argv[1] if len(sys.argv) > 1 else 'AppIcon.png'
def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)

surf = cairo.ImageSurface(cairo.FORMAT_RGB24, S, S)
c = cairo.Context(surf)

def glow(cx, cy, r, col, a):
    g = cairo.RadialGradient(cx, cy, 0, cx, cy, r)
    g.add_color_stop_rgba(0, *col[:3], a); g.add_color_stop_rgba(1, *col[:3], 0)
    c.new_sub_path(); c.arc(cx, cy, r, 0, 2*math.pi); c.set_source(g); c.fill()

# ---- background: deep space violet
g = cairo.RadialGradient(512, 430, 60, 512, 520, 760)
g.add_color_stop_rgb(0, *rgb('#2c2266')[:3]); g.add_color_stop_rgb(0.6, *rgb('#140f38')[:3]); g.add_color_stop_rgb(1, *rgb('#07061a')[:3])
c.rectangle(0, 0, S, S); c.set_source(g); c.fill()
random.seed(11)
for _ in range(70):
    x, y, r = random.uniform(0, S), random.uniform(0, S), random.uniform(1.2, 3.2)
    c.new_sub_path(); c.arc(x, y, r, 0, 2*math.pi); c.set_source_rgba(1, 1, 1, random.uniform(0.25, 0.75)); c.fill()

# ---- flask shape (Erlenmeyer)
cx = 512
neck_w, neck_top, neck_bot = 150, 150, 400
base_y, base_w = 880, 640
def flask_path():
    c.new_path()
    c.move_to(cx - neck_w/2, neck_top)
    c.line_to(cx - neck_w/2, neck_bot)
    c.line_to(cx - base_w/2 + 40, base_y - 50)
    c.curve_to(cx - base_w/2 + 10, base_y - 10, cx - base_w/2 + 30, base_y, cx - base_w/2 + 80, base_y)
    c.line_to(cx + base_w/2 - 80, base_y)
    c.curve_to(cx + base_w/2 - 30, base_y, cx + base_w/2 - 10, base_y - 10, cx + base_w/2 - 40, base_y - 50)
    c.line_to(cx + neck_w/2, neck_bot)
    c.line_to(cx + neck_w/2, neck_top)
    c.close_path()

# glow behind the flask
glow(cx, 700, 470, rgb('#7d5cff'), 0.35)
glow(cx, 760, 330, rgb('#5dff8f'), 0.22)

# back half of the orbit ring, behind the flask (a nod to table one)
c.save(); c.translate(cx, 520); c.rotate(-0.32); c.scale(430, 120)
c.new_sub_path(); c.arc(0, 0, 1, math.pi, math.pi*2)   # back half, behind the neck
c.restore(); c.set_line_width(10); c.set_source_rgba(*rgb('#b49cff')[:3], 0.5); c.stroke()

# glass body (faint fill)
flask_path(); c.set_source_rgba(1, 1, 1, 0.07); c.fill()

# liquid, clipped to the flask
liquid_top = 560
c.save(); flask_path(); c.clip()
g = cairo.LinearGradient(0, liquid_top, 0, base_y)
g.add_color_stop_rgb(0, *rgb('#8f6bff')[:3]); g.add_color_stop_rgb(0.55, *rgb('#3fd8a0')[:3]); g.add_color_stop_rgb(1, *rgb('#2fe36a')[:3])
c.move_to(0, liquid_top)
for i in range(0, S + 1, 16):
    c.line_to(i, liquid_top + 10*math.sin(i/70.0))
c.line_to(S, S); c.line_to(0, S); c.close_path(); c.set_source(g); c.fill()
# surface highlight
c.move_to(0, liquid_top)
for i in range(0, S + 1, 16):
    c.line_to(i, liquid_top + 10*math.sin(i/70.0))
c.set_line_width(8); c.set_source_rgba(0.85, 0.8, 1, 0.8); c.stroke()
# bubbles
random.seed(3)
for _ in range(16):
    x = random.uniform(cx - 230, cx + 230); y = random.uniform(liquid_top + 40, base_y - 30)
    r = random.uniform(6, 16)
    c.new_sub_path(); c.arc(x, y, r, 0, 2*math.pi); c.set_source_rgba(1, 1, 1, 0.18); c.fill_preserve()
    c.set_line_width(2.5); c.set_source_rgba(1, 1, 1, 0.5); c.stroke()
c.restore()

# ---- the steel pinball, half sunk in the liquid
bx, by, br = cx, 705, 128
glow(bx, by, br * 1.6, rgb('#d8ccff'), 0.35)
g = cairo.RadialGradient(bx - 55, by - 60, 10, bx, by, br)
g.add_color_stop_rgb(0, 1, 1, 1); g.add_color_stop_rgb(0.25, *rgb('#dcdff0')[:3])
g.add_color_stop_rgb(0.7, *rgb('#7d8299')[:3]); g.add_color_stop_rgb(1, *rgb('#2b2d40')[:3])
c.new_sub_path(); c.arc(bx, by, br, 0, 2*math.pi); c.set_source(g); c.fill()
# reflections: green below, purple at the rim
c.save(); c.new_sub_path(); c.arc(bx, by, br, 0, 2*math.pi); c.clip()
g = cairo.LinearGradient(0, by + 40, 0, by + br)
g.add_color_stop_rgba(0, *rgb('#3fe38a')[:3], 0); g.add_color_stop_rgba(1, *rgb('#3fe38a')[:3], 0.55)
c.rectangle(bx - br, by, 2*br, br); c.set_source(g); c.fill()
c.restore()
c.new_sub_path(); c.arc(bx, by, br, 0, 2*math.pi); c.set_line_width(4); c.set_source_rgba(0.75, 0.65, 1, 0.6); c.stroke()
# specular highlight
c.save(); c.translate(bx - 60, by - 70); c.rotate(-0.6); c.scale(42, 22)
c.new_sub_path(); c.arc(0, 0, 1, 0, 2*math.pi); c.restore(); c.set_source_rgba(1, 1, 1, 0.9); c.fill()

# ---- glass outline and shine
flask_path(); c.set_line_width(16); c.set_line_join(cairo.LINE_JOIN_ROUND); c.set_source_rgba(0.92, 0.9, 1, 0.92); c.stroke()
# lip at the top of the neck
c.new_path(); c.move_to(cx - neck_w/2 - 26, neck_top); c.line_to(cx + neck_w/2 + 26, neck_top)
c.set_line_width(22); c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke()
# shine streak on the left of the glass
c.new_path(); c.move_to(cx - neck_w/2 + 26, neck_top + 40); c.line_to(cx - neck_w/2 + 26, neck_bot - 10)
c.set_line_width(12); c.set_source_rgba(1, 1, 1, 0.35); c.stroke()

# ---- orbit ring around the flask (a nod to table one)
c.save(); c.translate(cx, 520); c.rotate(-0.32); c.scale(430, 120)
c.new_sub_path(); c.arc(0, 0, 1, 0, math.pi)            # front half
c.restore(); c.set_line_width(12); c.set_source_rgba(*rgb('#c9b8ff')[:3], 0.95); c.stroke()
# a small planet riding the ring
px, py = cx + 430*math.cos(0.5)*math.cos(-0.32) - 120*math.sin(0.5)*math.sin(-0.32), 520 + 430*math.cos(0.5)*math.sin(-0.32) + 120*math.sin(0.5)*math.cos(-0.32)
glow(px, py, 70, rgb('#5dff8f'), 0.5)
g = cairo.RadialGradient(px - 12, py - 12, 4, px, py, 34)
g.add_color_stop_rgb(0, *rgb('#c8ffd8')[:3]); g.add_color_stop_rgb(1, *rgb('#1fa84e')[:3])
c.new_sub_path(); c.arc(px, py, 34, 0, 2*math.pi); c.set_source(g); c.fill()

surf.write_to_png(out)
print('wrote', out)
