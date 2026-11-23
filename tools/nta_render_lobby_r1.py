"""Render the 9 to Alive Lobby sketch (round 1): three panels.
  1. Layout + gap callouts + the curved shot fan (simulated paths through the middle of each shot's window, 1,400 pt/s)
  2. Art direction mock (goofy cartoon, flat colours, thick outlines) - a look test, not art
  3. The cell on an iPhone 17 Pro Max screen with the HUD band and the horde meter mock
Usage: python3 nta_render_lobby_r1.py out.png"""
import math, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle, FancyBboxPatch, Rectangle, Ellipse
import pymunk
import nl_kit as K
import nta_room_lobby as R
import nta_lobby_checks as C
from nta_lobby_fan import space_with_names, fan

BG, WALL, ORANGE, RAMP, WIRE, POST = "#0d1110", "#39d98a", "#ff9a3c", "#39d98a", "#c9ced6", "#9aa0a6"

def track(origin, ang, v, secs=1.2):
    sp, _ = space_with_names()
    b = pymunk.Body(1, pymunk.moment_for_circle(1, 0, K.BALL_R)); b.position = origin
    b.velocity = (v * math.cos(math.radians(ang)), v * math.sin(math.radians(ang)))
    c = pymunk.Circle(b, K.BALL_R); c.elasticity, c.friction = 0.55, 0.25; sp.add(b, c)
    pts = []
    for i in range(int(secs * 240)):
        sp.step(1 / 240); pts.append(tuple(b.position))
        if b.position.y > 1000 or (b.position.y < 300 and b.velocity.y < 0 and i > 20):
            break
    return pts

def draw_poly(ax, pts, col, lw=2.0, fill=None, z=3, closed=False):
    if fill:
        ax.add_patch(Polygon(pts, closed=True, fc=fill, ec=col, lw=lw, zorder=z))
    else:
        xs, ys = zip(*pts); ax.plot(xs, ys, color=col, lw=lw, zorder=z, solid_capstyle="round")

def grey_box(ax, P):
    ax.set_facecolor(BG)
    for name, part in P.items():
        if name.startswith("flipper"):
            continue
        if part[0] == "circle":
            ax.add_patch(Circle(part[1], part[2], fc=POST, ec=POST, zorder=4))
        elif name in ("door block", "reception desk", "stairs U (floor-solid)") or name.startswith("sling "):
            draw_poly(ax, part[1], WALL, 1.6, fill="#173a2a", z=3)
        else:
            draw_poly(ax, part[1], WALL, 2.0)
    for side in ("L", "R"):
        piv = K.PIVOT_L if side == "L" else K.PIVOT_R
        tip, poly = K.flipper_poly(piv, side)
        ax.add_patch(Polygon(poly, closed=True, fc="#e8e8e8", ec="#e8e8e8", zorder=5))
        ax.add_patch(Circle(piv, K.FLIP_RP, fc="#e8e8e8", zorder=5)); ax.add_patch(Circle(tip, K.FLIP_RT, fc="#e8e8e8", zorder=5))
        # sling kicking faces in orange
        f = (lambda p: p) if side == "L" else K.M
        draw_poly(ax, [f(K.SLING_TIP_L), f(K.SLING_TOP_L)], ORANGE, 3, z=6)
    # drawn-only: the stairs ramp (raised), its ride, the door spinner, the wire ride, the return wires
    left, right = R.stair_outline()
    ax.add_patch(Polygon(left + list(reversed(right)), closed=True, fc=(0.22, 0.85, 0.54, 0.16), ec=RAMP, lw=1.2, zorder=2))
    u = R.STAIR_U_TOP
    draw_poly(ax, [(K.CX - R.stair_half_at(u) + 2, u + 4), (K.CX + R.stair_half_at(u) - 2, u + 4)], ORANGE, 4, z=6)  # stair door (shut)
    for side in ("L", "R"):
        draw_poly(ax, K.return_wire(side), WIRE, 1.2, z=2)
    draw_poly(ax, R.door_ride()[:3], "#ffd166", 2.2, z=6)
    draw_poly(ax, list(R.DOOR_SPINNER), "#ffd166", 5, z=6)
    for l, fa, fb, c, n in R.desk()[1]:
        draw_poly(ax, [fa, fb], ORANGE, 5, z=6)
    ax.set_xlim(0, 600); ax.set_ylim(0, 1060); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])

