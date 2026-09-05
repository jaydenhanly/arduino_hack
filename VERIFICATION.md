# Verification record

## Integrated authored Maze and atomic Pixel turns, September 5, 2026

Current desktop acceptance evidence:
`build/validation/final-v021/run-NoKLTBFK/summary.json` reports all checks passed.
The existing staged Normal Maze balance change to 97 pellets is preserved;
Demo remains 10. This differs from the earlier 30-pellet request.

| Check | Result |
| --- | --- |
| Snake/Maze topology and handoff | 10,310 deterministic checks passed |
| Frogger/Asteroids | 769 checks passed |
| Pixel generation, atomic lifecycle and bounded memory | 656 checks passed |
| Coordinator | 175 checks passed |
| Feedback protocol, priorities, rate limits and missing transport | 246 checks passed |
| Four input-driven full runs | 488 report entries, 77 frames, no failed reports |
| Presentation fixtures | 7 checks, 11 frames |
| Frogger actual-input reset fixture | 12 checks, 3 frames |
| Atomic conversation/rendered text fixtures | 14 checks, 7 frames |
| Project-only Unix socket capture mock | Passed; `build/validation/final-pixel-model/feedback.log` |
| Real model commentary | 6/10 accepted, 10/10 structurally valid |
| Real model conversation | 2/10 accepted, 10/10 structurally valid; ten turns and cleanup passed |
| Model service | Smoke test passed |

Visually inspected fresh captures under that roadmap directory:
`atomic_conversation/01_authored_maze.jpg`, `02_short_commentary.jpg`, and
`03_long_commentary.jpg`. The Maze shows connected walls, constrained corridors,
central ghost and open horizontal tunnel mouths. `Eep!` and the 80-character
sample fit the panel, with the long sample using two visual rows. These use
explicit fixtures, not proof of model-generated text or human difficulty tuning.

The first separate real-model rendered run in
`build/validation/final-model-rendered/` did not pass its generated-message-display
assertion: fallback remained visible. That failure is preserved, not counted as
successful generated delivery. The one retry in
`build/validation/final-model-rendered-retry/results.json` passed: accepted original
text reached the panel, Snake moved during inference, fallback appeared immediately,
and the model process stopped. Its `03_after_inference.jpg` was visually inspected.
The displayed line was `A sudden shift in energy as I observe... a fleeting glimpse
of vibrant colors.` It fits two rows but is more abstract narration than the intended
excitable robot voice. Request latency was 1,436 ms; frame p95 was 17.245 ms before
and 17.627 ms during inference. These are desktop observations, not board guarantees.

`docs/pixel-model-review.md` records accepted, rejected, bland and broken samples.
Structural success does not establish personality quality. The current heuristic
still accepts some generic and incomplete prose. This is a remaining product
quality limitation. The known Summer AuthManager ObjectDB shutdown warning remains.

No board was touched, no new export was produced, and nothing was deployed.
All ten frozen shared-kit file hashes match `docs/shared-kit-frozen.md`, including
the modified installer and new feedback directory from the interrupted direction.
Those bytes are preserved, not approved hardware implementation. Future approved
work must complete bridge/firmware integration, then physically check raw-button
haptics disabled, semantic pulse strength/timing, all aura animations and idle
return, priority replacement, comment silence, disconnect recovery, and gameplay
frame timing. See `docs/hardware-feedback.md`. Deployment requires app name and
emoji and the prescribed Uno Q skill workflow.

## Historical live commentary baseline, September 5, 2026

The current source checkout differs from the previously exported v0.2.1 bundle.
No new ARM64 export or Uno Q deployment was performed for this change.

| Check | Result | Evidence |
| --- | --- | --- |
| Deterministic Pixel tests | 338 checks passed | `build/validation/commentary/acceptance/run-61Ecm6Vg/ai_unit.log` |
| Full gameplay and presentation regression | Passed, including four full runs | `build/validation/commentary/acceptance/run-61Ecm6Vg/summary.json` |
| Real model, existing conversation | Three conversation turns, generative commentary, legacy API and cleanup passed | `build/validation/commentary/legacy-model.log` |
| Real model-to-screen path | Accepted generated message displayed; Snake moved while inference ran; immediate fallback and process cleanup passed | `build/validation/commentary/rendered-safe-route/results.json` |
| Real generative event samples | 9 of 10 replies accepted; one repetition kept its fallback | `build/validation/commentary/model-quality-final.log` |
| Worst-case context | Pruned to one history record; 779 prompt + 128 output + 16 margin tokens fit 1024 | `build/validation/commentary/model-quality-final.log` |
| Strict grounding review | **Failed**, four non-current-stage references flagged | `build/validation/commentary/model-quality-final.log` |

The rendered test displayed "The new serpent stage was ready!" after a 1,407 ms
request. Baseline frame p95 was 19.771 ms and inference p95 was 17.402 ms on this
Mac. This is not a board performance measurement. The frame was visually
inspected in `build/validation/commentary/rendered-safe-route/03_after_inference.jpg`.

Grounding remains a model-quality limitation, not a transport failure. A real
sample referred to a ghost escaping during a traffic event. The strict review
uses conservative heuristics and can flag legitimate references too; it is
separate from JSON validity, repetition checks and proof of model delivery.
Earlier prompt trials also produced instruction echoes and copied prior speech.
The 270M model has not been replaced or fine-tuned, and semantic reliability is
not claimed. The existing Summer AuthManager shutdown warning remains.

