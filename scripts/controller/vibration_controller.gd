extends RefCounted
## Sizes and rate-limits the Uno Q kit's vibration-motor pulse for a feedback
## cue. Pure logic, no I/O: the kit exposes only an internal vibration RPC and
## no game-facing output API yet (see README's "Uno Q and hardware feedback"),
## so nothing here reaches real hardware — it is the desktop-verifiable
## duration `hardware_feedback.gd` would hand to one when it does.

const PULSES := {"collect": 18, "danger": 35, "transform": 45, "death": 70,
	"victory": 60, "checkpoint": 20}
const MIN_INTERVAL_SECONDS := 0.15
# One-shot cues that must always be felt, regardless of what just buzzed: each
# happens at most once per run or per stage transition (often in the very
# same frame as the collect/checkpoint pulse for the event that triggered it),
# so spam is structurally impossible. Only the frequent, repeatable cues
# (collect, checkpoint, danger) are worth rate-limiting.
const UNTHROTTLED := ["death", "victory", "transform"]

var time_since_pulse := 1.0

func advance(delta: float) -> void:
	time_since_pulse += delta

## Returns the pulse length in ms for `kind`, or 0 for an unrecognized kind
## (e.g. "comment"). A throttled kind fired within MIN_INTERVAL_SECONDS of the
## last pulse also returns 0. A pulse that actually fires resets the timer.
func pulse_for(kind: String) -> int:
	var duration: int = int(PULSES.get(kind, 0))
	if duration > 0 and time_since_pulse < MIN_INTERVAL_SECONDS and kind not in UNTHROTTLED:
		duration = 0
	if duration > 0:
		time_since_pulse = 0.0
	return duration
