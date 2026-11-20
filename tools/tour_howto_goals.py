"""Table 06 (Orbit: Grand Tour) M10 r3: the How to Play goal pictures.

Unlike the older tables' scripts (which re-composite the art), these start from the game itself: the Simulator in the
TOP camera with `-playlab grandtour -tourCleanShot -tourPose <name>` (build/pose_shots.sh), so the lamps, arrows, planet
window and effects are exactly what the rules light for that goal. This script draws the shots on as dashed gold paths
with step numbers and rings round what to look at, crops to the part that matters and saves ~900 px wide JPEGs
(tour_goal_<name>.jpg) for TourHowToPlay.swift.
World points, y up. TOP camera (TOURMAP): centre (300, 695.32), scale 1.6186 pt of world per screen pt, view 402 × 874 pt,
3 px per screen pt.
Usage: python3 tour_howto_goals.py <poses dir (the <name>.png captures)> <out dir> [names; default all]"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
ONLY = set(sys.argv[3:])
os.makedirs(OUT, exist_ok=True)
CX, CY, S, VW, VH, PX = 300.0, 695.3203125, 1.6185818910598755, 402.0, 874.0, 3
GOLD = (255, 214, 110, 255)
CYAN = (140, 230, 255, 255)


def px(x, y):
    return (((x - CX) / S + VW / 2) * PX, (VH / 2 - (y - CY) / S) * PX)


# Where a ball rests on each flipper, and the shots (TourTableLayout: mouths, tips, craters, targets)
R, L = (345, 212), (223, 212)
SHOTS = {
    "moon": [R, (238, 560), (200, 760), (176, 870), (136, 955)],
    "saturn": [L, (382, 560), (420, 700), (448, 840), (455, 922)],
    "leftOrbit": [R, (150, 700), (85, 872), (44, 1010), (82, 1185), (200, 1262)],
    "rightOrbit": [L, (418, 560), (477, 689), (528, 810), (530, 1010), (482, 1185)],
    "door": [R, (284, 860)],
    "mission": [L, (284, 895)],
    "roc": [R, (78, 630)],
    "ket": [L, (388, 952)],
    "samples": [L, (496, 548)],
}
SPINNERS = [(30, 960), (530, 800)]
CROP_LOW = (-25, 120, 625, 1010)       # world x0, y0, x1, y1
CROP_FULL = (-25, 110, 625, 1300)


def dashed(d, pts, col, width=7, dash=22, gap=14):
    pp = [px(*p) for p in pts]
    for (x0, y0), (x1, y1) in zip(pp, pp[1:]):
        L_ = math.hypot(x1 - x0, y1 - y0)
        t = 0.0
        while t < L_:
            t1 = min(L_, t + dash)
            d.line([(x0 + (x1 - x0) * t / L_, y0 + (y1 - y0) * t / L_),
                    (x0 + (x1 - x0) * t1 / L_, y0 + (y1 - y0) * t1 / L_)], fill=col, width=width)
            t = t1 + gap
    # arrow head at the end
    (xa, ya), (xb, yb) = pp[-2], pp[-1]
    a = math.atan2(yb - ya, xb - xa)
    h = 30
    d.polygon([(xb, yb), (xb - h * math.cos(a - 0.45), yb - h * math.sin(a - 0.45)),
               (xb - h * math.cos(a + 0.45), yb - h * math.sin(a + 0.45))], fill=col)


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


FONT = font(34)


def badge(d, at, num, col=GOLD):
    x, y = px(*at)
    r = 26
    d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=(0, 0, 0, 200), width=3)
    t = str(num)
    w = d.textlength(t, font=FONT)
    d.text((x - w / 2, y - 21), t, font=FONT, fill=(0, 0, 0, 255))


def ring(d, at, r_world, col=GOLD):
    x, y = px(*at)
    r = r_world / S * PX
    for k in range(3):
        d.ellipse([x - r - k, y - r - k, x + r + k, y + r + k], outline=col, width=3)


def shot(d, name, num, col=GOLD):
    pts = SHOTS[name]
    dashed(d, pts, col)
    mid = pts[len(pts) // 2] if len(pts) > 2 else (pts[0][0] + (pts[1][0] - pts[0][0]) * 0.8,
                                                    pts[0][1] + (pts[1][1] - pts[0][1]) * 0.8)
    badge(d, mid, num, col)


def ball(d, at):
    x, y = px(*at)
    r = 9 / S * PX
    d.ellipse([x - r, y - r, x + r, y + r], fill=(200, 205, 215, 255), outline=(40, 40, 50, 255), width=3)


def picture(name, src, crop, draw):
    if ONLY and name not in ONLY:
        return
    im = Image.open(os.path.join(SRC, src + ".png")).convert("RGBA")
    over = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    draw(d)
    im = Image.alpha_composite(im, over)
    x0, y1 = px(crop[0], crop[1])
    x1, y0 = px(crop[2], crop[3])
    im = im.crop((max(0, int(x0)), max(0, int(y0)), min(im.width, int(x1)), min(im.height, int(y1))))
    w = 900
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS).convert("RGB")
    out = os.path.join(OUT, f"tour_goal_{name}.jpg")        # JPEG: ~10× smaller than PNG for these
    im.save(out, quality=86, optimize=True, progressive=True)
    print("saved", out, im.size)


def lit_shots(src):
    for line in open(os.path.join(SRC, src + ".log"), errors="ignore"):
        if line.startswith("TOURPOSE"):
            tail = line.split(" lit ", 1)[1].strip() if " lit " in line else ""
            return [s for s in tail.split(",") if s]
    return []


def lit_paths(src, start=1):
    def f(d):
        for i, s in enumerate(lit_shots(src)):
            shot(d, s, start + i)
    return f


picture("liftoff", "liftoff", CROP_LOW, lambda d: (ball(d, R), shot(d, "door", 1), ring(d, (284, 536), 50), badge(d, (222, 536), 2)))
picture("mission", "mission", CROP_LOW, lambda d: (ball(d, L), shot(d, "mission", 1)))
picture("mercury", "mercury", CROP_FULL, lambda d: (ball(d, R), lit_paths("mercury")(d)))
picture("venus", "venus", CROP_FULL, lambda d: (ring(d, (72, 633), 42), badge(d, (120, 660), 1),
                                                 ring(d, (390, 960), 42), badge(d, (390, 1015), 1),
                                                 lit_paths("venus", 2)(d)))
picture("mars", "mars", CROP_LOW, lambda d: (ball(d, L), shot(d, "samples", 1), ring(d, (532, 527), 26), badge(d, (575, 470), 2)))
picture("moonshot", "moon", CROP_FULL, lambda d: (ball(d, R), shot(d, "moon", 1)))
picture("jupiter", "jupiter", CROP_FULL, lambda d: (shot(d, "leftOrbit", 1), shot(d, "rightOrbit", 1),
                                                     [ring(d, p, 30, CYAN) for p in SPINNERS],
                                                     ring(d, (200, 760), 34), ring(d, (420, 700), 34),
                                                     badge(d, (200, 705), 2), badge(d, (420, 645), 2)))
picture("ringrunner", "saturn", CROP_FULL, lambda d: (ball(d, L), shot(d, "saturn", 1)))
picture("uranus", "uranus", CROP_FULL, lambda d: (ball(d, L), lit_paths("uranus")(d)))
picture("neptune", "neptune", CROP_FULL, lambda d: (shot(d, "leftOrbit", 1), shot(d, "rightOrbit", 1),
                                                     [ring(d, p, 30, CYAN) for p in SPINNERS],
                                                     ring(d, (286, 1062), 80), badge(d, (380, 1030), 2)))
picture("sun", "sun", CROP_FULL, lambda d: (lit_paths("sun")(d), ring(d, (284, 906), 34), badge(d, (284, 965), 3)))
picture("pluto", "pluto", CROP_FULL, lambda d: (shot(d, "leftOrbit", 1), shot(d, "rightOrbit", 1), shot(d, "saturn", 2)))
picture("saves", "saves", (-25, 60, 625, 520), lambda d: (ring(d, (37, 300), 24), badge(d, (37, 345), 1),
                                                          ring(d, (284, 162), 24), badge(d, (284, 215), 2)))
picture("lanes", "lanes", CROP_FULL, lambda d: (ring(d, (56, 408), 44), ring(d, (512, 408), 44),
                                                 badge(d, (56, 470), 1), badge(d, (512, 470), 1),
                                                 ring(d, (286, 1170), 85), badge(d, (286, 1240), 2)))
