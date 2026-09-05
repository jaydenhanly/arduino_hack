extends "res://tests/autopilot/probe_base.gd"

# Rendered check of the style toggle: green stays the default and stays four
# colours; Copenhagen switches from the title with Button C and never draws more
# than sixteen colours on any stage.

const Art = preload("res://scripts/pixel_art.gd")

var game: Node
var failures: Array[String] = []

func check(label: String, passed: bool) -> void:
	report(label, passed)
	if not passed:
		failures.append(label)

func count_colors() -> int:
	var image := get_viewport().get_texture().get_image()
	var colors := {}
	for row in image.get_height():
		for column in image.get_width():
			colors[image.get_pixel(column, row).to_rgba32()] = true
	return colors.size()

func palette_check(label: String) -> void:
	await settle(3)
	var count := count_colors()
	report(label + "_colors", count)
	if Art.cph():
		check(label + "_palette", count >= 6 and count <= 16)
	else:
		check(label + "_palette", count >= 3 and count <= 4)
	save_frame(label)

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene
	check("title", game.state == game.State.TITLE)
	check("default_green", Art.theme == "green")
	await palette_check("01_title_green")
	await press("pause", 20)
	await settle(2)
	check("button_c_toggles_copenhagen", Art.theme == "copenhagen")
	check("title_still_showing", game.state == game.State.TITLE)
	await palette_check("02_title_copenhagen")
	await press("pause", 20)
	await settle(2)
	check("button_c_toggles_back", Art.theme == "green")
	await press("pause", 20)
	await settle(2)
	await key(KEY_J, 20)
	await settle(2)
	check("start_from_copenhagen", game.state == game.State.PLAYING and Art.cph())
	await palette_check("03_snake_copenhagen")
	if game.playtest == null:
		report("error", "playtest tools unavailable, maze and arena not rendered")
		finish()
		return
	game.playtest.select_stage("snake", "near-completion")
	await palette_check("04_snake_bikes_copenhagen")
	check("snake_bikes_present", game.stage.walls.size() > 0)
	game.playtest.select_stage("maze", "midpoint")
	check("maze_entered", game.current_stage == "maze")
	check("maze_has_four_walls", game.stage.walls.size() == 4)
	await palette_check("05_maze_copenhagen")
	game.playtest.select_stage("arena", "near-completion")
	check("arena_entered", game.current_stage == "arena")
	await palette_check("06_arena_copenhagen")
	# Pause and title still work in the theme.
	await press("pause", 20)
	await settle(2)
	check("pause_in_copenhagen", game.state == game.State.PAUSED)
	await press("cancel", 20)
	await settle(2)
	check("cancel_to_title", game.state == game.State.TITLE)
	# Green regression on the same stages.
	Art.set_theme("green")
	game.playtest.select_stage("maze", "midpoint")
	await palette_check("07_maze_green")
	game.playtest.select_stage("arena", "near-completion")
	await palette_check("08_arena_green")
	report("error", ", ".join(failures))
	finish()
