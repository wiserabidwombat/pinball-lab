import SpriteKit
import CoreGraphics
import Foundation

/// Printed table text that stays readable at every camera zoom (M10 v5, Aaron: "On top down view the
/// text is too small to read on the table"). These names used to be painted into playfield.png, which
/// shrinks to ~60% on screen in Top-Down. Now they're live labels: each frame the font size grows with
/// the camera's zoom, up to the label's own limit so it never spills out of its spot.
final class TableLabel: SKNode {
    private let main: SKLabelNode
    private let shadow: SKLabelNode
    let baseSize: CGFloat
    let maxScale: CGFloat
    private var currentSize: CGFloat = 0

    init(_ text: String, baseSize: CGFloat, color: SKColor,
         vertical: SKLabelVerticalAlignmentMode = .center, maxScale: CGFloat) {
        main = SKLabelNode(text: text)
        shadow = SKLabelNode(text: text)
        self.baseSize = baseSize
        self.maxScale = maxScale
        super.init()
        for label in [shadow, main] {
            label.fontName = "Orbitron-Bold"
            label.verticalAlignmentMode = vertical
            label.horizontalAlignmentMode = .center
        }
        main.fontColor = color
        shadow.fontColor = SKColor(white: 0, alpha: 0.7)       // keeps it readable over the bright art
        addChild(shadow)
        addChild(main)
        setFontSize(baseSize)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `cameraScale` = world points per screen point (bigger = zoomed out).
    func fit(cameraScale: CGFloat, minScreenSize: CGFloat) {
        let scale = min(maxScale, max(1, cameraScale * minScreenSize / baseSize))
        // Half-point steps: a label re-renders its text on every size change, so a camera zoom
        // only redraws it a few times instead of every frame.
        let size = (baseSize * scale * 2).rounded() / 2
        guard size != currentSize else { return }
        setFontSize(size)
    }

    private func setFontSize(_ size: CGFloat) {
        currentSize = size
        main.fontSize = size
        shadow.fontSize = size
        shadow.position = CGPoint(x: size * 0.06, y: -size * 0.06)
    }
}

/// All the live table labels. Floor labels sit just above the playfield art; the ramp names are
/// added to their ramps (on the plastic, above the floor) but sized here too.
final class TableLabels: SKNode {
    /// The smallest a label should look on screen, in points (if its maxScale allows).
    static let minScreenSize: CGFloat = 9
    private var labels: [TableLabel] = []
    private var lastCameraScale: CGFloat = 0

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> SKColor {
        SKColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }

    override init() {
        super.init()
        zPosition = -15                                  // over the art (-20), under the ball's shadow (-5)
        // text, where, base size, colour, which edge is pinned (so it grows away from its lamp/hole), max scale, angle.
        // Positions were checked in a Top-Down mock-up (tools: labels_preview in HANDOFF).
        let specs: [(String, CGPoint, CGFloat, UInt32, SKLabelVerticalAlignmentMode, CGFloat, CGFloat)] = [
            ("HANGAR", CGPoint(x: 284, y: 627), 6, 0xe9e6f5, .top, 2.4, 0),           // under the hole
            ("ABDUCTION", CGPoint(x: 470, y: 677), 6, 0xe9e6f5, .top, 2.0, 0),        // under the hole
            ("LOCKS", CGPoint(x: 470, y: 747), 4, 0xb8ffcc, .bottom, 3.0, 0),         // over the lock lamps
            ("EARTH DEFENSE", CGPoint(x: 284, y: 465), 5.5, 0x9cc4ff, .bottom, 2.2, 0), // over its lamps
            ("SHIPS DOWN", CGPoint(x: 284, y: 401), 5, 0xffe58a, .top, 2.4, 0),       // under its lamps
            ("SHIELDS UP", CGPoint(x: 284, y: 289), 5, 0xd7b8ff, .top, 2.4, 0),       // under its lamp
            ("KICKBACK", CGPoint(x: 37, y: 300), 3.6, 0xffc9a0, .center, 3.0, 90),    // up the left outlane
            ("SAVE", CGPoint(x: 531, y: 300), 3.6, 0xa8fff4, .center, 3.0, 90),       // up the right outlane
        ]
        for (text, at, size, hex, vertical, maxScale, degrees) in specs {
            let label = TableLabel(text, baseSize: size, color: Self.color(hex), vertical: vertical, maxScale: maxScale)
            label.position = at
            label.zRotation = degrees * .pi / 180
            addChild(label)
            labels.append(label)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A ramp's name on its plastic (replaces Ramp.addLabel's fixed-size text).
    func addRampLabel(_ text: String, to ramp: SKNode, at point: CGPoint, degrees: CGFloat) {
        let label = TableLabel(text, baseSize: 6.5, color: SKColor(red: 0.85, green: 1.0, blue: 0.89, alpha: 0.95),
                               maxScale: 1.9)
        label.position = point
        label.zRotation = degrees * .pi / 180
        label.zPosition = 21.2                           // on the ramp plastic (20), under a ball on the ramp (30)
        ramp.addChild(label)
        labels.append(label)
    }

    /// Called after the camera moves each frame. Cheap when the zoom hasn't changed.
    func fit(cameraScale: CGFloat) {
        guard abs(cameraScale - lastCameraScale) > 0.005 else { return }
        lastCameraScale = cameraScale
        labels.forEach { $0.fit(cameraScale: cameraScale, minScreenSize: Self.minScreenSize) }
    }
}
