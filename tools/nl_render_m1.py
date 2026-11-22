"""Neon Labyrinth M1 round 1: render the Switchyard cell — (1) layout with gap checks and shot lines, (2) the neon look,
(3) how cells link + the check table. Usage: python3 nl_render_m1.py out.png"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import nl_layout as L
import nl_checks as C

S, SS = 1.25, 2
K = S * SS
PW, PH = int(L.CELL_W * K), int(L.CELL_H * K)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONOB = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

def f(sz, path=FONT):
    return ImageFont.truetype(path, int(sz * K))

def P(p):
    return (p[0] * K, (L.CELL_H - p[1]) * K)

P_ALL = L.floor_parts()

# ======================================================================== panel 1: layout + checks
def panel_layout():
    img = Image.new("RGB", (PW, PH), (12, 14, 20))
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, L.CELL_W + 1, 50):
        d.line([P((x, 0)), P((x, L.CELL_H))], fill=(40, 50, 70, 255) if x % 100 else (55, 70, 95, 255), width=1)
    for y in range(0, L.CELL_H + 1, 50):
        d.line([P((0, y)), P((L.CELL_W, y))], fill=(40, 50, 70, 255) if y % 100 else (55, 70, 95, 255), width=1)
    # bands: the open lower table and the shot line (45-56% from the flipper tips to the top)
    tip_y = L.TIP_L_REST[1]
    s0, s1 = tip_y + 0.45 * (L.TOP_Y - tip_y), tip_y + 0.56 * (L.TOP_Y - tip_y)
    d.rectangle([P((L.WALL_L, s1)), P((L.WALL_R, s0))], fill=(220, 180, 60, 26))
    d.rectangle([P((L.SLING_X + 10, s0)), P((L.CELL_W - L.SLING_X - 10, L.SLING_TOP_L[1]))], fill=(60, 200, 120, 18))
    d.text(P((L.CX, (L.SLING_TOP_L[1] + s0) / 2 + 30)), "open lower table — lamps only", font=f(8), fill=(110, 190, 140), anchor="mm")
    d.text(P((L.WALL_R - 8, s1 - 4)), f"shot line {s0:.0f}–{s1:.0f}", font=f(7), fill=(220, 190, 90), anchor="ra")

    GREEN, ORANGE, POST, TGT = (70, 205, 120), (240, 140, 40), (160, 160, 170), (250, 230, 130)
    def poly(pts, col, w=2.2, closed=False):
        pts = [P(p) for p in pts] + ([P(pts[0])] if closed else [])
        d.line(pts, fill=col, width=max(1, int(w * K)), joint="curve")
    def circ(c, r, outline, fill=None, w=1.6):
        x, y = P(c)
        d.ellipse([x - r * K, y - r * K, x + r * K, y + r * K], outline=outline, fill=fill, width=max(1, int(w * K)))
    def dashed(a, b, col, w=1.4, on=6, off=4):
        L_ = math.dist(a, b)
        if L_ == 0:
            return
        ux, uy = (b[0] - a[0]) / L_, (b[1] - a[1]) / L_
        s = 0
        while s < L_:
            e = min(s + on, L_)
            d.line([P((a[0] + ux * s, a[1] + uy * s)), P((a[0] + ux * e, a[1] + uy * e))], fill=col, width=max(1, int(w * K)))
            s += on + off
    def label(xy, s, sz=7, col=(220, 225, 235), anchor="mm"):
        d.text(P(xy), s, font=f(sz), fill=col, anchor=anchor)

    # return wires (rail layer): drop-ins from the top port + side entries -> inlane
    VI = (180, 140, 245)
    for sd in ("L", "R"):
        for pts in (L.return_wire(sd), L.entry_stub(sd)):
            for sgn in (-1, 1):
                off = []
                for i, p in enumerate(pts):
                    a = pts[max(0, i - 1)]; b = pts[min(len(pts) - 1, i + 1)]
                    u = C_unit(a, b)
                    off.append((p[0] - u[1] * 19 * sgn, p[1] + u[0] * 19 * sgn))
                poly(off, VI, 1.1)
    label((L.WIRE_X + 26, 900), "return wire", 6, VI, "lm")
    label((2 * L.CX - L.WIRE_X - 26, 900), "return wire", 6, VI, "rm")
    # the rise through the drain (from the cell below): scripted up to the release, then the pop onto a flipper
    import nl_sim as SIM
    for sd, col in (("L", (120, 220, 255)), ("R", (120, 220, 255))):
        dashed((L.CX, 40), L.UP_RELEASE, col, 1.4, 3, 3)
        sp = SIM.build(); b, sh = SIM.ball(sp, L.UP_RELEASE, L.UP_POP[sd]); prev = L.UP_RELEASE
        for i in range(240 * 2):
            sp.step(1 / 240)
            if i % 6 == 0:
                cur = (b.position.x, b.position.y); dashed(prev, cur, col, 1.4, 3, 3); prev = cur
            if any(getattr(q.shape, "part", "").startswith("flipper") for q in sp.shape_query(sh)):
                break
    label((L.CX, 430), "rise from below:", 6, (120, 220, 255))
    label((L.CX, 421), "pop onto a flipper", 6, (120, 220, 255))
    # ramp plastic (high part) + light-rails (rail layer)
    left, right = L.ramp_outline()
    d.polygon([P(p) for p in left] + [P(p) for p in reversed(right)], fill=(70, 205, 120, 45))
    for key, col in (("W", (200, 205, 215)), ("N", (200, 205, 215)), ("E", (200, 205, 215))):
        pts = L.rail_path(key)
        for sgn in (-1, 1):
            off = []
            for i, p in enumerate(pts):
                a = pts[max(0, i - 1)]; b = pts[min(len(pts) - 1, i + 1)]
                u = C_unit(a, b)
                off.append((p[0] - u[1] * L.RAIL_HALF * sgn, p[1] + u[0] * L.RAIL_HALF * sgn))
            poly(off, col, 1.2)
    circ(L.HUB, L.RAIL_RING_R[1], (200, 205, 215), None, 1.2)
    circ(L.HUB, L.RAIL_RING_R[0], (200, 205, 215), None, 1.0)
    circ(L.HUB, L.HUB_TRACK_R, (200, 205, 215), (40, 46, 60, 255), 1.6)
    # turntable track (pointing W in this sketch)
    hx, hy = L.HUB
    d.line([P((hx, hy - L.HUB_TRACK_R)), P((hx, hy)), P((hx - L.HUB_TRACK_R, hy))], fill=(200, 205, 215), width=int(3 * K))
    label((hx + 4, hy + 4), "turntable", 6, (230, 230, 240))
    label((hx, hy + L.RAIL_RING_R[1] + 10), "light-rail ring", 6, (200, 205, 215))
    label((150, 806), "W light-rail", 6, (200, 205, 215))
    label((L.CX + 40, 900), "N rail", 6, (200, 205, 215), "lm")
    label((450, 806), "E light-rail", 6, (200, 205, 215))

    # floor walls
    for nm, part in P_ALL.items():
        if part[0] == "poly":
            if nm.startswith("sling "):
                pts = part[1]
                poly(pts[:3], GREEN, 2.0)
                poly([pts[2], pts[0]], ORANGE, 2.8)
            elif nm.startswith("switch block") or nm == "RAILS block":
                poly(part[1], GREEN, 2.0, closed=nm == "RAILS block")
            else:
                poly(part[1], GREEN, 2.4)
        else:
            if nm.startswith("flipper pivot"):
                continue
            fill = None if nm == "hub base" else (235, 235, 240, 230)
            circ(part[1], part[2], GREEN if nm == "hub base" else POST, fill, 1.4)
    label((L.CX, L.HUB[1] - 20), "hub base", 6, (140, 220, 160))
    label((L.CX, L.RAMP_MOUTH_Y + 46), "RAMP", 8, (140, 230, 170))
    # target faces
    for nm, tgt in (("<", L.SWITCH_L), (">", L.SWITCH_R), ("RAILS", L.RAILS)):
        fa, fb, ba, bb, n = tgt
        d.line([P(fa), P(fb)], fill=TGT, width=int(4.5 * K))
        c = ((fa[0] + fb[0]) / 2 - n[0] * 22, (fa[1] + fb[1]) / 2 - n[1] * 22)
        label(c, "SWITCH " + nm if nm != "RAILS" else "RAILS", 6.5, TGT)
    # derail: a misaligned route drops the ball to the floor beside the turntable
    for dx in (-1, 1):
        label((L.CX + dx * 80, L.HUB[1] - 52), "derail →", 5.5, (255, 160, 90)) if dx < 0 else label((L.CX + dx * 80, L.HUB[1] - 52), "← derail", 5.5, (255, 160, 90))
    def portal(a, b, col, txt, tpos, anchor="mm"):
        d.line([P(a), P(b)], fill=col, width=int(5 * K))
        label(tpos, txt, 6, col, anchor)
    portal((L.WALL_L, L.SIDE_EXIT[0]), (L.WALL_L, L.SIDE_EXIT[1]), (240, 80, 200), "EXIT W", (L.WALL_L + 6, L.SIDE_EXIT[1] + 8), "lm")
    portal((L.WALL_R, L.SIDE_EXIT[0]), (L.WALL_R, L.SIDE_EXIT[1]), (240, 80, 200), "EXIT E", (L.WALL_R - 6, L.SIDE_EXIT[1] + 8), "rm")
    portal((L.TOP_PORT[0], L.TOP_Y + 2), (L.TOP_PORT[1], L.TOP_Y + 2), (240, 80, 200), "TOP PORT (exit N / drop-ins)", (L.CX, L.TOP_Y + 12))
    portal((L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2), L.ENTRY_PORTAL[0]), (L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2), L.ENTRY_PORTAL[1]), (80, 200, 255), "entry", (L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2) + 6, L.ENTRY_PORTAL[1] + 26), "lm")
    portal((2 * L.CX - L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2), L.ENTRY_PORTAL[0]), (2 * L.CX - L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2), L.ENTRY_PORTAL[1]), (80, 200, 255), "entry", (2 * L.CX - L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2) - 6, L.ENTRY_PORTAL[1] + 26), "rm")
    for sd in ("L", "R"):
        g = (lambda p: p) if sd == "L" else L.M
        label(g((47, 390)), "out", 6, (150, 220, 170)); label(g((47, 381)), "lane", 6, (150, 220, 170))
        label(g((L.INLANE_X, 390)), "in", 6, (150, 220, 170)); label(g((L.INLANE_X, 381)), "lane", 6, (150, 220, 170))
    label((L.CX, 70), "DRAIN → cell below", 7, (240, 150, 80))
    # flippers
    for pv, sd in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, pl = L.flipper_poly(pv, sd, L.FLIP_TRAVEL)
        poly(pl + [pl[0]], (150, 150, 160, 160), 1.0)
        tip, pl = L.flipper_poly(pv, sd)
        d.polygon([P(p) for p in pl], fill=(200, 200, 210))
        circ(pv, L.FLIP_RP, (200, 200, 210), (200, 200, 210))
        circ(tip, L.FLIP_RT, (200, 200, 210), (200, 200, 210))
    label((L.CX, 130), "flippers 80 · ball r 15 (real scale)", 6, (190, 190, 200))
    # shot lines
    fan = C.shot_fan()
    shots = {"SWITCH <": L.SWITCH_L_C, "ramp": (L.CX, L.RAMP_MOUTH_Y + 8), "SWITCH >": L.SWITCH_R_C, "RAILS": L.RAILS_C}
    for fl, sp, col in (("left", L.SWEET_L, (120, 200, 255, 170)), ("right", L.SWEET_R, (255, 170, 120, 170))):
        for k, t in shots.items():
            dashed(sp, t, col, 1.0, 5, 5)
    # angles at the bottom near each flipper
    for fl, base, anchor in (("left", (24, 300), "la"), ("right", (576, 300), "ra")):
        ys = 0
        for k, a in sorted(fan[fl].items(), key=lambda kv: kv[1]):
            d.text(P((base[0], base[1] - ys)), f"{k} {a:.0f}°", font=f(6), fill=(120, 200, 255) if fl == "left" else (255, 180, 130), anchor=anchor)
            ys += 9
    # gap callouts
    vcol = {"OK": (120, 240, 140), "open": (120, 240, 140), "closed": (180, 180, 190), "joined": (180, 180, 190),
            "WEDGE RISK": (255, 70, 70), "TOO NARROW": (255, 70, 70)}
    shown = set()
    for name, g, v, p, q in C.named_passages():
        if p is None or "raised flipper" in name or "resting flipper" in name:
            continue
        key = (round(p[0]), round(p[1]))
        if key in shown:
            continue
        shown.add(key)
        col = vcol.get(v, (255, 255, 255))
        d.line([P(p), P(q)], fill=col, width=int(1.6 * K))
        for e in (p, q):
            circ(e, 1.6, col, col, 1)
        m = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        d.text(P((m[0] + 3, m[1] + 3)), f"{g:.0f}", font=f(6.5, FONTB), fill=col, anchor="lb")
    d.text((10 * K, 8 * K), "1 · LAYOUT + GAP CHECKS (round 2)", font=f(10, FONTB), fill=(235, 235, 245))
    return img

def C_unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(dx, dy) or 1
    return (dx / l, dy / l)

# ======================================================================== panel 2: the neon look
CYAN, ORANGE, MAGENTA, WHITE = (0.10, 0.85, 1.0), (1.0, 0.45, 0.08), (1.0, 0.18, 0.80), (1.0, 1.0, 1.0)

class Neon:
    def __init__(self):
        self.core = Image.new("RGB", (PW, PH), (0, 0, 0))
        self.glow = Image.new("RGB", (PW, PH), (0, 0, 0))
        self.dc = ImageDraw.Draw(self.core)
        self.dg = ImageDraw.Draw(self.glow)
    def col(self, c, a=1.0):
        return tuple(int(255 * min(1, v * a)) for v in c)
    def line(self, pts, c, w=1.6, a=1.0, glow=1.0, closed=False):
        pts = [P(p) for p in pts] + ([P(pts[0])] if closed else [])
        self.dc.line(pts, fill=self.col(c, a), width=max(1, int(w * K)), joint="curve")
        self.dg.line(pts, fill=self.col(c, a * glow), width=max(1, int(w * 3.2 * K)), joint="curve")
    def circle(self, cxy, r, c, w=1.6, a=1.0, fill=None, glow=1.0):
        x, y = P(cxy)
        box = [x - r * K, y - r * K, x + r * K, y + r * K]
        self.dc.ellipse(box, outline=self.col(c, a), fill=self.col(fill) if fill else None, width=max(1, int(w * K)))
        self.dg.ellipse(box, outline=self.col(c, a * glow), width=max(1, int(w * 3.2 * K)))
    def poly_fill(self, pts, c, a):
        self.dc.polygon([P(p) for p in pts], fill=self.col(c, a))
    def text(self, xy, s, sz, c, a=1.0, anchor="mm", font=MONOB, glow=0.8):
        self.dc.text(P(xy), s, font=f(sz, font), fill=self.col(c, a), anchor=anchor)
        self.dg.text(P(xy), s, font=f(sz, font), fill=self.col(c, a * glow), anchor=anchor, stroke_width=int(1.2 * K), stroke_fill=self.col(c, a * glow))
    def compose(self, floor):
        g = np.asarray(self.glow, dtype=np.float32)
        out = np.asarray(floor, dtype=np.float32).copy()
        gi = Image.fromarray(g.astype(np.uint8))
        for rad, amt in ((3 * K, 0.9), (9 * K, 0.7), (22 * K, 0.45)):
            out += np.asarray(gi.filter(ImageFilter.GaussianBlur(rad)), dtype=np.float32) * amt
        out += np.asarray(self.core, dtype=np.float32)
        return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

def panel_neon():
    # the grid floor: dark, faint cyan lines, slightly brighter every 100, fading toward the top
    floor = Image.new("RGB", (PW, PH), (2, 3, 6))
    fd = ImageDraw.Draw(floor, "RGBA")
    for x in range(0, L.CELL_W + 1, 25):
        a = 70 if x % 100 == 0 else 26
        fd.line([P((x, 0)), P((x, L.CELL_H))], fill=(20, 140, 190, a), width=1)
    for y in range(0, L.CELL_H + 1, 25):
        a = 70 if y % 100 == 0 else 26
        fd.line([P((0, y)), P((L.CELL_W, y))], fill=(20, 140, 190, a), width=1)
    n = Neon()
    # outside the walls: void (mask the grid outside the outer wall)
    ow = L.outer_wall()
    mask = Image.new("L", (PW, PH), 0)
    md = ImageDraw.Draw(mask)
    md.polygon([P(p) for p in ow + [(L.M(L.APRON_END)[0], 0), (L.APRON_END[0], 0)]], fill=255)
    floor = Image.composite(floor, Image.new("RGB", (PW, PH), (0, 0, 0)), mask.filter(ImageFilter.GaussianBlur(2)))
    # return wires: dim cyan habitrails (they light when a ball rides)
    for sd in ("L", "R"):
        for pts in (L.return_wire(sd), L.entry_stub(sd)):
            for sgn in (-1, 1):
                off = []
                for i, p in enumerate(pts):
                    a = pts[max(0, i - 1)]; b = pts[min(len(pts) - 1, i + 1)]
                    u = C_unit(a, b)
                    off.append((p[0] - u[1] * 17 * sgn, p[1] + u[0] * 17 * sgn))
                n.line(off, CYAN, 0.9, a=0.45, glow=0.35)
    # lamp inserts in the open band: the route display (W lit = the route set below)
    cy = 505
    for dx, glyph, on in ((-46, "◄", True), (0, "▲", False), (46, "►", False)):
        c = MAGENTA if on else CYAN
        n.circle((L.CX + dx, cy), 15, c, 1.2, a=1.0 if on else 0.35, glow=1.0 if on else 0.3)
        n.text((L.CX + dx, cy - 1), glyph, 10, c, a=1.0 if on else 0.4, font=FONTB)
    n.text((L.CX, cy - 30), "ROUTE  W", 6.5, MAGENTA, a=0.9, font=MONO)
    # walls
    n.line(ow, CYAN, 2.0)
    for s in ("L", "R"):
        for nm in (f"lane guide {s}", f"outlane wall {s}", f"outlane post rail {s}", f"top lane wall {s}", f"switch block {s}"):
            n.line(P_ALL[nm][1], CYAN, 1.8, a=0.9)
        g = (lambda p: p) if s == "L" else L.M
        n.line([g(L.SLOPE_TOP), g(L.APRON_END), g((L.CHUTE_X, L.CHUTE_BOTTOM))], ORANGE, 2.0)
        for pn in (f"lane guide post {s}", f"outlane post {s}"):
            n.circle(P_ALL[pn][1], P_ALL[pn][2], CYAN, 1.4)
        sl = P_ALL[f"sling {s}"][1]
        n.line(sl[:3], CYAN, 1.8)
        n.line([sl[2], sl[0]], WHITE, 2.4, glow=0.9)
        for pn in (f"sling top post {s}", f"sling tip post {s}", f"ramp mouth post {s}", f"top lane post {s}"):
            c, r = P_ALL[pn][1], P_ALL[pn][2]
            n.circle(c, r, CYAN, 1.4)
    n.line(P_ALL["RAILS block"][1], CYAN, 1.8, closed=True)
    n.line(P_ALL["ramp U (floor-solid)"][1], CYAN, 1.8)
    # the ramp: translucent cyan plastic with bright rails
    left, right = L.ramp_outline()
    n.poly_fill(left + list(reversed(right)), CYAN, 0.10)
    n.line(left, CYAN, 1.6); n.line(right, CYAN, 1.6)
    for i in range(1, 9):
        y = L.RAMP_U_TOP + (L.RAMP_TOP_Y - L.RAMP_U_TOP) * i / 9
        h = L.ramp_half_at(y)
        n.line([(L.CX - h + 4, y), (L.CX + h - 4, y)], CYAN, 0.8, a=0.25, glow=0.2)
    # light-rails: W aligned (magenta), N and E idle (dim cyan)
    for key in ("W", "N", "E"):
        pts = L.rail_path(key)
        on = key == "W"
        for sgn in (-1, 1):
            off = []
            for i, p in enumerate(pts):
                a = pts[max(0, i - 1)]; b = pts[min(len(pts) - 1, i + 1)]
                u = C_unit(a, b)
                off.append((p[0] - u[1] * L.RAIL_HALF * sgn, p[1] + u[0] * L.RAIL_HALF * sgn))
            n.line(off, MAGENTA if on else CYAN, 1.5 if on else 1.0, a=1.0 if on else 0.4, glow=1.0 if on else 0.35)
    # rail ring with its bridge (pointing W) + turntable (pointing W)
    hx, hy = L.HUB
    n.circle(L.HUB, L.RAIL_RING_R[1], CYAN, 1.0, a=0.5, glow=0.4)
    n.circle(L.HUB, L.RAIL_RING_R[0], CYAN, 1.0, a=0.5, glow=0.4)
    r0, r1 = L.RAIL_RING_R
    for sgn in (-1, 1):
        n.line([(hx - r0, hy + sgn * L.RAIL_HALF), (hx - r1, hy + sgn * L.RAIL_HALF)], MAGENTA, 2.0)
    n.circle(L.HUB, L.HUB_TRACK_R, CYAN, 2.0, fill=(0.0, 0.03, 0.05))
    n.circle(L.HUB, L.HUB_BASE_R - 8, CYAN, 0.8, a=0.4, glow=0.3)
    # turntable track: a curve from S to W, white = active
    arc = [(hx + L.HUB_TRACK_R * math.cos(t) - L.HUB_TRACK_R, hy - L.HUB_TRACK_R + L.HUB_TRACK_R * math.sin(t)) for t in np.linspace(0, math.pi / 2, 12)]
    arc = [(hx - L.HUB_TRACK_R + L.HUB_TRACK_R * math.cos(t), hy - L.HUB_TRACK_R + L.HUB_TRACK_R * math.sin(t)) for t in np.linspace(0, math.pi / 2, 14)]
    n.line(arc, WHITE, 3.0)
    # targets
    for tgt, glyph in ((L.SWITCH_L, "◄"), (L.SWITCH_R, "►"), (L.RAILS, "⟲")):
        fa, fb, ba, bb, nn = tgt
        n.line([fa, fb], WHITE, 4.0, glow=1.2)
        c = ((fa[0] + fb[0]) / 2 - nn[0] * 16, (fa[1] + fb[1]) / 2 - nn[1] * 16)
        n.text(c, glyph, 9, WHITE, a=0.9, font=FONTB)
    # dock: cyan ring, dark core
    # portals: W open (magenta bloom), N and E locked (orange barriers); entries cyan chevrons
    def wall_portal(x, y0, y1, c, inward):
        n.line([(x, y0), (x, y1)], c, 4.0, glow=1.4)
        for k in range(3):
            yy = y0 + (y1 - y0) * (k + 1) / 4
            n.line([(x + inward * 4, yy - 6), (x + inward * 11, yy), (x + inward * 4, yy + 6)], c, 1.2, a=0.8)
    wall_portal(L.WALL_L, *L.SIDE_EXIT, MAGENTA, -1)
    wall_portal(L.WALL_R, *L.SIDE_EXIT, ORANGE, 1)
    n.line([(L.TOP_PORT[0], L.TOP_Y - 1), (L.TOP_PORT[1], L.TOP_Y - 1)], ORANGE, 4.0, glow=1.4)
    for x in (L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2), 2 * L.CX - L._bulge_x((L.ENTRY_PORTAL[0] + L.ENTRY_PORTAL[1]) / 2)):
        inward = 1 if x < L.CX else -1
        y0, y1 = L.ENTRY_PORTAL
        n.line([(x, y0), (x, y1)], CYAN, 3.0)
        for k in range(2):
            yy = y0 + (y1 - y0) * (k + 1) / 3
            n.line([(x + inward * 4, yy + 6), (x + inward * 11, yy), (x + inward * 4, yy - 6)], CYAN, 1.0, a=0.7)
    # flippers: white edges, cyan glow
    for pv, sd in ((L.PIVOT_L, "L"), (L.PIVOT_R, "R")):
        tip, pl = L.flipper_poly(pv, sd)
        n.poly_fill(pl, (0.0, 0.05, 0.08), 1.0)
        n.line(pl + [pl[0]], WHITE, 1.6, glow=0.0)
        n.line(pl + [pl[0]], CYAN, 0.1, glow=1.2)
        n.circle(pv, L.FLIP_RP, WHITE, 1.6, fill=(0, 0.05, 0.08), glow=0.7)
        n.circle(tip, L.FLIP_RT, WHITE, 1.4, fill=(0, 0.05, 0.08), glow=0.7)
    # the ball: a data packet on its way up the ramp, with a light trail
    trail = [(L.CX - 6 + 6 * i / 10, 400 + 25 * i) for i in range(11)]
    for i in range(len(trail) - 1):
        n.line([trail[i], trail[i + 1]], MAGENTA, 1.0 + i * 0.5, a=0.15 + 0.08 * i, glow=0.8)
    n.circle(trail[-1], L.BALL_R, WHITE, 2.0, fill=(0.85, 0.95, 1.0), glow=1.2)
    # terminal text on the apron
    n.text((L.CX, 42), "SECTOR 3-2 · SWITCHYARD", 6.5, CYAN, a=0.75, font=MONO, glow=0.5)
    img = n.compose(floor)
    d = ImageDraw.Draw(img)
    d.text((10 * K, 8 * K), "2 · NEON LOOK (route set W: turntable + rails aligned)", font=f(10, FONTB), fill=(235, 235, 245))
    return img

# ======================================================================== panel 3: how cells link + check table
def panel_info(h):
    w = int(560 * K)
    img = Image.new("RGB", (w, h), (14, 16, 22))
    d = ImageDraw.Draw(img, "RGBA")
    d.text((10 * K, 8 * K), "3 · HOW CELLS LINK", font=f(10, FONTB), fill=(235, 235, 245))
    # 2 x 2 mini cells
    cw, ch, gx, gy, ox, oy = 150, 265, 34, 40, 40, 40
    def cell_rect(c, r):  # c col, r row (0 = top)
        x0 = (ox + c * (cw + gx)) * K; y0 = (oy + r * (ch + gy)) * K + 20 * K
        return x0, y0, x0 + cw * K, y0 + ch * K
    def cp(c, r, u, v):   # u, v in 0..1 cell space (v up)
        x0, y0, x1, y1 = cell_rect(c, r)
        return (x0 + (x1 - x0) * u, y1 - (y1 - y0) * v)
    names = {(0, 0): "SECTOR 3-1", (1, 0): "SECTOR 3-2", (0, 1): "SECTOR 2-1", (1, 1): "SECTOR 2-2"}
    for (c, r), nm in names.items():
        x0, y0, x1, y1 = cell_rect(c, r)
        d.rounded_rectangle([x0, y0, x1, y1], radius=8 * K, outline=(30, 200, 255), width=int(1.6 * K))
        d.text(((x0 + x1) / 2, y1 - 10 * K), nm, font=f(7, MONO), fill=(80, 200, 240), anchor="mm")
        # mini parts: dock, flippers, entry tubes, portals
        for u in (0.36, 0.64):
            a = cp(c, r, u - 0.12 if u < 0.5 else u + 0.12, 0.2); b = cp(c, r, u, 0.16)
            d.line([a, b], fill=(220, 220, 230), width=int(2.5 * K))
        for u0, u1 in ((0.5, 0.1), (0.5, 0.9)):   # return wires (top lane round to each inlane)
            pts = [cp(c, r, u0 + (u1 - u0) * t, 0.95 - 0.02 * t) for t in (0, 0.5, 1)] + [cp(c, r, u1, 0.6), cp(c, r, 0.2 if u1 < 0.5 else 0.8, 0.4)]
            d.line(pts, fill=(150, 120, 210), width=int(1.2 * K))
        for u in (0.035, 0.965):
            d.line([cp(c, r, u, 0.56), cp(c, r, u, 0.61)], fill=(80, 200, 255), width=int(3 * K))
            d.line([cp(c, r, u, 0.75), cp(c, r, u, 0.82)], fill=(240, 80, 200), width=int(3 * K))
        d.line([cp(c, r, 0.45, 0.985), cp(c, r, 0.55, 0.985)], fill=(240, 80, 200), width=int(3 * K))
        d.line([cp(c, r, 0.44, 0.03), cp(c, r, 0.56, 0.03)], fill=(240, 150, 80), width=int(3 * K))
    def arrow(a, b, col, txt=None, tpos=None, anchor="mm"):
        d.line([a, b], fill=col, width=int(2 * K))
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        for s in (-1, 1):
            d.line([b, (b[0] - 9 * K * math.cos(ang + s * 0.45), b[1] - 9 * K * math.sin(ang + s * 0.45))], fill=col, width=int(2 * K))
        if txt:
            d.multiline_text(tpos, txt, font=f(6.2), fill=col, anchor=anchor, align="center", spacing=2)
    MAG, CY, OR, VI = (240, 90, 210), (80, 200, 255), (245, 160, 80), (190, 150, 250)
    def tag(xy, t, col):
        d.ellipse([xy[0] - 8 * K, xy[1] - 8 * K, xy[0] + 8 * K, xy[1] + 8 * K], fill=(14, 16, 22), outline=col, width=int(1.4 * K))
        d.text(xy, t, font=f(7, FONTB), fill=col, anchor="mm")
    a, b = cp(0, 1, 0.99, 0.785), cp(1, 1, 0.01, 0.585); arrow(a, b, MAG); tag(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - 14 * K), "1", MAG)
    a, b = cp(1, 1, 0.5, 1.0), cp(1, 0, 0.5, 0.3); arrow(a, b, MAG); tag((a[0] + 14 * K, a[1] - 18 * K), "2", MAG)
    arrow(b, cp(1, 0, 0.38, 0.2), MAG)
    a, b = cp(0, 0, 0.5, 0.0), cp(0, 1, 0.5, 0.95); arrow(a, b, OR); tag((a[0] - 14 * K, a[1] + 18 * K), "3", OR)
    y = cell_rect(0, 1)[3] + 22 * K
    lines = [
        ("1  side exit → the neighbour's entry portal → its return wire → inlane", (240, 90, 210), FONT),
        ("2  top exit → rises up through the upper cell's drain, pops onto a flipper", (240, 90, 210), FONT),
        ("3  drain → falls through the lower cell's top port onto a return wire", (245, 160, 80), FONT),
        ("   (sides alternate) → inlane", (245, 160, 80), FONT),
        ("So every arrival ends on a flipper. Only a bottom-row drain loses a ball.", (235, 235, 245), FONTB),
    ]
    for s, col, fnt in lines:
        d.text((24 * K, y), s, font=f(7, fnt), fill=col); y += 11 * K
    # check table
    y += 8 * K
    d.text((24 * K, y), "GAP CHECKS (ball 30: closed < 30 · passages ≥ 45)", font=f(7.5, FONTB), fill=(235, 235, 245)); y += 12 * K
    vcol = {"OK": (120, 240, 140), "open": (120, 240, 140), "closed": (180, 180, 190), "joined": (180, 180, 190),
            "WEDGE RISK": (255, 80, 80), "TOO NARROW": (255, 80, 80)}
    seen = set()
    for name, g, v, *_ in C.named_passages():
        nm = name.replace(" L:", ":").replace(" L ", " ").replace(" R:", ":").replace(" R ", " ")
        if nm in seen:
            continue
        seen.add(nm)
        d.text((24 * K, y), nm, font=f(6.5, MONO), fill=(200, 205, 215))
        d.text((410 * K, y), f"{g:6.1f}", font=f(6.5, MONO), fill=(200, 205, 215))
        d.text((460 * K, y), v, font=f(6.5, MONOB), fill=vcol.get(v, (255, 255, 255)))
        y += 9.5 * K
    wedges = [r for r in C.scan_pairs(45) if r[3] == "WEDGE RISK"]
    d.text((24 * K, y + 2 * K), f"all other part pairs: {len(wedges)} in the 30–45 band", font=f(6.5, MONOB),
           fill=(120, 240, 140) if not wedges else (255, 80, 80)); y += 14 * K
    d.text((24 * K, y), "SHOT LINES (straight path, ball r subtracted)", font=f(7.5, FONTB), fill=(235, 235, 245)); y += 12 * K
    for fl, k, c, nm in C.shot_clearance():
        a = C.shot_fan()[fl][k]
        d.text((24 * K, y), f"{fl:5s} → {k:9s} {a:5.1f}°  clears {nm} by {c:4.1f}", font=f(6.5, MONO),
               fill=(200, 205, 215) if c > 5 else (255, 200, 90)); y += 9.5 * K
    return img

if __name__ == "__main__":
    a = panel_layout()
    b = panel_neon()
    c = panel_info(PH)
    gap = int(12 * K)
    out = Image.new("RGB", (a.width + b.width + c.width + 2 * gap, PH), (6, 7, 10))
    out.paste(a, (0, 0)); out.paste(b, (a.width + gap, 0)); out.paste(c, (a.width + b.width + 2 * gap, 0))
    out = out.resize((out.width // SS, out.height // SS), Image.LANCZOS)
    out.save(sys.argv[1] if len(sys.argv) > 1 else "nl_switchyard_m1.png")
    b.resize((b.width // SS, b.height // SS), Image.LANCZOS).save("nl_switchyard_m1_neon.png")
    print(out.size)
