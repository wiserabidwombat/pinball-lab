// Pinball Lab Table 08 (Neon Labyrinth): the table scene. Milestone 1 v1 = one cell standing on its own, in grey box:
// the shared cell kit (walls with bulges, outlanes, lane guides, inlanes, slings, CHOMP!'s real-scale flippers and
// flipper model, the centre drain) and the Switchyard room's floor parts (the ramp's solid low end, the SWITCH and
// RAILS targets on their blocks, the turntable's base, the top lane). The ramp's raised part, the turntable, the
// light-rail ring and the rails are drawn only; they work from the next round.
//
// Every way into a cell is here, so they can be played before the maze exists. With no grid yet a drain costs
// nothing: the ball comes back in by the next way in, in turn —
//   FROM BELOW  : rises up through the drain chute and the flipper gap, then pops onto a flipper (sides alternate);
//   FROM ABOVE  : falls in through the top port onto a return wire, rides it round to an inlane (sides alternate);
//   FROM LEFT / FROM RIGHT : through a side entry portal onto that side's return wire, down to its inlane.
// Geometry: NlCellLayout.swift (the kit, generated from tools/nl_kit.py; checked by nl_checks.py / nl_sim.py).
// M2 v1: the Switchyard works. A ramp shot rides up onto the turntable; SWITCH ◄ / ► turn the turntable (W N E,
// stepping), RAILS steps the light-rail ring's bridge (W → N → E → W). Lined up, the turntable fires the ball down that
// light-rail and out through the exit portal; not lined up, the ball derails to the floor. With no maze yet, a ball
// out of an exit comes straight back in as the cell next door would get it (out the left → in from the right, out the
// top → in from below), costing nothing.
// M2 round A: the scene is the shared CELL; the Switchyard is a room (NlRoom / NlSwitchyardRoom.swift) that adds its own
// parts, targets, drawn parts and exit puzzle. The cell draws only the room's exits (and those sides' entry portals),
// brings in only arrivals through open sides, and calls the room each frame, per ball, per target hit and at ride ends.
// M2 round B: the scene is a COLUMN of cells. Each floor (NlCellFloor) is a cell with its own kit, flippers and room,
// stacked up the world; the ball is a child of its floor, so a cell's logic stays in cell coordinates. A drain drops the
// ball one floor (it comes in FROM ABOVE on the floor below); out the top exit it climbs one floor (FROM BELOW on the
// floor above). The table's column (NlColumn) says which room is on each floor and when a drain costs a ball (Neon: a
// drain on the bottom floor). The camera pans to the ball's floor. Side exits still come back in on the same floor
// (no columns beside it yet), as does the top exit of the top floor.
// T8 M4 v1: the GRID. A column can be several cells wide (`width`; rooms row by row from the bottom-left), laid out
// across and up the world. Out a side exit the ball goes to the cell beside (FROM THE RIGHT / FROM THE LEFT there), out
// the top to the cell above; a drain drops it to the cell below in the same column. Maze walls (`isWalled`) close a
// cell's exits: a walled exit is drawn as a solid orange wall, never opens, and has no entry portal on that side. With
// no cell beside or above and no wall, the ball still comes back in on the same cell (9 to Alive's width-1 column).
// M1 v2: the Shot Lab and Play Lab hosts (CHOMP!'s pattern; `-shotlab neon`, `-playlab neon`). In the Play Lab the cell
// plays as a bottom-row cell: a drain costs a ball (the next ball still comes in by the next way in).
import SpriteKit
import UIKit
import CoreGraphics
import Foundation

/// T8 M2 round B: a table's column of cells — the room on each floor (bottom first), and the table's rule for when a drain
/// costs a ball. Other tables (9 to Alive) give their own.
@MainActor
struct NlColumn {
    /// Makes the rooms, bottom floor first (one per floor).
    let makeRooms: () -> [NlRoom]
    /// Whether a drain on this floor costs a ball (otherwise it drops the ball to the floor below).
    let drainCostsBall: (_ floor: Int) -> Bool
    /// The space between floors in the world (the camera pans across it).
    var floorGap: CGFloat = 120
    /// T8 M3 v1: the neon look (Neon Labyrinth's; NlNeon.swift). Off = the grey box (9 to Alive draws its own).
    var neon = false
    /// T8 M2 round D (for 9 to Alive): the table's name in the labs' reports and file names
    /// (shotlab-<name>-…, playlab-<name>-…). Neon's is "Neon".
    var labName = "Neon"
    /// T8 M4 v1: how many cells across (1 = a column). `makeRooms` gives width × rows rooms, row by row from the
    /// bottom-left; `drainCostsBall` gets the row.
    var width = 1
    /// T8 M4 v1: whether a maze wall closes this cell's exit (cell index, row by row from the bottom-left).
    var isWalled: (_ cell: Int, _ exit: NlExit) -> Bool = { _, _ in false }
    /// T10 M3 v1 (for 9 to Alive): a drain cost a ball on this cell; returns the cell the next ball comes up on (from
    /// below). Neon's: the bottom-left cell, as before.
    var ballLost: (_ cell: Int) -> Int = { _ in 0 }
    /// T10 M3 v1 (for 9 to Alive's horde): every game frame while a game is on, with the ball's cell; returns a banner
    /// to show, or nil. Neon has none.
    var tick: ((_ dt: CGFloat, _ ballCell: Int) -> String?)?
    /// T8 M4 v3: moving between cells pulls the camera back to the whole grid, then dives into the next cell
    /// (Neon's; off = the plain pan, as 9 to Alive has).
    var cellTransition = false

    /// T8 M4 v1: a cell's name on the grid (column letter, row number from the bottom: A1 is the bottom-left).
    func cellName(_ i: Int) -> String {
        let col = i % width, row = i / width
        return "\(Character(UnicodeScalar(UInt8(65 + col))))\(row + 1)"
    }

    /// Neon Labyrinth's test maze (T8 M4 v1): 3 × 3 Switchyards. The ball starts in A1; the way through is
    /// A1 → B1 → up to B2 → A2 → up to A3 → B3 → C3. C1 and C2 are dead ends (C2's top is walled; C1 is reached only by
    /// draining from C2). The grid's edges are walls. A drain on the bottom row costs a ball.
    static func neonTest() -> NlColumn {
        let w = 3
        // Open passages: (cell, exit). Everything else is walled; a side passage opens both cells' facing exits.
        let open: Set<[Int]> = [[0, NlExit.right.rawValue],        // A1 → B1
                                [1, NlExit.top.rawValue],          // B1 ↑ B2
                                [2, NlExit.top.rawValue],          // C1 ↑ C2
                                [3, NlExit.right.rawValue],        // A2 → B2
                                [4, NlExit.right.rawValue],        // B2 → C2
                                [3, NlExit.top.rawValue],          // A2 ↑ A3
                                [6, NlExit.right.rawValue],        // A3 → B3
                                [7, NlExit.right.rawValue]]        // B3 → C3
        var column = NlColumn(makeRooms: { (0..<9).map { _ in NlSwitchyardRoom() } },
                              drainCostsBall: { $0 == 0 })
        column.neon = true
        column.cellTransition = true
        column.width = w
        column.isWalled = { cell, exit in
            switch exit {
            case .top, .right: return !open.contains([cell, exit.rawValue])
            case .left: return cell % w == 0 || !open.contains([cell - 1, NlExit.right.rawValue])
            }
        }
        return column
    }
}

final class NlTableScene: SKScene, RendererHostedScene {
    private enum Control { case left, right }

    /// The ways a ball comes into a cell (the drain cycles through them in M1).
    enum Arrival: CaseIterable {
        case fromBelow, fromAbove, fromLeft, fromRight
        var banner: String {
            switch self {
            case .fromBelow: return "FROM BELOW"
            case .fromAbove: return "FROM ABOVE"
            case .fromLeft: return "FROM THE LEFT"
            case .fromRight: return "FROM THE RIGHT"
            }
        }
    }

    /// A ball being moved along a path by the scene (collisions and gravity off), then let go with a set velocity.
    private struct Ride {
        let ball: NlBall
        let path: [CGPoint]
        let cumulative: [CGFloat]
        var s: CGFloat = 0
        let speed: CGFloat
        let height: CGFloat
        let release: CGVector
        /// The lab event when the ride lets go (which arrival it was).
        var event: String? = nil
        /// M2 v1: the height at the end of the path (the height eases from `height` to this along the path).
        var heightEnd: CGFloat? = nil
        /// M2 v1: what happens at the end of the path.
        var end: NlRideEnd = .release
        /// M2 v1: seconds to wait at the end of the path before it ends.
        var hold: CGFloat = 0
        var total: CGFloat { cumulative.last ?? 0 }
    }

