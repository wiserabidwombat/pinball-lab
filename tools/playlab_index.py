#!/usr/bin/env python3
"""Pinball Lab · Play Lab sweep index: one page that compares every table's Play Lab run.

    python3 tools/playlab_index.py --out ShotLab/sweep-<stamp>.html ShotLab/playlab-*.json [--failed monsoon,orbit]
    python3 tools/playlab_index.py ShotLab/playlab-the-lamplight-….json ShotLab/playlab-monsoon-….json   (text only)
    python3 tools/playlab_index.py --out … --baseline 2026-10-23T12-14-26Z <jsons…>     (plan 2 round 3: deltas vs that sweep)
    python3 tools/playlab_index.py --out … --baseline latest <jsons…>                    (vs the newest earlier sweep)

Regression mode (--baseline): every drains/min and score cell shows its delta against the same table, pass and skill
of the baseline sweep, coloured only when the move is bigger than the two 95 % bands combined; a "What changed" panel
on top lists objectives the advanced/expert robots gained or lost, drains/min and scores that moved beyond the band,
expert/advanced aim rates that moved beyond the band, and flags that are new or gone. The baseline is a sweep stamp
(resolved through ShotLab/sweep-<stamp>.json, the manifest this script writes next to each --out page, or the older
sweep-<stamp>.log), "latest", a manifest path, or a comma-separated list of report JSONs.

Per table: games, fps, watchdog incidents, the too-hard flags, score per skill at each pass, drains per minute per
pass × skill, how far the advanced/expert robots got (objectives reached, and the last one in the table's order), aim
accuracy for the expert, and links to the table's own page and tracks. Reads the JSONs with playlab_report.analyze,
so the numbers are the same ones the per-table pages show. Pure Python (the Mac's 3.9+), no dependencies.
"""
import argparse, glob, html, json, math, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import playlab_report as pr   # noqa: E402

GOOD = ("advanced", "expert")


def load(path):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return d, pr.analyze(d, precise=())


def summarize(path, d, a):
    games = a["games"]
    passes = a["passes"]
    rows = {(r["pass_"], r["skill"]): r for r in a["rows"]}
    drains = {(r["pass_"], r["skill"]): r for r in a["drain_rows"]}
    names = a["names"]
    # How far the good robots got, per pass: objectives reached (share > 0) and the ones they never reached.
    reach = {}
    for p in passes:
        got = [n for n in names if any(a["grid"].get((n, p, s), (0, None))[0] > 0 for s in GOOD)]
        missed = [n for n in names if n not in got]
        reach[p] = (len(got), ", ".join(missed[:5]) + (" …" if len(missed) > 5 else "") if missed else "everything")
    # The expert's aim table at 120 Hz (or the first pass).
    p0 = "hz120" if "hz120" in passes else (passes[0] if passes else None)
    aims = a["aims"].get((p0, "expert"), {}) if p0 else {}
    aim_text = ", ".join(f"{k} {m}/{t}" for k, (t, m) in sorted(aims.items())) or "—"
    minutes = sum(g["seconds"] for g in games) / 60
    reached = {p: {n for n in names if any(a["grid"].get((n, p, s), (0, None))[0] > 0 for s in GOOD)} for p in passes}
    return dict(path=path, table=d["table"], date=d["date"], games=len(games), fps=d.get("fps", 0), passes=passes,
                build=pr.build_line(d), build_key=pr.build_key(d),
                minutes=minutes, incidents=len(a["incidents"]), flags=a["flags"], notes=a["notes"], rows=rows,
                drains=drains, reach=reach, reached=reached, aims=a["aims"], nobj=len(names), aim_text=aim_text,
                page=os.path.splitext(path)[0] + ".html", tracks=os.path.splitext(path)[0] + "-tracks.svg", delta=None)


# ---------------------------------------------------------------- regression mode (plan 2, round 3)

