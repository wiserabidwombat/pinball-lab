"""Table 03 (Cthulhu Rising) polish: the How to Play goal pictures. The baked table and every part sprite composited the
way the game draws them (cth_lower + cth_upper, the ramps, bumpers, Sigil targets, magnet, spinner, plunger, flippers and,
when he's up, Cthulhu with his tentacles), with the lamps lit the way CthTableScene.updateLampStates() lights them and the
shots drawn on as dashed gold paths (step numbers where order matters) and dashed rings round what to look at.
Positions and boxes come from CthTableLayout / CthCthulhu (copied below); the flipper angles match cth_howto_map.py.
Reads the art from a CthArt folder (Assets.xcassets/CthArt or a copy). World points, y up, 3 px per pt.
Usage: python3 cth_howto_goals.py <CthArt dir> <out dir>"""
import sys, os, math, glob
import cairo

ART, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
PX = 3
X0, Y0, W, H = -40, -75, 680, 1405
_cache = {}

# ------------------------------------------------------------------ CthTableLayout
LOWER_RECT = (-40, -75, 680, 600)
UPPER_RECT = (-40, 525, 680, 805)
RAMP_RECT = (53, 467, 519, 503)
BUMPER_BOX = (-40, -48, 96, 100); BUMPERS = [(210, 1050), (338, 1050), (274, 950)]
TARGET_BOX = (-16, -24, 42, 58); TARGET_X, TARGET_YS = 464, [595, 565, 535, 505]
MAGNET_BOX = (-20, -20, 46, 42); RITUAL = (284, 470)
SPINNER_BOX = (-22, -10, 44, 32); SPINNER = (39, 935)
PLUNGER = (564, 95); PLUNGER_BOX = (-12, -25, 24, 50)
LAGOON = (452, 1030)
CTHULHU_BOX = (-30, -33, 72, 64)
TENTACLE_BOXES = [(-30, -11, 38, 24), (-30, -19, 40, 28), (-17, -11, 33, 52), (-6, -19, 37, 28), (-3, -11, 35, 24)]
TENTACLE_BASES = [(-80, 19), (-45, 19), (180, 12), (45, 19), (80, 19)]
CUTTABLE = [0, 1, 3, 4]                      # the Awakening's four tentacles; the middle one always stays
EYES = [(-5.8, -8.3), (5.8, -8.3)]
LANE_XS = [238, 274, 310]; FLAME_Y = 1156    # the Candle lanes (lanePostXs midpoints) and their printed flames
LIBRARY = (284, 650)

SEA = (0.30, 0.92, 0.80); PARCH = (0.98, 0.80, 0.40); FLAME = (1.0, 0.55, 0.20)
ELDRITCH = (0.72, 0.42, 1.0); TGREEN = (0.40, 0.95, 0.45); BRASS = (0.91, 0.76, 0.35)
ARROWS = {"rightRamp": ((336.3, 532), 70.8), "orbit": ((121.4, 722.7), 113.8), "library": ((284, 582), 90),
          "sigil": ((411.1, 493.2), 54.3), "lagoon": ((467, 962), 102.6)}
TOMES = [(260, 615), (284, 615), (308, 615)]
CANDLES = [(RITUAL[0] + 54 * math.cos(math.pi / 2 - i * 2 * math.pi / 5),
            RITUAL[1] + 54 * math.sin(math.pi / 2 - i * 2 * math.pi / 5)) for i in range(5)]
RITUAL_SHOTS = ["orbit", "rightRamp", "library", "lagoon", "sigil"]      # CthCampaign.ritualShots = candle order
EYE_LAMPS = [(430, 1070), (452, 1076), (474, 1070)]
TENTACLE_LAMPS = [(414, 996), (438, 989), (466, 989), (490, 996)]
KICKBACK = (37, 300); OUTLANE_SAVE = (568 - 37, 300); ELDER = (284, 312)


def img(name):
    if name not in _cache:
        hits = glob.glob(os.path.join(ART, '**', name + '.png'), recursive=True)
        _cache[name] = cairo.ImageSurface.create_from_png(hits[0]) if hits else None
    return _cache[name]


