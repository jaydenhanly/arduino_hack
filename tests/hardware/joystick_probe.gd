extends SceneTree
## Pre-deploy validation for scripts/controller/joystick_input.gd: confirms
## the Uno Q joystick's keyboard, D-pad, and analog-stick bindings each
## resolve to the correct Grid direction, and that installing the joystick
## does not leak face-button bindings (ButtonInput's job).

const JoystickInput = preload("res://scripts/controller/joystick_input.gd")

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

func _dpad_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event

func _axis_event(axis: int, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event

func _run() -> void:
	JoystickInput.install()

	_check(not InputMap.has_action("confirm"), "joystick install does not register face-button actions")

	var keyboard := {KEY_W: Vector2i.UP, KEY_UP: Vector2i.UP, KEY_S: Vector2i.DOWN, KEY_DOWN: Vector2i.DOWN,
		KEY_A: Vector2i.LEFT, KEY_LEFT: Vector2i.LEFT, KEY_D: Vector2i.RIGHT, KEY_RIGHT: Vector2i.RIGHT}
	for keycode: int in keyboard:
		var direction: Vector2i = keyboard[keycode]
		_check(JoystickInput.direction_for(_key_event(keycode)) == direction,
			"keycode %d resolves to %s" % [keycode, direction])

	var dpad := {JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
		JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT}
	for button: int in dpad:
		var direction: Vector2i = dpad[button]
		_check(JoystickInput.direction_for(_dpad_event(button)) == direction,
			"d-pad button %d resolves to %s" % [button, direction])

	_check(JoystickInput.direction_for(_axis_event(JOY_AXIS_LEFT_Y, -1.0)) == Vector2i.UP, "stick up resolves to UP")
	_check(JoystickInput.direction_for(_axis_event(JOY_AXIS_LEFT_Y, 1.0)) == Vector2i.DOWN, "stick down resolves to DOWN")
	_check(JoystickInput.direction_for(_axis_event(JOY_AXIS_LEFT_X, -1.0)) == Vector2i.LEFT, "stick left resolves to LEFT")
	_check(JoystickInput.direction_for(_axis_event(JOY_AXIS_LEFT_X, 1.0)) == Vector2i.RIGHT, "stick right resolves to RIGHT")

	_check(JoystickInput.direction_for(_key_event(KEY_M)) == Vector2i.ZERO, "unrelated key resolves to no direction")

	Input.action_press("move_up")
	_check(JoystickInput.vector().y < 0, "polled vector reflects a held move_up")
	Input.action_release("move_up")
	Input.action_press("move_right")
	_check(JoystickInput.vector().x > 0, "polled vector reflects a held move_right")
	Input.action_release("move_right")
	_check(JoystickInput.vector() == Vector2.ZERO, "polled vector is neutral once released")

	for failure in failures:
		printerr("FAIL: ", failure)
	print("JOYSTICK_PROBE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
