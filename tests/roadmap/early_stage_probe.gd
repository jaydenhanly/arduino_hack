extends SceneTree

const Snake = preload("res://scripts/snake_stage.gd")
const Maze = preload("res://scripts/maze_stage.gd")
const Grid = preload("res://scripts/grid.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_snake_rules()
	_test_snake_hazards()
	_test_maze_geometry()
	_test_maze_objective()
	_test_maze_collisions()
	_test_respawn()
	_test_snapshots()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("EARLY_STAGE_PROBE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _observe(stage: RefCounted) -> Dictionary:
	var events := {"points": 0, "deaths": 0, "completed": 0, "journal": []}
	stage.points_earned.connect(func(amount: int) -> void: events.points += amount)
	stage.life_lost.connect(func(_reason: String) -> void: events.deaths += 1)
	stage.objective_completed.connect(func() -> void: events.completed += 1)
	stage.journal_event.connect(func(kind: String, tags: Dictionary) -> void:
		events.journal.append({"kind": kind, "tags": tags.duplicate(true)})
	)
	return events

func _journal_count(events: Dictionary, kind: String) -> int:
	var count := 0
	for event: Dictionary in events.journal:
		if event.kind == kind:
			count += 1
	return count

func _feed_snake(stage: RefCounted) -> void:
	stage.apple = Grid.wrap(stage.body[0] + stage.direction)
	stage.step()

func _source(seed_value: int = 42) -> Dictionary:
	return {
		"stage": "snake", "seed": seed_value,
		"body": [Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(3, 6), Vector2i(2, 6), Vector2i(1, 6)],
		"direction": Vector2i.RIGHT, "apple": Vector2i(10, 6), "ghost_seed": Vector2i(-1, -1)
	}

func _test_snake_rules() -> void:
	var stage := Snake.new()
	var events := _observe(stage)
	stage.initialize(42, {"target": 3, "advanced_hazards": false})
	stage.advance(20.0)
	stage.steer(Vector2i(2, 0))
	_check(stage.body.size() == 1 and stage.awaiting_input, "Snake waits for cardinal input")
	stage.steer(Vector2i.RIGHT)
	_check(stage.body.size() == 3 and not stage.awaiting_input, "Snake stretches on first input")
	stage.steer(Vector2i.LEFT)
	_check(stage.pending_direction == Vector2i.RIGHT, "Snake forbids direct reversal")
	stage.steer(Vector2i.UP)
	stage.steer(Vector2i.LEFT)
	_check(stage.pending_direction == Vector2i.UP, "Snake cannot reverse using two buffered inputs")
	stage.steer(Vector2i.RIGHT)
	var initial_speed := stage.current_step_seconds()
	for apple_index in 3:
		_feed_snake(stage)
		_check(stage.apples == apple_index + 1, "Snake apple progress")
	_check(stage.stopped and stage.get_progress() == 3, "Snake configurable Demo objective")
	_check(events.points == 30 and events.completed == 1, "Snake points and completion are emitted once")
	_check(stage.body.size() == 6, "Demo Snake grows one cell per apple")
	_check(stage.current_step_seconds() < initial_speed, "Snake speed increases")
	stage.step()
	_check(events.completed == 1, "Stopped Snake cannot complete twice")
	_check(_journal_count(events, "collect") == 3 and _journal_count(events, "objective_completed") == 1, "Snake collect and objective journal")
	var maze := Maze.new()
	maze.initialize(stage.snapshot(), {"target": 10})
	_check(maze.body.size() >= 9 and maze.body.slice(0, 6) == stage.body, "Real Demo handoff keeps Snake and adds eight-cell tail")
	_check(_valid_body(maze), "Real Demo handoff has distinct adjacent walkable tail")
	for heading in Grid.DIRECTIONS:
		stage.initialize(8, {"advanced_hazards": false})
		stage.steer(heading)
		for cell in stage.body:
			_check(Grid.inside(cell), "Snake starting stretch stays in bounds")
	stage.initialize(8, {"target": 10, "advanced_hazards": false})
	stage.steer(Vector2i.RIGHT)
	for apple_index in 10:
		_feed_snake(stage)
	_check(stage.apples == 10 and stage.stopped and stage.walls.is_empty(), "Normal Snake target disables legacy hazards")
	stage.apples = 1000
	_check(is_equal_approx(stage.current_step_seconds(), Snake.MIN_STEP_SECONDS), "Snake speed is capped")
	stage.initialize(8)
	stage.steer(Vector2i.RIGHT)
	stage.body.assign([Vector2i(23, 6), Vector2i(22, 6), Vector2i(21, 6)])
	stage.apple = Vector2i(10, 10)
	stage.step()
	_check(stage.body[0] == Vector2i(0, 6), "Snake wraps screen edges")
	stage.body.assign([Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7), Vector2i(7, 6)])
	stage.step()
	_check(not stage.stopped and stage.body[0] == Vector2i(7, 6), "Snake may enter vacated tail cell")
	stage.body.assign([Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7), Vector2i(7, 6), Vector2i(8, 6)])
	stage.step()
	_check(stage.stopped and events.deaths == 1, "Snake self collision is fatal")
	_check(_journal_count(events, "death") == 1, "Snake death journal")
	stage.initialize(8)
	_check(stage.target == Snake.APPLE_TARGET and stage.awaiting_input and stage.body.size() == 1, "Snake legacy defaults and replay reset")
	print("PASS Snake movement, objectives, continuity, replay")