    private let game: NlGameState
    private let settings: GameSettings
    private let cameraRig = NlCameraRig()
    private let sound = MonSoundPlayer()
    /// The touch surface when the SKRenderer host draws the scene (devices); `view` is nil then.
    weak var hostView: UIView?
    private var buildTag: SKLabelNode?
    private var buildTagBack: SKShapeNode?
    private var buildTagAt: TimeInterval = 0
    private var fpsWindowStart: CFTimeInterval = 0
    private var fpsLastFrame: CFTimeInterval = 0
    private var fpsFrames = 0
    private var fpsWorstGap: CFTimeInterval = 0
    private var fpsShown = 0
    private var fpsWorstShown = 0
    private var fpsLow = 0
    /// T8 M4 v2: the game's worst frame so far, and where it happened (cell, game second, and "pan" if the camera was
    /// moving between cells), so a stutter can be traced from the build tag.
    private var fpsWorstEver = 0
    private var fpsWorstWhere = ""
    private var lastCameraOrigin = CGPoint.zero
    private var panUntil: TimeInterval = 0
    /// T8 M4 v3: the tracer ignores the first 2 s of a game (the build and first draw of every cell).
    private var tracerFrom: TimeInterval = 0
    /// T8 M4 v4: the last thing that happened (its sound, flippers aside) and when, so the worst frame can name it.
    private var lastHappening = ""
    private var lastHappeningAt: TimeInterval = -10
    /// T8 M4 v5: every frame slower than 25 ms (after the first 2 s), counted by what happened just before it.
    private var slowFrames: [String: Int] = [:]
    /// T8 M4 v5: the sling sparks, made once and reused round-robin (a new emitter per hit was the likely cause of
    /// Aaron's 33-34 ms frames "after s…" in A1).
    private var sparkPool: [SKEmitterNode] = []
    private var nextSpark = 0
    /// T8 M4 v3: the transition's marks on the grid: where the ball was (white) and where it's going (magenta).
    private var moveMarks: [SKShapeNode] = []
    #if DEBUG
    /// T8 M4 v3: `-nlFlyTest` flies the camera to the next cell every 3 s (no ball moves), to check the transition.
    /// Test only: it moves the camera off the ball's cell and can hide it, so don't play with it on.
    private lazy var flyTest = ProcessInfo.processInfo.arguments.contains("-nlFlyTest")
    private var flyTestCell = 0
    private var flyTestNext: TimeInterval = 3
    #endif
    private var lastStep: CGFloat = 0
    /// T8 M4 v3: every frame's step, set before the Shot Lab and menu returns (the camera's clock).
    private var frameStep: CGFloat = 0
    /// The camera's step: the Shot Lab's own, else every frame's.
    private var cameraStep: CGFloat {
        #if DEBUG
        if shotLab != nil { return lastStep }
        #endif
        return frameStep
    }

    private var balls: [NlBall] = []
    private var rides: [Ride] = []
    private var isBuilt = false
    // M2 round B: the column — its floors (bottom first) and the floor the ball is on.
    private let column: NlColumn
    private var floors: [NlCellFloor] = []
    private var activeFloor = 0
    /// The floor the ball is on (the one input and the camera follow).
    private var floor: NlCellFloor! { floors.isEmpty ? nil : floors[activeFloor] }
    /// The ball's floor's flippers (the only ones input drives).
    private var leftFlipper: NlFlipper! { floor?.leftFlipper }
    private var rightFlipper: NlFlipper! { floor?.rightFlipper }
    /// The ball's floor's room.
    private var room: NlRoom! { floor?.room }
    private let hitHaptic = Haptic(style: .medium)

    // The targets' short cooldown each (the targets themselves and their flashes are each floor's).
    private var targetLastHit: [String: TimeInterval] = [:]

    // Which side the alternating arrivals use next.
    private var nextBelowLeft = true
    private var nextAboveLeft = true
    private var drains = 0
    /// Drains that dropped the ball to the floor below (not counted in `drains`, which are balls lost).
    private var floorDrops = 0
    // The outlane saves (M1 v4) are each floor's own since M2 round C: NlCellFloor.kickbackLit / saveLit.
    #if DEBUG
    /// The lab events that count as Play Lab objectives: the room's and the cell's (built once).
    fileprivate lazy var cachedShotObjectives: Set<String> =
        room.playLabShotObjectives.union(["fromBelow", "fromAbove", "fromLeft", "fromRight",
                                          "kickback", "saveLit", "outlaneSave", "floorDown", "floorUp"])
            .union(column.width > 1 ? ["cellLeft", "cellRight"] : [])
    #endif
    /// The next ball in: how it arrives and on which floor (set by a drain or an exit; a new ball is FROM BELOW on the
    /// bottom floor).
    private var pendingArrival: (arrival: Arrival, floor: Int)?
    /// T10 M3 v1: where a new ball comes up (from below) when there's no pending arrival: the column's choice after a
    /// lost ball (NlColumn.ballLost), the bottom-left cell at a new game.
    private var newBallCell = 0

    #if DEBUG
    /// M1 v2: the Shot Lab robot (shared ShotLab) and its own clock.
    fileprivate var shotLab: ShotLab?
    fileprivate var shotLabTime: TimeInterval = 0
    /// M1 v2: the Play Lab (shared PlayLab): the run, when its next game starts.
    private var playLab: PlayLab?
    private var playLabNextAt: TimeInterval?
    private var playLabStarting = false
    /// The Play Lab's watchdog: where each ball was last seen moving, and when.
    private var watchSpots: [ObjectIdentifier: (CGPoint, TimeInterval)] = [:]
    #endif
    /// The Play Lab robot's buttons (always false outside it).
    private var robotLeft = false
    private var robotRight = false

    // Input
    private var activeTouches: [UITouch: Control] = [:]
    private let nudge = Nudge()
    private var padLeft = false
    private var padRight = false

    // Game clock: advances by the clamped frame time only, so pauses and hitches never eat timers.
    private var lastRealTime: TimeInterval?
    private var gameTime: TimeInterval = 0
    private var nextBallAt: TimeInterval?
    private var bannerClearAt: TimeInterval?

    /// The menu: physics stopped, touches ignored.
    var isAttractMode = false {
        didSet {
            guard isAttractMode != oldValue else { return }
            physicsWorld.speed = isAttractMode ? 0 : 1
            if isAttractMode { releaseAllControls() }
            #if DEBUG
            if isAttractMode { shotLab = nil }                  // Menu stops the Shot Lab
            if isAttractMode { stopPlayLab(saving: true) }      // and the Play Lab (saving the games so far)
            #endif
            refreshCamera()
        }
    }

    var isGamePaused = false {
        didSet {
            if isGamePaused { releaseNonTouchControls() }
            isPaused = isGamePaused
            lastRealTime = nil
        }
    }

    override var isPaused: Bool {
        didSet {
            if isGamePaused && !isPaused { isPaused = true }
        }
    }

    // Grey-box colours (the skill's): green walls on near-black, orange for anything that kicks or is one-way,
    // silver for wires and rails. The neon look replaces these in the art milestone.
    static let wallColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
    static let floorColor = SKColor(red: 0.03, green: 0.05, blue: 0.07, alpha: 1)
    static let wireColor = SKColor(white: 0.78, alpha: 0.75)
    static let entryColor = SKColor(red: 0.25, green: 0.80, blue: 1.0, alpha: 1)
    static let exitColor = SKColor(red: 1.0, green: 0.30, blue: 0.85, alpha: 1)
    static let targetColor = SKColor(red: 1.0, green: 0.90, blue: 0.50, alpha: 1)
    static let buildTagText = "T8 M4 v6"

    /// `column`: the table's column of cells (nil = Neon's test column).
    init(game: NlGameState, settings: GameSettings, column: NlColumn? = nil) {
        self.game = game
        self.settings = settings
        self.column = column ?? NlColumn.neonTest()
        super.init(size: NlTableLayout.worldSize)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = CGVector(dx: 0, dy: NlTableLayout.gravity)
        physicsWorld.contactDelegate = self
        cameraRig.install(in: self)
        buildTable()
        addBuildTag()
        refreshCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        refreshCamera()
    }

    /// A cell is one screen: always the whole cell (Top-Down).
    private var effectiveCameraMode: CameraMode { .topDown }

