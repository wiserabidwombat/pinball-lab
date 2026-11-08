"""Table 06 M3 v3: the top orbit gate + plunge flap in pymunk (left-orbit shots, right-orbit shots, plunges).
Usage: python3 tools/tour_gate_sim.py [gate_x] [gate_bottom_y]. 8 Nov 2026 (x 352, bottom 1214): left orbit 17/17 S-T-A-R R;
right orbit L lane 11, R lane (too weak) 5, S-T-A-R S 1; plunges 0.36-1.00 R lane 5, middle 1, S-T-A-R R 11; nothing stuck."""
import sys, math, collections; sys.path.insert(0,'.')
import pymunk, tour_plunge_sim as P, tour_layout_m3 as M
def arch_y(x):
    for u,v in zip(M.ARCH,M.ARCH[1:]):
        if u[0]<=x<=v[0] and v[0]>u[0]: return u[1]+(x-u[0])*(v[1]-u[1])/(v[0]-u[0])
GX=float(sys.argv[1]) if len(sys.argv)>1 else 352; GB=float(sys.argv[2]) if len(sys.argv)>2 else 1214
def run(start, vel, plunge):
    space, lgate = P.build('x')
    flap = pymunk.Segment(space.static_body,(395,1259.5),(330,1214),2); flap.elasticity=0.2; flap.friction=0.1
    og = pymunk.Segment(space.static_body,(GX,arch_y(GX)-1),(GX,GB),2); og.elasticity=0.1; og.friction=0.1
    body=pymunk.Body(0.08,pymunk.moment_for_circle(0.08,0,9)); body.position=start; body.velocity=vel
    s=pymunk.Circle(body,9); s.elasticity=0.1; s.friction=0.1; space.add(body,s)
    st={'g':False,'f':False,'o':False}; t=0; dt=1/240; prev=body.position; isP=plunge; stuck=0
    while t<6:
        x,y=body.position; vx,vy=body.velocity
        if isP and y<900 and x<548: isP=False
        for key,seg,want in (('g',lgate,(32*(y-955)-28*(x-548))>0 and vy<0),('f',flap,isP),('o',og,vx>0 and not isP)):
            if want!=st[key]: (space.add if want else space.remove)(seg); st[key]=want
        space.step(dt); t+=dt; p=body.position
        if math.hypot(*body.velocity)<5 and p.y>700: stuck+=1
        else: stuck=0
        if stuck>240: return f'STUCK at ({p.x:.0f},{p.y:.0f})'
        if p.y<150 and p.x>548 and body.velocity.y<0 and t>0.2: return 'fell back'
        if prev.y>=M.laneRolloverY>p.y and 214<p.x<358: return 'STAR '+'STAR'[min(3,int((p.x-214)//36))]
        if p.x<60 and p.y<900: return 'L lane'
        if 504<p.x<548 and p.y<760: return 'R lane (down)'
        if p.y<700 and 60<p.x<504: return 'middle'
        prev=pymunk.Vec2d(p.x,p.y)
    return 'other'
c=collections.Counter()
for v in range(1500,3200,100): c[run((40,930),(0,v),False)]+=1
print('left orbit (up the left lane, 1500-3100):',dict(c))
c=collections.Counter()
for v in range(1500,3200,100): c[run((526,880),(0,v),False)]+=1
print('right orbit (up the right lane):',dict(c))
c=collections.Counter()
for k in range(36,101,4): c[run((564,139),(0,1080+k/100*1230),True)]+=1
print('plunges 0.36-1.00:',dict(c))
