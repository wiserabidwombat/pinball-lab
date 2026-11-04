#!/usr/bin/env python3
"""Pinball Lab · the robots' hall of fame (Play Lab plan 2, round 23).

The best robot game per table and skill, kept in GreyInvasionPinball/HallOfFame/halloffame.json (bundled in the app;
the Lab card's "How it evolved" page shows it), with the table's top game's last screenshot as hof-<table>.jpg.
Each run only replaces an entry with a higher score, so the sweep can call it after every run.

    python3 tools/playlab_halloffame.py                       # every Play Lab report in ShotLab/
    python3 tools/playlab_halloffame.py --since 2026-10-28    # only reports from that date/time on (the sweep passes its stamp)
    python3 tools/playlab_halloffame.py ShotLab/playlab-….json …

Merged sweep reports (…-sweep.json) are skipped: their games are in the runs they were merged from, which also hold
the screenshots. "you" games (Record me) are left out.
"""
import glob
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "GreyInvasionPinball", "HallOfFame")
OUT = os.path.join(OUT_DIR, "halloffame.json")
SKILLS = ["beginner", "intermediate", "advanced", "expert"]
# The lab screenshots carry the debug build tag (fps, build, PLAY LAB line) in the bottom ~6 % of the frame; the
# picture ships in the app, so that strip is cropped off (2026-11-02, table agent). Keep 92.5 % of the height.
KEEP_HEIGHT = 0.925


def slug(table):
    return "".join(c for c in table.lower() if c.isalnum())


def norm_stamp(s):
    """'2026-11-01T00-09-23Z' or '2026-11-01T00:09:23Z' or '2026-10-28' → comparable '2026-11-01T00:09:23'."""
    if "T" in s:
        day, t = s.split("T", 1)
        return day + "T" + t.replace("-", ":").rstrip("Z")
    return s


def picture_for(report_path, game):
    """The game's last screenshot (gameEnd if it has one) as a path, or None."""
    caps = game.get("captures") or []
    if not caps:
        return None
    pick = next((c for c in caps if c.get("reason") == "gameEnd"), caps[-1])
    p = os.path.join(os.path.splitext(report_path)[0], pick.get("file", ""))
    return p if os.path.isfile(p) else None


def crop_debug_strip(path):
    """Crop the bottom (1 - KEEP_HEIGHT) of the picture, where the lab's debug tag sits. PIL if present, else sips."""
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB")
        w, h = im.size
        im.crop((0, 0, w, round(h * KEEP_HEIGHT))).save(path, quality=85)
        return
    except ImportError:
        pass
    if shutil.which("sips"):
        out = subprocess.run(["sips", "-g", "pixelHeight", "-g", "pixelWidth", path],
                             capture_output=True, text=True).stdout
        dims = {k.strip(): int(v) for k, v in (ln.rsplit(":", 1) for ln in out.splitlines()[1:] if ":" in ln)}
        h, w = dims.get("pixelHeight", 0), dims.get("pixelWidth", 0)
        if h and w:
            r = subprocess.run(["sips", "--cropToHeightWidth", str(round(h * KEEP_HEIGHT)), str(w),
                                "--cropOffset", "0", "0", path], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            if r.returncode == 0:
                return
            print("  sips crop failed:", r.stderr.strip()[:200])
    print(f"  warning: couldn't crop the debug strip off {os.path.basename(path)} (no PIL or sips)")


def main():
    argv = sys.argv[1:]
    since = None
    if "--since" in argv:
        i = argv.index("--since")
        since = norm_stamp(argv[i + 1])
        del argv[i:i + 2]
    paths = argv or sorted(glob.glob(os.path.join(ROOT, "ShotLab", "playlab-*.json")))
    paths = [p for p in paths if not p.endswith("-sweep.json")]
    hall = {"updated": "", "tables": {}}
    if os.path.isfile(OUT):
        hall = json.load(open(OUT))
    tables = hall.setdefault("tables", {})
    changed = {}
    for p in paths:
        try:
            d = json.load(open(p))
        except Exception:
            continue
        if since and norm_stamp(d.get("date", "")) < since:
            continue
        table = d.get("table", "")
        if not table or "(" in table:          # a scenario/what-if variant, not the table as played
            continue
        if (d.get("build") or {}).get("overrides"):
            continue
        for g in d.get("games", []):
            skill = g.get("skill")
            if skill not in SKILLS:
                continue
            entries = tables.setdefault(table, {})
            old = entries.get(skill)
            if old and old["score"] >= g.get("score", 0):
                continue
            entries[skill] = {"score": g.get("score", 0), "date": d.get("date", "")[:10], "pass": g.get("pass", ""),
                              "minutes": round(g.get("seconds", 0) / 60, 1), "report": os.path.basename(p),
                              "game": d["games"].index(g) + 1, "_picture": picture_for(p, g)}
            changed[(table, skill)] = g.get("score", 0)
    os.makedirs(OUT_DIR, exist_ok=True)
    # One picture per table: its top game's (keeps the app small).
    for table, entries in tables.items():
        top = max(entries.values(), key=lambda e: e["score"])
        src = top.pop("_picture", None)
        for e in entries.values():
            e.pop("_picture", None)
        if src:
            dst = os.path.join(OUT_DIR, f"hof-{slug(table)}.jpg")
            shutil.copyfile(src, dst)
            if shutil.which("sips"):
                subprocess.run(["sips", "-Z", "700", dst], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            crop_debug_strip(dst)
            for e in entries.values():
                e["picture"] = None
            top["picture"] = os.path.basename(dst)
    if changed:
        from datetime import datetime, timezone
        hall["updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    with open(OUT + ".tmp", "w") as f:
        json.dump(hall, f, indent=1, sort_keys=True)
    os.replace(OUT + ".tmp", OUT)
    print(f"Hall of fame: {len(changed)} new best game(s)"
          + ("" if not changed else ": " + "; ".join(f"{t} {s} {v:,}" for (t, s), v in sorted(changed.items()))))
    for table in sorted(tables):
        row = "  ".join(f"{s[:3]} {tables[table][s]['score']:>11,}" for s in SKILLS if s in tables[table])
        print(f"  {table:16} {row}")


if __name__ == "__main__":
    main()
