extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed
signal boost_triggered
signal tail_severed(segments: int)

const Grid = preload("res://scripts/grid.gd")
const BASE_STEP_SECONDS := 0.15
const MIN_STEP_SECONDS := 0.07
const STEP_DECAY := 0.0032
const BOOST_STEP_SECONDS := 0.05
const BOOST_DURATION := 3.0
const WALL_TIER_APPLES := 10
const SPIDER_TIER_APPLES := 15
const MUSHROOM_TIER_APPLES := 20
const APPLE_TARGET := 25
const APPLE_POINTS := 10
const SPIDER_STEP_TICKS := 2
const TIER_ONE_WALLS := 3
const TIER_TWO_WALLS := 3
const LOOKAHEAD := 3
const OFF_GRID := Vector2i(-1, -1)

var body: Array[Vector2i] = [Vector2i(6, 6)]
var direction := Vector2i.ZERO
var pending_direction := Vector2i.ZERO
var walls: Array[Vector2i] = []
var spiders: Array[Vector2i] = []
var spider_tick := 0
var mushroom := OFF_GRID
var boost_elapsed := 0.0
var ghost_seed := OFF_GRID
var apple := Vector2i(11, 6)
var apples := 0
var elapsed := 0.0
var stretch := 0.0
var stopped := false
var awaiting_input := true
var invulnerable := false
var rng := RandomNumberGenerator.new()

func initialize(seed_value: int) -> void:
	rng.seed = seed_value
	body.assign([Vector2i(6, 6)])
	direction = Vector2i.ZERO
	pending_direction = Vector2i.ZERO
	apple = Vector2i(11, 6)
	apples = 0
	elapsed = 0.0
	stretch = 0.0
	stopped = false
	awaiting_input = true
	walls.clear()
	spiders.clear()
	spider_tick = 0
	mushroom = OFF_GRID
	boost_elapsed = 0.0
	ghost_seed = OFF_GRID

func steer(next_direction: Vector2i) -> void:
	if stopped or next_direction == Vector2i.ZERO:
		return
	awaiting_input = false
	if direction == Vector2i.ZERO:
		direction = next_direction
		pending_direction = direction
		body.append(body[0] - direction)
		body.append(body[0] - direction * 2)
		stretch = 0.22
	elif next_direction != -direction:
		pending_direction = next_direction

func advance(delta: float) -> void:
	if stopped or awaiting_input or direction == Vector2i.ZERO:
		return
	if boost_elapsed > 0.0:
		boost_elapsed = maxf(0.0, boost_elapsed - delta)
	if stretch > 0.0:
		stretch = maxf(0.0, stretch - delta)
		return
	elapsed += delta
	while elapsed >= current_step_seconds() and not stopped:
		elapsed -= current_step_seconds()
		step()

func current_step_seconds() -> float:
	var value := maxf(MIN_STEP_SECONDS, BASE_STEP_SECONDS - apples * STEP_DECAY)
	if boost_elapsed > 0.0:
		value = minf(value, BOOST_STEP_SECONDS)
	return value

func step() -> void:
	if stopped or direction == Vector2i.ZERO:
		return
	direction = pending_direction
	var next := Grid.wrap(body[0] + direction)
	var grows := next == apple
	var solid_body := body.slice(0, body.size() if grows else body.size() - 1)
	var reason := ""
	if next in walls:
		reason = "WALL HIT"
	elif next in spiders:
		reason = "SPIDER BIT YOU"
	if not reason.is_empty():
		if not invulnerable:
			stopped = true
			life_lost.emit(reason)
		return
	# Biting yourself severs the tail instead of ending the run: everything from
	# the bitten segment back is lost, and each lost segment costs an apple.
	var bite_index := solid_body.find(next)
	if bite_index >= 0:
		if invulnerable:
			return
		var severed := body.size() - bite_index
		body = body.slice(0, bite_index)
		points_earned.emit(-severed * APPLE_POINTS)
		tail_severed.emit(severed)
		body.push_front(next)
		_advance_spiders()
		return
	body.push_front(next)
	if next == mushroom:
		boost_elapsed = BOOST_DURATION
		boost_triggered.emit()
		spawn_mushroom()
	if grows:
		apples += 1
		points_earned.emit(APPLE_POINTS)
		_check_tiers()
		if stopped:
			return
		if apples >= APPLE_TARGET:
			stopped = true
			ghost_seed = _pick_ghost_seed()
			objective_completed.emit()
		else:
			spawn_apple()
	else:
		body.pop_back()
	_advance_spiders()

func _check_tiers() -> void:
	if apples == WALL_TIER_APPLES:
		_spawn_walls(TIER_ONE_WALLS)
	elif apples == SPIDER_TIER_APPLES:
		_spawn_walls(TIER_TWO_WALLS)
		_spawn_spider()
	elif apples == MUSHROOM_TIER_APPLES:
		spawn_mushroom()

func _advance_spiders() -> void:
	if spiders.is_empty() or stopped:
		return
	spider_tick += 1
	if spider_tick % SPIDER_STEP_TICKS != 0:
		return
	for index in spiders.size():
		var options: Array[Vector2i] = []
		for heading in Grid.DIRECTIONS:
			var candidate := Grid.wrap(spiders[index] + heading)
			if candidate in walls or candidate in spiders or candidate == apple or candidate == mushroom:
				continue
			options.append(candidate)
		if not options.is_empty():
			spiders[index] = options[rng.randi_range(0, options.size() - 1)]
		if spiders[index] == body[0]:
			if not invulnerable:
				stopped = true
				life_lost.emit("SPIDER BIT YOU")
			return

func _spawn_walls(count: int) -> void:
	var forbidden := _forward_lookahead()
	for index in count:
		var free := _free_cells(forbidden)
		if free.is_empty():
			return
		var cell: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		walls.append(cell)
		forbidden.append(cell)

func _spawn_spider() -> void:
	var free := _free_cells(_forward_lookahead())
	if not free.is_empty():
		spiders.append(free[rng.randi_range(0, free.size() - 1)])

func spawn_apple() -> void:
	var free := _free_cells()
	if not free.is_empty():
		apple = free[rng.randi_range(0, free.size() - 1)]

func spawn_mushroom() -> void:
	var free := _free_cells()
	if not free.is_empty():
		mushroom = free[rng.randi_range(0, free.size() - 1)]

func _forward_lookahead() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if direction == Vector2i.ZERO:
		return result
	var cursor := body[0]
	for index in LOOKAHEAD:
		cursor = Grid.wrap(cursor + direction)
		result.append(cursor)
	return result

func _free_cells(extra: Array[Vector2i] = []) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for row in Grid.SIZE.y:
		for column in Grid.SIZE.x:
			var cell := Vector2i(column, row)
			if cell in body or cell in walls or cell in spiders or cell == apple or cell == mushroom or cell in extra:
				continue
			free.append(cell)
	return free

func _pick_ghost_seed() -> Vector2i:
	if not walls.is_empty():
		return walls[0]
	var free := _free_cells()
	if free.is_empty():
		return body[0]
	return free[rng.randi_range(0, free.size() - 1)]

func snapshot() -> Dictionary:
	return {"body": body.duplicate(), "direction": direction, "apple": apple, "ghost_seed": ghost_seed}
