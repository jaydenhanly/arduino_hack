extends Node

const Grid = preload("res://scripts/grid.gd")
const Art = preload("res://scripts/pixel_art.gd")
const Pacing = preload("res://scripts/pacing_config.gd")
const PRESETS := ["start", "midpoint", "near-completion"]

var game: Node
var panel_open := false
var active := false
var seed_value := 2026
var preset_index := 0
var stage_index := 0
var last_error := ""

func initialize(flow: Node) -> void:
	game = flow
	active = "--playtest" in OS.get_cmdline_user_args()
	panel_open = active
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	var bindings := {"dev_panel": KEY_F1, "dev_snake": KEY_F2, "dev_maze": KEY_F3,
		"dev_preset": KEY_F4, "dev_restart": KEY_F5, "dev_invulnerable": KEY_F6,
		"dev_complete": KEY_F7, "dev_seed": KEY_F8, "dev_profile": KEY_F9}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("dev_panel"):
		active = true
		panel_open = not panel_open
	elif panel_open and event.is_action_pressed("cancel"):
		panel_open = false
	elif event.is_action_pressed("dev_snake"):
		stage_index = posmod(stage_index - 1, Pacing.STAGES.size())
		load_preset(Pacing.STAGES[stage_index], PRESETS[preset_index])
	elif event.is_action_pressed("dev_maze"):
		stage_index = posmod(stage_index + 1, Pacing.STAGES.size())
		load_preset(Pacing.STAGES[stage_index], PRESETS[preset_index])
	elif event.is_action_pressed("dev_preset"):
		preset_index = posmod(preset_index + 1, PRESETS.size())
		load_preset(Pacing.STAGES[stage_index], PRESETS[preset_index])
	elif event.is_action_pressed("dev_restart"):
		load_preset(Pacing.STAGES[stage_index], PRESETS[preset_index])
	elif event.is_action_pressed("dev_invulnerable"):
		game.invulnerable = not game.invulnerable
		if game.stage != null:
			game.stage.invulnerable = game.invulnerable
	elif event.is_action_pressed("dev_complete"):
		complete_objective()
	elif event.is_action_pressed("dev_seed"):
		seed_value += 1
		load_preset(Pacing.STAGES[stage_index], PRESETS[preset_index])
	elif event.is_action_pressed("dev_profile"):
		game.profile = "demo" if game.profile == "normal" else "normal"
		load_preset(Pacing.STAGES[stage_index], PRESETS[preset_index])
	else:
		return
	active = true
	game.audio.set_paused(panel_open or game.state == game.State.PAUSED)
	get_viewport().set_input_as_handled()

func load_preset(stage_name: String, preset: String = "start") -> void:
	last_error = ""
	stage_index = maxi(0, Pacing.STAGES.find(stage_name))
	preset_index = maxi(0, PRESETS.find(preset))
	var saved_invulnerability: bool = game.invulnerable
	game.invulnerable = true
	game.start_run(seed_value)
	for preceding in stage_index:
		_drive_objective(game.stage.target)
		if game.state != game.State.SHIFTING:
			last_error = "COULD NOT BUILD CHECKPOINT"
			break
		game.transition.active = false
		game._enter_next_stage()
	if last_error.is_empty():
		var target: int = 0
		if preset == "midpoint":
			target = int(game.stage.target / 2)
		elif preset == "near-completion":
			target = game.stage.target - 1
		if target > 0:
			_drive_objective(target)
		if game.current_stage == "snake":
			game.stage.awaiting_input = true
		else:
			game.stage.started = false
	game.invulnerable = saved_invulnerability
	game.stage.invulnerable = saved_invulnerability
	game.audio.set_paused(panel_open)

func complete_objective() -> void:
	last_error = ""
	if game.state == game.State.TITLE or game.stage == null:
		game.start_run(seed_value)
	if game.state == game.State.SHIFTING:
		return
	if game.state != game.State.PLAYING:
		last_error = "SELECT A PLAYING CHECKPOINT"
		return
	var saved: bool = game.stage.invulnerable
	game.stage.invulnerable = true
	_drive_objective(game.stage.target)
	game.stage.invulnerable = saved

