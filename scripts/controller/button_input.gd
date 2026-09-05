extends RefCounted
## Registers the Uno Q kit's three face buttons (and their keyboard
## equivalents) as the confirm/cancel/pause/shoot actions. Movement bindings
## are JoystickInput's concern — this file never touches move_up/down/left/right.

static func install() -> void:
	var keys := {
		&"confirm": [KEY_J, KEY_ENTER, KEY_SPACE], &"shoot": [KEY_J],
		&"cancel": [KEY_K, KEY_ESCAPE], &"pause": [KEY_L, KEY_P],
	}
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for keycode: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	var buttons := {&"confirm": JOY_BUTTON_A, &"shoot": JOY_BUTTON_A,
		&"cancel": JOY_BUTTON_B, &"pause": JOY_BUTTON_X}
	for action: StringName in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
