# Pinball Lab

Three original pinball tables for iPhone, built one after another to see how far a table can go: from a one-screen
prototype to a table modelled and rendered like a real machine. SwiftUI + SpriteKit, no game engine.

| | Table | What it added |
|---|---|---|
| 01 | **Orbit Pinball** | Where it started: one screen, flippers, planet bumpers, slingshots, drop targets, a wormhole, skill shot and ball save. |
| 02 | **Grey Invasion** | A 600 × 1300 table bigger than the screen with a camera that flies with the ball, two ramps, multiball, three waves of saucers and a Mothership finale, all art drawn in code, and a robot "Shot Lab" that measures how hard every shot is. |
| 03 | **Cthulhu Rising** | Every part modelled and rendered in 3D (Blender), a clear ramp the ball climbs, a swaying Cthulhu toy, a spinner, a magnet and an up-kicker, a three-act story tuned with a game simulator, and its own synthesized sound set. |

Each table has a "How it evolved" page in the app with its stats and what building it taught us.

## Playing

- Touch the left or right half of the screen to flip; pull down on the plunger to launch.
- Game controllers work too: L1/L2 and R1/R2 flip, hold A (or pull the right stick down) to plunge, Menu pauses,
  A plays and resumes.
- Requires iOS 27, iPhone. Runs at 120 fps on ProMotion iPhones.

## Project layout

| Path | What's there |
|---|---|
| `GreyInvasionPinball/` | The app (a folder-synced Xcode group). Pinball Lab home and story pages at the top level, Grey Invasion's table at the top level too, `Orbit/` and `Cthulhu/` for the other two tables. |
| `GreyInvasionPinball/Assets.xcassets` | Art: `OrbitArt`, Grey Invasion's art, `CthArt` (the Blender renders). |
| `GreyInvasionPinball/Sounds`, `OrbitSounds`, `CthSounds` | Each table's sound effects. |
| `tools/` | The Python scripts that made the art, sounds and test analysis (see below). |
| `docs/HANDOFF.md` | The build diary: every milestone and playtest round, what changed and why. |
| `Info.plist` | Keys merged into the generated Info.plist: 120 Hz, controller support, App Store category. |
| `CREDITS.md` | Every asset, its source and licence. |

## Tools

- **Art:** `cth_render_*.py` render Cthulhu Rising's table and parts in Blender (`bpy`, Cycles) in a 22° oblique lean so the
  floor lines up with the physics; `cth_floor_*.py` paint the playfield (pycairo); `art_*.py` draw Grey Invasion's art.
- **Sound:** `cth_make_sfx.py` synthesizes Cthulhu Rising's bells, chants and roar (numpy) and levels Kenney impact sounds;
  `cth_make_loops.py` makes the seamless Awakening drone; `make_sfx.py` converts Grey Invasion's Kenney sounds.
- **Testing:** `shotlab_analyze.py` turns the in-app Shot Lab robot's runs into per-skill shot odds; `shotlab_simulate.py`
  and `cth_simulate.py` play thousands of simulated games to tune the rules; `slinglab_analyze.py` reads the slingshot lab.

## Credits

Built by Aaron Tilley with Claude. Kenney (kenney.nl) CC0 art and sounds, Orbitron and Cinzel fonts (SIL OFL 1.1);
everything else was made for these tables. Full list in [CREDITS.md](CREDITS.md).
