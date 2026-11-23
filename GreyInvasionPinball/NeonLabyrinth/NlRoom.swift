// Pinball Lab Table 08 (Neon Labyrinth): the room type. T8 M2 round A split the shared cell kit from the room:
// NlTableScene is the CELL (the kit's walls, lanes and slings, the flippers and the flipper model, arrivals as rides,
// the drain, the kickback / outlane save, nudge and tilt, targets' bodies and scoring, the labs' plumbing), and a ROOM
// adds its own floor parts, targets, drawn parts and exit puzzle, and says which exits it has. The Switchyard
// (NlSwitchyardRoom) is the first room; other tables (9 to Alive) build their own rooms on the same cell.
import SpriteKit
import CoreGraphics

/// The three ways out of a cell. A side exit comes with that side's entry portal (the cell next door's exit), so a
/// room without a side exit has neither portal on that side, and no entry stub.
enum NlExit: Int, CaseIterable {
    case left = 0, top = 1, right = 2
    var glyph: String { ["◄", "▲", "►"][rawValue] }
    /// The lab event when a ball leaves this way.
    var labEvent: String { ["exitLeft", "exitTop", "exitRight"][rawValue] }
}

/// How a ride ends: dropped to the floor with its release velocity, or handed back to the room with the room's tag.
enum NlRideEnd {
    case release
    case room(Int)
}

/// A room on the shared cell. The cell calls these; the room calls its floor's building and play services
/// (addChild, addWall, addPost, addTarget, addRails, ride, leave, setExitLit, showBanner, sfx, labEvent, haptic, score).
/// T8 M2 round B: a room sits on one floor of the column (NlCellFloor), in that floor's coordinates.
@MainActor
protocol NlRoom: AnyObject {
    /// Which exits the room has: the cell draws only these exit portals, and only these sides' entry portals and stubs,
    /// and only arrivals through open sides come in.
    var exits: Set<NlExit> { get }
    /// Closed outlines (last point = first) a floor ball must never end up inside; the cell pushes it back out.
    var solidBlocks: [[CGPoint]] { get }
    /// The room's targets' lab event names, by target name.
    var targetEvents: [String: String] { get }
    /// Builds the room's floor parts, targets and drawn parts into its floor (once, while the floor builds).
    func build(in cell: NlCellFloor)
    /// A new game: the room's state back to its start.
    func newGame()
    /// Every game frame, after the rides moved (game seconds).
    func update(_ dt: CGFloat)
    /// Every ball after the physics step, before its previous position moves on (line-crossing switches, ramp entries).
    func ballMoved(_ ball: NlBall)
    /// One of the room's targets was hit (the cell has scored and flashed it). Returns the banner to show.
    func targetHit(_ name: String) -> String
    /// A ride the room started with `.room(tag)` reached its end (the ride is already gone).
    func rideEnded(_ ball: NlBall, tag: Int)
    /// The ball went out through `exit` (already removed; the cell brings it back in as the next cell would get it).
    func ballLeft(by exit: NlExit)
    /// A short note on the room's state for the debug build tag.
    var tagText: String { get }
    /// The room's HUD line (NlGameState.status, shown dim when there's no banner), or nil.
    var status: String? { get }

    #if DEBUG
    /// Shot Lab: the room's shots that end a trial, and where to probe their paths.
    var shotLabMajorEvents: Set<String> { get }
    var shotLabProbes: [ShotLab.Probe] { get }
    /// Shot Lab: back to the room's state at a new game (between trials).
    func shotLabReset()
    /// Play Lab: the room's objectives, and which of its lab events count as objectives.
    var playLabObjectives: [PlayObjective] { get }
    var playLabShotObjectives: Set<String> { get }
    /// Play Lab: the robot's flip delays and inlane bands for the room's shots (from the room's own Shot Lab).
    var leftShots: [(name: String, delay: Double)] { get }
    var rightShots: [(name: String, delay: Double)] { get }
    var leftInlane: [(name: String, lo: CGFloat, hi: CGFloat)] { get }
    var rightInlane: [(name: String, lo: CGFloat, hi: CGFloat)] { get }
    /// Play Lab: the shots the room wants most, first. `saveNeeds` are the targets the cell still needs to light the
    /// outlane save (the room decides where they go in its order).
    func robotWanted(saveNeeds: [String]) -> [String]
    #endif
}
