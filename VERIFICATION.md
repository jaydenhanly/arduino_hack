# Verification record

Verified locally on September 5, 2026, using the installed Summer Engine 0.5.65 on macOS. Highest implemented and automatically verified version: v0.2.

## Executed checks

| Suite | Result | Evidence |
| --- | --- | --- |
| Headless import and launch | Passed, no parser errors | Local Summer CLI runs with explicit `retro-ai` project path |
| Snake rendered regression | 123 boolean checks passed | `builds/checks/snake/results.json` |
| Full rendered v0.2 run | 50 boolean checks passed | `tests/autopilot/out/results.json` |
| Checkpoint input timing | 5 boolean checks passed | `builds/checks/checkpoints/results.json` |
| Seed and edge-case variations | 68 boolean checks passed | `builds/checks/variations/results.json` |
| Release pack isolation | 8 checks passed | `tests/autopilot/release_check.gd` executed against the exported pack |
| Shell syntax | Passed | `bash -n retro-ai/run.sh retro-ai/tests/autopilot/run.sh` |

All four rendered suites finished with empty runtime-error and frame-warning lists. The final full run took about 19 seconds and consumed five apples in 58 grid moves. It used normal input from the title to Maze victory and full replay, without development-stage entry or invulnerability on that path.

The Snake regression covers the blinking start state, first-direction stretch, four movement directions, reversal rejection, apple growth/scoring, every collision type, stage reset, pause, lives, game over, replay, title return, and deterministic free-cell apple placement. Damage cases use explicit state fixtures to make each collision reproducible.

The full run checks the exact fifth-apple gate; retained head/tail cells; wall, apple, and ghost source mappings; pause during the shift; score/life continuity; connected floor; buffered turns; pellet scoring; both head/ghost collision directions; Maze restart; tail victory; and all six development presets.

Variation checks cover seeds 0 through 31, a non-default score/life carry-over, actual invulnerable ghost contact, completing a paused shift, and deterministic ghost choices. The rendered capture contains exactly four colors at 400x240. The game window measures 800x480. The generated audio signal reached approximately -20.4 dB on the engine's test mixer.

## Visual inspection

Inspected captured title, initial pixel, mid-transformation, Maze entry, normal victory, and development tools frames. The first implementation obscured the initial pixel with a hint panel; that was fixed before the Snake gate was archived. Transformation frames show body blocks moving and stretching while pellets spread from the fifth apple, with the retained player visible throughout.

The final full-run frame sequence is in `tests/autopilot/out/`. Images are JPEG evidence from the supplied harness; JPEG compression is not used by the game renderer.

## Build artifacts

- `builds/pixel-shift-v0.1.zip` is the passing Snake source recovery checkpoint.
- `builds/pixel-shift-v0.2.pck` is the release game-data pack, approximately 26 KiB.
- The release pack starts at the title, initializes Snake, contains neither development nor test scripts, and registers no development input actions.

## Limitations

- No human manual playtest or physical Arduino UNO Q test was performed. The automated normal-input run proves the loop is winnable; it does not establish human difficulty, handheld legibility, hardware input mapping, real speaker quality, or board performance.
- No standalone ARM64 executable was exported or deployed. The release PCK still needs a compatible Summer runtime. Physical deployment remains gated on approval and the prescribed board workflow.
- Summer emits an ObjectDB warning during shutdown. A verbose release smoke run identifies the object as the engine's `AuthManager`. Headless editor import/export also emits shutdown CanvasItem warnings. The rendered gameplay reports contain no runtime errors.
- No known gameplay test failures remain. Frogger, Asteroids, sensors, networking, local models, persistence, and additional cartridges remain outside this build.
