"""Lamplight economy simulator: evenings to fill the 120 books under different find rules."""
import random, statistics, sys
TIERS=[48,30,24,12,6]          # common..ultra
SHELF=[60,25,10,4,1]; LOFT=[40,30,18,9,3]
def evening_finds(F, loftShare):
    n=max(0,int(random.gauss(F, F*0.35)+0.5))
    return [random.random()<loftShare for _ in range(n)]
def sim(F, mode, loftShare=0.25, lucky=0.4, evenings=400, seed=None, pityR=15, pityU=120):
    owned=[set() for _ in TIERS]; sinceR=sinceU=0; dup=0
    marks={}
    for ev in range(1,evenings+1):
        isLucky=random.random()<lucky
        for loft in evening_finds(F, loftShare):
            w=list(LOFT if loft else SHELF)
            if isLucky: w=[x*1.5 if i>=2 else x for i,x in enumerate(w)]
            sinceR+=1; sinceU+=1
            r=random.random()*sum(w); t=0
            while r>=w[t]: r-=w[t]; t+=1
            if sinceU>=pityU: t=4
            elif sinceR>=pityR and t<2: t=2
            if t>=2: sinceR=0
            if t==4: sinceU=0
            if mode=='new':
                missing=[i for i in range(TIERS[t]) if i not in owned[t]]
                b=random.choice(missing) if missing else random.randrange(TIERS[t])
            else:
                b=random.randrange(TIERS[t])
            if b in owned[t]: dup+=1
            owned[t].add(b)
        tot=sum(len(o) for o in owned)
        for p in (60,90,108,120):
            if tot>=p and p not in marks: marks[p]=ev
        if len(owned[4])==6 and 'ultra' not in marks: marks['ultra']=ev
        if tot==120: break
    return marks
def run(F, mode, n=200, **kw):
    res={}
    for _ in range(n):
        m=sim(F,mode,**kw)
        for k,v in m.items(): res.setdefault(k,[]).append(v)
    return {k:int(statistics.median(v)) for k,v in res.items()}
# ---------------------------------------------------------------- plan 2 round 19: fed by the Play Lab
# `python3 tools/lmp_econ_sim.py --from ShotLab/playlab-the-lamplight-….json [more …]`: per skill, each simulated
# evening is one of that skill's real Play Lab evenings (finds, loft finds, lucky or not, score and regulars helped),
# drawn at random; the books come out by the game's own rules (LmpShop: shelf/loft odds, lucky ×1.5 on rare+, pity
# 15/120, any book of the rarity, so duplicates). Tips per evening = score / 25,000 + regulars helped + duplicates lent
# (LmpShop.tips + v19). Reports the median evening reaching 60 / 90 / 108 / all 120 books, all 6 ultras, and the
# whole furniture catalog (342 tips today). Treasures and cat gifts are left out (they don't fill the 120). Caveat: Play Lab
# evenings stop at the 8-minute cap, so the good robots' real evenings would be longer and richer.

CATALOG_TIPS = 342   # perches 20+12+15 + cozy 15+20+25+30+55+35+40+30+45 (LmpShop, LmpCozy, 2026-11-02)
POINTS_PER_TIP = 25_000
MARKS = (60, 90, 108, 120, "ultra", "catalog")


