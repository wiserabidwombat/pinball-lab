// Pinball Lab Table 10 (9 to Alive): the LOBBY, the run's first floor. A room on Neon Labyrinth's shared cell engine
// (NlRoom / NlCellFloor / NlColumn), with no copy of the engine. Geometry: NtaLobbyLayout.swift (generated from
// tools/nta_room_lobby.py; checked by nta_lobby_checks.py, nta_lobby_fan.py and nta_lobby_sim.py).
//
// T10 M1 v1 (grey box, placeholder rules until the rules milestone):
//   REVOLVING DOOR — a spinner across a short lane up the left side (the right flipper's shot). Every spin counts toward
//     opening the stairs. A ball that reaches the lane's end rides the kit's left return wire down to the left inlane.
//   STAIRS — the ramp up the middle, the floor's only exit. Shut, a shot in rolls back out ("STAIRS LOCKED"); open,
//     the ball rides up the stairs and out the top, and comes up from below on the floor above.
//   RECEPTION DESK — targets B · A · R. All three: "BARRICADE!" (it will stall the horde once there is a horde).
//   ZOMBIES (T10 M2 v2) — GARY under the revolving door's block and PAM on the right wall below the desk, where the
//     Lobby's Shot Lab found steep cross shots that hit nothing. A hit bonks the zombie: points, a groan, a wobble.
//     (The horde rules will have them block a lane until they're bonked.)
import SpriteKit
import CoreGraphics

/// Table 10 point values (placeholders until the rules milestone).
enum NtaPoints {
    static let spin = 100
    static let doorThrough = 1000
    static let stairsOpen = 5000
    static let upstairs = 5000
    static let barricade = 10000
    static let zombie = 2500
}

@MainActor
final class NtaLobbyRoom: NlRoom {
    typealias Y = NtaLobbyLayout

    // MARK: Tuning (T10 M1 v1)
    /// Spins of the revolving door that open the stairs (proposal: ~15–25 spins per good door shot, so 2–3 shots).
    static let spinsToOpen = 40
    /// A floor ball crossing into the stairs' mouth going up at least this fast is taken up (the Switchyard's ramp rule).
    static let stairsMinSpeed: CGFloat = 400
    static let stairsRideScale: CGFloat = 0.7
    static let stairsRideSpeeds: ClosedRange<CGFloat> = 450...900
    /// "STAIRS LOCKED" at most this often (s), so a ball rattling in the mouth doesn't flood the banner.
    static let lockedBannerGap: CGFloat = 1.5

    private enum Tag {
        static let stairs = 0             // up the stairs → out the top exit
    }

    private weak var cell: NlCellFloor?
    private var spinner: NtaSpinner?
    private var spins = 0
    private var stairsOpen = false
    private var deskHit: Set<String> = []
    private var barricades = 0
    private var bonks = 0
    /// Each zombie's drawn head, and when its wobble (after a bonk) ends.
    private var zombieHeads: [String: SKNode] = [:]
    private var wobbleLeft: [String: CGFloat] = [:]
    private var lockedBannerCooldown: CGFloat = 0
    // Drawn state
    private var stairDoor: SKShapeNode?
    private var stairsPlastic: SKShapeNode?
    private var spinLamps: [SKShapeNode] = []
    private var stairsArrow: SKShapeNode?
    private var deskLamps: [String: SKShapeNode] = [:]
    private var blink: CGFloat = 0
    /// One spinner tick sound per 50 ms at most (Grand Tour's rule).
    private var tickCooldown: CGFloat = 0

    // MARK: NlRoom

    let exits: Set<NlExit> = [.top]
    let solidBlocks: [[CGPoint]] = [Y.doorBlock, Y.deskBlock, Y.zombieWallBlock]
    let targetEvents = ["B": "deskB", "A": "deskA", "R": "deskR", "GARY": "zombieGary", "PAM": "zombiePam"]
    /// How long a bonked zombie wobbles (s), and how far (rad).
    static let wobbleTime: CGFloat = 0.6
    static let wobbleAngle: CGFloat = 0.45

    func build(in cell: NlCellFloor) {
        self.cell = cell
        for pts in [Y.doorBlock, Y.doorInnerWall, Y.deskBlock, Y.zombieWallBlock, Y.stairsU] { cell.addWall(points: pts) }
        for p in Y.stairsMouthPosts { cell.addPost(at: p, radius: Y.stairsPostRadius) }
        cell.addPost(at: Y.doorMouthPost, radius: Y.doorPostRadius)
        for t in Y.deskTargets { cell.addTarget(name: t.name, face: t.face, normal: t.normal) }
        for z in Y.zombies { cell.addTarget(name: z.name, face: z.face, normal: z.normal) }
        addDrawnParts(cell)
        refreshLook()
    }

