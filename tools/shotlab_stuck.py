#!/usr/bin/env python3
"""The stuck-ball finder's report: where balls dropped all over a table come to rest and stay.

    python3 tools/shotlab_stuck.py ShotLab/shotlab-monsoon-scatter-2026-11-17T23-00-00Z.json
    python3 tools/shotlab_stuck.py <scatter results> --svg map.svg       # the map somewhere else (default: <stem>.svg)
    python3 tools/shotlab_stuck.py <scatter results> --replays 0          # don't read Play Lab replays

Reads a Shot Lab run with `-shotlab-start scatter` (tools/shotlab_run.sh TABLE "" "" scatter): balls dropped at random
points with random velocities, flippers at rest. A ball that sat still 4 s got one flip of every flipper; `stuck` =
still there 2 s later. `flipFreed` rests were moved by that flip (a ball that waits for the player — usually fine
near a flipper, worth a look elsewhere). Stuck spots within 15 pt are grouped.

Each group is checked against the table's Play Lab replays (the newest few playlab-<table>-*.json in the same
folder): how many replay frames had a ball within 15 pt. A trap real balls reach ("seen in play") matters; one no
replay ball ever came near was probably a drop inside a wall or outside the table ("not seen in play"). The scoop or
lock a ball sat in shows in its last events. The map draws the groups over the table's art (red = stuck, orange =
freed by a flip; the bigger, the more drops ended there).
"""
import collections
import glob
import html
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RADIUS = 15.0


def slug_of(table):
    base = table.split(" (")[0]
    return "".join(c if c.isalnum() else "-" for c in base.lower())


def group(points):
    """Greedy clusters: each point joins the first group whose centre is within RADIUS."""
    groups = []
    for p in points:
        for g in groups:
            if math.hypot(p["x"] - g["x"], p["y"] - g["y"]) < RADIUS:
                g["items"].append(p)
                n = len(g["items"])
                g["x"] += (p["x"] - g["x"]) / n
                g["y"] += (p["y"] - g["y"]) / n
                break
        else:
            groups.append({"x": p["x"], "y": p["y"], "items": [p]})
    return sorted(groups, key=lambda g: -len(g["items"]))


