import GameController
import CoreGraphics
import QuartzCore
import Foundation

/// Pinball Lab (pre-TestFlight): game-controller support shared by every table. Any controller with the
/// Extended Gamepad profile (Xbox, PlayStation, MFi):
///   L1 / L2 = left flipper, R1 / R2 = right flipper (and the upper flipper on tables that have one)
///   plunger = hold A (it pulls back over 0.6 s; a quick press = a medium launch) or pull the right stick down,
///             and let go to launch
///   Menu = pause / resume, A = Play on the menu, Resume when paused, Play Again after a game
/// Menus stay touch-only. Tables poll `state` every frame for the flippers and plunger; the table view on screen
/// sets `onA` / `onMenu` for the buttons that drive its overlays.
@MainActor
final class LabGamepad {
    static let shared = LabGamepad()

    /// What the controller is doing this frame.
    struct State {
        var left = false
        var right = false
        /// How far the plunger is pulled back, 0…1 (A held, or the right stick pulled down).
        var pull: CGFloat = 0
        /// A is down (tables use it to tell a held press from a fresh one after Resume or Play).
        var aDown = false
    }

    /// Set by the table view on screen; called on the main thread when the button goes down.
    var onA: (() -> Void)?
    var onMenu: (() -> Void)?
    /// Which table set them, so a table leaving the screen only clears its own (a new table's onAppear can run
    /// before the old one's onDisappear).
    private var owner: String?

    /// The table view on screen takes the A and Menu buttons.
    func claim(_ table: String, onA: @escaping () -> Void, onMenu: @escaping () -> Void) {
        owner = table
        self.onA = onA
        self.onMenu = onMenu
    }

    /// A table leaving the screen lets go of A and Menu, unless another table has already claimed them.
    func release(_ table: String) {
        guard owner == table else { return }
        owner = nil
        onA = nil
        onMenu = nil
    }

    /// Seconds of holding A for a full pull.
    static let fullPullTime: CFTimeInterval = 0.6
    static let stickDeadZone: CGFloat = 0.2
    private var aDownSince: CFTimeInterval?

    private init() {
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LabGamepad.shared.attachHandlers() }
        }
        attachHandlers()
    }

    /// Call once at launch (or when a table appears) so the connect observer is in place.
    func start() {
        attachHandlers()
    }

    /// The controller's state now (all false / 0 with no controller connected).
    var state: State {
        guard let pad = GCController.current?.extendedGamepad else {
            aDownSince = nil
            return State()
        }
        var s = State()
        s.left = pad.leftShoulder.isPressed || pad.leftTrigger.isPressed
        s.right = pad.rightShoulder.isPressed || pad.rightTrigger.isPressed
        s.aDown = pad.buttonA.isPressed
        let now = CACurrentMediaTime()
        var aPull: CGFloat = 0
        if s.aDown {
            let since = aDownSince ?? now
            aDownSince = since
            aPull = CGFloat(min((now - since) / Self.fullPullTime, 1))
        } else {
            aDownSince = nil
        }
        // the right stick pulled down, with a dead zone so a resting stick's drift never touches the plunger
        let raw = CGFloat(max(0, -pad.rightThumbstick.yAxis.value))
        let stickPull = raw > Self.stickDeadZone ? (raw - Self.stickDeadZone) / (1 - Self.stickDeadZone) : 0
        s.pull = max(aPull, stickPull)
        return s
    }

    /// Menu and A as button-down events, on every connected controller.
    private func attachHandlers() {
        for controller in GCController.controllers() {
            guard let pad = controller.extendedGamepad else { continue }
            pad.buttonMenu.pressedChangedHandler = { _, _, pressed in
                guard pressed else { return }
                MainActor.assumeIsolated { LabGamepad.shared.onMenu?() }
            }
            pad.buttonA.pressedChangedHandler = { _, _, pressed in
                guard pressed else { return }
                MainActor.assumeIsolated { LabGamepad.shared.onA?() }
            }
        }
    }
}
