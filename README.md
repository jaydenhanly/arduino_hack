# Pixel Shift v0.2

A single game that changes its rules in front of you. Wake a pixel, grow a snake, eat 25 apples, then watch your body become a maze. The remaining tail is your weapon against one pursuing ghost.

## Play locally

From the repository root:

```sh
bash run.sh
```

The launcher uses the installed macOS Summer Engine. Set `SUMMER_BIN` to use another installation. You can also open `project.godot` in Summer and run its main scene.

- Joystick or arrow keys move. In Snake, the last valid turn before a grid tick wins, and direct reversal is rejected. Maze turns remain buffered until the requested direction opens.
- Button A starts, retries after damage, and replays after victory or game over. Enter and Space also confirm locally.
- Button B returns to the title. Escape also works locally.
- Button C pauses and resumes, including during the transformation. P also pauses locally.

Start with five lives. Apples score 10, pellets score 5, and defeating the ghost scores 100. Damage resets the current stage's local progress but preserves your total score and remaining lives. A retry waits for movement input. Replay starts from Snake with a fresh score and five lives.

The ghost moves more slowly than the player and shows an outlined next cell shortly before moving. Its head contact is dangerous; lure it into one of the three tail cells. Pellets are optional points, not a victory requirement. The transformed maze waits for a fresh direction before the chase starts.

## Scope decisions

The reference is `../workspaces/ai-game-console-hackathon/game-v0.2.md`. This implementation keeps its two-stage loop, with these concrete interpretations:

- The 25th apple scatters into pellets. Previously eaten apples no longer exist.
- The head and first three body cells stay in place. The remaining four segments slide and stretch into wall blocks. Walls avoid the retained player and ghost, and the walkable floor remains connected.
- Transformation lasts 2.4 seconds. It uses the same board and world coordinates, without a fade or scene cut. Movement is frozen during it, but pause and return to title still work.
- Maze retries reconstruct the entry state captured from that run's Snake completion, rather than loading an unrelated canned maze.
- A small original bitmap alphabet replaces the font attachment, which was not present locally. All art and square-wave sound effects are generated locally. There are no runtime downloads or external dependencies beyond Summer.
- The normal seed is 2026. Replay is deliberately repeatable.

The logical image is 400x240, presented at exactly 800x480 with nearest-neighbor integer scaling, a four-color palette, Compatibility rendering, and a 60 FPS cap.

## Development playtesting

Press F1 in the editor/local debug build, or launch directly into the tools:

```sh
bash run.sh -- --playtest --seed=2026
```

The tools pause gameplay while open. The seed stays visible when the tools are closed.

| Debug key | Action |
| --- | --- |
| F1 | Open or close tools |
| F2 | Select Snake at the current preset |
| F3 | Select Maze at the current preset |
| F4 | Cycle start, midpoint, near-completion |
| F5 | Restart current stage |
| F6 | Toggle invulnerability |
| F7 | Complete current objective through its actual rules |
| F8 | Increment seed and reconstruct current preset |

Snake presets contain zero, twelve, or twenty-four apples. Maze entry first simulates real Snake collection using the selected seed. Maze midpoint collects pellets; near-completion walks to a tail trap. These shortcuts do not teleport into uninitialized stages. F7 from Snake shows the full transformation. Invulnerable collisions stop the offending movement rather than putting the head outside the board or inside a ghost.

The release preset excludes `scripts/dev/` and `tests/`. Its `pixel_shift_release` feature disables the debug loader even when the pack is run with an editor executable. Debug inputs are never registered in that pack.

## Checks

```sh
# Real rendered run from title through 25 apples, shift, ghost defeat, and replay.
bash tests/autopilot/run.sh

# Snake regressions, including input, all collision types, and seeded spawning.
OUT_DIR="$PWD/builds/checks/snake" bash tests/autopilot/run.sh "$PWD/tests/autopilot/snake_probe.gd"

# Checkpoint input timing regression.
OUT_DIR="$PWD/builds/checks/checkpoints" bash tests/autopilot/run.sh "$PWD/tests/autopilot/checkpoint_probe.gd"

# 32 seeds, connected layouts, tail traps, audio signal, and palette.
OUT_DIR="$PWD/builds/checks/variations" bash tests/autopilot/run.sh "$PWD/tests/autopilot/variation_probe.gd"
```

The runner requires Python 3 to validate its JSON report. Default results and rendered frames land in `tests/autopilot/out/`. `OUT_DIR` keeps additional runs separate. The original waypoint template remains in `tests/autopilot/autopilot.gd`; it is not the current game's acceptance test.

Automated probes drive actual input for the full game, then use explicit fixtures for collision edge cases. Rendered frames have been visually inspected. These are automated playtests, not a claim that a human played on the handheld. See `VERIFICATION.md` for the evidence and limitations.

## Release pack

```sh
/Applications/Summer.app/Contents/MacOS/Summer --headless --path "$PWD" --export-pack 'Pixel Shift release' "$PWD/builds/pixel-shift-v0.2.pck"
/Applications/Summer.app/Contents/MacOS/Summer --headless --main-pack "$PWD/builds/pixel-shift-v0.2.pck" --script "$PWD/tests/autopilot/release_check.gd"
```

`builds/pixel-shift-v0.1.zip` preserves the passing Snake source checkpoint. The v0.2 PCK is game data, not a standalone executable or proof of handheld performance. Physical deployment requires separate approval and the exact `/Users/j/summer-uno-q/SKILL.md` workflow. No board scripts were changed and no hardware was deployed.

## Code map

- `scripts/game_flow.gd` owns score, lives, stage changes, menus, pause, and replay.
- `scripts/snake_stage.gd` and `scripts/maze_stage.gd` own deterministic grid mechanics and emit events.
- `scripts/game_board.gd` draws both stages and interpolates the transformation.
- `scripts/grid.gd` defines board geometry and input bindings.
- `scripts/pixel_art.gd` contains the palette, bitmap type, and tiny sprites.
- `scripts/retro_audio.gd` creates and plays short local PCM sound cues.
- `scripts/light_sensor.gd` reads the board's ambient light reading and fades the palette to match.
- `scripts/dev/playtest_manager.gd` owns development-only checkpoints.

Frogger, Asteroids, LLM-driven gameplay, networking, persistence, and additional cartridges remain deferred.

## Light sensor theme

On the Uno Q, a Modulino Light module feeds ambient lux into `scripts/light_sensor.gd` (an autoload), which fades `scripts/pixel_art.gd`'s palette between light mode (dark ink on green) and dark mode (green ink on black) — see `PixelArt.apply_light_level()`. It reads `/game/light_state.json`, written by the board's bridge; that file only exists on the board, so a desktop run always stays in light mode.

## Bundled local LLM

Gemma 3 270M is available through a reusable local service. It is deliberately not connected to gameplay or UI yet.

Fetch the pinned model and macOS/Linux ARM64 runtimes, then run a real local inference check:

```sh
bash tools/llm/fetch-assets.sh
bash tests/llm/run.sh
```

Future game code can instantiate `res://scripts/llm/llm_service.gd`, add it to the scene tree, then call `await start()`, `await generate(prompt)`, and `stop()`. The server listens only on `127.0.0.1`.

Build a fresh Uno Q export with the Linux runtime and model inside the same ZIP:

```sh
bash tools/llm/build-uno-bundle.sh
```

The result is `build/game-linux-arm64.zip`. Model weights and native libraries remain outside the Godot `.pck` under the archive's `llm/` directory.
