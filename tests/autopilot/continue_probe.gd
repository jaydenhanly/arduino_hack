# Probe: losing a life continues the run instead of restarting the stage.
extends "res://tests/autopilot/probe_base.gd"

const Arena = preload("res://scripts/arena_stage.gd")

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
	await _snake_keeps_its_length()
	await _maze_keeps_its_pellets()
	await _arena_keeps_its_clock()
	report("error", ", ".join(failures))
	finish()

func _snake_keeps_its_length() -> void:
	game.start_run()
	var snake: RefCounted = game.stage
	snake.steer(Vector2i.RIGHT)
	snake.body.assign([Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(3, 6), Vector2i(2, 6)])
	snake.apples = 12
	snake.walls.assign([Vector2i(7, 6), Vector2i(15, 3)])
	game.score = 120
	snake.step()
	check("snake_death_costs_a_heart", game.lives == 4 and game.state == game.State.LIFE_LOST)
	await press("confirm", 20)
	check("snake_same_stage_object", game.stage == snake)
	check("snake_keeps_length", snake.body.size() == 5)
	check("snake_keeps_apples", snake.apples == 12 and game.score == 120)
	check("snake_keeps_the_far_wall", Vector2i(15, 3) in snake.walls)
	check("snake_clears_the_wall_it_hit", Vector2i(7, 6) not in snake.walls)
	check("snake_waits_for_a_steer", game.state == game.State.PLAYING and snake.awaiting_input)
	snake.steer(Vector2i.RIGHT)
	snake.step()
	check("snake_moves_on", snake.body[0] == Vector2i(7, 6) and not snake.stopped)

func _maze_keeps_its_pellets() -> void:
	game.start_run()
	game.current_stage = "maze"
	game.maze_entry = {"body": [Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(3, 6)], "direction": Vector2i.RIGHT, "ghost_seed": Vector2i(10, 6)}
	game.restart_stage()
	var maze: RefCounted = game.stage
	maze.pellets.clear()
	maze.collected = 9
	game.score = 45
	maze.ghost = Vector2i(7, 6)
	maze.started = true
	maze.step_ghost()
	check("maze_death_costs_a_heart", game.lives == 4 and game.state == game.State.LIFE_LOST)
	await press("confirm", 20)
	check("maze_same_stage_object", game.stage == maze)
	check("maze_keeps_progress", maze.collected == 9 and game.score == 45 and maze.body.size() == 4)
	check("maze_ghost_backs_off", maze.ghost != maze.body[0] and maze.ghost_alive)
	check("maze_playing", game.state == game.State.PLAYING and not maze.stopped)

func _arena_keeps_its_clock() -> void:
	game.start_run()
	game.current_stage = "arena"
	game.arena_entry = {"body": [Vector2i(24, 12), Vector2i(23, 12), Vector2i(22, 12), Vector2i(21, 12)], "direction": Vector2i.RIGHT}
	game.restart_stage()
	var arena: RefCounted = game.stage
	arena.started = true
	arena.survived = 140.0
	arena.kos = 3
	game.score = 300
	var length: int = arena.body.size()
	arena.spiders.assign([arena.body[0] + Vector2i.RIGHT])
	arena.step()
	check("arena_death_costs_a_heart", game.lives == 4 and game.state == game.State.LIFE_LOST)
	await press("confirm", 20)
	check("arena_same_stage_object", game.stage == arena)
	check("arena_keeps_length_and_score", arena.body.size() == length and game.score == 300 and arena.kos == 3)
	check("arena_keeps_the_clock", is_equal_approx(arena.survived, 140.0))
	check("arena_clears_the_spider", arena.spiders.is_empty())
	check("arena_playing", game.state == game.State.PLAYING and not arena.stopped)
	# A meltdown burn rolls the fire back far enough for the head to live.
	arena.survived = Arena.SURVIVE_SECONDS - 2.0
	arena.body.assign([Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12)])
	arena.started = true
	arena.stopped = false
	arena._burn()
	check("arena_meltdown_burns", game.state == game.State.LIFE_LOST and game.damage_reason == "BURNED ALIVE")
	await press("confirm", 20)
	check("arena_head_is_clear_of_fire", not arena.burning(arena.body[0]) and not arena.stopped)
