#!/usr/bin/env python3
"""Play Lab report (any table): reads a playlab-*.json written by PlayLab.swift (ShotLab/ on the Mac) and prints, per
skill and physics pass (120 Hz / 60 Hz), how games went, which objectives were reached and when, aim accuracy, shot
tracks, every watchdog incident, and the "too hard" flags. It can also draw the tracks as an SVG and write the whole
report as one HTML page (tables, the objective grid, the flags, the tracks inline, every screenshot).

  python3 tools/playlab_report.py playlab-the-lamplight-....json
  python3 tools/playlab_report.py playlab-....json --html             # writes <stem>.html beside the JSON
  python3 tools/playlab_report.py playlab-....json --tracks tracks.svg [--map table.png --map-rect -40 -75 680 1405]
  python3 tools/playlab_report.py playlab-....json --checks "GRANDFATHER CLOCK>=1" "objective:rush>=1" "shot:ramp>=3"
  python3 tools/playlab_report.py playlab-....json --precise mail fireplace   # shots meant to be hard: no flag

Too-hard flags (first-guess thresholds; tune them as the tables teach us):
  - an objective no advanced or expert robot reaches in any game
  - an objective reached at one physics rate but never at the other (plays differently on 60 Hz phones)
  - a shot the experts aim for 8+ times and make under 15% of the time (unless listed with --precise)
"""
import json, sys, argparse, collections, statistics, os, html, math

SKILLS = ["beginner", "intermediate", "advanced", "expert"]
OUTCOME_COLOR = {"made": "#2e9e4e", "miss": "#8a8a8a", "drain": "#d1403a"}


def mean(xs):
    return statistics.mean(xs) if xs else 0


def median(xs):
    return statistics.median(xs) if xs else 0


def pass_order(p):
    return 0 if p == "hz120" else 1


# ---------------------------------------------------------------- analysis

def classify_drain(dr, flippers):
    """How the ball went out, from its path: 'outlane L/R' (down a side wall), 'tip clip' (it struck a raised flipper
    tip — the robot was holding that flipper), 'off tip' (rolled off a flipper tip into the gap), else 'centre'.
    Also whether a button was held over the last second ('held')."""
    p = dr.get("path") or []
    if len(p) < 3:
        return "?", False
    pts = [(q[0], q[1]) for q in p]
    buttons = [q[2] if len(q) > 2 else 0 for q in p]
    tail = pts[-20:]
    held = any(b for b in buttons[-7:])
    # Right outlane: x 490–548 (the lane wall); beyond it is the plunger lane (a relaunched ball, not a drain path).
    if any(490 < x < 549 and y < 220 for x, y in pts):
        return "outlane R", held
    if any(x < 110 and y < 220 for x, y in pts):
        return "outlane L", held
    lower = [f for f in flippers if not f.get("upper") and "pivot" in f]
    for f in lower:
        px, py = f["pivot"]
        up = math.pi / 3 - f["restAngle"]            # raised: the travel is 60° on every table
        sgn = -1 if f["pointsLeft"] else 1
        tip = (px + sgn * f["length"] * math.cos(up), py + f["length"] * math.sin(up))
        for (x, y), b in zip(pts, buttons):
            if abs(x - tip[0]) < 16 and abs(y - tip[1] - 12) < 16 and b and (int(b) & (2 if f["pointsLeft"] else 1)):
                return "tip clip", held
        rest = (px + sgn * f["length"] * math.cos(f["restAngle"]), py - f["length"] * math.sin(f["restAngle"]))
        if any(abs(x - rest[0]) < 14 and abs(y - rest[1] - 10) < 14 for x, y in tail):
            return "off tip", held
    return "centre", held


