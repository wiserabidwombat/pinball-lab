"""Table 06 (Orbit: Grand Tour) M5 round 7 (look development): the printed floor of the UPPER table (pycairo + numpy),
the counterpart of tour_floor_lower.py. The tour runs from Earth (rising behind the flippers) to the Sun: here the Sun
rises behind the S-T-A-R lanes at the top of the arch — granulation, limb darkening, prominences, a corona that warms
the space down to the bumpers. Faint gold orbit lines centred on the Sun cross the table; the asteroid belt sweeps past
under the bumpers (the "asteroids"); a concrete launch apron with hazard stripes and scorch marks lies under the
Rocket; the lower table's dashed launch path continues up the open centre to the blast door.
World points, y up; the image covers UPPER_RECT at PX_PER_PT * scale.  Usage: python3 tour_floor_upper.py out.png [scale]"""
import cairo, math, random, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tour_look_layout as L

OUT = sys.argv[1]
SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
UPPER_RECT = (-40, 640, 680, 700)              # y 640 … 1340 (overlaps the lower painting's top 60 pt)
X0, Y0, W, H = UPPER_RECT
S = L.PX_PER_PT * SCALE
PW, PH = int(W * S), int(H * S)
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, PW, PH)
cr = cairo.Context(surf)
cr.translate(-X0 * S, (Y0 + H) * S)
cr.scale(S, -S)
rnd = random.Random(11)
SUN = (284.0, 1365.0)                          # the Sun's centre, above the arch: most of its disc fills the arch
SUN_R = 205.0                                  # behind the S-T-A-R lanes (its lower limb y 1160, just over the lamps)


def rgb(c, a=1.0): cr.set_source_rgba(c[0], c[1], c[2], a)
def circle(x, y, r): cr.new_sub_path(); cr.arc(x, y, r, 0, 2 * math.pi)
def poly(pts):
    cr.move_to(*pts[0])
    for p in pts[1:]: cr.line_to(*p)
    cr.close_path()


def glow(x, y, r, col, a, sx=1.0, sy=1.0, rot=0.0):
    cr.save(); cr.translate(x, y); cr.rotate(rot); cr.scale(sx, sy)
    g = cairo.RadialGradient(0, 0, 0, 0, 0, r)
    g.add_color_stop_rgba(0, *col, a); g.add_color_stop_rgba(0.45, *col, a * 0.45); g.add_color_stop_rgba(1, *col, 0)
    cr.set_source(g); circle(0, 0, r); cr.fill(); cr.restore()


def text(x, y, s, size, col, a=1.0, angle=0.0, spacing=0.0):
    cr.save(); cr.translate(x, y); cr.rotate(angle); cr.scale(1, -1)
    cr.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    cr.set_font_size(size)
    widths = [cr.text_extents(ch).x_advance for ch in s]
    total = sum(widths) + spacing * (len(s) - 1); ext = cr.text_extents(s)
    cx = -total / 2; rgb(col, a)
    for ch, w in zip(s, widths):
        cr.move_to(cx, ext.height / 2); cr.show_text(ch); cx += w + spacing
    cr.restore()


# ------------------------------------------------------------------ deep space (continues the lower painting's top)
g = cairo.LinearGradient(0, Y0, 0, Y0 + H)
g.add_color_stop_rgb(0, 0.022, 0.020, 0.075)
g.add_color_stop_rgb(0.5, 0.020, 0.016, 0.055)
g.add_color_stop_rgb(1, 0.040, 0.020, 0.030)
cr.set_source(g); cr.rectangle(X0, Y0, W, H); cr.fill()
for (x, y, r, col, a, sx, sy, rot) in [(120, 760, 230, (0.18, 0.12, 0.45), 0.16, 1.0, 0.6, 0.4),
                                        (470, 820, 220, (0.06, 0.24, 0.40), 0.15, 1.0, 0.55, -0.6),
                                        (300, 870, 160, (0.42, 0.14, 0.34), 0.08, 1.0, 0.5, 0.2)]:
    glow(x, y, r, col, a, sx, sy, rot)
    for k in range(9):
        glow(x + rnd.gauss(0, r * 0.35), y + rnd.gauss(0, r * 0.2), r * rnd.uniform(0.2, 0.45), col,
             a * rnd.uniform(0.3, 0.8), 1.0, rnd.uniform(0.3, 0.7), rot + rnd.uniform(-0.4, 0.4))
