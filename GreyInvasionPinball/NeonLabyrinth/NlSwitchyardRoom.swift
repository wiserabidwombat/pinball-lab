// Pinball Lab Table 08 (Neon Labyrinth): the SWITCHYARD room (T8 M2 v1's rules, moved out of the scene in M2 round A
// with no gameplay change). Geometry: NlSwitchyardLayout.swift (generated from tools/nl_room_switchyard.py).
//
// A ramp shot rides up onto the turntable; SWITCH ◄ / ► turn the turntable (W N E, stepping), RAILS steps the
// light-rail ring's bridge (W → N → E → W). Lined up, the turntable fires the ball down that light-rail and out through
// the exit portal; not lined up, the ball derails to the floor.
import SpriteKit
import CoreGraphics

@MainActor
final class NlSwitchyardRoom: NlRoom {
    typealias Y = NlSwitchyardLayout

    // MARK: Tuning (T8 M2 v1)
    /// A floor ball crossing into the ramp's mouth going up at least this fast is taken up the ramp (a scripted ride);
    /// slower, it stays on the floor and falls back off the U's gable (a weak shot).
    static let rampMinSpeed: CGFloat = 400
    /// Up the ramp at the shot's speed × 0.7, between these, rising to the turntable's height.
    static let rampRideScale: CGFloat = 0.7
    static let rampRideSpeeds: ClosedRange<CGFloat> = 450...900
    /// Held on the turntable this long before it fires the ball along its heading.
    static let turntableHold: CGFloat = 0.5
    /// The turntable and the bridge turn this fast (rad/s) on screen.
    static let turnRate: CGFloat = 7
    /// Along a light-rail to its exit portal.
    static let railRideSpeed: CGFloat = 700
    /// A derail (the turntable and the bridge don't line up): the ball leaves the turntable along its heading, past the
    /// ring, and drops to the floor here, with this velocity (tools/nl_derail_sim.py: no stuck balls; 87–97% reach a
    /// flipper first with the flippers down and no player).
    static let derailOut: CGFloat = Y.railRingRadii.1 + 10
    static let derailNorthOut: CGFloat = Y.railRingRadii.1 + 16
    static let derailSideVelocity = CGVector(dx: 250, dy: -60)     // W mirrored
    static let derailNorthVelocity = CGVector(dx: 60, dy: 150)     // ± dx, alternating

    /// The three ways the turntable and the bridge can point: 0 = W (◄), 1 = N (▲), 2 = E (►) — NlExit's raw values.
    static let headingAngle: [CGFloat] = [.pi, .pi / 2, 0]
    private static func glyph(_ k: Int) -> String { NlExit(rawValue: k)?.glyph ?? "?" }

    /// The room's rides, by tag.
    private enum Tag {
        static let turntable = 0          // up the ramp → held on the turntable
        static let fire = 1               // held → fired along the heading (rail or derail, decided as it fires)
        static let exitBase = 10          // + heading: down a light-rail → out the exit
        static let derailBase = 20        // + heading: off the turntable → the floor
    }

    private weak var cell: NlTableScene?

    // Where the turntable and the bridge point (0 W, 1 N, 2 E), their drawn angles, and the nodes that show the route.
    private var turntable = 1
    private var bridge = 0
    private var turntableShown: CGFloat = .pi / 2
    private var bridgeShown: CGFloat = .pi
    private var turntablePointer: SKShapeNode?
    private var bridgeNode: SKShapeNode?
    private var railNodes: [[SKShapeNode]] = []
    private var routeLamps: [(lamp: SKShapeNode, label: SKLabelNode)] = []
    private var nextNorthDerailRight = true
    private var routeOpen: Bool { turntable == bridge }

    // MARK: NlRoom