    func refreshCamera() {
        guard isBuilt else { return }
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: 0, snap: true)
        endCellTransition()                        // a snap ends any transition (even while paused)
        placeBuildTag()
    }

    /// T8 M4 v3: the transition's marks go and every cell draws in full again.
    private func endCellTransition() {
        guard !moveMarks.isEmpty || floors.contains(where: { $0.inOverview }) else { return }
        moveMarks.forEach { $0.removeFromParent() }
        moveMarks = []
        floors.forEach { $0.setOverview(false) }
    }

    // MARK: - Table

    /// Builds the column: one floor per room, bottom first, stacked up the world with a gap between floors.
    private func buildTable() {
        hitHaptic.prepare()
        for (i, room) in column.makeRooms().enumerated() {
            let f = NlCellFloor(index: i, room: room, column: self, neon: column.neon)
            let col = i % column.width, row = i / column.width
            f.position = CGPoint(x: CGFloat(col) * (NlCellLayout.cellSize.width + column.floorGap),
                                 y: CGFloat(row) * (NlCellLayout.cellSize.height + column.floorGap))
            floors.append(f)
        }
        // T8 M4 v1: the maze's walls (from either side), and a side whose cell beside has no way in on that side, close
        // the exit.
        assert(floors.count % column.width == 0, "NlColumn: the rooms must fill whole rows")
        for f in floors {
            let col = f.index % column.width
            f.walled = Set(NlExit.allCases.filter { exit in
                guard f.room.exits.contains(exit) else { return false }
                if column.isWalled(f.index, exit) { return true }
                switch exit {
                case .left: return col > 0 && (!floors[f.index - 1].room.exits.contains(.right)
                                               || column.isWalled(f.index - 1, .right))
                case .right: return col + 1 < column.width && f.index + 1 < floors.count
                    && (!floors[f.index + 1].room.exits.contains(.left) || column.isWalled(f.index + 1, .left))
                case .top: return false
                }
            })
            addChild(f)
            f.build()
        }
        refreshKickLamps()
        // T8 M4 v2: every cell's baked glow goes to the GPU now, not the first time its cell comes on screen
        // (Aaron's 9-cell test: worst frame 34 ms, low 101 fps).
        let halos = floors.flatMap { f in ["neonHalos", "neonCores"].compactMap { (f.childNode(withName: $0) as? SKSpriteNode)?.texture } }
        if !halos.isEmpty { SKTexture.preload(halos) {} }
        makeSparkPool()
    }

    // MARK: - Sling sparks (T8 M4 v5)

    /// Four emitters set up like Effects.burst(count 8, speed 160, lifetime 0.25, size 0.22), idle until a hit. One
    /// fires now, under the first cell's floor (hidden, inside the ignored first 2 s), so the first real hit draws warm.
    private func makeSparkPool() {
        let spark = SKTexture(imageNamed: "orbit_star")
        let lifetime: CGFloat = 0.25, size: CGFloat = 0.22, speed: CGFloat = 160
        for _ in 0..<4 {
            let e = SKEmitterNode()
            e.particleTexture = spark
            e.zPosition = 20
            e.particleBirthRate = 0
            e.particleLifetime = lifetime
            e.particleLifetimeRange = lifetime * 0.4
            e.particleSpeed = speed
            e.particleSpeedRange = speed * 0.6
            e.emissionAngleRange = .pi * 2
            e.particleScale = size
            e.particleScaleRange = size * 0.5
            e.particleScaleSpeed = -size / lifetime
            e.particleAlpha = 1
            e.particleAlphaSpeed = -1 / lifetime
            e.particleColorBlendFactor = 1
            e.particleBlendMode = .add
            sparkPool.append(e)
        }
        guard let first = floors.first else { return }
        sparkBurst(in: first, at: CGPoint(x: NlCellLayout.centerX, y: 500), color: NlNeon.cyan)
        sparkPool[0].zPosition = -25                       // under the floor's fill
    }

    /// Fires the next pooled emitter: 8 sparks at `point` in `parent` (moved there if it was elsewhere).
    private func sparkBurst(in parent: SKNode, at point: CGPoint, color: SKColor) {
        guard !sparkPool.isEmpty else { return }
        let e = sparkPool[nextSpark]
        nextSpark = (nextSpark + 1) % sparkPool.count
        if e.parent !== parent {
            e.removeFromParent()
            parent.addChild(e)
        }
        e.zPosition = 20
        e.position = point
        e.particleColor = color
        e.numParticlesToEmit = 8
        e.particleBirthRate = 8 * 40                       // all out in ~1/40 s
        e.resetSimulation()
    }

    // MARK: - Services for the room (M2 round A)

    /// Whether the table is tilted (dead flippers until the next ball).
    var isTilted: Bool { nudge.tilted }

    /// Points for the room (the multiplier applies).
    func score(_ points: Int) {
        game.add(points)
    }

    func haptic(_ intensity: CGFloat) {
        hitHaptic.impactOccurred(intensity: intensity)
    }

    /// The ball has gone out through `exit` of `from`: it's removed, and comes in where that exit leads. Out the top it
    /// climbs to the floor above (FROM BELOW there); the top floor's top exit and the side exits have nowhere to go yet,
    /// so the ball comes back in on the same floor as the cell next door would get it (out the left → in from the right,
    /// out the top → in from below). Costs nothing.
    func leave(_ ball: NlBall, by exit: NlExit, from: NlCellFloor) {
        removeBall(ball)
        from.room.ballLeft(by: exit)
        labEvent(exit.labEvent)
        // T8 M4 v1: to the cell that exit leads to (above, or beside), if there is one.
        let w = column.width, col = from.index % w
        var next: (arrival: Arrival, cell: Int, event: String)?
        switch exit {
        case .top where from.index + w < floors.count: next = (.fromBelow, from.index + w, "floorUp")
        case .left where col > 0: next = (.fromRight, from.index - 1, "cellLeft")
        case .right where col + 1 < w && from.index + 1 < floors.count: next = (.fromLeft, from.index + 1, "cellRight")
        default: break
        }
        if let next {
            pendingArrival = (next.arrival, next.cell)
            let delay = moveCamera(to: next.cell, from: from.index)    // the pan (or the transition) starts now
            labEvent(next.event)
            if balls.isEmpty, nextBallAt == nil { nextBallAt = gameTime + delay }
            return
        }
        let back: Arrival = [Arrival.fromRight, .fromBelow, .fromLeft][exit.rawValue]
        pendingArrival = (availableArrivals(on: from).contains(back) ? back : .fromBelow, from.index)
        if balls.isEmpty, nextBallAt == nil { nextBallAt = gameTime + 0.8 }
    }

    /// From a drain or a top exit to the next floor's arrival (the camera pans meanwhile).
    static let floorMoveDelay: TimeInterval = 0.3

    /// T8 M4 v3: points the camera at cell `to`. With the cell transition it pulls back to the whole grid (the cell the
    /// ball left outlined white, the one it's going to magenta), holds, and dives in. Returns how long until the ball
    /// comes in (it arrives as the dive settles).
    private func moveCamera(to cell: Int, from: Int) -> TimeInterval {
        cameraRig.origin = floors[cell].position
        guard column.cellTransition else { return Self.floorMoveDelay }
        let cols = column.width, rows = floors.count / column.width
        let cw = NlCellLayout.cellSize.width, ch = NlCellLayout.cellSize.height, gap = column.floorGap
        let grid = CGRect(x: 0, y: 0, width: CGFloat(cols) * cw + CGFloat(cols - 1) * gap,
                          height: CGFloat(rows) * ch + CGFloat(rows - 1) * gap)
            .insetBy(dx: -70, dy: -70)                     // room for the marks round the edge cells
        cameraRig.flyVia(gridBounds: grid, viewSize: size)
        guard cameraRig.isFlying else { return Self.floorMoveDelay }    // Reduce Motion: the plain pan
        // Every cell but the two the move is between draws as its baked stand-in while the camera is out.
        for f in floors { f.setOverview(f.index != cell && f.index != from) }
        moveMarks.forEach { $0.removeFromParent() }
        moveMarks = []
        let px = cameraRig.overviewScale                    // world points per screen point at the grid framing
        for (i, color) in [(from, NlNeon.white), (cell, NlNeon.magenta)] {
            let rect = CGRect(origin: floors[i].position, size: NlCellLayout.cellSize).insetBy(dx: -8 * px, dy: -8 * px)
            let mark = SKShapeNode(rect: rect, cornerRadius: 6 * px)
            mark.fillColor = color.withAlphaComponent(i == cell ? 0.10 : 0.04)
            NlNeon.core(mark, color, width: (i == cell ? 3 : 2) * px)
            NlNeon.addHalo(to: mark, color, width: 12 * px, alpha: 0.35)
            mark.zPosition = 40
            mark.alpha = 0
            addChild(mark)
            moveMarks.append(mark)
        }
        return TimeInterval(NlCameraRig.flightTotal - 0.2)
    }

    /// The arrivals that can happen on a floor: below and above always, a side only if its room has that side.
    private func availableArrivals(on f: NlCellFloor) -> [Arrival] {
        Arrival.allCases.filter { a in
            switch a {
            case .fromLeft: return f.room.exits.contains(.left) && !f.walled.contains(.left)
            case .fromRight: return f.room.exits.contains(.right) && !f.walled.contains(.right)
            default: return true
            }
        }
    }


    // MARK: - Build tag (debug builds)

    private func addBuildTag() {
        #if DEBUG
        let label = SKLabelNode(text: Self.buildTagText)
        label.fontName = "Menlo-Bold"
        label.fontSize = 12
        label.fontColor = SKColor(white: 1, alpha: 0.85)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        label.numberOfLines = 0
        label.zPosition = 50
        cameraRig.node.addChild(label)
        let back = SKShapeNode()
        back.fillColor = SKColor(white: 0, alpha: 0.6)
        back.strokeColor = .clear
        back.zPosition = 49
        cameraRig.node.addChild(back)
        buildTagBack = back
        buildTag = label
        #endif
    }

    /// T8 M4 v5: "\nslow: sling 3 · standup 1 · - 2" (frames over 25 ms by the event before them), or "".
    private var slowText: String {
        guard !slowFrames.isEmpty else { return "" }
        let parts = slowFrames.sorted { $0.value > $1.value }.prefix(4).map { "\($0.key) \($0.value)" }
        return "\nslow: " + parts.joined(separator: " · ")
    }

    /// Camera children use screen points, centred on the screen. Text changes at most 4 times a second.
    private func placeBuildTag() {
        guard let buildTag else { return }
        buildTag.position = CGPoint(x: -size.width / 2 + 10, y: -size.height / 2 + 10)
        let t = CACurrentMediaTime()
        let gap = t - fpsLastFrame
        fpsLastFrame = t
        if gap > 0.5 {
            fpsWindowStart = t; fpsFrames = 0; fpsWorstGap = 0
        } else {
            fpsFrames += 1
            fpsWorstGap = max(fpsWorstGap, gap)
            if gap > 0.025, gameTime >= tracerFrom {
                let key = gameTime - lastHappeningAt < 0.7 ? lastHappening : "-"
                slowFrames[key, default: 0] += 1
            }
            let window = t - fpsWindowStart
            if window >= 0.5 {
                fpsShown = Int((Double(fpsFrames) / window).rounded())
                fpsWorstShown = Int((fpsWorstGap * 1000).rounded())
                if gameTime >= tracerFrom, fpsLow == 0 || fpsShown < fpsLow { fpsLow = fpsShown }
                if fpsWorstShown > fpsWorstEver, gameTime >= tracerFrom {
                    fpsWorstEver = fpsWorstShown
                    let cell = column.width > 1 ? column.cellName(activeFloor) : "floor \(activeFloor + 1)"
                    let ago = gameTime - lastHappeningAt          // within this 0.5 s window (+ a little)
                    let what = ago < 0.7 ? " after \(lastHappening)" : ""
                    fpsWorstWhere = "\(cell) \(Int(gameTime))s\(gameTime < panUntil ? " pan" : "")\(what)"
                }
                fpsWindowStart = t; fpsFrames = 0; fpsWorstGap = 0
            }
        }
        guard gameTime - buildTagAt >= 0.25 else { return }
        buildTagAt = gameTime
        var speed = 0
        if let v = focusBall?.physicsBody?.velocity {
            speed = Int(hypot(v.dx, v.dy) / 10) * 10
        }
        let fps = fpsShown > 0 ? "\(fpsShown) fps · low \(fpsLow) · worst \(fpsWorstShown) ms\nmax \(fpsWorstEver) ms \(fpsWorstWhere)\(slowText)\n" : ""
        let text = "\(fps)\(Self.buildTagText) · \(speed) · \(room.tagText) · \(column.width > 1 ? "cell \(column.cellName(activeFloor))" : "floor \(activeFloor + 1)/\(floors.count)") · drains \(drains)"
        if buildTag.text != text {
            buildTag.text = text
            buildTagBack?.path = CGPath(roundedRect: buildTag.frame.insetBy(dx: -4, dy: -4),
                                        cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    // MARK: - Balls and arrivals

    /// The ball the camera follows: the lowest one in play.
    private var focusBall: NlBall? {
        balls.min(by: { $0.position.y < $1.position.y })
    }

    private func removeBall(_ ball: NlBall) {
        rides.removeAll(where: { $0.ball === ball })
        ball.removeFromParent()
        balls.removeAll(where: { $0 === ball })
    }

    private func removeAllBalls() {
        rides.removeAll()
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
    }

    /// Brings a ball onto floor `on` by `arrival` (that floor becomes the ball's; the camera pans to it). The alternating
    /// ones (below, above) take the next side.
    private func arrive(_ arrival: Arrival, on floorIndex: Int, newBall: Bool = false) {
        typealias C = NlCellLayout
        setActiveFloor(floorIndex)
        if newBall {                                // every ball starts with every floor's kickback lit
            floors.forEach { $0.kickbackLit = true }
            refreshKickLamps()
        }
        if nudge.tilted { nudge.newBall(); updateFlippers() } else { nudge.newBall() }   // a tilt ends here
        switch arrival {
        case .fromBelow:
            let left = nextBelowLeft
            nextBelowLeft.toggle()
            let start = CGPoint(x: C.centerX, y: C.upRiseStartY)
            startRide(from: start, path: [start, C.upRelease], speed: NlTableLayout.riseSpeed, height: 0,
                      release: left ? C.upPopLeft : C.upPopRight, event: "fromBelow")
        case .fromAbove:
            let left = nextAboveLeft
            nextAboveLeft.toggle()
            let wire = left ? C.returnWireLeft : C.returnWireRight
            let top = CGPoint(x: C.centerX, y: C.topY - 4)          // through the top port, down the top lane
            startRide(from: top, path: [top] + wire, speed: NlTableLayout.wireRideSpeed,
                      height: NlTableLayout.wireHeight, release: CGVector(dx: 0, dy: -C.wireReleaseSpeed), event: "fromAbove")
        case .fromLeft, .fromRight:
            let isLeft = arrival == .fromLeft
            let stub = isLeft ? C.entryStubLeft : C.entryStubRight
            let wire = isLeft ? C.returnWireLeft : C.returnWireRight
            let join = stub.last!
            let j = wire.indices.min(by: { hypot(wire[$0].x - join.x, wire[$0].y - join.y)
                                           < hypot(wire[$1].x - join.x, wire[$1].y - join.y) }) ?? 0
            let path = stub + wire[(j + 1)...]
            startRide(from: stub[0], path: path, speed: NlTableLayout.wireRideSpeed,
                      height: NlTableLayout.wireHeight, release: CGVector(dx: 0, dy: -C.wireReleaseSpeed),
                      event: isLeft ? "fromLeft" : "fromRight")
        }
        showBanner(column.width > 1 ? "\(arrival.banner) · SECTOR \(column.cellName(floorIndex))"
                   : floors.count > 1 ? "\(arrival.banner) · FLOOR \(floorIndex + 1)" : arrival.banner)
        sfx(arrival == .fromBelow ? .upKick : .launch)
    }

    /// Makes floor `i` the ball's floor: its flippers take the input (the old floor's drop), the camera pans to it.
    private func setActiveFloor(_ i: Int) {
        guard i != activeFloor, floors.indices.contains(i) else { return }
        floor.leftFlipper.isPressed = false
        floor.rightFlipper.isPressed = false
        activeFloor = i
        cameraRig.origin = floor.position
        updateFlippers()
    }

    private func startRide(from start: CGPoint, path: [CGPoint], speed: CGFloat, height: CGFloat, release: CGVector,
                           event: String? = nil) {
        let ball = NlBall(at: start)
        if column.neon { ball.applyNeon() }
        floor.addChild(ball)                       // the ball lives on its floor (the floor's coordinates)
        balls.append(ball)
        ride(ball, path: path, speed: speed, height: height, release: release, event: event)
    }

    /// Puts a ball (new or in play) on a ride along `path`.
    func ride(_ ball: NlBall, path: [CGPoint], speed: CGFloat, height: CGFloat, heightEnd: CGFloat? = nil,
              release: CGVector, event: String? = nil, end: NlRideEnd = .release, hold: CGFloat = 0) {
        rides.removeAll(where: { $0.ball === ball })
        ball.setLayer(.ride)
        ball.physicsBody?.velocity = .zero
        ball.flipperGhostSteps = 0
        var cumulative: [CGFloat] = [0]
        for i in 1..<max(path.count, 1) {
            cumulative.append(cumulative[i - 1] + hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y))
        }
        rides.append(Ride(ball: ball, path: path, cumulative: cumulative, speed: speed, height: height, release: release,
                          event: event, heightEnd: heightEnd, end: end, hold: hold))
    }

    /// Moves every riding ball along its path; at the end it drops to the floor with its release velocity.
    private func updateRides(_ dt: CGFloat) {
        var finished: [Int] = []
        for i in rides.indices {
            rides[i].s += rides[i].speed * dt
            let ride = rides[i]
            let s = min(ride.s, ride.total)
            var k = 1
            while k < ride.cumulative.count - 1 && ride.cumulative[k] < s { k += 1 }
            let a = ride.path[k - 1], b = ride.path[min(k, ride.path.count - 1)]
            let seg = max(ride.cumulative[min(k, ride.cumulative.count - 1)] - ride.cumulative[k - 1], 0.001)
            let f = min(max((s - ride.cumulative[k - 1]) / seg, 0), 1)
            ride.ball.position = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            ride.ball.physicsBody?.velocity = .zero
            if let h1 = ride.heightEnd, ride.total > 0 {
                ride.ball.rampHeight = ride.height + (h1 - ride.height) * s / ride.total
            } else {
                ride.ball.rampHeight = ride.heightEnd ?? ride.height
            }
            if ride.s >= ride.total {
                if ride.hold > 0 { rides[i].hold -= dt } else { finished.append(i) }
            }
        }
        for i in finished.reversed() {
            let ride = rides.remove(at: i)
            if let name = ride.event { labEvent(name) }
            if case .release = ride.end {
                ride.ball.setLayer(.floor)
                ride.ball.rampHeight = 0
                ride.ball.physicsBody?.velocity = ride.release
                ride.ball.previousPosition = ride.ball.position
            } else if case .room(let tag) = ride.end {
                (ride.ball.parent as? NlCellFloor)?.room.rideEnded(ride.ball, tag: tag)
            }
        }
    }

    func newGame() {
        guard !floors.isEmpty else { return }      // not built yet (the column builds in didMove)
        fpsLow = 0
        fpsWorstEver = 0
        fpsWorstWhere = ""
        tracerFrom = gameTime + 2
        slowFrames = [:]
        isAttractMode = false
        #if DEBUG
        if shotLab != nil { physicsWorld.speed = 1 }
        shotLab = nil                              // a new game stops the Shot Lab
        if !playLabStarting { stopPlayLab(saving: true) }   // and the Play Lab, unless it's starting its next game
        #endif
        removeAllBalls()
        nextBallAt = nil
        bannerClearAt = nil
        targetLastHit = [:]
        for f in floors {
            f.kickbackLit = true
            f.saveLit = false
            f.targetsHitForSave = []
        }
        refreshKickLamps()
        pendingArrival = nil
        newBallCell = 0
        floors.forEach { $0.room.newGame() }
        drains = 0
        floorDrops = 0
        nextBelowLeft = true
        nextAboveLeft = true
        game.reset()
        arrive(.fromBelow, on: 0, newBall: true)   // a new ball comes up from below on the bottom floor
        cameraRig.origin = floor.position
        refreshCamera()
    }

    func showBanner(_ text: String) {
        #if DEBUG
        playLab?.banner(text)
        labObjective(forBanner: text)
        #endif
        game.banner = text
        bannerClearAt = gameTime + NlTableLayout.bannerSeconds
    }

    func sfx(_ s: MonSound) {
        if s != .flipper { lastHappening = s.rawValue; lastHappeningAt = gameTime }
        #if DEBUG
        if shotLab != nil { return }
        if playLab != nil, playLab?.isWatching != true { return }   // the robot plays silently unless watched
        #endif
        sound.play(s, volume: Float(settings.soundVolume))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView, !isAttractMode else { return }
        for touch in touches {
            let p = touch.location(in: view)   // screen points
            activeTouches[touch] = p.x < view.bounds.midX ? .left : .right
            nudge.swipeBegan(touch, at: p)
        }
        updateFlippers()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = view ?? hostView else { return }
        for touch in touches where activeTouches[touch] != nil {
            // A quick flick of a flipper finger nudges the table.
            if let direction = nudge.swipeMoved(touch, to: touch.location(in: view)) { applyNudge(direction) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            nudge.swipeEnded(touch)
            activeTouches.removeValue(forKey: touch)
        }
        updateFlippers()
    }

    private func updateFlippers() {
        #if DEBUG
        if shotLab != nil { return }               // the robot has the flippers
        #endif
        var left = activeTouches.values.contains(.left) || padLeft || robotLeft
        var right = activeTouches.values.contains(.right) || padRight || robotRight
        if nudge.tilted { left = false; right = false }      // tilted: dead flippers until the next ball
        if left && !leftFlipper.isPressed { sfx(.flipper) }
        if right && !rightFlipper.isPressed { sfx(.flipper) }
        leftFlipper.isPressed = left
        rightFlipper.isPressed = right
    }

    private func applyNudge(_ direction: Nudge.Direction) {
        guard !isAttractMode, !game.isGameOver else { return }
        let free = balls.filter { $0.isOnFloor }
        let outcome = nudge.nudge(direction, at: gameTime, balls: free.compactMap { $0.physicsBody })
        Nudge.haptic(for: outcome)
        switch outcome {
        case .ignored:
            return
        case .nudged:
            cameraRig.jolt(direction.unit, strength: Nudge.joltNudge)
        case .warning:
            cameraRig.jolt(direction.unit, strength: Nudge.joltWarning)
            cameraRig.shake(strength: 4, duration: 0.3)
            showBanner("TILT WARNING")
        case .tilt:
            cameraRig.jolt(direction.unit, strength: Nudge.joltTilt, duration: 0.35)
            cameraRig.shake(strength: 8, duration: 0.7)
            showBanner("TILT")
            updateFlippers()                                 // the flippers drop
        }
    }

    private func releaseAllControls() {
        activeTouches.removeAll()
        padLeft = false
        padRight = false
        if leftFlipper != nil { updateFlippers() }
    }

    /// Pausing (Table 06's fix): a flipper finger still down stays held, so a cradled ball is still cradled after resume.
    private func releaseNonTouchControls() {
        padLeft = false
        padRight = false
        if leftFlipper != nil { updateFlippers() }
    }

    /// Game controller, every frame of play: shoulders/triggers flip; touches keep working alongside.
    private func updateGamepad() {
        let pad = LabGamepad.shared.state
        if let direction = pad.nudge { applyNudge(direction) }
        if pad.left != padLeft || pad.right != padRight {
            padLeft = pad.left
            padRight = pad.right
            updateFlippers()
        }
    }

    // MARK: - Game loop

    override func update(_ realTime: TimeInterval) {
        var step = lastRealTime.map { min(max(realTime - $0, 1.0 / 240), 1.0 / 30) } ?? 1.0 / 120
        #if DEBUG
        if let lab = playLab { step *= Double(lab.physicsSpeed) }   // the Play Lab's pass (120 Hz steps)
        #endif
        lastRealTime = realTime
        gameTime += step
        frameStep = CGFloat(step)
        let now = gameTime
        #if DEBUG
        if shotLab != nil {                        // Shot Lab: the robot's frame instead of a game frame
            updateShotLab(CGFloat(step))
            return
        }
        #endif
        if isAttractMode { return }

        let dt = CGFloat(step)
        lastStep = dt
        updateGamepad()
        #if DEBUG
        updatePlayLab(now)
        #endif
        for f in floors {                        // every floor's flippers (an idle floor's fall back to rest)
            f.leftFlipper.step(dt: dt)
            f.rightFlipper.step(dt: dt)
        }
        updateRides(dt)
        floors.forEach { $0.room.update(dt) }
        // T10 M3 v1: during a move between floors the ball's cell is the one it's going to.
        if let tick = column.tick, !game.isGameOver, let banner = tick(dt, pendingArrival?.floor ?? activeFloor) {
            showBanner(banner)
        }
        if game.status != room.status { game.status = room.status }   // the ball's room owns the HUD status line
        handBallsToSwingingFlippers()
        for f in floors { f.slingshots.forEach { $0.settle() } }
        governInlanes()                          // the inlane speed limit (InlaneGovernor, shared)

        for f in floors {
            for t in f.targets {
                if let until = f.targetFlashUntil[t.name], now >= until {
                    f.targetFlashUntil[t.name] = nil
                    f.setTargetFlash(t.face, false)
                }
            }
        }

        if let due = bannerClearAt, now >= due {
            bannerClearAt = nil
            game.banner = nil
        }

        // The drain: a floor ball across its floor's drain line drops to the floor below (FROM ABOVE there), unless the
        // table's column says a drain on that floor costs a ball (Neon: the bottom floor). A new ball comes up from below
        // on the bottom floor.
        let drained = balls.filter { $0.isOnFloor && $0.position.y < NlCellLayout.drainLineY }
        if !drained.isEmpty {
            let from = (drained.first?.parent as? NlCellFloor)?.index ?? activeFloor
            let row = from / column.width             // T8 M4 v1: down one row, same column
            drained.forEach { removeBall($0) }
            if balls.isEmpty, nextBallAt == nil {
                // The bottom floor has nowhere to drop to, so a drain there always costs a ball.
                if column.drainCostsBall(row) || row == 0 {
                    drains += drained.count
                    cameraRig.shake(strength: 3, duration: 0.25)
                    sfx(.drain)
                    game.ballDrained()
                    newBallCell = column.ballLost(from)    // T10 M3 v1: the column says where the next ball comes up
                    pendingArrival = nil            // a new ball (FROM BELOW on that cell; Neon's: the bottom floor)
                    if !game.isGameOver { nextBallAt = now + 0.8 }
                } else {
                    pendingArrival = (.fromAbove, from - column.width)
                    floorDrops += 1
                    let delay = moveCamera(to: from - column.width, from: from)   // the pan (or transition) starts now
                    labEvent("floorDown")
                    sfx(.gate)
                    nextBallAt = now + delay
                }
            }
        }

        if let due = nextBallAt, now >= due {
            nextBallAt = nil
            // No pending arrival = a new ball (after a lost ball or a watchdog rescue): up from below on the bottom floor.
            let isNewBall = pendingArrival == nil
            let next = pendingArrival ?? (.fromBelow, newBallCell)
            pendingArrival = nil
            arrive(next.arrival, on: next.floor, newBall: isNewBall)
        }
        #if DEBUG
        checkPlayLabGame(now)
        #endif
    }

    /// A floor ball within reach of a flipper swinging up this frame belongs to the flipper model for the physics step
    /// (ghosted from the flippers); NlFlipper.solveSwing works out the frame afterwards (CHOMP! M2 v10).
    private func handBallsToSwingingFlippers() {
        guard NlTableLayout.flipperModel else { return }
        let r = NlTableLayout.ballRadius
        for ball in balls where ball.isOnFloor {
            for f in [leftFlipper!, rightFlipper!] where f.isSwingingUp && f.reaches(ball.position, ballRadius: r) {
                ball.flipperGhostSteps = max(ball.flipperGhostSteps, 1)
            }
        }
    }

    /// Hot inlane feeds: a ball rolling down an inlane is held to InlaneGovernor.maxSpeed so a held flipper can trap it.
    private func governInlanes() {
        for ball in balls where ball.isOnFloor {
            guard let body = ball.physicsBody,
                  let v = InlaneGovernor.limited(body.velocity, at: ball.position,
                                                 leftGuide: NlTableLayout.governorGuide,
                                                 mirrorSum: NlTableLayout.mirrorSum) else { continue }
            body.velocity = v
        }
    }

    /// The solid blocks (closed outlines): a floor ball whose centre ends up inside one is put back just outside its
    /// nearest edge, with any velocity into that edge removed (CHOMP! M3 v13).

    private func keepOutOfSolids(_ ball: NlBall) {
        let p = ball.position
        for closed in floor.solidBlocks where closed.count > 3 {
            let poly = Array(closed.dropLast())                  // last point repeats the first
            var inside = false
            var j = poly.count - 1
            for i in 0..<poly.count {
                let a = poly[i], b = poly[j]
                if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
                j = i
            }
            guard inside else { continue }
            var best = CGFloat.greatestFiniteMagnitude
            var q = p
            for i in 0..<poly.count {
                let a = poly[i], b = poly[(i + 1) % poly.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 0.001)))
                let c = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
                let d = hypot(p.x - c.x, p.y - c.y)
                if d < best { best = d; q = c }
            }
            let len = max(best, 0.001)
            let n = CGVector(dx: (q.x - p.x) / len, dy: (q.y - p.y) / len)      // outward (inside → the edge)
            let r = NlTableLayout.ballRadius + 0.5
            ball.position = CGPoint(x: q.x + n.dx * r, y: q.y + n.dy * r)
            if let body = ball.physicsBody {
                let v = body.velocity
                let vn = v.dx * n.dx + v.dy * n.dy
                if vn < 0 { body.velocity = CGVector(dx: v.dx - vn * n.dx, dy: v.dy - vn * n.dy) }
            }
            return
        }
    }

    override func didSimulatePhysics() {
        let r = NlTableLayout.ballRadius
        for ball in balls {
            guard let body = ball.physicsBody else { continue }
            if ball.flipperGhostSteps > 0 { ball.flipperGhostSteps -= 1 }
            if ball.isOnFloor {
                leftFlipper.solveSwing(ball, ballRadius: r)
                rightFlipper.solveSwing(ball, ballRadius: r)
                keepOutOfSolids(ball)
                checkOutlaneSave(ball)
            }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            if speed > NlTableLayout.maxBallSpeed {
                let scale = NlTableLayout.maxBallSpeed / speed
                body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
            }
            room.ballMoved(ball)                   // the room's line crossings (the Switchyard's ramp entry)
            ball.previousPosition = ball.position
            ball.previousVelocity = body.velocity
            ball.updateLook()
        }
    }

    override func didFinishUpdate() {
        guard isBuilt, !isPaused else { return }
        #if DEBUG
        if flyTest, !cameraRig.isFlying, gameTime >= flyTestNext, floors.count > 1 {
            let to = (flyTestCell + 1) % floors.count
            _ = moveCamera(to: to, from: flyTestCell)
            flyTestCell = to
            flyTestNext = gameTime + 3
        }
        #endif
        cameraRig.update(viewSize: size, ball: focusBall, mode: effectiveCameraMode, dt: cameraStep)
        if cameraRig.origin != lastCameraOrigin {          // a pan to another cell: count the next second as "pan"
            lastCameraOrigin = cameraRig.origin
            panUntil = gameTime + 1
        }
        if cameraRig.isFlying { panUntil = max(panUntil, gameTime + 0.3) }
        if !moveMarks.isEmpty {                            // T8 M4 v3: the marks show while the camera is pulled back
            let a = cameraRig.overviewAmount
            moveMarks.forEach { $0.alpha = a }
            if !cameraRig.isFlying { endCellTransition() }
        }
        placeBuildTag()
    }

    // MARK: - Outlane saves

    /// A lit save fires when a floor ball crosses the trigger height going down in its outlane: the ball is put at the
    /// outlane's centre and kicked out through the mouth, across to the far flipper (NlTableLayout.kick…).
    private func checkOutlaneSave(_ ball: NlBall) {
        let p0 = ball.previousPosition, p = ball.position
        let y = NlTableLayout.outlaneTriggerY
        guard p0.y >= y, p.y < y else { return }
        let left = p.x < NlTableLayout.outlaneMaxX
        let right = p.x > NlTableLayout.mirrorSum - NlTableLayout.outlaneMaxX
        guard let f = ball.parent as? NlCellFloor ?? floor,
              (left && f.kickbackLit) || (right && f.saveLit), let body = ball.physicsBody else { return }
        let a = NlTableLayout.kickAngle, k = NlTableLayout.kickSpeed
        let from = NlTableLayout.kickFromLeft
        if left {
            f.kickbackLit = false
            ball.position = from
            body.velocity = CGVector(dx: k * cos(a), dy: k * sin(a))
            showBanner("KICKBACK")
            labEvent("kickback")
        } else {
            f.saveLit = false
            ball.position = CGPoint(x: NlTableLayout.mirrorSum - from.x, y: from.y)
            body.velocity = CGVector(dx: -k * cos(a), dy: k * sin(a))
            showBanner("OUTLANE SAVE")
            labEvent("outlaneSave")
        }
        ball.previousPosition = ball.position
        f.refreshKickLamps()
        sfx(.kickback)
        hitHaptic.impactOccurred(intensity: 0.9)
        cameraRig.shake(strength: 3, duration: 0.2)
    }

    /// Every floor's save lamps (each shows its own floor's saves).
    private func refreshKickLamps() {
        floors.forEach { $0.refreshKickLamps() }
    }

    // MARK: - Contacts

    /// Only velocities, score and feedback change here; anything structural waits for update().
    fileprivate func handleContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let ballBody: SKPhysicsBody, other: SKPhysicsBody
        let ballish = NlPhysicsCategory.ball | NlPhysicsCategory.ghostBall
        if a.categoryBitMask & ballish != 0 {
            ballBody = a; other = b
        } else if b.categoryBitMask & ballish != 0 {
            ballBody = b; other = a
        } else {
            return
        }
        guard let ballNode = ballBody.node as? NlBall, let node = other.node else { return }

        switch other.categoryBitMask {
        case NlPhysicsCategory.slingshot:
            // The kicking face is a child of the slingshot node.
            if let sling = node.parent as? NlSlingshot, sling.hit(ball: ballBody, at: gameTime) {
                labEvent("sling")
                game.add(NlPoints.slingshot)
                hitHaptic.impactOccurred(intensity: 0.6)
                sparkBurst(in: ballNode.parent ?? self, at: ballNode.position,
                           color: column.neon ? NlNeon.cyan : Self.wallColor)
                sfx(.sling)
            }
        case NlPhysicsCategory.target:
            // The room's targets: the cell scores and flashes them and counts them for the outlane save; the room says what
            // they do (the Switchyard: turn the turntable or step the bridge) and what the banner reads.
            guard let tf = floors.first(where: { f in f.targets.contains(where: { $0.body === node }) }),
                  let t = tf.targets.first(where: { $0.body === node }) else { break }
            if let last = targetLastHit[t.name], gameTime - last < 0.15 { break }
            targetLastHit[t.name] = gameTime
            if !tf.saveLit {
                tf.targetsHitForSave.insert(t.name)
                if tf.targetsHitForSave.count == tf.targets.count {   // all this floor's targets: light its outlane save
                    tf.saveLit = true
                    tf.targetsHitForSave = []
                    tf.refreshKickLamps()
                    showBanner("OUTLANE SAVE LIT")
                    labEvent("saveLit")
                }
            }
            labEvent(tf.room.targetEvents[t.name] ?? "target")
            game.add(NlPoints.target)
            showBanner(tf.room.targetHit(t.name))
            sfx(.standup)
            hitHaptic.impactOccurred(intensity: 0.7)
            tf.setTargetFlash(t.face, true)                 // back to its colour in update()
            tf.targetFlashUntil[t.name] = gameTime + 0.12
        default:
            break
        }
    }
}

