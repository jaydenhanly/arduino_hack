extends "res://tests/autopilot/probe_base.gd"

const Grid = preload("res://scripts/grid.gd")
const SEED := 42
const TICK := 1.0 / 120.0
const TARGETS := {
	"normal": {"snake": 10, "maze": 30, "frogger": 3, "asteroids": 12},
	"demo": {"snake": 3, "maze": 10, "frogger": 1, "asteroids": 4},
}

var game: Node
var failures: Array[String] = []
var trace: Array[Dictionary] = []
var input_count := 0
var simulated_seconds := 0.0
var run_label := ""

func check(label: String, passed: bool) -> bool:
	report(label, passed)
	if not passed:
		failures.append(label)
	return passed

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().current_scene
	if not check("main_scene_available", game != null):
		_complete()
		return
	game.set_process(false)
	game.model_enabled = false
	game.pixel.model_enabled = false
	game.seed_override = SEED
	report("method", "Existing main scene; real Input events; GameFlow._process at deterministic simulation deltas; renderer continues normally. No counter, position, collision, near-win, or invulnerability fixtures. Wall-clock pacing is not tested.")
	report("seed", SEED)
	check("title_on_launch", game.state == game.State.TITLE)
	await _capture("00_title")
	for profile_name in ["normal", "demo"]:
		if not await _full_run(profile_name, "dialogue"):
			_complete()
			return
	if not await _full_run("demo", "skip_conversation"):
		_complete()
		return
	if not await _full_run("demo", "skip_payoff"):
		_complete()
		return
	await _death_and_replay()
	check("all_scenarios_completed", true)
	_complete()

func _complete() -> void:
	_release_controls()
	report("trace", trace)
	report("input_events", input_count)
	report("simulated_seconds", simulated_seconds)
	report("failure_count", failures.size())
	if not failures.is_empty():
		report("error", ", ".join(failures))
	finish()

func _event(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	input_count += 1

func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)

func _direction(heading: Vector2i) -> void:
	var index := Grid.DIRECTIONS.find(heading)
	if index >= 0:
		_tap(Grid.ACTIONS[index])

func _release_controls() -> void:
	for action in Grid.ACTIONS:
		_event(action, false)
	_event("shoot", false)

func _tick(delta: float) -> void:
	game._process(delta)
	simulated_seconds += delta

func _capture(label: String) -> void:
	game.queue_redraw()
	game.board.queue_redraw()
	game.pixel_panel.queue_redraw()
	await settle(2)
	check("frame_" + label, not save_frame(label).is_empty())

