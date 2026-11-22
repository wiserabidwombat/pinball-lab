// Pinball Lab Table 07 (CHOMP!), M3 v15: the fin — the shark's fin, a drop target that roams along the curved slot in
// the cyan "kidney" right of centre (p. 40; the real table's moving fin, "ricochets back to the flippers").
import SpriteKit
import CoreGraphics
import Foundation

/// A blade along the slot. Up, it is a solid target (category `target`, floor balls only) that the scene slides back
/// and forth along the slot; a hit drops it (the scene calls `drop()` from update, not from the contact callback) and
/// balls roll over the slot until the scene raises it again.
final class ChompFin: SKNode {
    private let slot: [CGPoint]
    private var cumulative: [CGFloat] = [0]
    private let minS: CGFloat
    private let maxS: CGFloat
    private let blade: SKShapeNode
    private let length: CGFloat
    private let thickness: CGFloat
    /// Distance along the slot of the fin's centre, and which way it is roaming (+1 toward the slot's lower right end).
    private(set) var s: CGFloat
    private var direction: CGFloat = 1
    private(set) var isUp = true
    private(set) var droppedAt: TimeInterval = 0

    init(slot: [CGPoint], minS: CGFloat, maxS: CGFloat, length: CGFloat, thickness: CGFloat) {
        self.slot = slot
        for (a, b) in zip(slot, slot.dropFirst()) {
            cumulative.append(cumulative.last! + hypot(b.x - a.x, b.y - a.y))
        }
        self.minS = minS
        self.maxS = min(maxS, cumulative.last!)
        self.length = length
        self.thickness = thickness
        self.s = minS
        blade = SKShapeNode(rectOf: CGSize(width: length, height: thickness), cornerRadius: thickness / 2)
        super.init()
        zPosition = 1
        blade.fillColor = SKColor(red: 0.36, green: 0.42, blue: 0.50, alpha: 1)      // shark grey
        blade.strokeColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.8)
        blade.lineWidth = 1.5
        addChild(blade)
        let ridge = SKShapeNode(rectOf: CGSize(width: length * 0.7, height: 2), cornerRadius: 1)
        ridge.position = CGPoint(x: -length * 0.08, y: 0)
        ridge.fillColor = SKColor(red: 0.80, green: 0.84, blue: 0.90, alpha: 0.9)
        ridge.strokeColor = .clear
        blade.addChild(ridge)
        let body = SKPhysicsBody(rectangleOf: CGSize(width: length, height: thickness))
        body.isDynamic = false
        body.restitution = 0.3
        body.friction = 0.2
        physicsBody = body
        setSolid(true)
        place()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The slot drawn into the playfield (a white groove), for the scene to add under the fin.
    func slotNode() -> SKShapeNode {
        let path = CGMutablePath()
        path.addLines(between: slot)
        let n = SKShapeNode(path: path)
        n.strokeColor = SKColor(white: 0.96, alpha: 0.85)
        n.lineWidth = 8
        n.lineCap = .round
        n.lineJoin = .round
        n.zPosition = 0.5
        return n
    }

    /// Point and heading on the slot at distance `d`.
    private func point(at d: CGFloat) -> (CGPoint, CGFloat) {
        let d = max(0, min(cumulative.last!, d))
        for i in 0..<(slot.count - 1) where d <= cumulative[i + 1] {
            let a = slot[i], b = slot[i + 1]
            let span = cumulative[i + 1] - cumulative[i]
            let t = span > 0 ? (d - cumulative[i]) / span : 0
            return (CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)), atan2(b.y - a.y, b.x - a.x))
        }
        let a = slot[slot.count - 2], b = slot[slot.count - 1]
        return (b, atan2(b.y - a.y, b.x - a.x))
    }

    private func place() {
        let (p, heading) = point(at: s)
        position = p
        zRotation = heading
    }

    private func setSolid(_ solid: Bool) {
        guard let body = physicsBody else { return }
        body.categoryBitMask = solid ? ChompPhysicsCategory.target : ChompPhysicsCategory.none
        body.collisionBitMask = solid ? ChompPhysicsCategory.ball : 0
        body.contactTestBitMask = solid ? ChompPhysicsCategory.ball : 0
    }

    /// Roams back and forth between the travel stops while up (`speed` pt/s along the slot; 0 parks it).
    func update(dt: CGFloat, speed: CGFloat) {
        guard isUp, speed > 0 else { return }
        s += direction * speed * dt
        if s >= maxS { s = maxS; direction = -1 }
        if s <= minS { s = minS; direction = 1 }
        place()
    }

    func drop(at now: TimeInterval) {
        guard isUp else { return }
        isUp = false
        droppedAt = now
        setSolid(false)
        blade.alpha = 0.25
    }

    /// Up again — unless a ball is over the blade (a drop target can't rise under a ball).
    @discardableResult
    func raise(clearOf balls: [CGPoint], ballRadius: CGFloat) -> Bool {
        guard !isUp else { return true }
        let reach = length / 2 + ballRadius + 4
        if balls.contains(where: { hypot($0.x - position.x, $0.y - position.y) < reach }) { return false }
        isUp = true
        setSolid(true)
        blade.alpha = 1
        return true
    }

    /// M5 v2: the fin's lamp — the blade takes a colour while a cameo wants it (nil = shark grey).
    func setGlow(_ color: SKColor?) {
        let c = color ?? SKColor(red: 0.36, green: 0.42, blue: 0.50, alpha: 1)
        if blade.fillColor != c { blade.fillColor = c }
    }

    /// Up, at the slot's upper-left stop, roaming toward the right.
    func reset() {
        isUp = true
        setSolid(true)
        blade.alpha = 1
        s = minS
        direction = 1
        place()
    }
}