extension NlTableScene: SKPhysicsContactDelegate {
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated { handleContact(contact) }
    }
}

private extension SKShapeNode {
    /// Configure a freshly made shape inline.
    func then(_ configure: (SKShapeNode) -> Void) -> SKShapeNode {
        configure(self)
        return self
    }
}

extension NlTableScene {
    /// A shot event for the labs (a no-op in play and in Release builds).
    func labEvent(_ name: String) {
        #if DEBUG
        shotLab?.event(name, at: shotLabTime)
        playLab?.shot(name, now: gameTime)
        if playLabShotObjectives.contains(name) { playLab?.objective(name, now: gameTime) }
        #endif
    }
}

#if DEBUG
// MARK: - M1 v2: the Shot Lab host (CHOMP!'s pattern). The robot sweeps flip timings from both flippers and records
// the first shot each flip makes. Run in the Simulator: tools/shotlab_run.sh neon
extension NlTableScene: ShotLabHost {
    var shotLabTableName: String { column.labName }

    /// The room's shots end a trial; slings are noted only.
    var shotLabMajorEvents: Set<String> { room.shotLabMajorEvents }

    /// CHOMP!'s gravity (−6.0) rolls a cradled ball slowly; its sweep runs to 0.85 s, so this one does too.
    var shotLabCradleDelays: ClosedRange<Double> { 0.20...1.00 }   // T10 M3 v2: from the new cradle the roll is longer

