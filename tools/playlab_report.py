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
import json, sys, argparse, collections, statistics, os, html, math, random

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


# ---------------------------------------------------------------- bands (plan 2, round 2)
# Two games per cell swing a lot. Every headline number carries a 95 % band so a change is only read as a change when
# it is bigger than the band. Score and drains/min: bootstrap over games (resample the games of a cell with
# replacement, 500 times, take the 2.5 and 97.5 percentiles); ball life: the same over the drains; aim rates: Wilson.

def boot(fn, items, reps=500, seed=7):
    """(lo, hi) of fn(resampled items), or (None, None) when there is nothing to resample."""
    if not items:
        return (None, None)
    rng = random.Random(seed)
    vals = []
    for _ in range(reps):
        pick = [items[rng.randrange(len(items))] for _ in items]
        v = fn(pick)
        if v is not None:
            vals.append(v)
    if not vals:
        return (None, None)
    vals.sort()
    return vals[int(0.025 * len(vals))], vals[min(len(vals) - 1, int(0.975 * len(vals)))]


def rate_band(gs):
    """Drains per minute over games gs, with a 95 % band: the bootstrap over games widened by the Poisson band (so one
    game still gets a band). Returns (rate, lo, hi)."""
    n = sum(len(g.get("drains", [])) for g in gs)
    minutes = sum(g["seconds"] for g in gs) / 60
    if not minutes:
        return (0, 0, 0)
    rate = n / minutes
    lo, hi = boot(lambda pick: sum(len(g.get("drains", [])) for g in pick) / (sum(g["seconds"] for g in pick) / 60)
                  if sum(g["seconds"] for g in pick) else None, gs)
    plo, phi = max(0, n - 1.96 * math.sqrt(n)) / minutes, (n + 1.96 * math.sqrt(n)) / minutes
    return (rate, min(plo, lo if lo is not None else plo), max(phi, hi if hi is not None else phi))


def wilson(k, n, z=1.96):
    """95 % band on a share k/n."""
    if not n:
        return (0, 1)
    p = k / n
    den = 1 + z * z / n
    mid = (p + z * z / (2 * n)) / den
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (max(0, mid - half), min(1, mid + half))


def pm(v, lo, hi, digits=1):
    """'1.4 ±0.5' (the half-width of the band)."""
    if lo is None or hi is None:
        return f"{v:.{digits}f}"
    return f"{v:.{digits}f} ±{(hi - lo) / 2:.{digits}f}"


def build_line(d):
    """'c6650e8 · clean · main · 2026-10-23 21:10 · 1.0 (12) · simulator iPhone 17 Pro Max', or what an older report has."""
    b = d.get("build")
    if not b:
        return "unknown (report predates build identity)"
    parts = [b.get("id") or "no runner id (phone build?)", b.get("bundleVersion", ""), "built " + b.get("builtAt", "?"),
             b.get("device", "")]
    return " · ".join(p for p in parts if p)


def build_key(d):
    """The part of the build identity two reports must share to be comparable: the runner id, else the build time."""
    b = d.get("build") or {}
    return b.get("id") or b.get("builtAt") or "unknown"


