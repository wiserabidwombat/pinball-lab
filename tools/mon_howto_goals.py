"""Table 04 (Monsoon) polish: the How to Play goal pictures, the same treatment as tools/lmp_howto.py (The Lamplight) and
tools/art_howto_goals.py (Grey Invasion). The table composited as the game draws it — the pencil sketch with each
painted region swapped for the watercolor through the region maps (MonPaint), the storm darkening the sky in Monsoon,
the parts in pencil or color with their region, the dust devil, captive ball, spinner, flippers and the three wires
lifted by their height (as tools/mon_howto_map.py) — with the lamps lit the way MonTableScene.updateLampStates lights
them, the shots drawn on as dashed gold paths with step numbers, and rings round what to look at. One crop per goal in
MonHowToPlay.swift, about 900 px wide.
World points, y up, 3 px per pt; the art covers world (-40,-75)-(640,1330).
Usage: python3 mon_howto_goals.py <MonArt dir (Assets.xcassets/MonArt)> <out dir> [picture names to render; default all]"""
import sys, os, math, glob
import numpy as np
import cairo
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cth_layout import RampPath

ART, OUT = sys.argv[1], sys.argv[2]
ONLY = set(sys.argv[3:])            # optional: render just these picture names
os.makedirs(OUT, exist_ok=True)
P = 3
X0, Y0, W, H = -40, -75, 680, 1405
K = 0.404                                         # oblique: drawn lift per point of height
SKY, MESAS, SAGUAROS, ARROYO, DESERT, FRAME = range(6)
GOLD = (1.0, 0.82, 0.45)                          # MonTableScene.addLamps: the shot arrows
REGION_COL = {SKY: (0.66, 0.48, 1.0), MESAS: (0.96, 0.50, 0.32), SAGUAROS: (0.52, 0.90, 0.46),
              ARROYO: (0.98, 0.74, 0.30), DESERT: (1.0, 0.90, 0.62)}
_cache = {}


def find(name):
    hits = glob.glob(os.path.join(ART, '**', name + '.*'), recursive=True)
    return [h for h in hits if h.endswith(('.png', '.jpg'))][0]


def pil(name):
    if name not in _cache: _cache[name] = Image.open(find(name)).convert('RGBA')
    return _cache[name]


def px(x, y): return ((x - X0) * P, (Y0 + H - y) * P)


# ---------------------------------------------------------------------------------------------------- MonTableLayout
ARROWS = {"mesaRamp": ((336.3, 532), 70.8), "orbit": ((121.4, 722.7), 113.8), "arroyo": ((284, 582), 90),
          "saguaros": ((411.1, 493.2), 54.3)}
CAP_M, CAP_H, CAP_LEN = (100, 592), math.radians(120), 82
ARROWS["captive"] = ((CAP_M[0] - 50 * math.cos(CAP_H), CAP_M[1] - 50 * math.sin(CAP_H)), 120)
DD = (284, 470)                                   # dust devil centre
DROPS = [(DD[0] + 60 * math.sin(i * 2 * math.pi / 5), DD[1] + 60 * math.cos(i * 2 * math.pi / 5)) for i in range(5)]
HELIX_LAMP, SHOOT_AGAIN, SUPERBLOOM = (364, 550), (284, 150), (284, 335)
KICKBACK, OUTLANE_SAVE = (37, 300), (531, 300)
LANES = [238, 274, 310]; LANE_LIGHT_Y = 1205
BUMPERS = [(210, 1050), (338, 1050), (274, 950)]
STANDUPS = [590, 560, 530]; STANDUP_X = 464
L_CRADLE, R_CRADLE = (222, 200), (346, 200)        # a ball resting on each flipper, near the tip


# ---------------------------------------------------------------------------------------------------- the wires
CLIMB = math.atan2(260, 90)


