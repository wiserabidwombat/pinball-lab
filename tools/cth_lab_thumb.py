"""Table 03 art round 5b: the Lab home card picture (cth_lab_thumb.png, 420 x 750 = the card's 84:150) composed from the
baked table art and every rendered part sprite, with Cthulhu risen and a ball on the ramp. Paths point at the
render outputs of that session (cth_upper/cth_lower, cth_ramps, the part, flipper and Cthulhu renders)."""
import sys, math, json
sys.path.insert(0, '/home/claude/gi-src/tools'); import cth_layout as L
from PIL import Image
P = 3
canvas = Image.new('RGBA', (680 * P, 1405 * P), (0, 0, 0, 255))
canvas.paste(Image.open('/tmp/claude-0/sl/art/cth_upper.png').convert('RGBA'), (0, 0))
canvas.paste(Image.open('/tmp/claude-0/sl/art/cth_lower.png').convert('RGBA'), (0, (1330 - 525) * P))
def put(path, ox, oy, box, rot=0.0):
    x0, y0, w, h = box
    im = Image.open(path).convert('RGBA').resize((round(w * P), round(h * P)), Image.LANCZOS)
    if rot:
        cx, cy = -x0 * P, (h + y0) * P
        R = int(max(w, h) * P * 1.6); c = Image.new('RGBA', (2 * R, 2 * R)); c.paste(im, (R - int(cx), R - int(cy)))
        im = c.rotate(math.degrees(rot), resample=Image.BICUBIC)
        canvas.alpha_composite(im, (int((ox + 40) * P - R), int((1330 - oy) * P - R))); return
    canvas.alpha_composite(im, (int((ox + x0 + 40) * P), int((1330 - (oy + y0 + h)) * P)))
V5 = '/mnt/user-data/outputs/gi/t3m8v5/'; V8 = '/mnt/user-data/outputs/gi/t3m8v8/'
for (bx, by) in L.BUMPERS: put(V5 + 'cth_bumper_m8v5.png', bx, by, (-40, -48, 96, 100))
for i, ty in enumerate(L.TARGET_YS): put(V8 + ('cth_target_m8v8.png' if i != 1 else 'cth_target_down_m8v8.png'), L.TARGET_X, ty, (-16, -24, 42, 58))
put(V5 + 'cth_magnet_m8v5.png', *L.RITUAL, (-20, -20, 46, 42))
info = json.load(open('/tmp/claude-0/ramp/cth_ramps.json')); x0, y0, w, h = info['box']
put('/tmp/claude-0/ramp/cth_ramps.png', 0, 0, (x0, y0, w, h))
FL = '/mnt/attach/outputs/gi/t3m2/CthArt/'
put(FL + 'cth_flipper_left.imageset/cth_flipper_left.png', 179, 220, (-18, -18, 132, 36), rot=math.radians(-30))
put(FL + 'cth_flipper_right.imageset/cth_flipper_right.png', 389, 220, (-114, -18, 132, 36), rot=math.radians(30))
put('/tmp/claude-0/p3/final/cth_flipper_upper.png', 528, 800, (-76, -15, 91, 30), rot=math.radians(30))
cb = json.load(open('/tmp/claude-0/cth/final/cthulhu.json'))
C = (452, 1030)
for k in (2, 0, 1, 3, 4):
    d, r = [(-80, 19), (-45, 19), (180, 12), (45, 19), (80, 19)][k]; th = math.radians(d)
    put(f'/tmp/claude-0/cth/final/cth_tentacle{k}.png', C[0] + r * math.sin(th), C[1] - r * math.cos(th), cb[f'tentacle{k}'])
put('/tmp/claude-0/cth/final/cth_cthulhu.png', *C, cb['cthulhu'])
# a ball climbing the ramp and one on the lower playfield
ball = '/home/claude/gi-src/tools/ball.png'
rp, apex = L.right_ramp_path(); (bx, by), _ = rp.sample(170); hh = L.ramp_height(170, apex, rp.length, L.RAMP_END_H)
s = 18 * 1.2 * (1 + 0.15 * hh / 40); put(ball, bx, by + (9 + hh) * L.OBLIQUE, (-s / 2, -s / 2, s, s))
s = 21.6; put(ball, 250, 400 + 9 * L.OBLIQUE, (-s / 2, -s / 2, s, s))
# crop: x -25..625, y 140..1300 (aspect 0.56), to 420 x 750
cx0, cx1, cy0, cy1 = -25, 625, 140, 1300
crop = canvas.crop(((cx0 + 40) * P, (1330 - cy1) * P, (cx1 + 40) * P, (1330 - cy0) * P))
crop.convert('RGB').resize((420, 750), Image.LANCZOS).save('cth_lab_thumb.png')
print(crop.size)
