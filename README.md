# DON'T LOOK BACK

A dark, cinematic 2D psychological-horror survival runner for Android (Godot 4, GDScript, zero third-party dependencies).
You run automatically. Something is always behind you. You can turn around and look — and it gets closer the longer you do.

* **Engine:** Godot 4.3+ (standard build, GL Compatibility renderer — runs on low/mid Android devices)
* **Orientation:** landscape, sensor-landscape (both directions); fills any aspect ratio with no black bars
* **Size:** ~2.5 MB of assets (sounds, fonts, logo), no network, only the `VIBRATE` permission

> **Status — please read.** The whole project was authored without access to a Godot editor or the Android SDK, so it
> has been statically checked (`tools/lint_gd.py`) and its audio/icons were generated and verified, but it has **not been
> run inside Godot yet**, and **no APK binary is included** — an APK can only be produced by Godot's exporter.
> Follow [`docs/BUILD_ANDROID.md`](docs/BUILD_ANDROID.md) (about 15 minutes, or push to GitHub and let CI build it).
> On the very first open, expect to fix at most a few small engine-version nits; the code is small, typed and commented.

## Controls

| Action | Touch (landscape) | Keyboard |
|---|---|---|
| **Jump** (hold = higher, tap = short hop) | right thumb, big button | Space / W / Up |
| **Slide** (hold to stay low; in air = fast-fall dive) | right thumb, left button | S / Down |
| **Dash** (i-frames, smashes anything but pits; 2 s cooldown) | left thumb, small button | Shift / D / Right |
| **Look back** (hold) | left thumb, big button | A / L / Left |
| Pause | top-right button / Android Back | Esc / P |

Multi-touch is real: hold LOOK with one thumb while jumping and sliding with the other.

## Art direction

*Moonlit folk-horror, drawn as layered silhouettes.* A limited palette — **ink indigo, bone white, ember amber, one crimson accent** — and a single idea: **the runner carries the only warm light in the world.**

* **Lighting.** A two-pass shader pipeline. Pass A turns the world dark and cold and lights it from the runner's swinging lantern (warm bounce near the flame, flicker, blackout events). An additive *glow layer* sits above it so rims, shards, windows and the creature's eyes never get swallowed. Pass B adds bloom, chromatic aberration, a filmic grade, vignette, grain, and the creeping-red edge that tracks the creature.
* **Depth.** Six parallax planes with atmospheric haze (stars → moon + rays → mountains → pine ridge → ruined chapels → dead trees → graveyard → lit path), mist banks, fast foreground grass and branches, soft contact shadows, ambient occlusion under the horizon, and shadows thrown *away from the lantern* (longer the closer they are to it).
* **Corruption.** Distance drains the sky from dusk-violet to blood-black, the moon swells and reddens, birds circle, eyes open in the trees, the ground cracks and glows, embers turn red, the creature grows.
* **Readable hazards.** Every hazard is big, shaded and wears the colour of its answer: **amber = jump, cyan = slide, red = dash** — a rim light, a coloured decal on the ground, and a floating chevron. Smashing one with a dash shatters it into chunks, sparks and a shockwave ring with hit-stop and camera punch.
* **The runner.** Hooded, with a lagging coat, hood tail, scarf and a pendulum lantern. A real gait cycle (foot plants matched to ground speed, double-frequency hip bounce, counter-swinging arms), landing crouch, stretch on take-off, lean into acceleration, IK legs/arms blended between run / jump / fall / slide / dash.
* **The creature.** Gaunt stalker with running legs, spine spikes, ragged cloak, hinged jaw that opens the longer you stare, reaching claws, and shadow tendrils crawling toward your feet.

## UI

Minimal, glassy, edge-anchored. Fonts: **Gloock** (titles), **Big Shoulders Bold** (numerals), **Instrument Sans** (labels) — all SIL OFL, bundled in `assets/fonts/` with their licences. All icons are drawn as vectors in code (`ui_draw.gd`), so there is nothing to blur at any resolution. HUD: distance + score top-left, a segmented **"it" proximity meter** with an eye that opens as it closes in, shard counter + multiplier + pause top-right, timer rings for power-ups, floating score popups, and glass thumb buttons (the LOOK ring fills as you stare; DASH shows its cooldown). Menus: logo screen over the live game, Scarves and Settings pages, pause card, and a "CONSUMED" result card with counting score and NEW BEST badge. Scene changes fade through black.

## Fills every screen

The project uses stretch mode `canvas_items` + aspect `expand`, so the viewport always covers the whole display — **no black bars** on 16:9, 18:9, 19.5:9, 20:9, 21:9, tablets, or foldables. Gameplay stays in a centred 16:9 design rect (so difficulty is identical everywhere); the sky, ground, parallax and the HUD extend to the real edges, HUD controls anchor to the real corners, and notch / cut-out insets are respected (`Cfg.update_view()` in `scripts/core/cfg.gd`).

## The rules of the world