    /// T10 M3 v2: the kit's angled feeds (T11 port, 2026-11-24) bring an inlane ball to the flipper ~0.9 s after the
    /// release (it was ~0.6 s with the r 120 bend), past the default 0.30–0.90 sweep.
    var shotLabInlaneDelays: ClosedRange<Double>? { 0.30...1.30 }

    /// Cradled as on CHOMP! (same flipper: 80 long, 30° rest, 51° stroke, 30 pt ball): dropped 40 pt out, above the raised
    /// flipper by the ball's radius + 5. The inlane start is the inlane's centre line under the guide post.
    var shotLabFlippers: [ShotLab.FlipperSpec] {
        let up = NlTableLayout.flipperTravel - NlTableLayout.flipperRestAngle
        // T10 M3 v2: with the angled feeds a held ball rests in the V between the guide's 20° slant and the raised
        // flipper, (203, 229) on the left (12 along, 26 above). Dropped at the old spot (40 out) it rolled into the V and
        // was still rocking at ~60 pt/s at the 1.2 s check, so every cradle trial was invalid.
        let along: CGFloat = 12, above: CGFloat = NlTableLayout.ballRadius + 11
        let l = NlCellLayout.pivotLeft
        let left = CGPoint(x: l.x + along * cos(up) - above * sin(up), y: l.y + along * sin(up) + above * cos(up))
        let right = CGPoint(x: NlTableLayout.mirrorSum - left.x, y: left.y)
        let ix = (NlCellLayout.laneGuidePostLeft.x + NlCellLayout.slingLeft[0].x) / 2
        let iy = NlCellLayout.laneGuidePostLeft.y + 10
        let r = NlCellLayout.pivotRight
        return [ShotLab.FlipperSpec(name: "left", pivot: l, cradle: left,
                                    starts: ShotLab.lowerStarts(pivot: l, pointsLeft: false, inlaneX: ix, inlaneTopY: iy)),
                ShotLab.FlipperSpec(name: "right", pivot: r, cradle: right,
                                    starts: ShotLab.lowerStarts(pivot: r, pointsLeft: true,
                                                                inlaneX: NlTableLayout.mirrorSum - ix, inlaneTopY: iy))]
    }

