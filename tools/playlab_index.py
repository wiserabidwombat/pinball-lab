#!/usr/bin/env python3
"""Pinball Lab · Play Lab sweep index: one page that compares every table's Play Lab run.

    python3 tools/playlab_index.py --out ShotLab/sweep-<stamp>.html ShotLab/playlab-*.json [--failed monsoon,orbit]
    python3 tools/playlab_index.py ShotLab/playlab-the-lamplight-….json ShotLab/playlab-monsoon-….json   (text only)

Per table: games, fps, watchdog incidents, the too-hard flags, score per skill at each pass, drains per minute per
pass × skill, how far the advanced/expert robots got (objectives reached, and the last one in the table's order), aim
accuracy for the expert, and links to the table's own page and tracks. Reads the JSONs with playlab_report.analyze,
so the numbers are the same ones the per-table pages show. Pure Python (the Mac's 3.9+), no dependencies.
"""
import argparse, html, json, os, sys

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
    return dict(path=path, table=d["table"], date=d["date"], games=len(games), fps=d.get("fps", 0), passes=passes,
                minutes=minutes, incidents=len(a["incidents"]), flags=a["flags"], notes=a["notes"], rows=rows,
                drains=drains, reach=reach, nobj=len(names), aim_text=aim_text,
                page=os.path.splitext(path)[0] + ".html", tracks=os.path.splitext(path)[0] + "-tracks.svg")


def cell_score(r):
    return f"{r['score']:,.0f}<div class='small'>{r['minutes']:.1f} min · {', '.join(r['ends'])}</div>" if r else "<span class='cn'>—</span>"


def cell_drain(r):
    if not r:
        return "<span class='cn'>—</span>"
    v = r["per_min"]
    cls = "c2" if v <= 1.0 else ("c1" if v <= 1.8 else "c0")
    return f"<span class='cell {cls}'>{v:.1f}</span><div class='small'>{r['n']} · life {r['life']:.0f} s</div>"


def write_html(tables, out_path, games_per_skill, hz, failed):
    e = html.escape
    h = [f"<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
         f"<title>Play Lab sweep · {e(os.path.basename(out_path))}</title><style>{pr.CSS}"
         ".grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}"
         ".tbl h3{margin:0 0 6px;font-size:17px}.tbl .sub{margin-bottom:8px}a{color:#9ec5ff}"
         "</style></head><body><main>"]
    total_min = sum(t["minutes"] for t in tables)
    h.append(f"<h1>Play Lab sweep</h1><div class='sub'>{len(tables)} table(s) · {games_per_skill} game(s) per skill · {e(hz)} · "
             f"{sum(t['games'] for t in tables)} games · {total_min / 60:.1f} h of play"
             + (f" · <span style='color:var(--bad)'>no report: {e(', '.join(failed))}</span>" if failed else "") + "</div>")

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
                     + "".join(f"<td>{cell_score(t['rows'].get((p, s)))}</td>" for s in pr.SKILLS)
                     + (f"<td>{t['incidents']}</td><td>{t['fps']}</td>" if i == 0 else "<td></td><td></td>") + "</tr>")
    h.append("</table></div>")

    # 3. Drains per minute (the stable comparison number)
    h.append("<h2>Drains per minute</h2><div class='panel small'>green ≤ 1.0 · amber ≤ 1.8 · red above — with the number of drains "
             "and the median ball life. Compare tables and runs by this, not by score or minutes (multiball loops swing those).</div>"
             "<div class='panel'><table><tr><th>table</th><th>pass</th>" + "".join(f"<th>{s}</th>" for s in pr.SKILLS) + "</tr>")
    for t in tables:
        for i, p in enumerate(t["passes"]):
            h.append(f"<tr><td>{e(t['table']) if i == 0 else ''}</td><td>{e(p)}</td>"
                     + "".join(f"<td>{cell_drain(t['drains'].get((p, s)))}</td>" for s in pr.SKILLS) + "</tr>")
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


def print_text(tables, failed):
    for t in tables:
        print(f"== {t['table']} · {t['date']} · {t['games']} games · {t['minutes']:.0f} min · {t['fps']} fps · watchdog {t['incidents']}")
        for p in t["passes"]:
            scores = "  ".join(f"{s[:3]} {t['rows'][(p, s)]['score']:>9,.0f}" if (p, s) in t["rows"] else f"{s[:3]}         —" for s in pr.SKILLS)
            dr = "  ".join(f"{t['drains'][(p, s)]['per_min']:.1f}" if (p, s) in t["drains"] else "  —" for s in pr.SKILLS)
            n, missed = t["reach"].get(p, (0, "—"))
            print(f"   {p:6} {scores}   drains/min {dr}   reached {n}/{t['nobj']}" + (f" (missed: {missed})" if missed != "everything" else ""))
        for f in t["flags"]:
            print(f"   ! {f}")
    if failed:
        print("No report:", ", ".join(failed))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("reports", nargs="+")
    ap.add_argument("--out", help="write the index as this HTML page")
    ap.add_argument("--games", default="?")
    ap.add_argument("--hz", default="?")
    ap.add_argument("--failed", default="", help="tables that produced no report, comma-separated")
    args = ap.parse_args()
    args.failed = [t for t in args.failed.split(",") if t]
    tables = [summarize(p, *load(p)) for p in args.reports]
    print_text(tables, args.failed)
    if args.out:
        write_html(tables, args.out, args.games, args.hz, args.failed)
        print("wrote", args.out)