def sbend(p, x):
    shift = x - p.pts[-1][0]
    if abs(shift) <= 0.5: return
    b = math.acos(1 - min(abs(shift), 119) / 120); t = b if shift > 0 else -b
    p.arc(60, t); p.arc(60, -t)


def high():
    p = RampPath((360, 600), CLIMB); p.line(math.hypot(90, 260)); p.arc(40, math.pi - CLIMB + math.radians(8))
    apex = p.length; p.line(262); p.arc(40, math.radians(82)); p.line(150); sbend(p, 69); p.line(p.pts[-1][1] - 490)
    return p, lambda s: (90 * math.sin(min(max(s, 0) / 275, 1) * math.pi / 2) if s <= apex
                         else 90 + (12 - 90) * min((s - apex) / max(p.length - apex, 1), 1))


def low():
    p = RampPath((284, 650), math.pi - CLIMB); p.line(math.hypot(90, 260)); p.arc(36, -(math.pi - CLIMB) - math.radians(8))
    apex = p.length; p.line(250); p.arc(36, -math.radians(82)); p.line(150); sbend(p, 499); p.line(p.pts[-1][1] - 490)
    return p, lambda s: (40 * math.sin(min(max(s, 0) / 110, 1) * math.pi / 2) if s <= apex
                         else 40 + (10 - 40) * min((s - apex) / max(p.length - apex, 1), 1))


def helix():
    start = (450, 860); r = 80
    p = RampPath(start, CLIMB); p.line((516 - start[0] - r * (1 - math.sin(CLIMB))) / math.cos(CLIMB))
    p.arc(r, math.pi / 2 - CLIMB); apex = p.length
    p.arc(48, 3 * math.pi); p.arc(40, -math.radians(70)); p.line(20)
    return p, lambda s: (90 + 10 * math.sin(min(max(s, 0) / apex, 1) * math.pi / 2) if s <= apex
                         else 100 - 100 * min((s - apex) / max(p.length - apex, 1), 1))


WIRES = {'high': high(), 'low': low(), 'helix': helix()}


def lifted(name, s0=0.0, s1=1e9, step=1):
    """Points along a wire from distance s0 to s1, drawn lifted by height (as the game draws the ball riding it)."""
    p, hf = WIRES[name]
    return [(x, y + hf(s) * K) for (x, y), s in zip(p.pts[::step], p.ds[::step]) if s0 <= s <= s1]


# ---------------------------------------------------------------------------------------------------- the table (PIL)
def painting(painted, storm):
    """The playfield art: sketch, with the painted regions in watercolor (hard region edges, as a full fill)."""
    canvas = Image.new('RGBA', (W * P, H * P), (0, 0, 0, 255))
    for half, top, rows in (('upper', 0, 805), ('lower', 805, 600)):
        sk = np.array(pil(f'mon_{half}_sketch').resize((680 * P, rows * P)))
        pt = np.array(pil(f'mon_{half}').resize((680 * P, rows * P)))
        r = np.array(pil(f'mon_{half}_regions').resize((680 * P, rows * P), Image.NEAREST))
        idx = (r[..., 0] > 127) * 1 + (r[..., 1] > 127) * 2 + (r[..., 2] > 127) * 4
        m = np.isin(idx, list(painted))[..., None]
        canvas.paste(Image.fromarray(np.where(m, pt, sk).astype(np.uint8)), (0, top * P))
    if storm > 0:                                 # the storm layer: dark violet cropped to the sky (mon_sky_mask)
        a = np.array(pil('mon_sky_mask').resize((680 * P, 805 * P)))[..., 3].astype(float) * storm
        lay = np.zeros((805 * P, 680 * P, 4), np.uint8); lay[..., :3] = (23, 15, 41); lay[..., 3] = a.astype(np.uint8)
        canvas.alpha_composite(Image.fromarray(lay), (0, 0))
    return canvas


