extends SceneTree
## Pre-deploy validation for scripts/controller/light_controller.gd: confirms
## every gameplay cue builds a well-formed 13x8 matrix frame and that
## progress clamps to [0, 1].

const LightController = preload("res://scripts/controller/light_controller.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run() -> void:
	var controller := LightController.new()

	for kind: String in LightController.PATTERNS:
		_check(controller.has_pattern(kind), "%s is a recognized cue" % kind)
		var frame := controller.frame_for(kind, 0.5)
		_check(frame.rows.size() == 8, "%s frame has 8 rows (7 pattern + 1 progress)" % kind)
		_check(frame.frame.size() == 13 * 8, "%s frame is 13x8 bytes" % kind)

	_check(not controller.has_pattern("not_a_real_cue"), "unrecognized cue has no pattern")

	_check(controller.frame_for("victory", 2.0).progress == 1.0, "progress clamps above 1.0")
	_check(controller.frame_for("victory", -1.0).progress == 0.0, "progress clamps below 0.0")
	_check(controller.frame_for("victory", 0.5).progress == 0.5, "progress passes through unclamped")

	for failure in failures:
		printerr("FAIL: ", failure)
	print("LIGHT_PROBE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
