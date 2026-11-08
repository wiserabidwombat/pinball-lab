// Pinball Lab Table 06 (Orbit: Grand Tour): a line switch, Table 04's MonRampSwitch with the Tour prefix (M3 v1:
// the orbits' arm/made switches and the spinners). A ball's move since last frame crossing the line, and which way.
import CoreGraphics

/// A line across a lane. `crossing` tells whether a ball's move this frame crossed it, forward (along `forward`) or back.
struct TourSwitch {
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
