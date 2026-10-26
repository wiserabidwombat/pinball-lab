import SpriteKit

/// Improve mode, the flip-spot coach (2026-10-26). While Improve is on (pause card), each resting flipper shows
/// coloured marks on its top face: where the ball should be when you flip to make a shot.
///
/// The marks come from the Shot Lab. Every trial records the ball's distance from the pivot at the flip
/// (`flipAlong`, ball centre to pivot) and what the flip made; a band is a solid run of trials (3 or more) that
/// made the same shot. Bands differ between 120 Hz and 60 Hz steps, so each flipper has a list for each.
/// The table says which shots are lit: lit bands draw bright with a label, the others faint. A flip with the
/// ball inside a band flashes it, so a player sees "that was the spot".
///
/// Shared by every table (one instance per table scene); the table owns the band numbers and the lit shots.
@MainActor
final class FlipCoach: SKNode {
    struct Band {
        let shot: String          // the table's shot name (its arrow lamp is "arrow.<shot>")
        let label: String
        let from: CGFloat         // ball centre to pivot at the flip, pt (Shot Lab flipAlong)
        let to: CGFloat
        let color: SKColor
    }

    struct Flipper {
        let pivot: CGPoint
        let pointsLeft: Bool      // false: the left flipper (arm to the right); true: right and upper flippers
        let restAngle: CGFloat    // radians below horizontal at rest
        let length: CGFloat
        let pivotRadius: CGFloat
        let tipRadius: CGFloat
        let bands120: [Band]
        let bands60: [Band]
    }

    private let flippers: [Flipper]
    private let ballRadius: CGFloat
    private var drawnLit: Set<String>?
    private var drawnSixty: Bool?
    /// One node per band currently drawn, per flipper, for the flash.
    private var bandNodes: [[(band: Band, node: SKShapeNode)]] = []

    init(flippers: [Flipper], ballRadius: CGFloat) {
        self.flippers = flippers
        self.ballRadius = ballRadius
        super.init()
        zPosition = 5                     // over the flippers (0), under the balls (10)
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Redraws only when the lit shots or the frame rate change.
    func update(lit: Set<String>, sixty: Bool) {
        guard lit != drawnLit || sixty != drawnSixty else { return }
        drawnLit = lit
        drawnSixty = sixty
        removeAllChildren()
        bandNodes = []
        for flipper in flippers {
            var nodes: [(band: Band, node: SKShapeNode)] = []
            for band in sixty ? flipper.bands60 : flipper.bands120 {
                let isLit = lit.contains(band.shot)
                let node = segment(band, on: flipper)
                node.alpha = isLit ? 1 : (lit.isEmpty ? 0.45 : 0.18)
                addChild(node)
                nodes.append((band, node))
                if isLit { addChild(label(band, on: flipper)) }
            }
            bandNodes.append(nodes)
        }
    }

    /// Call when a flipper goes up. Flashes the band the nearest ball on that flipper was in, if any.
    func flipped(flipper index: Int, balls: [CGPoint]) {
        guard index < flippers.count, index < bandNodes.count else { return }
        let f = flippers[index]
        let reach = f.length + f.tipRadius + ballRadius
        guard let d = balls.map({ hypot($0.x - f.pivot.x, $0.y - f.pivot.y) }).filter({ $0 <= reach }).min() else { return }
        for entry in bandNodes[index] where d >= entry.band.from && d <= entry.band.to {
            // A thicker copy over the band that fades out (no closures in the actions).
            guard let path = entry.node.path else { continue }
            let flash = SKShapeNode(path: path)
            flash.strokeColor = .white
            flash.lineWidth = 7
            flash.lineCap = .round
            flash.glowWidth = 4
            flash.alpha = 0
            addChild(flash)
            flash.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.04), .wait(forDuration: 0.2),
                                 .fadeOut(withDuration: 0.25), .removeFromParent()]))
        }
    }

    // MARK: Geometry (the flipper at rest)

    /// The arm's direction and the top face's normal at rest.
    private func axes(_ f: Flipper) -> (dir: CGVector, normal: CGVector) {
        let z = f.pointsLeft ? f.restAngle : -f.restAngle             // the flipper node's zRotation at rest
        let c = cos(z), s = sin(z)
        let dir = f.pointsLeft ? CGVector(dx: -c, dy: -s) : CGVector(dx: c, dy: s)
        return (dir, CGVector(dx: -s, dy: c))
    }

    /// The flipper's half-thickness at a distance along the arm (it tapers from the pivot to the tip).
    private func half(_ f: Flipper, along: CGFloat) -> CGFloat {
        let t = min(max(along / f.length, 0), 1)
        return f.pivotRadius + (f.tipRadius - f.pivotRadius) * t
    }

    /// Ball-centre distance from the pivot → distance along the arm (the ball sits on the face, above the axis).
    private func along(_ f: Flipper, distance d: CGFloat) -> CGFloat {
        var a = d
        for _ in 0..<4 {
            let h = half(f, along: a) + ballRadius
            a = sqrt(max(d * d - h * h, 0))
        }
        return min(a, f.length)
    }

    /// A point on the top face, `lift` points above the surface.
    private func facePoint(_ f: Flipper, along a: CGFloat, lift: CGFloat) -> CGPoint {
        let (dir, n) = axes(f)
        let up = half(f, along: a) + lift
        return CGPoint(x: f.pivot.x + dir.dx * a + n.dx * up, y: f.pivot.y + dir.dy * a + n.dy * up)
    }

    private func segment(_ band: Band, on f: Flipper) -> SKShapeNode {
        let a0 = along(f, distance: band.from), a1 = max(along(f, distance: band.to), a0 + 2)
        let path = CGMutablePath()
        path.move(to: facePoint(f, along: a0, lift: 2))
        path.addLine(to: facePoint(f, along: a1, lift: 2))
        let node = SKShapeNode(path: path)
        node.strokeColor = band.color
        node.lineWidth = 3.5
        node.lineCap = .round
        node.glowWidth = 1.5
        return node
    }

    private func label(_ band: Band, on f: Flipper) -> SKLabelNode {
        let mid = (along(f, distance: band.from) + along(f, distance: band.to)) / 2
        let text = SKLabelNode(text: band.label)
        text.fontName = "Menlo-Bold"
        text.fontSize = 8
        text.fontColor = band.color
        text.verticalAlignmentMode = .center
        text.horizontalAlignmentMode = .center
        text.position = facePoint(f, along: mid, lift: 11)
        let (dir, _) = axes(f)
        text.zRotation = f.pointsLeft ? atan2(-dir.dy, -dir.dx) : atan2(dir.dy, dir.dx)   // along the arm, upright
        return text
    }
}