func _test_snake_hazards() -> void:
	for threshold in [10, 15, 20]:
		var stage := Snake.new()
		var twin := Snake.new()
		for candidate in [stage, twin]:
			candidate.initialize(101)
			candidate.steer(Vector2i.RIGHT)
			candidate.apples = threshold - 1
			_feed_snake(candidate)
		_check(stage.snapshot() == twin.snapshot(), "Snake legacy hazards are seeded")
		if threshold == 10:
			_check(stage.walls.size() == Snake.TIER_ONE_WALLS, "Snake tier-one walls retained")
		elif threshold == 15:
			_check(stage.walls.size() == Snake.TIER_TWO_WALLS and stage.spiders.size() == 1, "Snake spider tier retained")
		else:
			_check(Grid.inside(stage.mushroom), "Snake mushroom tier retained")
		for wall in stage.walls:
			_check(wall not in stage.body and wall not in stage._forward_lookahead(), "Snake wall spawns avoid body and forward path")
		for sample in 20:
			stage.spawn_apple()
			_check(stage.apple not in stage.body and stage.apple not in stage.walls and stage.apple not in stage.spiders and stage.apple != stage.mushroom, "Snake seeded apples occupy safe cells")
	var stage := Snake.new()
	stage.initialize(8)
	stage.steer(Vector2i.RIGHT)
	stage.mushroom = stage.body[0] + Vector2i.RIGHT
	stage.step()
	_check(is_equal_approx(stage.boost_elapsed, Snake.BOOST_DURATION), "Snake mushroom enables legacy boost")
	_check(is_equal_approx(stage.current_step_seconds(), Snake.BOOST_STEP_SECONDS), "Snake boost changes speed")
	stage.stretch = 0.0
	stage.advance(0.01)
	_check(stage.boost_elapsed < Snake.BOOST_DURATION, "Snake boost timer expires through advance")
	for hazard in ["wall", "spider"]:
		stage.initialize(8)
		stage.steer(Vector2i.RIGHT)
		if hazard == "wall":
			stage.walls.append(stage.body[0] + Vector2i.RIGHT)
		else:
			stage.spiders.append(stage.body[0] + Vector2i.RIGHT)
		stage.step()
		_check(stage.stopped, "Snake legacy " + hazard + " collision")
	stage.initialize(8, {"advanced_hazards": false})
	stage.steer(Vector2i.RIGHT)
	stage.apples = 19
	_feed_snake(stage)
	_check(stage.mushroom == Snake.OFF_GRID, "Disabled advanced hazards do not spawn mushrooms")
	stage.initialize(8)
	stage.steer(Vector2i.RIGHT)
	stage.invulnerable = true
	stage.walls.append(stage.body[0] + Vector2i.RIGHT)
	stage.step()
	_check(not stage.stopped and stage.body[0] == Vector2i(6, 6), "Snake invulnerability blocks lethal step")
	print("PASS Snake legacy hazard regression checks")

func _valid_body(stage: RefCounted) -> bool:
	var occupied := {}
	for index in stage.body.size():
		var cell: Vector2i = stage.body[index]
		if not stage.walkable(cell) or occupied.has(cell):
			return false
		occupied[cell] = true
		if index > 0:
			var previous: Vector2i = stage.body[index - 1]
			if absi(cell.x - previous.x) + absi(cell.y - previous.y) != 1:
				return false
	return true