def resolve_baseline(spec, out_path, report_paths):
    """The baseline sweep's report paths, from a stamp / 'latest' / a manifest path / a comma-separated list of JSONs."""
    if spec.endswith(".json") and all(os.path.basename(p).startswith("playlab-") for p in spec.split(",")):
        return [p for p in spec.split(",") if p], "the given reports"
    # The sweeps live beside the reports (ShotLab/); the page may be written elsewhere.
    folder = os.path.dirname(os.path.abspath(report_paths[0] if report_paths else (out_path or "ShotLab/x")))
    own = os.path.splitext(os.path.basename(out_path))[0] if out_path else None
    if spec == "latest":
        # Whole-sweep stamps only (sweep-<stamp>.json / .log) — not the per-table sweep-<stamp>-<table>.log files —
        # and not this sweep's own; newest first, skipping any with nothing usable (a cancelled sweep).
        cands = sorted({re.sub(r"\.(json|log)$", "", os.path.basename(p)) for p in glob.glob(os.path.join(folder, "sweep-*.*"))
                        if re.fullmatch(r"sweep-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z\.(json|log)", os.path.basename(p))})
        cands = [c for c in cands if c != own]
        for c in reversed(cands):
            manifest = os.path.join(folder, c + ".json")
            log = os.path.join(folder, c + ".log")
            usable = os.path.exists(manifest)
            if not usable and os.path.exists(log):
                with open(log, encoding="utf-8", errors="replace") as f:
                    usable = any(re.search(r"→ \S*playlab-[^\s]+\.json\s*$", line) for line in f)
            if usable:
                spec = c
                break
        else:
            sys.exit("--baseline latest: no earlier sweep with reports (sweep-<stamp>.json or .log) in " + folder)
    stem = re.sub(r"\.(json|log|html)$", "", os.path.basename(spec))
    if not stem.startswith("sweep-"):
        stem = "sweep-" + stem
    manifest = os.path.join(folder, stem + ".json")
    if os.path.exists(manifest):
        with open(manifest, encoding="utf-8") as f:
            m = json.load(f)
        return [os.path.join(folder, os.path.basename(r)) for r in m.get("reports", [])], stem
    log = os.path.join(folder, stem + ".log")
    if os.path.exists(log):
        found = []
        with open(log, encoding="utf-8", errors="replace") as f:
            for line in f:
                mm = re.search(r"→ (\S*playlab-[^\s]+\.json)\s*$", line)
                if mm:
                    found.append(os.path.join(folder, os.path.basename(mm.group(1))))
        if found:
            return found, stem + " (from its log)"
    sys.exit(f"--baseline {spec}: no manifest {manifest} and no usable log {log}")


def hw(lo, hi):
    return (hi - lo) / 2 if lo is not None and hi is not None else None


def moved(v1, lo1, hi1, v0, lo0, hi0):
    """(delta, significant): significant when |delta| exceeds the two half-widths combined."""
    h1, h0 = hw(lo1, hi1), hw(lo0, hi0)
    d = v1 - v0
    if h1 is None or h0 is None:
        return d, False
    return d, abs(d) > math.sqrt(h1 * h1 + h0 * h0)


