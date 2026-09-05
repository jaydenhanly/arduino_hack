# Pixel Shift v0.2

A single game that changes its rules in front of you. Wake a pixel, grow a snake, eat 25 apples, then watch your body become a maze. The remaining tail is your weapon against one pursuing ghost. Outsmart the ghost and the walls dissolve into an arena where computer snakes hunt you.

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
- On the title screen, Button C switches the visual style between the default four-colour green palette and the Copenhagen style: a 16-colour palette, copper-green snake, maze walls drawn as Nyhavn, Børsen, Rundetårn and Rådhus, parked bicycles as Snake obstacles, and a skyline on the title. The style is not saved; every launch starts green.
- To play only the arena, launch with `bash run.sh -- --stage=arena`, or press `3` on the title screen. Every start and replay then begins in the arena with a fresh score and five lives.

Start with five lives. Apples score 10, pellets score 5, and defeating the ghost scores 100. Damage resets the current stage's local progress but preserves your total score and remaining lives. A retry waits for movement input. Replay starts from Snake with a fresh score and five lives.

The ghost moves more slowly than the player and shows an outlined next cell shortly before moving. Its head contact is dangerous; lure it into one of the three tail cells. Pellets are optional points, not a victory requirement. The transformed maze waits for a fresh direction before the chase starts.

### 03 Arena

Defeating the ghost starts a short shift: the camera pulls back so the 24x12 maze shrinks into the middle of a 48x24 arena, the walls dissolve, the ghost fades, and the pellets scatter into food. You keep your four retained cells and grow to eight as you move. You are the big, slow snake; the computer snakes are small and fast. Survive 300 seconds to win. Every piece of food scores 5, grows you by one cell up to 24, and takes 5 seconds off the clock, so eating is the fast way out. Every cell past eight makes you a little slower.

Hazards from the Snake stage return on a clock. At 60 seconds six wall blocks rise on free cells, never in the four cells ahead of your head or next to any snake's head. At 120 seconds six more walls and two spiders arrive, two more spiders at 180, and four walls plus two spiders at 240. A banner announces each wave. Walls kill any head that runs into them, yours or a computer snake's. Spiders wander one cell every 0.4 seconds, bite your head if they reach it, and eat any computer snake whose head they touch; computer snakes from generation 2 keep a one-cell distance from them. Fire burns spiders away.

The last 30 seconds are the meltdown. The border catches fire and the ring of flames advances one cell inward every 5 seconds, up to five cells deep. Fire destroys food, kills any computer snake it touches, burns your tail cells away, and costs a life if it reaches your head. Computer snakes now spawn every 5 seconds at the top generation and move 30 percent faster. The screen shakes and an alarm ticks every second. Eating food still cuts 5 seconds, so the meltdown can be shortened.

Collisions follow snake.io rules: whoever's head runs into someone else's body dies. You lose a life only when your head hits a wall, your own body, or a computer snake's body. A computer snake that runs into any part of you, including head-on, dies and counts as a KO. Retry rebuilds the same arena.

A new computer snake spawns at the start and every 30 seconds after that, three cells long, as far from the other heads as possible. Each generation is better than the one before: faster steps (0.17 s down to 0.07 s), a longer length cap, and a smarter brain. Generation 0 wanders toward food and often traps itself. Generation 1 checks reachable space before every turn. Generation 2 starts cutting in ahead of your head. Generation 3 also avoids every head's neighbours. Generation 4 predicts your next cell. Each KO is worth 50 points, and every dead snake leaves half its cells as food. Surviving the timer scores 200.

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
| F9 | Select Arena at the current preset |
| F4 | Cycle start, midpoint, near-completion |
| F5 | Restart current stage |
| F6 | Toggle invulnerability |
| F7 | Complete current objective through its actual rules |
| F8 | Increment seed and reconstruct current preset |

Snake presets contain zero, twelve, or twenty-four apples. Maze entry first simulates real Snake collection using the selected seed. Maze midpoint collects pellets; near-completion walks to a tail trap. Arena entry plays through the tail trap first; its midpoint and near-completion presets fast-forward the arena clock to 150 and 270 seconds with an invulnerable player, so later generations are already on the board. These shortcuts do not teleport into uninitialized stages. F7 from Snake shows the full transformation; F7 in Maze runs the tail trap into the arena shift; F7 in Arena runs the survival clock out. Invulnerable collisions stop the offending movement rather than putting the head outside the board or inside a ghost.

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

# Style toggle: Button C on the title, Copenhagen frames of every stage, at most 16 colours, green stays at 4.
OUT_DIR="$PWD/builds/checks/theme" bash tests/autopilot/run.sh "$PWD/tests/autopilot/theme_probe.gd"

# Arena balance: three seeds of 300 s with a simple automatic player; reports each generation's lifetime.
OUT_DIR="$PWD/builds/checks/arena_sim" MAX_SECONDS=300 bash tests/autopilot/run.sh "$PWD/tests/autopilot/arena_sim_probe.gd"
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
- `scripts/snake_stage.gd`, `scripts/maze_stage.gd`, and `scripts/arena_stage.gd` own deterministic grid mechanics and emit events. The arena also owns the computer snakes and their per-generation brains.
- `scripts/game_board.gd` draws all three stages and interpolates both transformations.
- `scripts/grid.gd` defines board geometry and input bindings.
- `scripts/pixel_art.gd` contains the palette, bitmap type, and tiny sprites.
- `scripts/copenhagen.gd` contains the Copenhagen sprites: six 70x28 landmarks, the bicycle, floor, apple and ghost. `pixel_art.gd` owns the theme switch.
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