def evenings_from(paths):
    """{skill: [evening dict]} from Play Lab JSONs of The Lamplight."""
    import json
    by = {}
    loft_known = True
    for p in paths:
        d = json.load(open(p))
        for g in d.get("games", []):
            ex = g.get("extras") or {}
            if "finds" not in ex:
                continue
            if "loftFinds" not in ex:
                loft_known = False
            oc = g.get("objectiveCounts") or {}
            by.setdefault(g["skill"], []).append(dict(
                finds=ex.get("finds", 0), loft=ex.get("loftFinds"), lucky=oc.get("luckyEvening", 0) > 0,
                tips=g.get("score", 0) // POINTS_PER_TIP + ex.get("requests", 0)))
    return by, loft_known


def sim_played(evs, loft_share=0.25, evenings=600):
    owned = [set() for _ in TIERS]
    since_r = since_u = 0
    tips = 0
    marks = {}
    for ev in range(1, evenings + 1):
        e = random.choice(evs)
        n_loft = e["loft"] if e["loft"] is not None else sum(random.random() < loft_share for _ in range(e["finds"]))
        tips += e["tips"]
        for k in range(e["finds"]):
            w = list(LOFT if k < n_loft else SHELF)
            if e["lucky"]:
                w = [x * 1.5 if i >= 2 else x for i, x in enumerate(w)]
            since_r += 1
            since_u += 1
            r = random.random() * sum(w)
            t = 0
            while r >= w[t]:
                r -= w[t]
                t += 1
            if since_u >= 120:
                t = 4
            elif since_r >= 15 and t < 2:
                t = 2
            if t >= 2:
                since_r = 0
            if t == 4:
                since_u = 0
            b = random.randrange(TIERS[t])
            if b in owned[t]:
                tips += 1                     # a duplicate is lent to a neighbour for a tip
            owned[t].add(b)
        tot = sum(len(o) for o in owned)
        for m in (60, 90, 108, 120):
            if tot >= m and m not in marks:
                marks[m] = ev
        if len(owned[4]) == 6 and "ultra" not in marks:
            marks["ultra"] = ev
        if tips >= CATALOG_TIPS and "catalog" not in marks:
            marks["catalog"] = ev
        if len(marks) == len(MARKS):
            break
    return marks


def played_summary(paths, n=200):
    """{skill: {"evenings": k, "finds": mean, "marks": {mark: median evening or None}}} and whether loft finds were measured."""
    by, loft_known = evenings_from(paths)
    out = {}
    for skill, evs in by.items():
        res = {}
        for _ in range(n):
            for k, v in sim_played(evs).items():
                res.setdefault(k, []).append(v)
        out[skill] = dict(evenings=len(evs), finds=sum(e["finds"] for e in evs) / len(evs),
                          tips=sum(e["tips"] for e in evs) / len(evs),
                          marks={k: (int(statistics.median(res[k])) if len(res.get(k, [])) > n // 2 else None) for k in MARKS})
    return out, loft_known


def played_lines(paths):
    order = ["beginner", "intermediate", "advanced", "expert", "you"]
    out, loft_known = played_summary(paths)
    lines = []
    for s in sorted(out, key=lambda s: order.index(s) if s in order else 9):
        o = out[s]
        m = o["marks"]
        f = lambda k: str(m[k]) if m[k] else ">600"
        lines.append(f"{s:12} {o['finds']:4.1f} finds, {o['tips']:4.1f} tips an evening ({o['evenings']} evenings) → "
                     f"books 60 by {f(60)}, 90 by {f(90)}, 108 by {f(108)}, all 120 by {f(120)}; ultras {f('ultra')}; "
                     f"catalog {f('catalog')}")
    if not loft_known:
        lines.append("(loft finds not in these reports: a quarter assumed; runs after round 19 measure it)")
    return lines


if __name__=='__main__':
    if "--from" in sys.argv:
        paths = sys.argv[sys.argv.index("--from") + 1:]
        print("The Lamplight's collection, fed by Play Lab evenings (median evening of 200 simulated players):")
        for line in played_lines(paths):
            print("  " + line)
        sys.exit(0)
    print("finds/evening  mode   ->  median evening reaching 60 / 90 / 108 / all 120 books, all 6 ultras")
    for mode in ('new','uniform'):
        for F in (3,5,8,12,20,35):
            m=run(F,mode)
            print(f"{F:5}  {mode:8} " + "  ".join(f"{k}:{m.get(k,'>400')}" for k in (60,90,108,120,'ultra')))