func _test_maze_geometry() -> void:
	var layouts := {}
	for seed_value in 64:
		var stage := Maze.new()
		var twin := Maze.new()
		stage.initialize(_source(seed_value), {"target": 30})
		twin.initialize(_source(seed_value), {"target": 30})
		_check(stage.snapshot() == twin.snapshot(), "Maze identical seed yields identical geometry")
		layouts[str(stage.walls)] = true
		_check(stage.body.size() >= 9 and _valid_body(stage), "Maze eight valid tail cells at seed " + str(seed_value))
		_check(stage.walls.size() == Maze.WALL_COUNT, "Maze four safe walls at seed " + str(seed_value))
		var reachable: Array[Vector2i] = stage.reachable_cells(stage.body[0])
		_check(reachable.size() == Grid.SIZE.x * Grid.SIZE.y - stage.walls.size() * 10, "Maze geometry is connected")
		_check(stage.pellets.size() >= stage.target, "Maze has enough reachable Normal pellets")
		for pellet in stage.pellets:
			_check(pellet in reachable and pellet not in stage.body and pellet != stage.ghost, "Maze pellet is safe and reachable")
		_check(stage._safe_ghost_cell(stage.ghost), "Maze initial ghost cannot collide on first input")
		for heading in Grid.DIRECTIONS:
			_check(stage.walkable(stage.body[0] + heading), "Maze preserves starting exits")
	_check(layouts.size() > 1, "Maze seeds vary layouts")
	for row in Grid.SIZE.y:
		for column in Grid.SIZE.x:
			for heading in Grid.DIRECTIONS:
				var previous: Array[Vector2i] = []
				for index in 6:
					previous.append(Grid.wrap(Vector2i(column, row) - heading * index))
				var stage := Maze.new()
				stage.initialize({"body": previous, "direction": heading, "seed": row * 24 + column}, {"target": 10})
				_check(stage.body[0] == previous[0] and stage.body.size() >= 9 and _valid_body(stage), "Maze repairs wrapped Demo tail at " + str(previous[0]) + str(heading))
	var stage := Maze.new()
	stage.initialize({"body": [Vector2i(0, 0)], "direction": Vector2i.LEFT})
	var before := stage.snapshot()
	stage.steer(Vector2i.LEFT)
	stage.steer(Vector2i(1, 1))
	stage.advance(100.0)
	stage.step()
	stage.step_ghost()
	_check(not stage.started and stage.snapshot() == before, "Maze blocked or invalid first input leaves hazards inactive")
	stage.steer(Vector2i.DOWN)
	_check(stage.started and stage.direction == Vector2i.DOWN, "Maze first legal input chooses safe movement")
	stage.initialize(_source())
	_check(stage.reachable_cells(Vector2i(-1, 0)).is_empty(), "Maze rejects unreachable start")
	print("PASS Maze seeded geometry and 1,152 wrapped-tail handoffs")

func _test_maze_objective() -> void:
	var stage := Maze.new()
	var events := _observe(stage)
	stage.initialize(_source(), {"target": 2})
	stage.walls.clear()
	stage.ghost_alive = false
	stage.ghost_respawn_remaining = 4.0
	stage.pellets.assign([Vector2i(7, 6), Vector2i(8, 6)])
	stage.steer(Vector2i.RIGHT)
	stage.step()
	_check(stage.get_progress() == 1 and events.points == 5 and events.completed == 0, "Maze pellets earn progress and points")
	stage.step()
	_check(stage.stopped and stage.get_progress() == 2 and events.completed == 1 and events.points == 10, "Maze pellet target alone completes objective")
	stage.step()
	stage.advance(10.0)
	_check(events.completed == 1 and events.points == 10, "Maze objective completion freezes play")
	_check(_journal_count(events, "collect") == 2 and _journal_count(events, "objective_completed") == 1, "Maze pellet journal events")
	stage.initialize(_source(), {"target": 1000})
	stage.walls.clear()
	stage.pellets.assign([Vector2i(7, 6)])
	stage.steer(Vector2i.RIGHT)
	stage.step()
	_check(stage.collected == 1 and not stage.pellets.is_empty() and not stage.stopped, "Maze refills pellets for custom targets")
	stage.walls.assign([Rect2i(7, 5, 1, 1)])
	stage.steer(Vector2i.UP)
	stage.step()
	_check(stage.body[0] == Vector2i(8, 6) and stage.pending_direction == Vector2i.UP, "Maze buffers blocked turn while moving forward")
	stage.step()
	_check(stage.body[0] == Vector2i(8, 5), "Maze takes buffered turn when corridor opens")
	_check(stage.body.size() == 9, "Maze preserves full tail during movement")
	print("PASS Maze pellet objective and buffered turns")

