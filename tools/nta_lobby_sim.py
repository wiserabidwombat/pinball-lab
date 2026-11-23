"""pymunk checks for the 9 to Alive Lobby (kit + room), at Neon's real-scale physics (gravity 900 pt/s^2, ball r 15).
Flippers are not modelled: a ball that falls below y 300 is done (it reached the lower table).
  stuck test: balls dropped anywhere in the upper table with random velocities -> any that come to rest (the Play Lab's
  watchdog, before there is a Play Lab). The shots themselves are in nta_lobby_fan.py.
"""
import math, random, sys
import pymunk
import nl_kit as K
import nta_room_lobby as R
from nta_lobby_checks import floor_parts

G = 900.0
ELAST, FRICT = 0.55, 0.25

def build(space):
    for name, part in floor_parts().items():
        if name.startswith("flipper"):
            continue
        if part[0] == "poly":
            pts = part[1]
            for a, b in zip(pts, pts[1:]):
                s = pymunk.Segment(space.static_body, a, b, 0.5)
                s.elasticity = 0.85 if name == "door block" and False else ELAST
                s.friction = FRICT
                space.add(s)
        else:
            c = pymunk.Circle(space.static_body, part[2], part[1])
            c.elasticity, c.friction = ELAST, FRICT
            space.add(c)

def new_space():
    sp = pymunk.Space()
    sp.gravity = (0, -G)
    sp.iterations = 30
    build(sp)
    return sp

def ball(space, pos, vel):
    b = pymunk.Body(1, pymunk.moment_for_circle(1, 0, K.BALL_R))
    b.position, b.velocity = pos, vel
    s = pymunk.Circle(b, K.BALL_R)
    s.elasticity, s.friction = ELAST, FRICT
    space.add(b, s)
    return b

def side_of(p, a, b):
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])

DT = 1 / 240.0

def stuck_test(n=500, seed=3):
    rnd = random.Random(seed)
    stuck = []
    for i in range(n):
        sp = new_space()
        for _ in range(50):
            pos = (rnd.uniform(40, 560), rnd.uniform(640, 1020))
            q = sp.point_query_nearest(pos, K.BALL_R + 1, pymunk.ShapeFilter())
            if q is None and not _inside_block(pos):
                break
        v = rnd.uniform(0, 600); a = rnd.uniform(0, 2 * math.pi)
        b = ball(sp, pos, (v * math.cos(a), v * math.sin(a)))
        still = 0.0
        for step in range(int(10 / DT)):
            sp.step(DT)
            still = still + DT if b.velocity.length < 8 else 0.0
            if still > 1.5:
                stuck.append((round(b.position[0]), round(b.position[1]))); break
            if b.position[1] < 300 and b.velocity.y < 0:
                break
        else:
            stuck.append(("timeout", round(b.position[0]), round(b.position[1])))
    return stuck

def _inside(poly, p):
    c = False
    for a, b in zip(poly, poly[1:]):
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < a[0] + (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]):
            c = not c
    return c

def _inside_block(p):
    if _inside(R.door_block(), p) or _inside(R.room_parts()["stairs U (floor-solid)"][1] + [R.room_parts()["stairs U (floor-solid)"][1][0]], p):
        return True
    return _inside(R.desk()[2], p) or p[0] > 2 * K.CX - R._knee_x(p[1]) - K.BALL_R or p[0] < R._knee_x(p[1]) + K.BALL_R

if __name__ == "__main__":
    st = stuck_test(int(sys.argv[1]) if len(sys.argv) > 1 else 1000)
    print(f"STUCK TEST (balls dropped anywhere in the upper table, y 640-1020, random 0-600 pt/s): {len(st)} stuck", st[:10])
