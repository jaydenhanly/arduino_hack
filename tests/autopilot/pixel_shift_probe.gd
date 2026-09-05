extends "res://tests/autopilot/probe_base.gd"

const Grid = preload("res://scripts/grid.gd")
const Maze = preload("res://scripts/maze_stage.gd")
const SnakeStage = preload("res://scripts/snake_stage.gd")

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
	check("title", game.state == game.State.TITLE)
	save_frame("01_title")
	await key(KEY_J, 20)
	check("hardware_confirm", game.state == game.State.PLAYING)
	save_frame("02_pixel")
	var steps := 0
	var apples_seen := 0
	while game.state == game.State.PLAYING and steps < 1500:
		var snake: RefCounted = game.stage
		var blocked: Array[Vector2i] = snake.body.slice(1)
		blocked.append_array(snake.walls)
		blocked.append_array(snake.spiders)
		if snake.direction != Vector2i.ZERO:
			blocked.append(snake.body[0] - snake.direction)
		var route := path_to(snake.body[0], snake.apple, blocked)
		if route.is_empty():
			break
		await move_one(_heading_to(snake.body[0], route[0]))
		steps += 1
		if game.stage.apples > apples_seen:
			apples_seen = game.stage.apples
			check("apple_%d_scored" % apples_seen, game.score == apples_seen * 10)
			check("apple_%d_transition_gate" % apples_seen, game.state == (game.State.SHIFTING if apples_seen == SnakeStage.APPLE_TARGET else game.State.PLAYING))
	check("normal_apple_target_transition", game.state == game.State.SHIFTING and apples_seen == SnakeStage.APPLE_TARGET)
	report("normal_snake_steps", steps)
	if game.state != game.State.SHIFTING:
		report("error", ", ".join(failures))
		finish()
		return
	var original_body: Array = game.stage.body.duplicate()
	var original_ghost_seed: Vector2i = game.stage.ghost_seed
	var original_apple: Vector2i = game.stage.apple
	await settle()
	save_frame("03_shift_start")
	await settle_physics(55)
	await press("pause", 10)
	var shift_time: float = game.shift_elapsed
	await settle_physics(12)
	check("pause_freezes_shift", game.shift_elapsed == shift_time)
	await press("pause", 10)
	await settle(3)
	save_frame("04_shift_middle")
	for frame in 160:
		if game.current_stage == "maze":
			break
		await get_tree().physics_frame
	check("maze_entered", game.current_stage == "maze" and game.state == game.State.PLAYING)
	check("head_and_three_tail_cells_retained", game.stage.body == original_body.slice(0, 4))
	check("ghost_seed_becomes_ghost", game.stage.ghost == original_ghost_seed)
	check("final_apple_is_scatter_source", game.board.shift_source.apple == original_apple)
	check("shift_wall_count_fixed", game.stage.walls.size() == Maze.WALL_COUNT)
	check("score_lives_continue", game.score == SnakeStage.APPLE_TARGET * 10 and game.lives == 5)
	check("maze_waits_for_direction", not game.stage.started)
	check("floor_connected", game.stage.reachable_cells(game.stage.body[0]).size() == 288 - game.stage.walls.size() * 10)
	await settle()
	save_frame("05_maze_start")
	var won := await hunt_ghost()
	check("normal_input_tail_victory", won)
	await settle()
	save_frame("06_normal_result")
	await press("confirm", 20)
	check("victory_full_replay", won and game.current_stage == "snake" and game.score == 0 and game.lives == 5)
	_test_maze_rules()
	await _test_checkpoints()
	await press("cancel", 20)
	check("title_return", game.state == game.State.TITLE)
	report("error", ", ".join(failures))
	finish()

func move_one(heading: Vector2i) -> void:
	var start: Vector2i = game.stage.body[0]
	var event := InputEventAction.new()
	event.action = Grid.ACTIONS[Grid.DIRECTIONS.find(heading)]
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = Grid.ACTIONS[Grid.DIRECTIONS.find(heading)]
	event.pressed = false
	Input.parse_input_event(event)
	for frame in 35:
		if game.stage.body[0] != start or game.state != game.State.PLAYING:
			return
		await get_tree().process_frame

func path_to(start: Vector2i, target: Vector2i, blocked: Array[Vector2i]) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if cell == target:
			var result: Array[Vector2i] = []
			while cell != start:
				result.push_front(cell)
				cell = previous[cell]
			return result
		for heading in Grid.DIRECTIONS:
			var next := Grid.wrap(cell + heading)
			if next in blocked or previous.has(next):
				continue
			previous[next] = cell
			queue.append(next)
	return []

func _heading_to(from: Vector2i, to: Vector2i) -> Vector2i:
	for heading in Grid.DIRECTIONS:
		if Grid.wrap(from + heading) == to:
			return heading
	return Vector2i.ZERO