def floor_toys(canvas):
    over = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); d = ImageDraw.Draw(over)
    cx, cy = DD; R = 40
    d.ellipse([*px(cx - R - 2, cy + R + 2), *px(cx + R + 2, cy - R - 2)], fill=(60, 45, 40, 110))
    d.ellipse([*px(cx - R, cy + R), *px(cx + R, cy - R)], fill=(222, 196, 150, 235), outline=(110, 85, 60, 200), width=4)
    for rr in (27, 14):
        d.ellipse([*px(cx - rr, cy + rr), *px(cx + rr, cy - rr)], outline=(176, 142, 100, 200), width=3)
    for k in range(5):
        pts = []
        for i in range(14):
            t = i / 13; a = k * 2 * math.pi / 5 + t * 2.4; r = 6 + t * (R - 8)
            pts.append(px(cx + r * math.cos(a), cy + r * math.sin(a)))
        d.line(pts, fill=(140, 105, 70, 230), width=12, joint='curve'); d.line(pts, fill=(250, 232, 196, 255), width=4, joint='curve')
    m = CAP_M; ax_, ay_ = math.cos(CAP_H), math.sin(CAP_H); nx, ny = -ay_, ax_; hw = 10.5
    end = (m[0] + ax_ * CAP_LEN, m[1] + ay_ * CAP_LEN)
    d.polygon([px(m[0] + nx * hw, m[1] + ny * hw), px(end[0] + nx * hw, end[1] + ny * hw),
               px(end[0] - nx * hw, end[1] - ny * hw), px(m[0] - nx * hw, m[1] - ny * hw)], fill=(70, 58, 92, 235))
    for s in (1, -1):
        a = px(m[0] + s * nx * hw, m[1] + s * ny * hw); b = px(end[0] + s * nx * hw, end[1] + s * ny * hw)
        d.line([a, b], fill=(20, 16, 30, 200), width=16); d.line([a, b], fill=(196, 200, 210, 255), width=9); d.line([a, b], fill=(250, 250, 255, 255), width=3)
    bc = (m[0] + ax_ * 9, m[1] + ay_ * 9)
    d.ellipse([*px(bc[0] - 9, bc[1] + 9), *px(bc[0] + 9, bc[1] - 9)], fill=(190, 194, 205, 255), outline=(40, 36, 50, 255), width=3)
    d.ellipse([*px(bc[0] - 5, bc[1] + 6), *px(bc[0] - 1, bc[1] + 2)], fill=(255, 255, 255, 230))
    canvas.alpha_composite(over)


def put(canvas, im, ox, oy, box, rot=0.0):
    x0, y0, w, h = box
    im = im.resize((round(w * P), round(h * P)), Image.LANCZOS)
    if rot:
        cx, cy = -x0 * P, (h + y0) * P
        R = int(max(w, h) * P * 1.6); c = Image.new('RGBA', (2 * R, 2 * R)); c.paste(im, (R - int(cx), R - int(cy)))
        im = c.rotate(math.degrees(rot), resample=Image.BICUBIC)
        canvas.alpha_composite(im, (int((ox - X0) * P - R), int((Y0 + H - oy) * P - R))); return
    canvas.alpha_composite(im, (int((ox + x0 - X0) * P), int((Y0 + H - (oy + y0 + h)) * P)))


