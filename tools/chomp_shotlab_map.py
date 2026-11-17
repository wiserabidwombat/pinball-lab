"""M2 v6: Shot Lab rays over the layout (and the reference drawing): each trial's launch from the flip point,
continued as a straight line, coloured by its first shot. Usage: chomp_shotlab_map.py results.json out.png [flipper] [stepMs]"""
import json, math, sys, io, contextlib
res, out = sys.argv[1], sys.argv[2]
flip = sys.argv[3] if len(sys.argv) > 3 else 'right'
step = float(sys.argv[4]) if len(sys.argv) > 4 else 8.3
sys.argv = ['chomp_render_m2.py', '/tmp/_base.png', '((-20,640),(150,1300))']
ns = {'__name__': 'render'}
with contextlib.redirect_stdout(io.StringIO()):
    exec(open('tools/chomp_render_m2.py').read(), ns)
ax, fig = ns['ax'], ns['fig']
col = {'leftLoop': '#00b050', 'waveRamp': '#9933cc', 'harpoonGate': '#ff7a00', 'fishPhone': '#d4a017',
       'buoy': '#0070c0', 'drain': '#d1403a', 'none': '#888888'}
d = json.load(open(res))
for t in d['trials']:
    if t['flipper'] != flip or abs(t['physicsStepMs'] - step) > 1 or not t.get('launch'): continue
    x, y, deg, sp = t['launch']; a = math.radians(deg); L = 1100
    ax.plot([t['flipPoint'][0], x + L * math.cos(a)], [t['flipPoint'][1], y + L * math.sin(a)],
            color=col.get(t['outcome'], '#888888'), lw=0.8, alpha=0.8)
for k, c in col.items(): ax.plot([], [], color=c, label=k)
ax.legend(loc='lower left', fontsize=7)
ax.set_xlim(-20, 640); ax.set_ylim(150, 1300)
ax.set_title(f'Shot Lab: {flip} flipper launches ({step:.0f} ms steps), coloured by first shot', fontsize=9)
fig.savefig(out, dpi=110, bbox_inches='tight')
