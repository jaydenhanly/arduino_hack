extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	var results := {
		"release_feature": OS.has_feature("pixel_shift_release"),
		"no_playtest_node": game.playtest == null,
		"no_debug_actions": not InputMap.has_action("dev_panel"),
		"no_debug_script": not ResourceLoader.exists("res://scripts/dev/playtest_manager.gd"),
		"no_test_scripts": not ResourceLoader.exists("res://tests/autopilot/snake_probe.gd"),
		"title_on_launch": game.state == game.State.TITLE,
		"version": ProjectSettings.get_setting("application/config/version") == "0.2"
	}
	game.start_run()
	results["snake_ready"] = game.stage.body.size() == 1 and game.lives == 3
	print(JSON.stringify(results, "  "))
	var passed := true
	for result: bool in results.values():
		passed = passed and result
	quit(0 if passed else 1)
