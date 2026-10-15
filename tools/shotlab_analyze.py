"""Shot Lab analysis: timing windows → hit odds for human players.
Model: a player aims a flip at some moment after dropping the flipper; their actual flip lands
with Gaussian timing error (sigma) and then on the next frame, like the robot's. P(shot) =
sum over measured flips of P(the player's flip lands nearest that flip) x [it made the shot].
The player is assumed to aim at the best moment for that shot (an upper bound for that skill level).
Usage: python3 analyze.py results.json"""
import json, sys, math, collections

SKILLS = {"beginner": 0.040, "average": 0.025, "expert": 0.015}   # timing sigma in seconds (assumed)
# Pinball Lab: the shots come from the results file's majorEvents (each table has its own); these are display names.
SHOTS = ["hangar", "leftRamp", "rightRamp", "orbit", "abduction", "fighter", "lane"]
NAMES = {"hangar": "Hangar", "leftRamp": "Defense Cannon (left ramp)", "rightRamp": "Tractor Beam (right ramp)",
         "orbit": "Orbit", "abduction": "Abduction scoop", "fighter": "Fighter bank", "lane": "U-F-O lane",
         "library": "Library (up-kicker)", "lagoon": "Lagoon", "sigil": "Sigil bank", "cthulhu": "Cthulhu (moving)"}

def phi(x): return 0.5 * (1 + math.erf(x / math.sqrt(2)))

def analyse(trials):
    """trials of one flipper at one step size → {shot: (window_ms, {skill: p})}"""
    # group by flip moment (frame-quantised): fraction of each outcome there
    by = collections.defaultdict(list)
    for t in trials:
        if t["outcome"] != "invalid":
            by[round(t["actualDelay"], 4)].append(t["outcome"])
    moments = sorted(by)
    if len(moments) < 2: return {}
    gaps = [b - a for a, b in zip(moments, moments[1:])]
    out = {}
    for shot in SHOTS:
        frac = [by[m].count(shot) / len(by[m]) for m in moments]
        if not any(frac): continue
        # window: total width of moments that made it (each moment owns half the gap each side)
        width = 0
        for i, m in enumerate(moments):
            lo = moments[i] - (gaps[i - 1] / 2 if i > 0 else gaps[0] / 2)
            hi = moments[i] + (gaps[i] / 2 if i < len(gaps) else gaps[-1] / 2)
            width += frac[i] * (hi - lo)
        best = {}
        for skill, sigma in SKILLS.items():
            bestp = 0
            for aim in [moments[0] + k * 0.001 for k in range(int((moments[-1] - moments[0]) / 0.001) + 1)]:
                p = 0
                for i, m in enumerate(moments):
                    lo = m - (gaps[i - 1] / 2 if i > 0 else gaps[0] / 2)
                    hi = m + (gaps[i] / 2 if i < len(gaps) else gaps[-1] / 2)
                    p += frac[i] * (phi((hi - aim) / sigma) - phi((lo - aim) / sigma))
                bestp = max(bestp, p)
            best[skill] = bestp
        out[shot] = (width * 1000, best)
    return out

if __name__ == "__main__":
    d = json.load(open(sys.argv[1]))
    if d.get("majorEvents"):
        SHOTS = d["majorEvents"]
    flippers = list(dict.fromkeys(t["flipper"] for t in d["trials"]))
    # group by pass: physics steps under 12 ms = a 120 Hz phone, otherwise 60 Hz
    hz = lambda t: 120 if t.get("physicsStepMs", 0) < 12 else 60
    steps = sorted(set(hz(t) for t in d["trials"]), reverse=True)
    report = {}
    for step in steps:
        for f in flippers:
            tr = [t for t in d["trials"] if t["flipper"] == f and hz(t) == step]
            res = analyse(tr)
            report[f"{f}@{step}"] = res
            print(f"\n{f.upper()} flipper, {step} Hz phone")
            print(f"  {'shot':28s} window   beginner  average  expert")
            for shot in SHOTS:
                if shot in res:
                    w, p = res[shot]
                    print(f"  {NAMES.get(shot, shot):28s} {w:5.0f} ms  {p['beginner']*100:5.0f}%   {p['average']*100:5.0f}%  {p['expert']*100:5.0f}%")
    json.dump({k: {s: {"windowMs": round(v[0], 1), **{sk: round(pv, 3) for sk, pv in v[1].items()}} for s, v in r.items()}
               for k, r in report.items()}, open(sys.argv[1].replace(".json", "-odds.json"), "w"), indent=1)