func _full_run(profile_name: String, ending: String) -> bool:
	run_label = profile_name + "_" + ending
	_release_controls()
	game.profile = profile_name
	if game.state != game.State.TITLE:
		_tap("cancel")
	_tap("confirm")
	if not check(run_label + "_start", game.state == game.State.PLAYING and game.current_stage == "snake"):
		return false
	var initial_run_id: int = game.run_id
	check(run_label + "_seeded_one_life", game.active_seed == SEED and game.lives == 1 and not game.invulnerable)
	check(run_label + "_model_disabled", not game.pixel.model_enabled and not game.pixel.thinking)
	check(run_label + "_journal_new_run", game.pixel.journal.run_id == initial_run_id and game.pixel.journal.count("run_ended") == 0)
	for stage_name in ["snake", "maze", "frogger", "asteroids"]:
		if not check(run_label + "_" + stage_name + "_entered", game.current_stage == stage_name and game.state == game.State.PLAYING):
			return false
		var stage: RefCounted = game.stage
		var entry_score: int = game.score
		check(run_label + "_" + stage_name + "_target", stage.target == TARGETS[profile_name][stage_name])
		check(run_label + "_" + stage_name + "_vulnerable", not stage.invulnerable)
		var idle: Dictionary = stage.snapshot()
		_tick(1.0)
		check(run_label + "_" + stage_name + "_waits_for_input", stage.snapshot() == idle)
		_pause_check(run_label + "_" + stage_name + "_idle_pause")
		await _capture(run_label + "_" + stage_name + "_entry")
		var completed := false
		match stage_name:
			"snake": completed = await _snake(stage.target)
			"maze": completed = await _maze()
			"frogger": completed = await _frogger()
			"asteroids": completed = await _asteroids()
		trace.append({"run": run_label, "stage": stage_name, "progress": stage.get_progress(), "target": stage.target, "lives": game.lives, "score": game.score, "state": game.state, "run_id": game.run_id})
		if not check(run_label + "_" + stage_name + "_real_objective", completed and stage.get_progress() == stage.target and game.lives == 1 and not stage.invulnerable):
			report("blocked_snapshot", stage.snapshot())
			await _capture(run_label + "_blocked")
			return false
		var base_points := int(TARGETS[profile_name][stage_name]) * int({"snake": 10, "maze": 5, "frogger": 100, "asteroids": 50}[stage_name])
		var gained: int = game.score - entry_score
		check(run_label + "_" + stage_name + "_score", gained == base_points or (stage_name == "maze" and gained >= base_points and (gained - base_points) % 100 == 0))
		check(run_label + "_" + stage_name + "_same_run", game.run_id == initial_run_id)
		if stage_name != "asteroids":
			if not await _transition(stage):
				return false
	_release_controls()
	if not check(run_label + "_evolved", game.state == game.State.EVOLVED):
		return false
	check(run_label + "_victory_journal", game.pixel.journal.count("victory") == 1 and game.pixel.journal.count("run_ended") == 1)
	check(run_label + "_all_stages_journaled", game.pixel.journal.count("stage_start") == 4 and game.pixel.journal.count("transformation_completed") == 3)
	await _capture(run_label + "_evolved")
	if ending == "skip_payoff":
		_tap("cancel")
	else:
		_tick(1.21)
		if not check(run_label + "_conversation", game.state == game.State.CONVERSATION and game.pixel.conversing and game.pixel.choices.size() == 3):
			return false
		check(run_label + "_journal_retained", game.pixel.journal.run_id == initial_run_id and game.pixel.journal.count("victory") == 1)
		await _capture(run_label + "_conversation")
		if ending == "skip_conversation":
			_tick(0.16)
			_tap("move_down")
			_tap("confirm")
			check(run_label + "_selection_before_skip", game.pixel.exchange == 1)
			_tap("cancel")
		else:
			for exchange_index in 3:
				check(run_label + "_choices_%d" % exchange_index, game.pixel.exchange == exchange_index and game.pixel.choices.size() == 3 and _distinct_choices())
				for movement in exchange_index:
					_tick(0.16)
					_tap("move_down")
				check(run_label + "_highlight_%d" % exchange_index, game.pixel_panel.selected == exchange_index)
				_tap("confirm")
				check(run_label + "_selection_%d" % exchange_index, game.pixel.exchange == exchange_index + 1)
				await _capture(run_label + "_exchange_%d" % (exchange_index + 1))
			check(run_label + "_farewell", game.state == game.State.CONVERSATION and game.pixel.choices.is_empty() and not game.pixel.message.is_empty())
			_tap("confirm")
			check(run_label + "_no_fourth_exchange", game.pixel.exchange == 3)
			_tick(2.0)
	if not check(run_label + "_replay_screen", game.state == game.State.VICTORY and not game.pixel.conversing and game.pixel.choices.is_empty()):
		return false
	check(run_label + "_journal_cleared_on_exit", game.pixel.journal.entries().is_empty())
	await _capture(run_label + "_replay_screen")
	_tap("confirm")
	check(run_label + "_replay_fresh", game.state == game.State.PLAYING and game.current_stage == "snake" and game.run_id == initial_run_id + 1 and game.lives == 1 and game.score == 0 and game.stage.get_progress() == 0 and game.pixel.exchange == 0 and game.pixel.choices.is_empty() and game.pixel.journal.count("victory") == 0)
	return true

func _distinct_choices() -> bool:
	var unique := {}
	for choice in game.pixel.choices:
		if choice.strip_edges().is_empty():
			return false
		unique[choice] = true
	return unique.size() == 3

func _pause_check(label: String) -> void:
	var previous_state: int = game.state
	_tap("pause")
	check(label + "_entered", game.state == game.State.PAUSED)
	var before: Dictionary = game.stage.snapshot()
	var clock_before: float = game.clock
	var elapsed_before: float = game.run_elapsed
	var shift_before: float = game.shift_elapsed
	var score_before: int = game.score
	var pixel_before: Dictionary = game.pixel.conversation_context()
	_tick(2.0)
	check(label + "_frozen", game.stage.snapshot() == before and game.clock == clock_before and game.run_elapsed == elapsed_before and game.shift_elapsed == shift_before and game.score == score_before and game.pixel.conversation_context() == pixel_before)
	_tap("pause")
	check(label + "_resumed", game.state == previous_state)

