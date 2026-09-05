extends Node
## Coordinates the Uno Q kit's two feedback channels behind the single
## `emit_feedback(kind)` call every gameplay event uses: a vibration pulse
## (VibrationController) and a 13x8 blue LED-matrix frame (LightController).
## See README's "Uno Q and hardware feedback": neither channel reaches real
## hardware yet, only this desktop-verifiable mock.

signal feedback_requested(event: Dictionary)

const VibrationController = preload("res://scripts/controller/vibration_controller.gd")
const LightController = preload("res://scripts/controller/light_controller.gd")

var last_event: Dictionary = {}
var recent_events: Array[Dictionary] = []
var transport: Callable
var enabled := true
var capability_status := "desktop_mock: kit has no game-to-matrix transport"

var _vibration := VibrationController.new()
var _light := LightController.new()

func advance(delta: float) -> void:
	_vibration.advance(delta)

func emit_feedback(kind: String, progress: float = 0.0) -> void:
	if not enabled or not _light.has_pattern(kind):
		return
	var frame := _light.frame_for(kind, progress)
	last_event = {"kind": kind, "pulse_ms": _vibration.pulse_for(kind),
		"matrix_rows": frame.rows, "matrix_frame": frame.frame,
		"progress": frame.progress, "color": "blue"}
	recent_events.append(last_event.duplicate(true))
	if recent_events.size() > 32:
		recent_events.pop_front()
	feedback_requested.emit(last_event.duplicate(true))
	if transport.is_valid():
		transport.call(last_event.duplicate(true))
