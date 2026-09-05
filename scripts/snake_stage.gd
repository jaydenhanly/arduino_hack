extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed

const Grid = preload("res://scripts/grid.gd")
const STEP_SECONDS := 0.15
const APPLE_TARGET := 5

var body: Array[Vector2i] = [Vector2i(6, 6)]
var direction := Vector2i.ZERO
var pending_direction := Vector2i.ZERO
var obstacle := Vector2i(17, 5)
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
	if stretch > 0.0:
		stretch = maxf(0.0, stretch - delta)
		return
	elapsed += delta
	while elapsed >= STEP_SECONDS and not stopped:
		elapsed -= STEP_SECONDS
		step()

func step() -> void:
	if stopped or direction == Vector2i.ZERO:
		return
	direction = pending_direction
	var next := body[0] + direction
	var grows := next == apple
	var solid_body := body.slice(0, body.size() if grows else body.size() - 1)
	var reason := ""
	if not Grid.inside(next):
		reason = "WALL HIT"
	elif next == obstacle:
		reason = "OBSTACLE HIT"
	elif next in solid_body:
		reason = "TAIL HIT"
	if not reason.is_empty():
		if not invulnerable:
			stopped = true
			life_lost.emit(reason)
		return
	body.push_front(next)
	if grows:
		apples += 1
		points_earned.emit(10)
		if apples == APPLE_TARGET:
			stopped = true
			objective_completed.emit()
		else:
			spawn_apple()
	else:
		body.pop_back()

func spawn_apple() -> void:
	var free: Array[Vector2i] = []
	for row in Grid.SIZE.y:
		for column in Grid.SIZE.x:
			var cell := Vector2i(column, row)
			if cell != obstacle and cell not in body:
				free.append(cell)
	if not free.is_empty():
		apple = free[rng.randi_range(0, free.size() - 1)]

func snapshot() -> Dictionary:
	return {"body": body.duplicate(), "direction": direction, "apple": apple, "obstacle": obstacle}
