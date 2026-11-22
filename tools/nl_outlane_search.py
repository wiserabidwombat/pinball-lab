import math, itertools, nl_outlane_sim as O, nl_layout as L
best=[]
for y0,y1,ins,pf in itertools.product((495,505,515),(760,800),(32,38,44),(0.1,0.15,0.2)):
    pts=O.bulge_pts(y0,y1,ins,pf)
    g=min(math.dist(p,L.OUTLANE_POST_L) for p in pts)-L.GUIDE_POST_R
    if g<45.5: continue
    r=O.trial_set(pts,n=80)
    out=r['crosser'].get('outlane',0)+r['slider'].get('outlane',0)
    bad=r['crosser'].get('timeout',0)+r['slider'].get('timeout',0)
    best.append((out,bad,y0,y1,ins,pf,round(g,1),r))
best.sort()
for b in best[:8]: print(b)
