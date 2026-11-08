"""Table 06 (Orbit: Grand Tour) layout in Python, mirroring TourTableLayout.swift (milestone 1: the lower table).
Same names as the Swift enum. Renders: tools/tour_render_m1.py."""
import math

W, H = 600, 1300
leftWallX, rightWallX, laneWallX = 20, 580, 548
laneFloorY, archStartY, topY = 40, 1000, 1270
apronTopY, drainEdgeX, drainEdgeY, drainLipY = 185, 250, 105, 85
leftBulgeBottom, leftBulgeTop, leftBulgeControlInset = 540, 780, 0   # left bulge removed 7 Nov 2026 (the R-O-C '/' deflector does its job)
rightBulgeBottom, rightBulgeTop, rightBulgeControlInset = 540, 780, 0   # right bulge removed 7 Nov 2026 (the Mars bunker guards the right outlane)
laneWallTop = 955
mirrorSum = leftWallX + laneWallX
ballRadius = 9

leftFlipperPivot = (179, 220); rightFlipperPivot = (389, 220)
flipperLength, flipperPivotRadius, flipperTipRadius = 96, 12, 6
flipperRestAngle = math.pi / 6

def mirrored(p): return (mirrorSum - p[0], p[1])

def quad(p0, c, p1, n=16):
    out = []
    for i in range(1, n + 1):
        t = i / n; u = 1 - t
        out.append((u*u*p0[0] + 2*u*t*c[0] + t*t*p1[0], u*u*p0[1] + 2*u*t*c[1] + t*t*p1[1]))
    return out

def outer_wall():
    pts = [(drainEdgeX, drainLipY), (drainEdgeX, drainEdgeY), (leftWallX, apronTopY), (leftWallX, leftBulgeBottom)]
    pts += quad((leftWallX, leftBulgeBottom), (leftWallX + leftBulgeControlInset, (leftBulgeBottom + leftBulgeTop) / 2), (leftWallX, leftBulgeTop))
    pts.append((leftWallX, archStartY))
    mid = W / 2
    pts += quad((leftWallX, archStartY), (leftWallX, topY), (mid, topY))
    pts += quad((mid, topY), (rightWallX, topY), (rightWallX, archStartY))
    pts += [(rightWallX, laneFloorY), (laneWallX, laneFloorY), (laneWallX, rightBulgeBottom)]
    pts += quad((laneWallX, rightBulgeBottom), (laneWallX - rightBulgeControlInset, (rightBulgeBottom + rightBulgeTop) / 2), (laneWallX, rightBulgeTop))
    pts.append((laneWallX, laneWallTop))
    return pts

def guide_end():
    r = flipperPivotRadius + 1
    return (leftFlipperPivot[0] + r * math.sin(flipperRestAngle), leftFlipperPivot[1] + r * math.cos(flipperRestAngle))

laneGuideX, laneGuideTop, laneGuideBend = 54, 470, 330
leftLaneGuide = [(laneGuideX, laneGuideTop), (laneGuideX, laneGuideBend), guide_end()]
rightLaneGuide = [mirrored(p) for p in leftLaneGuide]
outlaneWallBottom = 215
leftOutlaneWall = [(laneGuideX, laneGuideBend), (laneGuideX, outlaneWallBottom)]
rightOutlaneWall = [mirrored(p) for p in leftOutlaneWall]
leftOutlanePostRail = [(laneGuideX, laneGuideTop), (44, 482)]
rightOutlanePostRail = [mirrored(p) for p in leftOutlanePostRail]
rightApron = [(laneWallX, apronTopY), (mirrorSum - drainEdgeX, drainEdgeY), (mirrorSum - drainEdgeX, drainLipY)]
leftSling = ((88, 450), (88, 347), (150, 300.4))
rightSling = tuple(mirrored(p) for p in leftSling)

