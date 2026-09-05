extends "res://tests/autopilot/probe_base.gd"

const PixelPanelScript = preload("res://scripts/pixel_panel.gd")

func _ready() -> void:
	await super._ready()
	await settle(3)
	var game: Node = get_tree().current_scene
	game.pixel.model_enabled = false
	report("title", game.state == game.State.TITLE)
	save_frame("01_title")
	game.pixel_panel.title_mode = false
	game.pixel.message = "I saw those careful turns. You kept finding room when the path grew narrow."
	for emotion in ["curious", "excited", "worried", "surprised", "proud"]:
		game.pixel.emotion = emotion
		await settle(3)
		save_frame("emotion_" + emotion)
	game.pixel.emotion = "proud"
	game.pixel.message = "You made room for every turn. What part of that run would you try differently?"
	game.pixel.choices.assign(["I would take my time.", "I would chase another ghost.", "I would play it the same way."])
	game.pixel.thinking = false
	game.pixel_panel.expanded = true
	game.pixel_panel.selected = 1
	await settle(3)
	save_frame("conversation_maximum_text")
	report("compact_text_wraps", PixelPanelScript.wrap_text(game.pixel.message, 55, 2).size() == 2)
	report("conversation_text_fits", PixelPanelScript.wrap_text(game.pixel.message, 47, 2).size() <= 2)
	game.pixel_panel.expanded = false
	game.pixel.thinking = false
	game.pixel.choices.clear()
	game.profile = "demo"
	for stage_name in ["snake", "maze", "frogger", "asteroids"]:
		game.playtest.load_preset(stage_name, "start")
		report(stage_name + "_checkpoint", game.current_stage == stage_name and game.playtest.last_error.is_empty())
		await settle(3)
		save_frame("stage_" + stage_name)
	game.show_title()
	finish()
