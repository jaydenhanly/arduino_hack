extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed
signal journal_event(kind: String, tags: Dictionary)

const FIELD := Rect2(12, 32, 376, 156)
const GRID_SIZE := Vector2i(24, 12)
const CELL := 12.0
const ORIGIN := Vector2(56, 36)
const ROAD_WIDTH := 288.0
const FIXED_STEP := 1.0 / 120.0
const HOP_SECONDS := 0.15
const RESET_GRACE_SECONDS := 0.25
const SAFE_ROWS := [0, 1, 3, 5, 7, 9, 11]
const CAR_COLORS := [Color("f6ad55"), Color("e76f91"), Color("78bdd4")]

var player := Vector2i(12, 11)
var crossings: int = 0
var lanes: Array[Dictionary] = []
var stopped: bool = false
var invulnerable: bool = false
var target: int = 3
var started: bool = false
var seed: int = 0
var source: Dictionary = {}
var elapsed: float = 0.0
var hop_flash: float = 0.0
var crossing_flash: float = 0.0
var pending_direction := Vector2i.ZERO
var reset_grace: float = 0.0
var needs_neutral: bool = false
var _start_column: int = 12
var _accumulator: float = 0.0
var _hop_cooldown: float = 0.0
var _crossing_started_at: float = 0.0
var _danger_row: int = -1
var _danger_since: float = 0.0
var _rng := RandomNumberGenerator.new()


func initialize(previous: Dictionary, options: Dictionary = {}) -> void:
	source = previous.duplicate(true)
	seed = int(options.get("seed", source.get("seed", 0)))
	target = maxi(1, int(options.get("target", 3)))
	_rng.seed = seed
	_start_column = 12
	if source.has("player_position"):
		var prior_position: Vector2 = source.player_position
		_start_column = clampi(int((prior_position.x - ORIGIN.x) / CELL), 0, 23)
	elif source.has("body") and not source.body.is_empty():
		_start_column = clampi(source.body[0].x, 0, 23)
	player = Vector2i(_start_column, 11)
	crossings = 0
	stopped = false
	invulnerable = bool(options.get("invulnerable", false))
	started = false
	elapsed = 0.0
	_accumulator = 0.0
	_hop_cooldown = 0.0
	_crossing_started_at = 0.0
	_danger_row = -1
	_danger_since = 0.0
	hop_flash = 0.0
	crossing_flash = 0.0
	pending_direction = Vector2i.ZERO
	reset_grace = 0.0
	needs_neutral = false
	lanes.clear()
	for lane_index in 5:
		lanes.append({
			"row": 2 + lane_index * 2,
			"direction": -1 if _rng.randi_range(0, 1) == 0 else 1,
			"speed": _rng.randf_range(18.0, 28.0),
			"phase": _rng.randf_range(0.0, 96.0),
			"spacing": 96.0,
			"width": float(_rng.randi_range(2, 3) * 10),
			"color": lane_index % CAR_COLORS.size(),
		})


func get_progress() -> int:
	return crossings


func get_player_position() -> Vector2:
	return ORIGIN + (Vector2(player) + Vector2(0.5, 0.5)) * CELL


func steer(direction: Vector2i) -> void:
	if stopped:
		return
	if direction == Vector2i.ZERO:
		pending_direction = Vector2i.ZERO
		needs_neutral = false
		return
	if needs_neutral or reset_grace > 0.000000001:
		return
	var heading := Vector2i(signi(direction.x), 0) if direction.x != 0 else Vector2i(0, signi(direction.y))
	var destination := player + heading
	if destination.x < 0 or destination.x >= GRID_SIZE.x or destination.y < 0 or destination.y >= GRID_SIZE.y:
		return
	pending_direction = heading
	if not started:
		started = true


func advance(delta: float) -> void:
	if stopped or not started or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += delta
	while _accumulator + 0.000000001 >= FIXED_STEP and not stopped:
		_accumulator = maxf(0.0, _accumulator - FIXED_STEP)
		_tick()


