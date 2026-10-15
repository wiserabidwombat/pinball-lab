// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was TableLayout.swift.
import CoreGraphics
import Foundation

/// All table geometry in scene points. SpriteKit's origin is bottom-left.
/// The scene is a fixed 390 x 844 portrait canvas, scaled to fit any iPhone.
enum OrbitTableLayout {
    static let sceneSize = CGSize(width: 390, height: 844)

    // MARK: Physics tuning (milestone 7 revisits these)
    static let gravity: CGFloat = -6
    static let ballRadius: CGFloat = 10
    static let ballRestitution: CGFloat = 0.1   // SpriteKit uses the higher of two bodies' bounce
    static let maxBallSpeed: CGFloat = 1600

    // MARK: Walls
    static let leftWallX: CGFloat = 16
    static let rightWallX: CGFloat = 374
    static let laneWallX: CGFloat = 338       // inner wall of the plunger lane
    static let laneFloorY: CGFloat = 30
    static var laneCenterX: CGFloat { (laneWallX + rightWallX) / 2 }

    // MARK: Flippers
    static let leftFlipperPivot = CGPoint(x: 110, y: 180)
    static let rightFlipperPivot = CGPoint(x: 280, y: 180)
    static let flipperLength: CGFloat = 72
    static let flipperPivotRadius: CGFloat = 9
    static let flipperTipRadius: CGFloat = 5
    static let flipperRestAngle: CGFloat = .pi / 6   // 30° below horizontal
    static let flipperTravel: CGFloat = .pi / 3      // 60° swing
    static let flipperUpSpeed: CGFloat = 22          // radians per second
    static let flipperDownSpeed: CGFloat = 12
    static let flipperMass: CGFloat = 2
    static let flipperFriction: CGFloat = 0.4        // grip helps the ball settle when cradled

    /// Where each inlane guide ends: just above the top edge of the flipper's
    /// pivot at rest, so the ball rolls straight onto the flipper instead of
    /// wedging into the corner between the guide and the pivot.
    static var leftGuideEnd: CGPoint {
        let r = flipperPivotRadius + 1
        return CGPoint(x: leftFlipperPivot.x + r * sin(flipperRestAngle),
                       y: leftFlipperPivot.y + r * cos(flipperRestAngle))
    }
    static var rightGuideEnd: CGPoint {
        let r = flipperPivotRadius + 1
        return CGPoint(x: rightFlipperPivot.x - r * sin(flipperRestAngle),
                       y: rightFlipperPivot.y + r * cos(flipperRestAngle))
    }

    // MARK: Plunger
    static let plungerSize = CGSize(width: 26, height: 40)
    static let plungerRestTop: CGFloat = 90
    static var plungerRestPosition: CGPoint {
        CGPoint(x: laneCenterX, y: plungerRestTop - plungerSize.height / 2)
    }
    static let plungerMaxPull: CGFloat = 50
    static let minLaunchSpeed: CGFloat = 700
    static let maxLaunchSpeed: CGFloat = 1500
    static let tapLaunchPower: CGFloat = 0.6         // a quick tap = medium launch
    /// Touches here drive the plunger while a ball is waiting in the lane.
    static let plungerZone = CGRect(x: 290, y: 0, width: 100, height: 300)

    // MARK: Launch lane gate (one-way: closes once the ball has left the lane)
    static let laneWallTop: CGFloat = 620
    /// Slopes down to the left so a ball landing on it rolls into the playfield.
    static var gateLow: CGPoint { CGPoint(x: laneWallX, y: laneWallTop) }
    static var gateHigh: CGPoint { CGPoint(x: rightWallX, y: laneWallTop + 32) }

    // MARK: Planet bumpers
    static let bumperRadius: CGFloat = 24
    static let bumperCenters: [CGPoint] = [
        CGPoint(x: 135, y: 590),
        CGPoint(x: 235, y: 590),
        CGPoint(x: 185, y: 510),
    ]
    static let bumperKickSpeed: CGFloat = 750       // ball speed straight out of a bumper

