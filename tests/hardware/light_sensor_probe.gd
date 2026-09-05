extends SceneTree
## Pre-deploy validation for scripts/controller/light_sensor.gd and its
## palette-fade hook in presentation_director.gd: confirms the lux-to-fade
## math, malformed/missing state handling, and that Presentation darkens (but
## never crushes) each stage's palette as the level rises.

const LightSensor = preload("res://scripts/controller/light_sensor.gd")
const Presentation = preload("res://scripts/presentation_director.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run() -> void:
	_check(LightSensor.level_for_state('{"lux": %f}' % LightSensor.LUX_DARK) == 1.0,
		"lux at the dark threshold is fully dark")
	_check(LightSensor.level_for_state('{"lux": %f}' % LightSensor.LUX_LIGHT) == 0.0,
		"lux at the light threshold is fully bright")
	var mid: float = (LightSensor.LUX_DARK + LightSensor.LUX_LIGHT) / 2.0
	_check(is_equal_approx(LightSensor.level_for_state('{"lux": %f}' % mid), 0.5),
		"lux halfway between thresholds is half dark")
	_check(LightSensor.level_for_state('{"lux": -1000}') == 1.0, "lux below the dark threshold clamps to fully dark")
	_check(LightSensor.level_for_state('{"lux": 100000}') == 0.0, "lux above the light threshold clamps to fully bright")
	_check(LightSensor.level_for_state("not json") == null, "malformed JSON yields no level")
	_check(LightSensor.level_for_state("{}") == null, "JSON missing lux yields no level")
	_check(LightSensor.level_for_state('{"lux": 1}]') == null, "trailing garbage yields no level")

	var sensor := LightSensor.new()
	sensor._poll()
	_check(sensor._target_level == 0.0, "polling with no board-mounted state file leaves the target at full brightness")
	sensor.free()

	var baseline: Array = Presentation.palette("snake").duplicate(true)
	Presentation.set_dark_level(0.0)
	_check(Presentation.palette("snake") == baseline, "zero dark level leaves the palette unchanged")
	Presentation.set_dark_level(1.0)
	var darkened: Array = Presentation.palette("snake")
	for index in baseline.size():
		var original: Color = baseline[index]
		var faded: Color = darkened[index]
		_check(faded != original, "color %d darkens at full dark level" % index)
		_check(faded != Color.BLACK, "color %d is dimmed, not crushed to black, at full dark level" % index)
	Presentation.set_dark_level(2.0)
	_check(Presentation.palette("snake") == darkened, "dark level clamps above 1.0")
	Presentation.set_dark_level(0.0)
	_check(Presentation.palette("snake") == baseline, "dark level resets cleanly back to unchanged")

	for failure in failures:
		printerr("FAIL: ", failure)
	print("LIGHT_SENSOR_PROBE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
