extends "res://tests/autopilot/probe_base.gd"
const SnakeStage = preload("res://scripts/snake_stage.gd")
var game: Node

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene
	# mimic the full-suite ordering in _test_checkpoints
	for stage_name in ["snake", "maze"]:
		for preset in ["start", "midpoint", "near-completion"]:
			game.playtest.select_stage(stage_name, preset)
	game.playtest.select_stage("maze", "near-completion")
	await settle()
	await press("dev_complete", 20)
	await settle(3)
	report("maze_complete_state", game.state)   # expect 6 VICTORY
	game.playtest.select_stage("snake", "near-completion")
	report("s_state", game.state)
	report("s_apples", game.stage.apples)
	await press("dev_complete", 20)
	report("no_settle_state", game.state)
	await settle(2)
	report("after_press_state", game.state)
	report("after_press_apples", game.stage.apples if game.current_stage=="snake" else -1)
	report("after_press_err", game.playtest.last_error)
	# now call it directly to see if the mechanism works at this point
	game.playtest.complete_objective()
	report("after_direct_state", game.state)
	report("after_direct_apples", game.stage.apples if game.current_stage=="snake" else -1)
	report("after_direct_err", game.playtest.last_error)
	finish()