def parts(painted, bumpers_lit, standups_lit):
    top = Image.new('RGBA', (W * P, H * P), (0, 0, 0, 0))
    for (bx, by) in BUMPERS:
        nm = 'mon_bumper_lit' if bumpers_lit else ('mon_bumper' if SKY in painted else 'mon_bumper_sketch')
        put(top, pil(nm), bx, by, (-40, -48, 96, 100))
    for i, y in enumerate(STANDUPS):
        nm = 'mon_standup_lit' if i in standups_lit else ('mon_standup' if SAGUAROS in painted else 'mon_standup_sketch')
        put(top, pil(nm), STANDUP_X, y, (-14, -18, 30, 42))
    sheet = pil('mon_spinner_sheet'); fw, fh = sheet.width // 6, sheet.height // 4
    put(top, sheet.crop((0, 0, fw, fh)), 39, 935, (-22, -10, 44, 32))
    put(top, pil('mon_flipper_left'), 179, 220, (-18, -18, 132, 36), rot=math.radians(-30))
    put(top, pil('mon_flipper_right'), 389, 220, (-114, -18, 132, 36), rot=math.radians(30))
    put(top, pil('mon_flipper_upper'), 528, 800, (-76, -15, 91, 30), rot=math.radians(30))
    chrome = ((20, 16, 30, 170), (200, 204, 214, 255), (252, 252, 255, 255))
    brass = ((20, 16, 30, 170), (190, 150, 80, 255), (255, 232, 170, 255))
    allp = []
    for name, cols, plastic, half in (('low', brass, 0, 5.5), ('high', chrome, 275, 8), ('helix', chrome, 0, 5.5)):
        p, hf = WIRES[name]
        for i in range(1, len(p.pts)):
            (ax, ay), (bx, by) = p.pts[i - 1], p.pts[i]; s = p.ds[i]; hh = hf(s)
            hd = p.hd[i]; ox, oy = -math.sin(hd) * half, math.cos(hd) * half
            h0 = hf(p.ds[i - 1]) * K
            allp.append((hh, [(ax + ox, ay + oy + h0), (bx + ox, by + oy + hh * K)],
                         [(ax - ox, ay - oy + h0), (bx - ox, by - oy + hh * K)], cols, s <= plastic))
    allp.sort(key=lambda q: q[0])
    for hh, a, b, (ink, metal, hi), plastic in allp:
        o = Image.new('RGBA', top.size, (0, 0, 0, 0)); g = ImageDraw.Draw(o)
        A = [px(*q) for q in a]; B = [px(*q) for q in b]
        if plastic: g.polygon([A[0], A[1], B[1], B[0]], fill=(240, 196, 120, 80))
        for line in (A, B):
            g.line(line, fill=ink, width=13); g.line(line, fill=metal, width=7); g.line(line, fill=hi, width=2)
        top.alpha_composite(o)
    return top


