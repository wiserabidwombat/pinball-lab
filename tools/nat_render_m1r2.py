"""The Naturalist (Table 11), M1 round 1 render: the field station layout sketch.

Panel 1  grey box: walls, posts, the island, ramp + sky rail, pops, mode-only creature stages (dashed), habitats,
         pymunk shot tracks from both sweet spots (the centre of each measured window at 1,600 pt/s), callouts.
Panel 2  the field-journal look test: the same geometry drawn as a naturalist's plate (paper, ink, watercolor).
Panel 3  the numbers: named passages, the curved fan, orbit / pond / Reed Bed / stuck results, the catch loop.
Writes ../out/nat_station_m1r2.png (and a JPEG copy).
"""
import math, random, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MPoly, Circle as MCirc, FancyBboxPatch
import nat_layout as L
import nat_checks as C
import nat_sim as S

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
FONT_DIR = "/usr/share/fonts/truetype/google-fonts/ofl"
SERIF_I = f"{FONT_DIR}/crimsontext/CrimsonText-Italic.ttf"
SERIF_B = f"{FONT_DIR}/crimsontext/CrimsonText-SemiBoldItalic.ttf"
SERIF = f"{FONT_DIR}/crimsontext/CrimsonText-Regular.ttf"

HAB = {"pond": "#4aa3c7", "cave": "#8a7ca8", "grove": "#5fae5a", "sky": "#e0b84c", "cabin": "#d0844e"}

# ------------------------------------------------------------------ measurements (rerun the sims: fast)
FAN = S.fan(speeds=(1600, 2000))


def main_window(row, shot):
    runs = [r for r in S.windows(row).get(shot, []) if r[1] - r[0] >= 0.75]
    if not runs:
        return None
    a, b = max(runs, key=lambda r: r[1] - r[0])
    return a, b


def track(fl, ang, spd=1600, extra=0.35):
    sp, b = S.launch(S.SWEETS[fl], ang, spd)
    pts, prev, after = [], (b.position.x, b.position.y), None
    for i in range(int(3.0 / S.STEP)):
        sp.step(S.STEP); S.bump(b)
        p = (b.position.x, b.position.y); pts.append(p)
        if after is None and S.event(prev, p):
            after = i
        if after is not None and i - after > extra / S.STEP:
            break
        prev = p
    return pts


TRACKS = []
for fl in ("left", "right"):
    row = FAN[(fl, 1600)]
    for shot in L.SHOTS:
        if fl not in L.SHOT_FLIPPERS[shot]:
            continue
        w = main_window(row, shot)
        if w:
            TRACKS.append((fl, shot, (w[0] + w[1]) / 2, track(fl, (w[0] + w[1]) / 2)))

# ------------------------------------------------------------------ panel 1: grey box (matplotlib)
X0, X1, Y0, Y1 = -10, 650, 0, 1360