    func shotLabSetFlipper(_ index: Int, pressed: Bool) {
        if index == 0 { leftFlipper.isPressed = pressed } else { rightFlipper.isPressed = pressed }
    }

    func shotLabPlaceBall(at point: CGPoint) {
        let ball = NlBall(at: point)
        if column.neon { ball.applyNeon() }
        floor.addChild(ball)
        balls.append(ball)
    }

    func shotLabPlaceBall(at point: CGPoint, velocity: CGVector) {
        shotLabPlaceBall(at: point)
        balls.last?.physicsBody?.velocity = velocity
    }

    /// Every ball gone, nothing riding, no ball due.
    func shotLabResetTable() {
        removeAllBalls()
        nextBallAt = nil
        for f in floors {                           // the robot measures the bare table: no saves
            f.kickbackLit = false
            f.saveLit = false
        }
        refreshKickLamps()
        floors.forEach { $0.room.shotLabReset() }   // and the rooms as a new game has them
    }

    /// The room's probes (the Switchyard: the shot line and the RAILS target's height).
    var shotLabProbes: [ShotLab.Probe] { room.shotLabProbes }

    var shotLabBall: (position: CGPoint, velocity: CGVector)? {
        guard let ball = balls.first else { return nil }
        return (ball.position, ball.physicsBody?.velocity ?? .zero)
    }

