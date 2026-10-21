"""Table 05 (The Lamplight) polish: the How to Play pictures. The baked table and every part sprite composited as the game
draws them (z order, the loft's lift, the oblique view), with the lamps lit the way the rules light them and the shots
drawn on as dashed gold paths, one picture per goal, plus the whole-table map (numbered in SwiftUI).
Reads the art from an LmpArt folder (Assets.xcassets/LmpArt or a copy). World points, y up, 3 px per pt.
Usage: python3 lmp_howto.py <LmpArt dir> <out dir>"""
import sys, os, math, glob
import cairo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

ART, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
PX = 3
X0, Y0, W, H = -40, -75, 680, 1405
K = L.OBLIQUE
LOFT_LIFT = L.LOFT_HEIGHT * K
WARM = (1.0, 0.78, 0.42)
GREEN = (0.55, 0.85, 0.55)
COZY = (0.98, 0.62, 0.38)
_cache = {}


def img(name):
    if name not in _cache:
        hits = glob.glob(os.path.join(ART, '**', name + '.png'), recursive=True)
        _cache[name] = cairo.ImageSurface.create_from_png(hits[0]) if hits else None
    return _cache[name]


def px(x, y):
    return (x - X0) * PX, (Y0 + H - y) * PX


def sprite(cr, name, ax, ay, box, rot=0.0, scale=1.0, op=None, src=None):
    """Paint sprite `name` with its box (minX, minY, w, h) round world anchor (ax, ay); rot = SpriteKit zRotation."""
    s = src or img(name)
    if s is None: return
    bx, by, bw, bh = box
    cr.save()
    cr.identity_matrix()
    cx, cy = px(ax, ay)
    cr.translate(cx, cy)
    cr.rotate(-rot)
    cr.scale(scale, scale)
    sx, sy = bw * PX / s.get_width(), bh * PX / s.get_height()
    cr.translate(bx * PX, -(by + bh) * PX)
    cr.scale(sx, sy)
    cr.set_source_surface(s, 0, 0)
    cr.get_source().set_filter(cairo.FILTER_BEST)
    if op is not None: cr.set_operator(op)
    cr.paint()
    cr.restore()


def lamp_path(cr, shape, x, y, ang, k=1.0):
    cr.save(); cr.translate(x, y); cr.rotate(ang); cr.scale(k, k)
    kind = shape[0]
    if kind == 'arrow':
        ln, wd = shape[1], shape[2]
        cr.move_to(ln / 2, 0); cr.line_to(-ln / 2, wd / 2); cr.line_to(-ln / 2 + 6, 0); cr.line_to(-ln / 2, -wd / 2)
        cr.close_path()
    elif kind == 'round':
        cr.arc(0, 0, shape[1], 0, 2 * math.pi)
    else:
        for i in range(10):
            r = shape[1] if i % 2 == 0 else shape[2]
            a = math.pi / 2 + i * math.pi / 5
            (cr.move_to if i == 0 else cr.line_to)(r * math.cos(a), r * math.sin(a))
        cr.close_path()
    cr.restore()


def lamp(cr, shape, x, y, ang, col, lit):
    """LmpLamp: off = a dim tinted insert in a dark socket; lit = full colour, a halo and a near-white core."""
    lamp_path(cr, shape, x, y, ang, 1.25); cr.set_source_rgba(0.06, 0.05, 0.10, 0.55); cr.fill()
    if lit:
        lamp_path(cr, shape, x, y, ang, 2.6); cr.set_source_rgba(*col, 0.30); cr.fill()
        lamp_path(cr, shape, x, y, ang, 1.9); cr.set_source_rgba(*col, 0.55); cr.fill()
    k = 1.0 if lit else 0.45
    lamp_path(cr, shape, x, y, ang); cr.set_source_rgba(col[0] * k, col[1] * k, col[2] * k, 1.0 if lit else 0.30); cr.fill()
    lamp_path(cr, shape, x, y, ang); cr.set_source_rgba(*col, 0.7); cr.set_line_width(1); cr.stroke()
    if lit:
        lamp_path(cr, shape, x, y, ang, 0.45); cr.set_source_rgba(1, 1, 0.95, 0.9); cr.fill()


ARROWS = {"ramp": ((328, 585), 76), "rightLoop": ((428, 580), 60), "leftLoop": ((128, 560), 117),
          "kettle": ((238, 585), 104), "fireplace": ((284, 690), 90), "windowSeat": ((185, 1030), 125)}
