"""Table 04 (Monsoon) M9 v6: preview of the code-drawn habitrails (MonRamp.drawTube / drawHabitrail / drawShadow) over the
upper art, using mon_render_m5.py's wire paths. Writes /tmp/claude-0/s/wires_prev.png."""
import sys, math
sys.argv=['x','/dev/null','/dev/null']
sys.path.insert(0,'/home/claude/gi-src/tools')
import matplotlib; matplotlib.use('Agg')
src=open('/home/claude/gi-src/tools/mon_render_m5.py').read()
src=src[src.index('from cth_layout import RampPath'):src.index('X_ = helix()')]
import cth_layout as L
exec('import math\n'+src)
from PIL import Image, ImageDraw
import os
BASE=os.environ.get('BASE','/home/claude/gi-src/mon/m9/mon_upper.jpg'); OUTN=os.environ.get('OUTN','/tmp/claude-0/s/wires_prev.png'); OUTLINE=os.environ.get('OUTLINE')=='1'
up=Image.open(BASE).convert('RGBA')
ov=Image.new('RGBA',up.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
S=3; K=0.404; HW=16
def P(x,y): return ((x+40)*S,(1330-y)*S)
def draw(w,hfun,brass,from_apex=True,helix=False):
    p=w[0]; pts=p.pts; ds=p.ds
    # headings
    hd=[math.atan2(pts[min(i+1,len(pts)-1)][1]-pts[max(i-1,0)][1], pts[min(i+1,len(pts)-1)][0]-pts[max(i-1,0)][0]) for i in range(len(pts))]
    idx=[i for i in range(len(pts)) if (not from_apex) or ds[i]>=w[1]]
    dark=(128,87,31,255) if brass else (77,82,97,255); light=(250,209,122,255) if brass else (240,242,250,255)
    def pt(i,side,h,out):
        x,y=pts[i]; ww=HW+out
        return P(x - side*ww*math.sin(hd[i]), y + side*ww*math.cos(hd[i]) + h*K)
    # shadow
    for side in (1,-1):
        sh=[P(pts[i][0]-side*HW*math.sin(hd[i])+hfun(w,ds[i])*0.30, pts[i][1]+side*HW*math.cos(hd[i])-hfun(w,ds[i])*0.22) for i in idx]
        d.line(sh,fill=(0,0,0,70),width=4*S)
    # posts
    nxt=ds[idx[0]]+40
    for i in idx:
        if ds[i]>=nxt:
            nxt=ds[i]+110; h=hfun(w,ds[i])
            if h>10:
                c=P(*pts[i]); d.ellipse([c[0]-3.5*S,c[1]-2.5*S,c[0]+3.5*S,c[1]+2.5*S],fill=(140,145,158,255))
                d.line([c,P(pts[i][0],pts[i][1]+(h-3)*K)],fill=(90,95,110,255),width=int(2.6*S))
                d.line([c,P(pts[i][0],pts[i][1]+(h-3)*K)],fill=(225,230,240,255),width=int(1*S))
    lowL=[pt(i,1,hfun(w,ds[i]),0) for i in idx]; lowR=[pt(i,-1,hfun(w,ds[i]),0) for i in idx]
    topL=[pt(i,1,hfun(w,ds[i])+11,2) for i in idx]; topR=[pt(i,-1,hfun(w,ds[i])+11,2) for i in idx]
    nxt=ds[idx[0]]
    for k,i in enumerate(idx):
        if ds[i]>=nxt:
            nxt=ds[i]+12; d.line([topL[k],lowL[k],lowR[k],topR[k]],fill=dark,width=int(1*S))
    for r,rail in enumerate((lowL,lowR,topL,topR)):
        up_=r>=2
        if OUTLINE: d.line(rail,fill=(12,10,22,150),width=int(((2.0 if up_ else 2.6)+1.6)*S))
        d.line(rail,fill=dark,width=int((2.0 if up_ else 2.6)*S)); d.line(rail,fill=light,width=int((0.8 if up_ else 1.2)*S))
draw(low(),height,True,from_apex=False)
draw(high(),height,False)
draw(helix(),height_h,False,from_apex=False,helix=True)
up.alpha_composite(ov)
up.crop((0,0,up.width,int((1330-640)*S))).resize((680,690)).convert('RGB').save(OUTN)
