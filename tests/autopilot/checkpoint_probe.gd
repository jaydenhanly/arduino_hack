extends "res://tests/autopilot/probe_base.gd"

func _ready() -> void:
	await super._ready()
	await settle(3)
	var game: Node = get_tree().current_scene
	var failures: Array[String] = []
	for hold_ms in [10, 20, 50, 100]:
		game.playtest.select_stage("maze", "near-completion")
		await press("dev_complete", hold_ms)
		await settle(3)
		var passed: bool = game.state == game.State.SHIFTING
		report("complete_action_%d_ms" % hold_ms, passed)
		if not passed:
			failures.append("complete_action_%d_ms" % hold_ms)
	game.playtest.select_stage("maze", "near-completion")
	game.playtest.complete_objective()
	report("complete_method", game.state == game.State.SHIFTING)
	if game.state != game.State.SHIFTING:
		failures.append("complete_method")
	report("error", ", ".join(failures))
	await settle(3)
	save_frame("checkpoint")
	finish()