def replay_grid(folder, slug, limit):
    """Floor-ball positions from the newest Play Lab reports of this table, binned on a 5 pt grid."""
    paths = sorted(glob.glob(os.path.join(folder, f"playlab-{slug}-*.json")), reverse=True)
    paths = [p for p in paths if not p.endswith("-sweep.json")][:limit]
    grid = collections.Counter()
    used = []
    for p in paths:
        try:
            d = json.load(open(p))
        except Exception:
            continue
        frames = 0
        for g in d.get("games", []):
            for fr in (g.get("replay") or "").split(";"):
                v = fr.split(",")
                for j in range(2, len(v) - 2, 3):
                    try:
                        x, y, up = float(v[j]), float(v[j + 1]), v[j + 2]
                    except ValueError:
                        continue
                    if up == "0":
                        grid[(int(x // 5), int(y // 5))] += 1
                        frames += 1
        if frames:
            used.append(os.path.basename(p))
    return grid, used


def seen(grid, x, y):
    r = int(RADIUS // 5) + 1
    cx, cy = int(x // 5), int(y // 5)
    return sum(n for (gx, gy), n in ((k, grid[k]) for k in ((cx + i, cy + j) for i in range(-r, r + 1)
                                                                for j in range(-r, r + 1)))
               if math.hypot(gx * 5 + 2.5 - x, gy * 5 + 2.5 - y) <= RADIUS)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    path = argv[0]
    svg_out = argv[argv.index("--svg") + 1] if "--svg" in argv else os.path.splitext(path)[0] + ".svg"
    limit = int(argv[argv.index("--replays") + 1]) if "--replays" in argv else 4
    d = json.load(open(path))
    trials = [t for t in d.get("trials", []) if t.get("start") == "scatter" or d.get("start") == "scatter"]
    if not trials:
        sys.exit(f"{path}: no scatter trials (run with -shotlab-start scatter)")
    rate = lambda t: "120 Hz" if t.get("physicsStepMs", 8.3) < 12 else "60 Hz"
    print(f"{d['table']} · {d['date']} · {len(trials)} drops · {d.get('fps')} fps · stuck-ball finder")
    for p in ("120 Hz", "60 Hz"):
        c = collections.Counter(t["outcome"] for t in trials if rate(t) == p)
        freed = sum(1 for t in trials if rate(t) == p and t.get("flipFreed"))
        if c:
            print(f"  {p}: " + ", ".join(f"{k} {n}" for k, n in c.most_common()) + f" · rested until a flip {freed}")

    def items(pred):
        out = []
        for t in trials:
            if pred(t) and t.get("rest"):
                dx = t["drop"][0] - t["rest"][0] if t.get("drop") else 0
                dy = t["drop"][1] - t["rest"][1] if t.get("drop") else 0
                out.append({"x": t["rest"][0], "y": t["rest"][1], "rate": rate(t), "travel": math.hypot(dx, dy),
                            "events": t.get("events", []), "drop": t.get("drop")})
        return out

    stuck = group(items(lambda t: t["outcome"] == "stuck"))
    freed = group(items(lambda t: t.get("flipFreed") and t["outcome"] != "stuck"))
    moving = group(items(lambda t: t["outcome"] == "moving"))
    grid, used = ({}, []) if limit == 0 else replay_grid(os.path.dirname(os.path.abspath(path)), slug_of(d["table"]), limit)
    if limit:
        print(f"  replays: {', '.join(used) if used else 'none found for this table — reachability unknown'}")

    def describe(title, groups):
        if not groups:
            print(f"\n{title}: none")
            return
        print(f"\n{title}:")
        for g in groups:
            n = len(g["items"])
            rates = collections.Counter(i["rate"] for i in g["items"])
            last = collections.Counter(i["events"][-1] for i in g["items"] if i["events"])
            near = seen(grid, g["x"], g["y"]) if used else None
            reach = ("" if near is None else f" · seen in play ({near} frames)" if near
                     else " · not seen in play (inside a wall / outside the table?)")
            travel = max(i["travel"] for i in g["items"])
            print(f"  ({g['x']:.0f}, {g['y']:.0f})  {n} drop(s) · " + ", ".join(f"{r} {k}" for r, k in rates.items())
                  + f" · came from up to {travel:.0f} pt away" + reach
                  + (f" · last hit: {last.most_common(1)[0][0]}" if last else ""))
            g["near"] = near

    describe("STUCK (still after a flip of every flipper)", stuck)
    describe("Rested until a flip freed it", freed)
    describe("Still moving after 20 s", moving)
    write_svg(d, stuck, freed, svg_out)
    print(f"\nMap: {svg_out}")
    return 0


def write_svg(d, stuck, freed, out):
    X, Y, W, H = -40, -75, 680, 1405
    sx = lambda x: x - X
    sy = lambda y: Y + H - y
    art = ""
    try:
        sys.path.insert(0, HERE)
        import playlab_report as pr
        for p, (rx, ry, rw, rh) in pr.table_art(d["table"].split(" (")[0], os.path.dirname(os.path.abspath(out))):
            art += (f"<image href='{html.escape(p)}' x='{rx - X}' y='{Y + H - (ry + rh)}' width='{rw}' height='{rh}' "
                    f"preserveAspectRatio='none' opacity='0.6'/>")
    except Exception:
        pass
    if not art:
        art = f"<rect x='{sx(0)}' y='{sy(1300)}' width='600' height='1300' fill='none' stroke='#666' stroke-width='2'/>"
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {W} {H + 60}' width='{W // 2}' height='{(H + 60) // 2}' "
         f"style='background:#111'>", art]
    for groups, color in ((freed, "#ffa726"), (stuck, "#ff1744")):
        for g in groups:
            n = len(g["items"])
            r = 10 + 4 * math.sqrt(n)
            tip = html.escape(f"({g['x']:.0f}, {g['y']:.0f}) · {n} drop(s)")
            s.append(f"<circle cx='{sx(g['x']):.0f}' cy='{sy(g['y']):.0f}' r='{r:.0f}' fill='{color}' fill-opacity='0.35' "
                     f"stroke='{color}' stroke-width='3'><title>{tip}</title></circle>")
            if color == "#ff1744":
                s.append(f"<text x='{sx(g['x']) + r + 4:.0f}' y='{sy(g['y']) + 6:.0f}' fill='#fff' font-size='22' "
                         f"font-family='monospace'>{n}</text>")
    s.append(f"<text x='20' y='{H + 40}' fill='#ddd' font-size='22' font-family='monospace'>"
             f"{html.escape(d['table'])} · red stuck · orange freed by a flip</text></svg>")
    open(out, "w").write("".join(s))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
