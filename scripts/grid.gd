extends RefCounted

const SIZE := Vector2i(24, 12)
const CELL := 14
const ORIGIN := Vector2(32, 40)
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
const ACTIONS: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y

static func rect(cell: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cell) * CELL, Vector2.ONE * CELL)

static func direction_for(event: InputEvent) -> Vector2i:
	for index in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[index]):
			return DIRECTIONS[index]
	return Vector2i.ZERO

static func install_inputs() -> void:
	var bindings := {
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"confirm": [KEY_J, KEY_ENTER, KEY_SPACE], &"shoot": [KEY_J],
		&"cancel": [KEY_K, KEY_ESCAPE], &"pause": [KEY_L, KEY_P]
	}
	for action: StringName in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for keycode: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	var buttons := {&"confirm": JOY_BUTTON_A, &"shoot": JOY_BUTTON_A, &"cancel": JOY_BUTTON_B, &"pause": JOY_BUTTON_X,
		&"move_up": JOY_BUTTON_DPAD_UP, &"move_down": JOY_BUTTON_DPAD_DOWN,
		&"move_left": JOY_BUTTON_DPAD_LEFT, &"move_right": JOY_BUTTON_DPAD_RIGHT}
	for action: StringName in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	for index in ACTIONS.size():
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_Y if index % 2 == 0 else JOY_AXIS_LEFT_X
		event.axis_value = -1.0 if index < 2 else 1.0
		if not InputMap.action_has_event(ACTIONS[index], event):
			InputMap.action_add_event(ACTIONS[index], event)