    let exits: Set<NlExit> = [.left, .top, .right]
    let solidBlocks: [[CGPoint]] = [Y.switchBlockLeft, Y.switchBlockRight, Y.railsBlock]
    let targetEvents = ["SWITCH ◄": "switchLeft", "SWITCH ►": "switchRight", "RAILS": "rails"]

    func build(in cell: NlTableScene) {
        self.cell = cell
        for pts in [Y.switchBlockLeft, Y.switchBlockRight, Y.railsBlock, Y.rampU] { cell.addWall(points: pts) }
        for p in Y.rampMouthPosts { cell.addPost(at: p, radius: Y.rampMouthPostRadius) }
        cell.addPost(at: Y.hubCenter, radius: Y.hubBaseRadius, fill: SKColor(red: 0.08, green: 0.16, blue: 0.11, alpha: 1))
        cell.addTarget(name: "SWITCH ◄", face: Y.switchLeftFace, normal: Y.switchLeftNormal)
        cell.addTarget(name: "SWITCH ►", face: Y.switchRightFace, normal: Y.switchRightNormal)
        cell.addTarget(name: "RAILS", face: Y.railsFace, normal: Y.railsNormal)
        addDrawnParts(cell)
    }

    func newGame() {
        turntable = 1                              // the turntable points N, the bridge W (not lined up)
        bridge = 0
        nextNorthDerailRight = true
        refreshRoute(snap: true)
    }

    func update(_ dt: CGFloat) {
        turnRoute(dt)
    }

    func ballMoved(_ ball: NlBall) {
        checkRampEntry(ball)
    }

    func targetHit(_ name: String) -> String {
        switch name {
        case "SWITCH ◄": turntable = max(0, turntable - 1)
        case "SWITCH ►": turntable = min(2, turntable + 1)
        case "RAILS": bridge = (bridge + 1) % 3
        default: return name
        }
        refreshRoute()
        cell?.sfx(.diverter)
        if routeOpen { return "ROUTE OPEN \(Self.glyph(turntable))" }
        return name == "RAILS" ? "RAILS \(Self.glyph(bridge))" : "TURNTABLE \(Self.glyph(turntable))"
    }

    func rideEnded(_ ball: NlBall, tag: Int) {
        guard let cell else { return }
        let hub = Y.hubCenter
        let h = NlTableLayout.rampTopHeight
        switch tag {
        case Tag.turntable:
            cell.ride(ball, path: [hub, hub], speed: 0, height: h, release: .zero, end: .room(Tag.fire),
                      hold: Self.turntableHold)
            cell.showBanner("SWITCHYARD \(Self.glyph(turntable))")
            cell.sfx(.scoopIn)
        case Tag.fire:
            let k = turntable
            let a = Self.headingAngle[k]
            if routeOpen {
                let rail = [Y.railW, Y.railN, Y.railE][k]
                cell.ride(ball, path: [hub] + rail, speed: Self.railRideSpeed, height: h, release: .zero,
                          end: .room(Tag.exitBase + k))
                cell.sfx(.launch)
            } else {
                let out = k == 1 ? Self.derailNorthOut : Self.derailOut
                let to = CGPoint(x: hub.x + out * cos(a), y: hub.y + out * sin(a))
                cell.ride(ball, path: [hub, to], speed: Self.railRideSpeed, height: h, heightEnd: 0,
                          release: .zero, end: .room(Tag.derailBase + k))
            }
        case Tag.exitBase...(Tag.exitBase + 2):
            if let exit = NlExit(rawValue: tag - Tag.exitBase) { cell.leave(ball, by: exit) }
        case Tag.derailBase...(Tag.derailBase + 2):
            let k = tag - Tag.derailBase
            let v: CGVector
            switch k {
            case 0: v = CGVector(dx: -Self.derailSideVelocity.dx, dy: Self.derailSideVelocity.dy)
            case 2: v = Self.derailSideVelocity
            default:
                let n = Self.derailNorthVelocity
                v = CGVector(dx: nextNorthDerailRight ? n.dx : -n.dx, dy: n.dy)
                nextNorthDerailRight.toggle()
            }
            ball.setLayer(.floor)
            ball.rampHeight = 0
            ball.physicsBody?.velocity = v
            ball.previousPosition = ball.position
            cell.showBanner("DERAIL")
            cell.labEvent("derail")
            cell.sfx(.gate)
        default:
            break
        }
    }

