extends RefCounted

const Pacing = preload("res://scripts/pacing_config.gd")

var elapsed := 0.0
var progress := 0.0
var active := false

func begin() -> void:
	elapsed = 0.0
	progress = 0.0
	active = true

func advance(delta: float) -> bool:
	if not active:
		return false
	elapsed = minf(Pacing.TRANSITION_SECONDS, elapsed + delta)
	progress = elapsed / Pacing.TRANSITION_SECONDS
	if elapsed >= Pacing.TRANSITION_SECONDS:
		active = false
		return true
	return false

static func cut(progress_value: float) -> int:
	return mini(11, int(progress_value * 12.0))