for k in range(2400):                          # stars, fewer toward the Sun's glare
    x = rnd.uniform(X0, X0 + W); y = rnd.uniform(Y0, Y0 + H)
    fade = min(1.0, max(0.0, (math.hypot(x - SUN[0], y - SUN[1]) - SUN_R) / 260))
    b = rnd.random() ** 2.4
    tint = rnd.choice([(1.0, 1.0, 1.0), (0.80, 0.88, 1.0), (1.0, 0.92, 0.80), (1.0, 0.85, 0.75)])
    rgb(tint, (0.25 + 0.75 * b) * fade); circle(x, y, 0.25 + 0.75 * b); cr.fill()
for k in range(22):
    x = rnd.uniform(X0 + 20, X0 + W - 20); y = rnd.uniform(Y0 + 20, 1120)
    if math.hypot(x - SUN[0], y - SUN[1]) < SUN_R + 200: continue
    glow(x, y, rnd.uniform(3.5, 8), (0.75, 0.85, 1.0), 0.45)
    rgb((1, 1, 1), 0.9); circle(x, y, 0.8); cr.fill()
    ln = rnd.uniform(4, 9); rgb((0.85, 0.92, 1.0), 0.45); cr.set_line_width(0.35)
    cr.move_to(x - ln, y); cr.line_to(x + ln, y); cr.move_to(x, y - ln); cr.line_to(x, y + ln); cr.stroke()

# ------------------------------------------------------------------ the corona and the Sun's warm light (behind all)
glow(SUN[0], SUN[1], SUN_R * 2.6, (1.0, 0.42, 0.10), 0.30)
glow(SUN[0], SUN[1], SUN_R * 1.75, (1.0, 0.60, 0.20), 0.38)
glow(SUN[0], SUN[1], SUN_R * 1.28, (1.0, 0.80, 0.45), 0.55)
for k in range(28):                            # streamers of the corona
    a = rnd.uniform(math.pi * 1.05, math.pi * 1.95)
    d = SUN_R * rnd.uniform(1.05, 1.35)
    glow(SUN[0] + d * math.cos(a), SUN[1] + d * math.sin(a), SUN_R * rnd.uniform(0.35, 0.7), (1.0, 0.70, 0.35),
         0.10, 1.0, rnd.uniform(0.15, 0.3), a)

# ------------------------------------------------------------------ orbit lines round the Sun (faint gold, dashed)
cr.save()
for r, a in [(360, 0.20), (470, 0.17), (600, 0.15), (760, 0.13), (930, 0.11)]:
    rgb((0.95, 0.78, 0.45), a); cr.set_line_width(0.7); cr.set_dash([5, 4])
    cr.new_sub_path(); cr.arc(SUN[0], SUN[1], r, math.pi, 2 * math.pi); cr.stroke()
cr.restore()