* **Read the rim colour.** Gravestones and bone tusks → jump. Pits → jump. Hanging gibbets and crows → slide. Thorn walls → dash through (the only thing that can pass them).
* **The creature.** `gap` is its distance behind you. Looking closes the gap faster the longer you stare (and it remembers — peeks add up). After 1.5 s of staring it **lunges**. Hits knock it closer; if it reaches you, you're consumed.
* **Risk / reward.** Every ~10–18 s something glints *behind* you (Lantern: pushes it back and widens your light · Relic: score x2 · Ward: absorbs one hit). Turn and hold your gaze ~0.45 s to grab it — while it creeps closer.
* **Progression.** Speed ramps 500 → 1060 px/s; hazards unlock with distance (tusks/gibbets → pits → combos → thorn walls → crows → chained combos); random events: whispers, blackouts, fog, false-creature scares, creature surges.
* **Meta.** Shards unlock scarf colours (Ash · Ember · Bone · Blood · Void · Gold). Collecting shards without being hit raises the score multiplier (x1 → x3).

## Movement feel

`scripts/game/player_ctl.gd` is a small, tunable physics model: speed *eases* toward a state goal (accel 1500 / decel 2400 px/s²); coyote time (90 ms) + jump buffering (130 ms) + variable jump height + heavier fall gravity; eased dash with i-frames; hold-to-extend slide (0.36–0.95 s) and an air-dive that chains into a slide; damped-spring squash & stretch; forgiving hit-boxes; hit-stop on impacts.

## Project layout

```
dont-look-back/
├── project.godot            engine config (Compatibility renderer, landscape, autoloads)
├── export_presets.cfg       ready-made "Android" export preset (APK, arm64 + armv7)
├── assets/
│   ├── images/              launcher icons + logo (tools/generate_icons.py, generate_logo.py)
│   ├── fonts/               Gloock, Big Shoulders, Instrument Sans (+ OFL licences)
│   ├── sounds/              26 WAVs: SFX + seamless ambience loops (tools/generate_audio.py)
│   ├── music/               <- DROP YOUR MUSIC HERE (.ogg/.mp3/.wav) — auto-detected, see README.txt
│   └── shaders/             light.gdshader (lantern lighting) · grade.gdshader (bloom, aberration, vignette, grain)
├── scenes/                  main_menu · game · hud · pause_menu · game_over
├── scripts/
│   ├── autoload/            game_state.gd (save, settings, fonts, input map) · audio_manager.gd · transition.gd
│   ├── core/                cfg.gd (layout / fill-screen maths) · gfx.gd (draw helpers, IK)
│   ├── game/                game.gd (run controller) · player_ctl · creature · obstacle · world_gen · particle_system · pickup
│   ├── render/              world_renderer · glow_renderer · post_fx + background/obstacle/character/creature drawers
│   └── ui/                  hud · main_menu · pause_menu · game_over · ui_draw (icons) · fancy_button · switch_row · glass_panel
├── tools/                   build_android.sh · make_release_keystore.sh · generate_*.py · lint_gd.py
├── docs/BUILD_ANDROID.md    build, sign and publish guide
└── .github/workflows/       CI that builds the APK for you
```

Rendering is stacked layers: **world** → **light pass** (`light.gdshader`) → **glow** (additive, above the darkness) → **grade pass** (`grade.gdshader`) → **HUD**. Everything in the game world is drawn procedurally with `_draw()` — there are no sprite sheets to ship.

## Tuning cheat-sheet

| Want to change… | Edit |
|---|---|
| Jump height / gravity / coyote / buffer / slide & dash timings | constants at the top of `scripts/game/player_ctl.gd` |
| Run speed ramp, darkness curve, event timing | `_update_play()`, `_process()` in `scripts/game/game.gd` |
| How aggressive the creature is | `Creature.update()` / `rest_gap()` in `scripts/game/creature.gd` |
| Which hazards appear when, spacing, shard placement | `_spawn_pattern()` in `scripts/game/world_gen.gd` |
| Hazard look, size & colour language | `scripts/render/obstacle_drawer.gd`, `Cfg.COL_*` |
| Palette / world corruption | `scripts/render/background_drawer.gd` |
| Lighting strength, bloom, grade | `assets/shaders/*.gdshader`, `scripts/render/post_fx.gd` |
| HUD layout | `scripts/ui/hud.gd` |
| Touch-button positions/sizes | `BTN` in `scripts/ui/hud.gd` |
| Sound design | edit/re-run `tools/generate_audio.py`, or replace the WAVs (same filenames) |

## Regenerating assets / checking sources

```bash
pip install numpy pillow
python3 tools/generate_audio.py   # rewrites assets/sounds/*.wav
python3 tools/generate_icons.py   # rewrites the launcher icons
python3 tools/generate_logo.py    # rewrites assets/images/logo.png
python3 tools/check_refs.py       # verifies every cross-script call + resource path
python3 tools/lint_gd.py          # cheap static checks (indentation, brackets)
```