def compare(t, b):
    """Deltas of table t against its baseline b: drains and scores per (pass, skill), objectives, aims, flags."""
    out = dict(base=b, drains={}, scores={}, gained={}, lost={}, aims=[], new_flags=[], gone_flags=[], changes=[])
    for k, r in t["drains"].items():
        r0 = b["drains"].get(k)
        if r0:
            dlt, sig = moved(r["per_min"], r["per_min_lo"], r["per_min_hi"], r0["per_min"], r0["per_min_lo"], r0["per_min_hi"])
            out["drains"][k] = (dlt, sig)
            if sig:
                out["changes"].append(("bad" if dlt > 0 else "good",
                                       f"drains/min {k[0]} {k[1]}: {r0['per_min']:.1f} → {r['per_min']:.1f} ({dlt:+.1f}, beyond the bands)"))
    for k, r in t["rows"].items():
        r0 = b["rows"].get(k)
        if r0:
            dlt, sig = moved(r["score"], r.get("score_lo"), r.get("score_hi"), r0["score"], r0.get("score_lo"), r0.get("score_hi"))
            out["scores"][k] = (dlt, sig)
            if sig:
                # Scores swing with multiball loops and caps; listed last and in grey, never as a verdict.
                out["changes"].append(("score", f"score {k[0]} {k[1]}: {r0['score']:,.0f} → {r['score']:,.0f} ({dlt:+,.0f}, beyond the bands)"))
    for p in t["passes"]:
        if p in b["reached"]:
            g, l = sorted(t["reached"][p] - b["reached"][p]), sorted(b["reached"][p] - t["reached"][p])
            out["gained"][p], out["lost"][p] = g, l
            if l:
                out["changes"].append(("bad", f"{p}: advanced/expert no longer reach {', '.join(l)}"))
            if g:
                out["changes"].append(("good", f"{p}: advanced/expert now reach {', '.join(g)}"))
    for (p, s), tot in t["aims"].items():
        if s not in GOOD:
            continue
        tot0 = b["aims"].get((p, s), {})
        for shot, (tried, made) in sorted(tot.items()):
            if shot in tot0 and tried >= 5 and tot0[shot][0] >= 5:
                t0, m0 = tot0[shot]
                lo1, hi1 = pr.wilson(made, tried)
                lo0, hi0 = pr.wilson(m0, t0)
                dlt, sig = moved(made / tried, lo1, hi1, m0 / t0, lo0, hi0)
                if sig:
                    out["aims"].append((p, s, shot, m0, t0, made, tried, dlt))
                    out["changes"].append(("good" if dlt > 0 else "bad",
                                           f"aim {p} {s} {shot}: {m0}/{t0} → {made}/{tried} ({dlt * 100:+.0f} points, beyond the bands)"))
    out["new_flags"] = [f for f in t["flags"] if f not in b["flags"]]
    out["gone_flags"] = [f for f in b["flags"] if f not in t["flags"]]
    for f in out["new_flags"]:
        out["changes"].append(("bad", "new flag: " + f))
    for f in out["gone_flags"]:
        out["changes"].append(("good", "flag gone: " + f))
    out["changes"].sort(key=lambda c: c[0] == "score")
    return out


def delta_html(pair, fmt, bad_when_up):
    """A small 'Δ +0.4' line under a cell: coloured only when the move is beyond the bands."""
    if not pair:
        return ""
    dlt, sig = pair
    color = ("var(--bad)" if (dlt > 0) == bad_when_up else "var(--good)") if sig else "var(--dim)"
    return f"<div class='small' style='color:{color}' title='vs the baseline{'' if sig else ' — within the bands'}'>Δ {fmt(dlt)}</div>"


def cell_score(r, delta=None):
    if not r:
        return "<span class='cn'>—</span>"
    band = f" ±{(r['score_hi'] - r['score_lo']) / 2:,.0f}" if r.get("score_lo") is not None else ""
    return (f"{r['score']:,.0f}<span class='small'>{band}</span><div class='small'>{r['minutes']:.1f} min · {', '.join(r['ends'])}</div>"
            + delta_html(delta, lambda x: f"{x:+,.0f}", bad_when_up=False))


def cell_drain(r, delta=None):
    if not r:
        return "<span class='cn'>—</span>"
    v, lo, hi = r["per_min"], r.get("per_min_lo"), r.get("per_min_hi")
    band = lambda x: 2 if x <= 1.0 else (1 if x <= 1.8 else 0)
    cls = f"c{band(v)}"
    # Round 2: a cell whose 95 % band straddles a colour threshold is shown muted — the colour isn't settled yet.
    unc = " unc" if lo is not None and band(lo) != band(hi) else ""
    return (f"<span class='cell {cls}{unc}' title='95 % band {lo:.1f}–{hi:.1f} over {r.get('games', '?')} games'>{pr.pm(v, lo, hi)}</span>"
            f"<div class='small'>{r['n']} · life {r['life']:.0f} s</div>" + delta_html(delta, lambda x: f"{x:+.1f}", bad_when_up=True))


