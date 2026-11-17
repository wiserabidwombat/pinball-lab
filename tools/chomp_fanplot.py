import sys, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
def load(f):
    out=[]
    for l in open(f):
        p=l.split()
        if l.startswith('FAN ') and len(p)>=7:
            try: out.append(tuple(map(float,p[1:7])))
            except ValueError: pass
    return out
R=load(sys.argv[1])
fig,ax=plt.subplots(figsize=(7.5,4.5))
for ps,lab in [(0.5,'120 Hz'),(1.0,'60 Hz')]:
    for roll,ls in [(250,'-'),(400,'--')]:
        s=[r for r in R if r[0]==ps and r[2]==roll]
        ax.plot([r[5] for r in s],[r[3] for r in s],ls,marker='.',ms=2,lw=1,label=f'{lab}, rolling {roll:.0f} pt/s')
        j=max(abs(s[i][3]-s[i-1][3]) for i in range(1,len(s)))
        print(lab,roll,'range',round(min(r[3] for r in s),1),round(max(r[3] for r in s),1),'max step',round(j,2),'speed',round(min(r[4] for r in s)),round(max(r[4] for r in s)))
ax.set_xlabel('where the ball was on the right flipper at the flip (pt from the pivot)'); ax.set_ylabel('launch direction (degrees, 90 = straight up)')
ax.grid(alpha=0.3); ax.legend(fontsize=8); ax.set_title(sys.argv[3] if len(sys.argv)>3 else '',fontsize=10)
fig.savefig(sys.argv[2],dpi=110,bbox_inches='tight')