def panel_layout(ax):
    P = C.floor_parts()
    grey_box(ax, P)
    # open lower table band (sling tops -> shot line)
    ax.add_patch(Rectangle((150, K.SLING_TOP_L[1]), 300, R.STAIR_MOUTH_Y - K.SLING_TOP_L[1], fc=(1, 1, 1, 0.04),
                           ec=(1, 1, 1, 0.25), ls="--", lw=1, zorder=1))
    ax.text(300, 510, "open lower table\n(lamps + art only)", color="#8a9a90", ha="center", va="center", fontsize=7)
    # curved fan: paths through the middle of each window at 1400
    cols = {"STAIRS": "#4cc9f0", "DOOR": "#ffd166", "B": "#ff6b6b", "A": "#ff6b6b", "R": "#ff6b6b"}
    runs = fan(1400)
    for fl, sp in (("left", R.SWEET_L), ("right", R.SWEET_R)):
        for nm, a0, a1 in runs[fl]:
            if nm in cols:
                pts = track(sp, (a0 + a1) / 2, 1400)
                xs, ys = zip(*pts)
                ax.plot(xs, ys, color=cols[nm], lw=1.1, alpha=0.85, ls="-" if fl == "left" else "--", zorder=7)
    # labels
    lab = dict(color="white", fontsize=7.5, ha="center", zorder=9,
               bbox=dict(boxstyle="round,pad=0.25", fc="#000000aa", ec="none"))
    ax.text(300, 820, "STAIRS\n(ramp → top port)", **lab)
    ax.text(85, 610, "REVOLVING\nDOOR\n(spinner)", **lab)
    ax.text(505, 860, "RECEPTION DESK\nB · A · R", **lab)
    ax.text(165, 965, "ride onto the wire\n→ left inlane", color="#ffd166", fontsize=6.5, ha="center", zorder=9)
    ax.text(330, 668, "stair door (shut)", color=ORANGE, fontsize=6.5, ha="left", va="center", zorder=9)
    # gap callouts
    for name, g, v, p, q in C.named_passages():
        if p is None or "outlane" in name or "inlane" in name or g > 120:
            continue
        ax.annotate("", p, q, arrowprops=dict(arrowstyle="<->", color="#ffe066", lw=0.8), zorder=8)
        m = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        ax.text(m[0] + 6, m[1], f"{g:.0f}", color="#ffe066", fontsize=6.5, zorder=9)
    ax.set_title("Lobby · layout, gaps, curved shot fan (1,400 pt/s)\nsolid = left flipper, dashed = right flipper",
                 color="white", fontsize=9)

