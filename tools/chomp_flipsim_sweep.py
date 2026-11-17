import itertools, flipsim as F
def score(kw):
    res={}
    for roll in [250,400]:
        f=[(a, F.launch(a, roll, **kw)) for a in [30+i*0.5 for i in range(81)]]
        if any(r is None for a,r in f): return None
        d=[r[0] for a,r in f]; s=[r[1] for a,r in f]
        res[roll]=(min(d),max(d),max(abs(d[i]-d[i-1]) for i in range(1,len(d))), sum(1 for i in range(1,len(d)) if d[i]<d[i-1]-0.3), min(s), max(s), d[0], d[-1])
    return res