def analyze(d, precise=()):
    games = d.get("games", d.get("evenings", []))
    for g in games:
        g.setdefault("pass", "hz120")
    passes = sorted({g["pass"] for g in games}, key=pass_order)
    objectives = d.get("objectives", [])
    names = [o["name"] for o in objectives] or sorted({k for g in games for k in g.get("objectives", {})})
    by = collections.defaultdict(list)
    for g in games:
        by[(g["pass"], g["skill"])].append(g)
    extras = sorted({k for g in games for k in g.get("extras", {})})

    # Per pass × skill summary rows
    rows = []
    for p in passes:
        for s in SKILLS:
            gs = by.get((p, s), [])
            if gs:
                rows.append(dict(pass_=p, skill=s, games=len(gs), score=mean([g["score"] for g in gs]),
                                 minutes=mean([g["seconds"] for g in gs]) / 60, balls=mean([g["ballsPlayed"] for g in gs]),
                                 catches=mean([g["catches"] for g in gs]),
                                 lane_taps=mean([g.get("laneTaps", 0) for g in gs]),
                                 extras={k: mean([g.get("extras", {}).get(k, 0) for g in gs]) for k in extras},
                                 ends=[g["endedBy"] for g in gs]))

    # Objective grid: (name, pass, skill) → (share, median seconds)
    grid = {}
    for name in names:
        for p in passes:
            for s in SKILLS:
                gs = by.get((p, s), [])
                if not gs:
                    continue
                hit = [g["objectives"][name] for g in gs if name in g.get("objectives", {})]
                grid[(name, p, s)] = (len(hit) / len(gs), median(hit) if hit else None)

    # Aims per pass × skill: target → [tried, made]
    aims = {}
    for p in passes:
        for s in SKILLS:
            tot = collections.defaultdict(lambda: [0, 0])
            for g in by.get((p, s), []):
                for k, (t, m) in g["aims"].items():
                    tot[k][0] += t; tot[k][1] += m
            if tot:
                aims[(p, s)] = dict(tot)

    banners, shots, objs = collections.Counter(), collections.Counter(), collections.Counter()
    for g in games:
        banners.update(g["banners"]); shots.update(g["shots"]); objs.update(g.get("objectiveCounts", {}))
    incidents = [(g["pass"], g["skill"], i) for g in games for i in g["incidents"]]
    captures = [(gi, g["pass"], g["skill"], c) for gi, g in enumerate(games) for c in g.get("captures", [])]
    tracks = [(g["pass"], g["skill"], t) for g in games for t in g.get("tracks", [])]
    track_rows = []
    if tracks:
        outcomes = collections.Counter((t["flipper"], t["target"], t["outcome"]) for _, _, t in tracks)
        for fl, tg in sorted({(t["flipper"], t["target"]) for _, _, t in tracks}):
            track_rows.append((fl, tg, *(outcomes[(fl, tg, o)] for o in ("made", "miss", "drain"))))

    # Round 4b: the drain log, per pass × skill — median ball life, drains soon after a plunge (full vs soft), drains
    # while the robot was catching or cradling, and where they went out (left third / middle / right third).
    drain_rows = []
    for p in passes:
        for sk in SKILLS:
            ds = [dr for g in by.get((p, sk), []) for dr in g.get("drains", [])]
            if not ds:
                continue
            fed = collections.Counter((dr.get("after") or ["(nothing)"])[-1] for dr in ds)
            kinds = collections.Counter(classify_drain(dr, d.get("flippers", []))[0] for dr in ds)
            held = sum(1 for dr in ds if classify_drain(dr, d.get("flippers", []))[1])
            minutes = sum(g["seconds"] for g in by.get((p, sk), [])) / 60
            drain_rows.append(dict(
                fed=", ".join(f"{k} {n}" for k, n in fed.most_common(3)), per_min=len(ds) / minutes if minutes else 0,
                kinds=", ".join(f"{k} {n}" for k, n in kinds.most_common()), held=held,
                pass_=p, skill=sk, n=len(ds), life=median([dr["life"] for dr in ds]),
                early_full=sum(1 for dr in ds if dr["life"] <= 6 and dr["plunge"] >= 0.9),
                early_soft=sum(1 for dr in ds if dr["life"] <= 6 and 0 <= dr["plunge"] < 0.9),
                catching=sum(1 for dr in ds if dr["mode"] in ("catching", "cradled")),
                shooting=sum(1 for dr in ds if dr["mode"] in ("dropped", "shooting")),
                speed=median([dr["speed"] for dr in ds]),
                left=sum(1 for dr in ds if dr["x"] < 200), mid=sum(1 for dr in ds if 200 <= dr["x"] <= 400),
                right=sum(1 for dr in ds if dr["x"] > 400)))
    drains = [(g["pass"], g["skill"], dr) for g in games for dr in g.get("drains", [])]
    no60 = []
    for f in d.get("flippers", []):
        missing = sorted(set(f.get("shots120", {})) - set(f.get("shots60", {})))
        if f.get("shots60") and missing:
            no60.append((f["name"], missing))

    # Too-hard flags
    flags = []
    for name, missing in no60:
        flags.append(f"no 60 Hz window in the Shot Lab for {', '.join(missing)} from the {name} flipper "
                     "(the robot doesn't aim at them on that pass)")
    for name in names:
        reached = {p: any(name in g.get("objectives", {}) for g in games
                          if g["pass"] == p and g["skill"] in ("advanced", "expert")) for p in passes}
        if passes and not any(reached.values()):
            flags.append(f"objective '{name}' was never reached by an advanced or expert robot")
        elif len(passes) > 1 and any(reached.values()) and not all(reached.values()):
            only = [p for p, r in reached.items() if r][0]
            flags.append(f"objective '{name}' was reached only at {only} by advanced/expert robots")
    expert = collections.defaultdict(lambda: [0, 0])
    for g in games:
        if g["skill"] == "expert":
            for k, (t, m) in g["aims"].items():
                expert[k][0] += t; expert[k][1] += m
    notes = []
    for k, (t, m) in sorted(expert.items()):
        if t >= 8 and m / t < 0.15:
            if k in precise:
                notes.append(f"shot '{k}' made {m}/{t} ({m / t:.0%}) by experts — a precise shot by design")
            else:
                flags.append(f"shot '{k}' made {m}/{t} ({m / t:.0%}) by experts")

    return dict(games=games, passes=passes, objectives=objectives, names=names, extras=extras, rows=rows, grid=grid,
                aims=aims, banners=banners, shots=shots, objs=objs, incidents=incidents, captures=captures,
                tracks=tracks, track_rows=track_rows, flags=flags, notes=notes, drain_rows=drain_rows, no60=no60,
                drains=drains, flippers=d.get("flippers", []))


