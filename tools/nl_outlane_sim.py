"""Outlane drain experiments (T8 M1 v3): the Play Lab's outlane drains were wall-sliders — balls coming down the side
wall at x ~50-60 (left) or ~540-560 (right) at y ~500, then following the lower half of the bulge back out to the wall
and straight down the outlane. This sim drops wall-sliders and side-crossers on candidate wall shapes and counts where
they go first: the outlane, over the guide post into the inlane / playfield, or elsewhere.
Usage: python3 nl_outlane_sim.py"""
import math, random
import pymunk
import nl_layout as L
import nl_sim as S

def bulge_pts(y0, y1, inset, peak_frac, n=24):
    """A smooth bulge from (20, y0) to (20, y1) peaking `inset` in at y0 + peak_frac * (y1 - y0) (two quads)."""
    yp = y0 + peak_frac * (y1 - y0)
    pts = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        if y <= yp:
            t = (y - y0) / (yp - y0)
        else:
            t = (y1 - y) / (y1 - yp)
        x = L.WALL_L + inset * math.sin(t * math.pi / 2) ** 1.5
        pts.append((x, y))
    return pts

def build(bulge_left):
    sp = S.build()
    # replace the left outer wall section: remove nothing (pymunk static); instead build a fresh space without the
    # outer wall and add our own left wall + the rest
    return sp

def space_with(bulge_left, post=None):
    saved_bulge = L.bulge
    def custom(side="L"):
        pts = bulge_left
        return pts if side == "L" else [L.M(p) for p in pts]
    L.bulge = custom
    saved_post = L.OUTLANE_POST_L
    if post is not None:
        L.OUTLANE_POST_L = post
    try:
        return S.build()
    finally:
        L.bulge = saved_bulge
        L.OUTLANE_POST_L = saved_post

def classify(sp, s, b, secs=4.0):
    for i in range(int(240 * secs)):
        sp.step(1 / 240)
        x, y = b.position
        if y < 455 and x < 72:
            return "outlane"
        if y < 455 and x > 85:
            return "inside"           # into the inlane or back into the playfield below the guide post
        if y > 900 or (x > 230 and y < 700):
            return "away"             # bounced back up / out into the middle
    return "timeout"

def trial_set(bulge_left, post=None, n=200, seed=1):
    random.seed(seed)
    out = {"slider": {}, "crosser": {}}
    for kind in ("slider", "crosser"):
        for _ in range(n):
            sp = space_with(bulge_left, post)
            if kind == "slider":
                y = random.uniform(720, 900)
                pos = (L.WALL_L + L.BALL_R + 2, y)
                vel = (random.uniform(-120, 0), -random.uniform(0, 400))
            else:
                y = random.uniform(560, 700)
                pos = (random.uniform(110, 220), y)
                a = math.radians(random.uniform(195, 235))
                v = random.uniform(200, 650)
                vel = (v * math.cos(a), v * math.sin(a))
            b, s = S.ball(sp, pos, vel)
            r = classify(sp, s, b)
            out[kind][r] = out[kind].get(r, 0) + 1
    return out

if __name__ == "__main__":
    y0, y1, inset, pf = L.BULGE
    cands = {
        "now (480-760, peak 620, quad)": L.bulge("L"),
    }
    for (a, b_, ins, pf) in [(480, 760, 36, 0.5), (470, 760, 30, 0.25), (470, 720, 30, 0.2), (470, 760, 40, 0.3),
                             (470, 700, 26, 0.15), (500, 780, 36, 0.2)]:
        cands[f"{a}-{b_} inset {ins} peak@{pf}"] = bulge_pts(a, b_, ins, pf)
    for name, pts in cands.items():
        res = trial_set(pts)
        # mouth width: outlane post to the wall
        import nl_checks as C
        g = min(math.dist(p, L.OUTLANE_POST_L) for p in pts) - L.GUIDE_POST_R
        print(f"{name:34s} mouth~{g:5.1f}  sliders {res['slider']}  crossers {res['crosser']}")