    func newGame() {
        spins = 0
        stairsOpen = false
        deskHit = []
        barricades = 0
        bonks = 0
        for (name, head) in zombieHeads {
            head.zRotation = 0
            wobbleLeft[name] = nil
        }
        lockedBannerCooldown = 0
        spinner?.stop()                            // a door still turning from the last game (or Shot Lab trial) stops
        refreshLook()
    }

    func update(_ dt: CGFloat) {
        lockedBannerCooldown = max(0, lockedBannerCooldown - dt)
        tickCooldown = max(0, tickCooldown - dt)
        for (name, left) in wobbleLeft {              // a bonked zombie wobbles, then stands back up
            let t = max(0, left - dt)
            wobbleLeft[name] = t > 0 ? t : nil
            let k = t / Self.wobbleTime
            zombieHeads[name]?.zRotation = Self.wobbleAngle * k * sin((1 - k) * 18)
        }
        if let spinner {
            let n = spinner.update(dt: dt)
            if n > 0 { addSpins(n) }
        }
        if !stairsOpen {                           // the spin lamps' next lamp blinks: shoot the door
            blink += dt
            let lit = Self.litLamps(spins)
            if lit < spinLamps.count {
                spinLamps[lit].alpha = 0.45 + 0.55 * abs(sin(blink * 4))
            }
        } else if let arrow = stairsArrow {        // the stairs arrow blinks once they're open
            blink += dt
            arrow.alpha = 0.45 + 0.55 * abs(sin(blink * 4))
        }
    }

    func ballMoved(_ ball: NlBall) {
        guard ball.isOnFloor else { return }
        checkSpinner(ball)
        checkDoorEnd(ball)
        checkStairsEntry(ball)
    }

    func targetHit(_ name: String) -> String {
        if Y.zombies.contains(where: { $0.name == name }) {
            bonks += 1
            if !(cell?.isTilted ?? true) { cell?.score(NtaPoints.zombie) }   // the cell plays the hit sound and haptic
            wobbleLeft[name] = Self.wobbleTime
            return "BONK! \(name)"
        }
        guard Y.deskTargets.contains(where: { $0.name == name }) else { return name }
        deskHit.insert(name)
        if deskHit.count == Y.deskTargets.count {
            deskHit = []
            barricades += 1
            cell?.score(NtaPoints.barricade)
            cell?.sfx(.lanesComplete)
            cell?.haptic(0.9)
            cell?.labEvent("barricade")
            refreshLook()
            return "BARRICADE!"
        }
        refreshLook()
        return Y.deskTargets.map { deskHit.contains($0.name) ? $0.name : "_" }.joined(separator: " · ")
    }

    func rideEnded(_ ball: NlBall, tag: Int) {
        guard let cell, tag == Tag.stairs else { return }
        cell.leave(ball, by: .top)
    }

    func ballLeft(by exit: NlExit) {
        guard let cell else { return }
        if !cell.isTilted { cell.score(NtaPoints.upstairs) }
        cell.showBanner("UPSTAIRS!")
        cell.sfx(.jackpot)
        cell.haptic(1)
    }

    var tagText: String { "T10 M2 v2 · spins \(spins)/\(Self.spinsToOpen)\(stairsOpen ? " · OPEN" : "") · bar \(barricades) · bonk \(bonks)" }

    var status: String? {
        stairsOpen ? "STAIRS OPEN ▲  ·  GO UP!" : "REVOLVING DOOR \(min(spins, Self.spinsToOpen))/\(Self.spinsToOpen)"
    }

    // MARK: The revolving door

    /// A floor ball crossing the spinner's line inside the lane (either way) spins the door.
    private func checkSpinner(_ ball: NlBall) {
        let (a, b) = Y.doorSpinner
        guard Self.crossed(ball.previousPosition, ball.position, a, b), let body = ball.physicsBody else { return }
        let v = body.velocity
        spinner?.kick(ballSpeed: hypot(v.dx, v.dy))
        body.velocity = CGVector(dx: v.dx * NtaSpinner.ballSpeedKept, dy: v.dy * NtaSpinner.ballSpeedKept)
        if v.dx * Y.doorAxis.dx + v.dy * Y.doorAxis.dy > 0 { cell?.labEvent("door") }   // going up the lane
    }