def px(x, y):
    return (x - X0) * PX, (Y0 + H - y) * PX


def sprite(cr, name, ax, ay, box, rot=0.0, alpha=1.0, op=None, src=None):
    """Paint sprite `name` with its box (minX, minY, w, h) round world anchor (ax, ay); rot = SpriteKit zRotation."""
    s = src or img(name)
    if s is None: return
    bx, by, bw, bh = box
    cr.save()
    cr.identity_matrix()
    cx, cy = px(ax, ay)
    cr.translate(cx, cy)
    cr.rotate(-rot)
    cr.translate(bx * PX, -(by + bh) * PX)
    cr.scale(bw * PX / s.get_width(), bh * PX / s.get_height())
    cr.set_source_surface(s, 0, 0)
    cr.get_source().set_filter(cairo.FILTER_BEST)
    if op is not None: cr.set_operator(op)
    cr.paint_with_alpha(alpha)
    cr.restore()


def spinner_frame():
    s = img('cth_spinner_sheet')
    fw, fh = s.get_width() // 6, s.get_height() // 4
    out = cairo.ImageSurface(cairo.FORMAT_ARGB32, fw, fh)
    c = cairo.Context(out); c.set_source_surface(s, 0, 0); c.paint()
    return out


def lamp_path(cr, shape, x, y, ang, k=1.0):
    cr.save(); cr.translate(x, y); cr.rotate(math.radians(ang)); cr.scale(k, k)
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


def lamp(cr, shape, x, y, ang, col):
    """A lit painted CthLamp: the insert is in the art, so only the light is drawn (additive fill + halo).
    A shade brighter than one frame of the game so a still picture reads as lit."""
    cr.save(); cr.set_operator(cairo.OPERATOR_ADD)
    lamp_path(cr, shape, x, y, ang, 2.4); cr.set_source_rgba(*col, 0.22); cr.fill()
    lamp_path(cr, shape, x, y, ang, 1.6); cr.set_source_rgba(*col, 0.40); cr.fill()
    lamp_path(cr, shape, x, y, ang); cr.set_source_rgba(*col, 0.85); cr.fill()
    lamp_path(cr, shape, x, y, ang, 0.5); cr.set_source_rgba(1, 1, 0.95, 0.5); cr.fill()
    if shape[0] == 'arrow':                   # a teal arrow over teal art needs more white to read as lit
        lamp_path(cr, shape, x, y, ang, 0.8); cr.set_source_rgba(0.6, 0.7, 0.65, 0.6); cr.fill()
    cr.restore()


def flame(cr, x, y):
    """A lit Candle lane: CthRollover's additive halo and teardrop flame over the printed candle."""
    cr.save(); cr.set_operator(cairo.OPERATOR_ADD); cr.translate(x, y)
    cr.arc(0, 0, 11, 0, 6.29); cr.set_source_rgba(1.0, 0.62, 0.20, 0.30); cr.fill()
    cr.arc(0, 0, 18, 0, 6.29); cr.set_source_rgba(1.0, 0.62, 0.20, 0.12); cr.fill()
    def tongue(k, dy=0.0):
        cr.save(); cr.translate(0, dy); cr.scale(k, k)
        cr.move_to(0, 8); cr.curve_to(2.1, 6.3, 3.6, 3.5, 3.6, -1.5)
        cr.arc_negative(0, -1.5, 3.6, 0, math.pi)
        cr.curve_to(-3.6, 3.5, -2.1, 6.3, 0, 8); cr.close_path(); cr.restore()
    tongue(1); cr.set_source_rgb(1.0, 0.66, 0.22); cr.fill()
    tongue(0.5, -1.5); cr.set_source_rgb(1.0, 0.95, 0.75); cr.fill()
    cr.restore()


def ball(cr, x, y):
    r = 9
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
    if num is not None:
        badge(cr, *pts[0], num, col)