## Previous v0.2.1 export baseline

Verified locally on September 5, 2026 with the installed Summer Engine on macOS.
The current acceptance entry point is `bash tests/roadmap/run.sh`. It checks
engine logs and completion markers as well as process exit status. The default
`tests/autopilot/run.sh` now selects the four-stage rendered probe.

| Check | Result | Evidence |
| --- | --- | --- |
| Snake and Maze rules | 6,098 checks passed | `tests/roadmap/early_stage_probe.gd` |
| Frogger and Asteroids rules | 760 checks passed | `tests/roadmap/late_stage_probe.gd` |
| Pixel journal, fallbacks, timeout and stale-response handling | 275 checks passed | `tests/ai/unit.gd` |
| Shared lifecycle and all 24 debug checkpoints | 175 checks passed | `tests/roadmap/coordinator_probe.gd` |
| Four complete input-driven runs | 464 boolean checks and 77 rendered frames | `tests/roadmap/full_run_probe.gd` |
| Layout, five emotions and all stage entries | 7 checks and 11 rendered frames | `tests/roadmap/presentation_probe.gd` |
| Actual bundled Gemma | Three validated conversation turns, commentary, legacy API and process cleanup passed | `build/validation/v021/model-smoke.log` |
| Rendering while the local model runs | Snake moved, fallback appeared immediately, live request completed, process stopped | `build/validation/v021/model-rendered/results.json` |
| Release isolation | Required stage/AI modules included; tests/dev absent; one life and correct version | `tests/autopilot/release_check.gd` |
| Current ARM64 ZIP | ZIP integrity, model SHA-256, separate PCK, ARM64 executables and runtime mode passed | `build/validation/v021/bundle-check.json` |

The consolidated final run is recorded in `build/validation/v021/final-summary.log`,
which points to its fresh `summary.json`, detailed logs and captured frames. The
model smoke test is independent of the deterministic model-disabled acceptance
suite. It exercised the actual locally bundled model, not a remote endpoint.

The real-time rendered model probe measured 65 busy frames and a 1,101 ms request
in its successful run. Baseline frame-time p95 was 17.625 ms; during inference,
p95 was 17.216 ms and the maximum was 32.659 ms. These are measurements from this
Mac, with screenshot/probe overhead, not board guarantees. Initial attempts
exceeded the eight-second startup deadline. Their fallbacks remained visible,
Snake kept moving, and frame-time p95 stayed around 17 ms. The underlying startup
delay was not conclusively diagnosed; a later attempt succeeded without a
runtime-code change. Slow startup must remain a supported fallback path.

### What the complete-run probe proves

Normal and Demo both traverse Snake, Maze, Frogger and Asteroids through actual
objectives. Two additional Demo runs exercise skipping during conversation and
during the victory payoff. Pause is checked at idle/active stages and during
transitions. The probe also causes a real Snake self-collision and verifies replay.
Coordinator regressions additionally prove that held input from a previous stage
cannot auto-start Frogger/space, while fresh firing can start space without motion.

Inputs are injected through the game's normal input handling. The probe calls
GameFlow with deterministic simulation deltas between rendered frames; it does
not modify positions, counters or collision fixtures and never enables
invulnerability. This proves an input-driven winning route, not human pacing or
real-time reaction difficulty. Separate coordinator/presentation probes use
explicit development checkpoints and are not presented as normal playthroughs.

### Visual review

Inspected the actual rendered Maze, lane layout, active space scene and victory
conversation. Inspected the longer-message conversation fixture and the avatar
panel. A low-contrast first-input hint at the bottom of later stages was found
and given an opaque backing. All five avatar expressions have saved frames.
Screenshots are JPEG evidence from the runner; game textures are not JPEG.

### Build artifacts and limits

- `build/game-linux-arm64.zip` is a fresh complete game export with the existing
  Gemma model and Linux runtime. `bundle-check.json` records its digest and size.
- `builds/pixel-shift-v0.2.1.pck` is extracted from that exact ZIP and tested in an
  isolated working directory, so repository source files cannot mask exclusions.
- Physical Uno Q deployment has not run. App name/icon confirmation and an
  approved output-bridge extension remain necessary. The supplied kit does not
  expose game-driven matrix output. HardwareFeedback is a tested desktop mock
  and transport contract, not verified hardware feedback.
- Human difficulty, 60 to 90 second stage pacing, handheld legibility, physical
  controls, haptics/LED output and Linux inference/rendering performance remain
  unverified. No claim of complete hardware acceptance is made.
- Gemma selects context-grounded authored replies under a constrained schema.
  This is not unrestricted generated dialogue. See `docs/roadmap-status.md`.
- Summer emits its known AuthManager shutdown warning. Accelerated audio probes
  can also leave queued WAV playback objects at process teardown. These warnings
  are separate from parser/runtime errors and must not be described as an
  entirely warning-free run. Export also reports engine CanvasItem teardown RIDs.

## Historical v0.2 record

The remainder records the earlier two-stage build, not current acceptance.
Verified locally on September 5, 2026, using Summer Engine 0.5.65 on macOS.

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
