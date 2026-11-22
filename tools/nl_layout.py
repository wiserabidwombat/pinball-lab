"""Neon Labyrinth (Table 08) — one cell = the shared cell kit (nl_kit.py) + a room (nl_room_<name>.py).
T8 M2 round A: this file used to hold both; it now puts them together, so every check, sim and render keeps working
with `import nl_layout as L`. Pick another room with `nl_layout.use_room("<name>")` before using L.floor_parts().
"""
import importlib
from nl_kit import *
from nl_room_switchyard import *          # the default room's names (SWITCH_L, RAMP_*, HUB, rail_path ...)
import nl_room_switchyard as _default_room

ROOM = _default_room

def use_room(name):
    """Make room `name` (module nl_room_<name>) the one floor_parts() and the tools use."""
    global ROOM
    ROOM = importlib.import_module(f"nl_room_{name}")
    return ROOM

def floor_parts(room=None):
    """name -> ("poly", points) | ("circle", centre, r). Every floor-solid part of the cell: the kit's, then the room's."""
    r = room or ROOM
    P = kit_parts(r.EXITS)
    P.update(r.room_parts())
    return P

if __name__ == "__main__":
    for k in ("TIP_L_REST", "GUIDE_END_L", "GUIDE_BEND_L", "SLING_CORNER_L", "SLING_TIP_L", "SLING_TOP_L"):
        v = globals()[k]
        print(f"{k:16s} ({v[0]:.1f}, {v[1]:.1f})")
    print("switch block L", [(round(x, 1), round(y, 1)) for x, y in switch_block("L")])
    print("arch y at 270:", arch_y(270))