    /// A floor ball crossing the trigger near the lane's end going up rides onto the left return wire to the inlane.
    private func checkDoorEnd(_ ball: NlBall) {
        guard let cell, ball.isOnFloor else { return }
        let (a, b) = Y.doorTrigger
        guard Self.crossed(ball.previousPosition, ball.position, a, b), let v = ball.physicsBody?.velocity,
              v.dx * Y.doorAxis.dx + v.dy * Y.doorAxis.dy > 0 else { return }
        cell.ride(ball, path: [ball.position] + Y.doorRide, speed: NlTableLayout.wireRideSpeed,
                  height: NlTableLayout.wireHeight, release: CGVector(dx: 0, dy: -NlCellLayout.wireReleaseSpeed), event: "doorWire")
        if !cell.isTilted { cell.score(NtaPoints.doorThrough) }
        cell.sfx(.orbit)
    }

    private func addSpins(_ n: Int) {
        guard let cell, !cell.isTilted else { return }     // a tilted table's door counts nothing
        spins += n
        cell.score(NtaPoints.spin * n)
        if tickCooldown == 0 {
            cell.sfx(.spinner)
            tickCooldown = 0.05
        }
        if !stairsOpen && spins >= Self.spinsToOpen {
            stairsOpen = true
            cell.score(NtaPoints.stairsOpen)
            cell.showBanner("STAIRS OPEN!")
            cell.sfx(.lanesComplete)
            cell.haptic(1)
            cell.labEvent("stairsOpen")
        }
        refreshLook()
    }

    // MARK: The stairs

    /// A floor ball crossing into the stairs' mouth going up fast enough: up the stairs if they're open, else locked.
    private func checkStairsEntry(_ ball: NlBall) {
        guard let cell, ball.isOnFloor else { return }
        let p0 = ball.previousPosition, p = ball.position
        let c = NlCellLayout.centerX
        let entryY = Y.stairsMouthY + 12
        guard p0.y < entryY, p.y >= entryY, abs(p.x - c) < Y.stairsMouthPosts[1].x - c,
              let v = ball.physicsBody?.velocity, v.dy >= Self.stairsMinSpeed else { return }
        cell.labEvent("stairs")
        guard stairsOpen else {
            if lockedBannerCooldown == 0 {
                cell.showBanner("STAIRS LOCKED · SPIN THE DOOR")
                cell.sfx(.gate)
                lockedBannerCooldown = Self.lockedBannerGap
            }
            return
        }
        let speed = min(max(hypot(v.dx, v.dy) * Self.stairsRideScale, Self.stairsRideSpeeds.lowerBound),
                        Self.stairsRideSpeeds.upperBound)
        cell.ride(ball, path: [p, CGPoint(x: c, y: Y.stairsUTopY), CGPoint(x: c, y: Y.stairsTopY), Y.stairsExit],
                  speed: speed, height: 0, heightEnd: NlTableLayout.rampTopHeight, release: .zero,
                  end: .room(Tag.stairs))
        cell.sfx(.ramp)
    }

    // MARK: Drawing (grey box)

