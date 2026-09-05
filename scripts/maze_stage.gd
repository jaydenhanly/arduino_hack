extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed
signal journal_event(kind: String, tags: Dictionary)

const Grid = preload("res://scripts/grid.gd")
const STEP_SECONDS := 0.15
const GHOST_SECONDS := 0.36
const WALL_COUNT := 4
const MIN_TAIL_SEGMENTS := 8
const GHOST_MIN_DISTANCE := 6
const GHOST_BONUS := 100
const OFF_GRID := Vector2i(-1, -1)
const TIMER_EPSILON := 0.000001

var body: Array[Vector2i] = []
var direction := Vector2i.ZERO
var pending_direction := Vector2i.ZERO
var walls: Array[Rect2i] = []
var pellets: Array[Vector2i] = []
var ghost := Vector2i.ZERO
var ghost_next := Vector2i.ZERO
var ghost_alive := true
var ghost_warning := false
var respawn_warning: bool:
	get:
		return ghost_warning
var ghost_respawn_cell := OFF_GRID
var ghost_respawn_remaining := 0.0
var ghost_respawn_seconds := 4.0
var ghost_warning_seconds := 0.75
var ghosts_defeated := 0
var collected := 0
var elapsed := 0.0
var ghost_elapsed := 0.0
var started := false
var stopped := false
var invulnerable := false
var source: Dictionary = {}
var seed := 0
var target := 97
var rng := RandomNumberGenerator.new()

func initialize(source_snapshot: Dictionary, options: Dictionary = {}) -> void:
	source = source_snapshot.duplicate(true)
	seed = int(options.get("seed", source.get("seed", 0)))
	rng.seed = seed
	target = maxi(1, int(options.get("target", 97)))
	ghost_respawn_seconds = maxf(0.05, float(options.get("ghost_respawn_seconds", 4.0)))
	ghost_warning_seconds = clampf(float(options.get("ghost_warning_seconds", 0.75)), 0.05, ghost_respawn_seconds)
	walls.clear()
	pellets.clear()
	_build_body()
	direction = source.get("direction", Vector2i.RIGHT)
	if direction not in Grid.DIRECTIONS:
		direction = Vector2i.RIGHT
	pending_direction = direction
	ghost = source.get("ghost_seed", OFF_GRID)
	if not _safe_ghost_cell(ghost):
		ghost = _pick_spawn_cell()
	_build_walls()
	_build_pellets()
	ghost_alive = true
	ghost_warning = false
	ghost_respawn_cell = OFF_GRID
	ghost_respawn_remaining = 0.0
	ghosts_defeated = 0
	collected = 0
	elapsed = 0.0
	ghost_elapsed = 0.0
	started = false
	stopped = false
	ghost_next = chase_step()

func _build_body() -> void:
	body.clear()
	var previous: Array = source.get("body", [])
	for cell: Vector2i in previous:
		if not Grid.inside(cell) or cell in body:
			break
		if not body.is_empty() and _distance(body.back(), cell) != 1:
			break
		body.append(cell)
		if body.size() == MIN_TAIL_SEGMENTS + 1:
			break
	if body.is_empty():
		body.append(Vector2i(6, 6))
	while not _extend_tail():
		body.pop_back()

func _extend_tail() -> bool:
	if body.size() >= MIN_TAIL_SEGMENTS + 1:
		return true
	for heading in Grid.DIRECTIONS:
		var candidate: Vector2i = body.back() + heading
		if not Grid.inside(candidate) or candidate in body:
			continue
		body.append(candidate)
		if _extend_tail():
			return true
		body.pop_back()
	return false

func _build_walls() -> void:
	var protected: Array[Vector2i] = body.duplicate()
	protected.append(ghost)
	for heading in Grid.DIRECTIONS:
		protected.append(body[0] + heading)
	var candidates: Array[Vector2i] = []
	for row in range(1, Grid.SIZE.y - 2):
		for column in range(1, Grid.SIZE.x - 5):
			candidates.append(Vector2i(column, row))
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var cell := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = cell
	for origin in candidates:
		var candidate := Rect2i(origin, Vector2i(5, 2))
		var allowed := true
		for cell in protected:
			if candidate.has_point(cell):
				allowed = false
		for existing in walls:
			if candidate.grow(1).intersects(existing):
				allowed = false
		if not allowed:
			continue
		walls.append(candidate)
		if reachable_cells(body[0]).size() != Grid.SIZE.x * Grid.SIZE.y - walls.size() * 10:
			walls.pop_back()
		if walls.size() == WALL_COUNT:
			break