def badge(cr, x, y, num, col=(1.0, 0.86, 0.35)):
    cr.arc(x, y, 9, 0, 6.29); cr.set_source_rgb(0.1, 0.05, 0.0); cr.fill()
    cr.arc(x, y, 7.5, 0, 6.29); cr.set_source_rgb(*col); cr.fill()
    cr.save(); cr.translate(x, y); cr.scale(1, -1)
    cr.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); cr.set_font_size(11)
    e = cr.text_extents(str(num)); cr.move_to(-e.x_advance / 2 - e.x_bearing, e.height / 2)
    cr.set_source_rgb(0.1, 0.05, 0.0); cr.show_text(str(num)); cr.restore()


def ring(cr, x, y, r, col=(1.0, 0.86, 0.35)):
    cr.arc(x, y, r, 0, 6.29); cr.set_source_rgba(0.1, 0.05, 0.0, 0.7); cr.set_line_width(5); cr.stroke()
    cr.arc(x, y, r, 0, 6.29); cr.set_source_rgb(*col); cr.set_line_width(2.6); cr.set_dash([7, 5]); cr.stroke(); cr.set_dash([])


def oval(cr, x0, y0, x1, y1, col=(1.0, 0.86, 0.35)):
    """A dashed rounded box round a group (the Candle lanes, the Sigil bank)."""
    r = min(12, (x1 - x0) / 2, (y1 - y0) / 2)
    def shape():
        cr.new_sub_path()
        cr.arc(x1 - r, y1 - r, r, 0, math.pi / 2); cr.arc(x0 + r, y1 - r, r, math.pi / 2, math.pi)
        cr.arc(x0 + r, y0 + r, r, math.pi, 1.5 * math.pi); cr.arc(x1 - r, y0 + r, r, 1.5 * math.pi, 2 * math.pi)
        cr.close_path()
    shape(); cr.set_source_rgba(0.1, 0.05, 0.0, 0.7); cr.set_line_width(5); cr.stroke()
    shape(); cr.set_source_rgb(*col); cr.set_line_width(2.6); cr.set_dash([7, 5]); cr.stroke(); cr.set_dash([])


# ------------------------------------------------------------------ the table
def table(arrows=(), tomes=(), candles=(), eyes=(), tentacle_lamps=(), down=(), lanes=(), kickback=False, save=False,
          elder=False, cthulhu=False, cut=(), balls=(), extra=None):
    sf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W * PX, H * PX)
    cr = cairo.Context(sf)
    cr.set_source_rgb(0, 0, 0); cr.paint()
    for name, (rx, ry, rw, rh) in (('cth_lower', LOWER_RECT), ('cth_upper', UPPER_RECT)):
        sprite(cr, name, rx, ry, (0, 0, rw, rh))
    cr.translate(-X0 * PX, (Y0 + H) * PX); cr.scale(PX, -PX)            # world points from here on
    # painted lamps (z -18, just over the art)
    for n in arrows:
        (x, y), a = ARROWS[n]; lamp(cr, ('arrow', 24, 18), x, y, a, SEA)
    for i in tomes: lamp(cr, ('round', 6), *TOMES[i], 0, PARCH)
    for i in candles: lamp(cr, ('round', 7), *CANDLES[i], 0, FLAME)
    for i in eyes: lamp(cr, ('round', 5), *EYE_LAMPS[i], 0, ELDRITCH)
    for i in tentacle_lamps: lamp(cr, ('round', 5), *TENTACLE_LAMPS[i], 0, TGREEN)
    if kickback: lamp(cr, ('round', 9), *KICKBACK, 0, (1.0, 0.54, 0.24))
    if save: lamp(cr, ('round', 9), *OUTLANE_SAVE, 0, (0.28, 0.88, 0.78))
    if elder: lamp(cr, ('star', 20, 8.5), *ELDER, 0, (0.49, 0.94, 0.66))
    for i in lanes: flame(cr, LANE_XS[i], FLAME_Y)
    # parts
    sprite(cr, 'cth_magnet', *RITUAL, MAGNET_BOX)
    for i, ty in enumerate(TARGET_YS):
        sprite(cr, 'cth_target_down' if i in down else 'cth_target', TARGET_X, ty, TARGET_BOX)
    for (bx, by) in BUMPERS: sprite(cr, 'cth_bumper', bx, by, BUMPER_BOX)
    sprite(cr, None, *SPINNER, SPINNER_BOX, src=spinner_frame())
    sprite(cr, 'cth_plunger', *PLUNGER, PLUNGER_BOX)
    for b in balls:
        if b[1] < 900: ball(cr, *b)
    sprite(cr, 'cth_ramps', 0, 0, RAMP_RECT)
    sprite(cr, 'cth_flipper_left', 179, 220, (-18, -18, 132, 36), rot=math.radians(-30))
    sprite(cr, 'cth_flipper_right', 389, 220, (-114, -18, 132, 36), rot=math.radians(30))
    sprite(cr, 'cth_flipper_upper', 528, 800, (-76, -15, 91, 30), rot=math.radians(30))
    if cthulhu:
        cx, cy = LAGOON
        for k in (2, 0, 1, 3, 4):
            d, r = TENTACLE_BASES[k]; th = math.radians(d)
            gone = k in CUTTABLE and CUTTABLE.index(k) in cut
            sprite(cr, f'cth_tentacle{k}', cx + r * math.sin(th), cy - r * math.cos(th), TENTACLE_BOXES[k],
                   alpha=0.12 if gone else 1.0)
        sprite(cr, 'cth_cthulhu', cx, cy, CTHULHU_BOX)
        cr.save(); cr.set_operator(cairo.OPERATOR_ADD)
        for ex, ey in EYES:
            cr.arc(cx + ex, cy + ey, 3.6, 0, 6.29); cr.set_source_rgba(1.0, 0.62, 0.15, 0.8); cr.fill()
        cr.restore()
    for b in balls:
        if b[1] >= 900: ball(cr, *b)
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