def to_cairo(im):
    a = np.array(im.convert('RGBA')).astype(np.uint16)
    al = a[..., 3:4]
    pre = (a[..., :3] * al // 255).astype(np.uint8)
    bgra = np.dstack([pre[..., 2], pre[..., 1], pre[..., 0], a[..., 3].astype(np.uint8)]).copy()
    return cairo.ImageSurface.create_for_data(bytearray(bgra.tobytes()), cairo.FORMAT_ARGB32, im.width, im.height)


# ---------------------------------------------------------------------------------------------------- lamps (cairo, world coords)
def lamp_path(cr, shape, x, y, ang, k=1.0):
    cr.save(); cr.translate(x, y); cr.rotate(ang); cr.scale(k, k)
    kind = shape[0]
    if kind == 'arrow':
        ln, wd = shape[1], shape[2]
        cr.move_to(ln / 2, 0); cr.line_to(-ln / 2, wd / 2); cr.line_to(-ln / 2 + 6, 0); cr.line_to(-ln / 2, -wd / 2)
        cr.close_path()
    elif kind == 'round':
        cr.arc(0, 0, shape[1], 0, 2 * math.pi)
    elif kind == 'drop':                          # MonRollover's raindrop, point up, ~9 pt tall
        cr.move_to(0, 6.5); cr.curve_to(2.3, 5.2, 3.6, 2.0, 3.8, -1.2)
        cr.arc_negative(0, -1.2, 3.8, 0, math.pi); cr.curve_to(-3.6, 2.0, -2.3, 5.2, 0, 6.5); cr.close_path()
    else:
        for i in range(10):
            r = shape[1] if i % 2 == 0 else shape[2]
            a = math.pi / 2 + i * math.pi / 5
            (cr.move_to if i == 0 else cr.line_to)(r * math.cos(a), r * math.sin(a))
        cr.close_path()
    cr.restore()


def lamp(cr, shape, x, y, ang, col, lit):
    """MonLamp: off = a dim tinted insert in a dark socket; lit = full colour, a halo and a near-white core."""
    lamp_path(cr, shape, x, y, ang, 1.25); cr.set_source_rgba(0.06, 0.05, 0.10, 0.55); cr.fill()
    if lit:
        lamp_path(cr, shape, x, y, ang, 2.6); cr.set_source_rgba(*col, 0.30); cr.fill()
        lamp_path(cr, shape, x, y, ang, 1.9); cr.set_source_rgba(*col, 0.55); cr.fill()
    k = 1.0 if lit else 0.45
    lamp_path(cr, shape, x, y, ang); cr.set_source_rgba(col[0] * k, col[1] * k, col[2] * k, 1.0 if lit else 0.30); cr.fill()
    lamp_path(cr, shape, x, y, ang); cr.set_source_rgba(*col, 0.7); cr.set_line_width(1); cr.stroke()
    if lit:
        lamp_path(cr, shape, x, y, ang, 0.45); cr.set_source_rgba(1, 1, 0.95, 0.9); cr.fill()


def ball(cr, x, y, h=0.0):
    r = 9 * (1 + 0.12 * min(h / 90, 1))
    if h > 0:
        cr.arc(x + 2, y - 2, r * 0.9, 0, 2 * math.pi); cr.set_source_rgba(0, 0, 0, 0.3); cr.fill()
    y += h * K
    cr.arc(x + 1.2, y - 1.5, r, 0, 2 * math.pi); cr.set_source_rgba(0, 0, 0, 0.35); cr.fill()
    g = cairo.RadialGradient(x - r * 0.35, y + r * 0.4, r * 0.1, x, y, r)
    g.add_color_stop_rgb(0, 1, 1, 1); g.add_color_stop_rgb(0.35, 0.82, 0.83, 0.86)
    g.add_color_stop_rgb(0.8, 0.42, 0.43, 0.47); g.add_color_stop_rgb(1, 0.22, 0.22, 0.25)
    cr.arc(x, y, r, 0, 2 * math.pi); cr.set_source(g); cr.fill()


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
    if num is not None: badge(cr, *pts[0], num, col)


def badge(cr, x, y, num, col=(1.0, 0.86, 0.35)):
    cr.arc(x, y, 9, 0, 6.29); cr.set_source_rgb(0.1, 0.05, 0.0); cr.fill()
    cr.arc(x, y, 7.5, 0, 6.29); cr.set_source_rgb(*col); cr.fill()
    cr.save(); cr.translate(x, y); cr.scale(1, -1)
    cr.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); cr.set_font_size(11)
    e = cr.text_extents(str(num)); cr.move_to(-e.x_advance / 2, e.height / 2)
    cr.set_source_rgb(0.1, 0.05, 0.0); cr.show_text(str(num)); cr.restore()


def ring(cr, x, y, r, col=(1.0, 0.86, 0.35)):
    cr.arc(x, y, r, 0, 6.29); cr.set_source_rgba(0.1, 0.05, 0.0, 0.7); cr.set_line_width(5); cr.stroke()
    cr.arc(x, y, r, 0, 6.29); cr.set_source_rgb(*col); cr.set_line_width(2.6); cr.set_dash([7, 5]); cr.stroke(); cr.set_dash([])


