"""Table 04 (Monsoon) look development: the printed playfield and apron.
The playfield illustration IS Aaron's desert-storm watercolor (made with ChatGPT): a portrait slice of it covers the
whole table (cth_layout.FULL_RECT, world (-40,-75)-(640,1330), at PX_PER_PT), so the storm sky sits behind the bumpers,
the mesas mid-table and the desert foreground (rocks, prickly pear) round the flippers. It's upscaled ~2.5x, so a
paper grain is added at full resolution to keep it from looking soft. Lamp inserts are painted on top as clear
glass tinted in the painting's colours. The lower table is identical to Table 03's, so cth_layout supplies it.
Writes: <out>/mon_playfield_full.png (2040 x 4215), mon_floor_lower.png (the LOWER_RECT part, for the Blender
render), mon_apron.png (the apron plates' texture, LOWER_RECT).
Usage: python3 mon_floor.py <painting.jpg> <out dir>"""
import sys, os, math
import numpy as np
import cairo
from PIL import Image, ImageFilter
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
S = L.PX_PER_PT
FX0, FY0, FW, FH = L.FULL_RECT
PW, PH = int(FW * S), int(FH * S)                  # 2040 x 4215
CROP_X0 = 40                                       # painting px: the big saguaro sits on the table's left side

# ------------------------------------------------------------------ the illustration
paint = Image.open(SRC).convert('RGB')
cw = round(paint.height * FW / FH)
art = paint.crop((CROP_X0, 0, CROP_X0 + cw, paint.height)).resize((PW, PH), Image.LANCZOS)
art = art.filter(ImageFilter.UnsharpMask(radius=3, percent=40, threshold=2))
a = np.asarray(art).astype(np.float32) / 255

# paper: fine grain + a few fibres + gentle cold-press tooth, multiplied in
rng = np.random.default_rng(21)
grain = ndimage.gaussian_filter(rng.standard_normal((PH, PW)), 0.8)
tooth = ndimage.gaussian_filter(rng.standard_normal((PH, PW)), 3.0)
paper = 1 - 0.035 * (grain / grain.std()).clip(-2.5, 2.5) * 0.5 - 0.03 * (tooth / tooth.std()).clip(-2.5, 2.5) * 0.5
a = a * paper[..., None]
# pigment granulation: darker specks where the wash is dark
gran = ndimage.gaussian_filter(rng.standard_normal((PH, PW)), 1.2)
lum = a @ np.array([0.299, 0.587, 0.114], np.float32)
a = a * (1 - 0.05 * (1 - lum)[..., None] * (gran / gran.std()).clip(0, 3)[..., None])
a = np.clip(a, 0, 1)

surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, PW, PH)
buf = np.ndarray((PH, PW, 4), np.uint8, surf.get_data())
rgb8 = (a * 255).astype(np.uint8)
buf[..., 0], buf[..., 1], buf[..., 2], buf[..., 3] = rgb8[..., 2], rgb8[..., 1], rgb8[..., 0], 255
surf.mark_dirty()

c = cairo.Context(surf)
c.translate(0, PH); c.scale(S, -S); c.translate(-FX0, -FY0)      # world points, y up


def rgb(h, a=1.0):
    h = h.lstrip('#'); return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def text_up(c, txt, x, y, size, color, font='Cinzel', weight=cairo.FONT_WEIGHT_BOLD, spacing=0.0, rot=0.0):
    c.save(); c.translate(x, y); c.rotate(rot); c.scale(1, -1)
    c.select_font_face(font, cairo.FONT_SLANT_NORMAL, weight); c.set_font_size(size)
    widths = [c.text_extents(ch).x_advance for ch in txt]
    total = sum(widths) + spacing * (len(txt) - 1)
    xx = -total / 2; ext = c.text_extents(txt)
    for ch, w in zip(txt, widths):
        c.move_to(xx, ext.height / 2); c.text_path(ch); xx += w + spacing
    c.set_source_rgba(*color); c.fill(); c.restore()


def insert(path_fn, col):
    """A clear glass insert tinted `col`: a soft dark ring, the tinted glass, a pale inner glow and a highlight."""
    r, g, b, _ = rgb(col)
    path_fn(); c.set_line_width(2.6); c.set_source_rgba(0.12, 0.09, 0.14, 0.55); c.stroke()
    path_fn(); c.set_source_rgba(r * 0.75, g * 0.75, b * 0.75, 0.82); c.fill()
    path_fn(); c.set_source_rgba(min(1, r * 1.15), min(1, g * 1.15), min(1, b * 1.15), 0.45); c.set_line_width(1.2); c.stroke()


def arrow(x, y, ang, length=26, width=16):
    def f():
        c.save(); c.translate(x, y); c.rotate(ang)
        c.move_to(length / 2, 0); c.line_to(-length / 2, width / 2); c.line_to(-length / 2 + 6, 0)
        c.line_to(-length / 2, -width / 2); c.close_path(); c.restore()
    return f


def circle(x, y, r):
    def f():
        c.new_sub_path(); c.arc(x, y, r, 0, 2 * math.pi)
    return f


def raindrop(x, y, r):
    """A raindrop, point up (the ball-save insert)."""
    def f():
        c.save(); c.translate(x, y)
        c.move_to(0, r * 2.1)
        c.curve_to(r * 0.35, r * 1.3, r, r * 0.55, r, 0)
        c.arc_negative(0, 0, r, 0, -math.pi)                # round the bottom (y up)
        c.curve_to(-r, r * 0.55, -r * 0.35, r * 1.3, 0, r * 2.1)
        c.close_path(); c.restore()
    return f


