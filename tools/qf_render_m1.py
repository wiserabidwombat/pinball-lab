"""Render the Haunted Forest layout sketch (Quest & Flipper, Table 09, M1 round 1).
Panel 1: grey-box layout with shot lines, the open band, mode-only parts and gap callouts.
Panel 2: a pixel-art mood test of the same layout (2 pt per art pixel, a fixed 24-colour palette).
Panel 3: the check tables (gaps, shot fan, pymunk results)."""
import math, random, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle, Rectangle
from PIL import Image, ImageDraw, ImageFilter
import qf_layout as L
import qf_checks as C

BG = "#0d1110"; WALL = "#5fd38a"; KICK = "#ff9a3c"; POST = "#a9b0b4"; RAMP = "#5fd38a"; WIRE = "#c9d2d8"
MODE = "#e26bff"; TOY = "#7fe3ff"; TXT = "#e8efe9"; DIM = "#7c8a83"

def poly(ax, pts, **kw):
    xs, ys = zip(*pts); ax.plot(xs, ys, **kw)

def draw_layout(ax):
    ax.set_facecolor(BG)
    P = L.floor_parts(mode_parts=False)
    # the open band: sling tops to the shot line (the lane mouths)
    ax.add_patch(Rectangle((L.WALL_L, L.SLING_TOP_L[1]), L.WALL_R - L.WALL_L, L.LOG_MOUTH_Y - L.SLING_TOP_L[1],
                           color="#1d2a24", zorder=0))
    ax.text(300, 590, "open band (sling tops → shot line)\nonly mode pop-ups + lamps here", color=DIM, ha="center", va="center", fontsize=7, zorder=1)
    # island fill
    ax.add_patch(Polygon(L.island(), closed=True, facecolor="#17271f", edgecolor=WALL, lw=1.4, zorder=3))
    for nm, part in P.items():
        if nm == "island":
            continue
        col = WALL
        if nm.startswith("sling ") and "post" not in nm:
            col = WALL
        if nm == "launch gate":
            col = KICK
        if part[0] == "poly":
            poly(ax, part[1], color=col, lw=1.4, zorder=4)
        else:
            ax.add_patch(Circle(part[1], part[2], color=POST, zorder=5))
    # sling kicking faces (orange)
    for f in (lambda p: p, L.M):
        a, b = f(L.SLING_TOP_L), f(L.SLING_TIP_L)
        poly(ax, [a, b], color=KICK, lw=2.4, zorder=6)
    # targets
    for i, x in enumerate(L.BARK_XS):
        ax.add_patch(Rectangle((x - L.BARK_W / 2, L.BARK_Y), L.BARK_W, L.BARK_DEPTH, color="#c98a4b", zorder=6))
    poly(ax, [(L.CX - L.TRUNK_HALF, L.TRUNK_Y), (L.CX + L.TRUNK_HALF, L.TRUNK_Y)], color="#ffcf6b", lw=4, zorder=6)
    fa, fb, *_ = L.LANTERN_E
    poly(ax, [fa, fb], color="#ffcf6b", lw=4, zorder=6)
    # scoops / holes
    for c, r in ((L.WELL_HOLE, 15), (L.LOG_HOLE, 15)):
        ax.add_patch(Circle(c, r, facecolor="#000", edgecolor="#ffcf6b", lw=1.5, zorder=6))
    # spinner
    poly(ax, [(L.WALL_L + 2, L.SPINNER_Y), (L.ORBIT_INNER_X - 2, L.SPINNER_Y)], color=KICK, lw=3, zorder=6)
    # ramp (drawn: translucent band from the U's top; the U is floor-solid, part of the island)
    rp = L.ramp_path()
    lr, rr = rp.rails(L.RAMP_CHANNEL_HALF)
    pts_raised = [(p, h) for p, h, s in zip(rp.points, rp.headings, rp.dist) if s >= L.RAMP_U_LEN]
    plastic_end = L.RAMP_APEX_S + 120
    pl = [i for i, s in enumerate(rp.dist) if L.RAMP_U_LEN <= s <= plastic_end]
    band = [lr[i] for i in pl] + [rr[i] for i in reversed(pl)]
    ax.add_patch(Polygon(band, closed=True, facecolor=RAMP, alpha=0.18, edgecolor=RAMP, lw=0.8, zorder=7))
    wi = [i for i, s in enumerate(rp.dist) if s >= plastic_end - 10]
    for side in (lr, rr):
        poly(ax, [side[i] for i in wi], color=WIRE, lw=0.9, zorder=7)
    k = min(range(len(rp.dist)), key=lambda i: abs(rp.dist[i] - L.RAMP_APEX_S))
    ax.plot(*rp.points[k], marker="D", color="#ffcf6b", ms=5, zorder=8)
    ax.add_patch(Circle(L.FOREST_GATE, 16, facecolor="none", edgecolor="#ffcf6b", ls="--", lw=1.2, zorder=8))
    ax.annotate("", xy=L.FOREST_GATE, xytext=rp.points[k], arrowprops=dict(arrowstyle="->", color="#ffcf6b", lw=1, ls="--"), zorder=8)
    # flippers
    for piv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        for raised, a in ((0, 1.0), (L.FLIP_TRAVEL, 0.3)):
            tip, pp = L.flipper_poly(piv, side, raised)
            ax.add_patch(Polygon(pp, closed=True, color="#e8efe9", alpha=a, zorder=6))
            ax.add_patch(Circle(piv, L.FLIP_RP, color="#e8efe9", alpha=a, zorder=6))
            ax.add_patch(Circle(tip, L.FLIP_RT, color="#e8efe9", alpha=a, zorder=6))
    # wisps + their loops
    for i in range(len(L.WISPS)):
        path = L.wisp_path(i)
        poly(ax, path, color=TOY, lw=0.7, ls=":", zorder=6)
        ax.add_patch(Circle(L.WISPS[i][0], L.WISP_R, facecolor=TOY, alpha=0.75, zorder=7))
    # mode-only parts (dashed magenta)
    for h in L.GHOST_HAUNTS:
        ax.add_patch(Circle(h, L.GHOST_R, facecolor="none", edgecolor=MODE, ls="--", lw=1.3, zorder=7))
    ax.add_patch(Circle(L.ROOTS, L.ROOTS_R, facecolor="none", edgecolor=MODE, ls="--", lw=1.3, zorder=7))
    ax.add_patch(Polygon(L.GRAVESTONE, closed=True, facecolor="none", edgecolor=MODE, ls="--", lw=1.3, zorder=7))
    poly(ax, L.drifter_path(), color=MODE, lw=0.8, ls=(0, (2, 4)), zorder=2)
    ax.add_patch(Circle(L.KICKBACK, 9, facecolor="none", edgecolor=KICK, ls="--", lw=1.2, zorder=6))
    # shot lines
    cols = {"left": "#57b6ff", "right": "#ffd34d"}
    for fl, sp in (("left", L.SWEET_L), ("right", L.SWEET_R)):
        for k2, tgt in L.SHOTS.items():
            if fl in L.SHOT_FLIPPERS[k2]:
                ax.plot([sp[0], tgt[0]], [sp[1], tgt[1]], color=cols[fl], lw=0.8, alpha=0.75, zorder=9)
    # labels
    lab = dict(color=TXT, fontsize=7.5, ha="center", zorder=12, fontweight="bold")
    ax.text(*L.WELL_HOLE, "", **lab)
    ax.text(70, 668, "OLD\nWELL", **lab)
    ax.text(46, 960, "GRAVE-\nYARD\norbit", color=TXT, fontsize=6.5, ha="center", zorder=12, fontweight="bold")
    ax.text(L.LOG_HOLE[0], 960, "HOLLOW\nLOG", **lab)
    ax.text(300, 1050, "TREANT", **lab)
    ax.text(300, 966, "bark", color="#c98a4b", fontsize=6.5, ha="center", zorder=12)
    ax.text(300, 1018, "trunk", color="#1d1d1d", fontsize=6, ha="center", va="bottom", zorder=12)
    ax.text(L.RAMP_C_X, 960, "OLD\nROAD\nramp", **lab)
    ax.text(L.FOREST_GATE[0] - 4, L.FOREST_GATE[1] + 22, "FOREST GATE\n(exit, when lit)", color="#ffcf6b", fontsize=6, ha="center", zorder=12)
    ax.text(500, 760, "EAST\nLANTERN", color="#ffcf6b", fontsize=6.5, ha="center", zorder=12, fontweight="bold")
    ax.text(318, 1290, "WITCH'S GLADE  (wisps)", color=TOY, fontsize=7, ha="center", zorder=12, fontweight="bold")
    ax.text(305, 700, "ghost haunts", color=MODE, fontsize=6.5, ha="center", zorder=12)
    ax.text(300, 532, "gravestone (boss)", color=MODE, fontsize=6, ha="center", zorder=12)
    ax.text(470, 505, "roots\n(Treant)", color=MODE, fontsize=6, ha="left", zorder=12)
    ax.text(550, 612, "drifting\nghost", color=MODE, fontsize=6, ha="right", zorder=12)
    ax.text(45, 272, "kickback\n(gear)", color=KICK, fontsize=5.5, ha="center", va="top", zorder=12)
    ax.text(602, 600, "shooter lane", color=DIM, fontsize=6, rotation=90, ha="center", zorder=12)
    ax.text(602, 1080, "▲", color=KICK, fontsize=7, ha="center", zorder=12)
    # gap callouts on named passages
    for name, g, v, p, q in C.named_passages():
        if p is None or q is None or g > 140:
            continue
        col = "#7dffa6" if v in ("OK", "open") else ("#9aa" if v in ("closed", "joined") else "#ff6b6b")
        ax.plot([p[0], q[0]], [p[1], q[1]], color=col, lw=0.7, zorder=10)
        m = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        if v not in ("joined",):
            ax.text(m[0], m[1], f"{g:.0f}", color=col, fontsize=5, zorder=13, ha="center", va="center",
                    bbox=dict(boxstyle="round,pad=0.1", fc=BG, ec="none", alpha=0.7))
    ax.set_xlim(-5, L.W + 5); ax.set_ylim(-5, L.H + 5); ax.set_aspect("equal"); ax.axis("off")
    ax.set_title("Haunted Forest · layout sketch (grey box)", color=TXT, fontsize=10)
    ax.text(10, 10, "blue = left-flipper shots · gold = right · magenta dashed = mode-only · cyan = wisps",
            color=DIM, fontsize=6)

