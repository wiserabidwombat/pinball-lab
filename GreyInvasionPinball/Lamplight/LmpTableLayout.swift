import CoreGraphics
import SpriteKit
import UIKit
import Foundation

// Pinball Lab Table 05 (The Lamplight, Oct 2026), a cozy bookshop-café table. Every Table 05 type is prefixed "Lmp"
// (the app bundle is flat).
// Milestone 1: the card and a NEW lower table in grey box (Aaron chose "center post + one outlane"): the flippers sit
// 11 pt farther apart with a rubber post between their tips, and only the right side has an outlane (the left side is
// closed: a deflector off the left wall feeds the left inlane). The upper table comes in milestones 2–3.

/// All Table 05 geometry in world points. SpriteKit's origin is bottom-left.
/// Same 600 x 1300 world, radius-9 ball and physics as Tables 02–04 (every physics value proven on device there).
enum LmpTableLayout {
    static let worldSize = CGSize(width: 600, height: 1300)

    // MARK: Physics
    static let gravity: CGFloat = -9.2
    static let ballRadius: CGFloat = 9
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1
    static let maxBallSpeed: CGFloat = 2460
    static let wallRestitution: CGFloat = 0.3
    static let wallFriction: CGFloat = 0.1
    static let railRestitution: CGFloat = 0.15
    static let railFriction: CGFloat = 0.02
    static let ballsPerGame = 3

    // MARK: Art
    /// The oblique view the art will be drawn in (Tables 03–04's 22°): a point at height z appears z × this farther up.
    static let oblique: CGFloat = 0.4040
    /// Rendered part boxes (none yet: the parts fall back to their grey-box shapes). Kept so the copied parts build.
    static let upperFlipperArtBox = CGRect(x: -76, y: -15, width: 91, height: 30)
    static let launchGateArtBox = CGRect(x: -35, y: -37, width: 47, height: 48)

    /// A sprite placed by its art box (size + anchor), or nil when the image isn't in the app (grey box then).
    static func artSprite(_ name: String, box: CGRect) -> SKSpriteNode? {
        guard UIImage(named: name) != nil else { return nil }
        let s = SKSpriteNode(imageNamed: name)
        s.size = box.size
        s.anchorPoint = CGPoint(x: -box.minX / box.width, y: -box.minY / box.height)
        return s
    }

    // MARK: Walls
    static let leftWallX: CGFloat = 20
    static let rightWallX: CGFloat = 580
    static let laneWallX: CGFloat = 548
    static let laneFloorY: CGFloat = 40
    static let archStartY: CGFloat = 1000
    static let topY: CGFloat = 1270
    static let apronTopY: CGFloat = 185
    static let drainEdgeX: CGFloat = 250
    static let drainEdgeY: CGFloat = 105
    static let drainLipY: CGFloat = 85
    /// The right (plunger-lane) wall keeps Tables 02–04's inward bulge: without it a ball hit into the right wall
    /// slides straight down the right outlane (Grey Invasion M4 v6). The left side no longer needs one: its deflector
    /// (below) turns a ball sliding down the left wall into the inlane.
    static let rightBulgeBottom: CGFloat = 540
    static let rightBulgeTop: CGFloat = 780
    static let rightBulgeControlInset: CGFloat = 36
    static var laneCenterX: CGFloat { (laneWallX + rightWallX) / 2 }
    static var playfieldCenterX: CGFloat { (leftWallX + laneWallX) / 2 }     // 284

    // MARK: Flippers (T5 M1: 11 pt farther apart than Tables 02–04, for the center post)
    static let leftFlipperPivot = CGPoint(x: 168, y: 220)
    static let rightFlipperPivot = CGPoint(x: 400, y: 220)
    static let flipperLength: CGFloat = 96
    static let flipperPivotRadius: CGFloat = 12
    static let flipperTipRadius: CGFloat = 6
    static let flipperRestAngle: CGFloat = .pi / 6
    static let flipperTravel: CGFloat = .pi / 3
    static let flipperUpSpeed: CGFloat = 25.5
    static let flipperDownSpeed: CGFloat = 14
    static let flipperMass: CGFloat = 2
    static let flipperFriction: CGFloat = 0.4

    static var leftGuideEnd: CGPoint {
        let r = flipperPivotRadius + 1
        return CGPoint(x: leftFlipperPivot.x + r * sin(flipperRestAngle),
                       y: leftFlipperPivot.y + r * cos(flipperRestAngle))
    }

    // MARK: Center post
    /// A rubber post between the flipper tips: tips at rest are 53.8 apart edge to edge, so the r 7 post leaves two
    /// gaps of 19.9 (a ball is 18): a ball dropping straight down the middle usually bounces onto a flipper.
    static let centerPost = CGPoint(x: 284, y: 168)
    static let centerPostRadius: CGFloat = 7
    static let centerPostRestitution: CGFloat = 0.5

    // MARK: Plunger
    static let plungerSize = CGSize(width: 24, height: 50)
    static let plungerRestTop: CGFloat = 120
    static var plungerRestPosition: CGPoint {
        CGPoint(x: laneCenterX, y: plungerRestTop - plungerSize.height / 2)
    }
    static let plungerMaxPull: CGFloat = 60
    static let minLaunchSpeed: CGFloat = 1080
    static let maxLaunchSpeed: CGFloat = 2310
    static let tapLaunchPower: CGFloat = 0.6
    static let plungerZoneMinX: CGFloat = 0.62
    static let plungerZoneMinY: CGFloat = 0.55