    func ballLeft(by exit: NlExit) {
        guard let cell else { return }
        if !cell.isTilted { cell.score(NlPoints.exit) }   // a tilted ball still leaves, but scores nothing
        cell.showBanner("EXIT \(exit.glyph) · \(NlPoints.exit)")
        cell.sfx(.jackpot)
        cell.haptic(1)
    }

    var tagText: String { "\(Self.glyph(turntable))\(routeOpen ? "=" : "≠")\(Self.glyph(bridge))" }

    var status: String? { nil }

    // MARK: The ramp

    /// A floor ball crossing into the ramp's mouth going up fast enough is taken up the ramp to the turntable.
    private func checkRampEntry(_ ball: NlBall) {
        guard let cell else { return }
        let p0 = ball.previousPosition, p = ball.position
        let c = NlCellLayout.centerX
        let entryY = Y.rampMouthY + 12
        guard ball.isOnFloor, p0.y < entryY, p.y >= entryY, abs(p.x - c) < Y.rampMouthPosts[1].x - c,
              let v = ball.physicsBody?.velocity, v.dy >= Self.rampMinSpeed else { return }
        let speed = min(max(hypot(v.dx, v.dy) * Self.rampRideScale, Self.rampRideSpeeds.lowerBound),
                        Self.rampRideSpeeds.upperBound)
        cell.ride(ball, path: [p, CGPoint(x: c, y: Y.rampUTopY), CGPoint(x: c, y: Y.rampTopY), Y.hubCenter],
                  speed: speed, height: 0, heightEnd: NlTableLayout.rampTopHeight, release: .zero,
                  end: .room(Tag.turntable))
        cell.score(NlPoints.ramp)
        cell.sfx(.ramp)
        cell.labEvent("ramp")
    }

    // MARK: Drawing and the route