def run_checks(a, checks):
    out = []
    for c in checks:
        name, n = c.rsplit(">=", 1)
        n = int(n)
        if name.startswith("shot:"):
            got = a["shots"].get(name[5:], 0)
        elif name.startswith("objective:"):
            got = a["objs"].get(name[10:], 0)
        else:
            got = sum(v for k, v in a["banners"].items() if k.startswith(name))
        out.append((c, got >= n, got))
    return out


# ---------------------------------------------------------------- tracks SVG

def tracks_svg(a, map_file=None, map_rect=(-40, -75, 680, 1405), inline=False):
    X, Y, W, H = map_rect
    tracks = a["tracks"]
    flippers = sorted({t["flipper"] for _, _, t in tracks}) or ["left", "right"]
    drains = [dr for dr in a.get("drains", []) if len(dr[2].get("path", [])) >= 2]
    panels = len(flippers) + (1 if drains else 0)
    panel_w, gap = W, 60
    attrs = 'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'
    style = ' style="width:100%;height:auto"' if inline else ''
    out = [f'<svg {attrs} viewBox="0 0 {panels * (panel_w + gap)} {H + 60}" font-family="Helvetica, Arial" '
           f'font-size="22"{style}>']
    for i, fl in enumerate(flippers):
        ox = i * (panel_w + gap)
        out.append(f'<g transform="translate({ox},0)">')
        out.append(f'<rect x="0" y="40" width="{W}" height="{H}" fill="#101010"/>')
        if map_file:
            out.append(f'<image xlink:href="{html.escape(map_file)}" x="0" y="40" width="{W}" height="{H}" opacity="0.8"/>')
        out.append(f'<rect x="{0 - X}" y="{40 + (Y + H - 1300)}" width="600" height="1300" fill="none" stroke="#555" stroke-width="2"/>')
        n = collections.Counter(t["outcome"] for _, _, t in tracks if t["flipper"] == fl)
        out.append(f'<text x="8" y="28" fill="{"#ddd" if inline else "#222"}">{fl} flipper · {sum(n.values())} flips · '
                   f'made {n["made"]} · miss {n["miss"]} · drain {n["drain"]}</text>')
        for _, skill, t in tracks:
            if t["flipper"] != fl or len(t["points"]) < 2:
                continue
            pts = " ".join(f"{x - X:.0f},{40 + (Y + H - y):.0f}" for x, y in t["points"])
            out.append(f'<polyline points="{pts}" fill="none" stroke="{OUTCOME_COLOR.get(t["outcome"], "#888")}" '
                       f'stroke-width="2.5" stroke-opacity="0.55"><title>{skill} → {t["target"]}: {t["outcome"]} at {t["at"]:.0f}s</title></polyline>')
            x0, y0 = t["points"][0]
            out.append(f'<circle cx="{x0 - X:.0f}" cy="{40 + (Y + H - y0):.0f}" r="4" fill="#fff"/>')
        out.append("</g>")
    # Round 4c: every drain's last ~2 s, by pass (120 Hz red, 60 Hz orange); a dot where the path starts.
    if drains:
        ox = len(flippers) * (panel_w + gap)
        out.append(f'<g transform="translate({ox},0)">')
        out.append(f'<rect x="0" y="40" width="{W}" height="{H}" fill="#101010"/>')
        if map_file:
            out.append(f'<image xlink:href="{html.escape(map_file)}" x="0" y="40" width="{W}" height="{H}" opacity="0.8"/>')
        out.append(f'<rect x="{0 - X}" y="{40 + (Y + H - 1300)}" width="600" height="1300" fill="none" stroke="#555" stroke-width="2"/>')
        out.append(f'<text x="8" y="28" fill="{"#ddd" if inline else "#222"}">drains · {len(drains)} · the last ~4 s of each ball '
                   f'(120 Hz red, 60 Hz orange, dashed = a button held)</text>')
        for p, skill, dr in drains:
            pts = " ".join(f"{q[0] - X:.0f},{40 + (Y + H - q[1]):.0f}" for q in dr["path"])
            color = "#d1403a" if p == "hz120" else "#e0a63a"
            fed = (dr.get("after") or ["nothing"])[-1]
            kind, held = classify_drain(dr, a.get("flippers", []))
            dash = ' stroke-dasharray="6 4"' if held else ''
            out.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2.5" stroke-opacity="0.6"{dash}>'
                       f'<title>{p} {skill} at {dr["at"]:.0f}s · {kind}{" · button held" if held else ""} · after {fed} · x {dr["x"]:.0f} · {dr["speed"]:.0f} pt/s</title></polyline>')
            x0, y0 = dr["path"][0][0], dr["path"][0][1]
            out.append(f'<circle cx="{x0 - X:.0f}" cy="{40 + (Y + H - y0):.0f}" r="4" fill="#fff"/>')
        out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)


