"""Quest & Flipper (Table 09): the fixed playfield as pixel art, drawn from qf_layout.py (T9 M2 v4: deep forest).

Two layers, composed at 1 world pt per pixel (640 x 1360), palette-locked, then scaled x3 nearest to 3 px/pt
(1920 x 4080) so the game can show it with linear filtering under a zoomed camera:
  - the FLOOR: a seamless SpriteCook forest-floor texture (art/qf_floor_tex.png, asset 9004ee48...) tiled at
    1 texel per pt, darkened under the canopy (heavier towards the side walls and the top), crossed by two dithered
    moonlight shafts and the old low fog bands;
  - the PAINTED layer at 2 pt per pixel (transparent where the floor shows): the dark woods outside the cabinet
    (crowded trunk tops with root flares), roots creeping onto the floor edges, the layered treeline and moon behind
    the glade, the forest island (moss, bare trees, lane cut-outs, the hollow log, the Treant's trunk), glowing
    mushroom clusters and ferns, stone walls and posts, the well's ring, the Graveyard's headstones, the shooter lane.
Left to the game (moves or changes): flippers, slings, the Old Road ramp (QfRamp), bark drops, the diverter and orbit
stop, the launch gate, the Forest Gate, targets, and every monster and lantern sprite.

Run: python3 qf_art_playfield.py out.png [preview.png]
"""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw
import qf_layout as L
from qf_render_m1 import PAL, BAYER, tree, quantize

S = 2.0                      # world pt per painted pixel
AW, AH = int(L.W / S), int(L.H / S)
FW, FH = int(L.W), int(L.H)  # the floor/compose grid: 1 pt per pixel
UP = 3                       # compose px -> output px (3 px per pt)
import os
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qf_art", "qf_floor_tex.png")   # SpriteCook 9004ee48


def to_px(p):
    return (p[0] / S, (L.H - p[1]) / S)


def mask_of(poly, w=AW, h=AH, s=S):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([(p[0] / s, (L.H - p[1]) / s) for p in poly], fill=255)
    return np.asarray(m) > 0