# Milestone 1, new: O-R-B-T rollovers, one in each outlane and inlane (left outlane, left inlane, right inlane, right
# outlane), and their lamps just below them.
laneRolloverY = 405
laneRolloverXs = [(leftWallX + laneGuideX) / 2, (laneGuideX + 88) / 2,
                  mirrorSum - (laneGuideX + 88) / 2, mirrorSum - (leftWallX + laneGuideX) / 2]
laneSensorSize = (24, 10)
laneLampY = 378
laneLetters = "ORBT"
# The pop-up rocket post between the flipper tips.
rocketPost = (284, 162)
rocketPostRadius = 7
kickbackLamp = (37, 300)

def flipper_tip(pivot, side, raised=0.0):
    a = flipperRestAngle - raised
    dx = flipperLength * math.cos(a) * (1 if side == 'left' else -1)
    return (pivot[0] + dx, pivot[1] - flipperLength * math.sin(a))

# ---- Milestone 2 (grey-box layout, lower half): targets and scoops between the slings and the upper table. ----
def face(center, normal_deg, width, depth):
    """A thin target: its four corners, the face toward normal_deg (degrees, 0 = +x)."""
    a = math.radians(normal_deg); nx, ny = math.cos(a), math.sin(a); tx, ty = -ny, nx
    cx, cy = center; w, d = width / 2, depth / 2
    return [(cx + tx*w + nx*d, cy + ty*w + ny*d), (cx - tx*w + nx*d, cy - ty*w + ny*d),
            (cx - tx*w - nx*d, cy - ty*w - ny*d), (cx + tx*w - nx*d, cy + ty*w - ny*d)]

def aim(frm, to): return math.degrees(math.atan2(to[1] - frm[1], to[0] - frm[0]))

dropSize = (24, 8)        # face width, depth
standupSize = (26, 8)
rightFlipperAim = (300, 200)   # where left-side targets face (the right flipper's sweet spot)

# The countdown bank: five drops 5-4-3-2-1 across the centre, facing straight down the table.
countdownY = 640
countdownXs = [228, 256, 284, 312, 340]
countdownLabels = ["5", "4", "3", "2", "1"]
# Mission Control: a funnel behind the bank narrowing onto the scoop, with a pointed roof that sheds balls from above.
missionScoop = (284, 742)
missionEject = (-90, -560)           # pt/s, toward the left flipper
missionLeftWall = [(214, 634), (214, 700), (262, 766), (284, 782)]
missionRightWall = [(mirrorSum - x, y) for x, y in missionLeftWall]   # mirrored about 284

# ROCKET standups: R-O-C on the left facing the right flipper, K-E-T mirrored on the right.
def bank(first, normal_deg, step, n):
    """n targets in a straight row from `first` along the face line (tangent of normal_deg), `step` apart."""
    t = math.radians(normal_deg + 90)
    return [(first[0] + i * step * math.cos(t), first[1] + i * step * math.sin(t)) for i in range(n)]
rocketNormal = aim((100, 540), rightFlipperAim)
rocketLeft = bank((72, 518), rocketNormal, 34, 3)     # 26 pt faces 8 pt apart: the ball can't get between them
rocketLabels = ["R", "O", "C", "K", "E", "T"]
def rocket_targets():
    out = []
    for p in rocketLeft: out.append((p, rocketNormal))
    for p in reversed(rocketLeft): out.append((mirrored(p), 180 - rocketNormal))
    # order R O C K E T: right bank reads K E T from the top down → reverse it
    return out

# Mars: the sample bank (three drops) on the left, and the rover scoop above it. The rover shot and the rover's eject
# share one corridor from the right flipper, passing above the sample bank.
sampleNormal = aim((120, 660), rightFlipperAim)
sampleCenters = bank((96, 650), sampleNormal, 26, 3)
def sample_targets(): return [(p, sampleNormal) for p in sampleCenters]
roverScoop = (140, 820)
roverEject = (185, -651)     # pt/s, back down the corridor toward the right flipper
scoopRadius, scoopCapture = 14, 16
