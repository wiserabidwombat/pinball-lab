"""Table 06, Concept A (the Grand Fan): where every part goes. Shot mouths at the shot line, the centrepiece behind
the centre shot, targets only there or hugging a side wall. Builds on tour_layout.py (walls, flippers, lower table)."""
import math
import tour_layout as L

TIP_L = L.flipper_tip(L.leftFlipperPivot, 'left')     # (262, 172)
TIP_R = L.flipper_tip(L.rightFlipperPivot, 'right')   # (306, 172)
TOP = 1270
SHOT_LINE = 600          # the height our flippers reach (Monsoon's centre hole / ramp mouth 582-600); 790 was too high
OPEN_BAND = (470, SHOT_LINE)
CENTRE_OPEN = (150, 418) # the middle half of the width (x 150-418) must stay clear in the open band

def ang(frm, p): return math.degrees(math.atan2(p[1] - frm[1], p[0] - frm[0]))

# The fan: (name, mouth centre, the flipper that makes it). The left wall stays clear above the kickback (its ball rides
# the bulge up into the left orbit); the right orbit's mouth sits above the Mars bunker.
# The Saturn loop is the upper flipper's shot (plan: the upper flipper shoots the Saturn loop and Mission Control), so it
# has no mouth in the lower fan; that leaves room for the left orbit to clear the R-O-C bank.
SHOTS = [
    ('L orbit',   (40, 900),  'R'),
    ('Moon ramp', (200, 612), 'R'),
    ('centre',    (284, 925), 'both'),
    ('wire ramp', (388, 600), 'L'),
    ('asteroids', (458, 600), 'L'),
    ('R orbit',   (526, 700), 'L'),
]

# The centrepiece, v10 (Aaron 7 Nov 2026: pattern the table after real tables, nothing in the middle; the rules were
# rethought): the ROCKET on its launch pad at the back of the open centre channel (MM's castle / AFM's saucer). The
# pad's blast door is a bash target that counts the countdown down on five lamps; on "1" the rocket lifts off, the
# door drops and Mission Control (the scoop under the rocket) is open. Kick-out: a subway to the top of the left inlane.
# v11 (Aaron: "I can't hit the rocket with a caught ball… I miss the rocket to either side"): the pad gets a funnel — two
# guide rails 70° steep (near-parallel to the shot, see the skill) from a 122 pt mouth at y 808 down to the 36 pt door —
# and the whole pad comes 50 pt forward. A cradled ball that would have passed 40 pt wide now rides a rail into the door.
# v12: the whole pad down to where a CRADLED ball's lob reaches (Aaron: v11 at 934 still out of reach from a catch;
# the y 640 bank and the lane to 784 were reachable, 900 was not). Door 790, mouth 110 wide at 690, scoop 822, peak 854.
# v15: back up to the castle position with the real-table flippers (35 rad/s, rubber 0.3): door 934, mouth 122 at 808.
rocketPad = [(223, 808), (266, 926), (266, 980), (284, 998), (302, 980), (302, 926), (345, 808)]
blastDoor = (284, 934); dropFace = 34
countdownLamps = [(284, 500 + 18 * i) for i in range(5)]
missionScoop = (284, 966)
missionLeftWall, missionRightWall = rocketPad, []
missionSubwayExit = (71, 490)
missionEject = (0, -300)

# Right side wall: the ROCKET standups, two banks of three (R-O-C, K-E-T) up the wall, facing the left flipper.
def wall_x(y, side):
    pts = [p for p in L.outer_wall() if 470 < p[1] < 790 and (p[0] < 284) == (side == 'L')]
    pts.sort(key=lambda p: p[1])
    for a, b in zip(pts, pts[1:]):
        if a[1] <= y <= b[1]:
            return a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])
    return min(pts, key=lambda p: abs(p[1] - y))[0]
