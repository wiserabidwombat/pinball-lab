#!/usr/bin/env python3
"""Shot Lab windows: for each pass (physics step) and flipper, the bands of flip delays that made each shot, and the
middle of each band — the numbers a Play Lab host puts in PlayRobotFlipper.shots (120 Hz) and shots60 (60 Hz).

    python3 tools/shotlab_windows.py ShotLab/shotlab-the-lamplight-2026-10-17T02-41-51Z.json [--shot fireplace]
"""
import collections
import json
import sys


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
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = sys.argv[sys.argv.index("--shot") + 1] if "--shot" in sys.argv else None
    d = json.load(open(args[0]))
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
