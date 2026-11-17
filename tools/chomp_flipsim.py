"""Python twin of ChompFlipper.solveSwing (M2 v10) for the right flipper, continuous time (0.5 ms sub-steps)."""
import math
PIV=(389.0,220.0); L=80.0; R0,R1=12.0,6.0; BR=15.0; REST=math.radians(30); TRAVEL=math.radians(60); G=-9.2*150
def half(a): return R0+(R1-R0)*min(max(a/L,0),1)
def arm(th): return (-math.cos(th),-math.sin(th))   # right flipper
def launch(a0, roll, A=1200, tau=0.006, wmax=1000, e0=0.85, fall=0.35, mu=0.9, thr=250, h=0.0005, frame=None):
    th=REST; w=0.0; t=0.0; raised=0.0
    d=arm(th); n=(-math.sin(th),math.cos(th)); off=half(a0)+BR+0.5
    px=PIV[0]+a0*d[0]+off*n[0]; py=PIV[1]+a0*d[1]+off*n[1]
    vx=d[0]*roll; vy=d[1]*roll
    for k in range(int(0.3/h)):
        t+=h
        if raised<TRAVEL:
            w=min(w+A*(1-math.exp(-t/tau))*h, wmax); raised+=w*h
            if raised>=TRAVEL: raised=TRAVEL; w=0
        else: w=0
        thn=REST-raised; omega=-w     # right flipper raises clockwise: zRotation decreases
        vy+=G*h; px+=vx*h; py+=vy*h
        d=arm(thn)
        dx,dy=px-PIV[0],py-PIV[1]
        a=min(max(dx*d[0]+dy*d[1],0),L)
        qx,qy=PIV[0]+a*d[0],PIV[1]+a*d[1]
        nx,ny=px-qx,py-qy; dist=math.hypot(nx,ny); hf=half(a)
        if dist< hf+BR and dist>1e-3:
            nx/=dist; ny/=dist
            px=qx+nx*(hf+BR); py=qy+ny*(hf+BR)
            cx,cy=qx+nx*hf-PIV[0], qy+ny*hf-PIV[1]
            rvx,rvy=vx+omega*cy, vy-omega*cx
            vn=rvx*nx+rvy*ny
            if vn<0:
                e=0 if -vn<thr else e0/(1+fall*(-vn)/1000)
                jn=-(1+e)*vn
                tx,ty=rvx-vn*nx, rvy-vn*ny; vt=math.hypot(tx,ty); dvt=0
                if vt>1e-3: tx/=vt; ty/=vt; dvt=min(mu*jn, 2/7*vt)
                vx+=jn*nx-dvt*tx; vy+=jn*ny-dvt*ty
        if math.hypot(px-PIV[0],py-PIV[1])> L+R0+BR+20:
            return math.degrees(math.atan2(vy,vx)), math.hypot(vx,vy), t
    return None
def fan(**kw):
    out=[]
    for i in range(0,161):
        a0=30+i*0.25
        r=launch(a0, kw.pop('roll',250) if False else kw.get('roll_',250), **{k:v for k,v in kw.items() if k!='roll_'})
        out.append((a0, r))
    return out
if __name__=='__main__':
    for roll in [250,400]:
        f=fan(roll_=roll)
        degs=[r[1][0] for r in f if r[1]]
        print(roll, ' '.join(f'{a:.0f}:{r[0]:.0f}' for a,r in f if r and a%5==0), 'maxjump', round(max(abs(degs[i]-degs[i-1]) for i in range(1,len(degs))),1))