# ---------------------------------------------------------------- pixel-art mood test
PAL = {  # 24-colour Haunted Forest palette (cool darks, one warm family for lantern light)
    "void": (10, 8, 20), "night1": (20, 16, 38), "night2": (31, 24, 56), "night3": (44, 34, 78),
    "moss1": (16, 34, 40), "moss2": (22, 50, 54), "moss3": (34, 72, 72), "teal": (54, 110, 104),
    "bark1": (26, 20, 32), "bark2": (42, 32, 46), "bark3": (64, 50, 62), "stone1": (48, 52, 70),
    "stone2": (72, 78, 100), "stone3": (104, 112, 136), "fog1": (70, 78, 112), "fog2": (112, 122, 156),
    "fog3": (164, 176, 204), "ghost": (196, 226, 236), "wisp": (120, 232, 220), "wisp2": (200, 255, 246),
    "lamp1": (120, 54, 24), "lamp2": (214, 112, 36), "lamp3": (255, 186, 74), "lamp4": (255, 236, 160),
}
S = 2.0     # world pt per art pixel
AW, AH = int(L.W / S), int(L.H / S)

def to_px(p):
    return (p[0] / S, (L.H - p[1]) / S)

def quantize(img):
    cols = np.array(list(PAL.values()), dtype=np.float32)
    a = np.asarray(img.convert("RGB"), dtype=np.float32)
    d = ((a[:, :, None, :] - cols[None, None, :, :]) ** 2).sum(-1)
    return Image.fromarray(cols[d.argmin(-1)].astype(np.uint8))

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

