extends SceneTree
## Pre-deploy validation for scripts/controller/vibration_controller.gd:
## confirms every gameplay cue's pulse length, that unrecognized/"comment"
## cues never buzz, that rapid throttled cues are rate-limited, and that the
## one-shot death/victory/transform cues are never swallowed by a pulse that
## just fired in the same frame (the bug this file guards against: those cues
## routinely land right after a collect/checkpoint pulse in real gameplay).

const VibrationController = preload("res://scripts/controller/vibration_controller.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run() -> void:
	for kind: String in VibrationController.PULSES:
		var controller := VibrationController.new()
		var expected: int = VibrationController.PULSES[kind]
		_check(controller.pulse_for(kind) == expected, "%s pulses for %dms" % [kind, expected])

	var unknown := VibrationController.new()
	_check(unknown.pulse_for("comment") == 0, "comment cue never vibrates")
	_check(unknown.pulse_for("not_a_real_cue") == 0, "unrecognized cue never vibrates")

	var limited := VibrationController.new()
	_check(limited.pulse_for("collect") == VibrationController.PULSES["collect"], "first pulse fires")
	_check(limited.pulse_for("danger") == 0, "a pulse fired within the rate-limit window is suppressed")
	limited.advance(VibrationController.MIN_INTERVAL_SECONDS + 0.01)
	_check(limited.pulse_for("danger") == VibrationController.PULSES["danger"], "pulse fires again once the window clears")

	for kind: String in VibrationController.UNTHROTTLED:
		var unthrottled := VibrationController.new()
		unthrottled.pulse_for("collect")
		_check(unthrottled.pulse_for(kind) == VibrationController.PULSES[kind],
			"%s always fires even immediately after another pulse" % kind)

	for failure in failures:
		printerr("FAIL: ", failure)
	print("VIBRATION_PROBE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
