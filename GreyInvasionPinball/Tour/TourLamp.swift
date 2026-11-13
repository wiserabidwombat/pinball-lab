// Pinball Lab Table 06 (Orbit: Grand Tour), M7 v1: the lamp inserts as real lights. The floor painting has every
// insert painted UNLIT (tools/tour_floor_lower.py: jewel inserts, the planet arc, the shot arrows and their three-lamp
// stacks); a TourLamp sits over one and, when lit, covers it with the same insert glowing — bright plastic with a hot
// centre, its letter or number on top, and a soft additive halo spilling onto the floor. Off shows the painting.
import SpriteKit
import UIKit

@MainActor
final class TourLamp: SKNode {
    enum Mode: Equatable { case off, on, blink, blinkFast }
    enum Shape { case round(radius: CGFloat), planet(radius: CGFloat), arrow(heading: CGFloat) }

    private(set) var mode: Mode = .off
    /// What turns on: the lit insert, its label and its halo.
    private let lit = SKNode()

    /// M7 v2 (Aaron: "look like true glass lamps on a pinball table"): `insert` names a painted insert pair,
    /// tour_insert_<insert>_off / _on (tools/tour_paint_inserts.py: ink border, faceted plastic, clear-coat gloss; lit
    /// = glowing from the bulb's hot spot). The off image always shows (it covers the floor's painted insert); the on
    /// image fades in over it, with a soft halo of spill light. Planet inserts: the painted planet is the print, so off
    /// is just the glass and on an additive backlight. Labels are printed on top in ink.
    init(at point: CGPoint, shape: Shape, color: SKColor, insert: String, label: String? = nil,
         labelColor: SKColor = SKColor(white: 0.06, alpha: 0.92)) {
        super.init()
        position = point
        zPosition = -17.2
        let ptSize: (UIImage) -> CGSize = { CGSize(width: $0.size.width * $0.scale / 6, height: $0.size.height * $0.scale / 6) }
        let haloSize: CGSize
        var haloRotation: CGFloat = 0
        switch shape {
        case .round(let r): haloSize = CGSize(width: r * 4.6, height: r * 4.6)
        case .planet(let r): haloSize = CGSize(width: r * 5.5, height: r * 5.5)
        case .arrow(let h): haloSize = CGSize(width: 60, height: 42); haloRotation = h * .pi / 180
        }
        if let off = UIImage(named: "tour_insert_\(insert)_off") {
            let s = SKSpriteNode(texture: SKTexture(image: off), size: ptSize(off))
            addChild(s)
        }
        let halo = Self.halo(size: haloSize, color: color, alpha: 0.42)
        halo.zRotation = haloRotation
        halo.zPosition = -0.1
        lit.addChild(halo)
        if let on = UIImage(named: "tour_insert_\(insert)_on") {
            let s = SKSpriteNode(texture: SKTexture(image: on), size: ptSize(on))
            if case .planet = shape { s.blendMode = .add }
            lit.addChild(s)
        }
        lit.alpha = 0
        addChild(lit)
        if let label {
            let r: CGFloat
            if case .round(let rr) = shape { r = rr } else { r = 8 }
            let l = Self.label(label, size: r * 1.05, color: Self.unlitInk)
            l.zPosition = 0.2
            addChild(l)
            printed = l
            litInk = labelColor
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The printed letter: dark ink over the glow when lit, a pale print on the dark plastic when not (so it reads).
    private var printed: SKLabelNode?
    private var litInk = SKColor(white: 0.06, alpha: 0.92)
    private static let unlitInk = SKColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 0.72)

    func set(_ m: Mode) {
        guard m != mode else { return }
        mode = m
        printed?.fontColor = m == .off ? Self.unlitInk : litInk
        lit.removeAction(forKey: "blink")
        switch m {
        case .off: lit.alpha = 0
        case .on: lit.alpha = 1
        case .blink, .blinkFast:
            let half: TimeInterval = m == .blink ? 0.38 : 0.12
            lit.alpha = 1
            lit.run(.repeatForever(.sequence([.wait(forDuration: half), .fadeAlpha(to: 0, duration: 0.04),
                                              .wait(forDuration: half), .fadeAlpha(to: 1, duration: 0.04)])),
                    withKey: "blink")
        }
    }

    var isOn: Bool {
        get { mode != .off }
        set { set(newValue ? .on : .off) }
    }

    // MARK: drawing

    private static func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(text: text)
        l.fontName = "AvenirNext-Bold"
        l.fontSize = size
        l.fontColor = color
        l.verticalAlignmentMode = .center
        l.horizontalAlignmentMode = .center
        return l
    }

    private static func halo(size: CGSize, color: SKColor, alpha: CGFloat) -> SKSpriteNode {
        let h = SKSpriteNode(texture: haloTexture, size: size)
        h.color = color
        h.colorBlendFactor = 1
        h.blendMode = .add
        h.alpha = alpha
        return h
    }

    private static let haloTexture: SKTexture = {
        let side: CGFloat = 64
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let colors = [UIColor(white: 1, alpha: 0.9).cgColor, UIColor(white: 1, alpha: 0.35).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1])!
            let c = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: side / 2,
                                             options: [])
        }
        return SKTexture(image: image)
    }()
}