    // MARK: Launch lane gate (Table 03's one-way flap)
    static let laneWallTop: CGFloat = 955
    static var gateLow: CGPoint { CGPoint(x: laneWallX, y: laneWallTop) }
    static var gateHigh: CGPoint { CGPoint(x: rightWallX, y: laneWallTop + 28) }

    // MARK: Lower table
    static let mirrorSum: CGFloat = leftWallX + laneWallX   // 568
    static func mirrored(_ p: CGPoint) -> CGPoint { CGPoint(x: mirrorSum - p.x, y: p.y) }

    static let laneGuideX: CGFloat = 54
    static let laneGuideTop: CGFloat = 470
    static let laneGuideBend: CGFloat = 330
    /// The left deflector: from the left wall at y 520 down to the top of the lane guide (55° slope), so a ball
    /// coming down the left wall rolls into the inlane. There is no left outlane.
    static let leftDeflectorTop = CGPoint(x: leftWallX, y: 520)
    static var leftInlaneWall: [CGPoint] {
        [leftDeflectorTop, CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd]
    }
    /// The closed pocket left of the inlane (drawn as a darker floor; no ball can reach it).
    static var leftClosedPocket: [CGPoint] {
        [CGPoint(x: leftWallX, y: apronTopY), leftDeflectorTop, CGPoint(x: laneGuideX, y: laneGuideTop),
         CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd,
         CGPoint(x: leftGuideEnd.x, y: apronTopY - (leftGuideEnd.x - leftWallX) / (drainEdgeX - leftWallX) * (apronTopY - drainEdgeY))]
    }
    static var rightLaneGuide: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideTop), CGPoint(x: laneGuideX, y: laneGuideBend), leftGuideEnd].map { mirrored($0) }
    }

    /// Slings: Tables 02–04's shape, with the bottom side re-angled to run parallel to the new lane-guide slant
    /// (the flippers moved out), keeping the inlane 34.7 wide.
    static let leftSling = (top: CGPoint(x: 88, y: 450),
                            corner: CGPoint(x: 88, y: 347),
                            tip: CGPoint(x: 150, y: 296.2))
    static var rightSling: (top: CGPoint, corner: CGPoint, tip: CGPoint) {
        (mirrored(leftSling.top), mirrored(leftSling.corner), mirrored(leftSling.tip))
    }
    static let slingKickSpeed: CGFloat = 920
    static let slingKickFrom: CGFloat = 0.06
    static let slingKickTo: CGFloat = 0.94
    static let slingTopPostRadius: CGFloat = 7
    static let slingTipPostRadius: CGFloat = 6
    static let slingCornerPostRadius: CGFloat = 5.5
    static let slingPostRestitution: CGFloat = 0.1

    /// The right apron: from the plunger-lane wall down to the right side of the drain chute.
    static var rightApron: [CGPoint] {
        [CGPoint(x: laneWallX, y: apronTopY),
         CGPoint(x: mirrorSum - drainEdgeX, y: drainEdgeY),
         CGPoint(x: mirrorSum - drainEdgeX, y: drainLipY)]
    }
    static let outlaneWallBottom: CGFloat = 215
    static var rightOutlaneWall: [CGPoint] {
        [CGPoint(x: laneGuideX, y: laneGuideBend), CGPoint(x: laneGuideX, y: outlaneWallBottom)].map { mirrored($0) }
    }
    /// Crossed going down: the ball is draining down the right outlane (for the cat-flap save in the rules milestone).
    static let rightOutlaneLine = (a: CGPoint(x: 514, y: 240), b: CGPoint(x: laneWallX, y: 240))

    // MARK: Rules placeholders
    static let slingPoints = 10
    static let centerPostPoints = 50
    static let bannerSeconds: TimeInterval = 1.6

    /// The outer wall: the drain chute's left lip, the left apron slope, the straight left wall (no bulge: the
    /// deflector does its job), the arch, then the right side with its bulge down to the plunger lane.
    static var outerWall: [CGPoint] {
        var points: [CGPoint] = [
            CGPoint(x: drainEdgeX, y: drainLipY),
            CGPoint(x: drainEdgeX, y: drainEdgeY),
            CGPoint(x: leftWallX, y: apronTopY),
            CGPoint(x: leftWallX, y: archStartY),
        ]
        let midX = worldSize.width / 2
        points += quadCurve(from: CGPoint(x: leftWallX, y: archStartY),
                            control: CGPoint(x: leftWallX, y: topY),
                            to: CGPoint(x: midX, y: topY))
        points += quadCurve(from: CGPoint(x: midX, y: topY),
                            control: CGPoint(x: rightWallX, y: topY),
                            to: CGPoint(x: rightWallX, y: archStartY))
        points += [
            CGPoint(x: rightWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: rightBulgeBottom),
        ]
        points += quadCurve(from: CGPoint(x: laneWallX, y: rightBulgeBottom),
                            control: CGPoint(x: laneWallX - rightBulgeControlInset,
                                             y: (rightBulgeBottom + rightBulgeTop) / 2),
                            to: CGPoint(x: laneWallX, y: rightBulgeTop))
        points.append(CGPoint(x: laneWallX, y: laneWallTop))
        return points
    }

    /// Samples a quadratic Bézier into straight segments so it works as an edge chain.
    static func quadCurve(from p0: CGPoint, control c: CGPoint, to p1: CGPoint,
                          segments: Int = 16) -> [CGPoint] {
        (1...segments).map { i in
            let t = CGFloat(i) / CGFloat(segments)
            let u = 1 - t
            return CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                           y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
        }
    }
}
