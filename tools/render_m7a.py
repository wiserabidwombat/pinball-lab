# M7 v6: apron below the flippers (outlanes angle in to one centre drain). Geometry checks + render.
import math, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
R=9
def mirror(p): return (568-p[0], p[1])
apronTop=(20,185); drainEdge=(250,105); bottom=-60
leftApron=[(drainEdge[0],bottom),drainEdge,apronTop]
rightApron=[(568-drainEdge[0],bottom),(568-drainEdge[0],drainEdge[1]),(548,185)]
laneWallEnd=215
innerL=[(54,330),(54,laneWallEnd)]; innerR=[mirror(p) for p in innerL]
def segdist(p,a,b):
    dx,dy=b[0]-a[0],b[1]-a[1]; t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
def flipper(piv,side,ang):  # ang: radians below horizontal (rest 30°), sample points with radius
    pts=[]
    for i in range(41):
        s=i/40; L=96*s; r=12+(6-12)*s
        x=piv[0]+side*L*math.cos(ang); y=piv[1]-L*math.sin(ang)
        pts.append((x,y,r))
    return pts
worst=1e9
for piv,side in [((179,220),1),((389,220),-1)]:
    for deg in [30,0,-30]:
        for (x,y,r) in flipper(piv,side,math.radians(deg)):
            for ap in [leftApron,rightApron]:
                for a,b in zip(ap,ap[1:]):
                    worst=min(worst,segdist((x,y),a,b)-r)
print("closest flipper surface to an apron wall: %.1f (need > ball diameter 18 + margin)"%worst)
# outlane exit gap: inner wall end to apron line, perpendicular
a,b=apronTop,drainEdge
print("left outlane exit gap (wall end to apron): %.1f (need >= 27)"%segdist((54,laneWallEnd),a,b))
print("drain opening: %.0f wide; flipper tip gap ~31.7"%(568-2*drainEdge[0]))
print("apron slope: %.1f deg"%math.degrees(math.atan2(apronTop[1]-drainEdge[1],drainEdge[0]-apronTop[0])))
fig,ax=plt.subplots(figsize=(6,4.5))
for poly,c in [(leftApron,'g'),(rightApron,'g'),(innerL,'g'),(innerR,'g'),
               ([(54,470),(54,330),(185.5,231.3)],'g'),([mirror(p) for p in [(54,470),(54,330),(185.5,231.3)]],'g'),
               ([(20,185),(20,600)],'g'),([(548,185),(548,600)],'g'),([(548,40),(580,40),(580,600)],'g')]:
    ax.plot(*zip(*poly),c,lw=2)
for piv,side in [((179,220),1),((389,220),-1)]:
    for deg,c in [(30,'orange'),(-30,'y')]:
        f=flipper(piv,side,math.radians(deg)); ax.plot([p[0] for p in f],[p[1] for p in f],c,lw=8,alpha=.6)
for p in [(37,240),(37,190),(100,170),(200,130),(284,60)]:
    ax.add_patch(plt.Circle(p,R,color='w',ec='k'))
ax.axhline(-27,color='r',ls=':'); ax.plot([20,54],[240,240],'r--')
ax.set_xlim(0,600); ax.set_ylim(-70,480); ax.set_aspect('equal'); ax.set_facecolor('#0a1020')
plt.savefig('/home/claude/gi-src/tools/render_m7a.png',dpi=110,bbox_inches='tight')
