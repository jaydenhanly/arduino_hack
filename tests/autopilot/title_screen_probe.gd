extends "res://tests/autopilot/probe_base.gd"

var game: Node
var failures: Array[String] = []


func check(label: String, passed: bool) -> void:
	report(label, passed)
	if not passed:
		failures.append(label)


func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene
	game.model_enabled = false
	game.pixel.model_enabled = false
	game.set_process(false)
	check("title_state_visible", game.state == game.State.TITLE and game.pixel_panel.title_mode)
	game.pixel_panel.clock = 0.0
	check("pixel_begins_looking_forward", game.pixel_panel._title_gaze() == 0)
	game.pixel_panel.queue_redraw()
	await settle(2)
	save_frame("01_retromania_title")
	game.pixel_panel.clock = 2.7
	check("pixel_shifts_gaze", game.pixel_panel._title_gaze() == -1)
	game.pixel_panel.queue_redraw()
	await settle(2)
	save_frame("02_pixel_watching")
	await press("confirm", 50)
	await settle(3)
	check("button_a_starts_run", game.state == game.State.PLAYING and game.board.visible)
	check("compact_pixel_panel_restored", not game.pixel_panel.title_mode and not game.pixel_panel.expanded)
	save_frame("03_game_started")
	if not failures.is_empty():
		report("error", ", ".join(failures))
	finish()