def panel_greybox(path):
    fig = plt.figure(figsize=(6.6, 13.6), dpi=100)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(X0, X1); ax.set_ylim(Y0, Y1); ax.set_aspect("equal"); ax.axis("off")
    fig.patch.set_facecolor("#101418"); ax.set_facecolor("#101418")
    # habitats (tint under everything)
    def tint(poly, hab, a=0.16):
        ax.add_patch(MPoly(poly, closed=True, fc=HAB[hab], ec="none", alpha=a, zorder=0))
    tint([(20, 572), (100, 610), (100, 722), (20, 722)], "pond", 0.25)
    tint([(20, 790), (72, 790), (72, 1160), (20, 1150)], "cave", 0.35)
    tint([(500, 780), (580, 780), (580, 1110), (500, 1110)], "grove", 0.22)
    tint([(150, 1150), (600, 1150), (560, 1290), (330, 1330), (150, 1260)], "grove", 0.08)
    tint([(232, 1040), (368, 1040), (368, 1132), (232, 1132)], "cabin", 0.5)
    # the open band
    ax.add_patch(MPoly([(140, 445), (460, 445), (460, 780), (140, 780)], fc="#ffffff", alpha=0.03, ec="#ffffff",
                       ls=(0, (2, 4)), lw=0.6, zorder=0))
    ax.text(300, 462, "open band: lamps + art only", color="#7f8a93", ha="center", va="center", fontsize=7, zorder=1)
    P = L.floor_parts(mode_parts=False)
    for nm, part in P.items():
        if part[0] == "poly":
            xs, ys = zip(*part[1])
            col = "#ff9a3c" if nm.startswith("sling") or nm in ("launch gate",) else "#4fd06b"
            if nm == "island":
                ax.add_patch(MPoly(part[1], closed=True, fc="#1d3a26", ec="#4fd06b", lw=1.2, zorder=2))
                continue
            if nm.startswith("sling"):
                ax.add_patch(MPoly(part[1], closed=True, fc="#2a2118", ec="#ff9a3c", lw=1.2, zorder=2))
                continue
            ax.plot(xs, ys, color=col, lw=1.6 if nm != "grove branch" else 2.4, zorder=3, solid_capstyle="round")
        else:
            c, r = part[1], part[2]
            if nm.startswith("bumper"):
                ax.add_patch(MCirc(c, r, fc="#f08a7e", ec="#ffd2c8", lw=1.0, zorder=3))
            else:
                ax.add_patch(MCirc(c, r, fc="#9aa3ab", ec="#cfd6dc", lw=0.6, zorder=3))
    for piv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, poly = L.flipper_poly(piv, side)
        ax.add_patch(MPoly(poly, closed=True, fc="#e8e8e8", ec="#ffffff", zorder=4))
        ax.add_patch(MCirc(piv, L.FLIP_RP, fc="#e8e8e8", zorder=4)); ax.add_patch(MCirc(tip, L.FLIP_RT, fc="#e8e8e8", zorder=4))
    # sky ramp: plastic band then the rail
    sky = L.sky_path()
    lr, rr = sky.rails(L.RAMP_CHANNEL_HALF)
    k = max(i for i, s in enumerate(sky.dist) if s <= L.SKY_PLASTIC_LEN)
    band = lr[:k + 1] + rr[:k + 1][::-1]
    ax.add_patch(MPoly(band, closed=True, fc="#e0b84c", alpha=0.28, ec="#e0b84c", lw=0.8, zorder=5))
    for rail in sky.rails(9):
        xs, ys = zip(*rail[k:])
        ax.plot(xs, ys, color="#c9d2da", lw=0.9, zorder=5)
    # subways (dashed, under the table)
    for a, b in (((L.CX, L.SPECIMEN_HOLE[1]), L.INLANE_RELEASE_R), (L.REED_HOLE, L.INLANE_RELEASE_L)):
        ax.annotate("", xy=b, xytext=a, arrowprops=dict(arrowstyle="->", color="#6f7b86", lw=0.9, ls=(0, (3, 3))), zorder=1)
    # spinner, switches, catch line, reed hole, specimen hole
    ax.plot([L.GROVE_INNER_X + 3, L.WALL_R - 3], [L.GROVE_SPINNER_Y] * 2, color="#ffe066", lw=3, zorder=4)
    ax.plot([L.LILY_L_X + 6, L.LILY_R_X - 6], [L.LILY_SWITCH_Y] * 2, color="#7fd3ff", lw=1, ls=":", zorder=4)
    ax.plot([L.CABIN_L_X + 6, L.CABIN_R_X - 6], [L.CABIN_CATCH_Y] * 2, color="#ffb27a", lw=1, ls="--", zorder=4)
    ax.add_patch(MCirc(L.REED_HOLE, 15, fc="#05080a", ec="#7fd3ff", lw=1.2, zorder=4))
    ax.add_patch(MCirc(L.SPECIMEN_HOLE, 15, fc="#05080a", ec="#ffb27a", lw=1.2, zorder=4))
    ax.add_patch(MCirc(L.KICKBACK, 9, fc="none", ec="#ff9a3c", lw=1, ls="--", zorder=4))
    # cabin (drawn) and the cave tunnel (drawn)
    x0, y0, x1, y1 = L.CABIN_ART
    ax.add_patch(MPoly([(x0, y0), (x1, y0), (x1, y1 - 30), (300, y1 + 8), (x0, y1 - 30)], fc="none", ec="#d0844e", lw=1,
                       ls=(0, (4, 2)), zorder=6))
    ax.add_patch(MPoly([(18, L.CAVE_TUNNEL[0]), (74, L.CAVE_TUNNEL[0]), (74, 1150), (18, 1150)], fc="#000000", alpha=0.25,
                       ec="#8a7ca8", lw=0.8, ls=(0, (4, 2)), zorder=6))
    # mode-only creature stages (dashed)
    for i, p in enumerate(L.LILY_PADS):
        ax.add_patch(MCirc(p, L.CREATURE_R, fc="none", ec="#7fd3ff", lw=1.1, ls=(0, (2, 2)), zorder=7))
    for a, b in (L.CAVE_PATROL, L.GROVE_PATROL):
        ax.plot([a[0], b[0]], [a[1], b[1]], color="#ffffff", lw=2 * L.CREATURE_R, alpha=0.10, solid_capstyle="round", zorder=7)
        ax.plot([a[0], b[0]], [a[1], b[1]], color="#ffffff", lw=0.8, ls=(0, (2, 2)), zorder=7)
    xs, ys = zip(*L.CANOPY_FLIGHT)
    ax.plot(xs, ys, color="#e0b84c", lw=0.9, ls=(0, (1, 3)), zorder=7)
    xs, ys = zip(*L.rail_flight())
    ax.plot(xs, ys, color="#e0b84c", lw=3, alpha=0.5, ls=(0, (1, 2)), zorder=7)
    # shot tracks
    for fl, shot, ang, pts in TRACKS:
        col = HAB[L.HABITAT_OF[shot]]
        xs, ys = zip(*pts)
        ax.plot(xs, ys, color=col, lw=1.0, alpha=0.9, ls="-" if fl == "left" else (0, (5, 2)), zorder=8)
    for sp in (L.SWEET_L, L.SWEET_R):
        ax.add_patch(MCirc(sp, L.BALL_R, fc="#c0c6cc", ec="#ffffff", lw=0.6, zorder=9))
    # callouts
    calls = [(1, (60, 668), "Reed Bed scoop"), (2, (46, 1005), "Cave tunnel orbit"), (3, (192, 1040), "Lily-pad lane + pond"),
             (4, (300, 1090), "Station cabin · specimen scoop"), (5, (432, 960), "Sky ramp"), (6, (260, 1140), "Sky rail"),
             (7, (550, 1000), "Grove spinner lane"), (8, (556, 1172), "Grove branch"), (9, (316, 1224), "Canopy pops"),
             (10, (45, 320), "kickback slot (companion)")]
    for n, p, _ in calls:
        ax.add_patch(MCirc(p, 11, fc="#ffffff", ec="#101418", lw=1, zorder=10))
        ax.text(p[0], p[1] - 0.5, str(n), ha="center", va="center", fontsize=7, fontweight="bold", color="#101418", zorder=11)
    ax.text(300, 1350, "THE NATURALIST · field station · M1 r2 grey box", color="#e8e8e8", ha="center", va="top", fontsize=9,
            fontweight="bold")
    leg = ["1 Reed Bed scoop (pond, R flipper)", "2 Cave tunnel orbit (R)", "3 Lily-pad lane → pond basin (L + R)",
           "4 Station cabin · specimen scoop (L + R)", "5 Sky ramp (L + R)", "6 Sky rail → left inlane",
           "7 Grove spinner lane (L + R)", "8 Grove branch (turns it into the canopy)", "9 Canopy pops (bees)",
           "10 Kickback slot (companions only)", "dashed white/blue: creature stages (mode)", "tracks: solid = left, dashed = right flipper"]
    for i, t in enumerate(leg):
        ax.text(150, 770 - i * 15.5, t, color="#b8c2ca", fontsize=6.2, ha="left", va="top", zorder=12)
    fig.savefig(path, facecolor=fig.get_facecolor())
    plt.close(fig)


