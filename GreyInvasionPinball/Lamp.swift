import SpriteKit
import CoreGraphics
import Foundation

/// What a lamp is doing. The rules set states; only the LampController animates them.
/// Off = nothing to gain here, on = done / active, blink = the next goal, fast blink = do it now.
enum LampState { case off, on, blink, fastBlink }

/// A lamp insert painted on the playfield (milestone 6). No physics: it sits under everything
/// (z -1). An off lamp still shows as a dim insert, so the player can see what's there.
final class Lamp: SKNode {
    enum Shape {
        case arrow(length: CGFloat, width: CGFloat)   // points along +x before rotation
        case round(radius: CGFloat)
        case bar(size: CGSize)
    }

    var state: LampState = .off
    private let color: SKColor
    private let insert: SKShapeNode
    private let glow: SKShapeNode
    private var brightness: CGFloat = -1

    init(_ shape: Shape, color: SKColor, at point: CGPoint, angle: CGFloat = 0) {
        self.color = color
        let path = Lamp.path(for: shape)
        insert = SKShapeNode(path: path)
        glow = SKShapeNode(path: path)
        super.init()
        position = point
        zRotation = angle
        zPosition = -1

        // A soft additive halo: a larger copy of the shape (cheaper than glowWidth on a phone).
        glow.fillColor = color
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.setScale(1.6)
        addChild(glow)

        insert.strokeColor = color.withAlphaComponent(0.7)
        insert.lineWidth = 1
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
        insert.fillColor = color.withAlphaComponent(0.16 + 0.84 * b)
        glow.alpha = 0.35 * b
    }

    private static func path(for shape: Shape) -> CGPath {
        switch shape {
        case .arrow(let length, let width):
            let p = CGMutablePath()
            p.move(to: CGPoint(x: length / 2, y: 0))
            p.addLine(to: CGPoint(x: -length / 2, y: width / 2))
            p.addLine(to: CGPoint(x: -length / 4, y: 0))
            p.addLine(to: CGPoint(x: -length / 2, y: -width / 2))
            p.closeSubpath()
            return p
        case .round(let radius):
            return CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                          transform: nil)
        case .bar(let size):
            return CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                              width: size.width, height: size.height),
                          cornerWidth: 3, cornerHeight: 3, transform: nil)
        }
    }
}

/// Lamp shows (milestone 6 round 2): short light patterns that override the lamps' states.
enum LampShow {
    case attract    // menu: a band of light climbing the table, looping
    case sweep      // multiball start: one bright band rises up the table
    case flash      // jackpot: every lamp flashes
}

/// Owns every lamp by name and turns states into brightness each frame, all from one clock,
/// so every blinking lamp blinks in step. A running show overrides the states: its pattern
/// gives a brightness for each lamp from the lamp's position and the show's time.
@MainActor
final class LampController {
    private var lamps: [String: Lamp] = [:]
    private var showStart: TimeInterval = 0
    private var showEnd: TimeInterval = 0
    private var showPattern: ((CGPoint, TimeInterval) -> CGFloat?)?

    func play(_ show: LampShow, at now: TimeInterval) {
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

    func add(_ lamp: Lamp, named name: String) {
        lamps[name] = lamp
    }

    func set(_ name: String, _ state: LampState) {
        lamps[name]?.state = state
    }

    /// A lamp's state (the Play Lab robot reads the arrows the way a player does).
    func state(of name: String) -> LampState? {
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