func _drive_objective(target: int) -> void:
	game._mark_run_started()
	match game.current_stage:
		"snake":
			_feed_snake(target)
		"maze":
			_collect_pellets(target)
		"frogger":
			for tick in 2000:
				if game.stage.get_progress() >= target or game.state != game.State.PLAYING:
					return
				game.stage.steer(Vector2i.UP)
				game.stage.advance(0.16)
		"asteroids":
			for tick in 36000:
				if game.stage.get_progress() >= target or game.state != game.State.PLAYING:
					return
				var aim := Vector2.UP
				var distance := INF
				for rock: Dictionary in game.stage.asteroids:
					var offset: Vector2 = rock.position - game.stage.player
					if offset.length() < distance:
						distance = offset.length()
						aim = offset.normalized()
				game.stage.set_controls(aim, true)
				game.stage.advance(1.0 / 60.0)
	if game.stage.get_progress() < target:
		last_error = "CHECKPOINT STEP LIMIT"

func _feed_snake(target: int) -> void:
	for step_index in 4000:
		if game.stage.apples >= target or game.state != game.State.PLAYING:
			return
		var snake: RefCounted = game.stage
		var blocked: Array[Vector2i] = snake.body.slice(1)
		blocked.append_array(snake.walls)
		blocked.append_array(snake.spiders)
		if snake.direction != Vector2i.ZERO:
			blocked.append(Grid.wrap(snake.body[0] - snake.direction))
		var path := _path(snake.body[0], snake.apple, blocked, true)
		if path.is_empty():
			last_error = "NO SAFE SNAKE ROUTE"
			return
		snake.steer(_heading_to(snake.body[0], path[0]))
		snake.step()
	last_error = "CHECKPOINT STEP LIMIT"

func _collect_pellets(target: int) -> void:
	for step_index in 4000:
		if game.stage.collected >= target or game.state != game.State.PLAYING:
			return
		var maze: RefCounted = game.stage
		var best: Array[Vector2i] = []
		var blocked: Array[Vector2i] = []
		if maze.ghost_alive:
			blocked.append(maze.ghost)
		for pellet: Vector2i in maze.pellets:
			var route := _path(maze.body[0], pellet, blocked, false, maze)
			if not route.is_empty() and (best.is_empty() or route.size() < best.size()):
				best = route
		if best.is_empty():
			last_error = "NO SAFE PELLET ROUTE"
			return
		maze.steer(best[0] - maze.body[0])
		maze.step()
	last_error = "CHECKPOINT STEP LIMIT"

func _heading_to(origin: Vector2i, destination: Vector2i) -> Vector2i:
	for heading in Grid.DIRECTIONS:
		if Grid.wrap(origin + heading) == destination:
			return heading
	return Vector2i.ZERO

func _path(start: Vector2i, target: Vector2i, blocked: Array[Vector2i], wrapping: bool, maze: RefCounted = null) -> Array[Vector2i]:
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
			var next := Grid.wrap(cell + heading) if wrapping else cell + heading
			if not Grid.inside(next) or next in blocked or previous.has(next):
				continue
			if maze != null and not maze.walkable(next):
				continue
			previous[next] = cell
			queue.append(next)
	return []

func draw_overlay(canvas: CanvasItem) -> void:
	if not active:
		return
	Art.text(canvas, "DEV %d / %s" % [game.active_seed, game.profile], Vector2(167, 12), 1, Art.DARK)
	if not panel_open:
		return
	canvas.draw_rect(Rect2(24, 36, 352, 151), Art.LIGHT)
	canvas.draw_rect(Rect2(24, 36, 352, 151), Art.INK, false, 2)
	var lines := ["PLAYTEST / DEBUG ONLY", "F2/F3 STAGE: " + Pacing.STAGES[stage_index],
		"F4 PRESET: " + PRESETS[preset_index], "F5 REBUILD / F6 INVULNERABLE: " + str(game.invulnerable),
		"F7 COMPLETE / F8 NEXT SEED", "F9 PROFILE: " + game.profile, "F1 OR BUTTON B CLOSE"]
	for index in lines.size():
		Art.text(canvas, lines[index], Vector2(35, 46 + index * 18))
	if not last_error.is_empty():
		Art.centered(canvas, last_error, 178)