func _transition(completed: RefCounted) -> bool:
	var label: String = run_label + "_shift_" + game.current_stage
	if not check(label + "_started", game.state == game.State.SHIFTING):
		return false
	check(label + "_source_preserved", game.next_stage.source == completed.snapshot())
	await _capture(label + "_start")
	_tick(1.5)
	check(label + "_halfway", game.state == game.State.SHIFTING and is_equal_approx(game.board.shift_progress, 0.5))
	_pause_check(label + "_pause")
	await _capture(label + "_middle")
	_tick(1.49)
	check(label + "_not_early", game.state == game.State.SHIFTING)
	_tick(0.011)
	return check(label + "_three_seconds", game.state == game.State.PLAYING and is_equal_approx(game.shift_elapsed, 3.0))

func _route(start: Vector2i, goals: Array, blocked: Dictionary, wrapping: bool) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	var cursor := 0
	while cursor < queue.size() and cursor < Grid.SIZE.x * Grid.SIZE.y:
		var cell := queue[cursor]
		cursor += 1
		if cell != start and cell in goals:
			var result: Array[Vector2i] = []
			while cell != start:
				result.push_front(cell)
				cell = parents[cell]
			return result
		for heading in Grid.DIRECTIONS:
			var next := Grid.wrap(cell + heading) if wrapping else cell + heading
			if not Grid.inside(next) or blocked.has(next) or parents.has(next):
				continue
			parents[next] = cell
			queue.append(next)
	return []

func _heading(start: Vector2i, destination: Vector2i) -> Vector2i:
	for heading in Grid.DIRECTIONS:
		if Grid.wrap(start + heading) == destination:
			return heading
	return Vector2i.ZERO

func _snake(objective: int) -> bool:
	var stage: RefCounted = game.stage
	for decision in 5000:
		if game.state != game.State.PLAYING or stage.get_progress() >= objective:
			return stage.get_progress() == objective
		var blocked := {}
		for cell in stage.body.slice(1):
			blocked[cell] = true
		for cell in stage.walls:
			blocked[cell] = true
		for cell in stage.spiders:
			blocked[cell] = true
		if stage.direction != Vector2i.ZERO:
			blocked[Grid.wrap(stage.body[0] - stage.direction)] = true
		var route := _route(stage.body[0], [stage.apple], blocked, true)
		if route.is_empty():
			return false
		_direction(_heading(stage.body[0], route[0]))
		var before: Vector2i = stage.body[0]
		for tick_index in 60:
			_tick(TICK)
			if stage.body[0] != before or game.state != game.State.PLAYING:
				break
		if decision == 2:
			_pause_check(run_label + "_snake_active_pause")
			await _capture(run_label + "_snake_active")
		if decision % 48 == 0:
			await settle()
	return false

func _maze() -> bool:
	var stage: RefCounted = game.stage
	for decision in 5000:
		if game.state != game.State.PLAYING:
			return stage.get_progress() == stage.target
		var blocked := {}
		for row in Grid.SIZE.y:
			for column in Grid.SIZE.x:
				var cell := Vector2i(column, row)
				if not stage.walkable(cell) or (stage.ghost_alive and _grid_distance(cell, stage.ghost) <= 1):
					blocked[cell] = true
		var route := _route(stage.body[0], stage.pellets, blocked, false)
		var heading := Vector2i.ZERO
		if not route.is_empty():
			heading = route[0] - stage.body[0]
		else:
			var safest := -1
			for candidate in Grid.DIRECTIONS:
				var destination: Vector2i = stage.body[0] + candidate
				var distance := _grid_distance(destination, stage.ghost)
				if stage.walkable(destination) and not blocked.has(destination) and distance > safest:
					heading = candidate
					safest = distance
		if heading == Vector2i.ZERO:
			return false
		_direction(heading)
		_tick(0.15)
		if decision == 2:
			_pause_check(run_label + "_maze_active_pause")
			await _capture(run_label + "_maze_active")
		if decision % 48 == 0:
			await settle()
	return false

