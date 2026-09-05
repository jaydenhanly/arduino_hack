extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed

const Grid = preload("res://scripts/grid.gd")
const STEP_SECONDS := 0.15
const GHOST_SECONDS := 0.36

var body: Array[Vector2i] = []
var direction := Vector2i.ZERO
var pending_direction := Vector2i.ZERO
var walls: Array[Rect2i] = []
var pellets: Array[Vector2i] = []
var ghost := Vector2i.ZERO
var ghost_next := Vector2i.ZERO
var ghost_alive := true
var collected := 0
var elapsed := 0.0
var ghost_elapsed := 0.0
var started := false
var stopped := false
var invulnerable := false
var source: Dictionary = {}

func initialize(snapshot: Dictionary) -> void:
	source = snapshot.duplicate(true)
	body.assign(source.body.slice(0, 4))
	direction = source.direction
	pending_direction = direction
	ghost = source.obstacle
	walls.clear()
	pellets.clear()
	_build_walls()
	for row in range(1, Grid.SIZE.y, 2):
		for column in range(1, Grid.SIZE.x, 2):
			var cell := Vector2i(column, row)
			if walkable(cell) and cell not in body and cell != ghost:
				pellets.append(cell)
	ghost_next = chase_step()
	ghost_alive = true
	collected = 0
	elapsed = 0.0
	ghost_elapsed = 0.0
	started = false
	stopped = false

func _build_walls() -> void:
	var protected: Array[Vector2i] = body.duplicate()
	protected.append(ghost)
	for heading in Grid.DIRECTIONS:
		protected.append(body[0] + heading)
	var preferred: Array[Vector2i] = [Vector2i(4, 2), Vector2i(15, 2), Vector2i(4, 8), Vector2i(15, 8)]
	for wall_index in source.body.size() - body.size():
		var candidates: Array[Vector2i] = [preferred[wall_index % preferred.size()]]
		for row in range(1, Grid.SIZE.y - 2):
			for column in range(1, Grid.SIZE.x - 5):
				candidates.append(Vector2i(column, row))
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
			if reachable_cells(body[0]).size() == Grid.SIZE.x * Grid.SIZE.y - walls.size() * 10:
				break
			walls.pop_back()

func walkable(cell: Vector2i) -> bool:
	if not Grid.inside(cell):
		return false
	for wall in walls:
		if wall.has_point(cell):
			return false
	return true

func reachable_cells(start: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
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
	if stopped or next_direction == Vector2i.ZERO:
		return
	pending_direction = next_direction
	started = true

func advance(delta: float) -> void:
	if not started or stopped:
		return
	elapsed += delta
	while elapsed >= STEP_SECONDS and not stopped:
		elapsed -= STEP_SECONDS
		step()
	if stopped:
		return
	ghost_elapsed += delta
	while ghost_elapsed >= GHOST_SECONDS and not stopped:
		ghost_elapsed -= GHOST_SECONDS
		step_ghost()

func step() -> void:
	if stopped:
		return
	if walkable(body[0] + pending_direction):
		direction = pending_direction
	var next := body[0] + direction
	if not walkable(next):
		return
	if ghost_alive and next == ghost:
		_damage()
		return
	body.push_front(next)
	body.resize(4)
	if next in pellets:
		pellets.erase(next)
		collected += 1
		points_earned.emit(5)
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
	if stopped or not ghost_alive:
		return
	var next := chase_step()
	if next == body[0]:
		_damage()
		return
	ghost = next
	if ghost in body.slice(1):
		ghost_alive = false
		stopped = true
		points_earned.emit(100)
		objective_completed.emit()
	ghost_next = chase_step()

func _damage() -> void:
	if not invulnerable:
		stopped = true
		life_lost.emit("GHOST CAUGHT YOUR HEAD")

func snapshot() -> Dictionary:
	return {"body": body.duplicate(), "direction": direction}