# ---------------------------------------------------------------- text

def print_text(d, a, report_path, checks):
    games, passes, extras = a["games"], a["passes"], a["extras"]
    print(f"{d['table']} · {d['date']} · {len(games)} games · {d['fps']} fps · passes {', '.join(passes)}")
    print(f"\n{'pass':7}{'skill':13}{'games':>6}{'score':>10}{'min':>6}{'balls':>6}{'catch':>6}{'lanes':>6}"
          + "".join(f"{k[:7]:>8}" for k in extras) + "  end")
    for r in a["rows"]:
        print(f"{r['pass_']:7}{r['skill']:13}{r['games']:>6}{r['score']:>10,.0f}{r['minutes']:>6.1f}{r['balls']:>6.1f}"
              f"{r['catches']:>6.1f}{r['lane_taps']:>6.1f}" + "".join(f"{r['extras'][k]:>8.1f}" for k in extras)
              + "  " + ",".join(e[:4] for e in r["ends"]))
    if a["names"]:
        print("\nObjectives reached (share of games · median seconds to the first):")
        print(f"{'objective':15}" + "".join(f"{p + ' ' + s[:3]:>12}" for p in passes for s in SKILLS))
        for name in a["names"]:
            row = f"{name:15}"
            for p in passes:
                for s in SKILLS:
                    cell = a["grid"].get((name, p, s))
                    if cell is None:
                        row += f"{'-':>12}"
                    else:
                        share, med = cell
                        row += f"{f'{share:4.0%} {med:4.0f}s' if med is not None else f'{share:4.0%}      ':>12}"
            print(row)
        for o in a["objectives"]:
            print(f"  {o['name']:15} {o['text']}")
    print("\nAim accuracy (made / tried):")
    for (p, s), tot in a["aims"].items():
        if s != "beginner":
            print(f"  {p:7}{s:13}" + "  ".join(f"{k} {m}/{t}" for k, (t, m) in sorted(tot.items())))
    print("\nBanners (whole run):")
    for k, n in a["banners"].most_common():
        print(f"  {n:5}  {k}")
    print("\nShots (whole run): " + ", ".join(f"{k} {n}" for k, n in a["shots"].most_common()))
    print(f"\nWatchdog: {len(a['incidents'])} incident(s)")
    for p, skill, i in a["incidents"]:
        print(f"  {p:7}{skill:13}{i['kind']:12} at ({i['x']:.0f}, {i['y']:.0f}){' upper' if i['upper'] else ''}  t={i['time']:.0f}s")
    if a["captures"]:
        print(f"\nScreenshots: {len(a['captures'])} in {os.path.splitext(os.path.basename(report_path))[0]}/")
        for gi, p, skill, c in a["captures"]:
            print(f"  {p:7}{skill:13}{c['file']:40} {c['reason']:24} t={c['at']:.0f}s")
    if a["tracks"]:
        print(f"\nShot tracks: {len(a['tracks'])} aimed flips recorded")
        for fl, tg, made, miss, drain in a["track_rows"]:
            print(f"  {fl:7}{tg:13} made {made:3}  miss {miss:3}  drain {drain:3}")
    if a["drain_rows"]:
        print("\nDrains (median ball life · within 6 s of a full / soft plunge · while catching · while shooting · median speed · button held · how · fed by):")
        for r in a["drain_rows"]:
            print(f"  {r['pass_']:7}{r['skill']:13}{r['n']:3} drains ({r['per_min']:.1f}/min)  life {r['life']:5.1f}s  early full {r['early_full']:2} soft {r['early_soft']:2}"
                  f"  catching {r['catching']:2}  shooting {r['shooting']:2}  speed {r['speed']:4.0f}  held {r['held']:2}"
                  f"  how: {r['kinds']}  fed by: {r['fed']}")
    print("\nToo hard:" if a["flags"] else "\nToo hard: nothing flagged")
    for f in a["flags"]:
        print(f"  - {f}")
    for n in a["notes"]:
        print(f"  · {n}")
    if checks:
        print("\nChecklist:")
        results = run_checks(a, checks)
        for c, ok, got in results:
            print(f"  {'PASS' if ok else 'FAIL'}  {c}  (got {got})")
        print("ALL PASS" if all(ok for _, ok, _ in results) else "SOME FAILED")


