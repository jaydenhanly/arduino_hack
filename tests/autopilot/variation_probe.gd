extends "res://tests/autopilot/probe_base.gd"

const Art = preload("res://scripts/pixel_art.gd")
const Maze = preload("res://scripts/maze_stage.gd")
const SnakeStage = preload("res://scripts/snake_stage.gd")

func _ready() -> void:
	await super._ready()
	await settle(3)
	var game: Node = get_tree().current_scene
	var failures: Array[String] = []
	for seed_value in range(32):
		game.playtest.seed_value = seed_value
		game.playtest.select_stage("maze", "start")
		var valid: bool = game.current_stage == "maze" and game.playtest.last_error.is_empty()
		if valid:
			valid = game.stage.walls.size() == game.stage.topology.wall_cells.size() and game.stage.reachable_cells(game.stage.body[0]).size() == 288 - game.stage.walls.size()
			valid = valid and game.stage.walkable(game.stage.ghost) and game.score == SnakeStage.APPLE_TARGET * 10
			for cell: Vector2i in game.stage.body:
				valid = valid and game.stage.walkable(cell)
		report("seed_%d_valid_maze" % seed_value, valid)
		if not valid:
			failures.append("seed_%d" % seed_value)
		game.playtest.select_stage("maze", "near-completion")
		game.stage.step_ghost()
		var wins: bool = game.state == game.State.SHIFTING
		report("seed_%d_tail_trap" % seed_value, wins)
		if not wins:
			failures.append("tail_trap_%d" % seed_value)
	game.playtest.seed_value = 2026
	game.playtest.select_stage("snake", "near-completion")
	game.score = 740
	game.lives = 2
	game.playtest.complete_objective()
	var carry: bool = game.score == 750 and game.lives == 2 and game.state == game.State.SHIFTING
	game._enter_maze()
	carry = carry and game.score == 750 and game.lives == 2
	report("nondefault_score_lives_carry", carry)
	if not carry:
		failures.append("nondefault_score_lives_carry")
	game.invulnerable = true
	game.restart_stage()
	game.stage.body[0] = game.stage.ghost + Vector2i.LEFT
	game.stage.step_ghost()
	var safe: bool = game.lives == 2 and game.state == game.State.PLAYING
	report("invulnerability_prevents_damage", safe)
	if not safe:
		failures.append("invulnerability_prevents_damage")
	game.invulnerable = false
	game.playtest.select_stage("snake", "near-completion")
	game.playtest.complete_objective()
	await press("pause", 50)
	await settle(3)
	game.playtest.complete_objective()
	var resumes: bool = game.state == game.State.SHIFTING
	report("complete_during_paused_shift_resumes", resumes)
	if not resumes:
		failures.append("complete_during_paused_shift_resumes")
	game.playtest.select_stage("maze", "start")
	var maze_one: RefCounted = game.stage
	var maze_two := Maze.new()
	maze_two.initialize(maze_one.source)
	for step_index in 15:
		maze_one.step_ghost()
		maze_two.step_ghost()
		if maze_one.ghost != maze_two.ghost:
			failures.append("ghost_determinism_%d" % step_index)
	report("deterministic_ghost", maze_one.ghost == maze_two.ghost)
	game.start_run()
	game.audio.play("shift")
	await settle_physics(10)
	var peak := AudioServer.get_bus_peak_volume_left_db(0, 0)
	report("audio_peak_db", peak)
	if peak <= -100:
		failures.append("audio_silent")
	await settle(3)
	var image := get_viewport().get_texture().get_image()
	var colors := {}
	for row in image.get_height():
		for column in image.get_width():
			colors[image.get_pixel(column, row).to_rgba32()] = true
	report("palette_color_count", colors.size())
	if colors.size() != 4:
		failures.append("four_color_palette")
	Art.set_theme("copenhagen")
	game.queue_redraw()
	game.board.queue_redraw()
	await settle(3)
	image = get_viewport().get_texture().get_image()
	var cph_colors := {}
	for row in image.get_height():
		for column in image.get_width():
			cph_colors[image.get_pixel(column, row).to_rgba32()] = true
	report("copenhagen_color_count", cph_colors.size())
	if cph_colors.size() < 5 or cph_colors.size() > 16:
		failures.append("copenhagen_palette")
	save_frame("copenhagen_maze")
	Art.set_theme("green")
	report("logical_size", str(image.get_size()))
	report("window_size", str(get_window().size))
	report("error", ", ".join(failures))
	finish()