SHOP = [(62, 192), (112, 174), (162, 157), (506, 192), (456, 174), (406, 157)]
COZY_LAMPS = [(70, 124), (118, 107), (166, 90)]
COZY_SPOTS = [(48, 280), (100, 238), (148, 198)]
PERCH = {'shelf': (370, 1175), 'mantel': (252, 882), 'kettle': (134, 945), 'windowSeat': (165, 1140 + LOFT_LIFT)}


def ball(cr, x, y, upper=False, h=None):
    """A steel ball; an upper (loft/ramp) ball draws higher by its height and a little bigger."""
    hh = (L.LOFT_HEIGHT if upper else 0) if h is None else h
    r = 9 * (1 + 0.12 * min(hh / L.LOFT_HEIGHT, 1))
    if hh > 0:                                                         # its shadow on the floor below
        cr.arc(x + 2, y - 2, r * 0.9, 0, 2 * math.pi); cr.set_source_rgba(0, 0, 0, 0.3); cr.fill()
    y += hh * K
    cr.arc(x + 1.2, y - 1.5, r, 0, 2 * math.pi); cr.set_source_rgba(0, 0, 0, 0.35); cr.fill()
    g = cairo.RadialGradient(x - r * 0.35, y + r * 0.4, r * 0.1, x, y, r)
    g.add_color_stop_rgb(0, 1, 1, 1); g.add_color_stop_rgb(0.35, 0.82, 0.83, 0.86)
    g.add_color_stop_rgb(0.8, 0.42, 0.43, 0.47); g.add_color_stop_rgb(1, 0.22, 0.22, 0.25)
    cr.arc(x, y, r, 0, 2 * math.pi); cr.set_source(g); cr.fill()


def festival_lights(cr, colors=((1, 1, 1), (0.95, 0.25, 0.2), (0.3, 0.85, 0.4), (0.35, 0.55, 1))):
    for (a, b, sag) in (((26, 1015), (574, 1065), 70), ((26, 655), (574, 615), 60)):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - 2 * sag
        pts = [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * mx + t * t * b[0], (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * my + t * t * b[1])
               for t in [i / 60 for i in range(61)]]
        cr.set_source_rgba(0.08, 0.06, 0.05, 0.9); cr.set_line_width(1.2)
        cr.move_to(*pts[0]); [cr.line_to(*p) for p in pts[1:]]; cr.stroke()
        for i, p in enumerate(pts[::3]):
            c = colors[i % len(colors)]
            g = cairo.RadialGradient(p[0], p[1], 0, p[0], p[1], 10)
            g.add_color_stop_rgba(0, *c, 0.8); g.add_color_stop_rgba(1, *c, 0)
            cr.set_source(g); cr.arc(p[0], p[1], 10, 0, 6.29); cr.fill()
            cr.set_source_rgb(*c); cr.arc(p[0], p[1], 2.4, 0, 6.29); cr.fill()


def path(cr, pts, num=None, col=(1.0, 0.86, 0.35)):
    """A shot drawn on: a dark-edged dashed gold line with an arrowhead, and an optional step number at its start."""
    def line():
        cr.move_to(*pts[0])
        for p in pts[1:]: cr.line_to(*p)
    cr.set_line_cap(cairo.LINE_CAP_ROUND); cr.set_line_join(cairo.LINE_JOIN_ROUND)
    line(); cr.set_source_rgba(0.1, 0.05, 0.0, 0.7); cr.set_line_width(5.5); cr.set_dash([]); cr.stroke()
    line(); cr.set_source_rgb(*col); cr.set_line_width(3.0); cr.set_dash([9, 6]); cr.stroke(); cr.set_dash([])
    (x0, y0), (x1, y1) = pts[-2], pts[-1]
    a = math.atan2(y1 - y0, x1 - x0)
    for w_, c_ in ((9, (0.1, 0.05, 0.0)), (6.5, col)):
        cr.move_to(x1 + math.cos(a) * w_ * 0.6, y1 + math.sin(a) * w_ * 0.6)
        cr.line_to(x1 + math.cos(a + 2.5) * w_ * 1.5, y1 + math.sin(a + 2.5) * w_ * 1.5)
        cr.line_to(x1 + math.cos(a - 2.5) * w_ * 1.5, y1 + math.sin(a - 2.5) * w_ * 1.5)
        cr.close_path(); cr.set_source_rgb(*c_); cr.fill()
    if num is not None:
        x, y = pts[0]
        cr.arc(x, y, 9, 0, 6.29); cr.set_source_rgb(0.1, 0.05, 0.0); cr.fill()
        cr.arc(x, y, 7.5, 0, 6.29); cr.set_source_rgb(*col); cr.fill()
        cr.save(); cr.translate(x, y); cr.scale(1, -1)
        cr.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); cr.set_font_size(11)
        e = cr.text_extents(str(num)); cr.move_to(-e.x_advance / 2, e.height / 2)
        cr.set_source_rgb(0.1, 0.05, 0.0); cr.show_text(str(num)); cr.restore()