# ---------------------------------------------------------------- HTML

CSS = """
:root{--bg:#141418;--panel:#1d1d23;--ink:#e8e6e1;--dim:#9a978f;--line:#2e2e36;--good:#2e9e4e;--bad:#d1403a;--warn:#e0a63a;--mid:#8a8a8a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 -apple-system,Helvetica,Arial,sans-serif}
main{max-width:1180px;margin:0 auto;padding:24px 16px 60px}h1{font-size:26px;margin:0 0 4px}h2{font-size:18px;margin:36px 0 10px;color:var(--ink)}
.sub{color:var(--dim);margin-bottom:18px}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}
th,td{padding:6px 10px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}
th{color:var(--dim);font-weight:600;font-size:13px;text-transform:uppercase;letter-spacing:.04em}
.panel{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px;overflow-x:auto}
.flags{border-left:4px solid var(--bad)}.flags.ok{border-left-color:var(--good)}.flags li{margin:4px 0}
.cell{display:inline-block;min-width:66px;padding:2px 6px;border-radius:5px;text-align:center;font-size:13px}
.c0{background:#3a2426;color:#f0a8a8}.c1{background:#3b3324;color:#f0d6a0}.c2{background:#223a2a;color:#a8f0bb}.cn{color:var(--dim)}
.gal{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}.gal figure{margin:0}
.gal img{width:100%;border-radius:8px;border:1px solid var(--line);background:#000}.gal figcaption{font-size:12px;color:var(--dim);margin-top:4px}
.tag{display:inline-block;padding:1px 7px;border-radius:999px;border:1px solid var(--line);font-size:12px;color:var(--dim);margin-right:6px}
details summary{cursor:pointer;color:var(--dim)}.small{font-size:13px;color:var(--dim)}
.legend span{display:inline-block;width:14px;height:4px;border-radius:2px;margin:0 6px 2px 0}
"""


