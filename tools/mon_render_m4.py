"""Table 04 (Monsoon) milestone 4: the milestone 3 drawing plus the two habitrails, coloured by height (the mesa
ramp's high wire to the left inlane, the arroyo's low wire to the right inlane), with the crossing marked and
the clearances printed. The wire paths mirror MonTableLayout.mesaRampPath / arroyoWirePath.
Usage: python3 mon_render_m4.py <mon_lower.jpg> <out.png>"""
import sys, os, math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

ART, OUT = sys.argv[1], sys.argv[2]
ARROYO = (284, 650)
STANDUP_X, STANDUP_YS = 464, [590, 560, 530]
DUST, DUST_R = (284, 470), 44
CAPTIVE = (26, 560, 70, 200)
HELIX, HELIX_R = (468, 1085), 48

fig, ax = plt.subplots(figsize=(6, 13), dpi=110)
ax.set_xlim(-40, 640); ax.set_ylim(-75, 1330); ax.set_aspect('equal'); ax.axis('off')
fig.patch.set_facecolor('#151517')
X0, Y0, RW, RH = L.LOWER_RECT
ax.imshow(Image.open(ART), extent=(X0, X0 + RW, Y0, Y0 + RH), zorder=0)
wall = dict(color='#d9d4c9', lw=1.6, zorder=3)

def line(pts, **kw):
    xs, ys = zip(*pts); ax.plot(xs, ys, **{**wall, **kw})

line(L.outer_wall())
line(L.orbit_inner())
for x in L.LANE_POSTS: line([(x, L.LANE_BOTTOM), (x, L.LANE_TOP)])
for c in L.BUMPERS: ax.add_patch(Circle(c, L.BUMPER_R, fc='#7a6f9a', ec='#d9d4c9', lw=1.2, zorder=4))
ax.add_patch(Circle(ARROYO, L.SCOOP_R, fc='#222', ec='#d9d4c9', lw=1.2, zorder=4))
for y in STANDUP_YS: ax.add_patch(Rectangle((STANDUP_X - 6, y - 12), 12, 24, fc='#7fa36a', ec='w', lw=0.8, zorder=4))
line(L.BANK_BACK); line(L.BANK_CAP); line(L.UPPER_GUIDE)
p = L.UPPER_PIVOT; ang = math.pi + math.radians(30)
ax.plot([p[0], p[0] + 64 * math.cos(ang)], [p[1], p[1] + 64 * math.sin(ang)], color='#eee', lw=5, solid_capstyle='round', zorder=5)
ax.plot([L.LEFT_X, 58], [L.SPINNER_Y, L.SPINNER_Y], color='#f2c768', lw=3, zorder=5)
# the habitrails (same construction as MonTableLayout)
from cth_layout import RampPath
CLIMB = math.atan2(260, 90)
def sbend(p, x):
    shift = x - p.pts[-1][0]
    if abs(shift) <= 0.5: return
    b = math.acos(1 - min(abs(shift), 119) / 120); t = b if shift > 0 else -b
    p.arc(60, t); p.arc(60, -t)
def high():
    p = RampPath((360, 600), CLIMB); p.line(math.hypot(90, 260)); p.arc(40, math.pi - CLIMB + math.radians(8))
    apex = p.length; p.line(262); p.arc(40, math.radians(82)); p.line(150); sbend(p, 69); p.line(p.pts[-1][1] - 490)
    return p, apex, 90, 275, 12
def low():
    p = RampPath((284, 650), math.pi - CLIMB); p.line(math.hypot(90, 260)); p.arc(36, -(math.pi - CLIMB) - math.radians(8))
    apex = p.length; p.line(250); p.arc(36, -math.radians(82)); p.line(150); sbend(p, 499); p.line(p.pts[-1][1] - 490)
    return p, apex, 40, 110, 10
def height(w, s):
    p, apex, top, rise, end = w
    if s <= apex: return top * math.sin(min(max(s, 0) / rise, 1) * math.pi / 2)
    return top + (end - top) * min((s - apex) / max(p.length - apex, 1), 1)
def helix():
    start = (450, 860); r = 80
    p = RampPath(start, CLIMB); p.line((516 - start[0] - r * (1 - math.sin(CLIMB))) / math.cos(CLIMB))
    p.arc(r, math.pi / 2 - CLIMB); apex = p.length
    p.arc(48, 3 * math.pi); p.arc(40, -math.radians(70)); p.line(20)
    return p, apex, 100, apex, 0
def height_h(w, s):
    p, apex, top, rise, end = w
    if s <= apex: return 90 + (top - 90) * math.sin(min(max(s, 0) / rise, 1) * math.pi / 2)
    return top + (end - top) * min((s - apex) / max(p.length - apex, 1), 1)
