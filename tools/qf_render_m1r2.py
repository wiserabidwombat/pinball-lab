"""M1 round 2 sketch: the upper flipper at the glade's top right, its diverter, and what pymunk says about its feed and
its shots. Panel 1: the whole table (round 1 render + the new parts). Panel 2: the glade zoomed, with feed tracks
(diverter up: cyan; down: grey) and shot tracks from the flipper's face (gold), the wisp loops and their homes."""
import math, random, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle
import pymunk
import qf_layout as L
import qf_render_m1 as R
import qf_uf_sim as S

def track_feed(diverter, n=10, seed=4):
    random.seed(seed); out = []
    for _ in range(n):
        sp = pymunk.Space(); sp.gravity = (0, -S.G); sp.iterations = 20; S.build(sp, diverter=diverter)
        x = random.uniform(400, 460); spd = random.uniform(500, 1400); p, t = S.arch_start(x)
        b = S.ball(sp, p, (t[0] * spd, t[1] * spd)); tr = []
        for _ in range(int(2.2 / S.STEP)):
            sp.step(S.STEP); tr.append((b.position.x, b.position.y))
            if b.position.y < 980: break
        out.append(tr)
    return out

def track_shots():
    out = []
    for raised_deg in (5, 15, 25, 35, 45):
        r = math.radians(raised_deg); tip, _ = L.uf_poly(r)
        a = math.atan2(tip[1] - L.UF_PIVOT[1], tip[0] - L.UF_PIVOT[0]); nrm = a - math.pi / 2
        start = (L.UF_PIVOT[0] + (tip[0] - L.UF_PIVOT[0]) * 0.6 + math.cos(nrm) * (L.BALL_R + 7),
                 L.UF_PIVOT[1] + (tip[1] - L.UF_PIVOT[1]) * 0.6 + math.sin(nrm) * (L.BALL_R + 7))
        sp = pymunk.Space(); sp.gravity = (0, -S.G); sp.iterations = 20; S.build(sp, diverter=False, uf_raised=r)
        b = S.ball(sp, start, (math.cos(nrm) * 1500, math.sin(nrm) * 1500)); tr = []
        for _ in range(int(0.9 / S.STEP)):
            sp.step(S.STEP); tr.append((b.position.x, b.position.y))
        out.append((raised_deg, math.degrees(nrm) % 360, tr))
    return out

def draw_uf(ax, lw=1.0):
    tip, poly = L.uf_poly()
    ax.add_patch(Polygon(poly, closed=True, color="#e8efe9", zorder=8))
    ax.add_patch(Circle(L.UF_PIVOT, L.UF_RP, color="#e8efe9", zorder=8)); ax.add_patch(Circle(tip, L.UF_RT, color="#e8efe9", zorder=8))
    tip2, poly2 = L.uf_poly(L.FLIP_TRAVEL)
    ax.add_patch(Polygon(poly2, closed=True, color="#e8efe9", alpha=0.3, zorder=8))
    ax.plot([L.DIVERTER_A[0], L.DIVERTER_B[0]], [L.DIVERTER_A[1], L.DIVERTER_B[1]], color=R.KICK, lw=3 * lw, zorder=9)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "qf_forest_m1r2.png"
    fig = plt.figure(figsize=(17, 11), facecolor=R.BG)
    ax1 = fig.add_axes([0.0, 0.02, 0.34, 0.94]); R.draw_layout(ax1); draw_uf(ax1)
    ax1.set_title("Haunted Forest · round 2b: the upper flipper on the forest block (Aaron's mark)", color=R.TXT, fontsize=10)
    ax2 = fig.add_axes([0.35, 0.10, 0.64, 0.84]); R.draw_layout(ax2); draw_uf(ax2, 1.4)
    for tr in track_feed(False):
        xs, ys = zip(*tr); ax2.plot(xs, ys, color="#9aa", lw=1.0, alpha=0.7, zorder=11)
    for tr in track_feed(True):
        xs, ys = zip(*tr); ax2.plot(xs, ys, color="#5fe0ff", lw=1.2, alpha=0.8, zorder=11)
    for deg, head, tr in track_shots():
        xs, ys = zip(*tr); ax2.plot(xs, ys, color="#ffcf6b", lw=1.4, zorder=12)
        ax2.text(xs[min(25, len(xs) - 1)], ys[min(25, len(ys) - 1)], f"{head:.0f}°", color="#ffcf6b", fontsize=8, zorder=13)
    ax2.set_xlim(20, 640); ax2.set_ylim(900, 1345)
    ax2.set_title("the glade, zoomed: feed with the diverter UP (cyan) / DOWN (grey); flips at 1,500 pt/s (gold, heading off the face)",
                  color=R.TXT, fontsize=10)
    fig.text(0.355, 0.04, "pymunk: diverter up → 30/30 orbits land on the upper flipper (unflipped, they roll off its tip and left down the Graveyard lane);"
             " down → 30/30 ride past to the right lane.\nFlips straight up into the glade (69°–120°): 15/20 test flips hit a wisp — early flips the left one (121°), late flips the right one (72°).",
             color=R.TXT, fontsize=9)
    fig.savefig(out, dpi=120, facecolor=R.BG); print("saved", out)
