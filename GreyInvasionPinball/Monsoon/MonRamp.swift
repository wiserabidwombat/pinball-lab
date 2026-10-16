// Pinball Lab Table 04 (Monsoon): copied from Table 03 (Cthulhu Rising) with the "Mon" prefix.
import SpriteKit
import CoreGraphics
import Foundation

/// A ramp centerline built from straight runs and arcs, sampled into points.
/// Each point keeps its heading (radians) and its distance along the path.
struct MonRampPath {
    private(set) var points: [CGPoint]
    private(set) var headings: [CGFloat]
    private(set) var distances: [CGFloat]
    private var heading: CGFloat

    init(start: CGPoint, heading: CGFloat) {
        points = [start]
        headings = [heading]
        distances = [0]
        self.heading = heading
    }

    var length: CGFloat { distances.last ?? 0 }

    /// A straight run in the current heading.
    mutating func line(_ length: CGFloat, step: CGFloat = 10) {
        let n = max(1, Int((length / step).rounded(.up)))
        let start = points[points.count - 1]
        let s0 = self.length
        for i in 1...n {
            let d = length * CGFloat(i) / CGFloat(n)
            points.append(CGPoint(x: start.x + d * cos(heading), y: start.y + d * sin(heading)))
            headings.append(heading)
            distances.append(s0 + d)
        }
    }

    /// An arc. `turn` > 0 bends left (counterclockwise), < 0 bends right.
    mutating func arc(radius: CGFloat, turn: CGFloat, step: CGFloat = 8) {
        let n = max(2, Int((abs(turn) * radius / step).rounded(.up)))
        let sign: CGFloat = turn > 0 ? 1 : -1
        let start = points[points.count - 1]
        let center = CGPoint(x: start.x - sign * radius * sin(heading),
                             y: start.y + sign * radius * cos(heading))
        let a0 = atan2(start.y - center.y, start.x - center.x)
        let s0 = self.length
        let h0 = heading
        for i in 1...n {
            let f = CGFloat(i) / CGFloat(n)
            let a = a0 + turn * f
            points.append(CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a)))
            headings.append(h0 + turn * f)
            distances.append(s0 + abs(turn) * radius * f)
        }
        heading = h0 + turn
    }

    /// The point and heading at distance `s` along the path.
    func sample(at s: CGFloat) -> (point: CGPoint, heading: CGFloat) {
        for i in 1..<points.count where distances[i] >= s {
            let t = (s - distances[i - 1]) / max(distances[i] - distances[i - 1], 0.001)
            let a = points[i - 1], b = points[i]
            return (CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), headings[i])
        }
        return (points[points.count - 1], headings[headings.count - 1])
    }
}

/// A line across the ramp channel. Each frame the scene asks whether the ball's
/// movement crossed it, and in which direction along the ramp.
struct MonRampSwitch {
    enum Crossing { case none, forward, backward }

    let a: CGPoint
    let b: CGPoint
    let forward: CGVector   // unit vector pointing along the ramp, away from the mouth

    func crossing(from p0: CGPoint, to p1: CGPoint) -> Crossing {
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let side0 = ab.dx * (p0.y - a.y) - ab.dy * (p0.x - a.x)
        let side1 = ab.dx * (p1.y - a.y) - ab.dy * (p1.x - a.x)
        guard (side0 > 0) != (side1 > 0) else { return .none }

        // Where the movement met the line; it must land on the switch, not its extension.
        let t = side0 / (side0 - side1)
        let q = CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
        let u = ((q.x - a.x) * ab.dx + (q.y - a.y) * ab.dy) / max(ab.dx * ab.dx + ab.dy * ab.dy, 0.001)
        guard u >= -0.25, u <= 1.25 else { return .none }

        let along = (p1.x - p0.x) * forward.dx + (p1.y - p0.y) * forward.dy
        return along >= 0 ? .forward : .backward
    }
}

