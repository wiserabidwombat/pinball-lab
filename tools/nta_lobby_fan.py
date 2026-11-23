"""Curved shot fan for the 9 to Alive Lobby: straight lines ignore gravity, which bends a 1,200-1,800 pt/s shot by
40-80 pt over the table. For each launch angle from each sweet spot, simulate the ball (pymunk, gravity 900) and record
what it does first: STAIRS (crosses the stairs mouth going up at >= 400 pt/s), DOOR (crosses the spinner going up),
B / A / R (touches that standup), or the first other part it touches. Also: where door shots come back out."""
import math, sys
import pymunk
import nl_kit as K
import nta_room_lobby as R
from nta_lobby_checks import floor_parts
from nta_lobby_sim import side_of

DT = 1 / 240.0

def space_with_names():
    sp = pymunk.Space(); sp.gravity = (0, -900); sp.iterations = 30
    names = {}
    for name, part in floor_parts().items():
        if name.startswith("flipper"):
            continue
        shapes = [pymunk.Segment(sp.static_body, a, b, 0.5) for a, b in zip(part[1], part[1][1:])] if part[0] == "poly" \
            else [pymunk.Circle(sp.static_body, part[2], part[1])]
        for s in shapes:
            s.elasticity, s.friction = 0.55, 0.25
            sp.add(s); names[s] = name
    return sp, names

def shoot(origin, ang, v, follow_door=False):
    sp, names = space_with_names()
    b = pymunk.Body(1, pymunk.moment_for_circle(1, 0, K.BALL_R)); b.position = origin
    b.velocity = (v * math.cos(math.radians(ang)), v * math.sin(math.radians(ang)))
    c = pymunk.Circle(b, K.BALL_R); c.elasticity, c.friction = 0.55, 0.25; sp.add(b, c)
    s0, s1 = R.DOOR_SPINNER
    first, first_t, space_t = [], [], [0.0]
    t0, t1 = R.door_pt(R.DOOR_TRIGGER_T, "out", R.DOOR_HALF), R.door_pt(R.DOOR_TRIGGER_T, "in", R.DOOR_HALF)
    sd_trig = lambda q: side_of(q, t0, t1)
    wire = False
    def touched(arb, space, data):
        other = arb.shapes[1] if arb.shapes[0] is c else arb.shapes[0]
        if other in names and not first:
            first.append(names[other]); first_t.append(space_t[0])
    sp.on_collision(None, None, begin=touched) if hasattr(sp, "on_collision") else None
    prev_y, prev_side = b.position.y, side_of(b.position, s0, s1)
    door = False
    for step in range(int(6 / DT)):
        sp.step(DT); space_t[0] += DT
        p, vel = b.position, b.velocity
        if door and not wire and sd_trig(p) >= 0 and vel.dot(R.DOOR_U) > 0:
            return ("WIRE", None, vel.length)
        if not door and prev_y < R.STAIR_MOUTH_Y + 12 <= p.y and abs(p.x - K.CX) < R.STAIR_MOUTH_HALF - 5 and vel.y > 0 and vel.length >= 400 and (not first or first[0].startswith("stairs")):
            return ("STAIRS", None, vel.length)
        sd = side_of(p, s0, s1)
        within = min(s0[0], s1[0]) - 5 <= p.x <= max(s0[0], s1[0]) + 5
        if within and prev_side < 0 <= sd and not door:
            door = True; spd = vel.length
            if not follow_door:
                return ("DOOR", None, spd)
            first.clear(); first.append("door*")
        prev_y, prev_side = p.y, sd
        if first and not door and first[0].startswith(("door", "stairs")) and step * DT < first_t[0] + 0.6:
            pass                                       # glancing off the lane's flare or a mouth post can still go in
        elif first and not door:
            nm = first[0]
            if nm == "reception desk":
                for letter, c, n, face in R.barricade():
                    if math.dist(p, c) < R.DESK_TARGET_W / 2 + K.BALL_R + 4:
                        return (letter, None, vel.length)
                return ("desk front/roof", None, vel.length)
            return (nm, None, vel.length)
        if p.y < 230 and vel.y < 0 and step > 10:
            return ("DOOR" if door else "fell", p.x, None)
    return ("DOOR" if door else "timeout", None, None)

def fan(v):
    out = {}
    for fl, sp in (("left", R.SWEET_L), ("right", R.SWEET_R)):
        runs, cur, start = [], None, None
        a = 40.0
        while a <= 125.0:
            r = shoot(sp, a, v)[0]
            if r != cur:
                if cur is not None:
                    runs.append((cur, start, a - 0.25))
                cur, start = r, a
            a += 0.25
        runs.append((cur, start, 125.0))
        out[fl] = runs
    return out

if __name__ == "__main__":
    for v in (1200, 1600):
        print(f"FAN at {v} pt/s (angle ranges, deg; only the room's shots and wide runs shown)")
        for fl, runs in fan(v).items():
            print(f"  {fl}:")
            for nm, a0, a1 in runs:
                if nm in ("STAIRS", "DOOR", "B", "A", "R") or a1 - a0 >= 3:
                    print(f"    {a0:6.2f}..{a1:6.2f}  ({a1 - a0 + 0.25:4.2f})  {nm}")
    # where the door's returns land (aim inside the measured DOOR window at 1600)
    print("DOOR RETURNS (right flipper, 1200-1800 pt/s, across the 1600 window): x where they come down through y 230")
    runs = dict((nm, (a0, a1)) for nm, a0, a1 in fan(1600)["right"] if nm == "DOOR")
    a0, a1 = runs.get("DOOR", (None, None))
    xs, wires = [], []
    if a0 is not None:
        for v in (1200, 1400, 1600, 1800):
            a = a0
            while a <= a1:
                r = shoot(R.SWEET_R, a, v, follow_door=True)
                if r[0] == "WIRE":
                    wires.append(v)
                elif r[0] == "DOOR" and r[1] is not None:
                    xs.append(r[1])
                a += 0.25
    xs.sort()
    print(f"  {len(wires)} reached the end (ride the wire to the left inlane); {len(xs)} fell back down the lane")
    if xs:
        lf = sum(x < 262 for x in xs); gap = sum(262 <= x <= 338 for x in xs); rf = sum(x > 338 for x in xs)
        print(f"  {len(xs)} returns: over the left flipper {lf}, over the gap between the tips {gap}, over the right flipper {rf};"
              f" median x {xs[len(xs)//2]:.0f}")
