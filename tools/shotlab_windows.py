#!/usr/bin/env python3
"""Shot Lab windows: for each pass (physics step) and flipper, the bands of flip delays that made each shot, and the
middle of each band — the numbers a Play Lab host puts in PlayRobotFlipper.shots (120 Hz) and shots60 (60 Hz).

    python3 tools/shotlab_windows.py ShotLab/shotlab-the-lamplight-2026-10-17T02-41-51Z.json [--shot fireplace]
    python3 tools/shotlab_windows.py ShotLab/shotlab-….json --map map.svg [--art table.png --art-rect -40 -75 680 1405]

Plan 2 round 17, `--map`: a window map — per pass and flipper, one ray per trial from where the ball was at the flip
through its first 60 pt off the flipper, out to the table edge, coloured by outcome (needs a Shot Lab run made after
round 17: the trials carry `flipPoint` and `launch`).
"""
import collections
import html
import json
import sys

MAP_COLORS = {"none": "#5c5c5c", "drain": "#d1403a", "launched": "#e0a63a", "cradled": "#7fd17f", "pass": "#c08cff"}
MAP_PALETTE = ["#4fc3f7", "#ffd54f", "#81c784", "#ff8a65", "#ba68c8", "#4db6ac", "#f06292", "#aed581", "#9575cd",
               "#ffb74d", "#64b5f6", "#e57373"]
TABLE_W, TABLE_H = 600, 1300


def ray_end(x0, y0, x1, y1):
    """The point where the line from (x0, y0) through (x1, y1) leaves the 600 x 1300 table (or (x1, y1) if it doesn't move)."""
    dx, dy = x1 - x0, y1 - y0
    if abs(dx) < 1e-6 and abs(dy) < 1e-6:
        return x1, y1
    ts = []
    for edge, d0, dd in ((0, x0, dx), (TABLE_W, x0, dx), (0, y0, dy), (TABLE_H, y0, dy)):
        if abs(dd) > 1e-9:
            t = (edge - d0) / dd
            if t > 0:
                ts.append(t)
    t = min(ts) if ts else 1
    return x0 + dx * t, y0 + dy * t


def window_map(d, out_path, art=None, rect=(-40, -75, 680, 1405)):
    X, Y, W, H = rect
    trials = [t for t in d["trials"] if t.get("launch") and t.get("flipPoint") and t["outcome"] != "invalid"]
    if not trials:
        print("No trials with a launch line: this JSON is from before round 17 (run the Shot Lab again).")
        return False
    passes = [(lbl, lo, hi) for lbl, lo, hi in (("120 Hz", 0, 12), ("60 Hz", 12, 99))
              if any(lo <= t["physicsStepMs"] < hi for t in trials)]
    order = ["left", "right", "upper", "loft"]
    flippers = sorted({t["flipper"] for t in trials}, key=lambda f: order.index(f) if f in order else 9)
    shots = sorted({t["outcome"] for t in trials} - set(MAP_COLORS))
    color = dict(MAP_COLORS)
    for i, s in enumerate(shots):
        color[s] = MAP_PALETTE[i % len(MAP_PALETTE)]
    gap, head = 50, 120
    vw, vh = len(flippers) * (W + gap), len(passes) * (H + head)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {vw} {vh}" '
           f'font-family="Helvetica, Arial" font-size="22" style="background:#000">']
    for r, (lbl, lo, hi) in enumerate(passes):
        for c, fl in enumerate(flippers):
            tt = sorted([t for t in trials if t["flipper"] == fl and lo <= t["physicsStepMs"] < hi], key=lambda t: t["plannedDelay"])
            if not tt:
                continue
            ox, oy = c * (W + gap), r * (H + head)
            sx = lambda x: x - X
            sy = lambda y: head + (Y + H - y)
            out.append(f'<g transform="translate({ox},{oy})">')
            out.append(f'<rect x="0" y="{head}" width="{W}" height="{H}" fill="#101010"/>')
            if art:
                out.append(f'<image xlink:href="{html.escape(art)}" x="0" y="{head}" width="{W}" height="{H}" opacity="0.7"/>')
            out.append(f'<rect x="{sx(0)}" y="{sy(TABLE_H)}" width="{TABLE_W}" height="{TABLE_H}" fill="none" stroke="#555" stroke-width="2"/>')
            n = collections.Counter(t["outcome"] for t in tt)
            out.append(f'<text x="8" y="30" fill="#ddd" font-size="26">{html.escape(d["table"])} · {lbl} · {fl} flipper · {len(tt)} trials</text>')
            lx, ly = 8, 62
            for o, k in n.most_common():
                label = f"{o} {k}"
                if lx + 18 + 13 * len(label) > W:
                    lx, ly = 8, ly + 28
                out.append(f'<rect x="{lx}" y="{ly - 16}" width="14" height="14" fill="{color.get(o, "#888")}"/>'
                           f'<text x="{lx + 18}" y="{ly - 3}" fill="#ccc">{html.escape(label)}</text>')
                lx += 30 + 13 * len(label)
            # misses first, so the made shots draw on top
            for t in sorted(tt, key=lambda t: t["outcome"] in ("none", "drain")) [::-1]:
                fx, fy = t["flipPoint"]
                lx1, ly1 = t["launch"][0], t["launch"][1]
                ex, ey = ray_end(fx, fy, lx1, ly1)
                o = t["outcome"]
                w = 1.5 if o in ("none",) else 2.5
                op = 0.35 if o in ("none",) else 0.8
                out.append(f'<line x1="{sx(fx):.1f}" y1="{sy(fy):.1f}" x2="{sx(ex):.1f}" y2="{sy(ey):.1f}" stroke="{color.get(o, "#888")}" '
                           f'stroke-width="{w}" stroke-opacity="{op}"><title>{fl} · delay {t["plannedDelay"]:.3f} s · '
                           f'{t.get("flipAlong", 0):.1f} pt along · {o}</title></line>')
            out.append("</g>")
    out.append("</svg>")
    open(out_path, "w").write("\n".join(out))
    print(f"wrote {out_path} ({len(trials)} rays)")
    return True


