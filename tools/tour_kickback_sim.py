"""Table 06: the left kickback against the '/' deflector under the R-O-C bank (pymunk, 2D, our units).
Walls copied from the layout; the ball is fired up the left outlane at 1,500 pt/s like updateKickback."""
import math, sys
sys.path.insert(0, '.')
import pymunk
import tour_layout as L

G = -1380
def run(defl, kick_x, extra_walls=(), t_end=1.2, dt=1/240):
    sp = pymunk.Space(); sp.gravity = (0, G)
    def wall(pts, e=0.3, f=0.1):
        for a, b in zip(pts, pts[1:]):
            s = pymunk.Segment(sp.static_body, a, b, 0); s.elasticity = e; s.friction = f; sp.add(s)
    wall(L.outer_wall())
    for w in [L.leftLaneGuide, L.leftOutlaneWall, L.leftOutlanePostRail, list(L.leftSling) + [L.leftSling[0]], defl]:
        wall(w)
    for w in extra_walls: wall(w)
    b = pymunk.Body(0.08, pymunk.moment_for_circle(0.08, 0, 9)); b.position = (kick_x, 238); b.velocity = (0, 1500)
    c = pymunk.Circle(b, 9); c.elasticity = 1.0; c.friction = 0.1; sp.add(b, c)
    path = []
    t = 0
    while t < t_end:
        sp.step(dt); t += dt; path.append((t, b.position.x, b.position.y, b.velocity.x, b.velocity.y))
    return path

if __name__ == '__main__':
    import tour_layout_a as A
    for kx in (30, 37, 44):
        p = run(A.ROC_STRUCT, kx)
        top = max(p, key=lambda r: r[2])
        out = next((r for r in p if r[1] > 110), None)
        print(f'kick at x {kx}: leaves the wall side at t {out[0]:.2f}s ({out[1]:.0f},{out[2]:.0f}) v ({out[3]:.0f},{out[4]:.0f})' if out else f'kick at x {kx}: never leaves the left side', f'| highest y {top[2]:.0f} at x {top[1]:.0f} | at 1.2 s ({p[-1][1]:.0f},{p[-1][2]:.0f})')