def ring(cr, x, y, r, col=(1.0, 0.86, 0.35)):
    """A highlight ring round something to look at."""
    cr.arc(x, y, r, 0, 6.29); cr.set_source_rgba(0.1, 0.05, 0.0, 0.7); cr.set_line_width(5); cr.stroke()
    cr.arc(x, y, r, 0, 6.29); cr.set_source_rgb(*col); cr.set_line_width(2.6); cr.set_dash([7, 5]); cr.stroke(); cr.set_dash([])


def table(lit=(), down=(), cat=('shelf', 'sit'), balls=(), upper_balls=(), cozy=(), cozy_lit=0, shop_lit=0,
          lucky=False, flap=False, mail=False, festival=False, teacup_lit=False, season='autumn', extra=None):
    """The whole table as the game draws it, in a given state."""
    sf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W * PX, H * PX)
    cr = cairo.Context(sf)
    cr.set_source_rgb(0.1, 0.06, 0.04); cr.paint()
    sprite(cr, 'lmp_lower', 300, 225, (-340, -300, 680, 600))
    sprite(cr, 'lmp_upper', 300, 927.5, (-340, -402.5, 680, 805))
    sprite(cr, 'lmp_fire_5', 284, 770, (-42, -6, 84, 52), op=cairo.OPERATOR_ADD)
    sprite(cr, f'lmp_season_window_{season}', 125, 1130 + LOFT_LIFT, (-70, -60, 140, 120))
    for i, p in enumerate(COZY_SPOTS):
        if i < len(cozy): sprite(cr, f'lmp_cozy_{cozy[i]}', *p, (-32.5, -22.5, 65, 80))
    # world transform for drawing
    cr.translate(-X0 * PX, (Y0 + H) * PX); cr.scale(PX, -PX)
    for name, ((x, y), a) in ARROWS.items():
        lamp(cr, ('arrow', 30, 16), x, y + (LOFT_LIFT if name == 'windowSeat' else 0), math.radians(a), WARM, name in lit)
    lamp(cr, ('round', 17), 380, 640, 0, WARM, mail)
    lamp(cr, ('star', 11, 5), 284, 330, 0, GREEN, lucky)
    lamp(cr, ('round', 8), 531, 300, 0, GREEN, flap)
    for i, p in enumerate(SHOP): lamp(cr, ('round', 7), *p, 0, WARM, i < shop_lit)
    for i, p in enumerate(COZY_LAMPS): lamp(cr, ('round', 10), *p, 0, COZY, i < cozy_lit)
    sprite(cr, f'lmp_season_mantel_{season}', 284, 855, (-70, -12, 140, 56))
    for i, x in enumerate((240.2, 269.4, 298.6, 327.8)):
        sprite(cr, f'lmp_target_{i}' + ('_down' if i in down else ''), x, 745, (-15, -8, 30, 24))
    sp = img('lmp_spinner_sheet')
    if sp:
        fw, fh = sp.get_width() // 6, sp.get_height() // 4
        sub = cairo.ImageSurface(cairo.FORMAT_ARGB32, fw, fh); _c = cairo.Context(sub); _c.set_source_surface(sp, 0, 0); _c.paint()
        sx, sy = L.kettle_point(-L.KETTLE_LEN + 30, 0)
        sprite(cr, None, sx, sy, (-32, -20, 64, 48), src=sub)
    for (bx, by) in ((285, 930), (350, 930), (318, 1000)):
        sprite(cr, 'lmp_bumper_lit' if teacup_lit else 'lmp_bumper', bx, by, (-34, -40, 82, 86))
    sprite(cr, 'lmp_plunger', 564, 95, (-14, -27, 28, 62))
    sprite(cr, 'lmp_flipper_left', 168, 220, (-18, -18, 132, 36), rot=-math.pi / 6)
    sprite(cr, 'lmp_flipper_right', 400, 220, (-114, -18, 132, 36), rot=math.pi / 6)
    sprite(cr, 'lmp_shelf', 370, 1175, (-107, -14, 214, 40))
    for g, k in enumerate((3, 2, 4, 1, 2, 3)):
        sprite(cr, f'lmp_shelf_{g}_{k}', 274 + 32 * g, 1175, (-1, -14, 34, 40))
    for p in balls: ball(cr, *p)
    if cat:
        perch, pose = cat
        sprite(cr, f'lmp_cat_{pose}', *PERCH[perch], (-36, -26, 82, 70))
    sprite(cr, 'lmp_ramp', 368, 1000, (-136, -200, 272, 400))
    sprite(cr, 'lmp_flipper_right', 240, 985 + LOFT_LIFT, (-114, -18, 132, 36), rot=math.pi / 6, scale=56 / 96)
    for p in upper_balls: ball(cr, *p, upper=True)
    if festival: festival_lights(cr)
    if extra: extra(cr)
    return sf