    private func addDrawnParts(_ cell: NlCellFloor) {
        typealias S = NlTableScene
        // The stairs ramp's plastic above its solid low end, with step lines.
        let ramp = CGMutablePath()
        let left = Y.stairsLeftRail.filter { $0.y >= Y.stairsUTopY }
        let right = Y.stairsRightRail.filter { $0.y >= Y.stairsUTopY }
        ramp.addLines(between: left + right.reversed())
        ramp.closeSubpath()
        var y = Y.stairsUTopY + 24
        while y < Y.stairsTopY - 8 {
            ramp.move(to: CGPoint(x: NlCellLayout.centerX - Y.stairsChannelHalfWidth + 4, y: y))
            ramp.addLine(to: CGPoint(x: NlCellLayout.centerX + Y.stairsChannelHalfWidth - 4, y: y))
            y += 26
        }
        let plastic = SKShapeNode(path: ramp)
        plastic.fillColor = S.wallColor.withAlphaComponent(0.16)
        plastic.strokeColor = S.wallColor.withAlphaComponent(0.5)
        plastic.lineWidth = 1.5
        plastic.zPosition = 15
        cell.addChild(plastic)
        stairsPlastic = plastic
        // The stair door across the U's top (orange while shut, gone when open).
        let door = SKShapeNode(rect: CGRect(x: NlCellLayout.centerX - Y.stairsChannelHalfWidth, y: Y.stairsUTopY - 3,
                                            width: 2 * Y.stairsChannelHalfWidth, height: 7), cornerRadius: 2)
        door.fillColor = SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        door.strokeColor = .clear
        door.zPosition = 15.5
        cell.addChild(door)
        stairDoor = door
        // The revolving door (spinner), and the ride's link from the lane's end to the return wire.
        let (a, b) = Y.doorSpinner
        let s = NtaSpinner(from: a, to: b)
        s.zPosition = 6
        cell.addChild(s)
        spinner = s
        let link = CGMutablePath()
        link.addLines(between: Array(Y.doorRide.prefix(3)))
        let linkNode = SKShapeNode(path: link)
        linkNode.strokeColor = S.wireColor
        linkNode.lineWidth = 1.6
        linkNode.zPosition = 16
        cell.addChild(linkNode)
        // Spin lamps: 8 lamps up the open lower table's left side, one per 5 spins.
        for i in 0..<8 {
            let lamp = SKShapeNode(circleOfRadius: 8)
            lamp.position = CGPoint(x: 205 + CGFloat(i) * 8, y: 470 + CGFloat(i) * 22)
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            cell.addChild(lamp)
            spinLamps.append(lamp)
        }
        // The stairs arrow in front of the mouth.
        let arrow = CGMutablePath()
        let c = NlCellLayout.centerX
        arrow.addLines(between: [CGPoint(x: c - 20, y: 500), CGPoint(x: c, y: 540), CGPoint(x: c + 20, y: 500)])
        arrow.closeSubpath()
        let arrowNode = SKShapeNode(path: arrow)
        arrowNode.lineWidth = 2
        arrowNode.zPosition = -18
        cell.addChild(arrowNode)
        stairsArrow = arrowNode
        // The zombies (grey box): a green head behind each face, tilted by the wobble after a bonk.
        for z in Y.zombies {
            let head = SKShapeNode(circleOfRadius: 13)
            head.position = CGPoint(x: z.center.x - z.normal.dx * 42, y: z.center.y - z.normal.dy * 42)   // behind the name label
            head.fillColor = SKColor(red: 0.65, green: 0.79, blue: 0.34, alpha: 1)
            head.strokeColor = SKColor(red: 0.17, green: 0.13, blue: 0.20, alpha: 1)
            head.lineWidth = 2.5
            head.zPosition = 3
            for (dx, r) in [(CGFloat(-5), CGFloat(3.5)), (5, 2.5)] {       // goofy mismatched eyes
                let eye = SKShapeNode(circleOfRadius: r)
                eye.position = CGPoint(x: dx, y: 3)
                eye.fillColor = .white
                eye.strokeColor = .clear
                head.addChild(eye)
            }
            cell.addChild(head)
            zombieHeads[z.name] = head
        }
        // Desk lamps: one under each target, lit when hit.
        for t in Y.deskTargets {
            let lamp = SKShapeNode(circleOfRadius: 7)
            lamp.position = CGPoint(x: t.center.x + t.normal.dx * 26, y: t.center.y + t.normal.dy * 26)
            lamp.lineWidth = 1.5
            lamp.zPosition = -18
            cell.addChild(lamp)
            deskLamps[t.name] = lamp
        }
    }

    /// Lamps lit for this many spins (one per 5, up to 8).
    private static func litLamps(_ spins: Int) -> Int { min(spins / max(spinsToOpen / 8, 1), 8) }

