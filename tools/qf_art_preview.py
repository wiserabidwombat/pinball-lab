import sys, os
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, '/home/claude/qf')
import qf_render_m1 as R
PAL = list(R.PAL.values())
def lock(im):
    im = im.convert('RGBA'); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 128: px[x, y] = (0, 0, 0, 0); continue
            px[x, y] = (*min(PAL, key=lambda p: (p[0]-r)**2 + (p[1]-g)**2 + (p[2]-b)**2), 255)
    return im
U = '/mnt/user-data/uploads/GreyInvasionPinball/build/qf_art/'
# game name: (source file, drawn height in table pt)
PICKS = {'qf_wisp': ('wisp_gpt2low', 34), 'qf_ghost': ('ghost_2', 40), 'qf_treant_face': ('treant_1', 70),
         'qf_treant_hurt': ('treant_hurt', 70), 'qf_treant_felled': ('treant_felled', 70),
         'qf_witch': ('witch_2', 54), 'qf_lantern': ('lantern_2', 26), 'qf_gravestone': ('grave_1', 44),
         'qf_roots': ('roots_1', 34)}
os.makedirs('art/locked', exist_ok=True)
L = {}
for name, (src, h) in PICKS.items():
    im = lock(Image.open(U + src + '.png')); bb = im.getbbox(); im = im.crop(bb)
    im.save(f'art/locked/{name}.png'); L[name] = (im, h)
    print(name, im.size)
S = 1.5   # mood test px per pt
table = Image.open('qf_forest_m1r1_pixel.png').convert('RGBA')
def put(name, x, y, h=None):
    im, hh = L[name]; h = h or hh
    s = h * S / im.height; v = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)
    table.alpha_composite(v, (int(x * S - v.width / 2), int((1360 - y) * S - v.height / 2)))
for p in [(110, 1122), (280, 1246), (400, 1230)]: put('qf_wisp', *p)
put('qf_ghost', 250, 738)
put('qf_treant_face', 300, 1052)
for p in [(52, 668), (300, 1042 + 40), (526, 736)]: put('qf_lantern', *p)
put('qf_witch', 526 - 34, 736 + 10)
put('qf_gravestone', 300, 567)
put('qf_roots', 454, 474)
W = 960 + 560; out = Image.new('RGBA', (W, 2040), R.PAL['void'] + (255,))
out.alpha_composite(table, (0, 0)); d = ImageDraw.Draw(out)
f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
fs = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
d.text((990, 20), 'Picks, palette-locked (×4 nearest)', fill=(255, 236, 160), font=f)
y = 60
for name in PICKS:
    im, h = L[name]
    s = min(4, 200 / im.height, 230 / im.width); v = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)
    out.paste(Image.new('RGBA', (250, v.height + 16), R.PAL['night1'] + (255,)), (990, y))
    out.alpha_composite(v, (990 + (250 - v.width) // 2, y + 8))
    d.text((1255, y + 8), f'{name}\n{im.width}×{im.height} px\ndrawn {h} pt tall', fill=(164, 176, 204), font=fs)
    y += v.height + 30
out.convert('RGB').save('art/qf_art_preview.png'); print('ok')
