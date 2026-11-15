"""Copy of gi-src/tools/tour_layout.py (Table 06 M1 lower table), used as Table 07's base."""
import math

W, H = 600, 1300
leftWallX, rightWallX, laneWallX = 20, 580, 548
laneFloorY, archStartY, topY = 40, 1000, 1270
apronTopY, drainEdgeX, drainEdgeY, drainLipY = 185, 250, 105, 85
leftBulgeBottom, leftBulgeTop, leftBulgeControlInset = 540, 780, 0
rightBulgeBottom, rightBulgeTop, rightBulgeControlInset = 540, 780, 0
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

laneRolloverY = 405
laneRolloverXs = [(leftWallX + laneGuideX) / 2, (laneGuideX + 88) / 2,
                  mirrorSum - (laneGuideX + 88) / 2, mirrorSum - (leftWallX + laneGuideX) / 2]
laneSensorSize = (24, 10)

def flipper_tip(pivot, side, raised=0.0):
    a = flipperRestAngle - raised
    dx = flipperLength * math.cos(a) * (1 if side == 'left' else -1)
    return (pivot[0] + dx, pivot[1] - flipperLength * math.sin(a))
