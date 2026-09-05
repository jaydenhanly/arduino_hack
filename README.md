# Pixel Shift v0.2.1

A single run begins as Snake and changes into a maze, a crossing game, and an
inertial space shooter. Pixel watches the current run and offers a short,
controller-only conversation after victory. The player-facing UI does not name
future stages or display hidden objectives.

## Play locally

```sh
bash run.sh
bash run.sh -- --demo
bash run.sh -- --demo --no-model --seed=2026
```

Summer Engine must be installed. The logical display is 400x240, rendered at
800x480 with integer scaling. Gameplay uses the top 192 pixels; Pixel has a fixed
48-pixel panel below it. Procedural sprites and local PCM cues need no asset
downloads. Model assets are optional for gameplay.

| Handheld control | Keyboard equivalent | Action |
| --- | --- | --- |
| Joystick | Arrows or WASD | Move; select a conversation response |
| Button A | J, Enter, Space | Start, choose, replay; J fires in space |
| Button B | K, Escape | Leave dialogue; return to title from gameplay |
| Button C | L, P | Pause or resume gameplay and transformations |

Standard gamepad sticks/D-pad and A/B/X are also mapped. No mouse, typing,
network, audio, haptics, or external display output is required to understand play.

## Run rules

- One life. A fatal collision ends the run; replay begins again at Snake.
- Snake wraps screen edges, rejects reversal, grows and speeds up with apples.
- Maze movement has buffered turns. The head loses to a ghost, the tail defeats
  it. Ghosts respawn at safe, warned edge positions. Pellets, not ghost kills,
  advance the objective.
- Crossing lanes have seeded traffic with safe waiting rows. Each successful
  crossing returns the player to a safe start.
- Space movement has acceleration, inertia, a speed cap, wrapping, and shooting.
  New rocks are telegraphed before becoming dangerous.
- Each stage waits for the first relevant input before hazards advance.
- Three-second blink/glitch transformations preserve selected objects and the
  player. Score persists. Gameplay rules replace each other rather than stack.
- Victory freezes the final scene. Pixel offers three responses per turn, for at
  most three player selections, then a farewell and replay. Button B skips.

| Internal stage | Normal target | Demo target |
| --- | ---: | ---: |
| Snake apples | 10 | 3 |
| Maze pellets | 30 | 10 |
| Crossings | 3 | 1 |
| Asteroid destructions | 12 | 4 |

Targets and transition timing live in `scripts/pacing_config.gd`. These are the
roadmap's starting targets, not a claim of human-tested 60 to 90 second balance.
Normal replay picks a fresh seed. `--seed=N` makes runs repeatable. Stage and
companion RNG streams are separate so commentary cannot change gameplay.

The previous 25-apple Snake hazard implementation remains available through
stage options for legacy experiments. Walls, spiders, and mushrooms are disabled
in the release pacing profiles. The old five-life and ghost-kill-victory flows
are replaced by the full roadmap's one-life and pellet-completion rules.

## Pixel and the bundled model

Pixel keeps a current-run, in-memory journal of validated events, never raw input
or a persistent player profile. Event-driven commentary has a 12-second minimum
cooldown. Stage starts, near-completion, transformations, death and victory take
priority. Pause and development tools suspend the companion's activity clock.

Authored fallback lines appear immediately. Local Gemma may replace them with a
validated reply, but inference never holds gameplay or menu navigation hostage.
Requests carry run/stage/generation and event identity; responses from earlier states are
discarded. Victory retains the journal for the conversation. Leaving dialogue,
returning to title, or starting another run clears its memory.

Live commentary uses **LLM-authored messages**, not a supplied reply list. The
strict JSON contract permits five emotions and one UI-safe line of 1-80
characters. A separate event-linked history holds at most three displayed
comments, never inserts prose into the trusted journal, and replaces the
fallback record only after generation passes validation and freshness checks.
Recent repeated phrases are rejected. The prompt and chat-template token count
must fit the 1024-token runtime context with space reserved for output.

Post-victory dialogue remains model-selected from authored candidates, with
unchanged choices. Generative commentary does not have that semantic guarantee:
the 270M model sometimes confuses old and current events despite valid JSON.
See `docs/pixel-commentary.md` for the contract, diagnostics and quality limits.
In development, F1 shows the displayed message source and fallback reason.
`pixel.diagnostics()` exposes request latency, event sequence and acceptance
counts; `llm` means generated commentary and `llm_selected` means authored dialogue.

The existing Gemma 3 270M GGUF and `llama-server` remain the only model runtime.
The server binds to `127.0.0.1`. There is no Ollama or cloud fallback.

```sh
bash tools/llm/fetch-assets.sh
bash tests/llm/run.sh
/Applications/Summer.app/Contents/MacOS/Summer --headless --path "$PWD" --script tests/ai/model_smoke.gd
/Applications/Summer.app/Contents/MacOS/Summer --headless --path "$PWD" --script tests/ai/commentary_model_smoke.gd -- --strict-grounding
OUT_DIR="$PWD/build/validation/model-rendered" bash tests/autopilot/run.sh "$PWD/tests/ai/rendered_model_probe.gd"
```

The first command downloads pinned assets when needed. Normal game operation
never downloads anything. `--no-model` disables inference for deterministic
playtesting. Dialogue still works if assets are absent or inference fails.

## Development tools

```sh
bash run.sh -- --playtest --no-model --seed=2026
```

