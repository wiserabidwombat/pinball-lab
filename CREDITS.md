# Pinball Lab — credits

Pinball Lab by Aaron Tilley, built with Claude, in Swift, SwiftUI and SpriteKit. Shown in the app from the home screen's Credits button (LabCreditsView in LabStory.swift); each table also keeps its own credits screen.

## Shared

| Asset | File | Source | License |
|---|---|---|---|
| App icon (flask, pinball, orbit ring) | Assets.xcassets/AppIcon.appiconset/AppIcon.png | Drawn for Pinball Lab (tools/art_lab_icon.py) | Original, no license needed |
| Orbitron font (variable) | Orbitron.ttf | Matt McInerney, Google Fonts (github.com/google/fonts, ofl/orbitron) | SIL Open Font License 1.1 |

## Table 01 · Orbit Pinball

| Asset | File | Source | License |
|---|---|---|---|
| Planets, asteroids, wormhole ring, stars, nebula, ball | Assets.xcassets/OrbitArt (orbit_*) | Kenney (kenney.nl): Planets and Space Shooter Remastered | CC0 1.0 (public domain) |
| Sound effects (13 orbit_sfx_*.wav) | OrbitSounds/ | Kenney (kenney.nl): Sci-fi Sounds and Impact Sounds | CC0 1.0 (public domain) |

## Table 02 · Grey Invasion

| Asset | File | Source | License |
|---|---|---|---|
| Playfield, ball, shadow and all table art | playfield.png, ball.png, ballshadow.png, … | Drawn for this table (tools/*.py in the Project) | Original, no license needed |
| Sound effects (28 sfx_*.wav) | Sounds/ | Kenney (kenney.nl): Sci-fi Sounds 1.0 and Impact Sounds; converted, trimmed and levelled by tools/make_sfx.py | CC0 1.0 (public domain) |
| Grey Invasion's original icon (no longer the app icon) | tools/art_icon.py | Drawn for this table | Original, no license needed |

## Table 03 · Cthulhu Rising

| Asset | File | Source | License |
|---|---|---|---|
| Table art (lower table, flippers, plunger) | Assets.xcassets/CthArt (cth_*) | Modelled and rendered in Blender for this table (tools/cth_floor_lower.py, cth_render_lower.py, cth_render_parts.py) | Original, no license needed |
| Cinzel font (lettering printed in the table art; the font file isn't bundled) | — | The Cinzel Project Authors, Google Fonts (github.com/google/fonts, ofl/cinzel) | SIL Open Font License 1.1 |
| Sound effects: bells, gongs, chants, the rumble, Cthulhu's roar and squelches; the Awakening drone loop | CthSounds/cth_sfx_*.wav, cth_loop_awakening.wav | Synthesized for this table (tools/cth_make_sfx.py, cth_make_loops.py) | Original, no license needed |
| Sound effects: flippers, bumpers, slings, targets, holes, gates, plunger (mixed into some of the above) | CthSounds/cth_sfx_*.wav | Kenney (kenney.nl): Impact Sounds; converted, trimmed and levelled by tools/cth_make_sfx.py | CC0 1.0 (public domain) |

## Table 04 · Monsoon

| Asset | File | Source | License |
|---|---|---|---|
| Desert storm watercolor (the playfield painting and the card picture) | Assets.xcassets/MonArt/mon_lower, mon_upper (+ _sketch), mon_lab_thumb (tools/mon_floor.py, mon_lab_thumb.py) | Generated with ChatGPT (OpenAI) from Aaron Tilley's description | AI-generated for this table; OpenAI's terms of use assign the output to the user |
| Table art and parts (cabinet, rails, guides, slings, storm-cloud bumpers, saguaro targets, flippers, spinner) | Assets.xcassets/MonArt/mon_* | Modelled and rendered in Blender for this table, with a watercolor and pencil pass (tools/mon_render_lower.py, mon_render_table.py, mon_watercolor.py, mon_upper_art.py, mon_render_parts.py, mon_parts_sketch.py, mon_render_flippers.py, mon_render_flipper_upper.py, mon_render_spinner.py) | Original, no license needed |
| Cinzel font (lettering printed on the apron; the font file isn't bundled) | — | The Cinzel Project Authors, Google Fonts (github.com/google/fonts, ofl/cinzel) | SIL Open Font License 1.1 |
| Sound effects: thunder, raindrops, rain, brush washes, chimes, sand, the helix whir (mixed into most) | MonSounds/mon_sfx_*.wav | Synthesized for this table (tools/mon_make_sfx.py) | Original, no license needed |
| Storm bed loops: desert wind and cicadas, distant thunder, rain, birds after the storm | MonSounds/mon_loop_*.wav | Synthesized for this table (tools/mon_make_loops.py) | Original, no license needed |
| Sound effects: flippers, slings, gates, spinner, holes, kickback, plunger, standups, captive ball, diverter | MonSounds/mon_sfx_*.wav | Kenney (kenney.nl): Impact Sounds; converted, trimmed and levelled by tools/mon_make_sfx.py | CC0 1.0 (public domain) |
