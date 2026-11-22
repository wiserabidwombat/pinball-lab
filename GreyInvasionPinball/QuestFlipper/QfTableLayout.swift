// Pinball Lab Table 09 (Quest & Flipper): the table's physics and part constants. The Haunted Forest's geometry is in
// QfForestLayout.swift, generated from tools/qf_layout.py.
// T9 M1 v1: real ball scale and real physics, copied from Neon Labyrinth / CHOMP! (a 30 pt ball, 80 pt flippers,
// gravity −6.0, the Visual-Pinball-style flipper model with a 51° stroke), plus CHOMP!'s plunger.
import SpriteKit
import UIKit
import CoreGraphics

enum QfTableLayout {
    // MARK: World and ball
    static let worldSize = QfForestLayout.worldSize
    static let gravity: CGFloat = QfForestLayout.gravity
    static let ballRadius: CGFloat = QfForestLayout.ballRadius
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1
    static let maxBallSpeed: CGFloat = 3500
    static let wallRestitution: CGFloat = 0.3
    static let wallFriction: CGFloat = 0.1
    static let railRestitution: CGFloat = 0.15
    static let railFriction: CGFloat = 0.02
    static let postRestitution: CGFloat = 0.1

    // MARK: Art (grey box for now; pixel art comes in the art milestone)
    static let oblique: CGFloat = 0.4040
    static let upperFlipperArtBox = CGRect(x: -76, y: -15, width: 91, height: 30)
    static let rampTopHeight: CGFloat = 40
    static func artSprite(_ name: String, box: CGRect) -> SKSpriteNode? {
        guard UIImage(named: name) != nil else { return nil }
        let s = SKSpriteNode(imageNamed: name)
        s.size = box.size
        s.anchorPoint = CGPoint(x: -box.minX / box.width, y: -box.minY / box.height)
        return s
    }

    // MARK: Flippers (CHOMP!'s model and values)
    static let flipperLength: CGFloat = QfForestLayout.flipperLength
    static let flipperPivotRadius: CGFloat = QfForestLayout.flipperPivotRadius
    static let flipperTipRadius: CGFloat = QfForestLayout.flipperTipRadius
    static let flipperRestAngle: CGFloat = QfForestLayout.flipperRestAngle
    static let flipperTravel: CGFloat = QfForestLayout.flipperTravel
    static let flipperUpSpeed: CGFloat = 35
    static let flipperModel = true
    static let flipperCoilAccel: CGFloat = 1200
    static let flipperCoilRamp: CGFloat = 0.006
    static let flipperMaxSpeed: CGFloat = 1000
    static let flipperElasticity: CGFloat = 0.85
    static let flipperElasticityFalloff: CGFloat = 0.35
    static let flipperRubberFriction: CGFloat = 0
    static let flipperBounceThreshold: CGFloat = 600
    static let flipperRestitution: CGFloat = 0.3
    static let flipperDownSpeed: CGFloat = 14
    static let flipperMass: CGFloat = 2
    static let flipperFriction: CGFloat = 0.4

    // MARK: Slings
    static let slingKickSpeed: CGFloat = 920
    static let slingKickFrom: CGFloat = 0.06
    static let slingKickTo: CGFloat = 0.94
    static let slingTopPostRadius: CGFloat = QfForestLayout.slingTopPostRadius
    static let slingTipPostRadius: CGFloat = QfForestLayout.slingTipPostRadius
    static let slingCornerPostRadius: CGFloat = QfForestLayout.slingCornerPostRadius
    static let slingPostRestitution: CGFloat = 0.1

    // MARK: Plunger (CHOMP!'s, in a 45 pt lane x 580–625)
    static let plungerSize = CGSize(width: 24, height: 50)
    static let plungerRestTop: CGFloat = 120
    static var laneCenterX: CGFloat { (QfForestLayout.laneWallX + QfForestLayout.laneOuterX) / 2 }
    static var plungerRestPosition: CGPoint { CGPoint(x: laneCenterX, y: plungerRestTop - plungerSize.height / 2) }
    static let plungerMaxPull: CGFloat = 60
    static let minLaunchSpeed: CGFloat = 1050
    static let maxLaunchSpeed: CGFloat = 2310
    static let plungePowerExponent: CGFloat = 1.4
    static let tapLaunchPower: CGFloat = 0.6
    static let plungerZoneMinX: CGFloat = 0.62
    static let plungerZoneMinY: CGFloat = 0.55

    // MARK: Scoops and rides
    /// The Old Well and the Hollow Log hold a caught ball this long before letting it go.
    static let scoopHold: TimeInterval = 1.0
    /// A scoop ignores the ball it just let go for this long.
    static let scoopRecapture: TimeInterval = 0.6
    /// The well's subway: the ball rides under the table to the left inlane at this speed (drawn at height 0).
    static let subwaySpeed: CGFloat = 900
    static let inlaneReleaseSpeed: CGFloat = 450

    // MARK: Ramp layer (CHOMP!'s values; T9 M1 v2, the Old Road)
    static let rampEntryDistance: CGFloat = 12
    static let rampMadeAfterApex: CGFloat = 10
    static let rampExitBeforeEnd: CGFloat = 15
    static let rampFriction: CGFloat = 0.05
    static let rampRestitution: CGFloat = 0.1
    static let rampRiseLength: CGFloat = 110
    static let rampEndHeight: CGFloat = 12
    /// The Old Road's centreline, built from QfForestLayout's builder steps (generated from tools/qf_layout.py).
    static var oldRoadPath: QfRampPath {
        var p = QfRampPath(start: QfForestLayout.rampStart, heading: QfForestLayout.rampStartHeading)
        for piece in QfForestLayout.rampPieces {
            if piece.radius == 0 { p.line(piece.value) } else { p.arc(radius: piece.radius, turn: piece.value) }
        }
        return p
    }
    /// The Forest Gate: a ball made up the Old Road while the exit is lit rides into it at this speed.
    static let gateRideSpeed: CGFloat = 500
    /// Monsters to defeat before the exit lights. Placeholder: 1 while the Treant is the only monster; ~3 once the
    /// wisps and ghosts fight back.
    static let exitAfterDefeats = 1

    // MARK: Game
    static let bannerSeconds: TimeInterval = 1.6
    /// The bark rises again this long after it all fell, if the Treant hasn't been felled.
    static let barkRegrow: TimeInterval = 20
    /// The left inlane's guide as InlaneGovernor wants it: [top, bend, end at the pivot]. The right side mirrors.
    static let governorGuide: [CGPoint] = [QfForestLayout.laneGuidePostLeft, QfForestLayout.guideBendLeft,
                                           QfForestLayout.laneGuideLeft.last!]
    static let mirrorSum: CGFloat = QfForestLayout.centerX * 2
}