# ------------------------------------------------------------------ panel 2: the field journal look (numpy + PIL)
SC = 1.0
PW, PH = int(660 * SC), int(1360 * SC)


def to_px(p):
    return ((p[0] - X0) * SC, (Y1 - p[1]) * SC)


def value_noise(w, h, cell, seed):
    rng = np.random.default_rng(seed)
    gw, gh = w // cell + 3, h // cell + 3
    g = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)[:h, :w] / 255.0


def fbm(w, h, seed, cells=(160, 60, 22, 8), weights=(0.45, 0.3, 0.17, 0.08)):
    out = np.zeros((h, w), np.float32)
    for i, (c, wt) in enumerate(zip(cells, weights)):
        out += wt * value_noise(w, h, c, seed + i)
    return out


def poly_mask(polys, blur=0):
    m = Image.new("L", (PW, PH), 0)
    d = ImageDraw.Draw(m)
    for poly in polys:
        d.polygon([to_px(p) for p in poly], fill=255)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m, dtype=np.float32) / 255.0


def wash(paper, polys, rgb, strength=0.55, seed=0, blur=5):
    """Watercolor: a noisy, edge-darkened glaze multiplied onto the paper."""
    m = poly_mask(polys)
    soft = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255
    wob = fbm(PW, PH, seed, cells=(90, 30, 9), weights=(0.5, 0.35, 0.15))
    cov = np.clip(soft * (0.55 + 0.75 * wob) - 0.08, 0, 1)
    edge = np.clip(soft - np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur * 3)),
                                     np.float32) / 255, 0, 1)
    a = np.clip(cov * strength + edge * 0.9 * strength, 0, 1)[..., None]
    col = np.array(rgb, np.float32)[None, None, :] / 255
    return paper * (1 - a + a * col)