    /// The ramp's raised part, the turntable with its pointer, the light-rail ring with its bridge, the three
    /// light-rails, and the route lamps (◄ ▲ ►) in the open lower table.
    private func addDrawnParts(_ cell: NlTableScene) {
        typealias S = NlTableScene
        let c = NlCellLayout.centerX
        // The ramp's plastic above its solid low end.
        let ramp = CGMutablePath()
        let left = Y.rampLeftRail.filter { $0.y >= Y.rampUTopY }
        let right = Y.rampRightRail.filter { $0.y >= Y.rampUTopY }
        ramp.addLines(between: left + right.reversed())
        ramp.closeSubpath()
        let plastic = SKShapeNode(path: ramp)
        plastic.fillColor = S.wallColor.withAlphaComponent(0.16)
        plastic.strokeColor = S.wallColor.withAlphaComponent(0.5)
        plastic.lineWidth = 1.5
        plastic.zPosition = 15
        cell.addChild(plastic)
        // Turntable and the light-rail ring.
        for (r, w, a) in [(Y.hubTrackRadius, CGFloat(2.5), CGFloat(0.9)), (Y.railRingRadii.0, 1.2, 0.6), (Y.railRingRadii.1, 1.2, 0.6)] {
            let ring = SKShapeNode(circleOfRadius: r)
            ring.position = Y.hubCenter
            ring.strokeColor = S.wireColor.withAlphaComponent(a)
            ring.fillColor = r == Y.hubTrackRadius ? SKColor(white: 0.08, alpha: 1) : .clear
            ring.lineWidth = w
            ring.zPosition = 16
            cell.addChild(ring)
        }
        // The turntable's pointer and the ring's bridge (drawn pointing east; turned by zRotation).
        let pointer = CGMutablePath()
        pointer.addLines(between: [CGPoint(x: -14, y: 9), CGPoint(x: Y.hubTrackRadius - 4, y: 0), CGPoint(x: -14, y: -9)])
        pointer.closeSubpath()
        let pointerNode = SKShapeNode(path: pointer)
        pointerNode.position = Y.hubCenter
        pointerNode.lineWidth = 2
        pointerNode.zPosition = 16.5
        cell.addChild(pointerNode)
        turntablePointer = pointerNode
        let bridgeShape = SKShapeNode(rect: CGRect(x: Y.railRingRadii.0 - 2, y: -Y.railHalfWidth,
                                                   width: Y.railRingRadii.1 - Y.railRingRadii.0 + 6, height: 2 * Y.railHalfWidth),
                                      cornerRadius: 3)
        bridgeShape.position = Y.hubCenter
        bridgeShape.lineWidth = 2
        bridgeShape.zPosition = 16.4
        cell.addChild(bridgeShape)
        bridgeNode = bridgeShape
        // The light-rails: two silver rails each.
        railNodes = [Y.railW, Y.railN, Y.railE].map { cell.addRails($0, halfWidth: Y.railHalfWidth, z: 16) }
        // Route lamps (◄ ▲ ►) in the open lower table.
        for (dx, glyph) in [(CGFloat(-46), "◄"), (0, "▲"), (46, "►")] {
            let lamp = SKShapeNode(circleOfRadius: 15)
            lamp.position = CGPoint(x: c + dx, y: 505)
            lamp.strokeColor = S.entryColor.withAlphaComponent(0.5)
            lamp.fillColor = SKColor(white: 0.05, alpha: 1)
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            cell.addChild(lamp)
            let label = SKLabelNode(text: glyph)
            label.fontName = "Menlo-Bold"
            label.fontSize = 14
            label.fontColor = S.entryColor.withAlphaComponent(0.6)
            label.verticalAlignmentMode = .center
            label.position = lamp.position
            label.zPosition = -17.9
            cell.addChild(label)
            routeLamps.append((lamp: lamp, label: label))
        }
        refreshRoute(snap: true)
    }

    /// Colours the route: the turntable's pointer and its route lamp cyan when the bridge lines up (the route is
    /// open), orange when it doesn't (a ramp shot would derail); the bridge and its lamp's ring magenta; the open
    /// route's light-rail bright, and its exit portal lit. `snap` puts the drawn angles straight on their headings.
    private func refreshRoute(snap: Bool = false) {
        typealias S = NlTableScene
        if snap {
            turntableShown = Self.headingAngle[turntable]
            bridgeShown = Self.headingAngle[bridge]
        }
        let orange = SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        let aim = routeOpen ? S.entryColor : orange
        turntablePointer?.strokeColor = aim
        turntablePointer?.fillColor = aim.withAlphaComponent(0.35)
        turntablePointer?.zRotation = turntableShown
        bridgeNode?.strokeColor = routeOpen ? S.entryColor : S.exitColor
        bridgeNode?.fillColor = (routeOpen ? S.entryColor : S.exitColor).withAlphaComponent(0.25)
        bridgeNode?.zRotation = bridgeShown
        for (i, nodes) in railNodes.enumerated() {
            let open = routeOpen && i == turntable
            for n in nodes {
                n.strokeColor = open ? S.entryColor : S.wireColor
                n.lineWidth = open ? 2.6 : 1.6
            }
        }
        for (i, l) in routeLamps.enumerated() {
            let aimed = i == turntable
            l.lamp.fillColor = aimed ? aim.withAlphaComponent(routeOpen ? 0.85 : 0.45) : SKColor(white: 0.05, alpha: 1)
            l.lamp.strokeColor = i == bridge ? S.exitColor : S.entryColor.withAlphaComponent(0.5)
            l.lamp.lineWidth = i == bridge ? 3 : 1.5
            l.label.fontColor = aimed ? .white : S.entryColor.withAlphaComponent(0.6)
        }
        for exit in NlExit.allCases { cell?.setExitLit(exit, routeOpen && exit.rawValue == turntable) }
    }