def tree(d, base, ang, length, width, depth, rng):
    if depth == 0 or length < 3:
        return
    x0, y0 = base
    x1 = x0 + math.cos(ang) * length; y1 = y0 - math.sin(ang) * length
    d.line([(x0, y0), (x1, y1)], fill=PAL["bark1"] if depth > 2 else PAL["bark2"], width=max(1, int(width)))
    for k in range(2 if depth < 5 else 3):
        da = rng.uniform(0.25, 0.75) * (1 if k % 2 else -1) + rng.uniform(-0.2, 0.2)
        tree(d, (x1, y1), ang + da, length * rng.uniform(0.62, 0.8), width * 0.68, depth - 1, rng)

def draw_pixel():
    rng = random.Random(7)
    img = Image.new("RGB", (AW, AH), PAL["night1"])
    px = np.asarray(img).copy()
    # floor: vertical gradient night3 (bottom, nearer light) -> night1 (top) with moss patches, ordered dither
    yy, xx = np.mgrid[0:AH, 0:AW]
    t = yy / AH
    noise = (np.sin(xx * 0.11 + np.sin(yy * 0.05) * 2) + np.sin(yy * 0.07 + xx * 0.03)) * 0.25
    lvl = (0.35 + 0.5 * t + noise * 0.4)
    thr = BAYER[yy % 4, xx % 4]
    ramp = [PAL["night1"], PAL["night2"], PAL["moss1"], PAL["moss2"], PAL["night3"]]
    idx = np.clip((lvl * (len(ramp) - 1) + thr - 0.5).astype(int), 0, len(ramp) - 1)
    px = np.array(ramp, dtype=np.uint8)[idx]
    img = Image.fromarray(px)
    d = ImageDraw.Draw(img)
    # path of packed earth up the centre
    for y in range(int(AH * 0.25), int(AH * 0.9)):
        w = 16 + 6 * math.sin(y * 0.05)
        cx = AW * 0.47 + 10 * math.sin(y * 0.02)
        for x in range(int(cx - w), int(cx + w)):
            if (x + y) % 3 == 0 and 0 <= x < AW:
                img.putpixel((x, y), PAL["moss3"] if rng.random() < 0.3 else PAL["night3"])
    # island: dark forest mass with twisted bare trees
    isl = [to_px(p) for p in L.island()]
    d.polygon(isl, fill=PAL["moss1"])
    # dithered moss on the island floor
    for _ in range(900):
        x = rng.uniform(L.ORBIT_INNER_X, L.ISLAND_R_X); y = rng.uniform(800, L.roof_y(x))
        q = to_px((x, y))
        if 0 <= q[0] < AW and 0 <= q[1] < AH and img.getpixel((int(q[0]), int(q[1]))) == PAL["moss1"]:
            d.point(q, fill=PAL["moss2"] if rng.random() < 0.7 else PAL["teal"])
    for _ in range(34):
        x = rng.uniform(L.ORBIT_INNER_X + 6, L.ISLAND_R_X - 6)
        y = L.roof_y(x) - rng.uniform(8, 40)
        tree(d, to_px((x, y)), math.pi / 2 + rng.uniform(-0.3, 0.3), rng.uniform(10, 18), 3, 5, rng)
    # trees in the glade background and along the walls
    for x in (40, 110, 560, 600):
        tree(d, to_px((x, 1180)), math.pi / 2 + rng.uniform(-0.2, 0.2), 30, 4, 6, rng)
    # lane cut-outs (lighter floor)
    for lane in ([(L.LOG_L_X, L.LOG_MOUTH_Y), (L.LOG_R_X, L.LOG_MOUTH_Y), (L.LOG_R_X, L.LOG_BACK_Y), (L.LOG_L_X, L.LOG_BACK_Y)],
                 [(L.TREANT_L_X, L.TREANT_MOUTH_Y), (L.TREANT_R_X, L.TREANT_MOUTH_Y), (L.TREANT_R_X, L.TREANT_BACK_Y), (L.TREANT_L_X, L.TREANT_BACK_Y)]):
        d.polygon([to_px(p) for p in lane], fill=PAL["night2"])
    # hollow log (lying across its lane's back)
    lx0, ly0 = to_px((L.LOG_L_X + 2, L.LOG_BACK_Y + 4)); lx1, ly1 = to_px((L.LOG_R_X - 2, L.LOG_HOLE[1] - 14))
    d.rounded_rectangle([lx0, ly0, lx1, ly1], radius=5, fill=PAL["bark3"], outline=PAL["bark1"])
    d.ellipse([to_px((L.LOG_HOLE[0] - 13, 0))[0], to_px((0, L.LOG_HOLE[1] + 11))[1], to_px((L.LOG_HOLE[0] + 13, 0))[0], to_px((0, L.LOG_HOLE[1] - 11))[1]], fill=PAL["void"], outline=PAL["bark2"])
    # the Treant: a face in the trunk at the back of the clearing
    tx0, ty0 = to_px((L.CX - L.TRUNK_HALF - 6, L.TREANT_BACK_Y + 30)); tx1, ty1 = to_px((L.CX + L.TRUNK_HALF + 6, L.TRUNK_Y))
    d.rectangle([tx0, ty0, tx1, ty1], fill=PAL["bark2"])
    for k in range(5):
        x = tx0 + 4 + k * 8
        d.line([(x, ty0), (x + rng.choice([-1, 0, 1]), ty1)], fill=PAL["bark1"])
    ex, ey = to_px((L.CX - 14, L.TRUNK_Y + 12)); d.rectangle([ex, ey, ex + 2, ey + 1], fill=PAL["wisp"])
    ex, ey = to_px((L.CX + 10, L.TRUNK_Y + 12)); d.rectangle([ex, ey, ex + 2, ey + 1], fill=PAL["wisp"])
    for x in L.BARK_XS:  # bark plates
        a = to_px((x - L.BARK_W / 2, L.BARK_Y + L.BARK_DEPTH)); b = to_px((x + L.BARK_W / 2, L.BARK_Y))
        d.rectangle([a, b], fill=PAL["bark3"], outline=PAL["bark1"])
    # walls: stone edging
    def wall_line(pts, c1="stone1", c2="stone2"):
        q = [to_px(p) for p in pts]
        d.line(q, fill=PAL[c1], width=4); d.line(q, fill=PAL[c2], width=2)
    P = L.floor_parts(mode_parts=False)
    for nm, part in P.items():
        if part[0] == "poly" and nm not in ("island", "trunk") and not nm.startswith("bark"):
            wall_line(part[1])
        elif part[0] == "circle":
            c = to_px(part[1]); r = max(2, part[2] / S)
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=PAL["stone2"], outline=PAL["stone1"])
    d.line(isl, fill=PAL["bark2"], width=2)
    # the old well: stone ring
    c = to_px(L.WELL_HOLE)
    d.ellipse([c[0] - 11, c[1] - 11, c[0] + 11, c[1] + 11], fill=PAL["stone2"], outline=PAL["stone3"])
    d.ellipse([c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7], fill=PAL["void"])
    # slings as dark-wood plastics with a stone rim
    for f in (lambda p: p, L.M):
        d.polygon([to_px(f(L.SLING_TOP_L)), to_px(f(L.SLING_CORNER_L)), to_px(f(L.SLING_TIP_L))], fill=PAL["bark2"], outline=PAL["teal"])
    # ramp (plastic drawn as a pale wooden boardwalk) + wire
    rp = L.ramp_path(); lr, rr = rp.rails(L.RAMP_CHANNEL_HALF)
    pl = [i for i, s in enumerate(rp.dist) if L.RAMP_U_LEN <= s <= L.RAMP_APEX_S + 120]
    d.polygon([to_px(lr[i]) for i in pl] + [to_px(rr[i]) for i in reversed(pl)], fill=PAL["bark3"], outline=PAL["bark1"])
    for i in pl[::5]:
        d.line([to_px(lr[i]), to_px(rr[i])], fill=PAL["bark2"])
    wi = [i for i, s in enumerate(rp.dist) if s >= L.RAMP_APEX_S + 110]
    for side in (lr, rr):
        d.line([to_px(side[i]) for i in wi], fill=PAL["stone3"], width=1)
    # graves in the orbit lane (the Graveyard)
    for y in (840, 960, 1060):
        c = to_px((46, y)); d.rectangle([c[0] - 5, c[1] - 6, c[0] + 5, c[1] + 4], fill=PAL["stone2"], outline=PAL["stone1"])
        d.point((c[0], c[1] - 2), fill=PAL["stone3"])
    # floor fog: horizontal dithered bands (cool), denser low on the table
    a = np.asarray(img).astype(np.float32)
    yy, xx = np.mgrid[0:AH, 0:AW]
    fog = np.zeros((AH, AW))
    for band_y, amp, thick in ((AH * 0.80, 0.55, 26), (AH * 0.62, 0.35, 18), (AH * 0.45, 0.22, 14)):
        fog += amp * np.exp(-((yy - band_y - 6 * np.sin(xx * 0.05 + band_y)) / thick) ** 2)
    fog *= 0.75 + 0.25 * np.sin(xx * 0.09 + yy * 0.02)
    mask = fog > (BAYER[yy % 4, xx % 4] * 0.9 + 0.15)
    a[mask] = a[mask] * 0.45 + np.array(PAL["fog1"]) * 0.55
    mask2 = fog > (BAYER[yy % 4, xx % 4] * 0.9 + 0.45)
    a[mask2] = a[mask2] * 0.4 + np.array(PAL["fog2"]) * 0.6
    img = Image.fromarray(a.astype(np.uint8))
    # lantern light: the only warm colour (east lantern, the well's lantern, the witch's lanterns in the glade)
    glow = np.zeros((AH, AW))
    lamps = [L.LANTERN_E_C, (L.WELL_POST_HI[0] + 4, L.WELL_POST_HI[1] + 18), (L.CX, L.TREANT_BACK_Y + 40), L.FOREST_GATE]
    for p in lamps:
        c = to_px(p)
        glow = np.maximum(glow, np.exp(-((xx - c[0]) ** 2 + (yy - c[1]) ** 2) / (2 * 8 ** 2)))
    a = np.asarray(img).astype(np.float32)
    for lvl, col, mix in ((0.12, "lamp1", 0.45), (0.45, "lamp2", 0.6), (0.85, "lamp3", 0.7)):
        m = glow > lvl + (BAYER[yy % 4, xx % 4] - 0.5) * 0.3
        a[m] = a[m] * (1 - mix) + np.array(PAL[col]) * mix
    img = Image.fromarray(a.astype(np.uint8))
    d = ImageDraw.Draw(img)
    for p in lamps:
        c = to_px(p)
        d.rectangle([c[0] - 2, c[1] - 3, c[0] + 2, c[1] + 3], fill=PAL["lamp3"], outline=PAL["bark1"])
        d.point((c[0], c[1]), fill=PAL["lamp4"])
    # wisps
    for (cx, cy), _, _ in L.WISPS:
        c = to_px((cx, cy))
        d.ellipse([c[0] - 5, c[1] - 5, c[0] + 5, c[1] + 5], fill=PAL["wisp"])
        d.ellipse([c[0] - 2, c[1] - 3, c[0] + 2, c[1] + 1], fill=PAL["wisp2"])
        for k in range(3):
            d.point((c[0] - 4 + k * 4, c[1] + 6 + k % 2), fill=PAL["teal"])
    # a ghost at the left haunt (dithered = half visible) and the drifting ghost low on the table
    for (gx, gy), solid in ((L.GHOST_HAUNTS[0], False), ((150, 610), True)):
        c = to_px((gx, gy))
        for y in range(-9, 10):
            for x in range(-7, 8):
                inside = (x * x) / 49 + ((y + 2) ** 2) / 64 < 1 or (y > 2 and abs(x) < 7)
                if inside and (solid or (x + y) % 2 == 0):
                    img.putpixel((int(c[0] + x), int(c[1] + y)), PAL["ghost"])
        d.point((c[0] - 2, c[1] - 3), fill=PAL["void"]); d.point((c[0] + 2, c[1] - 3), fill=PAL["void"])
    # flippers: pale bone with a dark rubber
    for piv, side in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, pp = L.flipper_poly(piv, side)
        d.polygon([to_px(p) for p in pp], fill=PAL["fog3"], outline=PAL["night3"])
    # the ball: steel, with a warm lantern glint
    c = to_px((330, 520))
    d.ellipse([c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7], fill=PAL["stone2"], outline=PAL["stone1"])
    d.ellipse([c[0] - 4, c[1] - 5, c[0] - 1, c[1] - 2], fill=PAL["fog3"]); d.point((c[0] + 3, c[1] + 3), fill=PAL["lamp3"])
    img = quantize(img)
    return img

