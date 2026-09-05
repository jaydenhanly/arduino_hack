extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	game.model_enabled = false
	root.add_child(game)
	await process_frame
	var results := {
		"release_feature": OS.has_feature("pixel_shift_release"),
		"no_playtest_node": game.playtest == null,
		"no_debug_actions": not InputMap.has_action("dev_panel"),
		"no_development_directories": not DirAccess.dir_exists_absolute("res://tests") and not DirAccess.dir_exists_absolute("res://scripts/dev"),
		"no_debug_script": not ResourceLoader.exists("res://scripts/dev/playtest_manager.gd"),
		"no_test_scripts": not ResourceLoader.exists("res://tests/autopilot/snake_probe.gd") and not ResourceLoader.exists("res://tests/roadmap/full_run_probe.gd") and not ResourceLoader.exists("res://tests/ai/unit.gd"),
		"title_on_launch": game.state == game.State.TITLE,
		"version": ProjectSettings.get_setting("application/config/version") == "0.2.1"
	}
	for script_path in ["snake_stage", "maze_stage", "frogger_stage", "asteroids_stage", "pacing_config", "run_rng", "transition_director", "presentation_director", "pixel_panel", "controller/hardware_feedback", "controller/vibration_controller", "controller/light_controller", "controller/joystick_input", "controller/button_input", "ai/pixel_controller", "ai/run_journal", "ai/pixel_reply", "ai/pixel_fallbacks", "ai/gemma_adapter", "llm/llm_service"]:
		results["included_" + script_path] = ResourceLoader.exists("res://scripts/" + script_path + ".gd")
	game.start_run()
	results["snake_ready"] = game.stage.body.size() == 1 and game.lives == 1 and not game.stage.invulnerable
	results["normal_profile"] = game.profile == "normal" and game.stage.target == 10
	results["companion_ready"] = game.pixel != null and not game.pixel.model_enabled
	print(JSON.stringify(results, "  "))
	var passed := true
	for result: bool in results.values():
		passed = passed and result
	for voice in game.audio.voices:
		voice.stop()
	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
