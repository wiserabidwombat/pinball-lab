# Pinball Lab

Four original pinball tables for iPhone, built one after another to see how far a table can go: from a one-screen
prototype to a table modelled and rendered like a real machine, and one that paints itself as you play. SwiftUI +
SpriteKit, no game engine.

| | Table | What it added |
|---|---|---|
| 01 | **Orbit Pinball** | Where it started: one screen, flippers, planet bumpers, slingshots, drop targets, a wormhole, skill shot and ball save. |
| 02 | **Grey Invasion** | A 600 × 1300 table bigger than the screen with a camera that flies with the ball, two ramps, multiball, three waves of saucers and a Mothership finale, all art drawn in code, and a robot "Shot Lab" that measures how hard every shot is. |
| 03 | **Cthulhu Rising** | Every part modelled and rendered in 3D (Blender), a clear ramp the ball climbs, a swaying Cthulhu toy, a spinner, a magnet and an up-kicker, a three-act story tuned with a game simulator, and its own synthesized sound set. |
| 04 | **Monsoon** | Color as progress: the table starts as a pencil sketch and every goal washes watercolor into its part of the painting (a Metal shader, different every game). Crossing wire habitrails with a diverter and a helix, a captive ball, a dust devil that bends the ball's path, a storm soundtrack that builds with the game, and a live storm with lightning over the sky in the Monsoon multiball. |

Each table has a "How it evolved" page in the app with its stats and what building it taught us, and a How to Play
screen.

## Playing

- Touch the left or right half of the screen to flip; pull down on the plunger to launch.
- Game controllers work too: L1/L2 and R1/R2 flip, hold A (or pull the right stick down) to plunge, Menu pauses,
  A plays and resumes.
- Requires iOS 27, iPhone. Runs at 120 fps on ProMotion iPhones.

## Project layout

| Path | What's there |
|---|---|
| `GreyInvasionPinball/` | The app (a folder-synced Xcode group). Pinball Lab home and story pages at the top level, Grey Invasion's table at the top level too, `Orbit/`, `Cthulhu/` and `Monsoon/` for the other three tables. |
| `GreyInvasionPinball/Assets.xcassets` | Art: `OrbitArt`, Grey Invasion's art, `CthArt` (the Blender renders), `MonArt` (Monsoon's watercolor, pencil sketch and region maps, and its parts). |
| `GreyInvasionPinball/Sounds`, `OrbitSounds`, `CthSounds`, `MonSounds` | Each table's sound effects (and loops). |
| `tools/` | The Python scripts that made the art, sounds and test analysis (see below). |
| `docs/HANDOFF.md` | The build diary: every milestone and playtest round, what changed and why. |
| `Info.plist` | Keys merged into the generated Info.plist: 120 Hz, controller support, App Store category. |
| `CREDITS.md` | Every asset, its source and licence. |

## Tools

- **Art:** `cth_render_*.py` and `mon_render_*.py` render tables and parts in Blender (`bpy`, Cycles) in a 22° oblique
  lean so the floor lines up with the physics; `cth_floor_*.py` paint Cthulhu Rising's playfield (pycairo);
  `mon_floor.py`, `mon_watercolor.py` and `mon_upper_art.py` turn Monsoon's painting into the color art, the pencil
  sketch and the region maps the paint shader reads; `art_*.py` draw Grey Invasion's art.
- **Sound:** `cth_make_sfx.py` and `mon_make_sfx.py` synthesize each table's sounds (numpy) and level Kenney impact
  sounds; `cth_make_loops.py` makes the Awakening drone and `mon_make_loops.py` Monsoon's four-layer storm bed;
  `make_sfx.py` converts Grey Invasion's Kenney sounds.
- **Testing:** `shotlab_analyze.py` turns the in-app Shot Lab robot's runs into per-skill shot odds; `shotlab_simulate.py`,
  `cth_simulate.py` and `mon_simulate.py` play thousands of simulated games to tune the rules; `slinglab_analyze.py`
  reads the slingshot lab; `mon_sky_coverage_sim.py` checks how much of the painting each wash colors.

## Testing labs (Debug builds)