def write_html(tables, out_path, games_per_skill, hz, failed, baseline_name=None, retried=()):
    e = html.escape
    h = [f"<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
         f"<title>Play Lab sweep · {e(os.path.basename(out_path))}</title><style>{pr.CSS}"
         ".grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}"
         ".tbl h3{margin:0 0 6px;font-size:17px}.tbl .sub{margin-bottom:8px}a{color:#9ec5ff}"
         "</style></head><body><main>"]
    total_min = sum(t["minutes"] for t in tables)
    h.append(f"<h1>Play Lab sweep</h1><div class='sub'>{len(tables)} table(s) · {games_per_skill} game(s) per skill · {e(hz)} · "
             f"{sum(t['games'] for t in tables)} games · {total_min / 60:.1f} h of play"
             + (f" · <span style='color:var(--bad)'>no report: {e(', '.join(failed))}</span>" if failed else "")
             + (f" · <span style='color:var(--warn)' title='the first run produced no report (a stall or a dead Simulator); "
                f"the Simulator was rebooted and the table played again'>retried: {e(', '.join(retried))}</span>" if retried else "")
             + "</div>")
    builds = sorted({t["build_key"] for t in tables})
    if len(builds) == 1:
        h.append(f"<div class='sub'>build {e(tables[0]['build'])}</div>")
    else:
        h.append(f"<div class='sub' style='color:var(--bad)'>MIXED BUILDS — the tables of this sweep were not built alike, "
                 f"so compare them with care: " + " / ".join(f"{e(t['table'])}: {e(t['build_key'])}" for t in tables) + "</div>")

    # 0. What changed vs the baseline (round 3)
    if baseline_name:
        h.append(f"<h2>What changed vs {e(baseline_name)}</h2><div class='panel small'>only moves bigger than both runs' 95 % bands "
                 "combined are listed (and coloured in the tables below); everything else is within the noise of the sample sizes</div>")
        for t in tables:
            dl = t["delta"]
            if not dl:
                h.append(f"<div class='panel'><strong>{e(t['table'])}</strong> <span class='small'>— not in the baseline</span></div>")
                continue
            h.append(f"<div class='panel'><strong>{e(t['table'])}</strong> <span class='small'>vs {e(os.path.basename(dl['base']['path']))} "
                     f"({dl['base']['games']} games, build {e(dl['base']['build_key'])})</span>")
            if dl["changes"]:
                h.append("<ul>" + "".join(f"<li style='color:var(--{'bad' if kind == 'bad' else 'dim' if kind == 'score' else 'good'})'>{e(txt)}</li>"
                                          for kind, txt in dl["changes"]) + "</ul>")
            else:
                h.append("<div class='small' style='color:var(--good);margin-top:6px'>no change beyond the bands</div>")
            h.append("</div>")

    # 1. Flags across tables
    flagged = [(t, f) for t in tables for f in t["flags"]]
    h.append(f"<div class='panel flags{'' if flagged else ' ok'}'><strong>{'Too hard, by table' if flagged else 'Too hard: nothing flagged on any table'}</strong>")
    if flagged:
        h.append("<ul>")
        for t in tables:
            for f in t["flags"]:
                h.append(f"<li><span class='tag'>{e(t['table'])}</span>{e(f)}</li>")
        h.append("</ul>")
    h.append("</div>")

    # 2. Scores per skill and pass
    passes = sorted({p for t in tables for p in t["passes"]}, key=pr.pass_order)
    h.append("<h2>Scores</h2><div class='panel'><table><tr><th>table</th><th>pass</th>"
             + "".join(f"<th>{s}</th>" for s in pr.SKILLS) + "<th>watchdog</th><th>fps</th></tr>")
    for t in tables:
        for i, p in enumerate(t["passes"]):
            h.append(f"<tr><td>{e(t['table']) if i == 0 else ''}</td><td>{e(p)}</td>"
                     + "".join(f"<td>{cell_score(t['rows'].get((p, s)), (t['delta'] or {}).get('scores', {}).get((p, s)))}</td>" for s in pr.SKILLS)
                     + (f"<td>{t['incidents']}</td><td>{t['fps']}</td>" if i == 0 else "<td></td><td></td>") + "</tr>")
    h.append("</table></div>")

    # 3. Drains per minute (the stable comparison number)
    h.append("<h2>Drains per minute</h2><div class='panel small'>green ≤ 1.0 · amber ≤ 1.8 · red above — with the number of drains "
             "and the median ball life. Compare tables and runs by this, not by score or minutes (multiball loops swing those). "
             "± is half of a 95 % band (bootstrap over the cell's games); a dashed cell's band crosses a colour line, so its colour "
             "isn't settled — more games (UNTIL_TIGHT on the sweep) or no conclusion.</div>"
             "<div class='panel'><table><tr><th>table</th><th>pass</th>" + "".join(f"<th>{s}</th>" for s in pr.SKILLS) + "</tr>")
    for t in tables:
        for i, p in enumerate(t["passes"]):
            h.append(f"<tr><td>{e(t['table']) if i == 0 else ''}</td><td>{e(p)}</td>"
                     + "".join(f"<td>{cell_drain(t['drains'].get((p, s)), (t['delta'] or {}).get('drains', {}).get((p, s)))}</td>" for s in pr.SKILLS) + "</tr>")
    h.append("</table></div>")

    # 4. How far the good robots got
    h.append("<h2>How far the advanced/expert robots got</h2><div class='panel'><table><tr><th>table</th>"
             + "".join(f"<th>{e(p)}</th>" for p in passes) + "<th>expert aims (120 Hz)</th></tr>")
    for t in tables:
        cells = []
        for p in passes:
            if p in t["reach"]:
                n, missed = t["reach"][p]
                share = n / t["nobj"] if t["nobj"] else 0
                cls = "c2" if share >= 0.75 else ("c1" if share >= 0.4 else "c0")
                cells.append(f"<td style='white-space:normal'><span class='cell {cls}'>{n} / {t['nobj']}</span>"
                             f"<div class='small'>{'missed: ' if missed != 'everything' else ''}{e(missed)}</div></td>")
            else:
                cells.append("<td><span class='cn'>—</span></td>")
        h.append(f"<tr><td>{e(t['table'])}</td>{''.join(cells)}<td style='white-space:normal;text-align:left'>{e(t['aim_text'])}</td></tr>")
    h.append("</table></div>")

    # 5. Per-table cards with links
    h.append("<h2>Tables</h2><div class='grid2'>")
    for t in tables:
        rel = lambda p: os.path.relpath(p, os.path.dirname(os.path.abspath(out_path)))
        h.append(f"<div class='panel tbl'><h3>{e(t['table'])}</h3><div class='sub'>{e(t['date'])} · {t['games']} games · "
                 f"{t['minutes']:.0f} min · {t['fps']} fps · watchdog {t['incidents']}</div>"
                 f"<div class='sub small'>build {e(t['build'])}</div>"
                 f"<div><a href='{e(rel(t['page']))}'>report page</a> · <a href='{e(rel(t['tracks']))}'>tracks</a> · "
                 f"<span class='small'>{e(os.path.basename(t['path']))}</span></div>")
        if t["flags"]:
            h.append("<ul class='small'>" + "".join(f"<li>{e(f)}</li>" for f in t["flags"]) + "</ul>")
        else:
            h.append("<div class='small' style='color:var(--good);margin-top:6px'>nothing flagged</div>")
        if t["notes"]:
            h.append("<ul class='small'>" + "".join(f"<li>{e(n)}</li>" for n in t["notes"]) + "</ul>")
        h.append("</div>")
    h.append("</div></main></body></html>")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(h))


