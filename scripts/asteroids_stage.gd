extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed
signal journal_event(kind: String, tags: Dictionary)

const Art = preload("res://scripts/pixel_art.gd")
const FIELD := Rect2(12, 32, 376, 156)
const FIXED_STEP := 1.0 / 120.0
const ACCELERATION := 155.0
const MAX_SPEED := 112.0
const PLAYER_RADIUS := 4.0
const BULLET_SPEED := 225.0
const FIRE_SECONDS := 0.18
const WARNING_SECONDS := 0.9
const SPAWN_SAFE_DISTANCE := 64.0
const SPAWN_SECONDS := 1.1
const MAX_ASTEROIDS := 5
const MAX_PARTICLES := 96
const ROCK_COLORS := [Color("b1b5db"), Color("7c9bb6"), Color("cda1c3"), Color("d7b98f")]

var player := FIELD.get_center()
var velocity := Vector2.ZERO
var asteroids: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var destroyed: int = 0
var stopped: bool = false
var invulnerable: bool = false
var target: int = 12
var started: bool = false
var seed: int = 0
var source: Dictionary = {}
var axis := Vector2.ZERO
var firing: bool = false
var heading := Vector2.UP
var elapsed: float = 0.0
var shot_flash: float = 0.0
var impact_flash: float = 0.0
var stars: Array[Dictionary] = []
var _accumulator: float = 0.0
var _fire_cooldown: float = 0.0
var _spawn_elapsed: float = 0.0
var _next_id: int = 0
var _milestone_at: float = 0.0
var _danger_active: bool = false
var _danger_since: float = 0.0
var _rng := RandomNumberGenerator.new()
var _visual_rng := RandomNumberGenerator.new()


func initialize(previous: Dictionary, options: Dictionary = {}) -> void:
	source = previous.duplicate(true)
	seed = int(options.get("seed", source.get("seed", 0)))
	target = maxi(1, int(options.get("target", 12)))
	_rng.seed = seed
	_visual_rng.seed = seed ^ 0x41535452
	player = _wrap(source.get("player_position", FIELD.get_center()))
	velocity = Vector2.ZERO
	heading = Vector2.UP
	axis = Vector2.ZERO
	firing = false
	destroyed = 0
	stopped = false
	invulnerable = bool(options.get("invulnerable", false))
	started = false
	elapsed = 0.0
	_accumulator = 0.0
	_fire_cooldown = 0.0
	_spawn_elapsed = 0.0
	_next_id = 0
	_milestone_at = 0.0
	_danger_active = false
	_danger_since = 0.0
	shot_flash = 0.0
	impact_flash = 0.0
	asteroids.clear()
	bullets.clear()
	particles.clear()
	stars.clear()
	for star_index in 60:
		stars.append({"position": Vector2(_visual_rng.randf_range(FIELD.position.x, FIELD.end.x), _visual_rng.randf_range(FIELD.position.y, FIELD.end.y)), "layer": star_index % 3})
	for initial_index in 3:
		_spawn_asteroid(WARNING_SECONDS + initial_index * 0.25)


func get_progress() -> int:
	return destroyed


func get_player_position() -> Vector2:
	return player


func steer(direction: Vector2i) -> void:
	set_controls(Vector2(direction), firing)


func set_controls(next_axis: Vector2, next_firing: bool) -> void:
	if stopped:
		return
	axis = next_axis.limit_length(1.0) if next_axis.is_finite() and next_axis.length() > 0.15 else Vector2.ZERO
	firing = next_firing
	if axis != Vector2.ZERO:
		heading = axis.normalized()
	if not started and (axis != Vector2.ZERO or firing):
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
	shot_flash = maxf(0.0, shot_flash - FIXED_STEP)
	impact_flash = maxf(0.0, impact_flash - FIXED_STEP)
	velocity = (velocity + axis * ACCELERATION * FIXED_STEP).limit_length(MAX_SPEED)
	player = _wrap(player + velocity * FIXED_STEP)
	_fire_cooldown = maxf(0.0, _fire_cooldown - FIXED_STEP)
	if firing and _fire_cooldown <= 0.000000001:
		_fire()
	for asteroid in asteroids:
		if float(asteroid.warning) > 0.0:
			asteroid.warning = maxf(0.0, float(asteroid.warning) - FIXED_STEP)
			if float(asteroid.warning) <= 0.000000001:
				if _distance(player, asteroid.position) < SPAWN_SAFE_DISTANCE + float(asteroid.radius):
					asteroid.warning = 0.2
				else:
					asteroid.warning = 0.0
		else:
			asteroid.position = _wrap(Vector2(asteroid.position) + Vector2(asteroid.velocity) * FIXED_STEP)
			asteroid.angle = float(asteroid.angle) + float(asteroid.spin) * FIXED_STEP
	_update_particles()
	_update_bullets()
	if stopped:
		return
	for asteroid in asteroids:
		if float(asteroid.warning) == 0.0 and _distance(player, asteroid.position) < PLAYER_RADIUS + float(asteroid.radius):
			_damage()
			if stopped:
				return
	_update_danger()
	_spawn_elapsed += FIXED_STEP
	if _spawn_elapsed + 0.000000001 >= SPAWN_SECONDS:
		_spawn_elapsed -= SPAWN_SECONDS
		if asteroids.size() < MAX_ASTEROIDS:
			_spawn_asteroid(WARNING_SECONDS)