Two robot labs live in Debug builds (Release builds don't include them). The **Shot Lab** fires one flipper at a ball
again and again, at every flip delay, and records what each delay makes — the timing window of every shot. The **Play
Lab** has robot players at four skills (beginner, intermediate, advanced, expert) play whole games with each table's
real rules, at 120 Hz physics steps, and records everything they do. Both write JSON reports to `ShotLab/`
(on the Mac when run in the Simulator; shared from the phone when run there), and the Python tools in `tools/` turn
them into pages.

Both labs run **120 Hz only** by default. Since November 2026 every device steps the physics at 1/120 s or finer (a
60 Hz screen takes two steps a frame), so the old 60 Hz pass only shows how older builds behaved; ask for it with
`HZ=60` or `HZ=both` (Shot Lab runner), the `60` / `both` argument (Play Lab runner and sweep), or `-shotlab-hz` /
`-playlab-hz`.

**Fast-forward (Simulator only):** put `FAST=8` in front of any runner line to run 8 physics steps of exactly 1/120 s
per drawn frame — about 4× real time, 8× the normal lab speed (`FAST=8 tools/playlab_sweep.sh`). Tested on Grey
Invasion: shot windows and robot results match a normal run within run-to-run noise. It takes no screenshots, so run at
normal speed when you want new hall-of-fame pictures, and spot-check against a normal run now and then.

### On the pause card

| Button | What it does |
|---|---|
| **Shot Lab** | Runs the Shot Lab on this table (~15–40 min; best in the Simulator). |
| **Lab: …** | The Shot Lab with the table set up a special way: GI *bank down*; Cthulhu *Cthulhu up*, *sigils down*, *ritual*; Monsoon *devil raging*; Lamplight *books down*, *cat on mantel*, *cat by kettle*. |
| **Sling Lab** (Cthulhu) | Measures the slingshots. |
| **Play Lab** | All four skills at 120 Hz (~30 min in the Simulator). |
| **Play Lab · quick** | One expert game at the device's own rate, 3-minute cap; the report is shared when done. |
| **Watch the robots** | The robots play at real speed with sound and camera, skill after skill; nothing is saved. Menu stops it. |
| **Record me** | You play one game while the lab watches; the report is shared at the end. Feeds `playlab_calibrate.py`. |
| **What-if** | Type overrides (see below) — e.g. `Lab.nudge=0, Mon.calmPush=900`. Applies at once, until the app quits. |

Table buttons such as *Skip Wave*, *Light Ritual* or *Dust devil* jump the rules ahead for testing.

### From the Mac's Terminal (unattended, in the Simulator)

Run these from the project folder. Each builds the Debug app (unless `SKIP_BUILD=1`), boots the Simulator, launches
the lab, waits for the app to quit and prints the results. Table names: `greyinvasion`, `cthulhu`, `monsoon`,
`lamplight`, `grandtour`, `chomp`. Restart the Mac before a long run: after many hours the Simulator can stop drawing.

**Shot Lab** — `tools/shotlab_run.sh TABLE [SCENARIO] [FLIPPERS] [START]`

```
tools/shotlab_run.sh monsoon                          # the whole sweep, every flipper
tools/shotlab_run.sh lamplight booksdown left,right   # a scenario, two flippers
tools/shotlab_run.sh cthulhu "" "" inlane             # balls fed down the inlane instead of cradled
tools/shotlab_run.sh chomp "" "" scatter              # the stuck-ball finder (below)
```

- Scenarios: `bankdown` (GI); `cthulhuup`, `sigilsdown`, `ritual` (Cthulhu); `devilraging` (Monsoon); `booksdown`,
  `catmantel`, `catkettle` (Lamplight).
- Starts (4th argument, or `START=`): `cradle` (default), `inlane` (a wire-return drop at 300 pt/s), `drop` (a ball
  falling onto the flipper), `hold` and `holdfast` (the flipper raised and held, to measure catches; `holdfast` feeds
  at 1,000 pt/s), `scatter` (the stuck-ball finder).
- **The stuck-ball finder** (`scatter`): balls dropped at random points all over the table with random speeds and
  directions, flippers at rest (`DROPS=150`). A ball that sits still 4 s gets one flip of every flipper; if
  it still hasn't moved 2 s later it's **stuck**. Afterwards `tools/shotlab_stuck.py` (run for you) groups the stuck
  spots, says whether real balls in the table's Play Lab replays ever go there (a trap in play vs. a drop inside a wall),
  lists rests that only a flip freed, and draws a map over the table (an `.svg` beside the results).

**Play Lab** — `tools/playlab_run.sh TABLE [GAMES] [HZ] [SKILLS]`

```
tools/playlab_run.sh lamplight                        # 2 games per skill (~30 min)
tools/playlab_run.sh greyinvasion 12 120 expert       # one skill, one rate
tools/playlab_run.sh monsoon plunge                   # the plunge sweep (no flipping, every plunger power)
```

- `GAMES` per skill and rate (default 2); `HZ` = `120` (default), `60` or `both`; `SKILLS` = a comma list
  (`beginner,intermediate,advanced,expert`, or `custom`).
- Environment: `SKIP_BUILD=1` reuse the last build · `BUILD_ONLY=1` build and stop · `DEVICE="iPhone 18 Pro Max"`
  which Simulator · `CAP=480` seconds before a game is closed · `IDLE_MIN=25` minutes without a write before a stalled
  run is stopped · `FRESH_BOOT=0` don't reboot the Simulator first · `OVERRIDE="…"` what-ifs · `CUSTOM="…"` the custom
  skill's profile · `FAST=8` fast-forward (above).

**Sweep (overnight)** — `tools/playlab_sweep.sh [GAMES] [HZ] [TABLES…]`

```
tools/playlab_sweep.sh                                # every table, 2 games per skill
BASELINE=latest tools/playlab_sweep.sh 6             # compare with the newest earlier sweep
tools/playlab_sweep.sh 2 both lamplight monsoon       # just these tables
```

Builds once, runs each table, retries a failed table once after rebooting its Simulator, then writes
`ShotLab/sweep-STAMP.html` comparing the tables and refreshes the hall of fame. If the index or hall-of-fame step
fails it says so loudly (banner, bell, notification) and exits with an error. Environment: `BASELINE=latest` or a
sweep stamp · `UNTIL_TIGHT=0.5` keep adding games until the advanced/expert drains-per-minute bands are within ±0.5
(don't go much below ~0.4: tighter bands take many hours) · `BUDGET_MIN=60` extra minutes per table for that ·
`PARALLEL=2` two tables at once on cloned Simulators (needs the memory) · `SKIP_BUILD=1`.

### Launch arguments (Xcode scheme or `simctl launch`)

| Argument | Meaning |
|---|---|
| `-shotlab TABLE` | Open the table, run the Shot Lab, quit when saved. |
| `-shotlab-scenario NAME` · `-shotlab-flippers left,right` · `-shotlab-start inlane` · `-shotlab-hz 120\|60\|both` · `-shotlab-drops N` | As the runner's arguments above. |
| `-lab-fast N` | Fast-forward: N fixed 1/120 s physics steps per drawn frame (Simulator, Debug; either lab). |
| `-playlab TABLE` | Open the table, run the Play Lab, quit when saved. |
| `-playlab-games N` · `-playlab-hz 120\|60\|both` · `-playlab-skills expert,custom` · `-playlab-cap SECONDS` | Games per skill and rate, rates, skills, game cap (default 480 s). |
| `-playlab-plunge [REPEATS]` | The plunge sweep. |
| `-playlab-custom "base=intermediate,sigma=0.025,catch=0.30"` | The custom skill's profile. |
| `-override "Lab.nudge=0,Mon.calmPush=900"` | What-if overrides. |

### What-ifs and the custom skill

**Overrides** change a tunable without editing code; every report records the ones it ran with, so an A/B needs no
rebuild. Today's names (default in brackets): `Mon.calmPush` (600), `Mon.ragingPush` (1600), `Mon.calmBend` (0.00045),
`Mon.ragingBend` (0.0025) for Monsoon's dust devil; and switches for the robots' moves, on unless set to 0 —
`Lab.nudge`, `Lab.deadBounce`, `Lab.postPass`, `Lab.mbTrap`. A misspelled name is silently ignored (but still
recorded). New tunables go in `LabOverrides.swift`.

**The custom skill** is a robot that plays like a recorded player: the habits of a base skill (aiming, nudging, the
expert's moves, plunging) with its own timing (`sigma`, seconds) and catch rate (`catch`, 0–1). Record a few games
with **Record me**, then run `playlab_calibrate.py` on the report; it prints the exact runner line, for example:

```
CUSTOM="base=intermediate,sigma=0.025,catch=0.30" tools/playlab_run.sh lamplight 6 120 custom
```

### Reading the results

| Tool | What it does |
|---|---|
| `playlab_report.py REPORT.json --html` | The Play Lab page: scores, drains, objectives, aims, time per ball against the design targets, heat maps, time-to-objective curves, and a replay player over the table's art. Also `--tracks`, `--heat`, `--curves` (SVGs), `--checks`, `--precise`, `--tightness`. |
| `playlab_index.py --out ShotLab/sweep-X.html REPORTS… [--baseline latest]` | One page comparing tables (what the sweep writes). |
| `playlab_merge.py --out MERGED.json A.json B.json` | Merges runs of the same table into one report. |
| `playlab_calibrate.py RECORDING.json [ROBOT REPORTS…]` | Which robot you play like, and the custom skill's profile. |
| `playlab_halloffame.py [--since 2026-11-01]` | Keeps the robots' best game per table and skill in `GreyInvasionPinball/HallOfFame/` (shown in the app). |
| `lmp_econ_sim.py --from REPORTS…` | The Lamplight's collection pace from real evenings (books, ultras, the catalog). |
| `shotlab_windows.py SHOTLAB.json [--map map.svg]` | The Shot Lab's timing windows per flipper and rate; `--map` draws the flips over the table. |
| `shotlab_stuck.py SCATTER.json [--svg map.svg]` | The stuck-ball finder's report: stuck spots, rests a flip freed, and a map. |
| `shotlab_analyze.py SHOTLAB.json` | Turns timing windows into per-skill shot odds. |

File names: `ShotLab/shotlab-TABLE-…-STAMP.json` (the scenario and start in the name), `ShotLab/playlab-TABLE-STAMP.json` (+ `.html` and a
folder of screenshots), `ShotLab/sweep-STAMP.html/.json/.log`. The history of every lab round is in `docs/HANDOFF.md`.

## Credits

Built by Aaron Tilley with Claude. Kenney (kenney.nl) CC0 art and sounds, Orbitron and Cinzel fonts (SIL OFL 1.1);
Monsoon's desert-storm painting was generated with ChatGPT from Aaron's description; everything else was made for these
tables. Full list in [CREDITS.md](CREDITS.md).