# ---------------------------------------------------------------------------------------------------- one table state
def table(painted=(), storm=0.0, arrows=None, drops=None, helix_lamp=False, shoot_again=False, superbloom=False,
          kickback=False, outlane=False, lanes=(), bumpers_lit=False, standups_lit=(), balls=(), extra=None):
    """The whole table in a state. arrows=None: lit by Act 1's rule (blinking while their region needs color).
    drops=None: lit for each painted region. Blinking lamps are drawn lit."""
    painted = set(painted)
    if arrows is None:
        need = {"orbit": SKY, "mesaRamp": MESAS, "saguaros": SAGUAROS, "captive": SAGUAROS, "arroyo": ARROYO}
        arrows = {n for n, r in need.items() if r not in painted}
    if drops is None: drops = painted
    base = painting(painted, storm); floor_toys(base)
    sf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W * P, H * P)
    cr = cairo.Context(sf)
    cr.set_source_surface(to_cairo(base), 0, 0); cr.paint()
    cr.save(); cr.translate(-X0 * P, (Y0 + H) * P); cr.scale(P, -P)
    for name, ((x, y), a) in ARROWS.items():
        lamp(cr, ('arrow', 24, 18), x, y, math.radians(a), GOLD, name in arrows)
    for i, p in enumerate(DROPS): lamp(cr, ('round', 7), *p, 0, REGION_COL[i], i in drops)
    lamp(cr, ('round', 6), *HELIX_LAMP, 0, (1.0, 0.62, 0.25), helix_lamp)
    lamp(cr, ('round', 9), *SHOOT_AGAIN, 0, (0.55, 0.80, 1.0), shoot_again)
    lamp(cr, ('star', 20, 8.5), *SUPERBLOOM, 0, (1.0, 0.52, 0.76), superbloom)
    lamp(cr, ('round', 9), *KICKBACK, 0, (1.0, 0.54, 0.24), kickback)
    lamp(cr, ('round', 9), *OUTLANE_SAVE, 0, (0.28, 0.88, 0.78), outlane)
    for i, x in enumerate(LANES):
        lit = i in lanes
        if lit:
            g = cairo.RadialGradient(x, LANE_LIGHT_Y, 0, x, LANE_LIGHT_Y, 14)
            g.add_color_stop_rgba(0, 0.62, 0.84, 1.0, 0.6); g.add_color_stop_rgba(1, 0.62, 0.84, 1.0, 0)
            cr.arc(x, LANE_LIGHT_Y, 14, 0, 6.29); cr.set_source(g); cr.fill()
        lamp_path(cr, ('drop',), x, LANE_LIGHT_Y, 0, 1.0)
        cr.set_source_rgba(*((0.62, 0.84, 1.0, 1) if lit else (0.30, 0.34, 0.42, 0.85))); cr.fill()
    cr.restore()
    cr.set_source_surface(to_cairo(parts(painted, bumpers_lit, standups_lit)), 0, 0); cr.paint()
    cr.translate(-X0 * P, (Y0 + H) * P); cr.scale(P, -P)
    for b in balls: ball(cr, *b)
    if extra: extra(cr)
    return sf


def save(sf, name, crop, width=900):
    """crop = world (x0, y0, x1, y1); written as a PNG about `width` px wide."""
    if ONLY and name not in ONLY: return
    x0, y0, x1, y1 = crop
    y1 = min(y1, Y0 + H); y0 = max(y0, Y0); x0 = max(x0, X0); x1 = min(x1, X0 + W)
    (ax, ay), (bx, by) = px(x0, y1), px(x1, y0)
    w, h = int(bx - ax), int(by - ay)
    sub = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    c = cairo.Context(sub); c.set_source_surface(sf, -ax, -ay); c.paint()
    k = width / w
    out = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, int(h * k))
    c = cairo.Context(out); c.scale(k, k); c.set_source_surface(sub, 0, 0); c.get_source().set_filter(cairo.FILTER_BEST); c.paint()
    out.write_to_png(os.path.join(OUT, name + '.png'))
    print(name, out.get_width(), out.get_height())


# ---------------------------------------------------------------------------------------------------- shots
def shot_orbit():                                 # right flipper → orbit funnel → up the left lane → round the top
    return [R_CRADLE, (190, 520), ARROWS["orbit"][0], (75, 860), (39, 960), (40, 1080), (62, 1190), (130, 1255), (230, 1268)]