func _tail_defeat(seed_value: int = 42, options: Dictionary = {}) -> RefCounted:
	var stage := Maze.new()
	stage.initialize(_source(seed_value), options)
	stage.walls.clear()
	stage.body.clear()
	for column in 9:
		stage.body.append(Vector2i(column, 0))
	stage.direction = Vector2i.UP
	stage.pending_direction = Vector2i.UP
	stage.started = true
	stage.ghost = Vector2i(1, 1)
	return stage

func _test_maze_collisions() -> void:
	var stage := Maze.new()
	var events := _observe(stage)
	stage.initialize(_source())
	stage.walls.clear()
	stage.steer(Vector2i.RIGHT)
	stage.ghost = stage.body[0] + Vector2i.RIGHT
	stage.step()
	_check(stage.stopped and events.deaths == 1, "Maze head entering ghost is fatal")
	stage.step_ghost()
	_check(events.deaths == 1, "Maze death emitted once")
	stage.initialize(_source())
	stage.walls.clear()
	stage.steer(Vector2i.RIGHT)
	stage.ghost = stage.body[0] + Vector2i.UP
	stage.step_ghost()
	_check(stage.stopped and events.deaths == 2, "Maze ghost entering head is fatal")
	stage.initialize(_source())
	stage.steer(Vector2i.RIGHT)
	stage.ghost = stage.body[0]
	stage.step()
	_check(stage.stopped and events.deaths == 3, "Maze existing head overlap cannot escape collision")
	stage.initialize(_source())
	stage.walls.clear()
	stage.invulnerable = true
	stage.steer(Vector2i.RIGHT)
	stage.ghost = stage.body[0] + Vector2i.RIGHT
	stage.step()
	stage.step_ghost()
	_check(not stage.stopped and events.deaths == 3, "Maze invulnerability suppresses head deaths")
	_check(_journal_count(events, "death") == 3, "Maze collision journal events")
	stage = _tail_defeat(42, {"target": 1})
	events = _observe(stage)
	stage.step_ghost()
	_check(not stage.ghost_alive and not stage.stopped, "Maze tail defeats ghost without stopping stage")
	_check(events.points == 100 and events.completed == 0 and stage.get_progress() == 0, "Maze ghost bonus is not objective progress")
	_check(stage.ghosts_defeated == 1 and _journal_count(events, "ghost_defeated") == 1, "Maze tail attack journal")
	stage.step_ghost()
	_check(events.points == 100, "Dead Maze ghost cannot award duplicate bonus")
	stage = _tail_defeat()
	stage.ghost = stage.body[8]
	stage.step_ghost()
	_check(not stage.ghost_alive, "Maze eighth tail cell defeats overlapping ghost")
	print("PASS Maze head collisions and eight-cell tail attacks")

