import itertools, flipsim as F
from sweep import score
for A, thr, e0 in itertools.product([1200,1500],[600,1000,1500,1e9],[0.85,0.5]):
    kw=dict(mu=0,thr=thr,A=A,e0=e0)
    r=score(kw)
    print(kw, {k:tuple(round(x,1) for x in v) for k,v in r.items()})