def shot_mesa():                                  # left flipper → mesa ramp → up to the gate at its top
    return [L_CRADLE, (300, 430), ARROWS["mesaRamp"][0]] + lifted('high', 0, 270, 3)


def shot_mesa_highwire():
    return [L_CRADLE, (300, 430), ARROWS["mesaRamp"][0]] + lifted('high', 0, 1e9, 3)


def shot_helix():                                 # mesa ramp with the gate thrown → the helix
    return [L_CRADLE, (300, 430), ARROWS["mesaRamp"][0]] + lifted('high', 0, 270, 3) + lifted('helix', 0, 1e9, 2)


def shot_arroyo(start=R_CRADLE):
    return [start, ((start[0] + 284) / 2, 400), ARROWS["arroyo"][0], (284, 640)]


def shot_saguaros():
    return [L_CRADLE, (330, 380), ARROWS["saguaros"][0], (452, 552)]


def shot_captive():
    return [R_CRADLE, (220, 420), ARROWS["captive"][0], (CAP_M[0] + 4, CAP_M[1] - 8)]


UPPER = (-40, 440, 640, 1330)                     # the whole upper table
ALL = set(range(5))

# 1. Sky: the orbit, the raindrop lanes, the bumpers (sky painted part-way: the sky's drop blinks)
def x_sky(cr):
    path(cr, shot_orbit(), 1)
    ring(cr, 274, 1180, 62); ring(cr, 274, 1010, 108)
    badge(cr, 274 + 70, 1215, 2); badge(cr, 274 + 116, 1060, 3)
save(table(painted=(), drops={SKY}, lanes=(0, 2), balls=[R_CRADLE], extra=x_sky), 'mon_goal_sky', (-40, 150, 640, 1330))

# 2. Mesas: the mesa ramp and the helix (sky done)
def x_mesas(cr):
    path(cr, shot_mesa(), 1)
    ring(cr, 500, 1090, 80); badge(cr, 430, 1150, 2)
save(table(painted={SKY}, drops={SKY, MESAS}, balls=[L_CRADLE], extra=x_mesas), 'mon_goal_mesas', (60, 150, 640, 1250))

# 3. Saguaros: the standups and the captive ball
def x_sag(cr):
    path(cr, shot_saguaros(), 1); path(cr, shot_captive(), 2)
    ring(cr, 464, 560, 52); ring(cr, 66, 655, 40)
save(table(painted={SKY, MESAS}, drops={SKY, MESAS, SAGUAROS}, standups_lit={0}, balls=[L_CRADLE, R_CRADLE], extra=x_sag),
     'mon_goal_saguaros', (-30, 150, 600, 760))

# 4. Arroyo: the hole, then the low wire
def x_arroyo(cr):
    path(cr, shot_arroyo(), 1)
    path(cr, lifted('low', 30, 1e9, 3), 2, col=(1.0, 0.95, 0.75))
save(table(painted={SKY, MESAS, SAGUAROS}, drops={SKY, MESAS, SAGUAROS, ARROYO}, outlane=True, balls=[R_CRADLE],
           extra=x_arroyo), 'mon_goal_arroyo', (60, 150, 640, 1300))

# 5. Desert: the bumpers (every 10th hit) and the dust devil
def x_desert(cr):
    ring(cr, 274, 1010, 108); ring(cr, *DD, 50)
    badge(cr, 274 + 116, 1060, 1); badge(cr, DD[0] + 58, DD[1] - 40, 2)
    path(cr, [(150, 330), (230, 440), (300, 480), (360, 610)], None)
save(table(painted={SKY, MESAS, SAGUAROS, ARROYO}, drops={SKY, MESAS, SAGUAROS, ARROYO, DESERT}, outlane=True,
           bumpers_lit=True, extra=x_desert), 'mon_goal_desert', (60, 300, 520, 1160))

