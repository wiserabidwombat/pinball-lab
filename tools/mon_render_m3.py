"""Table 04 (Monsoon) milestone 3: a top-down drawing of the grey-box layout over the lower art, with the spots kept
clear for the helix, the captive ball and the dust devil, and the main shot lines (as measured on Table 03, whose
top this is). The upper table reuses cth_layout's numbers; the Monsoon changes are listed here.
Usage: python3 mon_render_m3.py <mon_lower.jpg> <out.png>"""
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
# the mesa ramp (Table 03's right ramp) as a band
try:
    rp = L.right_ramp_path()
    pts = rp[0].pts
    xs, ys = zip(*pts); ax.plot(xs, ys, color='#e6b870', lw=14, alpha=0.35, zorder=2, solid_capstyle='round')
except Exception as e:
    print('ramp path skipped:', e)
# reserved spots
for patch, name, at in ((Circle(DUST, DUST_R), 'DUST DEVIL', DUST), (Circle(HELIX, HELIX_R), 'HELIX', HELIX),
                        (Rectangle(CAPTIVE[:2], CAPTIVE[2], CAPTIVE[3]), 'CAPTIVE\nBALL', (CAPTIVE[0] + CAPTIVE[2] / 2, CAPTIVE[1] + CAPTIVE[3] / 2))):
    patch.set(fc='none', ec='#f2c768', lw=1.6, ls='--', zorder=6); ax.add_patch(patch)
    ax.text(*at, name, color='#f2c768', ha='center', va='center', fontsize=7, fontweight='bold', zorder=7)
# shot lines from the flipper tips (raised): left flipper → mesa ramp and standups, right → orbit, both → arroyo
lt = (L.L_PIVOT[0] + 96 * math.cos(math.radians(30)), L.L_PIVOT[1] + 96 * math.sin(math.radians(30)))
rt = (L.R_PIVOT[0] - 96 * math.cos(math.radians(30)), L.R_PIVOT[1] + 96 * math.sin(math.radians(30)))
for a, b, c in ((lt, (360, 600), '#e6b870'), (lt, (464, 560), '#a9cf9b'), (rt, (112, 800), '#9cc8e8'),
                (lt, ARROYO, '#bbb'), (rt, ARROYO, '#bbb')):
    ax.annotate('', xy=b, xytext=a, arrowprops=dict(arrowstyle='->', color=c, lw=1.4, alpha=0.9), zorder=8)
for t, xy in (('MESA RAMP', (395, 640)), ('ORBIT', (95, 840)), ('ARROYO', (284, 690)), ('SAGUAROS', (505, 560)),
              ('SPINNER', (39, 960)), ('UPPER\nFLIPPER', (500, 760))):
    ax.text(*xy, t, color='w', fontsize=6.5, ha='center', zorder=9)
plt.savefig(OUT, bbox_inches='tight', facecolor=fig.get_facecolor())
print('wrote', OUT)