def save(sf, name, crop=None, width=900):
    """Crop (world x0, y0, x1, y1) and scale to `width` px."""
    x0, y0, x1, y1 = crop or (X0, Y0, X0 + W, Y0 + H)
    (px0, py1), (px1, py0) = px(x0, y0), px(x1, y1)
    cw, ch = px1 - px0, py1 - py0
    k = width / cw
    out = cairo.ImageSurface(cairo.FORMAT_RGB24, int(width), int(ch * k))
    c = cairo.Context(out); c.scale(k, k); c.set_source_surface(sf, -px0, -py0)
    c.get_source().set_filter(cairo.FILTER_BEST); c.paint()
    out.write_to_png(os.path.join(OUT, name + '.png'))
    print('wrote', name, out.get_width(), out.get_height())


# ------------------------------------------------------------------ shot lines (world points; floor height unless lifted)
LEFT_CRADLE, RIGHT_CRADLE = (222, 196), (346, 196)
ramp_line = [LEFT_CRADLE, (328, 585), (412, 830)] + [(x, y + L.ramp_height((x, y)) * K) for x, y in L.ramp_centerline()[1:]] \
    + [(150, 1110 + LOFT_LIFT)]
right_lane = [(530, 760), (532, 1000)]
def arch_in(inset, xs):
    a = L.arch(); cx = 300
    return [(cx + (x - cx) * (280 - inset) / 280, 1000 + (y - 1000) * (270 - inset) / 270) for x, y in a if xs(x)]
right_loop = [LEFT_CRADLE, (428, 580), (505, 700)] + right_lane + list(reversed(arch_in(22, lambda x: True))) + [(42, 900), (44, 700)]
left_loop = [RIGHT_CRADLE, (128, 560), (60, 700), (42, 900)] + [p for p in arch_in(22, lambda x: x <= 372)] + [(372, 1240), (360, 1040)]
kettle_line = [RIGHT_CRADLE, (238, 585), (158, 760), (142, 885)]
fire_line = [RIGHT_CRADLE, (290, 600), (284, 735)]
alcove_line = [RIGHT_CRADLE, (290, 600), (284, 790)]
mail_line = [LEFT_CRADLE, (300, 420), (378, 628)]
plunge_line = [(564, 130), (564, 900), (566, 1000)] + list(reversed(arch_in(18, lambda x: x >= 150))) + [(150, 1215), (150, 1150 + LOFT_LIFT)]
dumbwaiter_line = [(142, 900), (142, 960), (150, 1080 + LOFT_LIFT)]
seat_line = [(212, 1003 + LOFT_LIFT), (185, 1030 + LOFT_LIFT), (122, 1104 + LOFT_LIFT)]
flap_line = [(531, 420), (531, 250)]
flap_back = [(538, 250), (538, 520), (520, 640), (470, 700)]

# ------------------------------------------------------------------ the pictures
FULL = (X0, Y0, X0 + W, Y0 + H)
UPPER = (-40, 120, 640, 1330)
BOOK = ['lmp_cozy_teapot', 'lmp_cozy_readingLamp', 'lmp_cozy_catBed']
COZY3 = ('teapot', 'readingLamp', 'catBed')

save(table(balls=[(564, 128)], cozy=COZY3, cozy_lit=3, shop_lit=2), 'lmp_howto_map', FULL, 1080)

save(table(lit={'fireplace'}, balls=[RIGHT_CRADLE], shop_lit=2,
           extra=lambda cr: (path(cr, fire_line), ring(cr, 284, 745, 46))), 'lmp_howto_req_book', (110, 130, 460, 880))