# 6. Monsoon lit: three regions painted, the arroyo arrow fast-blinks (sky darkening a little)
lit3 = {SKY, MESAS, SAGUAROS}
def x_mlit(cr):
    path(cr, shot_arroyo(L_CRADLE), 1); ring(cr, 284, 650, 30)
save(table(painted=lit3, storm=0.18, arrows={"arroyo"},
           outlane=True, balls=[L_CRADLE], extra=x_mlit), 'mon_goal_monsoon', (40, 150, 560, 900))

# 7. Wildflowers: Monsoon running — the gate throws to the helix (helix lamp on), the mesa ramp arrow is the jackpot
def x_wild(cr):
    path(cr, shot_helix(), 1)
    ring(cr, *HELIX_LAMP, 16)
save(table(painted=lit3, storm=0.45, arrows={"mesaRamp", "arroyo"}, helix_lamp=True, shoot_again=True, outlane=True,
           balls=[L_CRADLE, (300, 330)], extra=x_wild), 'mon_goal_wildflowers', (60, 150, 640, 1250))

# 8. Superbloom lit: everything painted, the star blinks, the arroyo starts it
def x_slit(cr):
    path(cr, shot_arroyo(), 1); ring(cr, *SUPERBLOOM, 30)
save(table(painted=ALL, arrows={"arroyo"}, superbloom=True, outlane=True, balls=[R_CRADLE], extra=x_slit),
     'mon_goal_superbloom_lit', (40, 150, 560, 900))

# 9. Superbloom running: every shot lit (15,000 each), the helix the super jackpot, petals falling
def petals(cr, n=70, seed=4):
    import random
    rnd = random.Random(seed)
    for _ in range(n):
        x, y = rnd.uniform(40, 540), rnd.uniform(250, 1250); a = rnd.uniform(0, math.pi)
        cr.save(); cr.translate(x, y); cr.rotate(a); cr.scale(3.4, 2.2)
        cr.arc(0, 0, 1, 0, 6.29); cr.restore()
        cr.set_source_rgba(1.0, 0.62 + rnd.uniform(-0.08, 0.08), 0.82, 0.9); cr.fill()
def x_sb(cr):
    petals(cr)
    path(cr, shot_orbit()[:3] + [(90, 800)])
    path(cr, [L_CRADLE, (300, 430), ARROWS["mesaRamp"][0], (352, 585)])
    path(cr, shot_arroyo(L_CRADLE))
    path(cr, shot_saguaros())
    path(cr, shot_captive())
    path(cr, lifted('helix', 0, 1e9, 2), col=(1.0, 0.6, 0.85)); ring(cr, 500, 1090, 80, col=(1.0, 0.6, 0.85))
save(table(painted=ALL, arrows=set(ARROWS), superbloom=True, helix_lamp=True, shoot_again=True, outlane=True,
           balls=[L_CRADLE, R_CRADLE, (250, 760)], extra=x_sb), 'mon_goal_superbloom', (-40, 150, 640, 1330))

# 10. Saving your ball: shoot again, kickback, outlane save
def x_save(cr):
    ring(cr, *SHOOT_AGAIN, 20); ring(cr, *KICKBACK, 20); ring(cr, *OUTLANE_SAVE, 20)
    badge(cr, SHOOT_AGAIN[0] + 26, SHOOT_AGAIN[1] + 16, 1); badge(cr, KICKBACK[0] + 26, KICKBACK[1] + 16, 2)
    badge(cr, OUTLANE_SAVE[0] - 26, OUTLANE_SAVE[1] + 16, 3)
save(table(painted={SKY, SAGUAROS}, shoot_again=True, kickback=True, outlane=True, standups_lit={0, 1, 2},
           extra=x_save), 'mon_goal_saves', (-40, 80, 640, 640))

# 11. Multiplier: the raindrop lanes, all three lit
def x_lanes(cr):
    ring(cr, 274, 1180, 62)
save(table(painted={SKY}, lanes=(0, 1, 2), extra=x_lanes), 'mon_goal_lanes', (120, 1040, 430, 1330))
