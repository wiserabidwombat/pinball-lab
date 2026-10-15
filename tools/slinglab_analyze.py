#!/usr/bin/env python3
"""Pinball Lab Table 03, milestone 5 round 2: reads a Sling Lab results file and compares the sling designs.

    python3 slinglab_analyze.py slinglab-cthulhu-rising-<date>.json

For each design: where every thrown ball ended up (flipper = saveable; outlane, centre drain, back up the
table, timeout), the same for only the balls a sling kicked, how many kicks a ball took, and where along the
rubber the kicks landed (0 = tip post, 1 = top post). Lost = outlane + centre drain.
"""
import json
import sys
from collections import Counter, defaultdict

OUTCOMES = ["flipper", "upfield", "outlaneLeft", "outlaneRight", "drain", "timeout"]


def pct(n, d):
    return f"{100 * n / d:5.1f}%" if d else "    -"


def table(rows, title):
    print(f"\n{title}")
    print(f"  {'design':<14}{'balls':>6}  " + "".join(f"{o[:9]:>10}" for o in OUTCOMES) + f"{'LOST':>9}")
    for name, trials in rows:
        c = Counter(t["outcome"] for t in trials)
        n = len(trials)
        lost = c["outlaneLeft"] + c["outlaneRight"] + c["drain"]
        print(f"  {name:<14}{n:>6}  " + "".join(f"{pct(c[o], n):>10}" for o in OUTCOMES) + f"{pct(lost, n):>9}")


def main(path):
    r = json.load(open(path))
    launches = r["launches"]
    names = [v["name"] for v in r["variants"]]
    by = defaultdict(list)
    for t in r["trials"]:
        by[t["variant"]].append(t)
    print(f"{r['table']} · {r['date']} · {len(r['trials'])} trials · {r['fps']} fps · physics speed {r['physicsSpeed']}")
    for v in r["variants"]:
        print(f"  {v['name']:<14} kick {r['kickDegrees'][v['name']]:5.1f}° above horizontal · rubber "
              f"{v['kickFrom']:.2f}–{v['kickTo']:.2f} · rotate {v['rotate']:+.0f}°")

    table([(n, by[n]) for n in names], "All balls")
    for fam in ["drop", "flipper"]:
        table([(n, [t for t in by[n] if launches[t["launch"]]["family"] == fam]) for n in names],
              f"Family '{fam}'")
    table([(n, [t for t in by[n] if t["kicks"]]) for n in names], "Only balls a sling kicked")

    print("\nKicks per ball (kicked balls) and where on the rubber the first kick landed")
    for n in names:
        kicked = [t for t in by[n] if t["kicks"]]
        if not kicked:
            continue
        counts = Counter(min(len(t["kicks"]), 4) for t in kicked)
        firsts = [t["kicks"][0]["along"] for t in kicked]
        bins = Counter(min(int(f * 5), 4) for f in firsts if 0 <= f <= 1)
        print(f"  {n:<14} 1:{counts[1]:>3} 2:{counts[2]:>3} 3:{counts[3]:>3} 4+:{counts[4]:>3}   "
              f"mean {sum(len(t['kicks']) for t in kicked) / len(kicked):.2f}   first kick along "
              + " ".join(f"{i * 20}-{i * 20 + 20}%:{bins[i]}" for i in range(5)))

    # Outlane losses by where the last kick hit (which part of the rubber feeds the outlanes)
    print("\nOutlane losses after a kick, by where the LAST kick hit (0 = tip, 1 = top)")
    for n in names:
        lost = [t for t in by[n] if t["kicks"] and t["outcome"].startswith("outlane")]
        bins = Counter(min(int(t["kicks"][-1]["along"] * 5), 4) for t in lost)
        same = sum(1 for t in lost if t["kicks"][-1]["sling"] == ("left" if t["outcome"] == "outlaneLeft" else "right"))
        print(f"  {n:<14} {len(lost):>3} lost · same-side sling {same}, cross-table {len(lost) - same} · "
              + " ".join(f"{i * 20}-{i * 20 + 20}%:{bins[i]}" for i in range(5)))

    # Paired: the same ball under each design vs 'current'
    base = {t["launch"]: t for t in by[names[0]]}
    print(f"\nSame ball, compared with '{names[0]}' (saved = flipper or upfield)")
    for n in names[1:]:
        better = worse = 0
        for t in by[n]:
            b = base.get(t["launch"])
            if not b:
                continue
            s0 = b["outcome"] in ("flipper", "upfield")
            s1 = t["outcome"] in ("flipper", "upfield")
            better += s1 and not s0
            worse += s0 and not s1
        print(f"  {n:<14} saved {better} balls '{names[0]}' lost · lost {worse} it saved")


if __name__ == "__main__":
    main(sys.argv[1])
