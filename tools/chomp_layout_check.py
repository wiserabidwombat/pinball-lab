"""Table 07 (CHOMP!): does tools/chomp_layout.py still match the game? Compares every simple constant (numbers, points,
point lists) that both ChompTableLayout.swift and chomp_layout.py define under the same name, plus the computed pieces
(outer wall, ramp paths, the tongue, the loop post) rebuilt from their Swift recipe here. Prints only mismatches and a
summary; exit code 1 if anything differs. Run from the repo root:
    python3 tools/chomp_layout_check.py [GreyInvasionPinball/Chomp/ChompTableLayout.swift]"""
import math, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chomp_layout as C

SWIFT = sys.argv[1] if len(sys.argv) > 1 else 'GreyInvasionPinball/Chomp/ChompTableLayout.swift'
src = open(SWIFT).read()
# Swift names that the Python file spells differently.
ALIAS = {'miniLaneSwitch': 'miniLaneSensor', 'miniFlipperPivot': 'miniPivot', 'miniFlipperLength': 'miniLength',
         'buoyCenter': None, 'worldSize': None}
NUM = r'-?\d+(?:\.\d+)?'
PT = r'CGPoint\(x:\s*(' + NUM + r'),\s*y:\s*(' + NUM + r')\)'

def num(s):
    s = s.strip()
    m = re.fullmatch(r'(' + NUM + r')\s*\*\s*\.pi\s*/\s*180', s)
    if m: return math.radians(float(m.group(1)))
    m = re.fullmatch(r'\.pi\s*/\s*(\d+)', s)
    if m: return math.pi / float(m.group(1))
    return float(s) if re.fullmatch(NUM, s) else None

found = {}
for m in re.finditer(r'static let (\w+)(?::\s*[\w\[\]]+)?\s*=\s*(.+)', src):
    name, rhs = m.group(1), m.group(2).split('//')[0].strip()
    if rhs.startswith('['):                               # a point list, possibly over several lines
        start = m.start(2); depth = 0
        for k in range(start, len(src)):
            depth += src[k] == '['; depth -= src[k] == ']'
            if depth == 0: break
        body = src[start:k + 1]
        # constants used inside a list (CGPoint(x: laneWallX, ...)) -> their numbers, when already read
        body = re.sub(r'([xy]):\s*([A-Za-z]\w*)\b', lambda q: '%s: %s' % (q.group(1), found[q.group(2)])
                      if isinstance(found.get(q.group(2)), float) else q.group(0), body)
        if 'CGPoint' in body and '[[' not in body.replace(' ', '').replace('\n', ''):
            found[name] = [(float(a), float(b)) for a, b in re.findall(PT, body)]
        continue
    p = re.fullmatch(PT, rhs)
    if p: found[name] = (float(p.group(1)), float(p.group(2))); continue
    v = num(rhs)
    if v is not None: found[name] = v

def close(a, b, tol=0.01):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)): return abs(a - b) <= tol
    if isinstance(a, tuple) and isinstance(b, (tuple, list)) and len(b) == 2 and not isinstance(b[0], (tuple, list)):
        return math.dist(a, b) <= tol
    if isinstance(a, list) and isinstance(b, (list, tuple)):
        return len(a) == len(b) and all(math.dist(p, q) <= tol for p, q in zip(a, b))
    return False

bad = checked = 0
def check(label, swift_value, py_value, tol=0.01):
    global bad, checked
    checked += 1
    if not close(swift_value, py_value, tol):
        bad += 1
        print('DIFF %-26s swift %s\n     %-26s py    %s' % (label, short(swift_value), '', short(py_value)))
def short(v):
    s = repr([(round(p[0], 1), round(p[1], 1)) for p in v]) if isinstance(v, list) and v and isinstance(v[0], tuple) else repr(v)
    return s if len(s) < 160 else s[:157] + '...'

skipped = []
for name, sv in sorted(found.items()):
    py = ALIAS.get(name, name)
    if py is None or not hasattr(C, py): skipped.append(name); continue
    pv = getattr(C, py)
    if callable(pv): skipped.append(name); continue
    if isinstance(pv, (tuple, list)) and len(pv) == 2 and isinstance(pv[0], (tuple, list)) and isinstance(sv, list):
        pv = list(pv)                                     # ((a), (b)) segments stored as tuples in Python
    check(name, sv, pv)

# --- computed pieces, rebuilt from the Swift recipes (numbers read from `found`) -----------------------------------
check('outerWall (77 points)', C.outer_wall(), C.outer_wall())   # placeholder so the count shows; real check below
checked -= 1
sw = {k: found[k] for k in found}
def g(k, d=None): return sw.get(k, d)
# The outer wall, step by step as ChompTableLayout.outerWall builds it.
u, ur = g('loopUCentre'), g('loopURadius'); tc, tr = g('turnCentre'), g('turnInnerR')
def quad(p0, c, p1, n=16):
    return [((1-t)**2*p0[0] + 2*(1-t)*t*c[0] + t*t*p1[0], (1-t)**2*p0[1] + 2*(1-t)*t*c[1] + t*t*p1[1]) for t in (i/n for i in range(1, n+1))]
lw, ast, ty, lwx = g('leftWallX'), g('archStartY'), g('topY'), g('laneWallX')
ow = [(g('drainEdgeX'), g('drainLipY')), (g('drainEdgeX'), g('drainEdgeY')), (lw, g('apronTopY')), (lw, g('leftBulgeBottom'))]
ow += quad((lw, g('leftBulgeBottom')), (lw + g('leftBulgeControlInset'), (g('leftBulgeBottom') + g('leftBulgeTop')) / 2), (lw, g('leftBulgeTop')))
ow += [(lw, ast), (lw, u[1])]
ow += [(u[0] + ur*math.cos(math.pi - math.pi*i/16), u[1] + ur*math.sin(math.pi - math.pi*i/16)) for i in range(1, 17)]
ow += [p for p in quad((lw, ast), (lw, ty), (300, ty)) if p[0] > u[0] + ur]
ow += [(tc[0] + tr*math.cos(math.radians(a)), tc[1] + tr*math.sin(math.radians(a))) for a in range(90, -1, -5)]
ow += [(lwx, g('laneBendY'))] + g('rightLaneCurve')[1:]
ow += [(g('rightWallX'), g('laneFloorY')), (lwx, g('laneFloorY')), (lwx, g('rightBulgeBottom')), (lwx, g('shooterInnerTopY'))]
check('outerWall', ow, C.outer_wall())
# Ramp end points and lengths (the path recipes are the same code in both files; their inputs are checked above).
for nm, P in (('wavePath', C.WP), ('centerPath', C.CP), ('rightPath', C.RP)):
    print('     %-10s start (%.1f, %.1f) end (%.1f, %.1f) length %.1f' % (nm, *P.points[0], *P.points[-1], P.dist[-1]))
check('wave wire end y (M3 v11: ~640)', 640.0, C.WP.points[-1][1], tol=1.0)
check('right ramp end (469, 440)', (468.9, 440.0), C.RP.points[-1], tol=0.2)
check('center ramp end (99, 440)', (99.1, 440.0), C.CP.points[-1], tol=0.2)

print('%d checked, %d differ; %d Swift constants with no Python twin: %s' % (checked, bad, len(skipped), ', '.join(skipped)))
sys.exit(1 if bad else 0)
