extends RefCounted
## Registers the four movement actions (move_up/down/left/right) across
## keyboard, D-pad, and analog stick, and resolves them to a Grid direction or
## a continuous vector. Face buttons are ButtonInput's concern — this file
## never touches confirm/cancel/pause/shoot.

const Grid = preload("res://scripts/grid.gd")

static func install() -> void:
	var keys := {
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
	}
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for keycode: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	var dpad := {&"move_up": JOY_BUTTON_DPAD_UP, &"move_down": JOY_BUTTON_DPAD_DOWN,
		&"move_left": JOY_BUTTON_DPAD_LEFT, &"move_right": JOY_BUTTON_DPAD_RIGHT}
	for action: StringName in dpad:
		var event := InputEventJoypadButton.new()
		event.button_index = dpad[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	for index in Grid.ACTIONS.size():
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_Y if index % 2 == 0 else JOY_AXIS_LEFT_X
		event.axis_value = -1.0 if index < 2 else 1.0
		if not InputMap.action_has_event(Grid.ACTIONS[index], event):
			InputMap.action_add_event(Grid.ACTIONS[index], event)

## Discrete resolution for _unhandled_input: which direction (if any) did this
## single InputEvent just press.
static func direction_for(event: InputEvent) -> Vector2i:
	for index in Grid.ACTIONS.size():
		if event.is_action_pressed(Grid.ACTIONS[index]):
			return Grid.DIRECTIONS[index]
	return Vector2i.ZERO

## Continuous resolution for stages that poll every frame (asteroids, frogger).
static func vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
