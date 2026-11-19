import math
slot = [(313,841),(329,848),(349.5,854.6),(369.7,858.7),(394,860),(407.6,857),(421,853),(445,843.7),(459,833),(472,818),(483,802),(490,785),(494.6,769)]
L=[0]
for a,b in zip(slot,slot[1:]): L.append(L[-1]+math.dist(a,b))
def at(s):
    s=max(0,min(L[-1],s))
    for i in range(len(slot)-1):
        if s<=L[i+1]:
            t=(s-L[i])/(L[i+1]-L[i]); a,b=slot[i],slot[i+1]
            return (a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])), math.atan2(b[1]-a[1],b[0]-a[0])
FL,FT=40,10
def rect(s):
    (x,y),h=at(s); c,si=math.cos(h),math.sin(h)
    return [(x+c*dx-si*dy,y+si*dx+c*dy) for dx,dy in((-FL/2,-FT/2),(FL/2,-FT/2),(FL/2,FT/2),(-FL/2,FT/2))]
def seg_pt(p,a,b):
    ax,ay=b[0]-a[0],b[1]-a[1]; t=max(0,min(1,((p[0]-a[0])*ax+(p[1]-a[1])*ay)/(ax*ax+ay*ay)))
    return math.dist(p,(a[0]+t*ax,a[1]+t*ay))
def rect_dist(s,p):
    r=rect(s); return min(seg_pt(p,r[i],r[(i+1)%4]) for i in range(4))
print('slot length %.1f'%L[-1])
bump=(490,687); 
for s in range(0,int(L[-1])+1,10):
    (x,y),h=at(s); print(s,'(%.0f,%.0f) %.0f deg'%(x,y,math.degrees(h)),'bumper surface gap %.1f'%(rect_dist(s,bump)-22))
print('--- travel 15..215')
mn=1e9
for s in range(15,216):
    r=rect(s); gx=min(548-max(p[0] for p in r), 1e9); mn=min(mn,gx)
print('fin to the right wall x 548 (min, over travel): %.1f'%mn)
print('fin to bumper surface min: %.1f'%min(rect_dist(s,(490,687))-22 for s in range(15,216)))
print('fin to buoy centre min: %.1f'%min(rect_dist(s,(468,638)) for s in range(15,216)))