def draw_tables(ax):
    ax.set_facecolor(BG); ax.axis("off")
    lines = ["NAMED PASSAGES (ball r 15: closed < 30 · passages ≥ 45)"]
    for name, g, v, *_ in C.named_passages():
        if "slot when one bark" in name:
            v = "slot, not a wedge (pymunk: 0/180 stuck)"
        lines.append(f"  {name[:46]:46s} {g:6.1f}  {v}")
    lines.append("")
    lines.append("SHOT FAN (deg, from the sweet spots)")
    for fl, d in C.shot_fan().items():
        lines.append(f"  {fl:5s}: " + " · ".join(f"{k.split(' (')[0]} {a:.0f}" for k, a in sorted(d.items(), key=lambda kv: kv[1])))
    lines.append("")
    lines.append("SHOT LINES (clearance, base table / every mode part up)")
    base = {(r[0], r[1]): r for r in C.shot_clearance()}
    mode = {(r[0], r[1]): r for r in C.shot_clearance(True)}
    for key, r in base.items():
        m = mode[key]
        tag = "" if m[2] > 0 else f"  ← {m[3].replace(' (mode)', '')} when up"
        lines.append(f"  {key[0]:5s} → {key[1][:16]:16s} {r[2]:6.1f} / {m[2]:6.1f}{tag}")
    lines.append("")
    lines.append("WISPS (swept loop to the nearest wall / each other)")
    for name, g, nm, v in C.wisp_clearance():
        lines.append(f"  {name:18s} {g:6.1f}  {v}")
    lines.append("")
    lines.append("PYMUNK (CHOMP!'s gravity, no flippers)")
    for s in SIMTXT:
        lines.append("  " + s)
    ax.text(0.0, 1.0, "\n".join(lines), color=TXT, family="monospace", fontsize=5.6, va="top", ha="left", transform=ax.transAxes)

