// Pinball Lab Table 03 (Cthulhu Rising), milestone 6 round 1: lamps. Grey Invasion's Lamp + LampController
// copied with the "Cth" prefix, plus a star shape and "painted" lamps that light inserts baked into the art.
import SpriteKit
import CoreGraphics
import Foundation

/// What a lamp is doing. The rules set states; only the controller animates them.
/// Off = nothing to gain here, on = done / active, blink = the next goal, fast blink = do it now.
enum CthLampState { case off, on, blink, fastBlink }

/// A lamp insert on the playfield. No physics: it sits under the moving parts (z -1, or -18 for lamps over
/// the baked lower-table art). An off lamp still shows as a dim insert so the player sees what's there,
/// except a `painted` one: its insert is already in the art, so off = nothing drawn, lit = a bright fill
/// and a glow over the painting.
final class CthLamp: SKNode {
    enum Shape {
        case arrow(length: CGFloat, width: CGFloat)   // points along +x before rotation
        case round(radius: CGFloat)
        case star(outer: CGFloat, inner: CGFloat)     // five points, one straight up
    }

    var state: CthLampState = .off
    private let color: SKColor
    private let painted: Bool
    private let insert: SKShapeNode
    private let glow: SKShapeNode
    private var brightness: CGFloat = -1

    init(_ shape: Shape, color: SKColor, at point: CGPoint, angle: CGFloat = 0, painted: Bool = false) {
        self.color = color
        self.painted = painted
        let path = CthLamp.path(for: shape)
        insert = SKShapeNode(path: path)
        glow = SKShapeNode(path: path)
        super.init()
        position = point
        zRotation = angle
        zPosition = painted ? -18 : -1          // painted lamps sit just over the lower art (z -19)

        // A soft additive halo: a larger copy of the shape (cheaper than glowWidth on a phone).
        glow.fillColor = color
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.setScale(1.6)
        addChild(glow)

        insert.strokeColor = painted ? .clear : color.withAlphaComponent(0.7)
        insert.lineWidth = 1
        if painted { insert.blendMode = .add }
        addChild(insert)
        setBrightness(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 0 = dark insert, 1 = fully lit. Only touches the nodes when the value changes.
    func setBrightness(_ b: CGFloat) {
        guard b != brightness else { return }
        brightness = b
        insert.fillColor = color.withAlphaComponent(painted ? 0.75 * b : 0.16 + 0.84 * b)
        glow.alpha = 0.35 * b
    }

    private static func path(for shape: Shape) -> CGPath {
        switch shape {
        case .arrow(let length, let width):
            // Same shape as the painted inserts (tools/cth_floor_lower.py): notch 6 pt in from the tail.
            let p = CGMutablePath()
            p.move(to: CGPoint(x: length / 2, y: 0))
            p.addLine(to: CGPoint(x: -length / 2, y: width / 2))
            p.addLine(to: CGPoint(x: -length / 2 + 6, y: 0))
            p.addLine(to: CGPoint(x: -length / 2, y: -width / 2))
            p.closeSubpath()
            return p
        case .round(let radius):
            return CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                          transform: nil)
        case .star(let outer, let inner):
            let p = CGMutablePath()
            for i in 0..<10 {
                let r = i % 2 == 0 ? outer : inner
                let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let pt = CGPoint(x: r * cos(a), y: r * sin(a))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }
}

/// Lamp shows: short light patterns that override the lamps' states.
enum CthLampShow {
    case attract    // menu: a band of light climbing the table, looping
    case sweep      // multiball / mode start: one bright band rises up the table
    case flash      // jackpot: every lamp flashes
}

/// Owns every lamp by name and turns states into brightness each frame, all from one clock, so every
/// blinking lamp blinks in step. A running show overrides the states.
@MainActor
final class CthLampController {
    private var lamps: [String: CthLamp] = [:]
    private var showStart: TimeInterval = 0
    private var showEnd: TimeInterval = 0
    private var showPattern: ((CGPoint, TimeInterval) -> CGFloat?)?

    func play(_ show: CthLampShow, at now: TimeInterval) {
        showStart = now
        switch show {
        case .attract:
            showEnd = .infinity
            showPattern = { p, t in
                // ~1.4 s per pass, bottom to top; lamps outside the band go dark
                var phase = (t * 0.7 - Double(p.y) / 1300).truncatingRemainder(dividingBy: 1)
                if phase < 0 { phase += 1 }
                return phase < 0.18 ? 1 : 0
            }
        case .sweep:
            showEnd = now + 1.0
            showPattern = { p, t in
                let bandY = 150 + t * 900                       // y 150 → 1050 in one second
                return abs(Double(p.y) - bandY) < 70 ? 1 : nil   // nil = the lamp's own state
            }
        case .flash:
            showEnd = now + 0.7
            showPattern = { _, t in
                Int(t * 12) % 2 == 0 ? 1 : 0                    // 6 flashes a second, all lamps
            }
        }
    }

    func stopShow() {
        showPattern = nil
    }

    func add(_ lamp: CthLamp, named name: String) {
        lamps[name] = lamp
    }

    func set(_ name: String, _ state: CthLampState) {
        lamps[name]?.state = state
    }

    func update(time: TimeInterval) {
        if showPattern != nil, time >= showEnd { showPattern = nil }
        let slowOn = Int(time * 4) % 2 == 0     // 2 blinks a second
        let fastOn = Int(time * 10) % 2 == 0    // 5 blinks a second
        let showTime = time - showStart
        for lamp in lamps.values {
            var b: CGFloat
            switch lamp.state {
            case .off: b = 0
            case .on: b = 1
            case .blink: b = slowOn ? 1 : 0
            case .fastBlink: b = fastOn ? 1 : 0
            }
            if let pattern = showPattern, let shown = pattern(lamp.position, showTime) {
                b = shown
            }
            lamp.setBrightness(b)
        }
    }
}
