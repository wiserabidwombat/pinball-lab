// Pinball Lab Table 10 (9 to Alive): the table's column of floors on Neon Labyrinth's shared cell engine (NlColumn).
// T10 M1 v1 (grey box): a test column of three Lobbies, so climbing the stairs and dropping back down can be played
// before more floors exist. A drain on the bottom floor costs a ball; above it a drain drops the ball one floor.
// The run's real column (Lobby, six shuffled floors, Roof) and the horde's drain rule come with the rules milestone.
import CoreGraphics

@MainActor
enum NtaColumn {
    static func test() -> NlColumn {
        NlColumn(makeRooms: { [NtaLobbyRoom(), NtaLobbyRoom(), NtaLobbyRoom()] },
                 drainCostsBall: { $0 == 0 },
                 labName: "Alive")             // T10 M1 v2: labs save as shotlab-alive-… / playlab-alive-…
    }
}