SIMTXT = [
    "Old Well from the right flipper, 116–136° × 1,600/2,000/2,400:",
    "  in at 122–126° (8/33) · low misses 128–130° → left outlane (4/33)",
    "  · the rest back into play",
    "Bark: one drop down × 3 × 60 balls: 0 stuck",
    "Graveyard lane fall-backs (60): 0 drains; they roll off the",
    "  well roof and cross to the right flipper (x 326–426 at y 460)",
]

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "qf_forest_m1r1.png"
    fig = plt.figure(figsize=(17, 11.5), facecolor=BG)
    ax1 = fig.add_axes([0.0, 0.02, 0.34, 0.94])
    draw_layout(ax1)
    pix = draw_pixel()
    pix.resize((AW * 3, AH * 3), Image.NEAREST).save(out.replace(".png", "_pixel.png"))
    ax2 = fig.add_axes([0.335, 0.02, 0.34, 0.94])
    ax2.imshow(np.asarray(pix), extent=(0, L.W, 0, L.H), interpolation="nearest")
    ax2.set_xlim(-5, L.W + 5); ax2.set_ylim(-5, L.H + 5); ax2.set_aspect("equal"); ax2.axis("off")
    ax2.set_title("pixel-art mood test (2 pt per art pixel, 24-colour palette)", color=TXT, fontsize=10)
    ax3 = fig.add_axes([0.685, 0.02, 0.31, 0.94])
    draw_tables(ax3)
    ax3.set_title("checks", color=TXT, fontsize=10)
    fig.savefig(out, dpi=130, facecolor=BG)
    print("saved", out)
