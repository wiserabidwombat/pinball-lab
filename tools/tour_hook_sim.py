"""Table 06 M3 v6: the plunge guide (a curve leaving the arch tangentially and turning down-left over S-T-A-R R).
pymunk, damping 0.9/s to match the DEBUG plunge probe (-shotlab grandtour -shotlab-scenario plungeprobe; peaks 0.4 → 985,
0.5 → 1117, 0.6 → (450, 1221)). hook(xs, rho, end_deg, ell) builds the guide; run(power, guide) gives the outcome.
Picked (420, 70, -130): every plunge from ~0.64 → R at damping 0.88-0.93; probe on v6: 0.7-1.0 → R, 0.6 → middle."""
import sys, math, itertools; sys.path.insert(0,'.')
import pymunk, tour_plunge_sim as S, tour_layout as L, tour_layout_m3 as M
OW=L.outer_wall()
arch=[p for p in OW if p[1]>1100 and p[0]>280]
def arch_at(x):
    best=min(zip(arch,arch[1:]), key=lambda ab: abs((ab[0][0]+ab[1][0])/2-x))
    (ax,ay),(bx,by)=best; t=(x-ax)/(bx-ax) if bx!=ax else 0
    y=ay+t*(by-ay); d=(ax-bx,ay-by) if ax>bx else (bx-ax,by-ay)
    # leftward tangent
    tx,ty=(-abs(bx-ax), (by-ay) if bx<ax else (ay-by)); n=math.hypot(tx,ty); return (x,y),(tx/n,ty/n)
def hook(xs, rho, end_deg, ell):
    (x,y),(tx,ty)=arch_at(xs); y-=1.0
    ang=math.atan2(ty,tx)   # heading (leftward, up-left)
    # turn counter-clockwise (left then down) from heading to end_deg
    end=math.radians(end_deg)
    while end<ang: end+=2*math.pi
    # centre of curvature on the left-turn side (ccw): n = (-ty, tx)
    cx,cy=x-ty*rho, y+tx*rho
    pts=[(x,y)]; a0=math.atan2(y-cy,x-cx); steps=12
    for k in range(1,steps+1):
        a=a0+(end-ang)*k/steps; pts.append((cx+rho*math.cos(a), cy+rho*math.sin(a)))
    ex,ey=pts[-1]; pts.append((ex+ell*math.cos(end), ey+ell*math.sin(end)))
    return pts
def run(power, guide, T=3):
    space, gate = S.build('v2'); space.damping=0.9
    for a,b in zip(guide,guide[1:]):
        s=pymunk.Segment(space.static_body,a,b,1.5); s.elasticity=0.2; s.friction=0.05; space.add(s)
    og=pymunk.Segment(space.static_body,(352,1266.4),(352,1214),1.5); og.elasticity=0.2   # orbit gate: solid only moving right
    v0=1080+power*1230; b=pymunk.Body(0.08,pymunk.moment_for_circle(0.08,0,9)); b.position=(564,146); b.velocity=(0,v0)
    sh=pymunk.Circle(b,9); sh.elasticity=0.1; sh.friction=0.1; space.add(b,sh)
    t=0; prev=b.position; gate_in=False; og_in=False
    while t<T:
        x,y=b.position; vx,vy=b.velocity
        want=((32*(y-955)-28*(x-548))>0) and vy<0
        if want!=gate_in: (space.add if want else space.remove)(gate); gate_in=want
        space.step(1/240); t+=1/240; p=b.position
        if prev.y>=M.laneRolloverY>p.y and 214<p.x<358: return 'STAR'[min(3,int((p.x-214)//36))]
        if p.y<150 and p.x>548 and t>0.2: return 'back'
        if 504<p.x<548 and p.y<760: return 'Rlane'
        if p.x<60 and p.y<900: return 'Llane'
        if p.y<1000 and 60<p.x<504: return 'mid'
        prev=pymunk.Vec2d(p.x,p.y)
    return 'stuck?'
powers=[0.45,0.5,0.55,0.6,0.65,0.7,0.8,0.9,1.0]
if __name__=='__main__':
    res=[]
    for xs,rho,ed,ell in itertools.product((440,470,500),(50,70,95),(-100,-120,-140),(0,20)):
        g=hook(xs,rho,ed,ell)
        if any(q[0]<200 or q[1]<1150 for q in g): continue
        o=[run(p,g) for p in powers]; n=sum(1 for v in o if v in 'STAR' and len(v)==1)
        res.append((n,(xs,rho,ed,ell),o,[tuple(round(c) for c in g[-1])]))
    res.sort(key=lambda r:-r[0])
    for r in res[:10]: print(r)