def hug(y, side, frm, depth=8, gap=3):
    """A plate centre at height y, its face toward `frm`, its back corner `gap` pt off the side wall."""
    a = math.radians(ang((0, 0), (frm[0] - (0 if side == 'L' else 600), frm[1] - y)))
    for off in [x * 0.5 for x in range(2, 120)]:
        x = wall_x(y, side) + (off if side == 'L' else -off)
        n = ang((x, y), frm)
        pts = L.face((x, y), n, 26, depth)
        wx = [wall_x(py, side) for _, py in pts]
        g = min((px - w) if side == 'L' else (w - px) for (px, _), w in zip(pts, wx))
        if g >= gap: return (x, y), n
# Straight banks, as on real tables: one row of identical targets on one flat backboard, all facing the same way, with a
# sloping cap from each end to the side wall so nothing rests on top or gets behind (v2's staircase trapped a ball at
# its top). Each bank leans with its wall, its face turned down toward the far flipper.
def straight_bank(first, line_deg, step, n, gap_after=None, extra=0):
    t = math.radians(line_deg); out = []; d = 0
    for i in range(n):
        out.append((first[0] + d * math.cos(t), first[1] + d * math.sin(t)))
        d += step + (extra if gap_after is not None and i == gap_after else 0)
    return out
def backboard(centres, line_deg, depth, behind, pad):
    """The wall behind a bank: parallel to the face line, `behind` pt behind the plates' backs, `pad` past each end."""
    t = math.radians(line_deg); tx, ty = math.cos(t), math.sin(t); nx, ny = ty, -tx    # (nx, ny) points behind
    off = depth / 2 + behind
    a = (centres[0][0] - tx * pad + nx * off, centres[0][1] - ty * pad + ny * off)
    b = (centres[-1][0] + tx * pad + nx * off, centres[-1][1] + ty * pad + ny * off)
    return a, b

# ROCKET moves to the upper table in M3 (Aaron, 7 Nov 2026): R-O-C beside the Moon, K-E-T in front of the bumpers.
def rocket_targets(): return []
rocketBack = []

# Mars, drawn on the LEFT here and then mirrored onto the RIGHT wall (the left wall stays clear for the kickback).
# Left side wall: Mars. The rover scoop in a bunker against the wall; the sample bank (three drops in a straight row)
# is the bunker's front, facing the right flipper, so the rover is open only once the samples are down.
sampleLine = 78                        # going up, leaning out; the face points -20° (right, 20° down)
sampleNormal = sampleLine - 90
sampleXY = straight_bank((68, 514), sampleLine, 27, 3)
def sample_targets(): return [(p, sampleNormal) for p in sampleXY]
_sa, _sb = backboard(sampleXY, sampleLine, 8, 0, 14)
# The bunker: the floor is a V under the scoop, so a ball that gets in past a dropped sample lands in the scoop's catch
# (the scene also catches any ball found inside); the roof slopes up to the wall so balls from above roll off.
roverScoop = (44, 522)
bunkerFloor = [(_sa[0], _sa[1] + 2), (44, 506), (20, 514)]
bunkerRoof = [(_sb[0], _sb[1] - 2), (60, 598), (wall_x(612, 'L') - 1, 612)]
def line_y(pts, x):
    for u, v in zip(pts, pts[1:]):
        lo, hi = min(u[0], v[0]), max(u[0], v[0])
        if lo <= x <= hi and hi > lo: return u[1] + (x - u[0]) * (v[1] - u[1]) / (v[0] - u[0])
def in_bunker(p):
    """Behind the sample bank's face line, below the roof line and above the floor line (the real shape, not a box:
    v3's box caught balls rolling on top of the roof)."""
    x0 = _sa[0] + (p[1] - _sa[1]) * (_sb[0] - _sa[0]) / (_sb[1] - _sa[1])
    r, f = line_y(bunkerRoof, p[0]), line_y(bunkerFloor, p[0])
    return p[0] < x0 - 6 and r is not None and f is not None and f < p[1] < r
roverEject = (240, 60)     # out through the dropped bank, a lob onto the left flipper

