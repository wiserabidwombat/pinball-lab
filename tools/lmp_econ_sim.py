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
if __name__=='__main__':
    print("finds/evening  mode   ->  median evening reaching 60 / 90 / 108 / all 120 books, all 6 ultras")
    for mode in ('new','uniform'):
        for F in (3,5,8,12,20,35):
            m=run(F,mode)
            print(f"{F:5}  {mode:8} " + "  ".join(f"{k}:{m.get(k,'>400')}" for k in (60,90,108,120,'ultra')))