func hunt_ghost() -> bool:
	for step_index in 180:
		if game.state != game.State.PLAYING:
			return game.state == game.State.VICTORY
		var maze: RefCounted = game.stage
		var best := Vector2i.ZERO
		var best_value := -99999.0
		for heading in Grid.DIRECTIONS:
			var next: Vector2i = maze.body[0] + heading
			if not maze.walkable(next) or next == maze.ghost:
				continue
			var future := Maze.new()
			future.initialize(maze.source)
			future.body.assign(maze.body)
			future.ghost = maze.ghost
			future.direction = maze.direction
			future.pending_direction = heading
			future.step()
			var ghost_step := future.chase_step()
			if ghost_step == future.body[0]:
				continue
			var distance: int = absi(next.x - maze.ghost.x) + absi(next.y - maze.ghost.y)
			var value := -absf(distance - 3) * 5.0
			if ghost_step in future.body.slice(1):
				value += 100.0
			if next in maze.body:
				value -= 30.0
			if heading == maze.direction:
				value += 1.0
			if next in maze.pellets:
				value += 2.0
			if value > best_value:
				best_value = value
				best = heading
		if best == Vector2i.ZERO:
			return false
		await move_one(best)
	return game.state == game.State.VICTORY

func canonical_source() -> Dictionary:
	var cells: Array[Vector2i] = []
	for column in range(11, 3, -1):
		cells.append(Vector2i(column, 6))
	return {"body": cells, "direction": Vector2i.RIGHT, "apple": Vector2i(11, 6), "ghost_seed": Vector2i(17, 5)}

func _test_maze_rules() -> void:
	game.maze_entry = canonical_source()
	game.current_stage = "maze"
	game.restart_stage()
	var maze: RefCounted = game.stage
	maze.body.assign([Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(1, 4)])
	maze.direction = Vector2i.RIGHT
	maze.steer(Vector2i.UP)
	maze.step()
	check("blocked_turn_keeps_heading", maze.body[0] == Vector2i(5, 4) and maze.pending_direction == Vector2i.UP)
	for step_index in 5:
		maze.step()
	check("buffered_turn_at_opening", maze.body[0] == Vector2i(9, 3))
	maze.body.assign([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	maze.direction = Vector2i.LEFT
	maze.steer(Vector2i.LEFT)
	maze.step()
	check("maze_wall_stops_without_damage", game.lives == 5 and maze.body[0] == Vector2i.ZERO)
	maze.pellets.assign([Vector2i(1, 0)])
	maze.steer(Vector2i.RIGHT)
	var score_before: int = game.score
	maze.step()
	check("pellet_score", maze.collected > 0 and maze.pellets.is_empty() and game.score == score_before + 5)
	maze.body.assign([Vector2i(16, 5), Vector2i(15, 5), Vector2i(14, 5), Vector2i(13, 5)])
	maze.steer(Vector2i.RIGHT)
	maze.step()
	check("player_head_hits_ghost", game.lives == 4 and game.state == game.State.LIFE_LOST)
	score_before = game.score
	game.restart_stage()
	check("maze_restart_valid", game.current_stage == "maze" and game.lives == 4 and game.score == score_before and game.stage.body == game.maze_entry.body.slice(0, 4) and game.stage.collected == 0)
	game.stage.body.assign([Vector2i(16, 5), Vector2i(15, 5), Vector2i(14, 5), Vector2i(13, 5)])
	game.stage.step_ghost()
	check("ghost_hits_head", game.lives == 3 and game.state == game.State.LIFE_LOST)
	game.restart_stage()
	game.stage.body.assign([Vector2i(20, 5), Vector2i(19, 5), Vector2i(18, 5), Vector2i(18, 6)])
	score_before = game.score
	game.stage.step_ghost()
	check("tail_defeats_ghost", game.state == game.State.VICTORY and not game.stage.ghost_alive and game.score == score_before + 100)

func _test_checkpoints() -> void:
	for stage_name in ["snake", "maze"]:
		for preset in ["start", "midpoint", "near-completion"]:
			game.playtest.select_stage(stage_name, preset)
			check("checkpoint_%s_%s" % [stage_name, preset], game.current_stage == stage_name and game.state == game.State.PLAYING and game.playtest.last_error.is_empty())
			if stage_name == "snake":
				var expected := 0 if preset == "start" else (SnakeStage.APPLE_TARGET / 2 if preset == "midpoint" else SnakeStage.APPLE_TARGET - 1)
				check("snake_preset_%s_count" % preset, game.stage.apples == expected)
			else:
				check("maze_preset_%s_valid" % preset, game.stage.body.size() == 4 and game.stage.walkable(game.stage.body[0]) and game.score >= SnakeStage.APPLE_TARGET * 10)
	game.playtest.select_stage("maze", "near-completion")
	await settle()
	save_frame("07_tail_trap_checkpoint")
	await press("dev_complete", 20)
	await settle(3)
	check("debug_complete_maze", game.state == game.State.VICTORY)
	game.playtest.select_stage("snake", "near-completion")
	await press("dev_complete", 20)
	check("debug_complete_runs_transition", game.state == game.State.SHIFTING)
	game.playtest.select_stage("maze", "midpoint")
	var first_body: Array = game.stage.body.duplicate()
	var first_pellets: Array = game.stage.pellets.duplicate()
	var first_walls: Array = game.stage.walls.duplicate()
	var first_score: int = game.score
	game.playtest.select_stage("maze", "midpoint")
	check("deterministic_checkpoint", game.stage.body == first_body and game.stage.pellets == first_pellets and game.stage.walls == first_walls and game.score == first_score)
	await press("dev_invulnerable", 20)
	check("debug_invulnerability", game.invulnerable and game.stage.invulnerable)
	await press("dev_restart", 20)
	check("debug_restart_keeps_invulnerability", game.stage.invulnerable and not game.stage.started)
	await press("dev_panel", 20)
	await settle()
	save_frame("08_debug_tools")
	await press("dev_panel", 20)
	await press("dev_invulnerable", 20)