    /// Eases the drawn turntable and bridge toward their headings (every game frame, so a pause holds them).
    private func turnRoute(_ dt: CGFloat) {
        let step = Self.turnRate * dt
        func ease(_ shown: inout CGFloat, _ target: CGFloat) -> Bool {
            let d = target - shown
            guard abs(d) > 0.0001 else { return false }
            shown = abs(d) <= step ? target : shown + (d > 0 ? step : -step)
            return true
        }
        let a = ease(&turntableShown, Self.headingAngle[turntable])
        let b = ease(&bridgeShown, Self.headingAngle[bridge])
        if a || b {
            turntablePointer?.zRotation = turntableShown
            bridgeNode?.zRotation = bridgeShown
        }
    }

    // MARK: Labs

    #if DEBUG
    var shotLabMajorEvents: Set<String> { ["ramp", "switchLeft", "switchRight", "rails"] }

    /// Where shots cross the shot line (the ramp mouth and the SWITCH targets, y ~560–610) and the RAILS target's height.
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "shotLine", y: 580), ShotLab.Probe(name: "rails", y: 752)]
    }

    func shotLabReset() {
        newGame()
    }

    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "ramp", text: "Shoot into the ramp's mouth"),
         PlayObjective(name: "switchLeft", text: "Hit SWITCH ◄"),
         PlayObjective(name: "switchRight", text: "Hit SWITCH ►"),
         PlayObjective(name: "rails", text: "Hit RAILS"),
         PlayObjective(name: "exitLeft", text: "Out the left exit (turntable and bridge ◄, then the ramp)"),
         PlayObjective(name: "exitTop", text: "Out the top exit (▲)"),
         PlayObjective(name: "exitRight", text: "Out the right exit (►)"),
         PlayObjective(name: "derail", text: "A ramp shot derails")]
    }

    var playLabShotObjectives: Set<String> {
        ["ramp", "switchLeft", "switchRight", "rails", "exitLeft", "exitTop", "exitRight", "derail"]
    }

    // Shot delays: the middle of each 120 Hz cradle window, shotlab-neon-2026-11-22T19-47-37Z (FAST=8). Inlane bands:
    // shotlab-neon-inlane-2026-11-22T19-50-16Z, 4 pt bins of the ball's distance from the pivot at the flip, 3+ trials.
    let leftShots: [(name: String, delay: Double)] = [("switchLeft", 0.244), ("ramp", 0.471),
                                                       ("switchRight", 0.557), ("rails", 0.621)]
    let rightShots: [(name: String, delay: Double)] = [("switchRight", 0.252), ("ramp", 0.471),
                                                        ("switchLeft", 0.558)]
    let leftInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("ramp", 28, 31), ("switchRight", 36, 39),
                                                                   ("rails", 40, 47)]
    let rightInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("ramp", 28, 31), ("switchLeft", 36, 39)]

    /// The route first: the ramp when it's open, else the target that lines it up soonest; then the targets the cell
    /// still needs for the outlane save; then the ramp and the rest.
    func robotWanted(saveNeeds: [String]) -> [String] {
        var route: [String] = ["ramp"]
        if !routeOpen {
            let switchHits = abs(turntable - bridge)
            let railsHits = (turntable - bridge + 3) % 3
            route = railsHits <= switchHits ? ["rails"] : [turntable > bridge ? "switchLeft" : "switchRight"]
        }
        var out: [String] = []
        for s in route + saveNeeds + ["ramp", "switchLeft", "switchRight", "rails"] where !out.contains(s) {
            out.append(s)
        }
        return out
    }
    #endif
}
