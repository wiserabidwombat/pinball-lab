#!/usr/bin/env python3
"""Play Lab plan 2, round 12: which robot do YOU play like?

    python3 tools/playlab_calibrate.py ShotLab/playlab-monsoon-<stamp>.json            # your "Record me" report
    python3 tools/playlab_calibrate.py <your report> <robot report> [<robot report>…]   # against these robot runs

Your report is one written by the pause card's "Record me" button (its game's skill is "you"). The robot reports
default to the newest ShotLab/playlab-<same table>-*.json files (newest first) until every skill has at least
4 games at your pass (hz120 / hz60); give them explicitly to compare against a particular run.

What is compared, per minute of play unless said otherwise: catches, drains (and the median ball life), shots made
(the table's shot events — orbits, ramps, lanes… — not bumpers/slings), score, and lane taps/nudges where you and
the robots both have them. Each measure is scored as a z-distance against the four robots' spread, the nearest
robot wins, and the end of the report says what PlaySkill settings would stand in for you (timing sigma and catch
chance interpolated between the two nearest robots) — paste those into a PlaySkill case when a "custom" skill
exists (not yet: PlaySkill is an exhaustive enum in several switches, so adding a case is its own round)."""
import glob
import json
import os
import statistics
import sys

SKILLS = ["beginner", "intermediate", "advanced", "expert"]
SIGMA = {"beginner": 0.040, "intermediate": 0.025, "advanced": 0.015, "expert": 0.008}
CATCH = {"beginner": 0.0, "intermediate": 0.4, "advanced": 0.8, "expert": 0.95}
NOISE = {"bumper", "sling", "dustDevil", "spinner", "captive"}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def measures(games):
    """Per-minute rates over a list of games (pooled), plus the median ball life."""
    minutes = sum(g.get("seconds", 0) for g in games) / 60 or 1e-9
    drains = [d for g in games for d in g.get("drains", [])]
    shots = sum(n for g in games for k, n in g.get("shots", {}).items() if k not in NOISE)
    lives = [d["life"] for d in drains if "life" in d]
    return {
        "catches/min": sum(g.get("catches", 0) for g in games) / minutes,
        "drains/min": len(drains) / minutes,
        "ball life s": statistics.median(lives) if lives else 0.0,
        "shots/min": shots / minutes,
        "score/min": sum(g.get("score", 0) for g in games) / minutes / 1000,   # thousands
        "lane taps/min": sum(g.get("laneTaps", 0) for g in games) / minutes,
        "nudges/min": sum(g.get("nudges", 0) for g in games) / minutes,
        "minutes": minutes,
        "games": len(games),
    }


