#!/usr/bin/env python3
"""Pinball Lab · one-command table health check (macOS, Simulator). Runs three quick labs on a table with fast-forward
and compares them with the table's last accepted results, then prints a pass / warn / fail list:

  1. the stuck-ball finder (Shot Lab `scatter`, DROPS drops)      → any stuck spot that wasn't there before = FAIL
  2. the Shot Lab's cradle sweep (every flipper)                  → a shot that vanished = FAIL, one that moved = WARN
  3. a few Play Lab games per skill                               → a watchdog incident = FAIL, a changed drain rate = WARN

    tools/lab_health.py chomp                 # check against tools/lab_accepted/chomp.json
    tools/lab_health.py chomp --accept        # run, then save this run as the accepted results
    tools/lab_health.py chomp --only stuck,windows
    tools/lab_health.py --compare A.json B.json    # compare two saved summaries, no run

Environment: FAST (default 8), DROPS (80), GAMES (2 per skill), DEVICE, DERIVED, SKIP_BUILD — as the runners take them.
Every run's summary is kept in ShotLab/health-<table>-<stamp>.json; the accepted one lives in tools/lab_accepted/
(in git, so it moves with the project). Exit code 1 if anything failed.
"""
import argparse, collections, glob, json, math, os, statistics, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import playlab_report as R  # noqa: E402

ACCEPTED = os.path.join(ROOT, "tools", "lab_accepted")
SKILLS = ["beginner", "intermediate", "advanced", "expert"]
# The file-name slug of each runner name (others are their own slug): only this table's results are read, since other
# sessions may be running other tables' labs at the same time.
SLUGS = {"greyinvasion": "grey-invasion", "cthulhu": "cthulhu-rising", "lamplight": "the-lamplight", "grandtour": "grand-tour"}


# ---------------------------------------------------------------- running the labs

def run(cmd, env):
    """Runs a runner script, echoing its lines; returns its output."""
    print("  $ " + " ".join(cmd), flush=True)
    p = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out = []
    for line in p.stdout:
        out.append(line)
        if line.startswith("▶") or "Build failed" in line or "error:" in line:
            print("    " + line.rstrip(), flush=True)
    p.wait()
    return "".join(out)


