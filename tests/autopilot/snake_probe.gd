extends "res://tests/autopilot/probe_base.gd"

const Grid = preload("res://scripts/grid.gd")
const Snake = preload("res://scripts/snake_stage.gd")

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
	check("title_on_launch", game.state == game.State.TITLE)
	save_frame("01_title")
	await press("confirm", 20)
	check("one_initial_pixel", game.stage.body.size() == 1)
	check("three_lives", game.lives == 3)
	await settle()
	save_frame("02_first_pixel")
	await press("move_right", 30)
	check("first_move_stretches", game.stage.body.size() == 3 and game.stage.stretch > 0)
	await settle()
	save_frame("03_stretch")
	await press("move_left", 20)
	check("reversal_rejected", game.stage.pending_direction == Vector2i.RIGHT)
	await press("pause", 20)
	var paused_body: Array = game.stage.body.duplicate()
	await settle_physics(20)
	check("pause_freezes", game.stage.body == paused_body and game.state == game.State.PAUSED)
	await press("pause", 20)
	check("resume", game.state == game.State.PLAYING)
	for frame in 80:
		await get_tree().physics_frame
		if game.stage.apples == 1:
			break
	check("real_input_collects_apple", game.stage.apples == 1 and game.score == 10 and game.stage.body.size() == 4)
	await press("pause", 20)
	save_frame("04_collection")
	for heading in Grid.DIRECTIONS:
		var snake := Snake.new()
		snake.initialize(2026)
		snake.steer(heading)
		var start: Vector2i = snake.body[0]
		snake.step()
		check("movement_%s" % heading, snake.body[0] == start + heading)
	for collision in ["wall", "body", "obstacle"]:
		game.start_run()
		game.score = 30
		var snake: RefCounted = game.stage
		snake.steer(Vector2i.RIGHT)
		if collision == "wall":
			snake.body.assign([Vector2i(23, 6), Vector2i(22, 6), Vector2i(21, 6)])
		elif collision == "body":
			snake.body.assign([Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7), Vector2i(7, 6), Vector2i(8, 6)])
		else:
			snake.body.assign([Vector2i(16, 5), Vector2i(15, 5), Vector2i(14, 5)])
		snake.step()
		check("%s_costs_one_life" % collision, game.lives == 2 and game.state == game.State.LIFE_LOST)
		await press("confirm", 20)
		check("%s_restart_preserves_run" % collision, game.lives == 2 and game.score == 30 and game.stage.body.size() == 1 and game.stage.apples == 0)
	game.lives = 1
	game.stage.steer(Vector2i.RIGHT)
	game.stage.body.assign([Vector2i(23, 6), Vector2i(22, 6), Vector2i(21, 6)])
	game.stage.step()
	check("zero_lives_game_over", game.state == game.State.GAME_OVER)
	await settle()
	save_frame("05_game_over")
	await press("confirm", 20)
	check("full_replay", game.score == 0 and game.lives == 3 and game.stage.body.size() == 1)
	var first := Snake.new()
	var second := Snake.new()
	first.initialize(991)
	second.initialize(991)
	for sample_index in 100:
		first.spawn_apple()
		second.spawn_apple()
		check("seed_and_spawn_%d" % sample_index, first.apple == second.apple and first.apple not in first.body and first.apple != first.obstacle)
	await press("cancel", 20)
	check("return_to_title", game.state == game.State.TITLE)
	check("logical_resolution", get_viewport().get_visible_rect().size == Vector2(400, 240))
	check("nearest_filter", game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	report("error", ", ".join(failures))
	finish()
