extends "res://tests/autopilot/probe_base.gd"

const Grid = preload("res://scripts/grid.gd")

func _ready() -> void:
	await super._ready()
	await settle(3)
	var game: Node = get_tree().current_scene
	for seed_value in [2026, 2027, 2028]:
		game.start_run(seed_value)
		game.arena_entry = {"body": [Vector2i(24, 12), Vector2i(23, 12), Vector2i(22, 12), Vector2i(21, 12)], "direction": Vector2i.RIGHT}
		game.current_stage = "arena"
		game.restart_stage()
		var arena: RefCounted = game.stage
		arena.started = true
		var born := {}
		var log: Array = []
		var max_bots := 0
		var max_len := 0
		while game.state == game.State.PLAYING and arena.survived < arena.SURVIVE_SECONDS:
			for bot in arena.bots:
				if not born.has(bot):
					born[bot] = arena.survived
			_auto_steer(arena)
			arena.advance(0.05)
			max_bots = maxi(max_bots, arena.bots.size())
			for bot in arena.bots:
				max_len = maxi(max_len, bot.body.size())
			for bot in born.keys():
				if bot not in arena.bots and not born[bot] is String:
					log.append("gen%d lived %.0fs len%d" % [bot.generation, arena.survived - born[bot], bot.body.size()])
					born[bot] = "dead"
		for bot in arena.bots:
			log.append("gen%d ALIVE len%d" % [bot.generation, bot.body.size()])
		report("seed_%d" % seed_value, "state=%s(%s) t=%.0f player_len=%d kos=%d max_bots=%d max_bot_len=%d | %s" % [game.State.keys()[game.state], game.damage_reason, arena.survived, arena.body.size(), arena.kos, max_bots, max_len, ", ".join(log)])
	finish()

func _auto_steer(arena: RefCounted) -> void:
	var blocked := {}
	if arena.fire_depth() > 0:
		for row in arena.SIZE.y:
			for column in arena.SIZE.x:
				if arena.burning(Vector2i(column, row)):
					blocked[Vector2i(column, row)] = true
	for cell in arena.walls:
		blocked[cell] = true
	for spider in arena.spiders:
		blocked[spider] = true
		for heading in Grid.DIRECTIONS:
			blocked[spider + heading] = true
	for cell in arena.body:
		blocked[cell] = true
	for bot in arena.bots:
		for cell in bot.body:
			blocked[cell] = true
		for heading in Grid.DIRECTIONS:
			blocked[bot.body[0] + heading] = true
	var best: Vector2i = arena.direction
	var best_value := -INF
	for heading in Grid.DIRECTIONS:
		if heading == -arena.direction:
			continue
		var next: Vector2i = arena.body[0] + heading
		if not arena.inside(next) or blocked.has(next) or arena.burning(next):
			continue
		var distances: Dictionary = arena._distances(next, blocked)
		var value := float(distances.size())
		if distances.size() < arena.body.size() + 3:
			value -= 300.0
		var food_distance := 999.0
		for morsel in arena.food:
			food_distance = minf(food_distance, float(distances.get(morsel, 999)))
		value -= food_distance * 0.5
		if value > best_value:
			best_value = value
			best = heading
	arena.steer(best)