FEED_KEYS = ["aim", "none", "raise", "caught", "launched", "dropped"]


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
                slo, shi = boot(lambda pick: mean([g["score"] for g in pick]), gs) if len(gs) >= 2 else (None, None)
                rows.append(dict(pass_=p, skill=s, games=len(gs), score=mean([g["score"] for g in gs]), score_lo=slo, score_hi=shi,
                                 minutes=mean([g["seconds"] for g in gs]) / 60, balls=mean([g["ballsPlayed"] for g in gs]),
                                 catches=mean([g["catches"] for g in gs]),
                                 lane_taps=mean([g.get("laneTaps", 0) for g in gs]),
                                 nudges=mean([g.get("nudges", 0) for g in gs]),
                                 tilts=mean([g.get("tilts", 0) for g in gs]),
                                 bounces=mean([g.get("bounces", 0) for g in gs]),
                                 traps=mean([g.get("traps", 0) for g in gs]),
                                 live=mean([g.get("liveCatches", 0) for g in gs]),
                                 feeds={k: mean([g.get("feeds", {}).get(k, 0) for g in gs]) for k in FEED_KEYS},
                                 extras={k: mean([g.get("extras", {}).get(k, 0) for g in gs]) for k in extras},
                                 ends=[g["endedBy"] for g in gs]))

    # Objective grid: (name, pass, skill) → (share, median seconds, games that reached it, games)
    grid = {}
    for name in names:
        for p in passes:
            for s in SKILLS:
                gs = by.get((p, s), [])
                if not gs:
                    continue
                hit = [g["objectives"][name] for g in gs if name in g.get("objectives", {})]
                grid[(name, p, s)] = (len(hit) / len(gs), median(hit) if hit else None, len(hit), len(gs))

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
            per_min, pm_lo, pm_hi = rate_band(by.get((p, sk), []))
            life_lo, life_hi = boot(lambda pick: median([dr["life"] for dr in pick]), ds)
            drain_rows.append(dict(
                fed=", ".join(f"{k} {n}" for k, n in fed.most_common(3)), per_min=per_min, per_min_lo=pm_lo, per_min_hi=pm_hi,
                kinds=", ".join(f"{k} {n}" for k, n in kinds.most_common()), held=held, games=len(by.get((p, sk), [])),
                pass_=p, skill=sk, n=len(ds), life=median([dr["life"] for dr in ds]), life_lo=life_lo, life_hi=life_hi,
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

    # Round 7a: the plunge sweep — per pass, power → what the plunges did.
    plunge_rows = []
    for p in passes:
        by_power = collections.defaultdict(list)
        for g in games:
            if g["pass"] == p:
                for pl in g.get("plunges", []):
                    by_power[pl["power"]].append(pl)
        for power in sorted(by_power):
            pls = by_power[power]
            plunge_rows.append(dict(
                pass_=p, power=power, n=len(pls),
                events=collections.Counter(pl["event"] or "(none)" for pl in pls),
                lanes=collections.Counter(pl["lane"] for pl in pls),
                skill=sum(1 for pl in pls if pl["skillShot"]), drained=sum(1 for pl in pls if pl["drained"]),
                peak=median([pl["peakY"] for pl in pls])))
    # The power bands per lane: runs of consecutive powers whose plunges mostly (≥ half) crossed that lane.
    plunge_bands = []
    for p in passes:
        prows = [r for r in plunge_rows if r["pass_"] == p]
        lanes = sorted({l for r in prows for l in r["lanes"] if l >= 0})
        for lane in lanes:
            run = []
            for r in prows + [None]:
                hit = r is not None and r["lanes"][lane] * 2 >= r["n"]
                if hit:
                    run.append(r)
                elif run:
                    plunge_bands.append((p, lane, run[0]["power"], run[-1]["power"], sum(x["lanes"][lane] for x in run), sum(x["n"] for x in run)))
                    run = []

    # Tightness: the widest drains/min half-width among the advanced/expert rows — what `--tightness` and the sweep's
    # UNTIL_TIGHT loop look at. A cell with no drains yet counts as untight (inf).
    tight = [(r["per_min_hi"] - r["per_min_lo"]) / 2 for r in drain_rows if r["skill"] in ("advanced", "expert")]
    good_cells = [(p, s) for p in passes for s in ("advanced", "expert") if by.get((p, s))]
    tightness = max(tight) if tight and len(tight) == len(good_cells) else float("inf")

    return dict(games=games, passes=passes, objectives=objectives, names=names, extras=extras, rows=rows, grid=grid,
                tightness=tightness, plunge_rows=plunge_rows, plunge_bands=plunge_bands,
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


# ---------------------------------------------------------------- heat maps (round 13)

SKILL_COLOR = {"beginner": "#4f8dd6", "intermediate": "#3fc1c9", "advanced": "#f2c14e", "expert": "#ffffff", "you": "#ff7ac6"}
FLIPPER_LINE_Y = 190      # just above the resting tips on the 600x1300 tables: below it the ball is on its way out


def lost_point(path):
    """Where a drain path last crossed the flipper line heading down (the point of no return), else its last point."""
    pts = [(q[0], q[1]) for q in path]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if y0 >= FLIPPER_LINE_Y > y1 and y0 != y1:
            t = (y0 - FLIPPER_LINE_Y) / (y0 - y1)
            return (x0 + (x1 - x0) * t, FLIPPER_LINE_Y)
    return pts[-1]


def heat_svg(a, map_file=None, map_rect=(-40, -75, 680, 1405), inline=False):
    """Two panels per pass: where balls were lost (by skill) and where aimed shots ended (by outcome)."""
    X, Y, W, H = map_rect
    passes = a["passes"]
    drains = [(p, sk, dr) for p, sk, dr in a.get("drains", []) if len(dr.get("path", [])) >= 2]
    tracks = [(p, sk, t) for p, sk, t in a.get("tracks", []) if len(t.get("points", [])) >= 1]
    panels = [(p, kind) for p in passes for kind in ("lost", "shots")]
    if not drains and not tracks:
        return ""
    panel_w, gap = W, 60
    attrs = 'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'
    style = ' style="width:100%;height:auto"' if inline else ''
    out = [f'<svg {attrs} viewBox="0 0 {len(panels) * (panel_w + gap)} {H + 60}" font-family="Helvetica, Arial" '
           f'font-size="22"{style}>', "<defs>"]
    for name, color in list(SKILL_COLOR.items()) + [("made", OUTCOME_COLOR.get("made", "#4caf50")),
                                                   ("miss", OUTCOME_COLOR.get("miss", "#9e9e9e")),
                                                   ("drain", OUTCOME_COLOR.get("drain", "#d1403a"))]:
        out.append(f'<radialGradient id="heat-{name}"><stop offset="0" stop-color="{color}" stop-opacity="0.55"/>'
                   f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>')
    out.append("</defs>")
    for i, (p, kind) in enumerate(panels):
        ox = i * (panel_w + gap)
        out.append(f'<g transform="translate({ox},0)">')
        out.append(f'<rect x="0" y="40" width="{W}" height="{H}" fill="#101010"/>')
        if map_file:
            out.append(f'<image xlink:href="{html.escape(map_file)}" x="0" y="40" width="{W}" height="{H}" opacity="0.6"/>')
        out.append(f'<rect x="{0 - X}" y="{40 + (Y + H - 1300)}" width="600" height="1300" fill="none" stroke="#555" stroke-width="2"/>')
        fg = "#ddd" if inline else "#222"
        if kind == "lost":
            items = [(sk, lost_point(dr["path"]), f"{sk} at {dr['at']:.0f}s") for pp, sk, dr in drains if pp == p]
            out.append(f'<text x="8" y="28" fill="{fg}">{p} · where balls were lost · {len(items)} · '
                       'beginner blue, intermediate teal, advanced yellow, expert white</text>')
            for sk, (x, y), tip in items:
                out.append(f'<circle cx="{x - X:.0f}" cy="{40 + (Y + H - y):.0f}" r="34" fill="url(#heat-{sk if sk in SKILL_COLOR else "expert"})"><title>{tip}</title></circle>')
        else:
            items = [(t["outcome"], t["points"][-1], f"{sk} → {t['target']}: {t['outcome']}") for pp, sk, t in tracks if pp == p]
            out.append(f'<text x="8" y="28" fill="{fg}">{p} · where aimed shots ended · {len(items)} · made green, miss grey, drain red</text>')
            for oc, (x, y), tip in items:
                key = oc if oc in ("made", "miss", "drain") else "miss"
                out.append(f'<circle cx="{x - X:.0f}" cy="{40 + (Y + H - y):.0f}" r="30" fill="url(#heat-{key})"><title>{tip}</title></circle>')
        out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)


# ---------------------------------------------------------------- time-to-objective curves (round 14)

def curves_svg(a, skills=SKILLS, inline=False, panel_w=300, panel_h=170, per_row=4):
    """One small panel per objective: the share of games (per pass × skill) that have reached it by t seconds.
    Step lines: hz120 solid, hz60 dashed, skill colours as the heat maps. A tick marks the median first reach."""
    names = a["names"]
    games = [g for g in a["games"] if g["skill"] in skills]
    if not names or not games:
        return ""
    passes = a["passes"]
    t_end = max(60.0, math.ceil(max(g.get("seconds", 0) for g in games) / 60.0) * 60.0)
    by = collections.defaultdict(list)
    for g in games:
        by[(g["pass"], g["skill"])].append(g)
    rows = (len(names) + per_row - 1) // per_row
    cols = min(per_row, len(names))
    attrs = 'xmlns="http://www.w3.org/2000/svg"'
    style = f' style="width:100%;height:auto;max-width:{cols * panel_w + 40}px"' if inline else ''
    W, H = cols * panel_w, rows * panel_h + 26
    out = [f'<svg {attrs} viewBox="0 0 {W} {H}" font-family="Helvetica, Arial" font-size="11"{style}>',
           f'<rect x="0" y="0" width="{W}" height="{H}" fill="#101010"/>']
    # Legend
    lx = 8
    for s in skills:
        out.append(f'<line x1="{lx}" y1="13" x2="{lx + 18}" y2="13" stroke="{SKILL_COLOR.get(s, "#fff")}" stroke-width="2.5"/>'
                   f'<text x="{lx + 22}" y="17" fill="#bbb">{s}</text>')
        lx += 30 + 7 * len(s)
    for p, dash in (("hz120", ""), ("hz60", ' stroke-dasharray="5,4"')):
        if p in passes:
            out.append(f'<line x1="{lx}" y1="13" x2="{lx + 22}" y2="13" stroke="#bbb" stroke-width="2"{dash}/>'
                       f'<text x="{lx + 26}" y="17" fill="#bbb">{p}</text>')
            lx += 70
    if W - lx > 420:
        out.append(f'<text x="{W - 8}" y="17" fill="#888" text-anchor="end">share of games that have reached the objective by t · '
                   f'tick = median first reach</text>')
    ml, mr, mt, mb = 30, 10, 22, 22          # margins inside a panel
    pw, ph = panel_w - ml - mr, panel_h - mt - mb
    for i, name in enumerate(names):
        ox, oy = (i % per_row) * panel_w, 26 + (i // per_row) * panel_h
        out.append(f'<g transform="translate({ox},{oy})">')
        out.append(f'<text x="{ml}" y="14" fill="#ddd" font-weight="bold">{html.escape(name)}</text>')
        out.append(f'<rect x="{ml}" y="{mt}" width="{pw}" height="{ph}" fill="#161616" stroke="#333"/>')
        for frac, lab in ((0.0, "0"), (0.5, "50%"), (1.0, "100%")):
            y = mt + ph - frac * ph
            out.append(f'<line x1="{ml}" y1="{y:.1f}" x2="{ml + pw}" y2="{y:.1f}" stroke="#2a2a2a"/>'
                       f'<text x="{ml - 3}" y="{y + 3.5:.1f}" fill="#777" text-anchor="end" font-size="9">{lab}</text>')
        t = 0.0
        while t <= t_end:
            x = ml + pw * t / t_end
            out.append(f'<line x1="{x:.1f}" y1="{mt}" x2="{x:.1f}" y2="{mt + ph}" stroke="#2a2a2a"/>'
                       f'<text x="{x:.1f}" y="{mt + ph + 11}" fill="#777" text-anchor="middle" font-size="9">{t:.0f}s</text>')
            t += 120.0 if t_end > 400 else 60.0
        for p in passes:
            dash = ' stroke-dasharray="5,4"' if p != "hz120" else ""
            for s in skills:
                gs = by.get((p, s), [])
                if not gs:
                    continue
                times = sorted(g["objectives"][name] for g in gs if name in g.get("objectives", {}))
                n = len(gs)
                pts = [(ml, mt + ph)]
                for k, tt in enumerate(times, 1):
                    x = ml + pw * min(tt, t_end) / t_end
                    y = mt + ph - ph * k / n
                    pts.append((x, pts[-1][1]))      # step: across, then up
                    pts.append((x, y))
                pts.append((ml + pw, pts[-1][1]))
                color = SKILL_COLOR.get(s, "#fff")
                med = median(times) if times else None
                tip = f"{p} {s}: {len(times)}/{n} games" + (f", median {med:.0f}s" if med is not None else "")
                out.append(f'<polyline points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="none" stroke="{color}" '
                           f'stroke-width="2" stroke-opacity="0.9"{dash}><title>{html.escape(tip)}</title></polyline>')
                if med is not None:
                    x = ml + pw * min(med, t_end) / t_end
                    y = mt + ph - ph * (len(times) / n) / 2
                    out.append(f'<line x1="{x:.1f}" y1="{y - 5:.1f}" x2="{x:.1f}" y2="{y + 5:.1f}" stroke="{color}" stroke-width="2"/>')
        out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)


# ---------------------------------------------------------------- text

def print_text(d, a, report_path, checks):
    games, passes, extras = a["games"], a["passes"], a["extras"]
    print(f"{d['table']} · {d['date']} · {len(games)} games · {d['fps']} fps · passes {', '.join(passes)}")
    print(f"build: {build_line(d)}")
    print(f"\n{'pass':7}{'skill':13}{'games':>6}{'score':>10}{'min':>6}{'balls':>6}{'catch':>6}{'lanes':>6}{'nudge':>6}{'tilt':>5}{'bounce':>7}{'trap':>5}{'live':>5}"
          + "".join(f"{k[:7]:>8}" for k in extras) + "  end")
    for r in a["rows"]:
        print(f"{r['pass_']:7}{r['skill']:13}{r['games']:>6}{r['score']:>10,.0f}{r['minutes']:>6.1f}{r['balls']:>6.1f}"
              f"{r['catches']:>6.1f}{r['lane_taps']:>6.1f}{r['nudges']:>6.1f}{r['tilts']:>5.1f}{r['bounces']:>7.1f}{r['traps']:>5.1f}{r['live']:>5.1f}" + "".join(f"{r['extras'][k]:>8.1f}" for k in extras)
              + "  " + ",".join(e[:4] for e in r["ends"])
              + (f"  score ±{(r['score_hi'] - r['score_lo']) / 2:,.0f}" if r["score_lo"] is not None else ""))
    if a["names"]:
        print("\nObjectives reached (games that reached it / games · median seconds to the first):")
        print(f"{'objective':15}" + "".join(f"{p + ' ' + s[:3]:>12}" for p in passes for s in SKILLS))
        for name in a["names"]:
            row = f"{name:15}"
            for p in passes:
                for s in SKILLS:
                    cell = a["grid"].get((name, p, s))
                    if cell is None:
                        row += f"{'-':>12}"
                    else:
                        share, med, k, n = cell
                        row += f"{f'{k}/{n} {med:4.0f}s' if med is not None else f'{k}/{n}      ':>12}"
            print(row)
        for o in a["objectives"]:
            print(f"  {o['name']:15} {o['text']}")
    if any(any(r["feeds"].values()) for r in a["rows"]):
        print("\nFeeds per game (round 9b: inlane feeds · aim = flipped live at the wanted shot · none = flipped at mid-face"
              " · raise = raised into a catch at 38 pt → caught / launched up the table / dropped):")
        print(f"  {'pass':7}{'skill':13}" + "".join(f"{k:>9}" for k in FEED_KEYS))
        for r in a["rows"]:
            print(f"  {r['pass_']:7}{r['skill']:13}" + "".join(f"{r['feeds'][k]:>9.1f}" for k in FEED_KEYS))
        # Round 9c′: where the raises were made — along the face (pt from the pivot) and the ball's speed at the press,
        # caught vs launched, so a late press shows as a short along / fast ball.
        lines = []
        by = collections.defaultdict(list)
        for g in a["games"]:
            by[(g["pass"], g["skill"])].append(g)
        for (p, s), gs in sorted(by.items(), key=lambda kv: (pass_order(kv[0][0]), SKILLS.index(kv[0][1]) if kv[0][1] in SKILLS else 9)):
            rs = [x for g in gs for x in g.get("feedRaises", [])]
            if not rs:
                continue
            parts = []
            for code, name in ((1, "caught"), (2, "launched"), (3, "dropped")):
                sel = [x for x in rs if len(x) >= 3 and x[2] == code]
                if sel:
                    parts.append(f"{name} {len(sel)}: along {median([x[0] for x in sel]):.0f} ({min(x[0] for x in sel):.0f}–{max(x[0] for x in sel):.0f}) · speed {median([x[1] for x in sel]):.0f}")
            lines.append(f"  {p:7}{s:13}" + "  |  ".join(parts))
        if lines:
            print("Raises: along at the press (pt from the pivot, median and range) · ball speed at the press (pt/s):")
            print("\n".join(lines))
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
            print(f"  {r['pass_']:7}{r['skill']:13}{r['n']:3} drains ({pm(r['per_min'], r['per_min_lo'], r['per_min_hi'])}/min)  life {pm(r['life'], r['life_lo'], r['life_hi'])}s  early full {r['early_full']:2} soft {r['early_soft']:2}"
                  f"  catching {r['catching']:2}  shooting {r['shooting']:2}  speed {r['speed']:4.0f}  held {r['held']:2}"
                  f"  how: {r['kinds']}  fed by: {r['fed']}")
        print(f"  bands are 95 % (bootstrap over games / drains); widest advanced/expert drains/min half-width: "
              + (f"±{a['tightness']:.2f}" if a["tightness"] != float("inf") else "n/a (a good robot has no drains yet)"))
    if a["plunge_rows"]:
        print("\nPlunge sweep (power → first event · top lane crossed · skill shots · drained · median peak y):")
        for r in a["plunge_rows"]:
            ev = ", ".join(f"{k} {n}" for k, n in r["events"].most_common())
            ln = ", ".join(f"lane {k} ×{n}" if k >= 0 else f"no lane ×{n}" for k, n in sorted(r["lanes"].items()))
            print(f"  {r['pass_']:7}{r['power']:5.2f}  n {r['n']:2}  {ev:40}  {ln:34}  skill {r['skill']}  drained {r['drained']}  peak {r['peak']:.0f}")
        if a["plunge_bands"]:
            print("  Bands (powers whose plunges mostly crossed the lane):")
            for p, lane, lo, hi, made, n in a["plunge_bands"]:
                print(f"    {p:7}lane {lane}: {lo:.2f}–{hi:.2f} ({made}/{n})")
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
.unc{opacity:.55;border:1px dashed var(--dim)}
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
             f"passes {', '.join(e(p) for p in passes)} · cap {d.get('maxGameSeconds', 480):.0f} s/game</div>"
             f"<div class='sub' title='which build played: git hash · dirty files · branch · built when · where it ran'>"
             f"build {e(build_line(d))}</div>")

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
             "<th title='nudges the robot made (round 8b: advanced/expert shove a ball heading for an outlane or the centre gap)'>nudges</th>"
             "<th title='TILT banners: a third nudge within 3 s, flippers dead for the rest of that ball'>tilts</th>"
             "<th title='dead bounces (round 9: the expert lets a fast crossing ball hit the resting flipper and go across)'>bounces</th>"
             "<th title='multiball traps (round 11: the expert holds one ball on a flipper while another is loose)'>traps</th>"
             "<th title='live catches (round 9b: inlane feeds flipped on the fly at the inlane Shot Lab window)'>live</th>"
             + "".join(f"<th>{e(k)}</th>" for k in extras) + "<th>ended by</th></tr>")
    for r in a["rows"]:
        h.append(f"<tr><td>{e(r['pass_'])}</td><td>{e(r['skill'])}</td><td>{r['games']}</td><td>{r['score']:,.0f}"
                 + (f"<div class='small'>±{(r['score_hi'] - r['score_lo']) / 2:,.0f}</div>" if r["score_lo"] is not None else "") + "</td>"
                 f"<td>{r['minutes']:.1f}</td><td>{r['balls']:.1f}</td><td>{r['catches']:.1f}</td><td>{r['lane_taps']:.1f}</td>"
                 f"<td>{r['nudges']:.1f}</td><td>{r['tilts']:.1f}</td><td>{r['bounces']:.1f}</td><td>{r['traps']:.1f}</td><td>{r['live']:.1f}</td>"
                 + "".join(f"<td>{r['extras'][k]:.1f}</td>" for k in extras)
                 + f"<td>{e(', '.join(r['ends']))}</td></tr>")
    h.append("</table></div>")

    # Objective grid
    if a["names"]:
        h.append("<h2>Objectives</h2><div class='panel small'>games that reached the objective / games played · median seconds to the first time</div>"
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
                        share, med, k, n = cell
                        cls = "c2" if share >= 0.75 else "c1" if share > 0 else ("c0" if s in ("advanced", "expert") else "cn")
                        h.append(f"<td><span class='cell {cls}' title='{share:.0%} of games'>{k}/{n}{f' · {med:.0f}s' if med is not None else ''}</span></td>")
            h.append("</tr>")
        h.append("</table>")
        if a["objectives"]:
            h.append("<details><summary>what each objective means</summary><ul class='small'>"
                     + "".join(f"<li><b>{e(o['name'])}</b> — {e(o['text'])}</li>" for o in a["objectives"]) + "</ul></details>")
        h.append("</div>")
        curves = curves_svg(a, inline=True)
        if curves:
            h.append("<h2>Time to objective</h2><div class='panel small'>round 14 · per objective, the share of games that have "
                     "reached it by t seconds — one step line per pass × skill (hz120 solid, hz60 dashed; beginner blue, "
                     "intermediate teal, advanced yellow, expert white), a tick at the median first reach; hover a line</div>"
                     "<div class='panel'>" + curves + "</div>")

    # Feeds (round 9b⁗)
    if any(any(r["feeds"].values()) for r in a["rows"]):
        h.append("<h2>Inlane feeds</h2><div class='panel small'>per game · aim = flipped live at the wanted shot's window · "
                 "none = flipped at mid-face · raise = raised into a catch at the cradle point (38 pt), then caught / "
                 "launched up the table / dropped</div><div class='panel'><table><tr><th>pass</th><th>skill</th>"
                 + "".join(f"<th>{k}</th>" for k in FEED_KEYS) + "</tr>")
        for r in a["rows"]:
            h.append(f"<tr><td>{e(r['pass_'])}</td><td>{e(r['skill'])}</td>"
                     + "".join(f"<td>{r['feeds'][k]:.1f}</td>" for k in FEED_KEYS) + "</tr>")
        h.append("</table></div>")

    # Aims
    if a["aims"]:
        targets = sorted({k for tot in a["aims"].values() for k in tot})
        h.append("<h2>Aim accuracy</h2><div class='panel small'>made / tried, flips from a caught ball (beginners never aim) · "
                 "hover for the 95 % band · dashed = too few tries to say (band wider than 50 points)</div>"
                 "<div class='panel'><table><tr><th>pass</th><th>skill</th>" + "".join(f"<th>{e(t)}</th>" for t in targets) + "</tr>")
        for (p, s), tot in a["aims"].items():
            if s == "beginner":
                continue
            h.append(f"<tr><td>{e(p)}</td><td>{e(s)}</td>")
            for t in targets:
                if t in tot:
                    tried, made = tot[t]
                    pct = made / tried if tried else 0
                    lo, hi = wilson(made, tried)
                    cls = "c2" if pct >= 0.5 else "c1" if pct >= 0.2 else "c0"
                    unc = " unc" if hi - lo > 0.5 else ""
                    h.append(f"<td><span class='cell {cls}{unc}' title='{pct:.0%}, 95 % band {lo:.0%}–{hi:.0%}'>{made}/{tried}</span></td>")
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
    heat = heat_svg(a, map_file, map_rect, inline=True)
    if heat:
        h.append("<h2>Heat maps</h2><div class='panel small'>round 13 · per pass: where balls were lost (the point where each "
                 "drain path crossed the flipper line, coloured by skill) and where aimed shots ended (coloured by outcome); "
                 "hover a blob</div><div class='panel'>" + heat + "</div>")

    # Drains (round 4b)
    if a["drain_rows"]:
        h.append("<h2>Drains</h2><div class='panel small'>every ball lost: median life since its plunge · lost within 6 s of a "
                 "full (≥ 0.9) or softer plunge · lost while the robot was catching/cradling or flipping an aimed shot · "
                 "median speed at the last sighting · a button held in the last second · how (from the path: outlane, "
                 "a raised tip clipped it, rolled off a tip, centre) · the last shot event before it · ± is half of a 95 % band</div>"
                 "<div class='panel'><table><tr><th>pass</th><th>skill</th><th>drains</th><th>per min</th><th>life</th><th>early · full</th>"
                 "<th>early · soft</th><th>catching</th><th>shooting</th><th>speed</th><th>button held</th><th>how</th><th>last event before</th></tr>")
        for r in a["drain_rows"]:
            h.append(f"<tr><td>{e(r['pass_'])}</td><td>{e(r['skill'])}</td><td>{r['n']}</td>"
                     f"<td title='95 % band (bootstrap over {r['games']} games, widened by Poisson)'>{pm(r['per_min'], r['per_min_lo'], r['per_min_hi'])}</td>"
                     f"<td title='95 % band (bootstrap over the drains)'>{pm(r['life'], r['life_lo'], r['life_hi'], 0)} s</td>"
                     f"<td>{r['early_full']}</td><td>{r['early_soft']}</td><td>{r['catching']}</td><td>{r['shooting']}</td>"
                     f"<td>{r['speed']:.0f}</td><td>{r['held']}</td><td>{e(r['kinds'])}</td><td>{e(r['fed'])}</td></tr>")
        h.append("</table></div>")

    # Plunge sweep (round 7a)
    if a["plunge_rows"]:
        h.append("<h2>Plunge sweep</h2><div class='panel small'>every served ball plunged at a scheduled power, no flipping: the first "
                 "shot event, which top lane the ball crossed first (the host's lanes, left to right from 0), SKILL SHOT fired, "
                 "drained within 4 s, and the median peak. Bands = runs of powers whose plunges mostly crossed a lane — the "
                 "numbers the robot's plunge-for-target table is pasted from.</div>"
                 "<div class='panel'><table><tr><th>pass</th><th>power</th><th>n</th><th>first event</th><th>lane</th><th>skill shot</th>"
                 "<th>drained</th><th>peak y</th></tr>")
        for r in a["plunge_rows"]:
            ev = ", ".join(f"{k} {n}" for k, n in r["events"].most_common())
            ln = ", ".join(f"{k} ×{n}" if k >= 0 else f"none ×{n}" for k, n in sorted(r["lanes"].items()))
            h.append(f"<tr><td>{e(r['pass_'])}</td><td>{r['power']:.2f}</td><td>{r['n']}</td><td style='text-align:left'>{e(ev)}</td>"
                     f"<td style='text-align:left'>{e(ln)}</td><td>{r['skill']}</td><td>{r['drained']}</td><td>{r['peak']:.0f}</td></tr>")
        h.append("</table>")
        if a["plunge_bands"]:
            h.append("<ul class='small'>" + "".join(f"<li>{e(p)} · lane {lane}: {lo:.2f}–{hi:.2f} ({made}/{n})</li>"
                                                      for p, lane, lo, hi, made, n in a["plunge_bands"]) + "</ul>")
        h.append("</div>")

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
    ap.add_argument("--heat", help="round 13: write the heat maps (balls lost / shot ends, per pass) as this SVG file")
    ap.add_argument("--curves", help="round 14: write the time-to-objective curves (all skills, both passes) as this SVG file")
    ap.add_argument("--html", nargs="?", const="", help="write the report as an HTML page (default: <stem>.html beside the JSON)")
    ap.add_argument("--map", help="a table picture to draw the tracks over")
    ap.add_argument("--tightness", action="store_true",
                    help="print only the widest advanced/expert drains/min half-width (inf if a good robot has no drains) and exit")
    ap.add_argument("--map-rect", nargs=4, type=float, metavar=("X", "Y", "W", "H"), default=[-40, -75, 680, 1405],
                    help="the world rect the picture covers (default: the 600x1300 tables' full art rect)")
    args = ap.parse_args()
    data = json.load(open(args.report))
    analysis = analyze(data, precise=set(args.precise))
    if args.tightness:
        print(f"{analysis['tightness']:.3f}" if analysis["tightness"] != float("inf") else "inf")
        sys.exit(0)
    print_text(data, analysis, args.report, args.checks)
    if args.tracks:
        open(args.tracks, "w").write(tracks_svg(analysis, args.map, args.map_rect))
        print(f"\nTracks drawn to {args.tracks}")
    if args.heat:
        open(args.heat, "w").write(heat_svg(analysis, args.map, args.map_rect))
        print(f"\nHeat maps drawn to {args.heat}")
    if args.curves:
        open(args.curves, "w").write(curves_svg(analysis))
        print(f"\nTime-to-objective curves drawn to {args.curves}")
    if args.html is not None:
        out = args.html or os.path.splitext(args.report)[0] + ".html"
        write_html(data, analysis, args.report, out, args.checks, args.map, args.map_rect)
        print(f"HTML report: {out}")