func _fire() -> void:
	_fire_cooldown = FIRE_SECONDS
	shot_flash = 0.07
	bullets.append({"position": _wrap(player + heading * 7.0), "velocity": heading * BULLET_SPEED + velocity * 0.3, "ttl": 1.65})


func _update_danger() -> void:
	var near: bool = false
	for asteroid in asteroids:
		if float(asteroid.warning) == 0.0 and _distance(player, asteroid.position) < PLAYER_RADIUS + float(asteroid.radius) + 14.0:
			near = true
	if near and not _danger_active:
		_danger_since = elapsed
	elif not near and _danger_active:
		journal_event.emit("danger_escaped", {"count": 1, "danger": "asteroid", "outcome": "escaped", "duration_ms": int((elapsed - _danger_since) * 1000)})
	_danger_active = near


func _update_bullets() -> void:
	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[bullet_index]
		var previous_position: Vector2 = bullet.position
		var next_position: Vector2 = previous_position + Vector2(bullet.velocity) * FIXED_STEP
		bullet.position = _wrap(next_position)
		bullet.ttl = float(bullet.ttl) - FIXED_STEP
		var hit_index: int = -1
		for asteroid_index in asteroids.size():
			var asteroid: Dictionary = asteroids[asteroid_index]
			if float(asteroid.warning) > 0.0:
				continue
			var nearby_center := previous_position + _offset(previous_position, asteroid.position)
			var nearest := Geometry2D.get_closest_point_to_segment(nearby_center, previous_position, next_position)
			if nearest.distance_to(nearby_center) <= float(asteroid.radius) + 2.0:
				hit_index = asteroid_index
				break
		if hit_index >= 0:
			bullets.remove_at(bullet_index)
			_destroy_asteroid(hit_index)
			if stopped:
				return
		elif float(bullet.ttl) <= 0.0:
			bullets.remove_at(bullet_index)


func _spawn_asteroid(warning: float) -> void:
	var radius: float = _rng.randf_range(8.0, 13.0)
	var edge_index: int = _rng.randi_range(0, 63)
	var spawn_position := Vector2.ZERO
	var found: bool = false
	for candidate_index in 64:
		var edge_slot: int = (edge_index + candidate_index) % 64
		var along: float = (float(edge_slot % 16) + 0.5) / 16.0
		match edge_slot / 16:
			0: spawn_position = Vector2(FIELD.position.x, FIELD.position.y + along * FIELD.size.y)
			1: spawn_position = Vector2(FIELD.end.x - 0.01, FIELD.position.y + along * FIELD.size.y)
			2: spawn_position = Vector2(FIELD.position.x + along * FIELD.size.x, FIELD.position.y)
			3: spawn_position = Vector2(FIELD.position.x + along * FIELD.size.x, FIELD.end.y - 0.01)
		if _distance(player, spawn_position) >= SPAWN_SAFE_DISTANCE + radius:
			found = true
			break
	if not found:
		return
	var inward := (FIELD.get_center() - spawn_position).normalized().rotated(_rng.randf_range(-0.65, 0.65))
	if is_equal_approx(spawn_position.x, FIELD.position.x):
		inward.x = absf(inward.x)
	elif is_equal_approx(spawn_position.x, FIELD.end.x - 0.01):
		inward.x = -absf(inward.x)
	elif is_equal_approx(spawn_position.y, FIELD.position.y):
		inward.y = absf(inward.y)
	else:
		inward.y = -absf(inward.y)
	asteroids.append({
		"id": _next_id, "position": spawn_position, "velocity": inward * _rng.randf_range(17.0, 29.0),
		"radius": radius, "warning": warning, "angle": _rng.randf_range(0, TAU),
		"spin": _rng.randf_range(-0.8, 0.8), "color": _next_id % ROCK_COLORS.size(),
	})
	_next_id += 1