    // MARK: Slingshots (triangles above each flipper)
    // top → corner → tip are the passive sides; tip → top is the kicking face.
    static let leftSling = (top: CGPoint(x: 60, y: 330),
                            corner: CGPoint(x: 60, y: 262),
                            tip: CGPoint(x: 102, y: 238))
    static let rightSling = (top: CGPoint(x: 308, y: 330),
                             corner: CGPoint(x: 308, y: 262),
                             tip: CGPoint(x: 268, y: 240))
    static let slingKickSpeed: CGFloat = 600

    // MARK: Top rollover lanes (3 lanes between 4 short posts)
    static let lanePostXs: [CGFloat] = [110, 160, 210, 260]
    static let lanePostBottom: CGFloat = 690
    static let lanePostTop: CGFloat = 745
    static let laneSensorY: CGFloat = 708
    static let laneLightY: CGFloat = 730
    static var laneCenterXs: [CGFloat] {
        zip(lanePostXs, lanePostXs.dropFirst()).map { ($0 + $1) / 2 }
    }

    // MARK: Asteroid drop targets (bank of 4 against the plunger lane wall)
    static let dropTargetSize = CGSize(width: 12, height: 26)
    static let dropTargetSpriteSize = CGSize(width: 30, height: 20)   // drawn rotated 90°
    static let dropTargetX: CGFloat = 326
    static let dropTargetYs: [CGFloat] = [500, 468, 436, 404]
    static let dropTargetResetDelay: TimeInterval = 1.0
    /// Deflector just above the bank, so a ball sliding down the right side is pushed
    /// left instead of brushing all four targets. It runs from the lane wall toward the
    /// targets and sits close enough to the bank that the ball can't wedge under it.
    /// (A matching guard below the bank was removed after playtesting.)
    static let dropTargetGuards: [[CGPoint]] = [
        [CGPoint(x: 338, y: 530), CGPoint(x: 312.5, y: 519.5)],   // above the top target (25% shorter after playtest)
    ]

    // MARK: OrbitWormhole (holds the ball, then ejects it)
    static let wormholeCenter = CGPoint(x: 58, y: 615)
    static let wormholeRadius: CGFloat = 16          // drawn size
    static let wormholeSensorRadius: CGFloat = 9     // the ball must get this close
    static let wormholeHold: TimeInterval = 1.0
    static let wormholeEject = CGVector(dx: 260, dy: -120)

    // MARK: Rules (milestone 4)
    static let ballSaveSeconds: TimeInterval = 10     // drain within this long after launch = ball returned once
    static let skillShotWindow: TimeInterval = 5      // skill shot must land within this long after launch
    static let bannerSeconds: TimeInterval = 1.5

    /// One continuous wall: left inlane guide → left wall → arched top →
    /// right wall → plunger lane floor → inner plunger lane wall.
    static var outerWall: [CGPoint] {
        var points: [CGPoint] = [
            leftGuideEnd,
            CGPoint(x: leftWallX, y: 260),
            CGPoint(x: leftWallX, y: 700),
        ]
        points += quadCurve(from: CGPoint(x: leftWallX, y: 700),
                            control: CGPoint(x: leftWallX, y: 820),
                            to: CGPoint(x: 195, y: 820))
        points += quadCurve(from: CGPoint(x: 195, y: 820),
                            control: CGPoint(x: rightWallX, y: 820),
                            to: CGPoint(x: rightWallX, y: 700))
        points += [
            CGPoint(x: rightWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: laneFloorY),
            CGPoint(x: laneWallX, y: laneWallTop),
        ]
        return points
    }

    /// Right inlane guide, from the plunger lane wall down to the right flipper.
    static var rightGuide: [CGPoint] {
        [CGPoint(x: laneWallX, y: 260), rightGuideEnd]
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