func _tick() -> void:
	elapsed += FIXED_STEP
	reset_grace = maxf(0.0, reset_grace - FIXED_STEP)
	_hop_cooldown = maxf(0.0, _hop_cooldown - FIXED_STEP)
	hop_flash = maxf(0.0, hop_flash - FIXED_STEP)
	crossing_flash = maxf(0.0, crossing_flash - FIXED_STEP)
	for lane in lanes:
		lane.phase = fposmod(float(lane.phase) + float(lane.direction) * float(lane.speed) * FIXED_STEP, float(lane.spacing))
	if _collides():
		_damage()
		if stopped:
			return
	if pending_direction != Vector2i.ZERO and _hop_cooldown <= 0.000000001:
		var destination := player + pending_direction
		pending_direction = Vector2i.ZERO
		if destination.x >= 0 and destination.x < GRID_SIZE.x and destination.y >= 0 and destination.y < GRID_SIZE.y:
			player = destination
			_hop_cooldown = HOP_SECONDS
			hop_flash = 0.12
			if _collides():
				_damage()
			if not stopped and player.y == 0:
				_complete_crossing()
	if not stopped:
		_update_danger()


func _update_danger() -> void:
	if _danger_row >= 0 and player.y != _danger_row:
		journal_event.emit("danger_escaped", {"count": 1, "danger": "traffic", "outcome": "escaped", "duration_ms": int((elapsed - _danger_since) * 1000)})
		_danger_row = -1
	var margin := Rect2(get_player_position() - Vector2(8, 3.5), Vector2(16, 7))
	for lane in lanes:
		if int(lane.row) != player.y:
			continue
		for rectangle in lane_rects(lane):
			if margin.intersects(rectangle) and _danger_row < 0:
				_danger_row = player.y
				_danger_since = elapsed


func _collides() -> bool:
	return not is_safe(player)


func is_safe(cell: Vector2i, time_offset: float = 0.0) -> bool:
	if cell.x < 0 or cell.x >= GRID_SIZE.x or cell.y < 0 or cell.y >= GRID_SIZE.y or not is_finite(time_offset):
		return false
	var center := ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var hitbox := Rect2(center - Vector2(3.5, 3.5), Vector2(7, 7))
	for lane in lanes:
		if int(lane.row) != cell.y:
			continue
		var projected := lane.duplicate()
		projected.phase = fposmod(float(lane.phase) + float(lane.direction) * float(lane.speed) * maxf(0.0, time_offset), float(lane.spacing))
		for vehicle in lane_rects(projected):
			if hitbox.intersects(vehicle):
				return false
	return true


func lane_rects(lane: Dictionary) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for vehicle_index in range(-1, 4):
		var rectangle := Rect2(
			ORIGIN + Vector2(float(lane.phase) + vehicle_index * float(lane.spacing), int(lane.row) * CELL + 1),
			Vector2(float(lane.width), 10)
		)
		var road := Rect2(ORIGIN.x, rectangle.position.y, ROAD_WIDTH, 10)
		if rectangle.intersects(road):
			rectangles.append(rectangle.intersection(road))
	return rectangles


func _damage() -> void:
	if stopped or invulnerable:
		return
	stopped = true
	life_lost.emit("CAUGHT IN TRAFFIC")


func _complete_crossing() -> void:
	crossings += 1
	crossing_flash = 0.55
	player = Vector2i(_start_column, 11)
	pending_direction = Vector2i.ZERO
	var completed := crossings >= target
	stopped = completed
	if not completed:
		reset_grace = RESET_GRACE_SECONDS
		needs_neutral = true
	points_earned.emit(100)
	journal_event.emit("crossing_completed", {"count": crossings, "outcome": "completed", "duration_ms": int((elapsed - _crossing_started_at) * 1000)})
	_crossing_started_at = elapsed
	if completed:
		objective_completed.emit()


func snapshot() -> Dictionary:
	var objects: Array[Dictionary] = []
	for lane_index in lanes.size():
		var lane: Dictionary = lanes[lane_index]
		for rectangle in lane_rects(lane):
			objects.append({"kind": "lane_piece", "position": rectangle.get_center(), "rect": rectangle, "lane": lane_index, "color": CAR_COLORS[int(lane.color)]})
	return {
		"stage": "frogger", "seed": seed, "player_position": get_player_position(),
		"player": player, "body": [player], "crossings": crossings,
		"lanes": lanes.duplicate(true), "source_objects": objects,
		"source": source.duplicate(true), "started": started, "elapsed": elapsed,
		"reset_grace": reset_grace, "needs_neutral": needs_neutral,
	}