    private func refreshLook() {
        typealias S = NlTableScene
        let lit = Self.litLamps(spins)
        let gold = SKColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1)
        for (i, lamp) in spinLamps.enumerated() {
            let on = stairsOpen || i < lit
            lamp.fillColor = on ? gold : SKColor(white: 0.06, alpha: 1)
            lamp.strokeColor = on ? .white : gold.withAlphaComponent(0.5)
            lamp.alpha = 1
        }
        stairDoor?.isHidden = stairsOpen
        let green = SKColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1)
        stairsArrow?.fillColor = stairsOpen ? green.withAlphaComponent(0.7) : SKColor(white: 0.06, alpha: 1)
        stairsArrow?.strokeColor = stairsOpen ? .white : green.withAlphaComponent(0.4)
        if !stairsOpen { stairsArrow?.alpha = 1 }
        stairsPlastic?.strokeColor = stairsOpen ? green : S.wallColor.withAlphaComponent(0.5)
        let red = SKColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1)
        for (name, lamp) in deskLamps {
            let on = deskHit.contains(name)
            lamp.fillColor = on ? red : SKColor(white: 0.06, alpha: 1)
            lamp.strokeColor = on ? .white : red.withAlphaComponent(0.5)
        }
        cell?.setExitLit(.top, stairsOpen)
    }

    /// Whether the move p0 → p crossed segment a–b.
    private static func crossed(_ p0: CGPoint, _ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Bool {
        func side(_ q: CGPoint) -> CGFloat { (b.x - a.x) * (q.y - a.y) - (b.y - a.y) * (q.x - a.x) }
        let s0 = side(p0), s1 = side(p)
        guard (s0 < 0) != (s1 < 0) else { return false }
        // where along a–b the move crossed
        let d = CGVector(dx: p.x - p0.x, dy: p.y - p0.y), e = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let den = d.dx * e.dy - d.dy * e.dx
        guard abs(den) > 1e-9 else { return false }
        let t = ((a.x - p0.x) * d.dy - (a.y - p0.y) * d.dx) / den
        return t >= -0.05 && t <= 1.05
    }

    // MARK: Labs

    #if DEBUG
    var shotLabMajorEvents: Set<String> { ["stairs", "door", "deskB", "deskA", "deskR", "zombieGary", "zombiePam"] }

    /// The shot line (the stairs' mouth, y 580) and the door's and desk's height (~800).
    var shotLabProbes: [ShotLab.Probe] {
        [ShotLab.Probe(name: "shotLine", y: 590), ShotLab.Probe(name: "doorDesk", y: 800)]
    }

    func shotLabReset() {
        newGame()
    }

    var playLabObjectives: [PlayObjective] {
        [PlayObjective(name: "door", text: "Shoot through the revolving door"),
         PlayObjective(name: "doorWire", text: "Through the door to the wire"),
         PlayObjective(name: "stairsOpen", text: "Open the stairs (\(Self.spinsToOpen) spins)"),
         PlayObjective(name: "stairs", text: "Shoot into the stairs' mouth"),
         PlayObjective(name: "exitTop", text: "Up the stairs and out the top"),
         PlayObjective(name: "deskB", text: "Hit B"),
         PlayObjective(name: "deskA", text: "Hit A"),
         PlayObjective(name: "deskR", text: "Hit R"),
         PlayObjective(name: "barricade", text: "B · A · R: a barricade"),
         PlayObjective(name: "zombieGary", text: "Bonk GARY (the right flipper's steep cross shot)"),
         PlayObjective(name: "zombiePam", text: "Bonk PAM (the left flipper's steep cross shot)")]
    }

    var playLabShotObjectives: Set<String> {
        ["door", "doorWire", "stairsOpen", "stairs", "exitTop", "deskB", "deskA", "deskR", "barricade", "zombieGary",
         "zombiePam"]
    }

    // T10 M2 v1: the Lobby's own Shot Lab (120 Hz, FAST=8). Cradle: shotlab-alive-2026-11-23T14-00-48Z, the middle of each
    // window (single-trial flukes left out). Inlane: shotlab-alive-inlane-2026-11-23T14-04-16Z, 4 pt bins of the ball's
    // distance from the pivot at the flip, 3+ hits.
    // The zombies (T10 M2 v2): the cradle delays whose measured launches the layout sims send into each zombie (PAM
    // 61–64°, GARY 111–116°), until the next Shot Lab run measures them.
    let leftShots: [(name: String, delay: Double)] = [("door", 0.221), ("stairs", 0.467), ("deskB", 0.562),
                                                       ("deskA", 0.583), ("deskR", 0.600), ("zombiePam", 0.620)]
    let rightShots: [(name: String, delay: Double)] = [("stairs", 0.468), ("door", 0.557), ("zombieGary", 0.600)]
    let leftInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("stairs", 28, 31), ("deskB", 68, 71)]
    let rightInlane: [(name: String, lo: CGFloat, hi: CGFloat)] = [("stairs", 28, 31), ("door", 36, 39)]

    /// The door until the stairs open, then the stairs; then the desk targets still needed for the outlane save.
    func robotWanted(saveNeeds: [String]) -> [String] {
        var out: [String] = stairsOpen ? ["stairs"] : ["door"]
        for s in saveNeeds + ["deskB", "deskA", "deskR", "zombieGary", "zombiePam", "door", "stairs"] where !out.contains(s) {
            out.append(s)
        }
        return out
    }
    #endif
}