    func debugStartShotLab() {
        stopPlayLab(saving: true)                  // a Shot Lab started mid Play Lab ends that run first
        isAttractMode = false
        removeAllBalls()
        setActiveFloor(0)                          // the robot plays the bottom floor
        cameraRig.origin = floor.position
        shotLabTime = 0
        for f in floors {
            f.kickbackLit = false
            f.saveLit = false
        }
        refreshKickLamps()
        shotLab = ShotLab(host: self)
        refreshCamera()
    }

    /// The robot's frame: only what the physics and shot detection need (no arrivals, drains or banners).
    fileprivate func updateShotLab(_ realDt: CGFloat) {
        guard let lab = shotLab else { return }
        let speed = CGFloat(lab.physicsSpeed)
        physicsWorld.speed = speed
        let dt = realDt * speed
        shotLabTime += TimeInterval(dt)
        let now = shotLabTime
        lastStep = dt
        leftFlipper.step(dt: dt)
        rightFlipper.step(dt: dt)
        handBallsToSwingingFlippers()
        floor.slingshots.forEach { $0.settle() }
        governInlanes()
        if lab.update(now: now) {
            game.banner = lab.progressText
        } else {
            let saved = lab.save(now: now)
            shotLab = nil
            physicsWorld.speed = 1
            shotLabResetTable()
            game.banner = "SHOT LAB DONE · \(lab.trials.count) TRIALS · \(saved)"
            ShotLab.quitIfLaunchedForLab()          // launched by tools/shotlab_run.sh neon → quit
        }
    }
}

// MARK: - M1 v2: the Play Lab host (CHOMP!'s pattern). Robot players at four skills play whole games of the cell as a
// bottom-row cell; the report shows drains, stuck balls and which shots get made. tools/playlab_run.sh neon
extension NlTableScene: PlayLabHost {
    var playLabTableName: String { column.labName }
    var playLabBallRadius: CGFloat { NlTableLayout.ballRadius }
    var playLabVariantCount: Int { 1 }

    /// Shot events that count as objectives the first time each game (labEvent reports them): the cell's and the room's.
    var playLabShotObjectives: Set<String> { cachedShotObjectives }

