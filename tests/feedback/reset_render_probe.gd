extends "res://tests/autopilot/probe_base.gd"

var game: Node
var failures: Array[String] = []


func check(label: String, passed: bool) -> void:
	report(label, passed)
	if not passed:
		failures.append(label)


func input(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tick(seconds: float) -> void:
	game._process(seconds)


func capture(label: String) -> void:
	game.queue_redraw()
	game.board.queue_redraw()
	await settle(3)
	save_frame(label)


func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene
	game.set_process(false)
	game.model_enabled = false
	game.pixel.model_enabled = false
	game.profile = "normal"
	game.playtest.load_preset("frogger", "start")
	report("method", "Focused reset fixture places frog one hop before exit; actual Input events and GameFlow simulation exercise all reset gates. Full roadmap run separately covers unassisted crossings.")
	input("move_right", true)
	tick(0.15)
	input("move_right", false)
	game.stage.player = Vector2i(12, 1)
	input("move_up", true)
	tick(1.0 / 120.0)
	check("nonfinal_reset", game.stage.crossings == 1 and game.stage.player.y == 11)
	var bank: Vector2i = game.stage.player
	var lanes: Array = game.stage.lanes.duplicate(true)
	tick(0.2)
	check("grace_held_bank", game.stage.player.y == 11 and game.stage.reset_grace > 0.0)
	await capture("01_grace_safe_bank")
	tick(0.8)
	check("held_after_expiry_stays_safe", game.stage.player.y == 11 and game.stage.needs_neutral)
	check("traffic_keeps_running", game.stage.lanes != lanes)
	input("move_down", true)
	tick(0.1)
	check("opposing_keys_are_not_neutral", game.stage.needs_neutral)
	input("move_up", false)
	input("move_down", false)
	tick(1.0 / 120.0)
	check("release_rearms", not game.stage.needs_neutral)
	input("move_right", true)
	tick(0.15)
	input("move_right", false)
	check("rearmed_fresh_movement", game.stage.player == bank + Vector2i.RIGHT)
	await capture("02_rearmed_fresh_hop")
	game.stage.player = Vector2i(12, 1)
	input("move_up", true)
	tick(1.0 / 120.0)
	input("move_up", false)
	tick(0.1)
	check("early_neutral_keeps_grace", not game.stage.needs_neutral and game.stage.reset_grace > 0.0)
	input("move_right", true)
	input("move_right", false)
	tick(0.15)
	check("grace_input_not_queued", game.stage.player == bank)
	input("move_right", true)
	input("move_right", false)
	tick(0.15)
	check("normal_tap_preserved", game.stage.player == bank + Vector2i.RIGHT)
	game.stage.player = Vector2i(12, 1)
	input("move_up", true)
	tick(1.0 / 120.0)
	input("move_up", false)
	check("final_crossing_completes", game.state == game.State.SHIFTING and game.stage.crossings == 3)
	await capture("03_final_crossing")
	if not failures.is_empty():
		report("error", ", ".join(failures))
	finish()
