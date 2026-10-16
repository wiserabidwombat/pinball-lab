"""Table 04 (Monsoon) polish round 1: the How to Play map (mon_howto_map.png, 1020x2108 = world (-40,-75)-(640,1330) at
1.5 px/pt), the painted table in full color with every part on it: storm-cloud bumpers, saguaro standups, flippers,
spinner, the dust devil, the captive ball and the wires (high wire, low wire, helix) drawn lifted by their height
like the game draws them. Wire paths as tools/mon_render_m4.py (= MonTableLayout).
Usage: python3 mon_howto_map.py <mon_upper.jpg> <mon_lower.jpg> <parts dir> <flippers dir> <out.png>"""
import sys, os, math
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L
from cth_layout import RampPath

UP, LO, PARTS, FLIPS, OUT = sys.argv[1:6]
P = 3
K = 0.404                                         # oblique: drawn lift per point of height
canvas = Image.new('RGBA', (680 * P, 1405 * P), (0, 0, 0, 255))
canvas.paste(Image.open(UP).convert('RGBA').resize((680 * P, 805 * P)), (0, 0))
canvas.paste(Image.open(LO).convert('RGBA').resize((680 * P, 600 * P)), (0, 805 * P))


def px(x, y): return ((x + 40) * P, (1330 - y) * P)


def put(path, ox, oy, box, rot=0.0):
    x0, y0, w, h = box
    im = Image.open(path).convert('RGBA').resize((round(w * P), round(h * P)), Image.LANCZOS)
    if rot:
        cx, cy = -x0 * P, (h + y0) * P
        R = int(max(w, h) * P * 1.6); c = Image.new('RGBA', (2 * R, 2 * R)); c.paste(im, (R - int(cx), R - int(cy)))
        im = c.rotate(math.degrees(rot), resample=Image.BICUBIC)
        canvas.alpha_composite(im, (int((ox + 40) * P - R), int((1330 - oy) * P - R))); return
    canvas.alpha_composite(im, (int((ox + x0 + 40) * P), int((1330 - (oy + y0 + h)) * P)))


# --- floor toys (under everything raised)
over = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); d = ImageDraw.Draw(over)
cx, cy = 284, 470; R = 40                         # dust devil: sand disc, rings, spiral arms
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
# captive ball: slot, steel rails, the ball at the mouth
m = (100, 592); h = math.radians(120); ln, hw = 82, 10.5
ax_, ay_ = math.cos(h), math.sin(h); nx, ny = -ay_, ax_
end = (m[0] + ax_ * ln, m[1] + ay_ * ln)
slot = [px(m[0] + nx * hw, m[1] + ny * hw), px(end[0] + nx * hw, end[1] + ny * hw),
        px(end[0] - nx * hw, end[1] - ny * hw), px(m[0] - nx * hw, m[1] - ny * hw)]
d.polygon(slot, fill=(70, 58, 92, 235))
for s in (1, -1):
    a = px(m[0] + s * nx * hw, m[1] + s * ny * hw); b = px(end[0] + s * nx * hw, end[1] + s * ny * hw)
    d.line([a, b], fill=(20, 16, 30, 200), width=16); d.line([a, b], fill=(196, 200, 210, 255), width=9); d.line([a, b], fill=(250, 250, 255, 255), width=3)
bc = (m[0] + ax_ * 9, m[1] + ay_ * 9)
d.ellipse([*px(bc[0] - 9, bc[1] + 9), *px(bc[0] + 9, bc[1] - 9)], fill=(190, 194, 205, 255), outline=(40, 36, 50, 255), width=3)
d.ellipse([*px(bc[0] - 5, bc[1] + 6), *px(bc[0] - 1, bc[1] + 2)], fill=(255, 255, 255, 230))
canvas.alpha_composite(over)

# --- parts
for (bx, by) in L.BUMPERS: put(os.path.join(PARTS, 'mon_bumper.png'), bx, by, (-40, -48, 96, 100))
for y in (590, 560, 530): put(os.path.join(PARTS, 'mon_standup.png'), 464, y, (-14, -18, 30, 42))
sheet = Image.open(os.path.join(FLIPS, 'mon_spinner_sheet.png')).convert('RGBA')
fw, fh = sheet.width // 6, sheet.height // 4
frame0 = sheet.crop((0, 0, fw, fh)); frame0.save('/tmp/claude-0/s/mon_spinner_f0.png')
put('/tmp/claude-0/s/mon_spinner_f0.png', 39, 935, (-22, -10, 44, 32))
put(os.path.join(FLIPS, 'mon_flipper_left.png'), 179, 220, (-18, -18, 132, 36), rot=math.radians(-30))
put(os.path.join(FLIPS, 'mon_flipper_right.png'), 389, 220, (-114, -18, 132, 36), rot=math.radians(30))
put(os.path.join(FLIPS, 'mon_flipper_upper.png'), 528, 800, (-76, -15, 91, 30), rot=math.radians(30))

# --- wires (as MonTableLayout; drawn lifted by height × K)
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


def rails(p, hfun, colors, plastic_until=0.0, half=5.5):
    """Each 10-pt piece: two rails offset ±half across the path, lifted by height; a clear amber band where plastic."""
    pieces = []
    for i in range(1, len(p.pts)):
        (ax, ay), (bx, by) = p.pts[i - 1], p.pts[i]; s = p.ds[i]; hh = hfun(s)
        hd = p.hd[i]; ox, oy = -math.sin(hd) * half, math.cos(hd) * half
        pieces.append((hh, s, [(ax + ox, ay + oy + hfun(p.ds[i - 1]) * K), (bx + ox, by + oy + hh * K)],
                       [(ax - ox, ay - oy + hfun(p.ds[i - 1]) * K), (bx - ox, by - oy + hh * K)]))
    return [(hh, s, a, b, colors, s <= plastic_until) for hh, s, a, b in pieces]


allp = []
H, hH = high(); W, hW = low(); X, hX = helix()
chrome = ((20, 16, 30, 170), (200, 204, 214, 255), (252, 252, 255, 255))
brass = ((20, 16, 30, 170), (190, 150, 80, 255), (255, 232, 170, 255))
allp += rails(W, hW, brass)
allp += rails(H, hH, chrome, plastic_until=275, half=8)
allp += rails(X, hX, chrome)
allp.sort(key=lambda q: q[0])                    # lower pieces first, so higher turns draw over them
for hh, s, a, b, (ink, metal, hi), plastic in allp:
    o = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); g = ImageDraw.Draw(o)
    A = [px(*q) for q in a]; B = [px(*q) for q in b]
    if plastic:
        g.polygon([A[0], A[1], B[1], B[0]], fill=(240, 196, 120, 80))
    for line in (A, B):
        g.line(line, fill=ink, width=13); g.line(line, fill=metal, width=7); g.line(line, fill=hi, width=2)
    canvas.alpha_composite(o)

full = canvas.resize((1020, 2108), Image.LANCZOS).convert('RGB')
full.save(OUT)
print(full.size, OUT)