save(table(lit={'leftLoop', 'rightLoop'}, down={0, 1, 2, 3}, balls=[(222, 196)], shop_lit=2,
           extra=lambda cr: (path(cr, right_loop, 1), path(cr, left_loop[:4], 2, col=(1.0, 0.62, 0.3)))), 'lmp_howto_req_loop', UPPER)
save(table(lit={'ramp'}, balls=[(222, 196)], shop_lit=3,
           extra=lambda cr: (path(cr, ramp_line, 1), path(cr, kettle_line, 2, col=(1.0, 0.62, 0.3)))), 'lmp_howto_req_tea', UPPER)
save(table(mail=True, balls=[(222, 196)], shop_lit=3,
           extra=lambda cr: path(cr, mail_line)), 'lmp_howto_req_mail', (150, 130, 520, 720))
save(table(lit={'fireplace'}, down={0, 1, 2, 3}, balls=[RIGHT_CRADLE], shop_lit=3,
           extra=lambda cr: (path(cr, alcove_line), ring(cr, 284, 800, 26))), 'lmp_howto_fireplace', (110, 130, 460, 900))
save(table(lit={'ramp', 'kettle'}, balls=[(564, 128)], upper_balls=[(150, 1110)], shop_lit=3,
           extra=lambda cr: (path(cr, ramp_line, 1), path(cr, kettle_line + [(142, 894)], 2, col=(1.0, 0.62, 0.3)),
                             path(cr, dumbwaiter_line, None, col=(1.0, 0.62, 0.3)), path(cr, plunge_line, 3, col=(0.65, 0.9, 1.0)))),
     'lmp_howto_loft', FULL, 1000)
save(table(lit={'windowSeat'}, upper_balls=[(212, 1003)], cat=('windowSeat', 'nap'),
           extra=lambda cr: path(cr, seat_line)), 'lmp_howto_windowseat', (20, 920, 300, 1250))
save(table(lit={'leftLoop', 'rightLoop', 'ramp'}, lucky=True, balls=[(222, 196)], shop_lit=4, teacup_lit=True,
           extra=lambda cr: (path(cr, right_loop, 1), path(cr, left_loop, 2, col=(1.0, 0.62, 0.3)), ring(cr, 284, 330, 20, col=GREEN))),
     'lmp_howto_combo', FULL, 1000)
save(table(balls=[(222, 196), (430, 520)], shop_lit=6, cozy=COZY3, cozy_lit=3,
           extra=lambda cr: [ring(cr, *p, 13) for p in SHOP]), 'lmp_howto_rush', (-40, -75, 640, 700))
save(table(lit={'kettle'}, balls=[RIGHT_CRADLE], cat=('kettle', 'nap'),
           extra=lambda cr: (path(cr, kettle_line[:-1] + [(140, 905)]), ring(cr, 134, 950, 34))), 'lmp_howto_cat', (40, 130, 420, 1010))
save(table(flap=True, balls=[(531, 430)],
           extra=lambda cr: (path(cr, flap_line), path(cr, flap_back, col=GREEN), ring(cr, 531, 300, 16, col=GREEN))),
     'lmp_howto_catflap', (380, 150, 610, 760))
save(table(lit={'fireplace', 'leftLoop', 'rightLoop', 'ramp', 'kettle', 'windowSeat'}, mail=True, down={0, 1, 2, 3},
           balls=[(222, 196), (300, 480), (480, 760)], upper_balls=[(160, 1060)], shop_lit=6, teacup_lit=True, festival=True,
           cozy=COZY3, cozy_lit=3, season='winter'), 'lmp_howto_festival', FULL, 1000)
save(table(cozy=COZY3, cozy_lit=3, shop_lit=6,
           extra=lambda cr: [ring(cr, *p, 15) for p in COZY_LAMPS]), 'lmp_howto_cozy', (-40, -75, 300, 340))

# ------------------------------------------------------------------ T5 M9 v45: the Lab card's picture (420 × 750)
# The shop on a festival evening: the fire lit, the cat on her shelf, string lights in the season's colours, lamps on.
save(table(lit={'fireplace', 'leftLoop', 'rightLoop', 'ramp', 'kettle', 'windowSeat'}, mail=True, lucky=True,
           balls=[(300, 640)], upper_balls=[(170, 1060)], shop_lit=6, teacup_lit=True, festival=True,
           cozy=COZY3, cozy_lit=3, season='autumn'), 'lmp_lab_thumb', (-6, 237, 606, 1330), 420)
