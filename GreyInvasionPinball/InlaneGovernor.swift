// 2026-11-02: an inlane speed limit, shared by the four campaign tables (their lower tables share the geometry).
// A wire return leaves its ramp capped at 700 pt/s, then drops ~230 pt down the inlane and reaches the flipper at
// ~1,050 pt/s. The Play Lab measured that a held-up flipper traps an inlane feed under ~900 pt/s (117 caught / 8
// launched / 18 dropped) but not above it (7 / 41 / 29; the holdfast Shot Lab at 1,000 pt/s: raised early, ~190/190
// drained). So a ball rolling DOWN an inlane is held to maxSpeed until just before the flipper's crook; it reaches the
// flipper at ~820 pt/s, trappable. Balls going up the inlane (flipped, kicked) and balls on the flipper aren't touched.
// Aaron chose this over deadening the held flipper or slowing the wire returns.
import CoreGraphics

enum InlaneGovernor {
    static let maxSpeed: CGFloat = 800
    /// How far the inlane channel reaches out from its guide (the inlane is ~34 wide; a little over for the ball).
    private static let width: CGFloat = 40
    /// Stop this far short of the guide's end, so a ball on the flipper is left alone.
    private static let stopShort: CGFloat = 22

    /// The ball's velocity held to maxSpeed if it's rolling down either inlane faster than that, else nil.
    /// `leftGuide` is the left lane guide: [top, bend, end at the flipper pivot]; the right side mirrors it.
    static func limited(_ v: CGVector, at p: CGPoint, leftGuide g: [CGPoint], mirrorSum: CGFloat) -> CGVector? {
        guard v.dy < 0, g.count >= 3 else { return nil }
        let speed = (v.dx * v.dx + v.dy * v.dy).squareRoot()
        guard speed > maxSpeed else { return nil }
        let q = p.x < mirrorSum / 2 ? p : CGPoint(x: mirrorSum - p.x, y: p.y)   // the right inlane, seen as the left
        guard inInlane(q, g) else { return nil }
        let k = maxSpeed / speed
        return CGVector(dx: v.dx * k, dy: v.dy * k)
    }

    private static func inInlane(_ p: CGPoint, _ g: [CGPoint]) -> Bool {
        // The straight part: right of the guide, from its top down to the bend.
        if p.y <= g[0].y, p.y >= g[1].y, p.x >= g[0].x, p.x <= g[0].x + width { return true }
        // The slant from the bend to the flipper: inside = up-right of the guide line.
        let ux = g[2].x - g[1].x, uy = g[2].y - g[1].y
        let len = (ux * ux + uy * uy).squareRoot()
        guard len > 1 else { return false }
        let dx = p.x - g[1].x, dy = p.y - g[1].y
        let along = (dx * ux + dy * uy) / len
        let out = (-dx * uy + dy * ux) / len
        return along >= 0 && along <= len - stopShort && out >= 0 && out <= width
    }
}