def print_text(tables, failed, baseline_name=None, retried=()):
    for t in tables:
        print(f"== {t['table']} · {t['date']} · {t['games']} games · {t['minutes']:.0f} min · {t['fps']} fps · watchdog {t['incidents']}")
        print(f"   build {t['build']}")
        if baseline_name:
            dl = t["delta"]
            if not dl:
                print(f"   vs {baseline_name}: not in the baseline")
            elif dl["changes"]:
                print(f"   vs {baseline_name} ({os.path.basename(dl['base']['path'])}):")
                for kind, txt in dl["changes"]:
                    print(f"     {'↓' if kind == 'bad' else '~' if kind == 'score' else '↑'} {txt}")
            else:
                print(f"   vs {baseline_name} ({os.path.basename(dl['base']['path'])}): no change beyond the bands")
        for p in t["passes"]:
            scores = "  ".join(f"{s[:3]} {t['rows'][(p, s)]['score']:>9,.0f}" if (p, s) in t["rows"] else f"{s[:3]}         —" for s in pr.SKILLS)
            dr = "  ".join(pr.pm(t['drains'][(p, s)]['per_min'], t['drains'][(p, s)]['per_min_lo'], t['drains'][(p, s)]['per_min_hi'])
                           if (p, s) in t["drains"] else "  —" for s in pr.SKILLS)
            n, missed = t["reach"].get(p, (0, "—"))
            print(f"   {p:6} {scores}   drains/min {dr}   reached {n}/{t['nobj']}" + (f" (missed: {missed})" if missed != "everything" else ""))
        for f in t["flags"]:
            print(f"   ! {f}")
    if failed:
        print("No report:", ", ".join(failed))
    if retried:
        print("Retried after a reboot:", ", ".join(retried))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("reports", nargs="+")
    ap.add_argument("--out", help="write the index as this HTML page")
    ap.add_argument("--games", default="?")
    ap.add_argument("--hz", default="?")
    ap.add_argument("--failed", default="", help="tables that produced no report, comma-separated")
    ap.add_argument("--baseline", help="regression mode: a sweep stamp, 'latest', a sweep manifest, or report JSONs (comma-separated)")
    ap.add_argument("--retried", default="", help="tables the sweep had to retry after a Simulator reboot, comma-separated")
    args = ap.parse_args()
    args.failed = [t for t in args.failed.split(",") if t]
    args.retried = [t for t in args.retried.split(",") if t]
    tables = [summarize(p, *load(p)) for p in args.reports]
    baseline_name = None
    if args.baseline:
        base_paths, baseline_name = resolve_baseline(args.baseline, args.out, args.reports)
        base = {}
        for p in base_paths:
            if os.path.exists(p):
                b = summarize(p, *load(p))
                base[b["table"]] = b
            else:
                print("baseline report missing:", p)
        for t in tables:
            t["delta"] = compare(t, base[t["table"]]) if t["table"] in base else None
    print_text(tables, args.failed, baseline_name, args.retried)
    if args.out:
        write_html(tables, args.out, args.games, args.hz, args.failed, baseline_name, args.retried)
        # The manifest: which reports this sweep page was built from, so a later sweep can baseline on this one.
        manifest = os.path.splitext(args.out)[0] + ".json"
        with open(manifest, "w", encoding="utf-8") as f:
            json.dump(dict(reports=[os.path.basename(p) for p in args.reports], failed=args.failed, retried=args.retried, games=args.games, hz=args.hz,
                           baseline=args.baseline, tables={t["table"]: dict(games=t["games"], build=t["build_key"]) for t in tables}), f, indent=1)
        print("wrote", args.out, "and", manifest)