def write_html(d, a, report_path, out_path, checks, map_file=None, map_rect=(-40, -75, 680, 1405)):
    e = html.escape
    games, passes, extras = a["games"], a["passes"], a["extras"]
    stem = os.path.splitext(os.path.basename(report_path))[0]
    h = [f"<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
         f"<title>Play Lab · {e(d['table'])} · {e(d['date'])}</title><style>{CSS}</style></head><body><main>"]
    h.append(f"<h1>Play Lab · {e(d['table'])}</h1><div class='sub'>{e(d['date'])} · {len(games)} games · {d['fps']} fps · "
             f"passes {', '.join(e(p) for p in passes)} · cap {d.get('maxGameSeconds', 480):.0f} s/game</div>")

    # Flags first
    flags = a["flags"]
    h.append(f"<div class='panel flags{'' if flags else ' ok'}'><strong>{'Too hard' if flags else 'Too hard: nothing flagged'}</strong>")
    if flags or a["notes"]:
        h.append("<ul>" + "".join(f"<li>{e(f)}</li>" for f in flags) + "".join(f"<li class='small'>{e(n)}</li>" for n in a["notes"]) + "</ul>")
    h.append("</div>")
    if checks:
        results = run_checks(a, checks)
        h.append("<h2>Checklist</h2><div class='panel'><ul>" + "".join(
            f"<li><span class='tag' style='color:{'var(--good)' if ok else 'var(--bad)'}'>{'PASS' if ok else 'FAIL'}</span>{e(c)} (got {got})</li>"
            for c, ok, got in results) + "</ul></div>")

    # Summary
    h.append("<h2>Games</h2><div class='panel'><table><tr><th>pass</th><th>skill</th><th>games</th><th>score</th><th>min</th>"
             "<th>balls</th><th>catches</th><th title='flipper taps that moved the lit lanes under a ball'>lane taps</th>"
             + "".join(f"<th>{e(k)}</th>" for k in extras) + "<th>ended by</th></tr>")
    for r in a["rows"]:
        h.append(f"<tr><td>{e(r['pass_'])}</td><td>{e(r['skill'])}</td><td>{r['games']}</td><td>{r['score']:,.0f}</td>"
                 f"<td>{r['minutes']:.1f}</td><td>{r['balls']:.1f}</td><td>{r['catches']:.1f}</td><td>{r['lane_taps']:.1f}</td>"
                 + "".join(f"<td>{r['extras'][k]:.1f}</td>" for k in extras)
                 + f"<td>{e(', '.join(r['ends']))}</td></tr>")
    h.append("</table></div>")

    # Objective grid
    if a["names"]:
        h.append("<h2>Objectives</h2><div class='panel small'>share of games the objective was reached · median seconds to the first time</div>"
                 "<div class='panel'><table><tr><th>objective</th>" + "".join(f"<th>{e(p)} {e(s)}</th>" for p in passes for s in SKILLS) + "</tr>")
        text = {o["name"]: o["text"] for o in a["objectives"]}
        for name in a["names"]:
            h.append(f"<tr><td title='{e(text.get(name, ''))}'>{e(name)}</td>")
            for p in passes:
                for s in SKILLS:
                    cell = a["grid"].get((name, p, s))
                    if cell is None:
                        h.append("<td><span class='cell cn'>–</span></td>")
                    else:
                        share, med = cell
                        cls = "c2" if share >= 0.75 else "c1" if share > 0 else ("c0" if s in ("advanced", "expert") else "cn")
                        h.append(f"<td><span class='cell {cls}'>{share:.0%}{f' · {med:.0f}s' if med is not None else ''}</span></td>")
            h.append("</tr>")
        h.append("</table>")
        if a["objectives"]:
            h.append("<details><summary>what each objective means</summary><ul class='small'>"
                     + "".join(f"<li><b>{e(o['name'])}</b> — {e(o['text'])}</li>" for o in a["objectives"]) + "</ul></details>")
        h.append("</div>")

    # Aims
    if a["aims"]:
        targets = sorted({k for tot in a["aims"].values() for k in tot})
        h.append("<h2>Aim accuracy</h2><div class='panel small'>made / tried, flips from a caught ball (beginners never aim)</div>"
                 "<div class='panel'><table><tr><th>pass</th><th>skill</th>" + "".join(f"<th>{e(t)}</th>" for t in targets) + "</tr>")
        for (p, s), tot in a["aims"].items():
            if s == "beginner":
                continue
            h.append(f"<tr><td>{e(p)}</td><td>{e(s)}</td>")
            for t in targets:
                if t in tot:
                    tried, made = tot[t]
                    pct = made / tried if tried else 0
                    cls = "c2" if pct >= 0.5 else "c1" if pct >= 0.2 else "c0"
                    h.append(f"<td><span class='cell {cls}'>{made}/{tried}</span></td>")
                else:
                    h.append("<td><span class='cell cn'>–</span></td>")
            h.append("</tr>")
        h.append("</table></div>")

    # Tracks
    if a["tracks"]:
        h.append("<h2>Shot tracks</h2><div class='panel small legend'>"
                 "<span style='background:var(--good)'></span>made &nbsp; <span style='background:var(--mid)'></span>miss &nbsp; "
                 "<span style='background:var(--bad)'></span>drain &nbsp; · one panel per flipper, world points, hover a path for skill → target</div>"
                 "<div class='panel'><table><tr><th>flipper</th><th>target</th><th>made</th><th>miss</th><th>drain</th></tr>")
        for fl, tg, made, miss, drain in a["track_rows"]:
            h.append(f"<tr><td>{e(fl)}</td><td>{e(tg)}</td><td>{made}</td><td>{miss}</td><td>{drain}</td></tr>")
        h.append("</table></div><div class='panel'>" + tracks_svg(a, map_file, map_rect, inline=True) + "</div>")

    # Drains (round 4b)
    if a["drain_rows"]:
        h.append("<h2>Drains</h2><div class='panel small'>every ball lost: median life since its plunge · lost within 6 s of a "
                 "full (≥ 0.9) or softer plunge · lost while the robot was catching/cradling or flipping an aimed shot · "
                 "median speed at the last sighting · a button held in the last second · how (from the path: outlane, "
                 "a raised tip clipped it, rolled off a tip, centre) · the last shot event before it</div>"
                 "<div class='panel'><table><tr><th>pass</th><th>skill</th><th>drains</th><th>per min</th><th>life</th><th>early · full</th>"
                 "<th>early · soft</th><th>catching</th><th>shooting</th><th>speed</th><th>button held</th><th>how</th><th>last event before</th></tr>")
        for r in a["drain_rows"]:
            h.append(f"<tr><td>{e(r['pass_'])}</td><td>{e(r['skill'])}</td><td>{r['n']}</td><td>{r['per_min']:.1f}</td><td>{r['life']:.1f}s</td>"
                     f"<td>{r['early_full']}</td><td>{r['early_soft']}</td><td>{r['catching']}</td><td>{r['shooting']}</td>"
                     f"<td>{r['speed']:.0f}</td><td>{r['held']}</td><td>{e(r['kinds'])}</td><td>{e(r['fed'])}</td></tr>")
        h.append("</table></div>")

    # Incidents
    h.append(f"<h2>Watchdog</h2><div class='panel'>{len(a['incidents'])} incident(s)")
    if a["incidents"]:
        h.append("<table><tr><th>pass</th><th>skill</th><th>kind</th><th>where</th><th>layer</th><th>t</th></tr>" + "".join(
            f"<tr><td>{e(p)}</td><td>{e(s)}</td><td>{e(i['kind'])}</td><td>({i['x']:.0f}, {i['y']:.0f})</td>"
            f"<td>{'upper' if i['upper'] else 'floor'}</td><td>{i['time']:.0f}s</td></tr>" for p, s, i in a["incidents"]) + "</table>")
    h.append("</div>")

    # Screenshots (relative to the HTML, which sits beside the JSON and the folder)
    if a["captures"]:
        h.append(f"<h2>Screenshots</h2><div class='panel small'>{len(a['captures'])} pictures in {e(stem)}/ · the first time each objective "
                 "was reached, every incident, the end of each game</div><div class='gal'>")
        for gi, p, s, c in a["captures"]:
            src = f"{stem}/{c['file']}"
            h.append(f"<figure><a href='{e(src)}'><img loading='lazy' src='{e(src)}' alt='{e(c['reason'])}'></a>"
                     f"<figcaption>g{gi + 1} {e(s)} · {e(c['reason'])} · {c['at']:.0f}s</figcaption></figure>")
        h.append("</div>")

    # Banners and shots
    h.append("<h2>Banners and shots</h2><div class='panel'><details open><summary>banners (whole run)</summary><table>"
             + "".join(f"<tr><td>{e(k)}</td><td>{n}</td></tr>" for k, n in a["banners"].most_common()) + "</table></details>"
             "<p class='small'>shots: " + ", ".join(f"{e(k)} {n}" for k, n in a["shots"].most_common()) + "</p></div>")
    h.append("</main></body></html>")
    open(out_path, "w").write("\n".join(h))


