"""Neon Labyrinth T8 M3 round 1: a preview of the neon look on the Switchyard floor (no Swift yet).

The recipe is the one the Swift will use (no SKEffectNodes): every line is a thin bright CORE plus a wide soft HALO,
added onto black (additive blending). The static parts of a floor are baked once into one image; the moving and
changing parts (flippers, turntable, bridge, rails, lamps, portals, targets) are drawn the same way, live.

Colour language (Notion > Neon Labyrinth > Art and sound):
  cyan    = route / neutral (walls, lanes, rails, grid, entries)
  orange  = hazards and locked exits (locked portals, a route that would derail, the drain and outlane mouths)
  magenta = rewards and unlocked exits (an open portal, the lined-up route)
  white   = active (flippers, targets, sling faces, lit lamps)

Usage: python3 nl_render_neon.py out.png
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import nl_layout as L

K = 2.0                                   # pixels per world point in the working canvas
W, H = int(L.CELL_W * K), int(L.CELL_H * K)
CYAN = (0.0, 0.88, 1.0)
ORANGE = (1.0, 0.48, 0.08)
MAGENTA = (1.0, 0.18, 0.86)
WHITE = (1.0, 1.0, 1.0)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

# The recipe (world points): core width, halo width, halo blur radius, halo strength.
CORE_W, HALO_W, HALO_BLUR, HALO_GAIN = 2.0, 7.0, 6.0, 0.9


def P(p):
    return (p[0] * K, (L.CELL_H - p[1]) * K)


class Neon:
    """Two float layers: core (sharp) and halo (blurred), added at the end."""
    def __init__(self):
        self.core = Image.new("RGB", (W, H))
        self.halo = Image.new("RGB", (W, H))
        self.fill = Image.new("RGB", (W, H))
        self.dc, self.dh, self.df = (ImageDraw.Draw(i) for i in (self.core, self.halo, self.fill))

    @staticmethod
    def c(col, a):
        return tuple(int(255 * min(1, v * a)) for v in col)

    def line(self, pts, col, a=1.0, core=CORE_W, halo=HALO_W, glow=1.0):
        q = [P(p) for p in pts]
        self.dh.line(q, fill=self.c(col, a * glow), width=max(1, int(halo * K)), joint="curve")
        self.dc.line(q, fill=self.c(col, a), width=max(1, int(core * K)), joint="curve")

    def circle(self, cxy, r, col, a=1.0, core=CORE_W, halo=HALO_W, glow=1.0, fill=None):
        x, y = P(cxy)
        box = [x - r * K, y - r * K, x + r * K, y + r * K]
        if fill is not None:
            self.df.ellipse(box, fill=self.c(col, fill))
        self.dh.ellipse(box, outline=self.c(col, a * glow), width=max(1, int(halo * K)))
        self.dc.ellipse(box, outline=self.c(col, a), width=max(1, int(core * K)))

    def poly_fill(self, pts, col, a):
        self.df.polygon([P(p) for p in pts], fill=self.c(col, a))

    def text(self, xy, s, sz, col, a=0.8):
        fnt = ImageFont.truetype(FONT, int(sz * K))
        self.dc.text(P(xy), s, font=fnt, fill=self.c(col, a), anchor="mm")
        self.dh.text(P(xy), s, font=fnt, fill=self.c(col, a * 0.8), anchor="mm", stroke_width=int(2 * K),
                     stroke_fill=self.c(col, a * 0.5))

    def image(self):
        core = np.asarray(self.core, np.float32)
        halo = np.asarray(self.halo.filter(ImageFilter.GaussianBlur(HALO_BLUR * K)), np.float32)
        fill = np.asarray(self.fill, np.float32)
        out = fill + core + halo * HALO_GAIN * 1.6
        return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def grid(n):
    """The wireframe floor: faint cyan lines every 50, brighter every 200, inside the outer wall."""
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([P(p) for p in L.outer_wall()], fill=255)
    g = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(g)
    for x in range(0, L.CELL_W + 1, 50):
        major = x % 200 == 100
        d.line([P((x, 0)), P((x, L.CELL_H))], fill=Neon.c(CYAN, 0.30 if major else 0.13), width=int(1.2 * K) if major else 1)
    for y in range(0, L.CELL_H + 1, 50):
        major = y % 200 == 0
        d.line([P((0, y)), P((L.CELL_W, y))], fill=Neon.c(CYAN, 0.30 if major else 0.13), width=int(1.2 * K) if major else 1)
    n.fill.paste(g, (0, 0), mask)


def rails(n, centre, half, col, a, core=1.4):
    sides = [[], []]
    for i, p in enumerate(centre):
        a0, b0 = centre[max(0, i - 1)], centre[min(len(centre) - 1, i + 1)]
        ln = max(math.hypot(b0[0] - a0[0], b0[1] - a0[1]), 1e-3)
        nx, ny = -(b0[1] - a0[1]) / ln, (b0[0] - a0[0]) / ln
        sides[0].append((p[0] + nx * half, p[1] + ny * half))
        sides[1].append((p[0] - nx * half, p[1] - ny * half))
    for s in sides:
        n.line(s, col, a, core=core, halo=5)


def render(route_open):
    n = Neon()
    grid(n)
    P_ = L.floor_parts()
    # Kit: walls, lanes, outlanes, posts (cyan = route / neutral).
    for name, part in P_.items():
        if part[0] == "poly" and not name.startswith(("sling", "switch block", "ramp U", "RAILS block")):
            n.line(part[1], CYAN, 1.0)
        elif part[0] == "circle" and not name.startswith(("flipper", "hub", "sling")):
            n.circle(part[1], part[2], CYAN, 1.0, core=1.6, halo=6)
    # Outlane mouths and the drain chute: hazards (orange chevrons on the floor).
    for sx in (1, -1):
        x = 47 if sx == 1 else L.CELL_W - 47
        for k in range(3):
            y = 300 - k * 22
            n.line([(x - 12, y + 6), (x, y - 6), (x + 12, y + 6)], ORANGE, 0.55 - k * 0.12, core=1.6, halo=5)
    for k in range(2):
        y = 70 - k * 22
        n.line([(L.CX - 16, y + 8), (L.CX, y - 6), (L.CX + 16, y + 8)], ORANGE, 0.6 - k * 0.2, core=1.8, halo=6)
    # Slings: cyan body, white kicking face (active).
    for side in ("L", "R"):
        top, corner, tip, _ = P_[f"sling {side}"][1]
        n.poly_fill([top, corner, tip], CYAN, 0.06)
        n.line([top, corner, tip], CYAN, 0.9)
        n.line([tip, top], WHITE, 1.0, core=2.6, halo=9)
        for p, r in ((top, L.SLING_POST_TOP), (tip, L.SLING_POST_TIP), (corner, L.SLING_POST_CORNER)):
            n.circle(p, r, CYAN, 1.0, core=1.4, halo=5)
    # Return wires and entry stubs: dim cyan rails; entry portals cyan.
    for side in ("L", "R"):
        rails(n, L.return_wire(side), 17, CYAN, 0.22, core=0.9)
        rails(n, L.entry_stub(side), 17, CYAN, 0.22, core=0.9)
        x = L.entry_stub(side)[0][0] + (6 if side == "L" else -6)
        n.line([(x, L.ENTRY_PORTAL[0]), (x, L.ENTRY_PORTAL[1])], CYAN, 1.0, core=4, halo=12)
    # The room: ramp, blocks, targets.
    left, right = L.ramp_outline()
    n.poly_fill(left + list(reversed(right)), CYAN, 0.07)
    n.line(left, CYAN, 0.9)
    n.line(right, CYAN, 0.9)
    for y in range(int(L.RAMP_U_TOP) + 8, int(L.RAMP_TOP_Y) - 4, 16):                  # chevrons up the ramp
        h = L.ramp_half_at(y) - 7
        n.line([(L.CX - h, y - 6), (L.CX, y + 2), (L.CX + h, y - 6)], CYAN, 0.35, core=1.0, halo=4)
    n.line(P_["ramp U (floor-solid)"][1], CYAN, 1.0)
    for name in ("switch block L", "switch block R", "RAILS block"):
        pts = P_[name][1]
        n.poly_fill(pts, CYAN, 0.05)
        n.line(pts + [pts[0]], CYAN, 0.85)
    for s in (L.SWITCH_L, L.SWITCH_R, L.RAILS):
        n.line([s[0], s[1]], WHITE, 1.0, core=4.5, halo=12)
    n.text((L.SWITCH_L_C[0] - 4, L.SWITCH_L_C[1] + 24), "SWITCH ◄", 9, CYAN, 0.7)
    n.text((L.SWITCH_R_C[0] + 4, L.SWITCH_R_C[1] + 24), "SWITCH ►", 9, CYAN, 0.7)
    n.text((L.RAILS_C[0] - 26, L.RAILS_C[1] + 22), "RAILS", 9, CYAN, 0.7)
    # Turntable state for this panel: open = turntable and bridge both ◄ (magenta), else turntable ▲, bridge ◄ (orange).
    turn, bridge = ("W", "W") if route_open else ("N", "W")
    state = MAGENTA if route_open else ORANGE
    for key in ("W", "N", "E"):
        on = route_open and key == turn
        rails(n, L.rail_path(key), L.RAIL_HALF, MAGENTA if on else CYAN, 1.0 if on else 0.45, core=1.8 if on else 1.1)
    n.circle(L.HUB, L.RAIL_RING_R[1], CYAN, 0.5, core=1.0, halo=4)
    n.circle(L.HUB, L.RAIL_RING_R[0], CYAN, 0.5, core=1.0, halo=4)
    n.circle(L.HUB, L.HUB_TRACK_R, CYAN, 0.9, core=2.0, halo=8, fill=0.05)
    a = math.radians(L.HEADINGS[turn])
    tipp = (L.HUB[0] + 36 * math.cos(a), L.HUB[1] + 36 * math.sin(a))
    back = [(L.HUB[0] - 14 * math.cos(a) + s * 9 * math.sin(a), L.HUB[1] - 14 * math.sin(a) - s * 9 * math.cos(a)) for s in (1, -1)]
    n.poly_fill([back[0], tipp, back[1]], state, 0.35)
    n.line([back[0], tipp, back[1], back[0]], state, 1.0, core=2.2, halo=9)
    b = math.radians(L.HEADINGS[bridge])
    r0, r1 = L.RAIL_RING_R[0] - 2, L.RAIL_RING_R[1] + 4
    hw = L.RAIL_HALF
    corners = [(r0, -hw), (r1, -hw), (r1, hw), (r0, hw)]
    tile = [(L.HUB[0] + u * math.cos(b) - v * math.sin(b), L.HUB[1] + u * math.sin(b) + v * math.cos(b)) for u, v in corners]
    n.poly_fill(tile, state, 0.25)
    n.line(tile + [tile[0]], state, 1.0, core=2.0, halo=8)
    # Exit portals: open = magenta bloom, locked = orange barrier.
    ye = L.SIDE_EXIT
    for key, x in (("W", L.WALL_L), ("E", L.WALL_R)):
        open_ = route_open and key == turn
        col = MAGENTA if open_ else ORANGE
        n.line([(x, ye[0]), (x, ye[1])], col, 1.0, core=5 if open_ else 4, halo=22 if open_ else 12, glow=1.6 if open_ else 1.0)
        if not open_:
            for y in range(int(ye[0]) + 8, int(ye[1]), 14):
                dx = 10 if key == "W" else -10
                n.line([(x, y), (x + dx, y + 8)], ORANGE, 0.5, core=1.2, halo=4)
    n.line([(L.TOP_PORT[0], L.TOP_Y - 1), (L.TOP_PORT[1], L.TOP_Y - 1)], ORANGE, 1.0, core=4, halo=12)
    # Route lamps: the turntable's heading filled (orange / magenta), the bridge's heading ringed white.
    for key, dx, g in (("W", -46, "◄"), ("N", 0, "▲"), ("E", 46, "►")):
        c = (L.CX + dx, 505)
        aimed = key == turn
        n.circle(c, 15, state if aimed else CYAN, 1.0 if aimed else 0.35, core=1.6, halo=6, fill=0.55 if aimed else None)
        if key == bridge:
            n.circle(c, 19, WHITE, 0.9, core=1.4, halo=5)
        n.text(c, g, 13, WHITE if aimed else CYAN, 0.95 if aimed else 0.5)
    # Save lamps: kickback lit (white on cyan), outlane save off (dim).
    n.circle(L.M((45, 330)), 9, CYAN, 0.3, core=1.2, halo=4)
    n.circle((45, 330), 9, WHITE, 1.0, core=1.6, halo=8, fill=0.6)
    # Flippers: white, cyan halo.
    for side, pv in (("L", L.PIVOT_L), ("R", L.PIVOT_R)):
        raised = math.radians(51) if (side == "R" and route_open) else 0.0
        tip, poly = L.flipper_poly(pv, side, raised)
        n.poly_fill(poly, CYAN, 0.12)
        n.line(poly + [poly[0]], WHITE, 1.0, core=2.0, halo=9)
        n.circle(pv, L.FLIP_RP, WHITE, 1.0, core=2.0, halo=8, fill=0.1)
        n.circle(tip, L.FLIP_RT, WHITE, 1.0, core=1.6, halo=6)
    # The ball: a white data packet with a short trail (colour shifts as things light: magenta when the route is open).
    if route_open:
        path = [L.HUB] + L.rail_path("W")
        ball = (150.0, 790.0)
        trail = [(250 - i * 18, 790) for i in range(5)][::-1]
        tc = MAGENTA
    else:
        ball = (330.0, 470.0)
        trail = [(330 + i * 5, 470 - i * 22) for i in range(5, 0, -1)]
        tc = CYAN
    for i in range(len(trail) - 1):
        n.line([trail[i], trail[i + 1]], tc, 0.2 + 0.15 * i, core=3 + i * 2, halo=10 + i * 3)
    n.circle(ball, L.BALL_R, WHITE, 1.0, core=2.0, halo=14, fill=0.85)
    n.text((L.CX, 26), "SECTOR 1-1 · SWITCHYARD", 8, CYAN, 0.7)
    return n.image()


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "nl_neon_r1.png"
    a, b = render(False), render(True)
    gap = int(30 * K)
    sheet = Image.new("RGB", (W * 2 + gap * 3, H + gap * 2 + int(40 * K)), (6, 6, 10))
    d = ImageDraw.Draw(sheet)
    fnt = ImageFont.truetype(FONT, int(14 * K))
    for i, (img, cap) in enumerate(((a, "not lined up: ▲ ≠ ◄ (a ramp shot derails)"),
                                    (b, "lined up: ◄ = ◄ (route open, exit blooms)"))):
        x = gap + i * (W + gap)
        sheet.paste(img, (x, gap + int(40 * K)))
        d.text((x + W // 2, gap + int(18 * K)), cap, font=fnt, fill=(200, 230, 255), anchor="mm")
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
    sheet.save(out)
    print("wrote", out, sheet.size)