func _destroy_asteroid(index: int) -> void:
	var asteroid: Dictionary = asteroids[index]
	asteroids.remove_at(index)
	destroyed += 1
	impact_flash = 0.18
	_burst(asteroid.position, ROCK_COLORS[int(asteroid.color)])
	var completed := destroyed >= target
	stopped = completed
	points_earned.emit(50)
	if destroyed % 3 == 0 or completed:
		journal_event.emit("asteroid_streak", {"count": destroyed, "style": "aggressive", "duration_ms": int((elapsed - _milestone_at) * 1000)})
		_milestone_at = elapsed
	if completed:
		objective_completed.emit()


func _damage() -> void:
	if stopped or invulnerable:
		return
	stopped = true
	_burst(player, Color("ff907c"))
	life_lost.emit("SHIP HIT AN ASTEROID")


func _burst(position: Vector2, color: Color) -> void:
	for particle_index in 16:
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var angle: float = _visual_rng.randf_range(0.0, TAU)
		particles.append({"position": position, "velocity": Vector2.from_angle(angle) * _visual_rng.randf_range(18, 64), "ttl": _visual_rng.randf_range(0.25, 0.6), "color": Color("fff1ae") if particle_index % 3 == 0 else color})


func _update_particles() -> void:
	for particle_index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[particle_index]
		particle.position = _wrap(Vector2(particle.position) + Vector2(particle.velocity) * FIXED_STEP)
		particle.ttl = float(particle.ttl) - FIXED_STEP
		if float(particle.ttl) <= 0.0:
			particles.remove_at(particle_index)


func _wrap(position: Vector2) -> Vector2:
	return FIELD.position + Vector2(fposmod(position.x - FIELD.position.x, FIELD.size.x), fposmod(position.y - FIELD.position.y, FIELD.size.y))


func _offset(from: Vector2, to: Vector2) -> Vector2:
	var difference := to - from
	return Vector2(wrapf(difference.x, -FIELD.size.x * 0.5, FIELD.size.x * 0.5), wrapf(difference.y, -FIELD.size.y * 0.5, FIELD.size.y * 0.5))


func _distance(from: Vector2, to: Vector2) -> float:
	return _offset(from, to).length()


func snapshot() -> Dictionary:
	var objects: Array[Dictionary] = []
	for asteroid in asteroids:
		objects.append({"kind": "asteroid", "position": asteroid.position, "radius": asteroid.radius, "id": asteroid.id, "warning": asteroid.warning})
	return {
		"stage": "asteroids", "seed": seed, "player_position": player,
		"player": player, "velocity": velocity, "heading": heading,
		"asteroids": asteroids.duplicate(true), "bullets": bullets.duplicate(true),
		"particles": particles.duplicate(true), "destroyed": destroyed,
		"source_objects": objects, "source": source.duplicate(true),
		"started": started, "elapsed": elapsed,
	}


func draw_stage(canvas: Node2D, clock: float) -> void:
	canvas.draw_rect(FIELD, Art.map_tone(Color("10182f")))
	for band in 13:
		_pixel(canvas, Rect2(12, 32 + band * 12, 376, 6), Art.map_tone(Color("151d38") if band % 2 == 0 else Color("131b32")))
	for star in stars:
		var layer: int = star.layer
		var star_position := _wrap(Vector2(star.position) + Vector2(-elapsed * (layer + 1) * 2.0, elapsed * (layer + 1) * 0.6)).floor()
		var star_color := Color("426280") if layer == 0 else Color("7a88b8")
		if layer == 2:
			star_color = Color("b5decd") if sin(clock * 2 + star_position.x) > 0.3 else Color("7d8eac")
		_pixel(canvas, Rect2(star_position, Vector2.ONE * (2 if layer == 2 else 1)), Art.map_tone(star_color))
	for asteroid in asteroids:
		if float(asteroid.warning) > 0.0:
			_draw_warning(canvas, asteroid, clock)
		else:
			_draw_rock(canvas, asteroid)
	# Particles and bullet trails are fired by, or explode out of, the player
	# ship/asteroids at the instant of impact — kept fixed like the ship below
	# rather than threading map/player provenance through each transient particle.
	for particle in particles:
		var color: Color = particle.color
		color.a = minf(1.0, float(particle.ttl) * 3.0)
		_wrapped_pixel(canvas, Rect2(Vector2(particle.position).floor(), Vector2(2, 2)), color)
	for bullet in bullets:
		var bullet_heading := Vector2(bullet.velocity).normalized()
		for trail_index in 3:
			var trail_position := (Vector2(bullet.position) - bullet_heading * trail_index * 3).floor()
			_wrapped_pixel(canvas, Rect2(trail_position - Vector2.ONE, Vector2(2, 2)), Color("fff4c4") if trail_index == 0 else Color("f6af69").darkened(trail_index * 0.15))
	_draw_ship(canvas)
	if impact_flash > 0.0:
		var flash_color := Art.map_tone(Color("b9a2e9"))
		flash_color.a = impact_flash * 2.0
		_pixel(canvas, Rect2(12, 32, 376, 2), flash_color)
		_pixel(canvas, Rect2(12, 186, 376, 2), flash_color)


