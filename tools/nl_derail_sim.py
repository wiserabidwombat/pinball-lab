"""T8 M2 v1: where a derailed ball (turntable and bridge not lined up) lands on the floor, and where it goes next.
The ball leaves the turntable at the ring's outer edge along its heading and drops to the floor with a release velocity.
Counts the first of: a flipper / an outlane / the centre drain / stuck (moved < 4 pt in 3 s) / still moving at 8 s."""
import math, random, sys
import nl_layout as L, nl_sim as S
random.seed(11)
R_OUT = L.RAIL_RING_R[1]
CANDS = {
    "W": [((L.CX - R_OUT - 10, L.HUB[1]), (-250, -60))],
    "E": [((L.CX + R_OUT + 10, L.HUB[1]), (250, -60))],
    "N": [((L.CX, L.HUB[1] + R_OUT + 16), (60, 150)), ((L.CX, L.HUB[1] + R_OUT + 16), (-60, 150))],
}
def run(pos, vel, n=150):
    rows = []
    for _ in range(n):
        sp = S.build()
        b, s = S.ball(sp, (pos[0] + random.uniform(-3, 3), pos[1] + random.uniform(-3, 3)),
                      (vel[0] * random.uniform(0.8, 1.2) + random.uniform(-25, 25), vel[1] * random.uniform(0.8, 1.2)))
        last = [(b.position.x, b.position.y, 0)]
        def stop(b, path):
            x, y = b.position
            for info in sp.shape_query(s):
                if getattr(info.shape, "part", "").startswith("flipper"): return "flipper"
            if y < 300 and (x < L.GUIDE_X or x > 2 * L.CX - L.GUIDE_X): return "outlane"
            if y < 130: return "centre drain"
            t = len(path)
            if t % 240 == 0:
                if t >= 720 and math.hypot(x - path[t - 720][0], y - path[t - 720][1]) < 4: return "stuck"
        r, hits, path = S.first_contacts(sp, s, b, 240 * 8, stop)
        rows.append(r)
    return S.tally(rows)
if __name__ == "__main__":
    for k, cs in CANDS.items():
        for pos, vel in cs:
            print(k, pos, vel, run(pos, vel))
