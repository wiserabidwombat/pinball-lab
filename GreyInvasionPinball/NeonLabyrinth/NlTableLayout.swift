// Pinball Lab Table 08 (Neon Labyrinth): the table's physics and part constants. The geometry of a cell (walls,
// lanes, slings, the Switchyard's parts) is in NlCellLayout.swift, generated from tools/nl_layout.py.
// T8 M1 v1: real ball scale and real physics, copied from CHOMP! (Table 07, fa86dbb): a 30 pt ball, 80 pt flippers,
// gravity −6.0, the Visual-Pinball-style flipper model with a 51° stroke.
import SpriteKit
import UIKit
import CoreGraphics

enum NlTableLayout {
    // MARK: World and ball
    /// One cell is the whole world for now (the maze grid comes in a later milestone).
    static let worldSize = NlCellLayout.cellSize
    static let gravity: CGFloat = NlCellLayout.gravity
    static let ballRadius: CGFloat = NlCellLayout.ballRadius
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.1
    static let maxBallSpeed: CGFloat = 3500
    static let wallRestitution: CGFloat = 0.3
    static let wallFriction: CGFloat = 0.1
    static let railRestitution: CGFloat = 0.15
    static let railFriction: CGFloat = 0.02
    static let postRestitution: CGFloat = 0.1

    // MARK: Art (grey box for now; the neon look comes later, drawn in code with pre-rendered glow sprites)
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
    static let flipperLength: CGFloat = NlCellLayout.flipperLength
    static let flipperPivotRadius: CGFloat = NlCellLayout.flipperPivotRadius
    static let flipperTipRadius: CGFloat = NlCellLayout.flipperTipRadius
    static let flipperRestAngle: CGFloat = NlCellLayout.flipperRestAngle
    static let flipperTravel: CGFloat = NlCellLayout.flipperTravel
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
    static let slingTopPostRadius: CGFloat = NlCellLayout.slingTopPostRadius
    static let slingTipPostRadius: CGFloat = NlCellLayout.slingTipPostRadius
    static let slingCornerPostRadius: CGFloat = NlCellLayout.slingCornerPostRadius
    static let slingPostRestitution: CGFloat = 0.1

    // MARK: Rides (T8 M1 v1)
    /// The rise from below: the ball comes up the drain chute at this speed (collisions off), then the pop.
    static let riseSpeed: CGFloat = 900
    /// A return wire is ridden at this speed (from the top lane or a side entry), drawn at the wire's height.
    static let wireRideSpeed: CGFloat = 650
    static let wireHeight: CGFloat = 40

    // MARK: Outlane saves (T8 M1 v4)
    /// A ball crossing this height going down in an outlane (x < outlaneMaxX, or mirrored) is kicked back if that
    /// side's save is lit. The knee over the outlane blocks a straight-up kick (nl_layout's knee, 44 pt deep at y 540),
    /// so the kick goes out through the outlane's mouth and ACROSS the lower table to the far flipper: from the outlane's
    /// centre at y 400, 46° above horizontal, 1,000 pt/s (pymunk, ±3° / ±8% / ±3 pt jitter: 98/100 reach a flipper,
    /// 93 the far one first).
    static let outlaneTriggerY: CGFloat = 420
    static let outlaneMaxX: CGFloat = 72
    static let kickFromLeft = CGPoint(x: 45, y: 400)
    static let kickAngle: CGFloat = 46 * .pi / 180
    static let kickSpeed: CGFloat = 1000
    /// The lamps in each outlane.
    static let kickLampLeft = CGPoint(x: 45, y: 330)

    // MARK: Game
    static let ballsPerGame = 3
    static let bannerSeconds: TimeInterval = 1.6
    /// The left inlane's guide as InlaneGovernor wants it: [top, bend, end at the pivot] (the bend's theoretical
    /// corner; the drawn and physical bend is NlCellLayout's r 120 curve). The right side mirrors about x 300.
    static let governorGuide: [CGPoint] = [NlCellLayout.laneGuidePostLeft, NlCellLayout.guideBendLeft,
                                           NlCellLayout.laneGuideLeft.last!]
    static let mirrorSum: CGFloat = NlCellLayout.centerX * 2
}