def main(argv):
    if not argv:
        sys.exit(__doc__)
    you = load(argv[0])
    mine = [g for g in you["games"] if g.get("skill") == "you"]
    if not mine:
        sys.exit(f"{argv[0]}: no game with skill 'you' — is this a Record me report?")
    pass_ = mine[0].get("pass", "hz120")
    table = you.get("table", "?")

    robot_games = {s: [] for s in SKILLS}
    sources = []
    if len(argv) > 1:
        paths = argv[1:]
    else:
        folder = os.path.dirname(os.path.abspath(argv[0]))
        slug = os.path.basename(argv[0]).split("-20")[0]          # playlab-<table>
        paths = sorted(glob.glob(os.path.join(folder, slug + "-*.json")), reverse=True)
        paths = [p for p in paths if os.path.abspath(p) != os.path.abspath(argv[0]) and not p.endswith("-sweep.json")]
    for p in paths:
        try:
            d = load(p)
        except Exception:
            continue
        got = False
        for g in d.get("games", []):
            s = g.get("skill")
            if s in robot_games and g.get("pass") == pass_ and (len(argv) > 1 or len(robot_games[s]) < 4):
                robot_games[s].append(g)
                got = True
        if got:
            sources.append(os.path.basename(p))
        if len(argv) == 1 and all(len(v) >= 4 for v in robot_games.values()):
            break
    missing = [s for s in SKILLS if not robot_games[s]]
    if missing:
        sys.exit(f"no robot games at {pass_} for {', '.join(missing)} in {', '.join(sources) or 'no reports'}")

    m_you = measures(mine)
    m_rob = {s: measures(robot_games[s]) for s in SKILLS}
    keys = ["catches/min", "drains/min", "ball life s", "shots/min", "score/min"]
    for k in ("lane taps/min", "nudges/min"):
        if m_you[k] > 0 and any(m_rob[s][k] > 0 for s in SKILLS):
            keys.append(k)

    print(f"{table} · you: {m_you['games']} game(s), {m_you['minutes']:.1f} min at {pass_} ({os.path.basename(argv[0])})")
    print(f"robots: {', '.join(sources)} — games per skill: " + ", ".join(f"{s} {m_rob[s]['games']}" for s in SKILLS))
    print()
    print(f"{'measure':16}{'you':>9}" + "".join(f"{s:>13}" for s in SKILLS) + "   nearest")
    dist = {s: 0.0 for s in SKILLS}
    for k in keys:
        vals = [m_rob[s][k] for s in SKILLS]
        spread = statistics.pstdev(vals) or (abs(statistics.mean(vals)) * 0.25 or 1.0)
        near_k = min(SKILLS, key=lambda s: abs(m_you[k] - m_rob[s][k]))
        line = f"{k:16}{m_you[k]:>9.2f}" + "".join(f"{v:>13.2f}" for v in vals) + f"   {near_k}"
        if k == "score/min":
            line += "  (shown, not scored: the robots loop for points)"
        print(line)
        if k == "score/min":
            continue
        for s in SKILLS:
            dist[s] += ((m_you[k] - m_rob[s][k]) / spread) ** 2
    order = sorted(SKILLS, key=lambda s: dist[s])
    print()
    print("distance        " + "".join(f"{dist[s] ** 0.5:>13.2f}" for s in SKILLS))
    nearest, second = order[0], order[1]
    print(f"\nYou play most like the {nearest.upper()} robot (then {second}).")
    # The two halves of pinball, said plainly: keeping the ball, and working it.
    keep = min(SKILLS, key=lambda s: abs(m_you["drains/min"] - m_rob[s]["drains/min"]) / (m_rob[s]["drains/min"] or 1)
               + abs(m_you["ball life s"] - m_rob[s]["ball life s"]) / (m_rob[s]["ball life s"] or 1))
    work = min(SKILLS, key=lambda s: abs(m_you["catches/min"] - m_rob[s]["catches/min"]) / (m_rob[s]["catches/min"] or 1)
               + abs(m_you["shots/min"] - m_rob[s]["shots/min"]) / (m_rob[s]["shots/min"] or 1))
    best_keep = min(SKILLS, key=lambda s: m_rob[s]["drains/min"])
    better = " — better than every robot" if m_you["drains/min"] < m_rob[best_keep]["drains/min"] else ""
    print(f"Keeping the ball (drains/min, ball life): like the {keep}{better}. "
          f"Working it (catches/min, shots/min): like the {work}.")

    # A stand-in skill: interpolate between the two nearest robots by their distances.
    d0, d1 = dist[nearest] ** 0.5, dist[second] ** 0.5
    w = d1 / (d0 + d1) if d0 + d1 > 0 else 1.0           # weight on the nearest
    sigma = w * SIGMA[nearest] + (1 - w) * SIGMA[second]
    catch = w * CATCH[nearest] + (1 - w) * CATCH[second]
    print(f"A stand-in robot for you: timingSigma {sigma:.3f} s, catchChance {catch:.2f}"
          f" (between {nearest} and {second}; aims = {'yes' if nearest in ('advanced', 'expert') else 'no'}).")
    if m_you["minutes"] < 6:
        print("(Under 6 minutes of play — record a couple more games before trusting this.)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