def wobble(pts, amp=1.2, seed=0, step=6):
    rng = random.Random(seed)
    out = []
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.dist(a, b) / step))
        for i in range(n):
            t = i / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    out.append(pts[-1])
    ph = rng.random() * 10
    res = []
    for i, p in enumerate(out):
        res.append((p[0] + amp * math.sin(i * 0.37 + ph) + rng.uniform(-amp, amp) * 0.3,
                    p[1] + amp * math.cos(i * 0.29 + ph * 1.3) + rng.uniform(-amp, amp) * 0.3))
    return res


def ink(draw, pts, w=1.6, col=(58, 42, 30, 235), seed=0, passes=2):
    for k in range(passes):
        q = [to_px(p) for p in wobble(pts, amp=0.9 + 0.5 * k, seed=seed * 7 + k)]
        draw.line(q, fill=col if k == 0 else (col[0], col[1], col[2], 120), width=max(1, int(round(w * SC - k * 0.5))),
                  joint="curve")


def ink_circle(draw, c, r, w=1.4, seed=0, col=(58, 42, 30, 235)):
    pts = [(c[0] + r * math.cos(2 * math.pi * i / 28), c[1] + r * math.sin(2 * math.pi * i / 28)) for i in range(30)]
    ink(draw, pts, w=w, seed=seed, col=col)


def hatch(layer, polys, spacing=7, angle=50, col=(70, 55, 40, 70)):
    m = poly_mask(polys)
    lines = Image.new("L", (PW, PH), 0)
    d = ImageDraw.Draw(lines)
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    for k in range(-PH * 2, PW * 2, spacing):
        x0, y0 = k, 0
        d.line([(x0 - 2000 * ca, y0 - 2000 * sa), (x0 + 2000 * ca, y0 + 2000 * sa)], fill=255, width=1)
    lv = np.asarray(lines, np.float32) / 255 * m
    lay = Image.new("RGBA", (PW, PH), col[:3] + (0,))
    lay.putalpha(Image.fromarray((lv * col[3]).astype(np.uint8)))
    layer.alpha_composite(lay)


def frog_sketch(draw, c, s=1.0, seed=3):
    """A Lantern Frog doodle: ink body, legs, eyes (washed + glow added separately)."""
    cx, cy = c
    body = [(cx + 34 * s * math.cos(t), cy + 22 * s * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 30)]
    ink(draw, body, w=1.5, seed=seed)
    for sx in (-1, 1):
        ink(draw, [(cx + sx * 26 * s, cy - 8 * s), (cx + sx * 46 * s, cy - 22 * s), (cx + sx * 30 * s, cy - 26 * s),
                   (cx + sx * 52 * s, cy - 30 * s)], w=1.3, seed=seed + sx)
        ink(draw, [(cx + sx * 14 * s, cy - 18 * s), (cx + sx * 18 * s, cy - 32 * s), (cx + sx * 26 * s, cy - 34 * s)],
            w=1.2, seed=seed + 5 + sx)
        ink_circle(draw, (cx + sx * 15 * s, cy + 20 * s), 8 * s, w=1.3, seed=seed + 9 + sx)
    ink(draw, [(cx - 16 * s, cy + 6 * s), (cx, cy + 2 * s), (cx + 16 * s, cy + 6 * s)], w=1.1, seed=seed + 20)


