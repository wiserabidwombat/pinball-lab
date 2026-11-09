#!/usr/bin/env python3
"""Grand Tour: where cradled shots cross the rocket hull probe (y 904), per pass and flipper. python3 tools/tour_hull_read.py ShotLab/shotlab-grand-tour-….json"""
import json,sys,collections
d=json.load(open(sys.argv[1]))
HULL=(236,332); DOOR=(267,301)  # hull M3 v12 (v20: 222–346; v19: 232–336)
tr=[t for t in d["trials"] if t["outcome"]!="invalid"]
print(d["table"], d.get("date"), "fps", d.get("fps"), "trials", len(tr))
for lbl,lo,hi in (("120 Hz",0,12),("60 Hz",12,99)):
  for fl in ("left","right"):
    tt=sorted([t for t in tr if t["flipper"]==fl and lo<=t["physicsStepMs"]<hi],key=lambda t:t["plannedDelay"])
    if not tt: continue
    oc=collections.Counter(t["outcome"] for t in tt)
    xs=[(t["flipAlong"],t["crossings"]["hull"]) for t in tt if "hull" in t.get("crossings",{})]
    onh=[a for a,c in xs if HULL[0]<=c["x"]<=HULL[1]]; ond=[a for a,c in xs if DOOR[0]<=c["x"]<=DOOR[1]]
    print(f"\n{lbl} {fl}: {len(tt)} trials · outcomes {dict(oc.most_common())}")
    print(f"  crossed hull height {len(xs)} · inside hull x{HULL[0]}-{HULL[1]}: {len(onh)} · door x267-301: {len(ond)}")
    if onh: print(f"  flipAlong on hull {min(onh):.1f}-{max(onh):.1f} pt; on door {(f'{min(ond):.1f}-{max(ond):.1f}' if ond else '-')}")
    # x at hull vs flipAlong, binned by 2pt
    b=collections.defaultdict(list)
    for a,c in xs: b[int(a//2)*2].append(c["x"])
    for k in sorted(b): v=sorted(b[k]); print(f"   along {k:>3}-{k+2}: x {v[0]:6.1f}..{v[-1]:6.1f} (n {len(v)})")