| Key | Action |
| --- | --- |
| F1 | Open/close tools |
| F2 / F3 | Previous/next stage checkpoint |
| F4 | Start, midpoint, near-completion preset |
| F5 | Reconstruct preset |
| F6 | Toggle invulnerability |
| F7 | Complete the current objective |
| F8 | Next reproducible seed |
| F9 | Switch Normal/Demo |

Checkpoint construction initializes preceding stages and runs their objective
mechanics with temporary invulnerability. It is a development fixture, not proof
of a normal playable route. Closing tools leaves the selected stage awaiting
input. Release exports exclude both tools and tests and register no debug keys.

## Verification

```sh
bash tests/roadmap/run.sh
```

The runner records fresh evidence in `builds/checks/roadmap/run-*`, checks exit codes
and engine logs, runs stage/AI/coordinator unit probes, rendered continuous runs,
and layout fixtures. Set `RELEASE_PACK` to a freshly exported PCK to include
isolated release-pack verification. `SUMMER_BIN` overrides the engine.
Python 3 is required for evidence validation. See `VERIFICATION.md` for executed
results and remaining checks. Legacy probes under `tests/autopilot/` describe the
old two-stage rules; the roadmap runner is the current acceptance entry point.

## Uno Q and hardware feedback

```sh
bash tools/llm/build-uno-bundle.sh
```

The bundle is `build/game-linux-arm64.zip`. Model weights and native libraries
live beside the executable under `llm/`, outside the PCK. Exporting a ZIP is not
proof that it runs on the board.

`scripts/controller/` isolates every Uno Q hardware concern from gameplay code,
so `game_flow.gd` only ever calls a small, hardware-agnostic API:

- `joystick_input.gd` registers the four movement actions (keyboard, D-pad,
  analog stick) and resolves them to a direction (`direction_for`, for
  discrete input) or a continuous vector (`vector`, for polled movement).
- `button_input.gd` registers the three face buttons (and their keyboard
  equivalents) as confirm/cancel/pause/shoot. Kept separate from the joystick
  so installing one can never leak the other's bindings.
- `vibration_controller.gd` sizes and rate-limits the vibration-motor pulse
  for a gameplay cue (`collect`, `danger`, `transform`, `death`, `victory`,
  `checkpoint`).
- `light_controller.gd` builds the blue 13x8 LED-matrix frame for the same
  cues, plus `comment`, clamping the bottom progress row to [0, 1].
- `hardware_feedback.gd` is the single node `game_flow.gd` calls
  (`emit_feedback(kind, progress)`, `advance(delta)`); it just coordinates the
  vibration and light controllers above and keeps their combined event
  history (`last_event`, `recent_events`, `feedback_requested`).
- `vibration_transport.gd` is `hardware_feedback.gd`'s `transport` Callable —
  the only piece that reaches real hardware. It POSTs `{"ms": pulse_ms}` to
  `/api/vibrate` on the board's bridge, an endpoint the board's install step
  patches in specifically for this game (see
  `~/summer-uno-q/board/install-game.sh`) so its own objective events drive
  the buzz instead of the bridge's generic per-keypress click. Which loopback
  address actually reaches that separate, persistent bridge container from
  inside this game's own App Lab container isn't settled by anything in this
  repo, so it fires at both `127.0.0.1` and `172.17.0.1` (the bridge's own HID
  injector reaches the host via the latter, its Docker bridge gateway) —
  whichever is unreachable fails silently. Failures log to
  `vibrate-debug.log` next to the game directory (host-visible) so a mismatch
  is diagnosable on the board.

The vibration pulse reaches real hardware through the transport above; the
LED matrix does not — its desktop mock is tested (see `tests/hardware/`
below) but the supplied kit exposes no game-facing matrix RPC. No board
scripts are modified to work around that boundary. Gameplay remains readable
without either adapter.

Physical deployment must follow `/Users/j/summer-uno-q/SKILL.md` and its `board/`
scripts exactly. The app name and icon must be confirmed for each deployment.
No improvised adb, container, firmware or installer commands are appropriate.

### Pre-deploy hardware validation

```sh
bash tests/hardware/run.sh
```

Runs one headless, logic-only probe per hardware component — joystick,
buttons, vibration, light (matrix output) — under `tests/hardware/`. No board or rendering is required; each probe drives
its `scripts/controller/` module directly with synthetic input events and cue
calls, and the runner fails on a nonzero exit, a missing completion marker,
or a script/parse error in the log. Run this before every physical deploy, in
addition to `tests/roadmap/run.sh`, to catch a broken binding or feedback
regression before it reaches the board.

## Code map

- `game_flow.gd`: run lifecycle, stage handoffs, input routing, score, pause/replay.
- `snake_stage.gd`, `maze_stage.gd`, `frogger_stage.gd`, `asteroids_stage.gd`:
  stage rules, deterministic simulation and semantic events.
- `pacing_config.gd`, `run_rng.gd`: objectives and independent seeded streams.
- `transition_director.gd`, `presentation_director.gd`, `game_board.gd`:
  hard-cut transformations and stage presentation.
- `pixel_panel.gd`: avatar expressions, stable panel and conversation layout.
- `ai/`: trusted journal, commentary prompt/history, authored fallbacks, validation, adapter and controller.
- `llm/llm_service.gd`: reusable local inference process and HTTP client.
- `controller/`: joystick, buttons, vibration, and light —
  see "Uno Q and hardware feedback" above.
- `retro_audio.gd`: local sound cues.

All code-map paths are under `scripts/`. Sensor mechanics, AI-directed gameplay,
side quests, hybrid stages, persistent memory and phone audio remain deferred.