# --- Mars on the right wall: the left-hand bunker above, mirrored about the table's centre line. ---
_m = lambda p: (L.mirrorSum - p[0], p[1])
sampleXY = [_m(p) for p in sampleXY]
sampleNormal = 180 - sampleNormal                 # faces 200°: left and 20° down, toward the left flipper
def sample_targets(): return [(p, sampleNormal) for p in sampleXY]
roverScoop = _m(roverScoop)
bunkerFloor = [_m(p) for p in bunkerFloor]
bunkerRoof = [_m(p) for p in bunkerRoof]
_sa, _sb = _m(_sa), _m(_sb)
_in_bunker_left = in_bunker
def in_bunker(p): return _in_bunker_left(_m(p))
roverEject = (-roverEject[0], roverEject[1])      # a lob onto the right flipper

# --- 7 Nov 2026: the right side wall is straight (no bulge). Mars moves DX toward the wall and its roof runs to the wall,
# so no V is left between the roof's end and the wall. ---
DX, DY = 8, 8
_sh = lambda p: (p[0] + DX, p[1] + DY)
sampleXY = [_sh(p) for p in sampleXY]
roverScoop = _sh(roverScoop)
bunkerFloor = [_sh(p) for p in bunkerFloor[:-1]] + [(548, bunkerFloor[-1][1] + DY)]
_r0, _r1 = _sh(bunkerRoof[0]), _sh(bunkerRoof[1])
_slope = (bunkerRoof[2][1] - bunkerRoof[1][1]) / (bunkerRoof[2][0] - bunkerRoof[1][0])
bunkerRoof = [_r0, _r1, (548, _r1[1] + (548 - _r1[0]) * _slope)]
_sa, _sb = _sh(_sa), _sh(_sb)
def in_bunker(p):
    x0 = _sa[0] + (p[1] - _sa[1]) * (_sb[0] - _sa[0]) / (_sb[1] - _sa[1])
    r, f = line_y(bunkerRoof, p[0]), line_y(bunkerFloor, p[0])
    return p[0] > x0 + 6 and r is not None and f is not None and f < p[1] < r

# --- 7 Nov 2026: R-O-C on the LEFT wall over a '/' deflector (Aaron). The left bulge is gone. The kickback's ball (fired
# from the lane centre) hits the underside of the 65° '/' and comes off it up and to the right, arcing into the middle
# (tools/tour_kickback_sim.py: exit ~(576,409) pt/s, peak ~(290,626), back down by the right inlane). R-O-C runs on up
# from the top of the '/' at 40°, facing the right flipper; a roof slopes from its top back down to the wall. ---
# v8 (Aaron 16:36: "The left bank sticks out pretty far and removes the risk of the ball draining"): the '/' starts 50 pt
# above the outlane's top (y 530, not 480) so wall-sliders can drop into the outlane under it again, and the bank runs on
# up the '/' line (65°, not 40°), so it reaches x 86 instead of 116; the L orbit mouth goes up to y 900 to clear it. tools/tour_left_drain_sim.py: left outlane 0% (v7)
# → ~4.5% (v6 with the bulge: 7%); the kickback still comes off the '/' into the middle.
DEFL_LO = (20, 530)
DEFL_HI = (50, 530 + 30 * math.tan(math.radians(65)))
rocLine = 65
rocNormal = rocLine - 90                  # -25°: down and right, toward the right flipper (~30° off square)
def _along(p, deg, d): t = math.radians(deg); return (p[0] + d * math.cos(t), p[1] + d * math.sin(t))
_n = math.radians(rocNormal)
def _front(p, d): return (p[0] + d * math.cos(_n), p[1] + d * math.sin(_n))
ROC_TOP = _along(DEFL_HI, rocLine, 4 + 3 * 26 + 2 * 2)                # 4 pt pad, three 26 pt standups 2 pt apart
rocCenters = [_front(_along(DEFL_HI, rocLine, 4 + 13 + i * 28), 4) for i in range(3)]
ROC_STRUCT = [DEFL_LO, DEFL_HI, ROC_TOP, (20, ROC_TOP[1] + 42)]       # the '/', the backboard, the roof to the wall
def roc_targets(): return [(c, rocNormal) for c in rocCenters]