def bands(trials):
    """[(first delay, last delay, outcome, trials)] — consecutive planned delays with the same outcome."""
    by = collections.defaultdict(list)
    for t in trials:
        by[round(t["plannedDelay"], 3)].append(t["outcome"])
    out = []
    for delay, outcomes in sorted(by.items()):
        o = "/".join(sorted(set(outcomes)))
        if out and out[-1][2] == o:
            out[-1][1] = delay
            out[-1][3] += len(outcomes)
        else:
            out.append([delay, delay, o, len(outcomes)])
    # A single stray "none" inside a band (frame jitter) doesn't split it.
    merged = []
    for b in out:
        if len(merged) >= 2 and merged[-1][2] in ("none", "invalid") and merged[-1][3] <= 1 and merged[-2][2] == b[2]:
            merged.pop()
            merged[-1][1] = b[1]
            merged[-1][3] += b[3]
        else:
            merged.append(b)
    return merged


def main():
    argv = sys.argv[1:]
    def opt(name, n=1):
        if name not in argv:
            return None
        i = argv.index(name)
        vals = argv[i + 1:i + 1 + n]
        del argv[i:i + 1 + n]
        return vals if n > 1 else vals[0]
    only = opt("--shot")
    map_out = opt("--map")
    art = opt("--art")
    rect = opt("--art-rect", 4)
    args = [a for a in argv if not a.startswith("--")]
    d = json.load(open(args[0]))
    if d.get("overrides"):          # plan 2 round 18: a what-if run
        print("OVERRIDES " + ", ".join(f"{k}={v:g}" for k, v in sorted(d["overrides"].items())))
    if map_out:
        window_map(d, map_out, art, tuple(float(v) for v in rect) if rect else (-40, -75, 680, 1405))
        return
    trials = d["trials"]
    start = d.get("start", "cradle")       # round 15: cradle | inlane | drop (delays count from the release for the moving starts)
    print(f"{d['table']} · {d['date']} · {len(trials)} trials · step {d['delayStep'] * 1000:.0f} ms · {d['fps']} fps · start: {start}")
    for label, lo, hi in (("120 Hz", 0, 12), ("60 Hz", 12, 99)):
        pass_trials = [t for t in trials if lo <= t["physicsStepMs"] < hi]
        if not pass_trials:
            continue
        print(f"\n== {label} pass ({min(t['physicsStepMs'] for t in pass_trials):.1f}–{max(t['physicsStepMs'] for t in pass_trials):.1f} ms steps)")
        for fl in sorted({t["flipper"] for t in pass_trials}, key=lambda f: ["left", "right", "upper", "loft"].index(f) if f in ("left", "right", "upper", "loft") else 9):
            tt = [t for t in pass_trials if t["flipper"] == fl]
            if not tt:
                continue
            print(f"  {fl}:")
            mids = collections.defaultdict(list)
            for a, b, o, n in bands(tt):
                if o in ("none", "invalid") or (only and o != only):
                    continue
                print(f"    {a:.3f}–{b:.3f}  {o:14} ({n} trials)")
                if "/" not in o and o != "drain":
                    mids[o].append((n, (a + b) / 2, b - a))
            if mids:
                best = {k: max(v)[1] for k, v in mids.items()}   # the widest band's middle
                print("    → delays: " + ", ".join(f'("{k}", {v:.3f})' for k, v in sorted(best.items(), key=lambda kv: kv[1])))


if __name__ == "__main__":
    main()