func _draw_rock(canvas: Node2D, asteroid: Dictionary) -> void:
	var radius: float = asteroid.radius
	var extent: int = int(ceil(radius / 2.0))
	var base_color: Color = Art.map_tone(ROCK_COLORS[int(asteroid.color)])
	for row in range(-extent, extent + 1):
		for column in range(-extent, extent + 1):
			var offset := Vector2(column * 2, row * 2)
			var angle: float = offset.angle() + float(asteroid.angle)
			var edge: float = radius * (0.85 + 0.10 * sin(angle * 5 + int(asteroid.id)))
			if offset.length() > edge:
				continue
			var color := base_color.darkened(0.15 + (column + row + extent * 2) * 0.018)
			if offset.length() > edge - 2.0:
				color = base_color.lightened(0.18) if row < 0 else base_color.darkened(0.45)
			elif (column + int(asteroid.id)) % 4 == 0 and row % 3 == 0:
				color = base_color.darkened(0.4)
			_wrapped_pixel(canvas, Rect2((Vector2(asteroid.position) + offset).floor(), Vector2(2, 2)), color)


func _draw_warning(canvas: Node2D, asteroid: Dictionary, clock: float) -> void:
	var center := Vector2(asteroid.position).floor()
	var radius: float = float(asteroid.radius) + 4
	var color := Art.map_tone(Color("f7bb76") if int(clock * 8) % 2 == 0 else Color("875581"))
	for side in [-1, 1]:
		_wrapped_pixel(canvas, Rect2(center + Vector2(side * radius, -4), Vector2(2, 8)), color)
		_wrapped_pixel(canvas, Rect2(center + Vector2(-4, side * radius), Vector2(8, 2)), color)
	_wrapped_pixel(canvas, Rect2(center - Vector2(1, 4), Vector2(2, 5)), color)
	_wrapped_pixel(canvas, Rect2(center + Vector2(-1, 3), Vector2(2, 2)), color)


func _draw_ship(canvas: Node2D) -> void:
	var side := heading.orthogonal()
	if axis != Vector2.ZERO and started and not stopped:
		var flame_length: int = 3 + int(elapsed * 30) % 3
		for flame_index in flame_length:
			var flame_position := (player - heading * (5 + flame_index * 2)).floor()
			_wrapped_pixel(canvas, Rect2(flame_position - Vector2.ONE, Vector2(2, 2)), Color("fff2aa") if flame_index < 2 else Color("ee8568"))
	for forward in range(-3, 5):
		var half_width: int = maxi(0, int((4 - forward) / 2))
		for sideways in range(-half_width, half_width + 1):
			var tile_position := (player + heading * forward * 1.6 + side * sideways * 1.6).floor()
			var color := Color("9ce6cf") if sideways == 0 else Color("6b90bf")
			if forward >= 2 or shot_flash > 0.0:
				color = Color("effbd6")
			_wrapped_pixel(canvas, Rect2(tile_position - Vector2.ONE, Vector2(2, 2)), color)
	_wrapped_pixel(canvas, Rect2(player.floor() - Vector2.ONE, Vector2(2, 2)), Color("283d68"))


func _wrapped_pixel(canvas: Node2D, rectangle: Rect2, color: Color) -> void:
	_pixel(canvas, rectangle, color)
	var horizontal: float = 0.0
	var vertical: float = 0.0
	if rectangle.position.x < FIELD.position.x:
		horizontal = FIELD.size.x
	elif rectangle.end.x > FIELD.end.x:
		horizontal = -FIELD.size.x
	if rectangle.position.y < FIELD.position.y:
		vertical = FIELD.size.y
	elif rectangle.end.y > FIELD.end.y:
		vertical = -FIELD.size.y
	if horizontal != 0.0:
		_pixel(canvas, Rect2(rectangle.position + Vector2(horizontal, 0), rectangle.size), color)
	if vertical != 0.0:
		_pixel(canvas, Rect2(rectangle.position + Vector2(0, vertical), rectangle.size), color)
	if horizontal != 0.0 and vertical != 0.0:
		_pixel(canvas, Rect2(rectangle.position + Vector2(horizontal, vertical), rectangle.size), color)


func _pixel(canvas: Node2D, rectangle: Rect2, color: Color) -> void:
	if rectangle.intersects(FIELD):
		canvas.draw_rect(rectangle.intersection(FIELD), color)
