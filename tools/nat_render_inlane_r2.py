"""M1 round 2 picture: the left inlane feed, r1 curved (Neon kit) vs r2 angled, with pymunk tracks of balls coming down
the inlane onto the held-up flipper and the speed each meets it with. Writes ../out/nat_inlane_m1r2.png."""
import math, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MPoly, Circle as MCirc
import nat_layout as L
import nat_inlane_sim as N

OUT = os.path.join(os.path.dirname(__file__), "..", "out")


def draw(ax, title, deg, R):
    N.set_slant(deg)
    ax.set_xlim(10, 300); ax.set_ylim(150, 500); ax.set_aspect("equal"); ax.axis("off")
    ax.set_facecolor("#101418")
    ax.add_patch(MPoly([(10, 150), (300, 150), (300, 500), (10, 500)], fc="#101418", zorder=0))
    ow = [(L.CHUTE_X, L.CHUTE_BOTTOM), L.APRON_END, L.SLOPE_TOP, (L.WALL_L, 520)]
    ax.plot(*zip(*ow), color="#4fd06b", lw=2)
    g = N.guide(R)
    ax.plot(*zip(*g), color="#4fd06b", lw=2.4, solid_capstyle="round")
    ax.add_patch(MCirc((L.GUIDE_X, L.GUIDE_TOP_Y), L.GUIDE_POST_R, fc="#9aa3ab"))
    corner, tip, _ = N.sling_for(R)
    ax.add_patch(MPoly([L.SLING_TOP_L, corner, tip], fc="#2a2118", ec="#ff9a3c", lw=1.4))
    for raised, a in ((0.0, 0.25), (L.FLIP_TRAVEL, 1.0)):
        ft, poly = L.flipper_poly(L.PIVOT_L, "L", raised)
        ax.add_patch(MPoly(poly, fc="#e8e8e8", alpha=a, ec="none"))
        ax.add_patch(MCirc(L.PIVOT_L, L.FLIP_RP, fc="#e8e8e8", alpha=a)); ax.add_patch(MCirc(ft, L.FLIP_RT, fc="#e8e8e8", alpha=a))
    speeds = []
    for v, col in ((150, "#7fd3ff"), (450, "#e0b84c"), (800, "#f08a7e")):
        tr = []
        s = N.onto_flipper(R, v, L.INLANE_X, track=tr)
        speeds.append((v, s))
        ax.plot(*zip(*tr), color=col, lw=1.3)
        ax.add_patch(MCirc(tr[-1], L.BALL_R, fc="none", ec=col, lw=1.2))
        ax.text(tr[-1][0] + 18, tr[-1][1] + 16 + (v - 450) / 30, f"{s:.0f}", color=col, fontsize=10, fontweight="bold")
    res = N.compare()
    key = [k for k in res if (("curved" in k) == (R > 0))][0]
    med, lo, hi, cy, by = res[key]
    N.set_slant(deg)
    ax.text(155, 490, title, color="#e8e8e8", ha="center", va="top", fontsize=11, fontweight="bold")
    ax.text(155, 470, f"meets the held-up flipper at {med:.0f} pt/s median\n({lo:.0f}-{hi:.0f}, balls let go at 150-800)",
            color="#c9d2da", ha="center", va="top", fontsize=8.5)
    ax.text(20, 160, "tracks: let go at 150 / 450 / 800 pt/s;\nnumber = speed onto the flipper", color="#7f8a93", fontsize=7)


fig, axs = plt.subplots(1, 2, figsize=(11, 6.8), dpi=110)
fig.patch.set_facecolor("#101418")
draw(axs[0], "r1: curved (Neon's kit, 32°, r 120)", 32, 120)
draw(axs[1], "r2: traditional angled (20°, sharp corner)", 20, 0)
fig.text(0.5, 0.02, "CHOMP!'s Play Lab catches: 91–98 % under 300 pt/s · 32 % at 300–400 · ~1 % over 500", color="#e0b84c",
         ha="center", fontsize=9)
fig.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.06, wspace=0.02)
fig.savefig(os.path.join(OUT, "nat_inlane_m1r2.png"), facecolor=fig.get_facecolor())
print("ok")