# ------------------------------------------------------------------ the asteroid belt under the bumpers
BELT_R, BELT_W = 392.0, 30.0                   # passes y ~973 at the centre: between the apron and the pops
for k in range(900):
    a = rnd.uniform(math.pi * 1.02, math.pi * 1.98)
    off = rnd.gauss(0, BELT_W * 0.45)
    r = BELT_R + off
    x, y = SUN[0] + r * math.cos(a), SUN[1] + r * math.sin(a)
    size = (rnd.random() ** 3) * 3.4 + 0.5
    if abs(off) > BELT_W: size *= 0.6
    n = rnd.randint(5, 8); rot = rnd.uniform(0, 6.28)
    pts = [(x + size * rnd.uniform(0.65, 1.15) * math.cos(rot + i * 2 * math.pi / n),
            y + size * rnd.uniform(0.65, 1.15) * math.sin(rot + i * 2 * math.pi / n)) for i in range(n)]
    tone = rnd.uniform(0.28, 0.55); warm = rnd.uniform(0.9, 1.05)
    rgb((tone * warm, tone * 0.92, tone * 0.85 / warm), 0.95); poly(pts); cr.fill()
    if size > 1.4:                             # lit from the Sun (above): a bright rim on the top side
        rgb((1.0, 0.86, 0.62), 0.55); cr.set_line_width(0.35)
        top = sorted(pts, key=lambda p: -p[1])[:3]
        cr.move_to(*top[0]); [cr.line_to(*p) for p in top[1:]]; cr.stroke()
glow(SUN[0], SUN[1] - BELT_R, 260, (0.70, 0.55, 0.40), 0.06, 1.0, 0.12, 0)   # the belt's dust

# ------------------------------------------------------------------ the Sun itself (numpy: granulation, limb darkening)
sz = int(2 * SUN_R * S) + 2
yy, xx = np.mgrid[0:sz, 0:sz]
ux = (xx + 0.5 - sz / 2) / (SUN_R * S); uy = -(yy + 0.5 - sz / 2) / (SUN_R * S)
rr = np.hypot(ux, uy); mu = np.sqrt(np.clip(1 - rr * rr, 0, 1))
nrng = np.random.default_rng(3)
from scipy import ndimage as nd
gran = nd.gaussian_filter(nrng.standard_normal((sz, sz)), 1.1 * SCALE * 1.5)
gran = gran / gran.std()
cells = nd.gaussian_filter(nrng.standard_normal((sz, sz)), 6 * SCALE * 1.5); cells /= cells.std()
limb = 0.42 + 0.58 * mu ** 0.5
# white-gold centre → deep orange limb; granulation only in brightness, small and soft
base = np.stack([np.ones_like(mu), 0.50 + 0.42 * mu ** 0.7, 0.10 + 0.50 * mu ** 1.8], -1)
col = base * (1.18 * limb * (1 + 0.03 * gran))[..., None]
spots = (nd.gaussian_filter(nrng.standard_normal((sz, sz)), 14 * SCALE) > 2.4 * 0.012)  # placeholder, replaced below
col = np.clip(col, 0, 1)
alpha = np.clip((1 - rr) * SUN_R * S / 1.5, 0, 1)
buf = np.zeros((sz, sz, 4), np.uint8)
buf[..., 0] = (col[..., 2] * alpha * 255).astype(np.uint8); buf[..., 1] = (col[..., 1] * alpha * 255).astype(np.uint8)
buf[..., 2] = (col[..., 0] * alpha * 255).astype(np.uint8); buf[..., 3] = (alpha * 255).astype(np.uint8)
img = cairo.ImageSurface.create_for_data(memoryview(buf), cairo.FORMAT_ARGB32, sz, sz, sz * 4)
dx, dy = cr.user_to_device(*SUN)
cr.save(); cr.identity_matrix(); cr.set_source_surface(img, dx - sz / 2, dy - sz / 2); cr.paint(); cr.restore()
# two sunspot groups and prominences on the lower limb
for (a, d, r0) in [(math.radians(242), 0.62, 5.0), (math.radians(300), 0.50, 3.6)]:
    x, y = SUN[0] + SUN_R * d * math.cos(a), SUN[1] + SUN_R * d * math.sin(a)
    glow(x, y, r0 * 2.2, (0.55, 0.22, 0.05), 0.55, 1.0, 0.7, a)
    rgb((0.18, 0.06, 0.02), 0.85); cr.save(); cr.translate(x, y); cr.scale(1, 0.7); circle(0, 0, r0); cr.fill(); cr.restore()
    for k in range(4):
        rgb((0.25, 0.09, 0.03), 0.7); circle(x + rnd.gauss(0, r0 * 1.8), y + rnd.gauss(0, r0), r0 * rnd.uniform(0.25, 0.5)); cr.fill()
