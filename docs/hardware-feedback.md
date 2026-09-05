# Project-local optional feedback

The current authorization covers this project only. No physical board was
contacted. The shared kit's earlier edits are frozen and are not approved work.
Their exact inventory and hashes are in `shared-kit-frozen.md`.

`HardwareFeedback` owns semantic event mapping. It emits abstract 13x8 row-mask
animations: breathing idle, collect ripple, danger pulse, transformation sweep,
death collapse, victory burst, and silent comment shimmer. It never renders
Pixel's face, text, stage names or exact objective progress. All feedback is
optional. Idle follows transient effects. Frames are 100 ms apart.

Priorities are idle 0, comment 1, collect 2, danger 3, transformation 4, and death/
victory 5. Same-tick requests coalesce before dispatch; terminal feedback replaces
lower-priority pending effects. Checkpoints do not create separate haptic pulses.
Periodic comments have no vibration. Distinct short pulse sequences are tunable,
not physically approved intensity or duration settings.

## Version 1 packet

The exact envelope keys are `version`, `sequence`, `priority`, `replace`, `loop`,
`vibration` and `frames`. No game event names cross the transport boundary.

- Version is 1. Sequence is an integer from 1 through 2147483647; priority 0-5.
- `replace` and `loop` are booleans. Only priority-zero, vibration-free idle loops.
- At most eight vibration entries, each `{on_ms, off_ms}`. On time is 10-120 ms;
  off time 0-1000 ms. Total on time is at most 600 ms per packet.
- One through 32 frames, each `{rows, duration_ms, level}`. Rows contain exactly
  eight integer masks from 0 through 8191. Bit 12 is the leftmost of 13 LEDs.
  Duration is 100-1000 ms and brightness level 0-7.
- Pulse timeline and frame timeline are each at most 5000 ms. JSON is at most
  8192 UTF-8 bytes, followed by a newline. Unknown fields and malformed values fail.

`feedback_transport.gd` is a nonblocking Unix-domain socket client. It uses
`SUMMER_FEEDBACK_SOCKET` only when explicitly configured. One partial write and
one priority-coalesced pending packet are the maximum. A 250 ms deadline and two
second retry backoff bound failed attempts; dropped transients are not replayed.
Missing endpoints and unsupported socket classes leave gameplay functional.
`socket_connected` means transport connectivity, not physical hardware success.

`tests/feedback/run.py` uses a project-owned desktop capture mock. It neither
imports nor executes the frozen shared kit. It proves Godot JSON traverses a
local filesystem socket unchanged, not that any MCU receives it. No network
listener is added by the game-feedback path.

The project bundle script includes `summer-feedback.json` requesting raw button
haptics off. That is a proposed installer policy, not evidence of deployment.
The frozen shared-kit extension would need separate review and authorization
before it could supply a stable container endpoint and generic MCU executor.

## Physical work still required after separate authorization

Review the frozen installer/protocol/firmware work, actual Arduino compilation,
RPC signatures, container socket permissions, bridge loss and reconnect behavior.
Then physically check matrix orientation, eight-row geometry, brightness, every
aura animation, return to idle, and no more than ten visual updates per second.
Check gentle collect/transform/death/victory haptics, priority replacement, no
checkpoint double pulses, no comment vibration, and no raw fire/menu vibration.
Test held joystick crossings, neutral rearming, keyboard parity and unaffected
traffic. Check Linux inference/frame time, thermal behavior and human comfort.

Deployment is prohibited under the current scope. Any later deployment requires
explicit approval, the app name and emoji, and the prescribed Uno Q skill/scripts.