    /// The room's objectives, then the cell's (the ways in, the saves, tilt).
    var playLabObjectives: [PlayObjective] {
        room.playLabObjectives +
        [PlayObjective(name: "fromBelow", text: "A ball comes in from below"),
         PlayObjective(name: "fromAbove", text: "A ball comes in from above"),
         PlayObjective(name: "fromLeft", text: "A ball comes in from the left"),
         PlayObjective(name: "fromRight", text: "A ball comes in from the right"),
         PlayObjective(name: "kickback", text: "The kickback saves a ball"),
         PlayObjective(name: "saveLit", text: "Light the outlane save (all the room's targets)"),
         PlayObjective(name: "outlaneSave", text: "The outlane save saves a ball"),
         PlayObjective(name: "floorDown", text: "A drain drops the ball to the floor below"),
         PlayObjective(name: "floorUp", text: "Out the top exit to the floor above"),
         PlayObjective(name: "tilt", text: "Tilt")] +
        (column.width > 1 ? [PlayObjective(name: "cellLeft", text: "Out the left exit to the cell beside"),
                             PlayObjective(name: "cellRight", text: "Out the right exit to the cell beside")] : [])
    }

    /// Where a 30 pt ball rests on the raised flipper: CHOMP!'s measured spot (M4 v2) moved with the pivot — the same
    /// flipper. Flip delays: the middle of each Shot Lab window, 120 Hz (filled in from this table's own Shot Lab).
    var playLabFlippers: [PlayRobotFlipper] {
        let specs = shotLabFlippers
        let rest = NlTableLayout.flipperRestAngle
        let rightRest = CGPoint(x: NlCellLayout.pivotRight.x - 7, y: NlCellLayout.pivotRight.y + 32)
        let leftRest = CGPoint(x: NlTableLayout.mirrorSum - rightRest.x, y: rightRest.y)
        return [PlayRobotFlipper(name: "left", pivot: specs[0].pivot, length: NlTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: false, cradle: leftRest, rightButton: false, upper: false,
                                 shots: room.leftShots, inlane: room.leftInlane, feedCatchSpeed: 300),
                PlayRobotFlipper(name: "right", pivot: specs[1].pivot, length: NlTableLayout.flipperLength, restAngle: rest,
                                 pointsLeft: true, cradle: rightRest, rightButton: true, upper: false,
                                 shots: room.rightShots, inlane: room.rightInlane, feedCatchSpeed: 300)]
    }

    // The robot's shot delays and inlane bands are the room's (NlSwitchyardRoom: from its own Shot Lab).

    func playLabStartGame(variant: Int) -> String {
        game.isRobot = true
        playLabStarting = true
        newGame()
        playLabStarting = false
        physicsWorld.speed = playLab?.physicsSpeed ?? 1
        return ""
    }

    func playLabEndGame() -> [String: Int] {
        if !game.isGameOver {
            removeAllBalls()
            nextBallAt = nil
        }
        return ["drains": drains, "floorDrops": floorDrops]
    }

    func playLabStop() {
        game.isRobot = false
    }

    /// Starts the Play Lab (robot players at four skills, 120 Hz, or as the launch arguments say). Menu or a new game
    /// stops it, saving the games played so far.
    func debugStartPlayLab() {
        shotLab = nil
        stopPlayLab(saving: true)
        isAttractMode = false
        let lab = PlayLab(host: self)
        playLab = lab
        lab.beginGame(now: gameTime)
    }

    /// Everything the robot needs to know this frame, and its buttons applied. Riding balls count as held.
    fileprivate func updatePlayLab(_ now: TimeInterval) {
        guard let lab = playLab else { return }
        if game.isGameOver || playLabNextAt != nil {
            if robotLeft || robotRight { robotLeft = false; robotRight = false; updateFlippers() }
            return
        }
        let view = PlayRobotView(now: now, balls: balls.map { b in
            PlayRobotView.Ball(position: b.position, velocity: b.physicsBody?.velocity ?? .zero, isUpper: !b.isOnFloor,
                               isHeld: !b.isOnFloor, onPlunger: false, id: ObjectIdentifier(b).hashValue)
        }, wanted: robotWanted())
        runWatchdog(now, lab)
        guard let cmd = lab.frame(view) else { return }
        if let direction = cmd.nudge { applyNudge(direction) }
        if cmd.left != robotLeft || cmd.right != robotRight {
            robotLeft = cmd.left
            robotRight = cmd.right
            updateFlippers()
        }
    }

    /// A ball off the table, or one that hasn't moved 4 pt in 5 s while not riding or cradled, is recorded as an
    /// incident and served again (no ball lost).
    private func runWatchdog(_ now: TimeInterval, _ lab: PlayLab) {
        let w = NlTableLayout.worldSize
        for ball in balls {
            let id = ObjectIdentifier(ball)
            let p = ball.position
            if !p.x.isFinite || !p.y.isFinite || p.x < -30 || p.x > w.width + 30 || p.y > w.height + 30 {
                watchdogRescue("offTable", ball, now, lab)
                continue
            }
            if !ball.isOnFloor || isCradled(ball) || p.y < NlCellLayout.drainLineY {
                watchSpots[id] = (p, now)
                continue
            }
            if let spot = watchSpots[id], hypot(p.x - spot.0.x, p.y - spot.0.y) < 4 {
                if now - spot.1 > 5 { watchdogRescue("stuck", ball, now, lab) }
            } else {
                watchSpots[id] = (p, now)
            }
        }
    }

    /// A ball resting on a raised flipper is being held on purpose.
    private func isCradled(_ ball: NlBall) -> Bool {
        let flippers = playLabFlippers
        for (i, pressed) in [leftFlipper.isPressed, rightFlipper.isPressed].enumerated() where pressed {
            let c = flippers[i].cradle
            if hypot(ball.position.x - c.x, ball.position.y - c.y) < 30 { return true }
        }
        return false
    }

    private func watchdogRescue(_ kind: String, _ ball: NlBall, _ now: TimeInterval, _ lab: PlayLab) {
        let p = ball.position
        let x = p.x.isFinite ? Double(p.x) : -1, y = p.y.isFinite ? Double(p.y) : -1
        lab.incident(PlayIncident(kind: kind, x: x.rounded(), y: y.rounded(), upper: !ball.isOnFloor,
                                  time: lab.elapsed(now: now).rounded()))
        watchSpots[ObjectIdentifier(ball)] = nil
        removeBall(ball)
        if balls.isEmpty, nextBallAt == nil { nextBallAt = now + 0.5 }      // served again, no ball lost
        showBanner("WATCHDOG · \(kind == "stuck" ? "STUCK BALL" : "BALL OFF THE TABLE") AT \(Int(x)), \(Int(y))")
    }

    /// The shots the table wants, most wanted first: the room decides, given the targets still needed for the save.
    private func robotWanted() -> [String] {
        let need = floor.targets.map(\.name).filter { !floor.targetsHitForSave.contains($0) }.compactMap { room.targetEvents[$0] }
        return room.robotWanted(saveNeeds: floor.saveLit ? [] : need)
    }

    /// Banners that double as objectives.
    fileprivate func labObjective(forBanner text: String) {
        guard let lab = playLab else { return }
        if text == "TILT" { lab.objective("tilt", now: gameTime) }
    }

    /// At game over (or after the cap) the game is recorded; the next one starts 2 s later.
    fileprivate func checkPlayLabGame(_ now: TimeInterval) {
        guard let lab = playLab else { return }
        if let due = playLabNextAt {
            if now >= due {
                playLabNextAt = nil
                if lab.isDone { finishPlayLab() } else { lab.beginGame(now: now) }
            }
            return
        }
        guard lab.current != nil, game.isGameOver || lab.isTimeUp(now: now) else { return }
        let over = game.isGameOver
        lab.endGame(score: game.score, ballsPlayed: NlGameState.ballsPerGame - game.ballsLeft + (over ? 0 : 1),
                    endedBy: over ? "gameOver" : "time", now: now)
        physicsWorld.speed = lab.physicsSpeed
        playLabNextAt = now + 2
    }

    private func finishPlayLab() {
        guard let lab = playLab else { return }
        let saved = lab.save()
        let count = lab.games.count
        stopPlayLab(saving: false)
        newGame()
        game.banner = "PLAY LAB DONE · \(count) GAMES · \(saved)"
        bannerClearAt = nil
        PlayLab.quitIfLaunchedForLab()
    }

    fileprivate func stopPlayLab(saving: Bool) {
        guard let lab = playLab else { return }
        playLab = nil
        lab.stop(saving: saving)
        playLabNextAt = nil
        watchSpots.removeAll()
        robotLeft = false
        robotRight = false
        if leftFlipper != nil { updateFlippers() }
        physicsWorld.speed = isAttractMode ? 0 : 1
    }
}
#endif
