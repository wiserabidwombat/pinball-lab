import numpy as np, random
from PIL import Image
reg=np.asarray(Image.open('mon/m9/mon_upper_regions.png').convert('RGBA'),np.float32)/255
H,W=reg.shape[:2]
idx=(reg[...,0]>.5)*1+(reg[...,1]>.5)*2+(reg[...,2]>.5)*4
alpha=reg[...,3]
X0,Y0,RW,RH=-40,525,680,805
yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
px=X0+(xx+.5)/W*RW; py=Y0+RH-(yy+.5)/H*RH
n=np.clip((alpha-.2)/.8,0,1)
SKY=0
sky=idx==SKY
area=sky.sum()*RW*RH/(W*H)
print('sky area',area, 'counts', [int((idx==k).sum()) for k in range(6)])
def strength(a,w,L):
    r=(-2*L+np.sqrt(4*L*L+4*np.pi*a))/(2*np.pi); return min(.8,(r/(210*w)+.367)/1.8)
def cov(drops):
    t=np.full((H,W),9.)
    for ax,ay,bx,by,w,s in drops:
        abx,aby=bx-ax,by-ay
        h=np.clip(((px-ax)*abx+(py-ay)*aby)/max(abx*abx+aby*aby,1e-4),0,1)
        d=np.hypot(px-ax-abx*h,py-ay-aby*h)
        t=np.minimum(t,d/(210*w)*.75+n*.55-s*1.35)
    return ((t<0)&sky).sum()/sky.sum()
pts=[(200,1235),(274,1150),(256,1150)]
for amt in [0.15]:
  for trial in range(3):
    drops=[];out=[]
    for k in range(3):
        p=random.choice(pts); w=random.uniform(.85,1.2)
        a=amt*area
        drops.append((p[0]+random.uniform(-25,25),p[1]+random.uniform(-25,25),)*2+(w,strength(a,w,0)))
        out.append(round(cov(drops),2))
    print(out, [round(d[5],2) for d in drops])
print('--- frontier')
ys,xs=np.nonzero(sky)
def rp():
    i=random.randrange(len(xs)); return (px[ys[i],xs[i]],py[ys[i],xs[i]])
def covered(p,drops):
    for ax,ay,bx,by,w,s in drops:
        if np.hypot(p[0]-ax,p[1]-ay) < 210*w*(1.8*s-.37)*0.9: return True
    return False
for trial in range(5):
    drops=[];out=[]
    for k in range(3):
        p=random.choice(pts); p=(p[0]+random.uniform(-25,25),p[1]+random.uniform(-25,25))
        if covered(p,drops):
            c=[q for q in (rp() for _ in range(60)) if not covered(q,drops)]
            if c: p=min(c,key=lambda q:np.hypot(q[0]-p[0],q[1]-p[1]))
        w=random.uniform(.85,1.2)
        drops.append(p*2+(w,strength(.15*area,w,0)))
        out.append(round(cov(drops),2))
    print(out)
print('--- tuned (M10 v2)')
st=8
sub=sky[st//2::st, st//2::st]; SX=px[st//2::st, st//2::st][sub]; SY=py[st//2::st, st//2::st][sub]; SN=n[st//2::st, st//2::st][sub]
def tthr(d,s):
    ax,ay,bx,by,w=d; abx,aby=bx-ax,by-ay
    k=np.clip(((SX-ax)*abx+(SY-ay)*aby)/max(abx*abx+aby*aby,1e-4),0,1)
    dd=np.hypot(SX-ax-abx*k,SY-ay-aby*k); return dd/(210*w)*.75+SN*.55-s*1.35
for trial in range(5):
    drops=[];out=[]
    for k in range(4):
        cov_=np.zeros(len(SX),bool)
        for d,s in drops: cov_|=tthr(d,s)<0
        p=random.choice(pts); p=(p[0]+random.uniform(-25,25),p[1]+random.uniform(-25,25))
        j=np.argmin(np.hypot(SX-p[0],SY-p[1]))
        if cov_[j] or np.hypot(SX[j]-p[0],SY[j]-p[1])>16:
            c=np.where(~cov_)[0]; j=c[np.argmin(np.hypot(SX[c]-p[0],SY[c]-p[1]))]; p=(SX[j],SY[j])
        w=random.uniform(.85,1.2); d=(p[0],p[1],p[0],p[1],w)
        goal=cov_.mean()+.75/4; need=int(np.ceil(goal*len(SX)))-cov_.sum()
        sm=np.sort(tthr(d,0)[~cov_]/1.35); sm=sm[sm<.8]
        s=sm[need-1]+.002 if len(sm)>=need else .8
        drops.append((d,s)); 
        out.append(round(cov([dd+(ss,) for dd,ss in drops]),2))
    print(out)