# ---------------------------------------------------------------- main

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--checks", nargs="*", default=[])
    ap.add_argument("--precise", nargs="*", default=[], help="shots meant to be hard: an expert rate under 15% is noted, not flagged")
    ap.add_argument("--tracks", help="write the shot tracks as this SVG file")
    ap.add_argument("--html", nargs="?", const="", help="write the report as an HTML page (default: <stem>.html beside the JSON)")
    ap.add_argument("--map", help="a table picture to draw the tracks over")
    ap.add_argument("--map-rect", nargs=4, type=float, metavar=("X", "Y", "W", "H"), default=[-40, -75, 680, 1405],
                    help="the world rect the picture covers (default: the 600x1300 tables' full art rect)")
    args = ap.parse_args()
    data = json.load(open(args.report))
    analysis = analyze(data, precise=set(args.precise))
    print_text(data, analysis, args.report, args.checks)
    if args.tracks:
        open(args.tracks, "w").write(tracks_svg(analysis, args.map, args.map_rect))
        print(f"\nTracks drawn to {args.tracks}")
    if args.html is not None:
        out = args.html or os.path.splitext(args.report)[0] + ".html"
        write_html(data, analysis, args.report, out, args.checks, args.map, args.map_rect)
        print(f"HTML report: {out}")
