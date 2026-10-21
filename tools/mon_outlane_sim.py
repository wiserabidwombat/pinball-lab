# Monsoon (Table 04): a 2D model of the left outlane mouth, for choosing the outlane post (Play Lab run 3).
# pip install pymunk; python3 tools/mon_outlane_sim.py
# Numbers copied from MonTableLayout (left wall + bulge, lane guide, left sling, captive channel and its top guard,
# gravity -9.2 × 150 pt/s², ball r 9, walls restitution 0.3). It's a model, not SpriteKit: it reproduces the
# real failure (a ball dropping off the captive channel at x 47-48 goes down the outlane) and compares tips.
# Outcomes when the ball gets below y 300: OUT (outlane), inlane, field (onto the sling / lower table), up (resting).
import pymunk, math, sys
G=-9.2*150
def quad(p0,c,p1,n=24):
    out=[]
    for i in range(n+1):
        t=i/n;u=1-t
        out.append((u*u*p0[0]+2*u*t*c[0]+t*t*p1[0],u*u*p0[1]+2*u*t*c[1]+t*t*p1[1]))
    return out
def chan():
    a=(math.cos(math.radians(120)),math.sin(math.radians(120)))
    m=(100,592); L=82; hw=10.5
    end=(m[0]+a[0]*L,m[1]+a[1]*L)
    n=(a[1],-a[0])
    return [(m[0]+n[0]*hw,m[1]+n[1]*hw),(end[0]+n[0]*hw,end[1]+n[1]*hw),(end[0]-n[0]*hw,end[1]-n[1]*hw),(m[0]-n[0]*hw,m[1]-n[1]*hw)]
def build(space,hook):
    segs=[]
    wall=[(20,185),(20,540)]+quad((20,540),(56,660),(20,780))[1:]+[(20,1000)]
    for a,b in zip(wall,wall[1:]): segs.append((a,b,0.3))
    segs+= [((54,470),(54,330),0.3),((54,330),(54,215),0.3)]
    # left sling outer side and top
    segs+= [((88,450),(88,347),0.3),((88,347),(150,300.4),0.3),((150,300.4),(88,450),0.3)]
    c=chan()
    for a,b in zip(c,c[1:]+c[:1]): segs.append((a,b,0.3))
    segs.append(((36.5,694),(68,668),0.3))
    if hook: segs.append(((54,470),hook,0.3))
    for a,b,e in segs:
        s=pymunk.Segment(space.static_body,a,b,1.5); s.elasticity=e; s.friction=0.3; space.add(s)
def run(x,y,vx,vy,hook,T=2.5):
    sp=pymunk.Space(); sp.gravity=(0,G)
    build(sp,hook)
    b=pymunk.Body(0.08,pymunk.moment_for_circle(0.08,0,9)); b.position=(x,y); b.velocity=(vx,vy)
    s=pymunk.Circle(b,9); s.elasticity=1.0; s.friction=0.3; sp.add(b,s)
    dt=1/240; t=0; kicked=False; path=[]
    while t<T:
        sp.step(dt); t+=dt
        p=b.position
        path.append((p.x,p.y))
        if p.y<300:
            if p.x<54: return 'OUT',path
            if p.x<90: return 'inlane',path
            return 'field',path
    return 'up',path
if __name__=='__main__':
    for hook in [None,(44,482)]:
        print('post tip', hook or 'none (the guide post only)')
        print('  the real failure (drop off the captive channel at 48, 642):', run(48,642,0,0,hook)[0])
        print('  drops from y 600, x 43..63:', ' '.join(f"{x}:{run(x,600,0,-150,hook)[0][0]}" for x in range(43,64)))
        print('  slides from y 560 at 500 pt/s:', ' '.join(f"{x}:{run(x,560,0,-500,hook)[0][0]}" for x in range(29,64,2)))
        print('  kickback (1330 pt/s at y 320):', ' '.join(f"{x}:{run(x,320,0,1330,hook,T=4)[0]}" for x in (30,32,35,38,41)))
    print("('u' at exactly a post's x is the model balancing a ball on a point; SpriteKit won't hold it there.)")
