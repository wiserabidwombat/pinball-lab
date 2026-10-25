#!/usr/bin/env python3
"""Pinball Lab · merge several Play Lab reports of ONE table into one JSON (plan 2, round 2).

    python3 tools/playlab_merge.py --out ShotLab/playlab-monsoon-<stamp>-sweep.json a.json b.json …

The games are concatenated (so every per-cell number in playlab_report.py is computed over all of them, with tighter
bands); the objectives and flippers come from the first report; fps is the game-weighted mean; the build is the first
report's, with a note when the parts were built differently (then the merge is only as comparable as its parts).
Screenshot file names are rewritten as ../<part stem>/<file>, so the merged page (whose own folder doesn't exist) still
shows every picture. Pure Python, no dependencies.
"""
import argparse, json, os, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("reports", nargs="+")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    parts = []
    for p in args.reports:
        with open(p, encoding="utf-8") as f:
            parts.append((p, json.load(f)))
    first = parts[0][1]
    tables = {d["table"] for _, d in parts}
    if len(tables) > 1:
        sys.exit(f"these reports are of different tables: {', '.join(sorted(tables))}")
    out = {k: v for k, v in first.items() if k != "games"}
    games = []
    for p, d in parts:
        stem = os.path.splitext(os.path.basename(p))[0]
        for g in d.get("games", []):
            g = dict(g)
            if g.get("captures"):
                g["captures"] = [dict(c, file=f"../{stem}/{c['file']}") for c in g["captures"]]
            games.append(g)
    out["games"] = games
    n = sum(len(d.get("games", [])) for _, d in parts)
    out["fps"] = round(sum(d.get("fps", 0) * len(d.get("games", [])) for _, d in parts) / n, 1) if n else 0
    cells = {}
    for g in games:
        cells[(g.get("pass", "hz120"), g["skill"])] = cells.get((g.get("pass", "hz120"), g["skill"]), 0) + 1
    out["gamesPerSkill"] = max(cells.values()) if cells else 0
    keys = []
    for _, d in parts:
        b = d.get("build") or {}
        k = b.get("id") or b.get("builtAt") or "unknown"
        if k not in keys:
            keys.append(k)
    if len(keys) > 1:
        b = dict(first.get("build") or {})
        b["id"] = (b.get("id") or "unknown") + f" · MERGED FROM {len(keys)} DIFFERENT BUILDS: " + " / ".join(keys)
        out["build"] = b
    out["mergedFrom"] = [os.path.basename(p) for p, _ in parts]
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f)
    print(f"merged {len(parts)} reports, {n} games → {args.out}" + (" (DIFFERENT BUILDS)" if len(keys) > 1 else ""))


if __name__ == "__main__":
    main()
