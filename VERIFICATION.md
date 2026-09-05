# Verification record

Verified locally on September 5, 2026, using the installed Summer Engine 0.5.65 on macOS. Highest implemented and automatically verified version: v0.2.

## Executed checks

| Suite | Result | Evidence |
| --- | --- | --- |
| Headless import and launch | Passed, no parser errors | Local Summer CLI runs with this repository as the project path |
| Snake rendered regression | 124 boolean checks passed | `build/validation/snake/results.json` |
| Full rendered run | 90 boolean checks passed | `build/validation/full-final/results.json` |
| Checkpoint input timing | 5 boolean checks passed | `build/validation/checkpoints/results.json` |
| Seed and edge-case variations | Failed at seed 6 | The existing probe remains in `SnakeStage`, then calls `step_ghost()`; see limitations |
| Release pack isolation | 8 checks passed | `tests/autopilot/release_check.gd` executed against the exported pack |
| Local Gemma inference | Passed | Gemma 3 270M Q4_K_M loaded through `LlmService` and returned a non-empty response |
| Bundled ARM64 export | Passed | ZIP integrity, model SHA-256, separate PCK, runtime architecture, and executable mode checked |
| Shell syntax | Passed | Launch, autopilot, LLM fetch, smoke-test, and bundle scripts parsed with `bash -n` |

The full run, Snake regression, and checkpoint suite finished with empty runtime-error and frame-warning lists. The full run consumed 25 apples in 244 grid moves and reached Maze victory and replay through normal input. The variation suite stopped at its known seed-6 failure.

The Snake regression covers the blinking start state, first-direction stretch, four movement directions, reversal rejection, apple growth/scoring, every collision type, stage reset, pause, lives, game over, replay, title return, and deterministic free-cell apple placement. Damage cases use explicit state fixtures to make each collision reproducible.

The full run checks the exact 25th-apple gate; retained head/tail cells; wall, apple, and ghost source mappings; pause during the shift; score/life continuity; connected floor; buffered turns; pellet scoring; both head/ghost collision directions; Maze restart; tail victory; and all six development presets.

The variation probe passes seeds 0 through 5 before the seed-6 checkpoint failure described below. Its later checks for score/life carry-over, invulnerability, paused shifts, ghost choices, palette, and audio do not run after that failure.

## Visual inspection

Inspected captured title, initial pixel, mid-transformation, Maze entry, normal victory, and development tools frames. The first implementation obscured the initial pixel with a hint panel; that was fixed before the Snake gate was archived. Transformation frames show body blocks moving and stretching while pellets spread from the 25th apple, with the retained player visible throughout.

The final full-run frame sequence is in `tests/autopilot/out/`. Images are JPEG evidence from the supplied harness; JPEG compression is not used by the game renderer.

## Build artifacts

- `builds/pixel-shift-v0.1.zip` is the passing Snake source recovery checkpoint.
- `builds/pixel-shift-v0.2.pck` is the release game-data pack, approximately 26 KiB.
- `build/game-linux-arm64.zip` is the fresh ARM64 game export with the model and native LLM runtime, approximately 273 MiB.
- The release pack starts at the title, initializes Snake, contains neither development nor test scripts, and registers no development input actions.

## Limitations

- No human manual playtest or physical Arduino UNO Q test was performed. The automated normal-input run proves the loop is winnable; it does not establish human difficulty, handheld legibility, hardware input mapping, real speaker quality, or board performance.
- A standalone ARM64 export with the bundled LLM exists at `build/game-linux-arm64.zip`. Its Linux runtime was inspected but not executed because no physical Uno Q deployment was requested.
- Summer emits an ObjectDB warning during shutdown. A verbose release smoke run identifies the object as the engine's `AuthManager`. Headless editor import/export also emits shutdown CanvasItem warnings. The rendered gameplay reports contain no runtime errors.
- The destination's existing 25-apple variation probe fails deterministically at seed 6 before reaching Maze, then calls the Maze-only `step_ghost()` method on `SnakeStage`. The LLM port does not modify gameplay code.
- Frogger, Asteroids, sensors, LLM-driven gameplay, networking, persistence, and additional cartridges remain outside this build.