X_ = helix()
cmap = plt.get_cmap('plasma')
K = 0.404
for a, b, s in zip(X_[0].pts, X_[0].pts[1:], X_[0].ds[1:]):
    h = height_h(X_, s)
    ax.plot([a[0], b[0]], [a[1] + h * K, b[1] + h * K], color=cmap(h / 105), lw=5, alpha=0.95, zorder=13 + h / 100, solid_capstyle='round')
e = X_[0].pts[-1]; ax.annotate('', xy=(e[0] - 60 * 0.94, e[1] - 60 * 0.34), xytext=e, arrowprops=dict(arrowstyle='->', color='w'), zorder=14)
ax.text(468, 1150, 'HELIX (drawn lifted by height)', color='w', fontsize=6.5, ha='center', zorder=14)
H_, L_ = high(), low()
cmap = plt.get_cmap('plasma')
for w, lw, z in ((L_, 7, 10), (H_, 7, 11)):
    p = w[0]
    for a, b, s in zip(p.pts, p.pts[1:], p.ds[1:]):
        ax.plot([a[0], b[0]], [a[1], b[1]], color=cmap(height(w, s) / 95), lw=lw, alpha=0.9, zorder=z, solid_capstyle='round')
best = min(((math.dist(a, b), i, j) for i, a in enumerate(H_[0].pts) for j, b in enumerate(L_[0].pts)))
cx, cy = H_[0].pts[best[1]]
hh, lh = height(H_, H_[0].ds[best[1]]), height(L_, L_[0].ds[best[2]])
ax.add_patch(Circle((cx, cy), 16, fc='none', ec='w', lw=1.5, zorder=12))
ax.text(cx + 22, cy + 18, f'crossing: high {hh:.0f} pt over low {lh:.0f} pt', color='w', fontsize=6.5, zorder=12)
for w, name in ((H_, 'HIGH WIRE → left inlane'), (L_, 'LOW WIRE → right inlane')):
    e = w[0].pts[-1]; ax.text(e[0], e[1] - 22, name, color='w', fontsize=6, ha='center', zorder=12)
print(f'crossing at ({cx:.0f},{cy:.0f}): high {hh:.1f} low {lh:.1f}; high ends {H_[0].pts[-1]}, low ends {L_[0].pts[-1]}')
print('high x range', min(q[0] for q in H_[0].pts), max(q[0] for q in H_[0].pts), 'low x range', min(q[0] for q in L_[0].pts), max(q[0] for q in L_[0].pts))
# reserved spots
for patch, name, at in ((Circle(DUST, DUST_R), 'DUST DEVIL', DUST),
                        (Rectangle(CAPTIVE[:2], CAPTIVE[2], CAPTIVE[3]), 'CAPTIVE\nBALL', (CAPTIVE[0] + CAPTIVE[2] / 2, CAPTIVE[1] + CAPTIVE[3] / 2))):
    patch.set(fc='none', ec='#f2c768', lw=1.6, ls='--', zorder=6); ax.add_patch(patch)
    ax.text(*at, name, color='#f2c768', ha='center', va='center', fontsize=7, fontweight='bold', zorder=7)
# shot lines from the flipper tips (raised): left flipper → mesa ramp and standups, right → orbit, both → arroyo
lt = (L.L_PIVOT[0] + 96 * math.cos(math.radians(30)), L.L_PIVOT[1] + 96 * math.sin(math.radians(30)))
rt = (L.R_PIVOT[0] - 96 * math.cos(math.radians(30)), L.R_PIVOT[1] + 96 * math.sin(math.radians(30)))
for a, b, c in ((lt, (360, 600), '#e6b870'), (lt, (464, 560), '#a9cf9b'), (rt, (112, 800), '#9cc8e8'),
                (lt, ARROYO, '#bbb'), (rt, ARROYO, '#bbb')):
    ax.annotate('', xy=b, xytext=a, arrowprops=dict(arrowstyle='->', color=c, lw=1.4, alpha=0.9), zorder=8)
for t, xy in (('MESA RAMP', (330, 700)), ('ORBIT', (95, 840)), ('ARROYO', (284, 690)), ('SAGUAROS', (505, 560)),
              ('SPINNER', (39, 960)), ('UPPER\nFLIPPER', (500, 760))):
    ax.text(*xy, t, color='w', fontsize=6.5, ha='center', zorder=9)
plt.savefig(OUT, bbox_inches='tight', facecolor=fig.get_facecolor())
print('wrote', OUT)