for a in [math.radians(205), math.radians(258), math.radians(322)]:
    x, y = SUN[0] + SUN_R * math.cos(a), SUN[1] + SUN_R * math.sin(a)
    for k in range(5):
        glow(x + rnd.gauss(0, 4), y + rnd.gauss(0, 4), rnd.uniform(6, 11), (1.0, 0.40, 0.18), 0.30, 1.0, 0.5, a)
    cr.save(); cr.translate(x, y); cr.rotate(a + math.pi / 2)        # a soft loop standing off the limb
    for w, al in [(5.0, 0.12), (3.0, 0.22), (1.4, 0.45)]:
        rgb((1.0, 0.40, 0.20), al); cr.set_line_width(w); cr.set_line_cap(cairo.LINE_CAP_ROUND)
        cr.move_to(-8, -1); cr.curve_to(-7, 13, 7, 14, 9, -1); cr.stroke()
    cr.restore()

# ------------------------------------------------------------------ the launch apron under the Rocket
PAD = [(235.8, 892.0), (266, 920), (284, 938), (302, 920), (332.2, 892.0)]
apron = [(214, 868), (214, 905), (250, 948), (284, 972), (318, 948), (354, 905), (354, 868)]
rgb((0.30, 0.30, 0.32)); poly(apron); cr.fill()
for k in range(260):                           # concrete mottling
    x = rnd.uniform(214, 354); y = rnd.uniform(868, 972)
    rgb((0.42, 0.41, 0.40) if rnd.random() < 0.5 else (0.22, 0.22, 0.24), 0.25)
    circle(x, y, rnd.uniform(0.6, 2.4)); cr.fill()
cr.save(); poly(apron); cr.clip()
rgb((0.12, 0.12, 0.14), 0.7); cr.set_line_width(0.6)       # expansion joints
for x in range(224, 354, 22): cr.move_to(x, 860); cr.line_to(x, 980)
for y in range(878, 980, 22): cr.move_to(200, y); cr.line_to(370, y)
cr.stroke()
glow(284, 900, 46, (0.02, 0.01, 0.01), 0.85, 1.0, 0.55, 0)  # flame scorch fanning down from the pad
glow(284, 880, 30, (0.08, 0.03, 0.01), 0.7, 1.0, 0.8, 0)
cr.restore()
cr.save()                                      # hazard stripes along the apron's front edge
cr.move_to(214, 868); cr.line_to(354, 868); cr.line_to(354, 876); cr.line_to(214, 876); cr.close_path(); cr.clip()
rgb((0.95, 0.72, 0.10)); cr.rectangle(210, 866, 150, 12); cr.fill()
rgb((0.08, 0.07, 0.06))
for x in range(200, 370, 10):
    cr.move_to(x, 864); cr.line_to(x + 6, 864); cr.line_to(x + 14, 880); cr.line_to(x + 8, 880); cr.close_path(); cr.fill()
cr.restore()
rgb((0.85, 0.86, 0.90), 0.75); cr.set_line_width(0.8); poly(apron); cr.stroke()
text(284, 858, "LAUNCH COMPLEX 6", 6.5, (0.95, 0.80, 0.40), 0.85, spacing=0.6)

# ------------------------------------------------------------------ the dashed launch path up the centre channel
cr.save(); rgb((0.98, 0.84, 0.50), 0.55); cr.set_line_width(1.6); cr.set_dash([7, 6])
cr.move_to(284, Y0); cr.line_to(284, 846); cr.stroke(); cr.restore()
for y in (700, 760, 820):                      # chevrons pointing up the channel
    rgb((0.98, 0.84, 0.50), 0.35); cr.set_line_width(1.3)
    cr.move_to(276, y - 5); cr.line_to(284, y + 3); cr.line_to(292, y - 5); cr.stroke()

surf.write_to_png(OUT)
print('wrote', OUT, PW, PH)