# ------------------------------------------------------------------ shot lines (world points)
LEFT_TIP, RIGHT_TIP = (250, 185), (318, 185)          # where a shot leaves each flipper
UPPER_TIP = (470, 770)
RAMP = [LEFT_TIP, (336, 532), (358, 600), (425, 790), (455, 860), (482, 892), (510, 886), (522, 862), (524, 760)]
ORBIT = [RIGHT_TIP, (121, 723), (64, 830), (39, 960), (38, 1110), (60, 1190), (110, 1240), (183, 1264), (284, 1272),
         (385, 1264), (465, 1236), (525, 1180), (552, 1110)]
LIBRARY_SHOT = [(262, 195), (271, 560), (280, 634)]
LAGOON_SHOT = [UPPER_TIP, (467, 962), (455, 1012)]
SIGIL_SHOT = [LEFT_TIP, (411, 493), (450, 548)]
FULL = (-30, 150, 610, 1320)
UPPER = (-30, 430, 610, 1320)


def lanes_box(cr): oval(cr, 222, 1130, 326, 1185)
def bank_box(cr): oval(cr, 446, 478, 486, 622)


def main():
    # Act 1 · 1: clues. Any of these shots is a clue: ramp, orbit, Lagoon, all three Candle lanes, the whole Sigil bank.
    def clues(cr):
        path(cr, RAMP); path(cr, ORBIT); path(cr, LAGOON_SHOT)
        lanes_box(cr); bank_box(cr)
    save(table(lanes=(0, 1, 2), down=(0, 1, 2, 3), extra=clues), 'cth_howto_clues', FULL, 900)

    # Act 1 · 2: the Library lit (two clues): its arrow and the next tome's lamp blink.
    def library(cr):
        path(cr, LIBRARY_SHOT); ring(cr, 284, 615, 38)
    save(table(arrows=('library',), tomes=(0,), extra=library), 'cth_howto_library', (60, 160, 510, 760), 900)

    # Tome I: pages. The spinner (orbit) and the ramp blink.
    def tome1(cr):
        path(cr, ORBIT); path(cr, RAMP); ring(cr, *SPINNER, 30)
    save(table(arrows=('orbit', 'rightRamp'), tomes=(0,), extra=tome1), 'cth_howto_tome1', FULL, 900)

    # Tome II: two random shots light (here the ramp and the Lagoon).
    def tome2(cr):
        path(cr, RAMP); path(cr, LAGOON_SHOT)
    save(table(arrows=('rightRamp', 'lagoon'), tomes=(0, 1), extra=tome2), 'cth_howto_tome2', UPPER, 900)

    # Tome III: the seals (the Sigil bank), then the ramp.
    def tome3(cr):
        path(cr, SIGIL_SHOT, 1); bank_box(cr); path(cr, [(245, 230)] + RAMP[1:], 2)
    save(table(arrows=('sigil', 'rightRamp'), tomes=(0, 1, 2), down=(0, 1, 2, 3), extra=tome3),
         'cth_howto_tome3', (60, 160, 610, 960), 900)

    # Act 2 · 1: the five candles. Two lit (orbit, ramp); the other three shots' arrows blink.
    def candles(cr):
        path(cr, LIBRARY_SHOT); path(cr, LAGOON_SHOT); path(cr, SIGIL_SHOT); ring(cr, *RITUAL, 72)
    save(table(arrows=('library', 'lagoon', 'sigil'), tomes=(0, 1, 2), candles=(0, 1),
               balls=[(200, 420), (380, 700)], extra=candles), 'cth_howto_candles', UPPER[:1] + (150,) + UPPER[2:], 900)

    # Act 2 · 2: the Summoning. Every candle lit, Cthulhu rises out of the Lagoon.
    def summon(cr):
        ring(cr, *RITUAL, 72); ring(cr, *LAGOON, 62)
    save(table(tomes=(0, 1, 2), candles=range(5), tentacle_lamps=range(4), arrows=('lagoon', 'rightRamp', 'orbit'),
               cthulhu=True, extra=summon), 'cth_howto_summoning', (150, 380, 600, 1160), 900)

    # Act 3 · 1: tentacles. Two cut (their lamps out, faint stubs), two to go; Cthulhu, the ramp or the orbit cuts.
    def tentacles(cr):
        path(cr, RAMP); path(cr, ORBIT); path(cr, LAGOON_SHOT); ring(cr, 452, 993, 52)
    save(table(tomes=(0, 1, 2), candles=range(5), tentacle_lamps=(2, 3), cut=(0, 1),
               arrows=('lagoon', 'rightRamp', 'orbit'), cthulhu=True,
               balls=[(300, 330), (140, 560), (420, 880)], extra=tentacles), 'cth_howto_tentacles', UPPER, 900)

    # Act 3 · 2: the eye. Every tentacle cut, his eye open: one eye hit lit, the next blinking.
    def eye(cr):
        path(cr, LAGOON_SHOT); ring(cr, 452, 1066, 38)
    save(table(tomes=(0, 1, 2), candles=range(5), eyes=(0, 1), cut=range(4), arrows=('lagoon',), cthulhu=True,
               balls=[(500, 820)], extra=eye), 'cth_howto_eye', (330, 740, 600, 1130), 900)

    # Act 3 · 3: banish. All three eye lamps lit.
    def banish(cr):
        ring(cr, 452, 1060, 46)
    save(table(tomes=(0, 1, 2), candles=range(5), eyes=range(3), cut=range(4), arrows=('lagoon',), cthulhu=True,
               extra=banish), 'cth_howto_banish', (330, 900, 600, 1130), 900)

    # Saving: the kickback, lit by the Sigil bank.
    def kick(cr):
        path(cr, SIGIL_SHOT, 1); bank_box(cr); ring(cr, *KICKBACK, 18); badge(cr, KICKBACK[0] + 22, KICKBACK[1] + 22, 2)
        path(cr, [(37, 260), (37, 430)])
    save(table(kickback=True, down=(0, 1, 2, 3), extra=kick), 'cth_howto_kickback', (-30, 150, 530, 660), 900)

    # Saving: the outlane save, lit by a finished tome (its lamp).
    def outlane(cr):
        ring(cr, *OUTLANE_SAVE, 18); ring(cr, 284, 615, 38); path(cr, [(531, 260), (531, 430)])
    save(table(save=True, tomes=(0,), extra=outlane), 'cth_howto_outlane', (60, 150, 610, 700), 900)

    # Scoring: the multiplier. All three Candle lanes lit.
    def mult(cr):
        lanes_box(cr)
    save(table(lanes=(0, 1, 2), balls=[(274, 1215)], extra=mult), 'cth_howto_lanes', (130, 1080, 420, 1300), 900)


main()