def lock(img):
    """Nearest palette colour per pixel (keeps alpha)."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    cols = np.array(list(PAL.values()), dtype=np.float32)
    d = ((a[:, :, None, :3] - cols[None, None]) ** 2).sum(-1)
    out = a.copy(); out[..., :3] = cols[d.argmin(-1)]
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def floor_layer(rng):
    """The forest floor at 1 pt/px: the texture, canopy shade, moonlight shafts and fog."""
    tex = lock(Image.open(TEX)).convert("RGB")
    a = np.zeros((FH, FW, 3), np.float32)
    t = np.asarray(tex, np.float32)
    for y in range(0, FH, tex.height):
        for x in range(0, FW, tex.width):
            h = min(tex.height, FH - y); w = min(tex.width, FW - x)
            a[y:y + h, x:x + w] = t[:h, :w]
    yy, xx = np.mgrid[0:FH, 0:FW]
    wx = L.H - yy                                              # world y of each row
    bay = BAYER[yy % 4, xx % 4]
    # canopy shade: dark towards the side walls, the top corners and under a few big crowns
    shade = np.clip(1 - np.minimum(xx - 20, 580 - xx) / 120, 0, 1) * 0.55
    shade = np.maximum(shade, np.clip((wx - 1000) / 330, 0, 1) * 0.35)
    for _ in range(9):
        cx, cy, r = rng.uniform(40, 560), rng.uniform(300, 1300), rng.uniform(60, 120)
        shade = np.maximum(shade, 0.45 * np.exp(-((xx - cx) ** 2 + (wx - cy) ** 2) / (2 * r * r)))
    dark = shade > bay * 0.9 + 0.08
    a[dark] *= 0.55
    darker = shade > bay * 0.9 + 0.45
    a[darker] *= 0.7
    # moonlight shafts: two slanted dithered bands from the top left
    beam = np.zeros((FH, FW))
    for x0, w in ((150, 46), (390, 34)):
        d = (xx - (x0 + (L.H - wx) * 0.32))
        beam = np.maximum(beam, np.exp(-(d / w) ** 2) * np.clip((wx - 250) / 600, 0, 1))
    lit = beam > bay * 0.9 + 0.25
    a[lit] = a[lit] * 0.62 + np.array(PAL["fog1"]) * 0.38
    lit2 = beam > bay * 0.9 + 0.62
    a[lit2] = a[lit2] * 0.6 + np.array(PAL["fog2"]) * 0.4
    # low fog bands near the flippers (as round 1, in pt)
    fog = np.zeros((FH, FW))
    for band_y, amp, thick in ((FH * 0.80, 0.55, 52), (FH * 0.62, 0.35, 36), (FH * 0.45, 0.2, 28)):
        fog += amp * np.exp(-((yy - band_y - 12 * np.sin(xx * 0.025 + band_y)) / thick) ** 2)
    fog *= 0.75 + 0.25 * np.sin(xx * 0.045 + yy * 0.01)
    m1 = fog > bay * 0.9 + 0.18
    a[m1] = a[m1] * 0.5 + np.array(PAL["fog1"]) * 0.5
    m2 = fog > bay * 0.9 + 0.5
    a[m2] = a[m2] * 0.45 + np.array(PAL["fog2"]) * 0.55
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def trunk_top(d, c, r, rng):
    """A big tree seen from above: a bark disc with growth rings and a few root flares."""
    for k in range(rng.randint(3, 6)):
        ang = rng.uniform(0, 2 * math.pi); ln = r * rng.uniform(1.4, 2.4)
        p = c
        for j in range(4):
            q = (p[0] + math.cos(ang) * ln / 4, p[1] + math.sin(ang) * ln / 4)
            d.line([p, q], fill=PAL["bark1"], width=max(1, int(r * 0.45 * (1 - j / 4))))
            p = q; ang += rng.uniform(-0.4, 0.4)
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=PAL["bark2"], outline=PAL["bark1"])
    if r > 4:
        d.ellipse([c[0] - r * 0.55, c[1] - r * 0.55, c[0] + r * 0.55, c[1] + r * 0.55], outline=PAL["bark3"])
        d.point((c[0], c[1]), fill=PAL["bark3"])


def mushrooms(d, c, rng):
    for _ in range(rng.randint(3, 5)):
        x, y = c[0] + rng.uniform(-4, 4), c[1] + rng.uniform(-3, 3)
        d.point((x, y + 1), fill=PAL["void"])
        d.line([(x - 1, y), (x + 1, y)], fill=PAL["wisp"])
        d.point((x, y - 1), fill=PAL["wisp2"])


def fern(d, c, rng):
    ang = rng.uniform(0, 2 * math.pi)
    for k in range(rng.randint(3, 5)):
        a2 = ang + k * 1.3 + rng.uniform(-0.2, 0.2)
        p = c
        for j in range(4):
            q = (p[0] + math.cos(a2) * 2, p[1] + math.sin(a2) * 2)
            d.line([p, q], fill=PAL["moss3"] if j < 3 else PAL["teal"])
            p = q; a2 += 0.25


def painted_layer(rng):
    """The painted parts at 2 pt/px on a transparent layer."""
    P = L.floor_parts(mode_parts=False)
    field = mask_of(P["outer wall"][1])
    island = mask_of(L.island())
    yy, xx = np.mgrid[0:AH, 0:AW]
    im = Image.new("RGBA", (AW, AH), (0, 0, 0, 0))
    # outside the cabinet: the dark woods, crowded with trunk tops
    outside = np.zeros((AH, AW, 4), np.uint8)
    noise = np.sin(xx * 0.21 + yy * 0.05) * 0.15 + np.sin(yy * 0.13) * 0.1
    lv = np.clip(0.25 + noise, 0, 1)
    ramp = np.array([PAL["void"], PAL["night1"], PAL["bark1"]], np.uint8)
    idx = np.clip((lv * 2 + BAYER[yy % 4, xx % 4] - 0.5).astype(int), 0, 2)
    outside[..., :3] = ramp[idx]; outside[..., 3] = np.where(field, 0, 255)
    im = Image.fromarray(outside, "RGBA")
    d = ImageDraw.Draw(im)
    for _ in range(170):                                   # trunks hugging the cabinet, some roots reaching in
        side = rng.random()
        if side < 0.42:
            x = rng.uniform(-14, 14)
        elif side < 0.84:
            x = rng.uniform(L.W - 12, L.W + 10)
        else:
            x = rng.uniform(0, L.W)
        y = rng.uniform(0, L.H + 20)
        q = to_px((x, y))
        if 0 <= q[0] < AW and 0 <= q[1] < AH and field[int(q[1]), int(q[0])]:
            continue
        trunk_top(d, q, rng.uniform(3, 9), rng)

    # behind the glade: the moon and a layered treeline under the arch (dark, low contrast; wisps fly over it)
    gl = [p for p in P["outer wall"][1] if p[1] > 1150]
    m = to_px((150, 1290))
    d.ellipse([m[0] - 9, m[1] - 9, m[0] + 9, m[1] + 9], fill=PAL["fog3"])
    d.ellipse([m[0] - 6, m[1] - 8, m[0] + 7, m[1] + 5], fill=PAL["ghost"])
    d.ellipse([m[0] - 3, m[1] - 3, m[0] + 0, m[1] + 0], fill=PAL["fog3"])
    for layer, col, base, amp in ((0, "night2", 1215, 70), (1, "night1", 1185, 55), (2, "bark1", 1160, 40)):
        for x in range(25, 600, 3):
            top = base + amp * (0.5 + 0.5 * math.sin(x * 0.05 + layer * 2.1)) * rng.uniform(0.6, 1.0)
            if layer == 2 and rng.random() < 0.15:
                top += rng.uniform(15, 40)                    # a taller bare crown poking up
            bottom = 1150 if layer < 2 else 1150 - (rng.uniform(10, 60) if rng.random() < 0.4 else rng.uniform(0, 12))
            a0, a1 = to_px((x, bottom)), to_px((x + 3, top))
            for px_ in range(int(a0[0]), int(a1[0]) + 1):
                for py in range(int(a1[1]), int(a0[1]) + 1):
                    if 0 <= px_ < AW and 0 <= py < AH and field[py, px_] and not island[py, px_]:
                        if layer < 2 or (px_ + py) % 2 == 0 or py > a1[1] + 3 and py < a0[1] - 2:
                            im.putpixel((px_, py), PAL[col] + (255,))
            if layer == 0:                                     # the back layer fades down into the floor (dithered)
                for py in range(int(a0[1]) + 1, int(to_px((x, 1080))[1])):
                    fade = (py - a0[1]) / (to_px((x, 1080))[1] - a0[1])
                    for px_ in range(int(a0[0]), int(a1[0]) + 1):
                        if 0 <= px_ < AW and 0 <= py < AH and field[py, px_] and not island[py, px_] \
                                and BAYER[py % 4, px_ % 4] > fade:
                            im.putpixel((px_, py), PAL[col] + (255,))
    for _ in range(14):                                       # bare trees standing in the treeline
        x = rng.uniform(40, 580)
        tree(d, to_px((x, 1150)), math.pi / 2 + rng.uniform(-0.15, 0.15), rng.uniform(26, 44), 3, 6, rng)

    # the forest island: dark moss, dithered growth, lane cut-outs, bare trees, the log and the trunk
    isl = [to_px(p) for p in L.island()]
    d.polygon(isl, fill=PAL["moss1"])
    for _ in range(1600):
        x, y = rng.uniform(0, AW - 1), rng.uniform(0, AH - 1)
        if island[int(y), int(x)]:
            d.point((x, y), fill=PAL["moss2"] if rng.random() < 0.7 else PAL["teal"])
    lanes = [[(L.LOG_L_X, L.LOG_MOUTH_Y), (L.LOG_R_X, L.LOG_MOUTH_Y), (L.LOG_R_X, L.LOG_BACK_Y), (L.LOG_L_X, L.LOG_BACK_Y)],
             [(L.TREANT_L_X, L.TREANT_MOUTH_Y), (L.TREANT_R_X, L.TREANT_MOUTH_Y), (L.TREANT_R_X, L.TREANT_BACK_Y),
              (L.TREANT_L_X, L.TREANT_BACK_Y)]]
    for lane in lanes:
        d.polygon([to_px(p) for p in lane], fill=PAL["night2"])
        for _ in range(80):
            x = rng.uniform(lane[0][0] + 4, lane[1][0] - 4); y = rng.uniform(lane[0][1], lane[2][1])
            d.point(to_px((x, y)), fill=PAL["night3"] if rng.random() < 0.7 else PAL["bark2"])
    lane_masks = [mask_of(l) for l in lanes]
    placed = 0
    while placed < 22:                                        # big trunk tops on the island, then bare crowns
        x, y = rng.uniform(80, 520), rng.uniform(820, 1100)
        q = to_px((x, y)); qi = (int(q[1]), int(q[0]))
        if island[qi] and not any(mm[qi] for mm in lane_masks):
            trunk_top(d, q, rng.uniform(3, 6), rng); placed += 1
    placed = 0
    while placed < 26:
        x, y = rng.uniform(80, 520), rng.uniform(820, 1110)
        q = to_px((x, y)); qi = (int(q[1]), int(q[0]))
        if island[qi] and not any(mm[qi] for mm in lane_masks):
            tree(d, q, math.pi / 2 + rng.uniform(-0.3, 0.3), rng.uniform(8, 15), 3, 5, rng); placed += 1
    lx0, ly0 = to_px((L.LOG_L_X + 3, L.LOG_HOLE[1] + 26)); lx1, ly1 = to_px((L.LOG_R_X - 3, L.LOG_HOLE[1] - 20))
    d.rounded_rectangle([lx0, ly0, lx1, ly1], radius=5, fill=PAL["bark3"], outline=PAL["bark1"])
    for k in range(3):
        d.line([(lx0 + 3, ly0 + 4 + k * 5), (lx1 - 3, ly0 + 4 + k * 5)], fill=PAL["bark2"])
    mushrooms(d, (lx1 - 3, ly0 + 2), rng)
    c = to_px(L.LOG_HOLE)
    d.ellipse([c[0] - 8, c[1] - 7, c[0] + 8, c[1] + 7], fill=PAL["void"], outline=PAL["bark2"])
    tx0, ty0 = to_px((L.CX - L.TRUNK_HALF - 4, L.TREANT_BACK_Y)); tx1, ty1 = to_px((L.CX + L.TRUNK_HALF + 4, L.TRUNK_Y))
    d.rectangle([tx0, ty0, tx1, ty1], fill=PAL["bark2"])
    for k in range(6):
        x = tx0 + 3 + k * 7
        d.line([(x, ty0), (x + rng.choice([-1, 0, 1]), ty1)], fill=PAL["bark1"])

    # the floor's edges: roots creeping in from the walls, glowing mushrooms, ferns (kept off the flippers' area)
    for _ in range(26):
        y = rng.uniform(330, 1120); left = rng.random() < 0.5
        x = 22 if left else 576
        p = to_px((x, y)); ang = (0 if left else math.pi) + rng.uniform(-0.6, 0.6)
        for j in range(rng.randint(3, 6)):
            q = (p[0] + math.cos(ang) * 3, p[1] + math.sin(ang) * 3)
            qi = (int(q[1]), int(q[0]))
            if not (0 <= qi[0] < AH and 0 <= qi[1] < AW) or not field[qi] or island[qi]:
                break
            d.line([p, q], fill=PAL["bark1"], width=2 if j < 2 else 1)
            p = q; ang += rng.uniform(-0.5, 0.5)
    spots = [(36, 470), (40, 760), (560, 600), (548, 905), (90, 1135), (505, 1120), (120, 330), (480, 330),
             (230, 760), (372, 760)]
    for x, y in spots:
        q = to_px((x, y)); qi = (int(q[1]), int(q[0]))
        if field[qi] and not island[qi]:
            mushrooms(d, q, rng)
    for x, y in [(45, 560), (555, 520), (60, 1000), (540, 1010), (150, 420), (450, 420), (30, 880)]:
        q = to_px((x, y)); qi = (int(q[1]), int(q[0]))
        if field[qi] and not island[qi]:
            fern(d, q, rng)

    # the shooter lane: dark boards
    sl = [(L.WALL_R, L.SHOOT_FLOOR_Y), (L.W - 15, L.SHOOT_FLOOR_Y), (L.W - 15, 1150), (L.WALL_R, 1150)]
    d.polygon([to_px(p) for p in sl], fill=PAL["bark1"])
    for y in range(int(L.SHOOT_FLOOR_Y), 1150, 24):
        d.line([to_px((L.WALL_R, y)), to_px((L.W - 15, y))], fill=PAL["bark2"])
    # the Graveyard: little headstones up the left orbit lane
    for y in (830, 930, 1010):
        c = to_px((46, y))
        d.rectangle([c[0] - 4, c[1] - 5, c[0] + 4, c[1] + 4], fill=PAL["stone2"], outline=PAL["stone1"])
        d.point((c[0], c[1] - 2), fill=PAL["stone3"])
    # walls: stone edging; the island's rim in bark; posts as stone studs; the well's ring
    skip = {"island", "trunk", "launch gate", "upper flipper"}
    for nm, part in P.items():
        if part[0] != "poly" or nm in skip or nm.startswith("bark") or nm.startswith("sling"):
            continue
        q = [to_px(p) for p in part[1]]
        d.line(q, fill=PAL["stone1"], width=3)
        d.line(q, fill=PAL["stone2"], width=1)
    d.line(isl + [isl[0]], fill=PAL["bark2"], width=2)
    d.line(isl + [isl[0]], fill=PAL["bark3"], width=1)
    for nm, part in P.items():
        if part[0] == "circle" and "flipper" not in nm and "sling" not in nm:
            c = to_px(part[1]); r = max(2, part[2] / S)
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=PAL["stone2"], outline=PAL["stone1"])
            d.point((c[0] - 1, c[1] - 1), fill=PAL["stone3"])
    c = to_px(L.WELL_HOLE)
    d.ellipse([c[0] - 11, c[1] - 11, c[0] + 11, c[1] + 11], fill=PAL["stone2"], outline=PAL["stone3"])
    for k in range(8):
        ang = k * math.pi / 4
        d.point((c[0] + 9 * math.cos(ang), c[1] + 9 * math.sin(ang)), fill=PAL["stone1"])
    d.ellipse([c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7], fill=PAL["void"])
    return im


def paint():
    rng = random.Random(9)
    floor = floor_layer(rng).convert("RGBA")
    over = painted_layer(rng).resize((FW, FH), Image.NEAREST)
    floor.alpha_composite(over)
    return lock(floor).convert("RGB")


if __name__ == "__main__":
    art = paint()
    big = art.resize((FW * UP, FH * UP), Image.NEAREST)
    big.save(sys.argv[1] if len(sys.argv) > 1 else "qf_playfield.png", optimize=True)
    if len(sys.argv) > 2:
        art.resize((FW * 3 // 2, FH * 3 // 2), Image.NEAREST).save(sys.argv[2])
    print("art", art.size, "->", big.size)