func _test_respawn() -> void:
	var stage := _tail_defeat()
	var twin := _tail_defeat()
	var events := _observe(stage)
	stage.step_ghost()
	twin.step_ghost()
	stage.advance(3.249)
	_check(not stage.ghost_alive and not stage.respawn_warning, "Maze default respawn stays hidden before warning")
	stage.advance(0.001)
	_check(stage.respawn_warning and not stage.ghost_alive, "Maze warning appears 0.75 seconds before four-second respawn")
	_check(stage.ghost == stage.ghost_respawn_cell and stage.ghost_next == stage.ghost, "Maze board warning uses ghost position")
	_check(stage._safe_ghost_cell(stage.ghost), "Maze warned spawn is distant and unoccupied")
	_check(stage.ghost.x == 0 or stage.ghost.y == 0 or stage.ghost.x == Grid.SIZE.x - 1 or stage.ghost.y == Grid.SIZE.y - 1, "Maze warned spawn is an edge cell")
	var warned_cell: Vector2i = stage.ghost
	stage.advance(0.749)
	_check(not stage.ghost_alive, "Maze ghost cannot spawn before delay expires")
	stage.advance(0.001)
	_check(stage.ghost_alive and not stage.respawn_warning and stage.ghost == warned_cell, "Maze ghost respawns on warned cell after four seconds")
	_check(_journal_count(events, "ghost_warning") == 1 and _journal_count(events, "ghost_respawn") == 1, "Maze warning and respawn journal")
	twin.advance(4.0)
	_check(twin.snapshot() == stage.snapshot(), "Maze respawn is deterministic across delta partitions")
	stage.advance(0.36)
	for tick in 36:
		twin.advance(0.01)
	_check(twin.snapshot() == stage.snapshot(), "Maze ghost movement starts a full tick after respawn")
	var spawn_cells := {}
	for seed_value in 32:
		stage = _tail_defeat(seed_value, {"ghost_respawn_seconds": 1.0, "ghost_warning_seconds": 0.2})
		stage.step_ghost()
		stage.advance(0.8)
		_check(stage.respawn_warning and not stage.ghost_alive, "Maze configurable warning timing")
		spawn_cells[stage.ghost] = true
		stage.advance(0.2)
		_check(stage.ghost_alive and stage._safe_ghost_cell(stage.ghost), "Maze configurable respawn delay and safety")
	_check(spawn_cells.size() > 1, "Maze respawn positions vary by seed")
	stage = _tail_defeat()
	events = _observe(stage)
	stage.step_ghost()
	stage.advance(3.25)
	warned_cell = stage.ghost
	stage.body[0] = warned_cell
	stage.direction = Vector2i.LEFT if warned_cell.x == 0 else Vector2i.RIGHT
	if warned_cell.y == 0 or warned_cell.y == Grid.SIZE.y - 1:
		stage.direction = Vector2i.UP if warned_cell.y == 0 else Vector2i.DOWN
	stage.pending_direction = stage.direction
	stage.advance(0.01)
	_check(stage.respawn_warning and stage.ghost != warned_cell and stage._safe_ghost_cell(stage.ghost), "Maze reselects warned cell if player approaches")
	_check(_journal_count(events, "ghost_warning") == 2, "Maze changed spawn gets a new warning")
	stage.advance(0.74)
	_check(not stage.ghost_alive, "Maze relocated spawn receives full warning duration")
	stage.advance(0.01)
	_check(stage.ghost_alive and stage._safe_ghost_cell(stage.ghost), "Maze relocated spawn remains safe at activation")
	stage.initialize(_source())
	_check(not stage.started and stage.ghost_alive and not stage.respawn_warning and stage.ghost_respawn_remaining == 0.0 and stage.ghosts_defeated == 0, "Maze initialization resets respawn lifecycle")
	print("PASS Maze warned, distant, seeded respawn lifecycle")

func _test_snapshots() -> void:
	var snake := Snake.new()
	snake.initialize(123, {"target": 3, "advanced_hazards": false})
	snake.steer(Vector2i.RIGHT)
	var snapshot := snake.snapshot()
	_check(snapshot.stage == "snake" and snapshot.seed == 123 and snapshot.progress == snake.get_progress(), "Snake snapshot contract")
	_check(snake.get_player_position() == Grid.rect(snake.body[0]).get_center(), "Snake position is logical pixel center")
	snapshot.body.clear()
	_check(snake.body.size() == 3, "Snake snapshot arrays are detached")
	var source := snake.snapshot()
	var maze := Maze.new()
	maze.initialize(source, {"seed": 456, "target": 10})
	source.body.clear()
	snapshot = maze.snapshot()
	_check(snapshot.stage == "maze" and snapshot.seed == 456 and snapshot.target == 10, "Maze snapshot contract and seed override")
	_check(maze.get_player_position() == Grid.rect(maze.body[0]).get_center(), "Maze position is logical pixel center")
	_check(snapshot.source.body.size() == 3 and snapshot.body.size() >= 9, "Maze source continuity is detached from caller")
	snapshot.body.clear()
	snapshot.source.body.clear()
	_check(maze.body.size() >= 9 and maze.source.body.size() == 3, "Maze snapshot deeply isolates source objects")
	print("PASS shared stage APIs and snapshot isolation")