func _build_pellets() -> void:
	var apple: Vector2i = source.get("apple", body[0])
	_add_pellet(apple)
	for heading in Grid.DIRECTIONS:
		_add_pellet(apple + heading)
	for row in range(1, Grid.SIZE.y, 2):
		for column in range(1, Grid.SIZE.x, 2):
			_add_pellet(Vector2i(column, row))

func _add_pellet(cell: Vector2i) -> void:
	if walkable(cell) and cell not in body and cell != ghost and cell not in pellets:
		pellets.append(cell)

func walkable(cell: Vector2i) -> bool:
	if not Grid.inside(cell):
		return false
	for wall in walls:
		if wall.has_point(cell):
			return false
	return true

func reachable_cells(start: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = []
	if not walkable(start):
		return queue
	queue.append(start)
	var seen := {start: true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for heading in Grid.DIRECTIONS:
			var next := cell + heading
			if walkable(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return queue

func steer(next_direction: Vector2i) -> void:
	if stopped or next_direction not in Grid.DIRECTIONS:
		return
	if not started:
		var next := body[0] + next_direction
		if not walkable(next) or (ghost_alive and next == ghost):
			return
		direction = next_direction
		started = true
		journal_event.emit("started", {"direction": next_direction})
	pending_direction = next_direction

func advance(delta: float) -> void:
	if not started or stopped or delta <= 0.0:
		return
	var remaining := delta
	while remaining > TIMER_EPSILON and not stopped:
		var interval := minf(remaining, maxf(0.0, STEP_SECONDS - elapsed))
		var was_alive := ghost_alive
		if was_alive:
			interval = minf(interval, maxf(0.0, GHOST_SECONDS - ghost_elapsed))
		else:
			var deadline := ghost_respawn_remaining
			if not ghost_warning and deadline > ghost_warning_seconds:
				deadline -= ghost_warning_seconds
			interval = minf(interval, maxf(0.0, deadline))
		remaining -= interval
		elapsed += interval
		if was_alive:
			ghost_elapsed += interval
		else:
			_advance_respawn(interval)
		if elapsed + TIMER_EPSILON >= STEP_SECONDS:
			elapsed = maxf(0.0, elapsed - STEP_SECONDS)
			step()
		if was_alive and ghost_alive and ghost_elapsed + TIMER_EPSILON >= GHOST_SECONDS:
			ghost_elapsed = maxf(0.0, ghost_elapsed - GHOST_SECONDS)
			step_ghost()

func step() -> void:
	if stopped or not started:
		return
	if ghost_alive and ghost == body[0]:
		_damage()
		return
	if walkable(body[0] + pending_direction):
		direction = pending_direction
	var next := body[0] + direction
	if not walkable(next):
		return
	if ghost_alive and next == ghost:
		_damage()
		return
	var length := body.size()
	body.push_front(next)
	body.resize(length)
	if next in pellets:
		pellets.erase(next)
		collected += 1
		points_earned.emit(5)
		journal_event.emit("collect", {"item": "pellet", "progress": collected, "target": target})
		if collected >= target:
			stopped = true
			journal_event.emit("objective_completed", {"progress": collected, "target": target})
			objective_completed.emit()
			return
		if pellets.is_empty():
			_build_pellets()
	if ghost_alive:
		ghost_next = chase_step()

func chase_step() -> Vector2i:
	var queue: Array[Vector2i] = [body[0]]
	var distance := {body[0]: 0}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for heading in Grid.DIRECTIONS:
			var next := cell + heading
			if walkable(next) and not distance.has(next):
				distance[next] = int(distance[cell]) + 1
				queue.append(next)
	var best := ghost
	var best_distance: int = distance.get(ghost, 9999)
	for heading in Grid.DIRECTIONS:
		var next := ghost + heading
		var candidate_distance: int = distance.get(next, 9999)
		if candidate_distance < best_distance:
			best = next
			best_distance = candidate_distance
	return best

func step_ghost() -> void:
	if stopped or not started or not ghost_alive:
		return
	if ghost == body[0]:
		_damage()
		return
	if ghost in body.slice(1):
		_defeat_ghost()
		return
	var next := chase_step()
	if next == body[0]:
		_damage()
		return
	ghost = next
	if ghost in body.slice(1):
		_defeat_ghost()
	else:
		ghost_next = chase_step()

func _defeat_ghost() -> void:
	ghost_alive = false
	ghost_warning = false
	ghost_next = OFF_GRID
	ghost_respawn_cell = OFF_GRID
	ghost_respawn_remaining = ghost_respawn_seconds
	ghost_elapsed = 0.0
	ghosts_defeated += 1
	points_earned.emit(GHOST_BONUS)
	journal_event.emit("ghost_defeated", {"defeats": ghosts_defeated, "progress": collected, "bonus": GHOST_BONUS})

func _advance_respawn(delta: float) -> void:
	ghost_respawn_remaining = maxf(0.0, ghost_respawn_remaining - delta)
	if ghost_warning and not _safe_ghost_cell(ghost_respawn_cell):
		ghost_warning = false
		ghost_respawn_cell = OFF_GRID
		ghost_respawn_remaining = maxf(ghost_respawn_remaining, ghost_warning_seconds)
	if not ghost_warning and ghost_respawn_remaining <= ghost_warning_seconds + TIMER_EPSILON:
		ghost_respawn_cell = _pick_spawn_cell()
		if ghost_respawn_cell == OFF_GRID:
			ghost_respawn_remaining = ghost_warning_seconds
			return
		ghost_warning = true
		ghost = ghost_respawn_cell
		ghost_next = ghost_respawn_cell
		journal_event.emit("ghost_warning", {"cell": ghost_respawn_cell, "seconds": ghost_respawn_remaining})
	if ghost_warning and ghost_respawn_remaining <= TIMER_EPSILON:
		ghost = ghost_respawn_cell
		ghost_alive = true
		ghost_warning = false
		ghost_respawn_cell = OFF_GRID
		ghost_respawn_remaining = 0.0
		ghost_elapsed = 0.0
		ghost_next = chase_step()
		journal_event.emit("ghost_respawn", {"cell": ghost})

func _pick_spawn_cell() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row in Grid.SIZE.y:
		for column in Grid.SIZE.x:
			if row != 0 and row != Grid.SIZE.y - 1 and column != 0 and column != Grid.SIZE.x - 1:
				continue
			var cell := Vector2i(column, row)
			if _safe_ghost_cell(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return OFF_GRID
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _safe_ghost_cell(cell: Vector2i) -> bool:
	return walkable(cell) and cell not in body and _distance(cell, body[0]) >= GHOST_MIN_DISTANCE

func _distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)

func _damage() -> void:
	if not invulnerable:
		stopped = true
		journal_event.emit("death", {"reason": "GHOST CAUGHT YOUR HEAD", "progress": collected})
		life_lost.emit("GHOST CAUGHT YOUR HEAD")

func get_progress() -> int:
	return collected

func get_player_position() -> Vector2:
	return Grid.rect(body[0]).get_center()

func snapshot() -> Dictionary:
	return {
		"stage": "maze", "seed": seed, "player_position": get_player_position(),
		"body": body.duplicate(), "direction": direction, "walls": walls.duplicate(),
		"pellets": pellets.duplicate(), "ghost": ghost, "ghost_next": ghost_next,
		"ghost_alive": ghost_alive, "ghost_warning": ghost_warning, "respawn_warning": respawn_warning,
		"ghost_respawn_cell": ghost_respawn_cell, "ghost_respawn_remaining": ghost_respawn_remaining,
		"collected": collected, "progress": collected, "target": target,
		"ghosts_defeated": ghosts_defeated, "source": source.duplicate(true)
	}