def panel_art(ax):
    """Look test: flat cartoon colours, chunky dark outlines, a bean zombie in a tie."""
    ink = "#2b2233"
    ax.set_facecolor("#2b2233")
    out = K.outer_wall()
    ax.add_patch(Polygon(out, closed=True, fc="#f4e3c1", ec=ink, lw=4, zorder=1))          # lobby carpet
    for y in range(120, 1000, 60):                                                          # carpet pattern
        for x in range(40, 580, 60):
            ax.add_patch(Circle((x + (30 if (y // 60) % 2 else 0), y), 5, fc="#e9cf9e", ec="none", zorder=1))
    # checker entry mat in the open lower table (art only)
    for i in range(6):
        for j in range(3):
            if (i + j) % 2 == 0:
                ax.add_patch(Rectangle((210 + i * 30, 470 + j * 30), 30, 30, fc="#cf5c36", ec="none", zorder=1.5))
    P = C.floor_parts()
    ax.add_patch(Polygon(P["door block"][1], closed=True, fc="#7fb7be", ec=ink, lw=3, zorder=2))   # glass entrance
    ax.add_patch(Polygon(P["reception desk"][1], closed=True, fc="#b5713f", ec=ink, lw=3, zorder=2))  # wooden desk
    for l, fa, fb, c, n in R.desk()[1]:
        ax.plot([fa[0], fb[0]], [fa[1], fb[1]], color="#ffd23f", lw=7, solid_capstyle="round", zorder=3)
        ax.text(c[0] - n[0] * 16, c[1] - n[1] * 16, l, color=ink, fontsize=9, weight="bold", ha="center", va="center", zorder=4)
    left, right = R.stair_outline()
    ax.add_patch(Polygon(left + list(reversed(right)), closed=True, fc="#9bc53d", ec=ink, lw=3, zorder=2))
    for y in range(int(R.STAIR_U_TOP) + 10, 975, 26):
        ax.plot([K.CX - 20, K.CX + 20], [y, y], color=ink, lw=1.5, zorder=3)                 # steps
    ax.add_patch(FancyBboxPatch((255, 990), 90, 34, boxstyle="round,pad=2", fc="#3aa655", ec=ink, lw=2.5, zorder=4))
    ax.text(300, 1007, "STAIRS ▲", color="white", fontsize=8, weight="bold", ha="center", va="center", zorder=5)
    # revolving door
    s0, s1 = R.DOOR_SPINNER
    mid = ((s0[0] + s1[0]) / 2, (s0[1] + s1[1]) / 2)
    ax.add_patch(Circle(mid, 30, fc="#d7f2f7", ec=ink, lw=3, zorder=4))
    for k in range(4):
        a = math.radians(20 + 90 * k)
        ax.plot([mid[0], mid[0] + 28 * math.cos(a)], [mid[1], mid[1] + 28 * math.sin(a)], color=ink, lw=2.5, zorder=5)
    # slings + flippers in cartoon colours
    for side in ("L", "R"):
        f = (lambda p: p) if side == "L" else K.M
        ax.add_patch(Polygon([f(K.SLING_TOP_L), f(K.SLING_CORNER_L), f(K.SLING_TIP_L)], closed=True, fc="#ef476f", ec=ink, lw=3, zorder=3))
        piv = K.PIVOT_L if side == "L" else K.PIVOT_R
        tip, poly = K.flipper_poly(piv, side)
        ax.add_patch(Polygon(poly, closed=True, fc="white", ec=ink, lw=3, zorder=5))
    # a zombie bean in a tie (character look test)
    zx, zy = 300, 800
    ax.add_patch(Ellipse((zx, zy), 70, 96, fc="#a7c957", ec=ink, lw=3, zorder=6))
    ax.add_patch(Circle((zx - 13, zy + 18), 11, fc="white", ec=ink, lw=2, zorder=7))
    ax.add_patch(Circle((zx + 14, zy + 14), 8, fc="white", ec=ink, lw=2, zorder=7))
    ax.add_patch(Circle((zx - 10, zy + 16), 4, fc=ink, zorder=8)); ax.add_patch(Circle((zx + 16, zy + 12), 3, fc=ink, zorder=8))
    ax.plot([zx - 14, zx - 4, zx + 6, zx + 14], [zy - 10, zy - 14, zy - 10, zy - 15], color=ink, lw=2.5, zorder=7)
    ax.add_patch(Polygon([(zx - 6, zy - 24), (zx + 6, zy - 24), (zx + 9, zy - 46), (zx, zy - 54), (zx - 9, zy - 46)],
                         closed=True, fc="#d62828", ec=ink, lw=2, zorder=7))                    # tie
    ax.add_patch(Ellipse((zx + 22, zy + 44), 16, 8, angle=30, fc="#f4a261", ec=ink, lw=1.5, zorder=7))   # coffee-stain lanyard tag
    ax.text(300, 860, "\"...mondays...\"", color=ink, fontsize=7, ha="center", style="italic", zorder=8)
    ax.set_xlim(0, 600); ax.set_ylim(0, 1060); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    ax.set_title("Look test: flat cartoon, thick ink outlines\n(drawn in code; not final art)", color="white", fontsize=9)

def panel_phone(ax):
    """iPhone 17 Pro Max portrait, 440 x 956 pt; the cell at 600/440 = 1.36 world pt per screen pt."""
    W, H = 440, 956
    ax.set_facecolor("#000000")
    ax.add_patch(FancyBboxPatch((0, 0), W, H, boxstyle="round,pad=0,rounding_size=50", fc="#050505", ec="#555", lw=2))
    top_safe, bottom_safe = 62, 34
    s = 1 / 1.36
    cell_h = K.CELL_H * s
    y0 = bottom_safe
    sub = ax.inset_axes([0, y0 / H, 1, cell_h / H], transform=ax.transAxes)
    grey_box(sub, C.floor_parts())
    sub.set_facecolor(BG)
    band_y = y0 + cell_h
    band_h = H - top_safe - band_y
    ax.add_patch(Rectangle((0, band_y), W, band_h, fc="#141821", ec="none"))
    # horde meter: 8 floor pips, horde icon, ball icon, fill to the next floor
    floors = ["L", "2", "3", "4", "5", "6", "7", "R"]
    px0, pw, gap_ = 16, 34, 4
    for i, f in enumerate(floors):
        x = px0 + i * (pw + gap_)
        col = "#5a3d6b" if i == 0 else ("#2a3140" if i > 2 else "#3b4456")
        ax.add_patch(FancyBboxPatch((x, band_y + 10), pw, 22, boxstyle="round,pad=0,rounding_size=4", fc=col, ec="#8892a6", lw=0.8))
        ax.text(x + pw / 2, band_y + 21, f, color="white", fontsize=7, ha="center", va="center")
    ax.add_patch(Rectangle((px0 + 2, band_y + 5), (pw + gap_) * 0.62, 3, fc="#a7c957", ec="none"))   # horde 62% of the way to floor 2
    ax.text(px0 + pw / 2, band_y + 38, "🧟", fontsize=8, ha="center") if False else \
        ax.add_patch(Circle((px0 + pw / 2, band_y + 40), 5, fc="#a7c957", ec="#2b2233", lw=1))
    ax.add_patch(Circle((px0 + 2 * (pw + gap_) + pw / 2, band_y + 40), 5, fc="#e8e8e8", ec="#2b2233", lw=1))
    ax.text(px0 + 8 * (pw + gap_) + 4, band_y + 26, "1,240,500", color="#ffd166", fontsize=8, ha="left", va="center")
    ax.text(W / 2, band_y + band_h - 6, f"HUD band: {band_h:.0f} pt  ·  cell {cell_h:.0f} pt tall at 1.36", color="#9aa0a6",
            fontsize=6, ha="center", va="top")
    ax.set_xlim(0, W); ax.set_ylim(0, H); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    ax.set_title("On the phone: horde meter in the top band\n(green = horde, white = ball, bar = how close to the next floor)",
                 color="white", fontsize=9)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "nta_lobby_r1.png"
    fig, axes = plt.subplots(1, 3, figsize=(17, 10.5), facecolor="#1a1d22",
                             gridspec_kw=dict(width_ratios=[600, 600, 440 * 1060 / 956 * 0.98]))
    panel_layout(axes[0]); panel_art(axes[1]); panel_phone(axes[2])
    fig.suptitle("9 to Alive · Lobby floor · round 1 sketch (Neon's cell kit + the Lobby room)", color="white", fontsize=12, y=0.995)
    plt.tight_layout(rect=(0, 0, 1, 0.965))
    fig.savefig(out, dpi=110, facecolor=fig.get_facecolor())
    print("wrote", out)
