extends "res://tests/autopilot/probe_base.gd"

const Grid = preload("res://scripts/grid.gd")
const SnakeStage = preload("res://scripts/snake_stage.gd")

var game: Node

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene

	# --- B: dev_complete from snake near-completion ---
	game.playtest.select_stage("snake", "near-completion")
	report("B_after_select_stage", game.current_stage)
	report("B_after_select_state", game.state)
	report("B_after_select_apples", game.stage.apples)
	report("B_after_select_err", game.playtest.last_error)
	report("B_after_select_walls", game.stage.walls.size())
	report("B_after_select_spiders", game.stage.spiders.size())
	report("B_after_select_bodylen", game.stage.body.size())
	game.playtest.complete_objective()
	report("B_after_complete_state", game.state)
	report("B_after_complete_apples", game.stage.apples if game.current_stage == "snake" else -1)
	report("B_after_complete_err", game.playtest.last_error)
	report("B_after_complete_stage", game.current_stage)
	report("B_expected_state_SHIFTING", game.State.SHIFTING)

	# --- A: victory -> confirm -> replay ---
	game.playtest.select_stage("maze", "near-completion")
	await press("dev_complete", 20)
	await settle(3)
	report("A_state_after_win", game.state)
	report("A_is_victory", game.state == game.State.VICTORY)
	report("A_score_at_victory", game.score)
	await press("confirm", 20)
	await settle(3)
	report("A_state_after_confirm", game.state)
	report("A_stage_after_confirm", game.current_stage)
	report("A_score_after_confirm", game.score)
	report("A_lives_after_confirm", game.lives)
	report("A_panel_open", game.playtest.panel_open)
	report("A_dev_active", game.playtest.active)
	finish()