/// A ramp on its own physics layer. Its rails only collide with a ball on the ramp layer,
/// so a ball on the floor rolls underneath it. Short posts at the mouth are floor walls,
/// so a ball that misses the entrance bounces off its edges.
/// The part up to the apex is drawn as plastic; the return after it as a wire.
final class MonRamp: SKNode {
    let path: MonRampPath
    let entrySwitch: MonRampSwitch     // floor ↔ ramp at the mouth
    let madeSwitch: MonRampSwitch      // just past the apex: the shot is made
    let exitSwitch: MonRampSwitch      // end of the wire: back to the floor
    private let mouthHalfWidth: CGFloat
    private let halfWidth: CGFloat
    private let flareLength: CGFloat
    /// Table 03 milestone 4: false for a wire the ball is put on by a toy (the Library's up-kicker): a floor
    /// ball rolling across its start must not climb onto it.
    let acceptsFloorEntry: Bool
    private let apexDistance: CGFloat
    private let endHeight: CGFloat
    /// Table 04 milestone 4: each wire level's own height profile, collision categories and drawing depth.
    let topHeight: CGFloat
    private let riseLength: CGFloat
    /// Where the rise starts from (0 for a ramp off the floor; the helix starts up on the high wire).
    private let startHeight: CGFloat
    /// M4 round 2: a ramp ridden on rails (the helix): drawn, but with no physics walls; the scene moves the ball.
    let ridden: Bool
    /// The rails' category and the category a ball riding this ramp takes (MonBall reads both).
    let wallCategory: UInt32
    let ballCategory: UInt32
    /// Added to the art's z (20…21): a higher wire draws over a lower one.
    private let zShift: CGFloat
    /// Where a ball on this ramp draws: over this ramp's art.
    var ballZ: CGFloat { 30 + zShift }