func draw_stage(canvas: Node2D, clock: float) -> void:
	canvas.draw_rect(FIELD, Color("152d36"))
	for row in GRID_SIZE.y:
		var safe: bool = row in SAFE_ROWS
		var row_rect := Rect2(ORIGIN + Vector2(0, row * CELL), Vector2(ROAD_WIDTH, CELL))
		canvas.draw_rect(row_rect, Color("315d4f") if safe else Color("263d50"))
		if safe:
			for column in range(0, 24, 2):
				var grass := ORIGIN + Vector2(column * CELL + 3, row * CELL + 7)
				_pixel(canvas, Rect2(grass, Vector2(2, 2)), Color("4b8065"))
				_pixel(canvas, Rect2(grass + Vector2(3, -2), Vector2(2, 3)), Color("3e7258"))
		else:
			for stripe in 12:
				_pixel(canvas, Rect2(ORIGIN + Vector2(stripe * 24 + 4, row * CELL), Vector2(10, 1)), Color("638079"))
	for lane in lanes:
		for rectangle in lane_rects(lane):
			var color: Color = CAR_COLORS[int(lane.color)]
			_pixel(canvas, rectangle, color.darkened(0.25))
			_pixel(canvas, Rect2(rectangle.position + Vector2(1, 2), rectangle.size - Vector2(2, 4)), color)
			if rectangle.size.x >= 12:
				var cab_x: float = rectangle.end.x - 8 if int(lane.direction) > 0 else rectangle.position.x + 3
				_pixel(canvas, Rect2(cab_x, rectangle.position.y + 2, 4, 6), Color("263d50"))
				_pixel(canvas, Rect2(rectangle.position + Vector2(3, 0), Vector2(4, 1)), Color("101f30"))
				_pixel(canvas, Rect2(rectangle.position + Vector2(3, 9), Vector2(4, 1)), Color("101f30"))
		var marker_y: float = ORIGIN.y + int(lane.row) * CELL + 5
		var pulse: float = 0.6 + 0.4 * sin(clock * 3.0 + int(lane.row))
		for chevron in 3:
			var marker_x: float = 38 + chevron * 3 * int(lane.direction)
			_pixel(canvas, Rect2(marker_x, marker_y + absi(chevron - 1), 2, 2), Color("f6ad55").darkened(pulse * 0.3))
	for column in 24:
		_pixel(canvas, Rect2(ORIGIN.x + column * CELL, ORIGIN.y, CELL - 1, 2), Color("cce89a") if column % 2 == 0 else Color("79aa7c"))
	for bank_x in [18, 352, 374]:
		for leaf in 7:
			var leaf_y: float = 40 + leaf * 21
			var sway: float = floor(sin(clock * 1.5 + leaf) * 2)
			_pixel(canvas, Rect2(bank_x + sway, leaf_y, 5, 4), Color("41705a"))
			_pixel(canvas, Rect2(bank_x + 2, leaf_y + 4, 2, 5), Color("295341"))
	var center := get_player_position().floor()
	_pixel(canvas, Rect2(center - Vector2(5, 3), Vector2(10, 8)), Color("132e35"))
	var frog_color := Color("dcf5a2") if hop_flash > 0.0 else Color("9ede82")
	_pixel(canvas, Rect2(center - Vector2(3, 3), Vector2(6, 7)), frog_color)
	for side in [-1, 1]:
		_pixel(canvas, Rect2(center + Vector2(side * 4 - 1, -4), Vector2(3, 3)), frog_color)
		_pixel(canvas, Rect2(center + Vector2(side * 4, -4), Vector2(1, 1)), Color("173847"))
		_pixel(canvas, Rect2(center + Vector2(side * 4 - 1, 3), Vector2(3, 2)), Color("69b97a"))
	if crossing_flash > 0.0:
		for sparkle in 8:
			_pixel(canvas, Rect2(ORIGIN + Vector2(12 + sparkle * 36, 3), Vector2(3, 3)), Color("fff2a6"))


func _pixel(canvas: Node2D, rectangle: Rect2, color: Color) -> void:
	if rectangle.size.x > 0 and rectangle.size.y > 0 and rectangle.intersects(FIELD):
		canvas.draw_rect(rectangle.intersection(FIELD), color)
