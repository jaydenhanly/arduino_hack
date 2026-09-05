extends Node

const Grid = preload("res://scripts/grid.gd")
const Art = preload("res://scripts/pixel_art.gd")
const PRESETS := ["start", "midpoint", "near-completion"]

var game: Node
var panel_open := false
var active := false
var seed_value := 2026
var preset_index := 0
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
		"dev_complete": KEY_F7, "dev_seed": KEY_F8, "dev_arena": KEY_F9}
	for action: String in bindings:
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
	elif active:
		if event.is_action_pressed("dev_snake"):
			select_stage("snake", PRESETS[preset_index])
		elif event.is_action_pressed("dev_maze"):
			select_stage("maze", PRESETS[preset_index])
		elif event.is_action_pressed("dev_arena"):
			select_stage("arena", PRESETS[preset_index])
		elif event.is_action_pressed("dev_preset"):
			preset_index = (preset_index + 1) % PRESETS.size()
			select_stage(game.current_stage, PRESETS[preset_index])
		elif event.is_action_pressed("dev_restart"):
			game.restart_stage()
		elif event.is_action_pressed("dev_invulnerable"):
			game.invulnerable = not game.invulnerable
			if game.stage != null:
				game.stage.invulnerable = game.invulnerable
		elif event.is_action_pressed("dev_complete"):
			complete_objective()
		elif event.is_action_pressed("dev_seed"):
			seed_value += 1
			select_stage(game.current_stage, PRESETS[preset_index])
		elif panel_open:
			if event.is_action_pressed("cancel"):
				panel_open = false
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()
	game.queue_redraw()

func select_stage(stage_name: String, preset: String = "start") -> void:
	active = true
	panel_open = false
	last_error = ""
	game.start_run(seed_value)
	if stage_name == "snake":
		var target := 0 if preset == "start" else (2 if preset == "midpoint" else 4)
		_feed_snake(target)
		game.stage.awaiting_input = true
	elif stage_name == "maze":
		_feed_snake(5)
		if game.state != game.State.SHIFTING:
			return
		game._enter_maze()
		if preset == "midpoint":
			_collect_pellets(5)
		elif preset == "near-completion":
			_prepare_tail_trap()
		game.stage.started = false
	else:
		_feed_snake(5)
		if game.state != game.State.SHIFTING:
			return
		game._enter_maze()
		if not _prepare_tail_trap():
			return
		game.stage.step_ghost()
		if game.state != game.State.SHIFTING:
			last_error = "NO ARENA ENTRY"
			return
		game._enter_arena()
		if preset == "midpoint":
			_advance_arena(150.0)
		elif preset == "near-completion":
			_advance_arena(270.0)
		game.stage.started = false

func complete_objective() -> void:
	if game.stage == null or game.state == game.State.TITLE:
		game.start_run(seed_value)
	if game.state == game.State.SHIFTING or (game.state == game.State.PAUSED and game.previous_state == game.State.SHIFTING):
		game.state = game.State.SHIFTING
		game.audio.set_paused(false)
		return
	if game.current_stage == "snake":
		if game.state == game.State.LIFE_LOST or game.state == game.State.GAME_OVER:
			game.restart_stage()
		if game.state == game.State.PAUSED:
			game.state = game.State.PLAYING
		_feed_snake(5)
	elif game.current_stage == "arena":
		if game.state != game.State.PLAYING:
			game.restart_stage()
		game.stage.started = true
		_advance_arena(game.stage.SURVIVE_SECONDS)
	else:
		if game.state != game.State.PLAYING:
			game.restart_stage()
		if _prepare_tail_trap():
			game.stage.step_ghost()

func _feed_snake(target: int) -> void:
	var steps := 0
	while game.current_stage == "snake" and game.stage.apples < target and steps < 1000:
		var snake: RefCounted = game.stage
		var blocked: Array[Vector2i] = snake.body.slice(1)
		blocked.append(snake.obstacle)
		if snake.direction != Vector2i.ZERO:
			blocked.append(snake.body[0] - snake.direction)
		var path := _path(snake.body[0], snake.apple, blocked)
		if path.is_empty():
			last_error = "NO SAFE SNAKE ROUTE"
			return
		snake.steer(path[0] - snake.body[0])
		snake.step()
		steps += 1
		if game.state != game.State.PLAYING:
			break
	if steps == 1000:
		last_error = "CHECKPOINT STEP LIMIT"

func _path(start: Vector2i, target: Vector2i, blocked: Array[Vector2i], maze: RefCounted = null) -> Array[Vector2i]:
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
			var next := cell + heading
			if not Grid.inside(next) or next in blocked or previous.has(next):
				continue
			if maze != null and not maze.walkable(next):
				continue
			previous[next] = cell
			queue.append(next)
	return []

func _walk(path: Array[Vector2i]) -> void:
	for cell in path:
		game.stage.steer(cell - game.stage.body[0])
		game.stage.step()
		if game.state != game.State.PLAYING:
			return

func _advance_arena(target_seconds: float) -> void:
	var arena: RefCounted = game.stage
	arena.invulnerable = true
	arena.started = true
	var ticks := 0
	while arena.survived < target_seconds and not arena.stopped and ticks < 20000:
		arena.advance(0.05)
		ticks += 1
	arena.invulnerable = game.invulnerable
	if ticks == 20000:
		last_error = "ARENA STEP LIMIT"

func _collect_pellets(target: int) -> void:
	while game.stage.collected < target and not game.stage.pellets.is_empty():
		var path := _path(game.stage.body[0], game.stage.pellets[0], [game.stage.ghost], game.stage)
		if path.is_empty():
			last_error = "NO PELLET ROUTE"
			return
		_walk(path)

func _prepare_tail_trap() -> bool:
	var maze: RefCounted = game.stage
	for heading in Grid.DIRECTIONS:
		var first: Vector2i = maze.ghost + heading
		var second: Vector2i = maze.ghost + heading * 2
		var third: Vector2i = maze.ghost + heading * 3
		if not maze.walkable(first) or not maze.walkable(second) or not maze.walkable(third):
			continue
		var route := _path(maze.body[0], first, [maze.ghost], maze)
		if route.is_empty() and maze.body[0] != first:
			continue
		route.append(second)
		route.append(third)
		_walk(route)
		return true
	last_error = "NO TAIL TRAP ROUTE"
	return false

func draw_overlay(canvas: CanvasItem) -> void:
	if not active:
		return
	Art.text(canvas, "DEV SEED %d  %s" % [game.active_seed, "INVULNERABLE" if game.invulnerable else "F1 TOOLS"], Vector2(6, 233), 1, Art.DARK)
	if not panel_open:
		return
	canvas.draw_rect(Rect2(30, 43, 340, 159), Art.LIGHT)
	canvas.draw_rect(Rect2(30, 43, 340, 159), Art.INK, false, 2)
	var lines := ["PLAYTEST / DEBUG BUILD ONLY", "F2 SNAKE  F3 MAZE  F9 ARENA", "F4 PRESET: " + PRESETS[preset_index],
		"F5 RESTART  F6 INVULNERABILITY", "F7 COMPLETE  F8 NEXT SEED", "F1 CLOSE / BUTTON B CLOSE"]
	for index in lines.size():
		Art.text(canvas, lines[index], Vector2(42, 55 + index * 21))
	if not last_error.is_empty():
		Art.centered(canvas, last_error, 187)