    /// `wireOnly`: no plastic part (drawn as a brass wire from start to end), no floor entry.
    /// `artBaked` (art round 3): the ramp is in the rendered mon_ramps sprite, so only the physics is built here.
    init(path: MonRampPath, apexDistance: CGFloat,
         mouthHalfWidth: CGFloat, halfWidth: CGFloat, flareLength: CGFloat, postLength: CGFloat,
         wireOnly: Bool = false, lowLength: CGFloat = 0,
         endHeight: CGFloat = MonTableLayout.rampEndHeight, artBaked: Bool = false,
         topHeight: CGFloat = MonTableLayout.rampTopHeight, riseLength: CGFloat = MonTableLayout.rampRiseLength,
         wallCategory: UInt32 = MonPhysicsCategory.rampWall, ballCategory: UInt32 = MonPhysicsCategory.rampBall,
         zShift: CGFloat = 0, startHeight: CGFloat = 0, ridden: Bool = false) {
        self.startHeight = startHeight
        self.ridden = ridden
        acceptsFloorEntry = !wireOnly
        self.topHeight = topHeight
        self.riseLength = riseLength
        self.wallCategory = wallCategory
        self.ballCategory = ballCategory
        self.zShift = zShift
        self.path = path
        self.apexDistance = apexDistance
        self.endHeight = endHeight
        self.mouthHalfWidth = mouthHalfWidth
        self.halfWidth = halfWidth
        self.flareLength = flareLength

        func width(_ s: CGFloat) -> CGFloat {
            mouthHalfWidth + (halfWidth - mouthHalfWidth) * min(s / flareLength, 1)
        }
        func across(_ s: CGFloat) -> MonRampSwitch {
            let (p, h) = path.sample(at: s)
            let w = width(s) + 2
            let n = CGVector(dx: -sin(h), dy: cos(h))
            return MonRampSwitch(a: CGPoint(x: p.x + w * n.dx, y: p.y + w * n.dy),
                              b: CGPoint(x: p.x - w * n.dx, y: p.y - w * n.dy),
                              forward: CGVector(dx: cos(h), dy: sin(h)))
        }
        entrySwitch = across(MonTableLayout.rampEntryDistance)
        madeSwitch = across(apexDistance + MonTableLayout.rampMadeAfterApex)
        exitSwitch = across(path.length - MonTableLayout.rampExitBeforeEnd)
        super.init()

        // Rails: the centerline offset to each side.
        var leftRail: [CGPoint] = []
        var rightRail: [CGPoint] = []
        for (i, p) in path.points.enumerated() {
            let h = path.headings[i]
            let w = width(path.distances[i])
            leftRail.append(CGPoint(x: p.x - w * sin(h), y: p.y + w * cos(h)))
            rightRail.append(CGPoint(x: p.x + w * sin(h), y: p.y - w * cos(h)))
        }
        // T4 M4 v2 (Aaron: round the mesa ramp's curve the ball rode above the rail): the drawn ramp is lifted by its
        // height × the oblique, like the ball and the rendered art, so the ball sits on its rails. Physics stays flat.
        let lean = MonTableLayout.oblique
        let leftDrawn = leftRail.indices.map { i -> CGPoint in
            CGPoint(x: leftRail[i].x, y: leftRail[i].y + heightAlong(path.distances[i]) * lean)
        }
        let rightDrawn = rightRail.indices.map { i -> CGPoint in
            CGPoint(x: rightRail[i].x, y: rightRail[i].y + heightAlong(path.distances[i]) * lean)
        }
        if ridden {
            drawRidden(left: leftDrawn, right: rightDrawn, leftFloor: leftRail, rightFloor: rightRail)
            return
        }
        let plastic = wireOnly ? [] : path.distances.indices.filter { path.distances[$0] <= apexDistance }
        let wire = wireOnly ? Array(path.distances.indices) : path.distances.indices.filter { path.distances[$0] >= apexDistance }
        let posts = path.distances.indices.filter { path.distances[$0] <= postLength }

        // M11 v2 (Aaron: "the right ramp is still just two lines and doesn't feel like a ramp"): a real plastic ramp —
        // a steel entrance flap, a tinted plastic floor with ribs, clear side walls with rolled, ink-edged tops, chrome
        // support brackets and its shadow on the playfield.
        if plastic.count > 1, !artBaked {
            drawPlastic(plastic, leftFloor: leftRail, rightFloor: rightRail, leftDrawn: leftDrawn, rightDrawn: rightDrawn)
        }
        let plasticEdge = SKColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 0.85)
        let plasticShine = SKColor(white: 1, alpha: 0.5)
        // The up-kicker's wire is old brass (the plan); ramp wires are silver.
        let wireDark = wireOnly ? SKColor(red: 0.55, green: 0.38, blue: 0.14, alpha: 1)
                                : SKColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
        let wireLight = wireOnly ? SKColor(red: 0.95, green: 0.78, blue: 0.42, alpha: 1)
                                 : SKColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1)
        let chromeDark = SKColor(red: 0.23, green: 0.25, blue: 0.32, alpha: 1)
        let chrome = SKColor(red: 0.79, green: 0.81, blue: 0.85, alpha: 1)
        for (rail, drawn) in [(leftRail, leftDrawn), (rightRail, rightDrawn)] {
            addBody(rail, category: wallCategory)                           // this ramp's own layer
            if lowLength <= 0 {
                addBody(posts.map { rail[$0] }, category: MonPhysicsCategory.wall)  // floor: entrance posts
            }
            if artBaked { continue }
            if plastic.count <= 1 {
                addLine(plastic.map { drawn[$0] }, color: plasticEdge, width: 2.4)
                addLine(plastic.map { drawn[$0] }, color: plasticShine, width: 0.8, z: 21.1)
            }
            addLine(wire.map { drawn[$0] }, color: wireDark, width: 2.6)
            addLine(wire.map { drawn[$0] }, color: wireLight, width: 1.4, z: 21.1)
            let post = posts.map { rail[$0] }
            addLine(post, color: chromeDark, width: 6.5, z: 1)
            addLine(post, color: chrome, width: 4, z: 1.1)
            addLine(post, color: SKColor(white: 1, alpha: 0.7), width: 1.4, z: 1.2)
        }

        if !artBaked { drawHabitrail(wire, leftFloor: leftRail, rightFloor: rightRail, brass: wireOnly) }

        // T3 M8 v7 (Aaron: a ball could fall back down through the ramp; on a real table the ramp's low end sits on
        // the playfield, so a ball from behind hits it and goes left or right): for the first `lowLength` points the
        // ramp is solid for FLOOR balls, a U of floor wall up both sides and across the back, open only at the
        // mouth. A ball entering the mouth switches to the ramp layer 12 pt in, so it never meets these walls.
        if lowLength > 0 {
            let low = path.distances.indices.filter { path.distances[$0] < lowLength }
            let (bp, bh) = path.sample(at: lowLength)
            let bw = width(lowLength)
            let backLeft = CGPoint(x: bp.x - bw * sin(bh), y: bp.y + bw * cos(bh))
            let backRight = CGPoint(x: bp.x + bw * sin(bh), y: bp.y - bw * cos(bh))
            let u = low.map { leftRail[$0] } + [backLeft, backRight] + low.reversed().map { rightRail[$0] }
            addBody(u, category: MonPhysicsCategory.wall)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// How far a point is from the centerline (used to catch a ball that somehow left the channel).
    func distanceToCenterline(_ q: CGPoint) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        let pts = path.points
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let dx = b.x - a.x, dy = b.y - a.y
            let t = max(0, min(1, ((q.x - a.x) * dx + (q.y - a.y) * dy) / max(dx * dx + dy * dy, 0.001)))
            best = min(best, hypot(q.x - a.x - t * dx, q.y - a.y - t * dy))
        }
        return best
    }

    /// Art round 3: how high the running surface is under a point (the nearest spot on the centerline), so the
    /// ball can be drawn riding on the rendered ramp. Same profile as tools/mon_layout.py ramp_height.
    func height(at q: CGPoint) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        var bestS: CGFloat = 0
        let pts = path.points
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let dx = b.x - a.x, dy = b.y - a.y
            let t = max(0, min(1, ((q.x - a.x) * dx + (q.y - a.y) * dy) / max(dx * dx + dy * dy, 0.001)))
            let d = hypot(q.x - a.x - t * dx, q.y - a.y - t * dy)
            if d < best {
                best = d
                bestS = path.distances[i - 1] + t * (path.distances[i] - path.distances[i - 1])
            }
        }
        return heightAlong(bestS)
    }

    /// The running surface's height `s` points along the centerline: up over `riseLength` (a quarter sine) to
    /// `topHeight`, held to the apex, then down in a straight line to `endHeight` at the end.
    func heightAlong(_ s: CGFloat) -> CGFloat {
        let top = topHeight
        if s <= apexDistance {
            return startHeight + (top - startHeight) * sin(min(max(s, 0) / riseLength, 1) * .pi / 2)
        }
        let f = min((s - apexDistance) / max(path.length - apexDistance, 1), 1)
        return top + (endHeight - top) * f
    }

    /// The widest the channel gets (at the mouth), for the escape check.
    var maxHalfWidth: CGFloat { max(mouthHalfWidth, halfWidth) }

    /// The ramp's name printed along its plastic (M8), in Orbitron when it's bundled.
    func addLabel(_ text: String, at point: CGPoint, angle: CGFloat) {
        let label = SKLabelNode(text: text)
        label.fontName = "Orbitron-Bold"
        label.fontSize = 6.5
        label.fontColor = SKColor(red: 0.85, green: 1.0, blue: 0.89, alpha: 0.95)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.zRotation = angle
        label.zPosition = 21.2 + zShift
        addChild(label)
    }

    private func addLine(_ points: [CGPoint], color: SKColor, width: CGFloat, z: CGFloat = 21) {
        guard points.count > 1 else { return }
        let p = CGMutablePath()
        p.addLines(between: points)
        let node = SKShapeNode(path: p)
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z >= 20 ? z + zShift : z           // the mouth posts stay on the floor
        addChild(node)
    }

    /// Where a ball riding this ramp draws at distance `s`: just over the rails at its height, under any turn of the
    /// helix that's higher (it passes under them) and over any that's lower.
    func rideZ(at s: CGFloat) -> CGFloat {
        41 + heightAlong(s) / 20 + 0.3
    }

    /// The ridden (helix) rails: drawn in short pieces, each at a depth set by its height, so a higher turn of the
    /// corkscrew draws over a lower one. M9 v6: a four-wire chrome habitrail (two running rails, two upper side rails,
    /// a hoop every 12 points) with its shadow on the floor.
    private func drawRidden(left: [CGPoint], right: [CGPoint], leftFloor: [CGPoint], rightFloor: [CGPoint]) {
        let n = path.points.count
        drawShadow(Array(0..<n), leftFloor: leftFloor, rightFloor: rightFloor)
        var i = 0
        while i < n - 1 {
            let j = min(i + 10, n - 1)
            let mid = (path.distances[i] + path.distances[j]) / 2
            drawTube(Array(i...j), leftFloor: leftFloor, rightFloor: rightFloor, brass: false, z: 41 + heightAlong(mid) / 20)
            i = j
        }
    }

    // MARK: Habitrail drawing (M9 v6)

    /// Running rails' colours: chrome, or old brass for the up-kicker's low wire.
    private static func wireColors(brass: Bool) -> (dark: SKColor, light: SKColor) {
        brass ? (SKColor(red: 0.50, green: 0.34, blue: 0.12, alpha: 1), SKColor(red: 0.98, green: 0.82, blue: 0.48, alpha: 1))
              : (SKColor(red: 0.28, green: 0.30, blue: 0.36, alpha: 1), SKColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1))
    }

    /// Where a floor point draws at height `h` (lifted by the oblique), pushed `out` points sideways from the centerline.
    private func lifted(_ floor: CGPoint, _ i: Int, h: CGFloat, out: CGFloat, side: CGFloat) -> CGPoint {
        let hd = path.headings[i]
        return CGPoint(x: floor.x - side * out * sin(hd), y: floor.y + side * out * cos(hd) + h * MonTableLayout.oblique)
    }

    /// The wire part of a ramp: its upper side rails, hoops, chrome support posts and floor shadow (the running rails
    /// themselves are drawn by init).
    private func drawHabitrail(_ idx: [Int], leftFloor: [CGPoint], rightFloor: [CGPoint], brass: Bool) {
        guard idx.count > 1 else { return }
        drawShadow(idx, leftFloor: leftFloor, rightFloor: rightFloor)
        drawTube(idx, leftFloor: leftFloor, rightFloor: rightFloor, brass: brass, z: 21, runningRails: false)
        // support posts every ~110 pt where the wire is up off the floor: a chrome rod from a little foot on the floor
        let posts = CGMutablePath(), feet = CGMutablePath()
        var next: CGFloat = path.distances[idx[0]] + 40
        for i in idx where path.distances[i] >= next {
            next = path.distances[i] + 110
            let h = heightAlong(path.distances[i])
            guard h > 10 else { continue }
            let c = path.points[i]
            posts.move(to: c)
            posts.addLine(to: CGPoint(x: c.x, y: c.y + (h - 3) * MonTableLayout.oblique))
            feet.addEllipse(in: CGRect(x: c.x - 3.5, y: c.y - 2.5, width: 7, height: 5))
        }
        addPath(feet, fill: SKColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1), stroke: .clear, width: 0, z: -17.9)
        addPath(posts, fill: .clear, stroke: SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.6), width: 4.0, z: 19.85)
        addPath(posts, fill: .clear, stroke: SKColor(red: 0.35, green: 0.37, blue: 0.43, alpha: 1), width: 2.6, z: 19.9)
        addPath(posts, fill: .clear, stroke: SKColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1), width: 1.0, z: 19.95)
    }

    /// A tube of wires along `idx`: (optionally) the two running rails, two upper side rails 11 pt above and 2 pt
    /// outside them, and a hoop (running rail → side rail on both sides, plus a tie underneath) every 12 points.
    private func drawTube(_ idx: [Int], leftFloor: [CGPoint], rightFloor: [CGPoint], brass: Bool, z: CGFloat,
                          runningRails: Bool = true) {
        let (dark, light) = Self.wireColors(brass: brass)
        var lowL: [CGPoint] = [], lowR: [CGPoint] = [], topL: [CGPoint] = [], topR: [CGPoint] = []
        for i in idx {
            let h = heightAlong(path.distances[i])
            lowL.append(lifted(leftFloor[i], i, h: h, out: 0, side: 1))
            lowR.append(lifted(rightFloor[i], i, h: h, out: 0, side: -1))
            topL.append(lifted(leftFloor[i], i, h: h + 11, out: 2, side: 1))
            topR.append(lifted(rightFloor[i], i, h: h + 11, out: 2, side: -1))
        }
        let hoops = CGMutablePath()
        var next = path.distances[idx[0]]
        for (k, i) in idx.enumerated() where path.distances[i] >= next {
            next = path.distances[i] + 12
            hoops.move(to: topL[k]); hoops.addLine(to: lowL[k]); hoops.addLine(to: lowR[k]); hoops.addLine(to: topR[k])
        }
        let zz = z >= 40 ? z : z + zShift
        // M9 v6b (Aaron: check "the contrast and color on the metal lanes"): every wire gets a dark ink outline under
        // it, so the chrome reads on the pale sky and on the pencil sketch alike; brighter highlights, firmer hoops.
        let ink = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.6)
        let outline = CGMutablePath()
        for rail in [lowL, lowR, topL, topR] where rail.count > 1 { outline.addLines(between: rail) }
        addPath(outline, fill: .clear, stroke: ink, width: 4.2, z: zz - 0.03)
        addPath(hoops, fill: .clear, stroke: ink, width: 2.2, z: zz - 0.03)
        addPath(hoops, fill: .clear, stroke: dark, width: 1.1, z: zz - 0.02)
        let rails = runningRails ? [lowL, lowR, topL, topR] : [topL, topR]
        for (r, rail) in rails.enumerated() {
            let upper = !runningRails || r >= 2
            addRawLine(rail, color: dark, width: upper ? 2.2 : 2.6, z: zz)
            addRawLine(rail, color: light, width: upper ? 1.0 : 1.4, z: zz + 0.01)
        }
    }

    /// The plastic part of a ramp (M11 v2), drawn lifted by its height like the ball. Layers, bottom to top: its
    /// shadow on the playfield, the steel entrance flap on the floor at the mouth, the chrome support brackets, the
    /// tinted floor with ribs, then both side walls (clear plastic 14 pt tall) with a rolled top edge over an ink line
    /// so they read on the light paper. Physics is unchanged.
    private func drawPlastic(_ idx: [Int], leftFloor: [CGPoint], rightFloor: [CGPoint],
                             leftDrawn: [CGPoint], rightDrawn: [CGPoint]) {
        let wall: CGFloat = 14
        let lean = MonTableLayout.oblique
        let z = 20 + zShift
        // shadow: the floor outline pushed down-right by height, plus the walls' height
        let shadow = CGMutablePath()
        let shadowPts = idx.map { i -> CGPoint in
            let h = heightAlong(path.distances[i]) + wall * 0.5
            return CGPoint(x: leftFloor[i].x + h * 0.30, y: leftFloor[i].y - h * 0.22)
        } + idx.reversed().map { i -> CGPoint in
            let h = heightAlong(path.distances[i]) + wall * 0.5
            return CGPoint(x: rightFloor[i].x + h * 0.30, y: rightFloor[i].y - h * 0.22)
        }
        shadow.addLines(between: shadowPts)
        shadow.closeSubpath()
        addPath(shadow, fill: SKColor(white: 0, alpha: 0.20), stroke: .clear, width: 0, z: -17.95)

        // entrance flap: a steel plate on the playfield in front of the mouth, with two rivets
        let i0 = idx[0], h0 = path.headings[i0]
        let back = CGVector(dx: -cos(h0) * 13, dy: -sin(h0) * 13)
        let side = CGVector(dx: -sin(h0) * 3, dy: cos(h0) * 3)
        let flap = CGMutablePath()
        flap.addLines(between: [leftFloor[i0], rightFloor[i0],
                                CGPoint(x: rightFloor[i0].x + back.dx - side.dx, y: rightFloor[i0].y + back.dy - side.dy),
                                CGPoint(x: leftFloor[i0].x + back.dx + side.dx, y: leftFloor[i0].y + back.dy + side.dy)])
        flap.closeSubpath()
        addPath(flap, fill: SKColor(red: 0.66, green: 0.68, blue: 0.74, alpha: 1),
                stroke: SKColor(red: 0.08, green: 0.07, blue: 0.12, alpha: 0.75), width: 1.4, z: -17.8)
        let lip = CGMutablePath()
        lip.move(to: leftFloor[i0]); lip.addLine(to: rightFloor[i0])
        addPath(lip, fill: .clear, stroke: SKColor(white: 1, alpha: 0.8), width: 1.2, z: -17.79)
        let rivets = CGMutablePath()
        for f in [CGFloat(0.25), 0.75] {
            let c = CGPoint(x: leftFloor[i0].x + (rightFloor[i0].x - leftFloor[i0].x) * f + back.dx * 0.55,
                            y: leftFloor[i0].y + (rightFloor[i0].y - leftFloor[i0].y) * f + back.dy * 0.55)
            rivets.addEllipse(in: CGRect(x: c.x - 1.4, y: c.y - 1.4, width: 2.8, height: 2.8))
        }
        addPath(rivets, fill: SKColor(red: 0.30, green: 0.31, blue: 0.36, alpha: 1), stroke: .clear, width: 0, z: -17.78)

        // chrome support brackets where the plastic is well off the floor
        let brackets = CGMutablePath()
        let lastS = path.distances[idx[idx.count - 1]]
        for target in [CGFloat(150), lastS - 40] {
            guard let i = idx.min(by: { abs(path.distances[$0] - target) < abs(path.distances[$1] - target) }) else { continue }
            let h = heightAlong(path.distances[i])
            guard h > 14 else { continue }
            for floor in [leftFloor[i], rightFloor[i]] {
                brackets.move(to: floor)
                brackets.addLine(to: CGPoint(x: floor.x, y: floor.y + (h - 1) * lean))
            }
        }
        addPath(brackets, fill: .clear, stroke: SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.6), width: 4.2, z: z - 0.3)
        addPath(brackets, fill: .clear, stroke: SKColor(red: 0.80, green: 0.82, blue: 0.87, alpha: 1), width: 2.4, z: z - 0.29)

        // the floor: tinted clear amber, darker toward the edges, with ribs across it
        let floor = CGMutablePath()
        floor.addLines(between: idx.map { leftDrawn[$0] } + idx.reversed().map { rightDrawn[$0] })
        floor.closeSubpath()
        addPath(floor, fill: SKColor(red: 0.93, green: 0.70, blue: 0.40, alpha: 0.42), stroke: .clear, width: 0, z: z)
        let inner = CGMutablePath()
        let mid = { (i: Int, f: CGFloat) -> CGPoint in
            CGPoint(x: leftDrawn[i].x + (rightDrawn[i].x - leftDrawn[i].x) * f,
                    y: leftDrawn[i].y + (rightDrawn[i].y - leftDrawn[i].y) * f)
        }
        inner.addLines(between: idx.map { mid($0, 0.3) } + idx.reversed().map { mid($0, 0.7) })
        inner.closeSubpath()
        addPath(inner, fill: SKColor(red: 1.0, green: 0.90, blue: 0.70, alpha: 0.22), stroke: .clear, width: 0, z: z + 0.01)
        let ribs = CGMutablePath()
        var nextRib = path.distances[i0] + 8
        for i in idx where path.distances[i] >= nextRib {
            nextRib = path.distances[i] + 16
            ribs.move(to: leftDrawn[i]); ribs.addLine(to: rightDrawn[i])
        }
        addPath(ribs, fill: .clear, stroke: SKColor(red: 0.62, green: 0.40, blue: 0.20, alpha: 0.35), width: 1.2, z: z + 0.02)

        // the side walls: a clear panel up to the rolled top edge
        for (floorPts, drawnPts, sideSign) in [(leftFloor, leftDrawn, CGFloat(1)), (rightFloor, rightDrawn, CGFloat(-1))] {
            let top = idx.map { i in lifted(floorPts[i], i, h: heightAlong(path.distances[i]) + wall, out: 1.2, side: sideSign) }
            let panel = CGMutablePath()
            panel.addLines(between: idx.map { drawnPts[$0] } + top.reversed())
            panel.closeSubpath()
            addPath(panel, fill: SKColor(red: 0.98, green: 0.88, blue: 0.70, alpha: 0.30), stroke: .clear, width: 0, z: z + 0.05)
            let topLine = CGMutablePath(); topLine.addLines(between: top)
            let baseLine = CGMutablePath(); baseLine.addLines(between: idx.map { drawnPts[$0] })
            addPath(baseLine, fill: .clear, stroke: SKColor(red: 0.55, green: 0.34, blue: 0.16, alpha: 0.55), width: 1.4, z: z + 0.06)
            addPath(topLine, fill: .clear, stroke: SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.55), width: 4.4, z: z + 0.07)
            addPath(topLine, fill: .clear, stroke: SKColor(red: 1.0, green: 0.84, blue: 0.56, alpha: 1), width: 2.6, z: z + 0.08)
            addPath(topLine, fill: .clear, stroke: SKColor(white: 1, alpha: 0.85), width: 0.9, z: z + 0.09)
        }
    }

    /// The wires' shadow on the floor: the light comes from the top left, so it falls down and right, farther the
    /// higher the wire. Drawn just over the table art, under everything else.
    private func drawShadow(_ idx: [Int], leftFloor: [CGPoint], rightFloor: [CGPoint]) {
        let shadow = CGMutablePath()
        for floor in [leftFloor, rightFloor] {
            var first = true
            for i in idx {
                let h = heightAlong(path.distances[i])
                let q = CGPoint(x: floor[i].x + h * 0.30, y: floor[i].y - h * 0.22)
                if first { shadow.move(to: q); first = false } else { shadow.addLine(to: q) }
            }
        }
        addPath(shadow, fill: .clear, stroke: SKColor(white: 0, alpha: 0.28), width: 4, z: -17.95)
    }

    private func addPath(_ p: CGPath, fill: SKColor, stroke: SKColor, width: CGFloat, z: CGFloat) {
        let node = SKShapeNode(path: p)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        addChild(node)
    }

    private func addRawLine(_ points: [CGPoint], color: SKColor, width: CGFloat, z: CGFloat) {
        guard points.count > 1 else { return }
        let p = CGMutablePath()
        p.addLines(between: points)
        let node = SKShapeNode(path: p)
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        node.zPosition = z
        addChild(node)
    }

    private func addBody(_ points: [CGPoint], category: UInt32) {
        guard points.count > 1 else { return }
        let p = CGMutablePath()
        p.addLines(between: points)
        let body = SKPhysicsBody(edgeChainFrom: p)
        body.friction = MonTableLayout.rampFriction
        body.restitution = MonTableLayout.rampRestitution
        body.categoryBitMask = category
        // Floor walls (the mouth posts, the low end) only ever meet floor balls; rails meet ramp balls too.
        body.collisionBitMask = category == MonPhysicsCategory.wall ? MonPhysicsCategory.ball
                                                                    : MonPhysicsCategory.ball | ballCategory
        let holder = SKNode()
        holder.physicsBody = body
        addChild(holder)
    }
}
