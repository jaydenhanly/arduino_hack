extends SceneTree
## Pre-deploy validation for scripts/controller/button_input.gd: confirms the
## Uno Q kit's three face buttons (and their keyboard equivalents) resolve to
## confirm/cancel/pause/shoot, and that installing them does not leak
## movement bindings (JoystickInput's job).

const ButtonInput = preload("res://scripts/controller/button_input.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _button_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event

func _run() -> void:
	ButtonInput.install()

	_check(not InputMap.has_action("move_up"), "button install does not register movement actions")

	var keyboard := {KEY_J: ["confirm", "shoot"], KEY_ENTER: ["confirm"], KEY_SPACE: ["confirm"],
		KEY_K: ["cancel"], KEY_ESCAPE: ["cancel"], KEY_L: ["pause"], KEY_P: ["pause"]}
	for keycode: int in keyboard:
		var event := _key_event(keycode)
		for action: String in keyboard[keycode]:
			_check(event.is_action_pressed(action), "keycode %d presses %s" % [keycode, action])

	var joypad := {JOY_BUTTON_A: ["confirm", "shoot"], JOY_BUTTON_B: ["cancel"], JOY_BUTTON_X: ["pause"]}
	for button: int in joypad:
		var event := _button_event(button)
		for action: String in joypad[button]:
			_check(event.is_action_pressed(action), "joypad button %d presses %s" % [button, action])

	_check(not _key_event(KEY_J).is_action_pressed("cancel"), "confirm key does not also press cancel")

	for failure in failures:
		printerr("FAIL: ", failure)
	print("BUTTON_PROBE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