CANOPY_POLY = [(x, y - 6) for x, y in L.arch() if y > L.roof_y(min(max(x, 72), 520)) + 20 and 30 < x < 610] + [L.ROOF_R, L.ROOF_L]


def panel_journal(path):
    base = np.array([241, 232, 210], np.float32) / 255
    n = fbm(PW, PH, 7)
    grain = np.random.default_rng(5).normal(0, 1, (PH, PW)).astype(np.float32)
    grain = np.asarray(Image.fromarray(np.clip(grain * 40 + 128, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)),
                       np.float32) / 255 - 0.5
    yy, xx = np.mgrid[0:PH, 0:PW]
    vig = 1 - 0.18 * (((xx - PW / 2) / (PW / 2)) ** 2 + ((yy - PH / 2) / (PH / 2)) ** 2) ** 1.4
    paper = base[None, None, :] * (0.93 + 0.1 * n[..., None] + 0.05 * grain[..., None]) * vig[..., None]
    # habitat washes
    paper = wash(paper, [[(20, 560), (110, 600), (110, 730), (20, 735)]], (150, 200, 220), 0.5, seed=11, blur=8)
    paper = wash(paper, [[(L.LILY_L_X, 805), (L.LILY_R_X, 805), (250, 950), (250, 1080), (96, 1080), (96, 950)]],
                 (90, 160, 200), 0.55, seed=12)
    paper = wash(paper, [[(18, 790), (74, 790), (74, 1160), (18, 1150)]], (110, 95, 130), 0.75, seed=13)
    paper = wash(paper, [[(500, 770), (582, 770), (582, 1120), (500, 1120)], CANOPY_POLY],
                 (130, 185, 110), 0.5, seed=14, blur=7)
    paper = wash(paper, [[(L.CABIN_ART[0], L.CABIN_ART[1]), (L.CABIN_ART[2], L.CABIN_ART[1]), (L.CABIN_ART[2], L.CABIN_ART[3] - 30),
                          (300, L.CABIN_ART[3] + 8), (L.CABIN_ART[0], L.CABIN_ART[3] - 30)]], (200, 140, 95), 0.6, seed=15)
    sky = L.sky_path(); lr, rr = sky.rails(L.RAMP_CHANNEL_HALF)
    k = max(i for i, s in enumerate(sky.dist) if s <= L.SKY_PLASTIC_LEN)
    paper = wash(paper, [lr[:k + 1] + rr[:k + 1][::-1]], (232, 200, 120), 0.5, seed=16, blur=3)
    paper = wash(paper, [L.island()], (180, 170, 140), 0.25, seed=17, blur=3)
    img = Image.fromarray((np.clip(paper, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    hatch(img, [L.island()], spacing=8, angle=55)
    hatch(img, [[(18, L.CAVE_TUNNEL[0]), (74, L.CAVE_TUNNEL[0]), (74, 1150), (18, 1150)]], spacing=4, angle=-40,
          col=(50, 40, 60, 90))
    lay = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    P = L.floor_parts(mode_parts=False)
    for i, (nm, part) in enumerate(P.items()):
        if part[0] == "poly":
            w = 1.9 if nm in ("outer wall", "right wall", "island") else 1.5
            ink(d, part[1], w=w, seed=i)
        elif nm.startswith("bumper"):
            ink_circle(d, part[1], part[2], w=1.5, seed=i)
            ink_circle(d, part[1], part[2] * 0.55, w=1.0, seed=i + 50)
        else:
            ink_circle(d, part[1], part[2], w=1.1, seed=i)
    for piv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, poly = L.flipper_poly(piv, side)
        ink(d, poly + [poly[0]], w=1.5, seed=99 if side == "L" else 98)
    for rail in sky.rails(9):
        ink(d, rail[k:], w=1.0, seed=77, col=(90, 80, 70, 200), passes=1)
    for rail in (lr[:k + 1], rr[:k + 1]):
        ink(d, rail, w=1.2, seed=78)
    # trees along the grove lane, reeds by the scoop, rocks in the cave, lily pads
    rng = random.Random(4)
    for y in range(860, 1100, 46):
        for x in (509, 589):
            ink_circle(d, (x + rng.uniform(-3, 3), y + rng.uniform(-6, 6)), 9 + rng.uniform(-2, 3), w=1.2, seed=y + x)
    for i in range(9):
        x = 26 + i * 4.5
        ink(d, [(x, 580 + rng.uniform(0, 10)), (x + rng.uniform(-4, 4), 640 + rng.uniform(0, 30))], w=1.0, seed=300 + i)
    for p in L.LILY_PADS:
        pts = [(p[0] + 14 * math.cos(t), p[1] + 11 * math.sin(t)) for t in np.linspace(0.35, 2 * math.pi - 0.1, 24)] + [p]
        ink(d, pts + [pts[0]], w=1.1, seed=int(p[0]))
    # the cabin
    x0, y0, x1, y1 = L.CABIN_ART
    ink(d, [(x0 + 10, y0), (x1 - 10, y0), (x1 - 10, y1 - 34), (300, y1 + 4), (x0 + 10, y1 - 34), (x0 + 10, y0)], w=1.6, seed=500)
    ink(d, [(x0 + 4, y1 - 30), (300, y1 + 10), (x1 - 4, y1 - 30)], w=1.3, seed=501)
    for xx_ in (264, 336):
        ink(d, [(xx_ - 10, 1060), (xx_ + 10, 1060), (xx_ + 10, 1078), (xx_ - 10, 1078), (xx_ - 10, 1060)], w=1.0, seed=xx_)
    img.alpha_composite(lay)
    # frog plate with lantern-eye glow
    glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    fc = (300, 690 + 0)
    for sx in (-1, 1):
        ex, ey = to_px((fc[0] + sx * 15 * 1.6, fc[1] + 20 * 1.6))
        gd.ellipse([ex - 22, ey - 22, ex + 22, ey + 22], fill=(255, 210, 90, 140))
    glow = glow.filter(ImageFilter.GaussianBlur(9))
    img.alpha_composite(glow)
    fpaper = np.asarray(img.convert("RGB"), np.float32) / 255
    fpaper = wash(fpaper, [[(fc[0] + 54 * math.cos(t), fc[1] + 36 * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 30)]],
                  (120, 170, 90), 0.6, seed=40, blur=3)
    img = Image.fromarray((np.clip(fpaper, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    lay2 = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(lay2)
    frog_sketch(d2, fc, s=1.6)
    img.alpha_composite(lay2)
    # annotations
    d3 = ImageDraw.Draw(img)
    fI = ImageFont.truetype(SERIF_I, int(15 * SC)); fS = ImageFont.truetype(SERIF_I, int(12 * SC))
    fT = ImageFont.truetype(SERIF_B, int(22 * SC)); fR = ImageFont.truetype(SERIF, int(12 * SC))
    sep = (70, 50, 34)
    def note(p, text, f=fS, anchor="la"):
        d3.text(to_px(p), text, fill=sep, font=f, anchor=anchor)
    d3.text(to_px((300, 606)), "The Naturalist — Field Station, Plate XI", fill=sep, font=fT, anchor="ma")
    d3.text(to_px((300, 578)), "look test · paper, ink and wash · not the final art", fill=(110, 90, 70), font=fS, anchor="ma")
    note((86, 660), "Reed Bed")
    note((24, 1170), "the Cave", f=fI)
    note((100, 1096), "pond", f=fI)
    note((262, 1018), "specimen scoop", f=fS)
    note((300, 1146), "Station Cabin", f=fI, anchor="ma")
    note((418, 1040), "sky ramp", f=fS)
    note((470, 1262), "the Canopy", f=fI)
    note((508, 790), "the Grove", f=fI)
    note((210, 760), "Fig. 4 — Lantern Frog (Rana lucerna)", f=fS)
    note((214, 744), "eyes glow at dusk; hops pad to pad", f=fS)
    # a scale bar like a plate
    sx0, sy0 = to_px((420, 120))
    d3.line([sx0, sy0, sx0 + 60 * SC, sy0], fill=sep, width=2)
    for t in (0, 30, 60):
        d3.line([sx0 + t * SC, sy0 - 4, sx0 + t * SC, sy0 + 4], fill=sep, width=1)
    d3.text((sx0, sy0 + 6), "two balls", fill=sep, font=fR)
    img.convert("RGB").save(path)


# ------------------------------------------------------------------ panel 3: numbers + the catch loop
def panel_numbers(path):
    fig = plt.figure(figsize=(7.4, 13.6), dpi=100)
    fig.patch.set_facecolor("#f6f3ec")
    ax = fig.add_axes([0, 0, 1, 1]); ax.axis("off"); ax.set_xlim(0, 740); ax.set_ylim(0, 1360)
    y = [1340]

    def line(t, size=7.2, bold=False, color="#222", dx=0, gap=None):
        ax.text(16 + dx, y[0], t, fontsize=size, fontweight="bold" if bold else "normal", color=color, va="top",
                family="DejaVu Sans")
        y[0] -= gap if gap else size * 2.05

    line("CHECKS · real scale (ball r 15): closed < 30, passages >= 45", 9, True)
    flagged = 0
    for name, g, v, *_ in C.named_passages():
        bad = v in ("WEDGE RISK", "TOO NARROW")
        flagged += bad
        if bad or "mouth" in name or "lane" in name.lower() or "branch" in name or "bumper" in name or "patrol" in name or "frog" in name:
            line(f"{name[:62]:62s} {g:6.1f}  {v}", 6.3, color="#b00020" if bad else "#333")
    pairs = [r for r in C.scan_pairs(45) if r[3] == "WEDGE RISK"]
    line(f"Every named passage: {'OK' if not flagged else str(flagged) + ' flagged'}.  Other pairs in the 30-45 band: {len(pairs)}.",
         7.2, True, gap=22)
    line("CURVED FAN · pymunk, sweet spots (243, 214) / (357, 214), main window per shot (deg, width)", 9, True)
    for fl in ("left", "right"):
        for spd in (1600, 2000):
            row = FAN[(fl, spd)]
            parts = []
            for shot in sorted(L.SHOTS, key=lambda s: C.shot_fan().get(fl, {}).get(s, 999)):
                if fl not in L.SHOT_FLIPPERS[shot]:
                    continue
                w = main_window(row, shot)
                if w:
                    parts.append(f"{shot.split()[0]} {w[0]:.1f}-{w[1]:.1f} ({w[1] - w[0] + 0.25:.2f})")
            line(f"{fl:5s} @ {spd}: " + " · ".join(parts), 6.0)
    y[0] -= 6
    line("FOLLOW-ONS (pymunk, every shot in its window at 1,600 + 2,000)", 9, True)
    for t in RESULTS:
        line(t, 6.4)
    y[0] -= 8
    line("THE CATCH LOOP (rules later; the layout makes room for it)", 9, True)
    steps = [("BAIT", "shoot a habitat's lane 3x\n(pond: lily lane or Reed Bed;\ncave orbit; grove lane; sky ramp)"),
             ("APPEARS", "its creature comes out on that\nhabitat's stage: hops, patrols\nor flies (dashed in panel 1)"),
             ("STUN", "hit it: a shot up that same\nlane or ramp meets it"),
             ("CATCH", "specimen scoop (centre, both\nflippers) before it recovers;\nrarer = more hits, faster")]
    bx, by = 20, y[0] - 112
    for i, (h, t) in enumerate(steps):
        x = bx + i * 178
        ax.add_patch(FancyBboxPatch((x, by), 160, 104, boxstyle="round,pad=4", fc="#fffdf7", ec="#7a5a3a", lw=1))
        ax.text(x + 80, by + 92, h, ha="center", va="top", fontsize=8.5, fontweight="bold", color="#5a3d22")
        ax.text(x + 80, by + 70, t, ha="center", va="top", fontsize=6.2, color="#333")
        if i < 3:
            ax.annotate("", xy=(x + 176, by + 52), xytext=(x + 164, by + 52), arrowprops=dict(arrowstyle="->", color="#7a5a3a"))
    ax.annotate("", xy=(bx + 20, by - 4), xytext=(bx + 3 * 178 + 140, by - 4),
                arrowprops=dict(arrowstyle="->", color="#7a5a3a", connectionstyle="arc3,rad=-0.25", ls=(0, (3, 2))))
    ax.text(bx + 330, by - 50, "it recovers → flees back to its stage (bait stays set)", ha="center", fontsize=6.3, color="#5a3d22")
    y[0] = by - 72
    line("CREATURE STAGES (mode-only)", 9, True)
    for t in ["Pond: 3 lily pads in the basin (frog hops pad to pad); each pad >= 45 clear of the basin walls.",
              "Cave: patrol up/down the tunnel lane (bat); 13 pt to each wall, so the orbit must hit it.",
              "Grove: patrol up/down the grove lane (squirrel); 17 pt to each wall, the same rule.",
              "Sky: along the sky rail's top run (swift, ramp layer: a ramp ball meets it) and a glide",
              "      across the canopy (owl). Upper ledge = the island's roof (wren).",
              "Room for a 2nd creature at once (multiball): each habitat has its own stage."]:
        line(t, 6.4)
    fig.savefig(path, facecolor=fig.get_facecolor())
    plt.close(fig)


def follow_results():
    out = []
    agg = {}
    for (fl, spd), row in FAN.items():
        for a, e in row:
            if e in ("Cave orbit",) and fl == "right":
                f, made, where = S.orbit_round(fl, a, spd)
                r = agg.setdefault("cave", [0, 0]); r[0] += made; r[1] += 1
            if e == "Grove lane":
                first, where, path = S.follow(fl, a, spd, seconds=6)
                canopy = any(p[0] < 480 and p[1] > 1150 for p in path)
                pops = any(any(math.dist(p, b) < L.BUMPER_R + L.BALL_R + 1.5 for b in L.BUMPERS) for p in path)
                r = agg.setdefault("grove " + fl, [0, 0, 0]); r[0] += canopy; r[1] += pops; r[2] += 1
    c = agg["cave"]
    out.append(f"Cave orbit (right flipper): {c[0]}/{c[1]} go round the top and come down the grove lane;")
    out.append("   the misses stall at the top of the arch (Quest's arch; it went round on the phone). Shot Lab decides.")
    for fl in ("left", "right"):
        g = agg["grove " + fl]
        out.append(f"Grove lane ({fl}): {g[0]}/{g[2]} turned into the canopy by the branch, {g[1]}/{g[2]} reach the pops.")
    out.append("   (without the branch 45% fell straight back down the lane off the arch's flat shoulder)")
    out.append(LILY_TXT)
    out.append(REED_TXT)
    out.append(STUCK_TXT)
    return out


def lily_text():
    n = hit = outl = 0
    lands = {}
    for (fl, spd), row in FAN.items():
        for a, e in row:
            if e != "Lily-pad lane":
                continue
            for pad in L.LILY_PADS:
                sp = S.new_space(pads=[pad])
                u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
                b = S.ball(sp, S.SWEETS[fl], (spd * u[0], spd * u[1]))
                h = False
                for _ in range(int(7 / S.STEP)):
                    sp.step(S.STEP)
                    q = (b.position.x, b.position.y)
                    if math.dist(q, pad) < L.CREATURE_R + L.BALL_R + 2:
                        h = True
                    if q[1] < 440 and b.velocity.y < 0:
                        outl += q[0] < L.GUIDE_X
                        break
                n += 1; hit += h
    return f"Lily-pad lane with the frog out: it's hit {hit}/{n}; the ball comes back out to the left side, {outl}/{n} down the left outlane."


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    LILY_TXT = lily_text()
    out, by = S.reed_trials()
    REED_TXT = f"Reed Bed (Quest's Old Well pocket): in {out['in']}/33, left outlane {out['outlane L']}/33, back in play {out['play']}/33."
    s, c_, n, rows = S.stuck_test()
    s2 = sum(S.stuck_test(300, seed=30 + i, pads=[L.LILY_PADS[i]])[0] for i in range(3))
    STUCK_TXT = f"Stuck test: {s}/{n} balls rest outside a catch zone; with the frog on each pad: {s2}/900."
    RESULTS = follow_results()
    a, b, c = (os.path.join(OUT, f) for f in ("_p1.png", "_p2.png", "_p3.png"))
    panel_greybox(a); panel_journal(b); panel_numbers(c)
    ims = [Image.open(p).convert("RGB") for p in (a, b, c)]
    H_ = max(i.height for i in ims)
    ims = [i.resize((int(i.width * H_ / i.height), H_)) for i in ims]
    W_ = sum(i.width for i in ims)
    sheet = Image.new("RGB", (W_, H_), (246, 243, 236))
    x = 0
    for i in ims:
        sheet.paste(i, (x, 0)); x += i.width
    sheet.save(os.path.join(OUT, "nat_station_m1r2.png"))
    sheet.save(os.path.join(OUT, "nat_station_m1r2.jpg"), quality=88)
    print("\n".join(RESULTS))
    print("saved", sheet.size)
