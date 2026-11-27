"""Replay a Shot Lab sweep's launches in pymunk against a layout (Quest & Flipper, Table 09).

Each Shot Lab trial records where the ball left the flipper's reach and how (x, y, heading, speed). This replays
those launches against qf_layout's static parts (flippers at rest, mode parts off) and classifies the first shot it
makes, so a layout change can be judged on the real flipper fan before a Simulator run.

  python3 qf_fan_replay.py results.json [flipper] [--compare]

Outcomes: well (path within the capture radius), orbit (crosses the spinner line in the Graveyard lane), log (path
within 18 of the log hole), bark (reaches the bark row), oldRoad (crosses the ramp's entry line going up),
eastLantern (touches the lantern's face), drain (below y 150), none (anything else within 2.5 s).
"""
import json, math, sys
import pymunk
import qf_layout as L
from qf_sim import build, ball, G

STEP = 1 / 120

def near_path(a, b, c, r):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = 0 if dx == dy == 0 else max(0, min(1, ((c[0] - a[0]) * dx + (c[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist((a[0] + dx * t, a[1] + dy * t), c) < r

def replay(x, y, heading, speed, seconds=2.5):
    sp = pymunk.Space(); sp.gravity = (0, -G); sp.iterations = 20
    build(sp)
    h = math.radians(heading)
    b = ball(sp, (x, y), (speed * math.cos(h), speed * math.sin(h)))
    prev = (x, y)
    lant = L.LANTERN_E_C
    for _ in range(int(seconds / STEP)):
        sp.step(STEP)
        p = (b.position.x, b.position.y)
        if near_path(prev, p, L.WELL_HOLE, L.WELL_CAPTURE_R):
            return "well"
        if near_path(prev, p, L.LOG_HOLE, 18):
            return "log"
        if p[0] < L.ORBIT_INNER_X and prev[1] < L.SPINNER_Y <= p[1]:
            return "orbit"
        if L.TREANT_L_X < p[0] < L.TREANT_R_X and p[1] > L.BARK_Y - L.BALL_R - 1:
            return "bark"
        if (L.RAMP_C_X - L.RAMP_MOUTH_HALF < p[0] < L.RAMP_C_X + L.RAMP_MOUTH_HALF
                and prev[1] < L.RAMP_MOUTH_Y + 12 <= p[1]):
            return "oldRoad"
        if math.dist(p, lant) < L.BALL_R + 14:
            return "eastLantern"
        if p[1] < 150:
            return "drain"
        prev = p
    return "none"

def trials(path, flipper="right", fast=True):
    d = json.load(open(path))
    out = []
    for t in d["trials"]:
        if t["flipper"] != flipper or (fast and t["physicsStepMs"] > 8.8) or not t.get("launch"):
            continue
        out.append(t)
    return sorted(out, key=lambda t: t["actualDelay"])

if __name__ == "__main__":
    path = sys.argv[1]
    flipper = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("-") else "right"
    rows = trials(path, flipper)
    agree = tally = 0
    counts = {}
    seen = set()
    for t in rows:
        key = round(t["actualDelay"], 3)
        if key in seen:
            continue
        seen.add(key)
        x, y, hd, spd = t["launch"]
        got = replay(x, y, hd, spd)
        counts[got] = counts.get(got, 0) + 1
        lab = t["outcome"]
        if "--compare" in sys.argv:
            ok = got == lab or (lab in ("none", "drain") and got in ("none", "drain"))
            agree += ok; tally += 1
            print(f"{t['actualDelay']:.3f} launch {hd:6.1f} {spd:5.0f}  lab {lab:<11} sim {got:<11} {'' if ok else '<-'}")
    print(flipper, "frames:", dict(sorted(counts.items(), key=lambda kv: -kv[1])))
    if tally:
        print(f"agreement {agree}/{tally}")
