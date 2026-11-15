"""Table 07 (CHOMP!) layout in Python, milestone 1: the lower table.
Base = Table 06's lower table (tour_layout.py, Monsoon's proven walls/flippers/slings), changed to match Jaws:
  removed: the rocket post between the flippers, the O-R-B-T letters (plain lane switches stay)
  changed: the left-outlane kickback -> the inner tube save (same kicker, action button in a timed window)
  added:   inlane up-posts, the right outlane save (rubber post + one-way gate), the pier mini-flipper pocket
           (feed lane, mini-flipper, beach-ball bumper, buoy target) on the right side.
First-pass positions from Jaws photos/rulesheets; tune with renders + the Shot Lab."""
import math
from chomp_base_tour_layout import (W, H, leftWallX, rightWallX, laneWallX, laneFloorY, archStartY, topY, apronTopY,
                         drainEdgeX, drainEdgeY, drainLipY, laneWallTop, mirrorSum, ballRadius,
                         leftFlipperPivot, rightFlipperPivot, flipperLength, flipperPivotRadius, flipperTipRadius,
                         flipperRestAngle, mirrored, outer_wall, leftLaneGuide, rightLaneGuide, leftOutlaneWall,
                         rightOutlaneWall, leftOutlanePostRail, rightOutlanePostRail, rightApron, leftSling,
                         rightSling, laneRolloverY, laneRolloverXs, laneSensorSize, flipper_tip, laneGuideX)

# ---- Inlane up-posts: one near the bottom of each inlane, in the middle of the channel between the lane guide's
# slanted leg and the sling's bottom edge. Ball sits on it; the gaps either side are < 1 ball diameter.
def _inlane_center(x):
    g0, g1 = leftLaneGuide[1], leftLaneGuide[2]          # guide's slanted leg
    s0, s1 = leftSling[1], leftSling[2]                  # sling's bottom edge
    gy = g0[1] + (g1[1] - g0[1]) * (x - g0[0]) / (g1[0] - g0[0])
    sy = s0[1] + (s1[1] - s0[1]) * (x - s0[0]) / (s1[0] - s0[0])
    return (x, (gy + sy) / 2)
upPostRadius = 5
leftUpPost = _inlane_center(128)
rightUpPost = mirrored(leftUpPost)

# ---- Left outlane: the inner tube save. Tour's kickback kicker, armed only while the action button window is open.
innerTubeLamp = (37, 300)
innerTubeWindow = 0.6          # s the insert flashes after the outlane switch (first award: grace, later shorter)

# ---- Right outlane save: a rubber post against the outer wall, and a one-way gate in the right lane guide.
outlaneSavePost = (544.5, 440)
outlaneSavePostRadius = 3.5
saveGateTopY, saveGateBottomY = 425, 393     # opening in the right lane guide (x = mirrorSum - laneGuideX)
saveGateX = mirrorSum - laneGuideX
# right lane guide with the gate opening cut out
rightLaneGuideWithGate = [[(saveGateX, rightLaneGuide[0][1]), (saveGateX, saveGateTopY)],
                          [(saveGateX, saveGateBottomY)] + rightLaneGuide[1:]]

# ---- The pier mini-flipper pocket (right side, above the right sling).
miniPivot = (539, 596)
miniLength = 56
miniRestAngle = math.pi / 6          # 30 deg below horizontal, tip pointing left
miniSwing = math.pi / 3              # up to 30 deg above horizontal
miniPivotRadius, miniTipRadius = 9, 5
feedLaneInnerX = 514                  # feed lane = x 514..548 (34 wide), down the wall onto the flipper's base
feedLaneInner = [(feedLaneInnerX, 790), (feedLaneInnerX, 660)]
miniLaneSensor = (531, 700)           # the "lane above the mini-flipper" rollover (skill shot 2, fish finder, quickshot)
pocketFloor = [(laneWallX, 575), (miniPivot[0] + 2, miniPivot[1] - 11)]   # under the pivot, sheds to the flipper
pocketDeflector = [(laneWallX, 614), (534.5, 603.8)]   # M1 v3: a short cap from the wall onto the pivot cap's left shoulder
bumperCenter, bumperRadius = (462, 752), 22
buoyTarget = ((452, 690), 205.0)      # standup centre, facing (deg): toward the lower-left, hit from the left flipper

def mini_tip(raised=0.0):
    a = miniRestAngle - raised
    return (miniPivot[0] - miniLength * math.cos(a), miniPivot[1] - miniLength * math.sin(a))

# Where the mini-flipper has to reach (milestone 2 parts, shown as markers only)
harpoonLaneMouth = (70, 860)
leftBankCenter = (100, 640)