func _grid_distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)

func _frog_safe(stage: RefCounted, destination: Vector2i) -> bool:
	var center := (float(destination.x) + 0.5) * 12.0
	for lane: Dictionary in stage.lanes:
		if int(lane.row) != destination.y:
			continue
		for tick_index in 24:
			var phase := fposmod(float(lane.phase) + float(lane.direction) * float(lane.speed) * TICK * tick_index, float(lane.spacing))
			for vehicle in range(-1, 4):
				var left := phase + vehicle * float(lane.spacing)
				if center + 4.5 > left and center - 4.5 < left + float(lane.width):
					return false
	return true

func _frogger() -> bool:
	var stage: RefCounted = game.stage
	if not _frog_safe(stage, stage.player + Vector2i.UP):
		_direction(Vector2i.RIGHT if stage.player.x < Grid.SIZE.x - 1 else Vector2i.LEFT)
		_tick(19.0 * TICK)
	for decision in 12000:
		if game.state != game.State.PLAYING:
			return stage.get_progress() == stage.target
		if _frog_safe(stage, stage.player + Vector2i.UP):
			_direction(Vector2i.UP)
			_tick(19.0 * TICK)
		else:
			_tick(TICK)
		if decision == 2:
			_pause_check(run_label + "_frogger_active_pause")
			await _capture(run_label + "_frogger_active")
		if decision % 48 == 0:
			await settle()
	return false

func _analog(axis: Vector2) -> void:
	var raw_axis := axis.normalized() * (0.5 + axis.length() * 0.5) if axis != Vector2.ZERO else Vector2.ZERO
	for index in Grid.DIRECTIONS.size():
		var strength := maxf(0.0, raw_axis.dot(Vector2(Grid.DIRECTIONS[index])))
		_event(Grid.ACTIONS[index], strength > 0.0, strength)

func _asteroids() -> bool:
	var stage: RefCounted = game.stage
	_event("shoot", true)
	for decision in 24000:
		if game.state != game.State.PLAYING:
			_release_controls()
			return stage.get_progress() == stage.target
		var aim := Vector2.UP
		var closest := INF
		for asteroid: Dictionary in stage.asteroids:
			if float(asteroid.warning) > 0.0:
				continue
			var offset: Vector2 = asteroid.position - stage.player
			offset = Vector2(wrapf(offset.x, -188.0, 188.0), wrapf(offset.y, -78.0, 78.0))
			if offset.length() < closest:
				closest = offset.length()
				aim = (offset + Vector2(asteroid.velocity) * offset.length() / 225.0).normalized()
		_analog(aim * 0.16)
		_tick(1.0 / 60.0)
		if decision == 2:
			_pause_check(run_label + "_asteroids_active_pause")
			check(run_label + "_asteroids_analog_input", is_equal_approx(stage.axis.length(), 0.16) and stage.firing)
			await _capture(run_label + "_asteroids_active")
		if decision % 48 == 0:
			await settle()
	_release_controls()
	return false

func _death_and_replay() -> void:
	run_label = "death"
	if not await _snake(2):
		check("death_setup_two_real_apples", false)
		return
	var heading: Vector2i = game.stage.direction
	for turn in 4:
		if game.state == game.State.GAME_OVER:
			break
		heading = Vector2i(-heading.y, heading.x)
		_direction(heading)
		var before: Vector2i = game.stage.body[0]
		for tick_index in 60:
			_tick(TICK)
			if game.state == game.State.GAME_OVER or game.stage.body[0] != before:
				break
	check("death_real_tail_collision", game.state == game.State.GAME_OVER and game.lives == 0 and not game.stage.invulnerable)
	var stopped: Dictionary = game.stage.snapshot()
	_tick(2.0)
	check("death_freezes_stage", game.stage.snapshot() == stopped)
	await _capture("death_game_over")
	var previous_run: int = game.run_id
	_tap("confirm")
	check("death_replay", game.run_id == previous_run + 1 and game.lives == 1 and game.score == 0 and game.current_stage == "snake" and game.state == game.State.PLAYING)
	_tap("pause")
	_tap("cancel")
	check("pause_cancel_title", game.state == game.State.TITLE and game.pixel.journal.entries().is_empty())
	await _capture("final_title")
