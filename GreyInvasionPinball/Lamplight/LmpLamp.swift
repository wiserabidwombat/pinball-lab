// Pinball Lab Table 05 (The Lamplight), milestone 7: lamps. Monsoon's MonLamp + MonLampController (from Table 03's)
// copied with the "Lmp" prefix (star shape and "painted" lamps included, for inserts baked into the art later).
import SpriteKit
import CoreGraphics
import Foundation

/// What a lamp is doing. The rules set states; only the controller animates them.
/// Off = nothing to gain here, on = done / active, blink = the next goal, fast blink = do it now.
enum LmpLampState { case off, on, blink, fastBlink }

/// A lamp insert on the playfield. No physics: it sits under the moving parts (z -1, or -18 for lamps over
/// the baked lower-table art). An off lamp still shows as a dim insert so the player sees what's there,
/// except a `painted` one: its insert is already in the art, so off = nothing drawn, lit = a bright fill
/// and a glow over the painting.
final class LmpLamp: SKNode {
    enum Shape {
        case arrow(length: CGFloat, width: CGFloat)   // points along +x before rotation
        case round(radius: CGFloat)
        case star(outer: CGFloat, inner: CGFloat)     // five points, one straight up
    }

    var state: LmpLampState = .off
    private let color: SKColor
    private let painted: Bool
    private let insert: SKShapeNode
    private let glow: SKShapeNode
    /// M9 v6c (Aaron: "double check some of the lights"): on the pencil sketch and the pale watercolor an additive glow
    /// and a faint insert were nearly invisible. A dark socket behind each insert, a normal-blend halo and a hot core
    /// make lamps read on any background.
    private let socket: SKShapeNode
    private let core: SKShapeNode
    private var brightness: CGFloat = -1

    init(_ shape: Shape, color: SKColor, at point: CGPoint, angle: CGFloat = 0, painted: Bool = false) {
        self.color = color
        self.painted = painted
        let path = LmpLamp.path(for: shape)
        insert = SKShapeNode(path: path)
        glow = SKShapeNode(path: path)
        socket = SKShapeNode(path: path)
        core = SKShapeNode(path: path)
        super.init()
        position = point
        zRotation = angle
        zPosition = painted ? -18 : -1          // painted lamps sit just over the lower art (z -19)

        if !painted {
            socket.fillColor = SKColor(red: 0.06, green: 0.05, blue: 0.10, alpha: 0.55)
            socket.strokeColor = .clear
            socket.setScale(1.25)
            addChild(socket)
        }
        // A soft halo: a larger copy of the shape (cheaper than glowWidth on a phone). Normal blend, so it also shows on
        // light paper (painted lamps keep the additive glow over their printed inserts).
        glow.fillColor = color
        glow.strokeColor = .clear
        glow.blendMode = painted ? .add : .alpha
        glow.setScale(painted ? 1.6 : 1.9)
        addChild(glow)

        insert.strokeColor = painted ? .clear : color.withAlphaComponent(0.7)
        insert.lineWidth = 1
        if painted { insert.blendMode = .add }
        addChild(insert)
        if !painted {
            core.fillColor = SKColor(red: 1, green: 1, blue: 0.95, alpha: 1)
            core.strokeColor = .clear
            core.setScale(0.45)
            addChild(core)
        }
        setBrightness(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 0 = dark insert, 1 = fully lit. Only touches the nodes when the value changes.
    func setBrightness(_ b: CGFloat) {
        guard b != brightness else { return }
        brightness = b
        if painted {
            insert.fillColor = color.withAlphaComponent(0.75 * b)
            glow.alpha = 0.35 * b
        } else {
            // off: a dim tinted insert in its dark socket; lit: full colour, a halo and a near-white core
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &bl, alpha: &a)
            let k = 0.45 + 0.55 * b
            insert.fillColor = SKColor(red: r * k, green: g * k, blue: bl * k, alpha: 0.30 + 0.70 * b)
            glow.alpha = 0.45 * b
            core.alpha = 0.9 * b
        }
    }

    private static func path(for shape: Shape) -> CGPath {
        switch shape {
        case .arrow(let length, let width):
            // Same shape as the painted inserts (Table 03's painted inserts): notch 6 pt in from the tail.
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
enum LmpLampShow {
    case attract    // menu: a band of light climbing the table, looping
    case sweep      // multiball / mode start: one bright band rises up the table
    case flash      // jackpot: every lamp flashes
}

/// Owns every lamp by name and turns states into brightness each frame, all from one clock, so every
/// blinking lamp blinks in step. A running show overrides the states.
@MainActor
final class LmpLampController {
    private var lamps: [String: LmpLamp] = [:]
    private var showStart: TimeInterval = 0
    private var showEnd: TimeInterval = 0
    private var showPattern: ((CGPoint, TimeInterval) -> CGFloat?)?

    func play(_ show: LmpLampShow, at now: TimeInterval) {
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

    func add(_ lamp: LmpLamp, named name: String) {
        lamps[name] = lamp
    }

    func set(_ name: String, _ state: LmpLampState) {
        lamps[name]?.state = state
    }

    /// A lamp's state (the Play Lab robot reads the arrows the way a player does).
    func state(of name: String) -> LmpLampState? {
        lamps[name]?.state
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