GOLD, VIOLET, SAGE, RAIN = '#f2c768', '#a98be0', '#a9cf9b', '#9cc8e8'
insert(arrow(71, 410, math.pi / 2), GOLD)
insert(arrow(L.MIRROR - 71, 410, math.pi / 2), GOLD)
insert(circle(37, 300, 9), VIOLET)                     # kickback
insert(circle(L.MIRROR - 37, 300, 9), SAGE)            # outlane save
insert(raindrop(284, 300, 13), RAIN)                   # ball save
insert(arrow(118, 286, -math.radians(36), 18, 11), GOLD)
insert(arrow(L.MIRROR - 118, 286, -math.pi + math.radians(36), 18, 11), GOLD)
text_up(c, 'FIRST RAIN', 284, 262, 7.5, rgb('#2a2230', 0.8), spacing=1.4)
text_up(c, 'KICKBACK', 37, 345, 6, rgb('#2a2230', 0.75), spacing=0.8, rot=math.pi / 2)
text_up(c, 'SAVE', L.MIRROR - 37, 345, 6, rgb('#2a2230', 0.75), spacing=0.8, rot=math.pi / 2)

# the plunger lane: a quieter wash (darkened, desaturated) so the lane reads as wood under the painting
c.rectangle(L.LANE_X, L.LANE_FLOOR_Y, L.RIGHT_X - L.LANE_X, L.LANE_WALL_TOP - L.LANE_FLOOR_Y); c.set_source_rgba(0.16, 0.13, 0.12, 0.55); c.fill()
# drain chute
c.rectangle(L.DRAIN_X, FY0, L.MIRROR - 2 * L.DRAIN_X, L.DRAIN_Y - FY0 + 4); c.set_source_rgba(0.02, 0.02, 0.025, 1); c.fill()
surf.flush()
surf.write_to_png(os.path.join(OUT, 'mon_playfield_full.png'))

# the lower part (LOWER_RECT) for the Blender floor
LX0, LY0, LW, LH = L.LOWER_RECT
full = Image.open(os.path.join(OUT, 'mon_playfield_full.png'))
top = int((FY0 + FH - (LY0 + LH)) * S)
full.crop((0, top, PW, top + int(LH * S))).save(os.path.join(OUT, 'mon_floor_lower.png'))

# ------------------------------------------------------------------ apron plates: cream watercolor paper, the title
AW, AH = int(LW * S), int(LH * S)
ap = np.ones((AH, AW, 3), np.float32) * np.array([0.93, 0.89, 0.81], np.float32)
yy, xx = np.mgrid[0:AH, 0:AW].astype(np.float32)
wash = ndimage.gaussian_filter(rng.standard_normal((AH, AW)), 60)
wash = (wash - wash.min()) / (wash.max() - wash.min())
violet = np.array([0.58, 0.48, 0.70], np.float32); gold = np.array([0.95, 0.76, 0.42], np.float32)
low = (yy / AH)                                                   # 0 at the top of the image (y 525), 1 at -75
tint = (violet * (1 - wash[..., None]) + gold * wash[..., None])
ap = ap * (1 - 0.32 * low[..., None]) + tint * 0.32 * low[..., None]
g2 = ndimage.gaussian_filter(rng.standard_normal((AH, AW)), 0.8)
ap = np.clip(ap * (1 - 0.03 * (g2 / g2.std()).clip(-2.5, 2.5))[..., None], 0, 1)
s2 = cairo.ImageSurface(cairo.FORMAT_ARGB32, AW, AH)
b2 = np.ndarray((AH, AW, 4), np.uint8, s2.get_data())
q = (ap * 255).astype(np.uint8)
b2[..., 0], b2[..., 1], b2[..., 2], b2[..., 3] = q[..., 2], q[..., 1], q[..., 0], 255
s2.mark_dirty()
c = cairo.Context(s2)
c.translate(0, AH); c.scale(S, -S); c.translate(-LX0, -LY0)
text_up(c, 'MON', 120, 66, 28, rgb('#3a2c4a'), spacing=5)
text_up(c, 'SOON', L.MIRROR - 120, 66, 28, rgb('#3a2c4a'), spacing=5)
text_up(c, 'PINBALL LAB  ·  TABLE 04', 120, 30, 7, rgb('#6a5a48'), spacing=1.5)
text_up(c, 'PAINT  ·  STORM  ·  BLOOM', L.MIRROR - 120, 30, 7, rgb('#6a5a48'), spacing=1.5)
# a few painted raindrops under each word
for x0 in (120, L.MIRROR - 120):
    for dx, dy, r in ((-30, 4, 3), (0, 0, 4), (30, 4, 3)):
        c.save(); c.translate(x0 + dx, dy)
        c.move_to(0, r * 2.2); c.curve_to(r * 0.4, r * 1.3, r, r * 0.6, r, 0); c.arc_negative(0, 0, r, 0, -math.pi)
        c.curve_to(-r, r * 0.6, -r * 0.4, r * 1.3, 0, r * 2.2); c.close_path()
        c.set_source_rgba(0.45, 0.62, 0.80, 0.75); c.fill(); c.restore()
s2.flush()
s2.write_to_png(os.path.join(OUT, 'mon_apron.png'))
print('wrote', OUT, PW, PH, AW, AH)