def newest(pattern, since, want=lambda d: True):
    """The newest file matching `pattern` written after `since` whose JSON passes `want`."""
    files = [f for f in glob.glob(os.path.join(ROOT, "ShotLab", pattern)) if os.path.getmtime(f) >= since]
    for f in sorted(files, key=os.path.getmtime, reverse=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if want(d):
            return f, d
    return None, None


# ---------------------------------------------------------------- summaries

def stuck_summary(d):
    trials = d.get("trials", [])
    out = collections.Counter(t.get("outcome", "?") for t in trials)
    spots = []
    for t in trials:
        if t.get("outcome") == "stuck" and t.get("rest"):
            x, y = t["rest"][:2]
            # How far the ball travelled from its drop: a ball that stuck a few points from where it was dropped was
            # most likely dropped inside a part; one that came from far away found a real trap.
            far = round(math.hypot(x - t["drop"][0], y - t["drop"][1])) if len(t.get("drop", [])) >= 2 else 999
            for s in spots:
                if abs(s[0] - x) < 15 and abs(s[1] - y) < 15:
                    s[2] += 1
                    s[3] = max(s[3], far)
                    break
            else:
                spots.append([round(x), round(y), 1, far])
    return dict(drops=len(trials), stuck=out.get("stuck", 0), moving=out.get("moving", 0),
                freed=sum(1 for t in trials if t.get("flipFreed")), spots=sorted(spots, key=lambda s: -s[2]))


def windows_summary(d):
    by = collections.defaultdict(list)
    for t in d.get("trials", []):
        o = t.get("outcome")
        if o and o not in ("none", "drain"):
            by[(t.get("flipper", "?"), o)].append(t.get("actualDelay", t.get("plannedDelay", 0)))
    res = collections.defaultdict(dict)
    for (fl, shot), ds in by.items():
        res[fl][shot] = dict(trials=len(ds), mid=round(statistics.median(ds), 3), lo=round(min(ds), 3), hi=round(max(ds), 3))
    drains = collections.Counter(t.get("flipper", "?") for t in d.get("trials", []) if t.get("outcome") == "drain")
    return dict(trials=len(d.get("trials", [])), shots=res, drains=dict(drains))


def play_summary(d):
    R.SKILLS[:] = list(SKILLS)
    a = R.analyze(d)
    games = [g for g in d["games"] if g["skill"] in SKILLS]
    rate, lo, hi = R.rate_band(games)
    skills = {}
    balls = {r["skill"]: r for r in a["ball_rows"]}
    for r in a["drain_rows"]:
        k = r["skill"]
        gs = [g for g in games if g["skill"] == k]
        skills[k] = dict(games=len(gs), drains_per_min=round(r["per_min"], 2), lo=round(r["per_min_lo"], 2),
                         hi=round(r["per_min_hi"], 2), seconds_per_ball=round(balls[k]["median"]) if k in balls else None,
                         verdict=balls[k]["verdict"] if k in balls else "", median_score=statistics.median(g["score"] for g in gs))
    reached = sorted({n for g in games if g["skill"] in ("advanced", "expert") for n in g.get("objectives", {})})
    return dict(games=len(games), drains_per_min=round(rate, 2), lo=round(lo, 2), hi=round(hi, 2), skills=skills,
                incidents=[dict(kind=i["kind"], x=round(i["x"]), y=round(i["y"]), skill=s) for _, s, i in a["incidents"]],
                objectives=[o["name"] for o in a["objectives"]] or a["names"], reached=reached, flags=a["flags"])


# ---------------------------------------------------------------- the comparison

FAR = 100   # pt: a stuck ball that travelled at least this far from its drop found a real trap


def far_of(sp):
    return sp[3] if len(sp) > 3 else 999


def spot_text(sp):
    return f"({sp[0]}, {sp[1]}) ×{sp[2]}" + (f" from up to {sp[3]} pt away" if len(sp) > 3 and sp[3] != 999 else "")


def compare(now, old):
    """[(level, text)] — level FAIL / WARN / OK / NOTE. `old` may be None (nothing accepted yet)."""
    out = []
    s, so = now.get("stuck"), (old or {}).get("stuck")
    if s:
        if so is None:
            out.append(("WARN" if s["stuck"] else "OK", f"stuck balls: {s['stuck']} of {s['drops']} drops"
                        + (" at " + ", ".join(spot_text(sp) for sp in s["spots"][:6]) if s["spots"] else "")
                        + " (nothing accepted yet: look at each spot once — the plunger's rest is not a trap)"))
        else:
            new = [sp for sp in s["spots"] if not any(abs(sp[0] - o[0]) < 20 and abs(sp[1] - o[1]) < 20 for o in so["spots"])]
            real = [sp for sp in new if far_of(sp) >= FAR]
            near = [sp for sp in new if far_of(sp) < FAR]
            if real:
                out.append(("FAIL", "new stuck spot(s) reached from a distance: " + ", ".join(spot_text(sp) for sp in real)))
            if near:
                out.append(("WARN", "new stuck spot(s) right where the ball was dropped (probably dropped inside a part): "
                            + ", ".join(spot_text(sp) for sp in near)))
            if new:
                pass
            elif s["stuck"] > so["stuck"] + 2:
                out.append(("WARN", f"more stuck balls at the known spots: {so['stuck']} → {s['stuck']} of {s['drops']}"))
            else:
                out.append(("OK", f"stuck balls: {s['stuck']} of {s['drops']} (accepted {so['stuck']} of {so['drops']}), no new spot"))
    w, wo = now.get("windows"), (old or {}).get("windows")
    if w:
        n_shots = sum(len(v) for v in w["shots"].values())
        if wo is None:
            out.append(("NOTE", f"shot windows: {n_shots} shots from {len(w['shots'])} flippers (nothing accepted to compare with)"))
        else:
            bad = False
            for fl in sorted(set(w["shots"]) | set(wo["shots"])):
                a, b = w["shots"].get(fl, {}), wo["shots"].get(fl, {})
                for shot in sorted(set(a) | set(b)):
                    x, y = a.get(shot), b.get(shot)
                    if y and not x and y["trials"] >= 3:
                        out.append(("FAIL", f"shot gone: {shot} from the {fl} flipper (was {y['trials']} flips, {y['lo']}–{y['hi']} s)")); bad = True
                    elif x and not y and x["trials"] >= 3:
                        out.append(("NOTE", f"new shot: {shot} from the {fl} flipper ({x['trials']} flips, {x['lo']}–{x['hi']} s)"))
                    elif x and y:
                        if abs(x["trials"] - y["trials"]) >= 3 and abs(x["trials"] - y["trials"]) > 0.4 * y["trials"]:
                            out.append(("WARN", f"{shot} from the {fl} flipper: window {y['trials']} → {x['trials']} flips")); bad = True
                        elif (x["lo"] > y["hi"] + 0.01 or x["hi"] < y["lo"] - 0.01) and min(x["trials"], y["trials"]) >= 3:
                            # Windows often come in two bands, so the middle jumps about: only a window that no
                            # longer overlaps the accepted one has moved.
                            out.append(("WARN", f"{shot} from the {fl} flipper: window moved {y['lo']}–{y['hi']} → {x['lo']}–{x['hi']} s")); bad = True
            if not bad:
                out.append(("OK", f"shot windows: {n_shots} shots, none gone or moved"))
    p, po = now.get("play"), (old or {}).get("play")
    if p:
        if p["incidents"]:
            out.append(("FAIL", f"{len(p['incidents'])} watchdog incident(s): " + ", ".join(
                f"{i['kind']} at ({i['x']}, {i['y']})" for i in p["incidents"][:5])))
        else:
            out.append(("OK", f"no watchdog incidents in {p['games']} robot games"))
        if po:
            if p["lo"] > po["hi"] or p["hi"] < po["lo"]:
                out.append(("WARN", f"drain rate changed: {po['drains_per_min']} ({po['lo']}–{po['hi']}) → "
                                    f"{p['drains_per_min']} ({p['lo']}–{p['hi']}) per minute"))
            else:
                out.append(("OK", f"drain rate {p['drains_per_min']} per minute (accepted {po['drains_per_min']}, bands overlap)"))
            lost = sorted(set(po["reached"]) - set(p["reached"]))
            if lost:
                out.append(("WARN", "objectives the advanced/expert robots reached before but not now: " + ", ".join(lost)))
        else:
            out.append(("NOTE", f"drain rate {p['drains_per_min']} ({p['lo']}–{p['hi']}) per minute (nothing accepted to compare with)"))
        for k in SKILLS:
            if k in p["skills"] and p["skills"][k]["seconds_per_ball"] is not None:
                sk = p["skills"][k]
                out.append(("NOTE", f"{k}: {sk['seconds_per_ball']} s a ball — {sk['verdict']}"))
    return out


def show(table, checks, summary_path=None):
    order = {"FAIL": 0, "WARN": 1, "OK": 2, "NOTE": 3}
    fails = sum(1 for lv, _ in checks if lv == "FAIL")
    warns = sum(1 for lv, _ in checks if lv == "WARN")
    print(f"\n== Health check · {table} · " + ("FAILED" if fails else "passed with warnings" if warns else "PASSED")
          + f" ({fails} failed, {warns} warnings)")
    for lv, text in sorted(checks, key=lambda c: order[c[0]]):
        print(f"  {lv:4}  {text}")
    if summary_path:
        print(f"  summary: {os.path.relpath(summary_path, ROOT)}")
    return 1 if fails else 0


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("table", nargs="?")
    ap.add_argument("--accept", action="store_true", help="save this run as the table's accepted results")
    ap.add_argument("--only", default="stuck,windows,play", help="which steps: stuck,windows,play")
    ap.add_argument("--compare", nargs=2, metavar=("NOW", "ACCEPTED"), help="compare two saved summaries; no run")
    args = ap.parse_args()
    if args.compare:
        now, old = (json.load(open(f)) for f in args.compare)
        sys.exit(show(now.get("table", "?"), compare(now, old)))
    if not args.table:
        ap.error("table (greyinvasion, cthulhu, monsoon, lamplight, grandtour, chomp, …)")
    steps = set(args.only.split(","))
    env = dict(os.environ)
    env.setdefault("FAST", "8")
    drops, games = env.get("DROPS", "80"), env.get("GAMES", "2")
    env["DROPS"] = drops
    t_start = time.time()
    summary = dict(table=args.table, date=time.strftime("%Y-%m-%dT%H-%M-%SZ", time.gmtime()), fast=env["FAST"])
    name = None
    slug = SLUGS.get(args.table, args.table)
    if "stuck" in steps:
        print("▶ 1/3 the stuck-ball finder", flush=True)
        t0 = time.time()
        run(["tools/shotlab_run.sh", args.table, "", "", "scatter"], env)
        env["SKIP_BUILD"] = "1"
        f, d = newest(f"shotlab-{slug}-scatter-*.json", t0)
        if d:
            summary["stuck"] = stuck_summary(d); summary["stuck"]["file"] = os.path.basename(f); name = d.get("table")
        else:
            summary["stuck_error"] = "no scatter result"
    if "windows" in steps:
        print("▶ 2/3 the shot windows", flush=True)
        t0 = time.time()
        run(["tools/shotlab_run.sh", args.table], env)
        env["SKIP_BUILD"] = "1"
        f, d = newest(f"shotlab-{slug}-2*.json", t0, lambda d: d.get("start", "cradle") == "cradle")
        if d:
            summary["windows"] = windows_summary(d); summary["windows"]["file"] = os.path.basename(f); name = name or d.get("table")
        else:
            summary["windows_error"] = "no Shot Lab result"
    if "play" in steps:
        print("▶ 3/3 robot games", flush=True)
        t0 = time.time()
        out = run(["tools/playlab_run.sh", args.table, games, "120"], env)
        rep = [l.split("▶ Report: ", 1)[1].strip() for l in out.splitlines() if l.startswith("▶ Report: ")]
        if rep and os.path.isfile(os.path.join(ROOT, rep[-1])):
            d = json.load(open(os.path.join(ROOT, rep[-1])))
            summary["play"] = play_summary(d); summary["play"]["file"] = os.path.basename(rep[-1]); name = name or d.get("table")
        else:
            summary["play_error"] = "no Play Lab report"
    summary["table_name"] = name
    summary["minutes"] = round((time.time() - t_start) / 60, 1)
    path = os.path.join(ROOT, "ShotLab", f"health-{args.table}-{summary['date']}.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(summary, open(path, "w"), indent=1)
    acc_path = os.path.join(ACCEPTED, args.table + ".json")
    old = json.load(open(acc_path)) if os.path.isfile(acc_path) else None
    checks = compare(summary, old)
    for k in ("stuck_error", "windows_error", "play_error"):
        if k in summary:
            checks.append(("FAIL", f"{k.split('_')[0]} step produced nothing: {summary[k]}"))
    rc = show(name or args.table, checks, path)
    print(f"  took {summary['minutes']} min" + ("" if old else " · no accepted results yet: rerun with --accept to save these"))
    if args.accept and any(k in summary for k in ("stuck_error", "windows_error", "play_error")):
        print("  NOT accepted: a step produced nothing (an incomplete reference would hide later problems)")
    elif args.accept:
        os.makedirs(ACCEPTED, exist_ok=True)
        json.dump(summary, open(acc_path, "w"), indent=1)
        print(f"  accepted → {os.path.relpath(acc_path, ROOT)}")
    sys.exit(rc)


if __name__ == "__main__":
    main()
