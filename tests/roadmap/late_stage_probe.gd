extends SceneTree

const FroggerStage = preload("res://scripts/frogger_stage.gd")
const AsteroidsStage = preload("res://scripts/asteroids_stage.gd")

var checks: int = 0
var failures: Array[String] = []


class StageCanvas extends Node2D:
	var stage: RefCounted
	var drew: bool = false

	func _draw() -> void:
		stage.draw_stage(self, 2.0)
		drew = true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_frogger_initialization()
	_test_frogger_motion()
	_test_frogger_collision()
	_test_crossings()
	_test_asteroids_initialization()
	_test_asteroids_motion()
	_test_asteroids_collision()
	_test_asteroids_shooting()
	_test_spawn_replenishment()
	_test_seeded_wins()
	_test_unassisted_late_run()
	_test_journal_events()
	await _test_drawing()
	if failures.is_empty():
		print("LATE_STAGE_PROBE_OK: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("LATE_STAGE_PROBE_FAILED: " + failure)
		print("LATE_STAGE_PROBE_FAILED: %d / %d checks" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frog(seed_value: int = 42, objective: int = 3) -> RefCounted:
	var stage := FroggerStage.new()
	stage.initialize({"seed": seed_value, "player_position": Vector2(206, 102), "walls": [Rect2i(3, 2, 4, 1)], "ghost": Vector2i(4, 5)}, {"target": objective})
	return stage


func _space(seed_value: int = 42, objective: int = 12) -> RefCounted:
	var stage := AsteroidsStage.new()
	stage.initialize(_frog(seed_value).snapshot(), {"target": objective})
	return stage


func _events(stage: RefCounted) -> Dictionary:
	var events := {"score": 0, "deaths": 0, "wins": 0, "journal": []}
	stage.points_earned.connect(func(amount: int) -> void: events.score += amount)
	stage.life_lost.connect(func(_reason: String) -> void: events.deaths += 1)
	stage.objective_completed.connect(func() -> void: events.wins += 1)
	stage.journal_event.connect(func(kind: String, tags: Dictionary) -> void: events.journal.append({"kind": kind, "tags": tags}))
	return events


func _test_frogger_initialization() -> void:
	var stage := _frog()
	var initial: Dictionary = stage.snapshot()
	stage.advance(600.0)
	stage.steer(Vector2i.ZERO)
	stage.steer(Vector2i.DOWN)
	_check(not stage.started and initial == stage.snapshot(), "frogger waits safely for a valid first hop")
	_check(stage.player == Vector2i(12, 11) and stage.get_player_position() == Vector2(206, 174), "frogger uses contract grid coordinates and safe start")
	_check(stage.snapshot().source.walls == [Rect2i(3, 2, 4, 1)], "frogger retains maze source objects")
	_check(stage.snapshot().source_objects.size() >= 15, "frogger snapshot exposes visible lane pieces")
	_check(stage.is_safe(Vector2i(12, 11), 300.0) and not stage.is_safe(Vector2i(-1, 11)), "frogger safety query handles safe banks and bounds")
	_check(stage.lanes == _frog().lanes and stage.lanes != _frog(43).lanes, "frogger seed reproduces and varies bounded lanes")
	for lane: Dictionary in stage.lanes:
		_check(lane.speed >= 18 and lane.speed <= 28 and lane.spacing - lane.width >= 66, "frogger lane speed and gaps are solvable bounds")
	initial.lanes[0].speed = 999
	initial.source.walls.clear()
	_check(stage.lanes[0].speed <= 28 and stage.source.walls.size() == 1, "frogger snapshots are independent deep copies")


func _test_frogger_motion() -> void:
	var coarse := _frog()
	var fine := _frog()
	coarse.steer(Vector2i.RIGHT)
	fine.steer(Vector2i.RIGHT)
	coarse.advance(2.0)
	for frame in 240:
		fine.advance(1.0 / 120.0)
	_check(coarse.snapshot() == fine.snapshot(), "frogger simulation is independent of frame chunks")
	_check(coarse.player == Vector2i(13, 11), "frogger input makes one hop rather than automatic marching")
	_check(coarse.lanes != _frog().lanes, "frogger traffic moves after input")
	for attempt in 40:
		coarse.steer(Vector2i.RIGHT)
		coarse.advance(0.15)
	_check(coarse.player.x == 23 and not coarse.stopped, "frogger grid edges are bounded and safe")
	coarse.initialize({}, {"seed": 42})
	_check(not coarse.started and coarse.crossings == 0, "frogger reinitialization clears run state")


func _test_frogger_collision() -> void:
	var stage := _frog()
	var events := _events(stage)
	stage.lanes[4].phase = 144.0
	stage.lanes[4].speed = 0.0
	stage.steer(Vector2i.UP)
	stage.advance(0.02)
	_check(stage.stopped and events.deaths == 1 and events.wins == 0, "frogger landing on traffic causes a fatal collision")
	var terminal: Dictionary = stage.snapshot()
	stage.advance(10.0)
	stage.steer(Vector2i.RIGHT)
	_check(stage.snapshot() == terminal and events.deaths == 1, "frogger death freezes state and emits once")
	stage.initialize({}, {"seed": 42, "invulnerable": true})
	stage.lanes[4].phase = 144.0
	stage.lanes[4].speed = 0.0
	stage.steer(Vector2i.UP)
	stage.advance(0.02)
	_check(not stage.stopped and stage.player.y == 10, "frogger development invulnerability suppresses fatal contact")
	stage = _frog()
	stage.player = Vector2i(12, 10)
	stage.lanes[4].phase = 136.0
	stage.lanes[4].width = 10.0
	stage.lanes[4].direction = 1
	stage.lanes[4].speed = 28.0
	stage.started = true
	stage.advance(0.3)
	_check(stage.stopped, "frogger moving traffic hits a waiting player")


func _safe_up(stage: RefCounted) -> bool:
	var destination: Vector2i = stage.player + Vector2i.UP
	for future_tick in 23:
		if not stage.is_safe(destination, future_tick / 120.0):
			return false
	return true


func _test_crossings() -> void:
	for seed_value in 48:
		var objective: int = 1 if seed_value % 2 == 0 else 3
		var stage := _frog(seed_value, objective)
		var events := _events(stage)
		stage.steer(Vector2i.RIGHT)
		stage.advance(0.15)
		for decision in 4000:
			if stage.stopped:
				break
			if _safe_up(stage):
				var before: int = stage.crossings
				stage.steer(Vector2i.UP)
				stage.advance(0.15)
				if stage.crossings != before:
					_check(stage.player.y == 11, "each crossing resets to the safe bank")
			else:
				stage.advance(0.05)
		_check(stage.get_progress() == objective and events.wins == 1 and events.deaths == 0, "frogger generated route completes without invulnerability, seed %d" % seed_value)
		_check(events.score == objective * 100, "frogger score and objective progression agree, seed %d" % seed_value)
		stage.advance(20.0)
		_check(events.wins == 1 and events.score == objective * 100, "frogger completion emits only once")


func _test_asteroids_initialization() -> void:
	var stage := _space()
	var initial: Dictionary = stage.snapshot()
	stage.advance(600.0)
	stage.set_controls(Vector2(0.1, 0), false)
	_check(not stage.started and stage.snapshot() == initial, "asteroids waits on neutral controls and joystick deadzone")
	_check(stage.player == Vector2(206, 174), "ship retains frogger player pixel position")
	_check(stage.source.lanes == _frog().lanes and stage.source.source.walls.size() == 1, "asteroids retains lane and maze transition history")
	_check(stage.asteroids == _space().asteroids and stage.asteroids != _space(43).asteroids, "asteroid seeds reproduce and vary spawns")
	for seed_value in 48:
		var seeded := _space(seed_value)
		for asteroid: Dictionary in seeded.asteroids:
			var edge: Vector2 = asteroid.position
			_check(is_equal_approx(edge.x, 12) or is_equal_approx(edge.x, 387.99) or is_equal_approx(edge.y, 32) or is_equal_approx(edge.y, 187.99), "asteroids are seeded on playfield edges")
			_check(seeded._distance(seeded.player, edge) >= AsteroidsStage.SPAWN_SAFE_DISTANCE + asteroid.radius and asteroid.warning >= 0.9, "edge spawns respect toroidal safety distance and warning")
			var next: Vector2 = edge + Vector2(asteroid.velocity) * 0.01
			_check(AsteroidsStage.FIELD.has_point(next), "warned edge spawns travel into the field")
	initial.asteroids[0].position = Vector2.ZERO
	initial.source.lanes.clear()
	_check(stage.asteroids[0].position != Vector2.ZERO and not stage.source.lanes.is_empty(), "asteroids snapshots do not alias live objects")


func _test_asteroids_motion() -> void:
	var coarse := _space()
	var fine := _space()
	coarse.invulnerable = true
	fine.invulnerable = true
	coarse.set_controls(Vector2(1, 1), true)
	fine.set_controls(Vector2(1, 1), true)
	coarse.advance(4.0)
	for frame in 480:
		fine.advance(1.0 / 120.0)
	_check(coarse.snapshot() == fine.snapshot(), "asteroids motion, warnings, firing, particles and spawns are chunk independent")
	_check(is_equal_approx(coarse.velocity.length(), AsteroidsStage.MAX_SPEED), "diagonal joystick acceleration reaches the same capped speed")
	var speed: Vector2 = coarse.velocity
	var position: Vector2 = coarse.player
	coarse.set_controls(Vector2.ZERO, false)
	coarse.advance(0.5)
	_check(coarse.velocity.is_equal_approx(speed) and not coarse.player.is_equal_approx(position), "ship keeps inertia after joystick release")
	coarse.player = Vector2(387, 187)
	coarse.velocity = Vector2(80, 70)
	coarse.advance(0.05)
	_check(coarse.player.x < 20 and coarse.player.y < 40, "ship wraps both screen edges")
	coarse.steer(Vector2i.LEFT)
	_check(coarse.axis == Vector2.LEFT and coarse.heading == Vector2.LEFT, "digital steer uses the same acceleration and aim contract")
	coarse.initialize({}, {"seed": 42})
	_check(not coarse.started and coarse.velocity == Vector2.ZERO and coarse.bullets.is_empty(), "asteroids resets all motion and shooting on reinitialization")


func _rock(position: Vector2, warning: float = 0.0) -> Dictionary:
	return {"id": 99, "position": position, "velocity": Vector2.ZERO, "radius": 10.0, "warning": warning, "angle": 0.0, "spin": 0.0, "color": 0}


func _test_asteroids_collision() -> void:
	var stage := _space()
	var events := _events(stage)
	stage.asteroids.assign([_rock(stage.player)])
	stage.set_controls(Vector2.RIGHT, false)
	stage.advance(0.02)
	_check(stage.stopped and events.deaths == 1, "asteroid contact causes one fatal collision")
	var terminal: Dictionary = stage.snapshot()
	stage.advance(2.0)
	stage.set_controls(Vector2.UP, true)
	_check(stage.snapshot() == terminal and events.deaths == 1, "asteroid death is frozen and idempotent")
	stage = _space()
	stage.player = Vector2(13, 100)
	stage.asteroids.assign([_rock(Vector2(387, 100))])
	stage.set_controls(Vector2.RIGHT, false)
	stage.advance(0.02)
	_check(stage.stopped, "asteroid collisions respect screen wrapping")
	stage = _space()
	stage.asteroids.assign([_rock(stage.player, 0.01)])
	stage.set_controls(Vector2.ZERO, true)
	stage.advance(0.4)
	_check(not stage.stopped and stage.asteroids[0].warning > 0.0 and stage.destroyed == 0, "unsafe warning expiry stays harmless and cannot be shot")
	stage.player = stage._wrap(stage.player + Vector2(140, 0))
	stage.set_controls(Vector2.ZERO, false)
	stage.bullets.clear()
	stage.advance(0.3)
	_check(stage.asteroids[0].warning == 0.0, "warning activates after player clears the safety radius")
	stage.asteroids[0].position = stage.player
	stage.invulnerable = true
	stage.advance(0.02)
	_check(not stage.stopped, "asteroids supports development invulnerability")


func _test_asteroids_shooting() -> void:
	var stage := _space(42, 2)
	var events := _events(stage)
	stage.player = Vector2(200, 120)
	stage.asteroids.assign([_rock(Vector2(200, 80))])
	stage.set_controls(Vector2.ZERO, true)
	stage.advance(0.25)
	_check(stage.started and stage.get_progress() == 1 and events.score == 50 and stage.asteroids.is_empty(), "Button A alone starts play, fires, and destroys a rock")
	_check(not stage.particles.is_empty() and not stage.stopped, "destruction produces particles without premature completion")
	stage.asteroids.append(_rock(Vector2(200, 65)))
	stage.advance(0.3)
	_check(stage.stopped and stage.destroyed == 2 and events.score == 100 and events.wins == 1, "shooting reaches the target and emits objective completion")
	stage.advance(10.0)
	_check(events.wins == 1 and events.score == 100, "asteroid completion cannot score twice")
	stage = _space(42, 1)
	stage.player = Vector2(380, 100)
	stage.asteroids.assign([_rock(Vector2(32, 100))])
	stage.set_controls(Vector2.RIGHT, true)
	stage.advance(0.2)
	_check(stage.destroyed == 1, "bullets hit rocks across the wrapping edge")
	stage = _space()
	stage.asteroids.clear()
	stage.set_controls(Vector2.ZERO, true)
	stage.advance(1.0)
	_check(stage.bullets.size() == 6, "holding Button A uses a bounded six-shot-per-second cadence")
	stage.set_controls(Vector2.ZERO, false)
	stage.advance(1.7)
	_check(stage.bullets.is_empty(), "released fire stops shooting and old bullets expire")


func _test_spawn_replenishment() -> void:
	var stage := _space()
	stage.asteroids.clear()
	stage.set_controls(Vector2.RIGHT, false)
	stage.advance(1.11)
	_check(stage.asteroids.size() == 1 and stage.asteroids[0].warning > 0, "an empty asteroid field replenishes with warning")
	stage.invulnerable = true
	stage.set_controls(Vector2.ZERO, false)
	stage.advance(30.0)
	_check(stage.asteroids.size() == AsteroidsStage.MAX_ASTEROIDS, "spawn density stays capped instead of overwhelming the player")
	for asteroid: Dictionary in stage.asteroids:
		_check(AsteroidsStage.FIELD.has_point(asteroid.position), "moving rocks wrap and remain available as targets")


func _test_seeded_wins() -> void:
	for seed_value in [7, 42, 91, 321]:
		for objective in [4, 12]:
			var stage := _space(seed_value, objective)
			var events := _events(stage)
			stage.invulnerable = true
			for decision in 24000:
				if stage.stopped:
					break
				var aim := Vector2.UP
				var closest: float = INF
				for asteroid: Dictionary in stage.asteroids:
					if float(asteroid.warning) > 0.0:
						continue
					var offset: Vector2 = stage._offset(stage.player, asteroid.position)
					if offset.length() < closest:
						closest = offset.length()
						aim = (offset + Vector2(asteroid.velocity) * offset.length() / AsteroidsStage.BULLET_SPEED).normalized()
				stage.set_controls(aim * 0.16, true)
				stage.advance(1.0 / 60.0)
			_check(events.wins == 1 and stage.destroyed == objective and events.score == objective * 50, "seeded live shooting reaches target %d, seed %d" % [objective, seed_value])
			_check(stage.particles.size() <= AsteroidsStage.MAX_PARTICLES, "live shooting particles remain bounded")


func _test_unassisted_late_run() -> void:
	var frog := _frog(42, 3)
	var frog_events := _events(frog)
	frog.steer(Vector2i.RIGHT)
	frog.advance(0.15)
	for decision in 4000:
		if frog.stopped:
			break
		if _safe_up(frog):
			frog.steer(Vector2i.UP)
			frog.advance(0.15)
		else:
			frog.advance(0.05)
	_check(frog_events.wins == 1 and frog_events.deaths == 0 and not frog.invulnerable, "unassisted late-stage run completes three actual crossings")
	var stage := AsteroidsStage.new()
	stage.initialize(frog.snapshot(), {"target": 12})
	_check(stage.player == frog.get_player_position(), "real crossing completion preserves position through the space handoff")
	var events := _events(stage)
	for decision in 24000:
		if stage.stopped:
			break
		var aim := Vector2.UP
		var closest: float = INF
		for asteroid: Dictionary in stage.asteroids:
			if float(asteroid.warning) > 0.0:
				continue
			var offset: Vector2 = stage._offset(stage.player, asteroid.position)
			if offset.length() < closest:
				closest = offset.length()
				aim = (offset + Vector2(asteroid.velocity) * offset.length() / AsteroidsStage.BULLET_SPEED).normalized()
		stage.set_controls(aim * 0.16, true)
		stage.advance(1.0 / 60.0)
	_check(not stage.invulnerable and events.deaths == 0 and events.wins == 1 and stage.destroyed == 12, "normal asteroid target completes using only live controls, without invulnerability")
	print("UNASSISTED_LATE_RUN: crossings=%d destroyed=%d deaths=%d elapsed=%.2f" % [frog.crossings, stage.destroyed, frog_events.deaths + events.deaths, frog.elapsed + stage.elapsed])
	_check(events.journal.filter(func(entry: Dictionary) -> bool: return entry.kind == "asteroid_streak").size() == 4, "asteroid streaks record each three-kill milestone")


func _test_journal_events() -> void:
	var frog := _frog(42, 1)
	var frog_events := _events(frog)
	frog.lanes[4].phase = 154.0
	frog.lanes[4].speed = 0.0
	frog.steer(Vector2i.UP)
	frog.advance(0.15)
	frog.steer(Vector2i.UP)
	frog.advance(0.15)
	_check(not frog.stopped and frog_events.journal.size() == 1 and frog_events.journal[0].kind == "danger_escaped", "frogger near-traffic escape records the canonical event")
	frog.player = Vector2i(12, 1)
	frog.steer(Vector2i.UP)
	frog.advance(0.15)
	_check(frog_events.journal[-1].kind == "crossing_completed" and frog_events.journal[-1].tags.count == 1, "crossing completion uses canonical count tags")
	var space := _space()
	var space_events := _events(space)
	space.player = Vector2(200, 120)
	space.asteroids.assign([_rock(Vector2(220, 120))])
	space.set_controls(Vector2.LEFT, false)
	space.advance(0.8)
	_check(not space.stopped and space_events.journal.size() == 1 and space_events.journal[0].kind == "danger_escaped", "ship evasion records a genuine danger escape")
	for entry: Dictionary in frog_events.journal + space_events.journal:
		for key: String in entry.tags:
			_check(key in ["count", "duration_ms", "danger", "outcome", "style"], "journal events contain only allowed small tags")


func _test_drawing() -> void:
	var canvas := StageCanvas.new()
	root.add_child(canvas)
	var stages: Array[RefCounted] = [_frog(), _space()]
	for stage in stages:
		stage.invulnerable = true
		stage.steer(Vector2i.RIGHT)
		stage.advance(2.0)
		var before: Dictionary = stage.snapshot()
		canvas.stage = stage
		canvas.drew = false
		canvas.queue_redraw()
		await process_frame
		await process_frame
		_check(canvas.drew and stage.snapshot() == before, "draw_stage executes without mutating simulation")
		if "--render-preview" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var path: String = "/tmp/late_stage_%s.png" % stage.snapshot().stage
			_check(image.save_png(path) == OK, "rendered preview saves to " + path)
			var clear_color: Color = image.get_pixel(0, 0)
			var outside_changed: bool = false
			for row in image.get_height():
				for column in image.get_width():
					if not AsteroidsStage.FIELD.has_point(Vector2(column, row)) and image.get_pixel(column, row) != clear_color:
						outside_changed = true
			_check(not outside_changed, "stage pixels stay within Rect2(12, 32, 376, 156)")
	canvas.queue_free()
	await process_frame
