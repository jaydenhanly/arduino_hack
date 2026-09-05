extends "res://tests/autopilot/probe_base.gd"

const Mock = preload("res://tests/ai/mock_adapter.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const PixelPanel = preload("res://scripts/pixel_panel.gd")
const LONG_MESSAGE := "My tiny circuits brought a picnic to the apocalypse! Wait, where are the spoons?"

var game: Node
var failures: Array[String] = []


func check(label: String, passed: bool) -> void:
	report(label, passed)
	if not passed:
		failures.append(label)


func event(action: String, pressed: bool) -> void:
	var input := InputEventAction.new()
	input.action = action
	input.pressed = pressed
	Input.parse_input_event(input)
	Input.flush_buffered_events()


func tap(action: String) -> void:
	event(action, true)
	event(action, false)


func capture(label: String) -> void:
	game.queue_redraw()
	game.board.queue_redraw()
	game.pixel_panel.queue_redraw()
	await settle(3)
	save_frame(label)


func conversation_fixture() -> void:
	game.model_enabled = false
	game.pixel.model_enabled = false
	game.playtest.load_preset("asteroids", "near-completion")
	game.playtest.complete_objective()
	game.model_enabled = true
	game.pixel.model_enabled = true
	game._process(1.21)


func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene
	game.set_process(false)
	game.model_enabled = false
	game.pixel.model_enabled = false
	game.profile = "normal"
	game.playtest.load_preset("maze", "start")
	await capture("01_authored_maze")
	game.pixel._show({"emotion": "surprised", "message": "Eep!"})
	await capture("02_short_commentary")
	var long_reply := {"emotion": "excited", "message": LONG_MESSAGE}
	check("long_sample_valid", LONG_MESSAGE.length() == 80 and not Reply.validate(JSON.stringify(long_reply), false).is_empty())
	game.pixel._show(long_reply)
	var lines := PixelPanel.wrap_text(LONG_MESSAGE, 55, 2)
	check("compact_two_rows_no_loss", lines.size() == 2 and " ".join(lines) == LONG_MESSAGE)
	check("long_unbroken_token_wraps", PixelPanel.wrap_text("A".repeat(79) + "!", 55, 2).size() == 2)
	await capture("03_long_commentary")
	game.pixel.adapter = Mock.new()
	game.pixel.add_child(game.pixel.adapter)
	conversation_fixture()
	check("thinking_choices_hidden", game.state == game.State.CONVERSATION and game.pixel.thinking and game.pixel.choices.is_empty())
	tap("confirm")
	check("thinking_cannot_select", game.pixel.exchange == 0)
	await capture("04_conversation_thinking")
	tap("cancel")
	check("exit_during_thinking_is_title", game.state == game.State.TITLE and game.pixel.journal.sequence == 0 and game.pixel.conversation_context().history.is_empty())
	var title_message: String = game.pixel.message
	var generated := {"emotion": "excited", "message": LONG_MESSAGE,
		"choices": ["Did the ghost take the spoons?", "Tell me about your tiny picnic.", "How do circuits eat sandwiches?"]}
	game.pixel.adapter.complete(generated)
	check("late_callback_cannot_touch_title", game.state == game.State.TITLE and game.pixel.message == title_message and game.pixel.choices.is_empty())
	conversation_fixture()
	game.pixel.adapter.complete(generated)
	check("generated_turn_atomic", not game.pixel.thinking and game.pixel.choices.size() == 3 and game.pixel.diagnostics().source == "llm_conversation")
	check("conversation_two_rows_no_loss", " ".join(PixelPanel.wrap_text(LONG_MESSAGE, 47, 2)) == LONG_MESSAGE)
	await capture("05_generated_conversation_long")
	game._process(0.2)
	tap("move_down")
	var stable_choices: Array = game.pixel.choices.duplicate()
	game._process(9.0)
	check("navigation_does_not_replace_choices", game.pixel.choices == stable_choices and game.pixel_panel.selected == 1)
	tap("confirm")
	check("selection_begins_next_atomic_turn", game.pixel.thinking and game.pixel.choices.is_empty() and game.pixel.exchange == 1)
	game._process(9.0)
	stable_choices = game.pixel.choices.duplicate()
	var fallback: String = game.pixel.message
	check("timeout_finalizes_fallback", not game.pixel.thinking and stable_choices.size() == 3 and game.pixel.diagnostics().source == "fallback")
	game.pixel.adapter.complete({"emotion": "proud", "message": "My late spoon has arrived!", "choices": ["Hello spoon!", "Why so late?", "Where is the picnic?"]})
	check("late_timeout_cannot_replace_choices", game.pixel.choices == stable_choices and game.pixel.message == fallback)
	await capture("06_stable_fallback")
	tap("cancel")
	check("exit_ready_turn_is_title", game.state == game.State.TITLE and game.pixel.journal.sequence == 0 and game.pixel.conversation_context().history.is_empty())
	await capture("07_exit_title")
	if not failures.is_empty():
		report("error", ", ".join(failures))
	finish()
