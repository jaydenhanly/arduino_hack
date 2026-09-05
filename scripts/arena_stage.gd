extends RefCounted

signal points_earned(amount: int)
signal life_lost(reason: String)
signal objective_completed
signal tail_severed(segments: int)

const Grid = preload("res://scripts/grid.gd")
const SIZE := Vector2i(48, 24)
const CELL := 7
const OFFSET := Vector2i(12, 6)
const FOOD_SECONDS := 5.0
const SURVIVE_SECONDS := 300.0
const MELTDOWN_SECONDS := 30.0
const MELTDOWN_SPAWN_SECONDS := 5.0
const MELTDOWN_BOT_SPEED := 0.7
const FIRE_STEP_SECONDS := 5.0
const FIRE_MAX_DEPTH := 5
const SPAWN_SECONDS := 30.0
const START_LENGTH := 8
const PLAYER_MAX_LENGTH := 24
const BOT_LENGTH := 3
const FOOD_COUNT := 8
const PLAYER_BASE_STEP := 0.20
const PLAYER_MAX_STEP := 0.32
const HAZARD_TIERS := [
	{"at": 60.0, "walls": 6, "spiders": 0, "banner": "WALLS RISE"},
	{"at": 120.0, "walls": 6, "spiders": 2, "banner": "SPIDERS!"},
	{"at": 180.0, "walls": 0, "spiders": 2, "banner": "MORE SPIDERS!"},
	{"at": 240.0, "walls": 4, "spiders": 2, "banner": "THE WALLS CLOSE IN"},
]
const SPIDER_STEP_SECONDS := 0.4
const LOOKAHEAD := 4
const BANNER_SECONDS := 2.5
const KO_POINTS := 50
const SURVIVAL_POINTS := 200
const FOOD_POINTS := 5

class Bot extends RefCounted:
	var body: Array[Vector2i] = []
	var direction := Vector2i.RIGHT
	var generation := 0
	var step_seconds := 0.17
	var elapsed := 0.0
	var growth := 0

var body: Array[Vector2i] = []
var direction := Vector2i.ZERO
var pending_direction := Vector2i.ZERO
var growth := 0
var food: Array[Vector2i] = []
var bots: Array[Bot] = []
var walls: Array[Vector2i] = []
var spiders: Array[Vector2i] = []
var tier_index := 0
var spider_elapsed := 0.0
var banner := ""
var banner_until := 0.0
var spawned := 0
var kos := 0
var survived := 0.0
var spawn_timer := 0.0
var elapsed := 0.0
var started := false
var stopped := false
var invulnerable := false
var last_spawn := Vector2i(-1, -1)
var source: Dictionary = {}
var rng := RandomNumberGenerator.new()

func initialize(snapshot: Dictionary, seed_value: int = 2026) -> void:
	source = snapshot.duplicate(true)
	rng.seed = seed_value * 7 + 3
	body.assign(source.body)
	direction = source.direction
	pending_direction = direction
	growth = maxi(0, START_LENGTH - body.size())
	food.clear()
	bots.clear()
	walls.clear()
	spiders.clear()
	tier_index = 0
	spider_elapsed = 0.0
	banner = ""
	banner_until = 0.0
	spawned = 0
	kos = 0
	survived = 0.0
	spawn_timer = 0.0
	elapsed = 0.0
	started = false
	stopped = false
	for index in FOOD_COUNT:
		_spawn_food()
	spawn_bot()

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y

static func rect(cell: Vector2i) -> Rect2:
	return Rect2(Grid.ORIGIN + Vector2(cell) * CELL, Vector2.ONE * CELL)

static func from_maze(snapshot: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in snapshot.body:
		cells.append(cell + OFFSET)
	return {"body": cells, "direction": snapshot.direction}

func meltdown() -> bool:
	return survived >= SURVIVE_SECONDS - MELTDOWN_SECONDS

func fire_depth() -> int:
	if not meltdown():
		return 0
	return mini(FIRE_MAX_DEPTH, 1 + int((survived - (SURVIVE_SECONDS - MELTDOWN_SECONDS)) / FIRE_STEP_SECONDS))

func burning(cell: Vector2i) -> bool:
	var depth := fire_depth()
	return depth > 0 and (cell.x < depth or cell.y < depth or cell.x >= SIZE.x - depth or cell.y >= SIZE.y - depth)

func bot_step_seconds(bot: Bot) -> float:
	return bot.step_seconds * (MELTDOWN_BOT_SPEED if meltdown() else 1.0)

static func bot_max_length(generation: int) -> int:
	return 8 + 3 * generation

func player_step_seconds() -> float:
	return clampf(PLAYER_BASE_STEP + 0.006 * (body.size() - START_LENGTH), PLAYER_BASE_STEP, PLAYER_MAX_STEP)

func seconds_left() -> int:
	return int(ceil(maxf(0.0, SURVIVE_SECONDS - survived)))

# Continue the arena where it broke down: same body, same score, same clock. The
# fire rolls back far enough to free the head and whatever landed the hit is
# cleared off the neighbouring cells.
func resume() -> void:
	stopped = false
	started = false
	elapsed = 0.0
	spider_elapsed = 0.0
	pending_direction = direction
	while meltdown() and burning(body[0]):
		survived -= FIRE_STEP_SECONDS
	var head: Vector2i = body[0]
	for spider in spiders.duplicate():
		if _within(spider, head, 2):
			spiders.erase(spider)
	for cell in walls.duplicate():
		if _within(cell, head, 1):
			walls.erase(cell)
	for bot in bots.duplicate():
		for cell in bot.body:
			if _within(cell, head, 2):
				_kill_bot(bot, false)
				break

func _within(cell: Vector2i, head: Vector2i, radius: int) -> bool:
	return absi(cell.x - head.x) + absi(cell.y - head.y) <= radius

func steer(next_direction: Vector2i) -> void:
	if stopped or next_direction == Vector2i.ZERO:
		return
	if next_direction != -direction:
		pending_direction = next_direction
		started = true

func advance(delta: float) -> void:
	if not started or stopped:
		return
	survived += delta
	if survived >= SURVIVE_SECONDS:
		_win()
		return
	var spawn_interval := MELTDOWN_SPAWN_SECONDS if meltdown() else SPAWN_SECONDS
	spawn_timer += delta
	while spawn_timer >= spawn_interval:
		spawn_timer -= spawn_interval
		spawn_bot()
	while tier_index < HAZARD_TIERS.size() and survived >= HAZARD_TIERS[tier_index].at:
		_spawn_hazards(HAZARD_TIERS[tier_index])
		tier_index += 1
	if meltdown():
		_burn()
		if stopped:
			return
	spider_elapsed += delta
	while spider_elapsed >= SPIDER_STEP_SECONDS and not stopped:
		spider_elapsed -= SPIDER_STEP_SECONDS
		step_spiders()
	if stopped:
		return
	elapsed += delta
	while elapsed >= player_step_seconds() and not stopped:
		elapsed -= player_step_seconds()
		step()
	if not stopped and survived >= SURVIVE_SECONDS:
		_win()
		return
	for bot in bots.duplicate():
		if stopped:
			return
		bot.elapsed += delta
		while bot.elapsed >= bot_step_seconds(bot) and not stopped and bot in bots:
			bot.elapsed -= bot_step_seconds(bot)
			step_bot(bot)

func banner_visible() -> bool:
	return not banner.is_empty() and survived < banner_until

func _spawn_hazards(tier: Dictionary) -> void:
	banner = tier.banner
	banner_until = survived + BANNER_SECONDS
	var forbidden := {}
	var cursor := body[0]
	for index in LOOKAHEAD:
		cursor += direction
		forbidden[cursor] = true
	for heading in Grid.DIRECTIONS:
		forbidden[body[0] + heading] = true
		for bot in bots:
			forbidden[bot.body[0] + heading] = true
	for index in int(tier.walls):
		var free := _free_cells(forbidden)
		if free.is_empty():
			break
		var cell: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		walls.append(cell)
		forbidden[cell] = true
	for index in int(tier.spiders):
		var free := _free_cells(forbidden)
		var far: Array[Vector2i] = []
		for cell in free:
			if absi(cell.x - body[0].x) + absi(cell.y - body[0].y) >= 8:
				far.append(cell)
		if far.is_empty():
			far = free
		if far.is_empty():
			break
		var cell: Vector2i = far[rng.randi_range(0, far.size() - 1)]
		spiders.append(cell)
		forbidden[cell] = true

func _free_cells(forbidden: Dictionary) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for row in SIZE.y:
		for column in SIZE.x:
			var cell := Vector2i(column, row)
			if not forbidden.has(cell) and not _occupied(cell):
				free.append(cell)
	return free

func step_spiders() -> void:
	for index in spiders.size():
		var spider := spiders[index]
		var bite := Vector2i(-1, -1)
		var options: Array[Vector2i] = []
		for heading in Grid.DIRECTIONS:
			var candidate := spider + heading
			if not inside(candidate) or burning(candidate) or candidate in walls or candidate in spiders:
				continue
			if candidate == body[0]:
				bite = candidate
				continue
			if candidate in body or candidate in food:
				continue
			var victim := _bot_at(candidate)
			if victim != null:
				if candidate == victim.body[0]:
					_kill_bot(victim, false)
					spiders[index] = candidate
					bite = Vector2i(-2, -2)
					break
				continue
			options.append(candidate)
		if bite == Vector2i(-2, -2):
			continue
		if bite.x >= 0:
			if invulnerable:
				continue
			spiders[index] = bite
			_damage("SPIDER BIT YOU")
			return
		if not options.is_empty():
			spiders[index] = options[rng.randi_range(0, options.size() - 1)]

func _burn() -> void:
	for spider in spiders.duplicate():
		if burning(spider):
			spiders.erase(spider)
	for bot in bots.duplicate():
		for cell in bot.body:
			if burning(cell):
				_kill_bot(bot, false)
				break
	for morsel in food.duplicate():
		if burning(morsel):
			food.erase(morsel)
	while body.size() > 1 and burning(body[body.size() - 1]):
		body.pop_back()
	if burning(body[0]):
		_damage("BURNED ALIVE")

func _damage(reason: String) -> void:
	if not invulnerable:
		stopped = true
		life_lost.emit(reason)

func _win() -> void:
	stopped = true
	points_earned.emit(SURVIVAL_POINTS)
	objective_completed.emit()

func step() -> void:
	if stopped:
		return
	direction = pending_direction
	var next := body[0] + direction
	var reason := ""
	if not inside(next):
		reason = "WALL HIT"
	elif burning(next):
		reason = "BURNED ALIVE"
	elif next in walls:
		reason = "WALL HIT"
	elif next in spiders:
		reason = "SPIDER BIT YOU"
	elif _bot_body_at(next) != null:
		reason = "BITTEN BY A SNAKE"
	if not reason.is_empty():
		_damage(reason)
		return
	# Same rule as the snake stage: biting yourself cuts the tail off and costs
	# points, it does not end the run.
	var bite_index := body.slice(0, body.size() if growth > 0 else body.size() - 1).find(next)
	if bite_index >= 0:
		if invulnerable:
			return
		var severed := body.size() - bite_index
		body = body.slice(0, bite_index)
		growth = 0
		points_earned.emit(-severed * FOOD_POINTS)
		tail_severed.emit(severed)
		body.push_front(next)
		return
	var rammed := _bot_at(next)
	if rammed != null:
		_kill_bot(rammed, true)
	body.push_front(next)
	if growth > 0:
		growth -= 1
	else:
		body.pop_back()
	if next in food:
		food.erase(next)
		if body.size() + growth < PLAYER_MAX_LENGTH:
			growth += 1
		survived += FOOD_SECONDS
		points_earned.emit(FOOD_POINTS)
		_spawn_food()

func step_bot(bot: Bot) -> void:
	var heading := _bot_choose(bot)
	bot.direction = heading
	var next := bot.body[0] + heading
	var own_solid := bot.body.slice(0, bot.body.size() if bot.growth > 0 else bot.body.size() - 1)
	var hit_player := next in body
	if not inside(next) or burning(next) or next in walls or next in spiders or next in own_solid or hit_player or _bot_at(next, bot) != null:
		_kill_bot(bot, hit_player)
		return
	bot.body.push_front(next)
	if bot.growth > 0:
		bot.growth -= 1
	else:
		bot.body.pop_back()
	if next in food:
		food.erase(next)
		if bot.body.size() + bot.growth < bot_max_length(bot.generation):
			bot.growth += 1
		_spawn_food()

func _kill_bot(bot: Bot, by_player: bool) -> void:
	bots.erase(bot)
	for index in range(0, bot.body.size(), 2):
		var cell: Vector2i = bot.body[index]
		if cell not in food and cell not in body and _bot_at(cell) == null and not burning(cell):
			food.append(cell)
	if by_player:
		kos += 1
		points_earned.emit(KO_POINTS)

func _bot_body_at(cell: Vector2i) -> Bot:
	for bot in bots:
		if cell in bot.body.slice(1):
			return bot
	return null

func _bot_at(cell: Vector2i, skip: Bot = null) -> Bot:
	for bot in bots:
		if bot != skip and cell in bot.body:
			return bot
	return null

func _occupied(cell: Vector2i) -> bool:
	return burning(cell) or cell in walls or cell in spiders or cell in body or cell in food or _bot_at(cell) != null

func _spawn_food() -> void:
	var free: Array[Vector2i] = []
	for row in SIZE.y:
		for column in SIZE.x:
			var cell := Vector2i(column, row)
			if not _occupied(cell):
				free.append(cell)
	if not free.is_empty():
		food.append(free[rng.randi_range(0, free.size() - 1)])

func spawn_bot() -> Bot:
	var generation := maxi(spawned, 4) if meltdown() else spawned
	var best_origin := Vector2i(-1, -1)
	var best_heading := Vector2i.RIGHT
	var best_score := -1
	for row in SIZE.y:
		for column in SIZE.x:
			var origin := Vector2i(column, row)
			var heading := Vector2i.RIGHT if column < SIZE.x / 2 else Vector2i.LEFT
			var clear := true
			for index in BOT_LENGTH + 2:
				var cell := origin + heading * (index - BOT_LENGTH + 1)
				if not inside(cell) or _occupied(cell):
					clear = false
			if not clear:
				continue
			var distance := absi(origin.x - body[0].x) + absi(origin.y - body[0].y)
			for bot in bots:
				distance = mini(distance, absi(origin.x - bot.body[0].x) + absi(origin.y - bot.body[0].y))
			if distance > best_score:
				best_score = distance
				best_origin = origin
				best_heading = heading
	if best_score < 0:
		return null
	var bot := Bot.new()
	bot.generation = generation
	bot.direction = best_heading
	bot.step_seconds = maxf(0.07, 0.17 - 0.025 * mini(generation, 4))
	for index in BOT_LENGTH:
		bot.body.append(best_origin - best_heading * index)
	bots.append(bot)
	spawned += 1
	last_spawn = best_origin
	return bot

func _bot_choose(bot: Bot) -> Vector2i:
	var generation := bot.generation
	var blocked := {}
	var depth := fire_depth()
	if depth > 0:
		for row in SIZE.y:
			for column in SIZE.x:
				var cell := Vector2i(column, row)
				if burning(cell):
					blocked[cell] = true
	for cell in walls:
		blocked[cell] = true
	for spider in spiders:
		blocked[spider] = true
		if generation >= 2:
			for heading in Grid.DIRECTIONS:
				blocked[spider + heading] = true
	for cell in body:
		blocked[cell] = true
	if generation >= 4 and direction != Vector2i.ZERO:
		blocked[body[0] + direction] = true
	for other in bots:
		var cells: Array[Vector2i] = other.body
		if other == bot and other.growth == 0:
			cells = other.body.slice(0, other.body.size() - 1)
		for cell in cells:
			blocked[cell] = true
	var danger := {}
	if generation >= 3:
		for heading in Grid.DIRECTIONS:
			danger[body[0] + heading] = true
			for other in bots:
				if other != bot:
					danger[other.body[0] + heading] = true
	var best := bot.direction
	var best_value := -INF
	for heading in Grid.DIRECTIONS:
		if heading == -bot.direction:
			continue
		var next: Vector2i = bot.body[0] + heading
		if not inside(next) or blocked.has(next):
			continue
		var value := 0.0
		var distances := {}
		if generation >= 1:
			distances = _distances(next, blocked)
			var space := distances.size()
			if space < bot.body.size() + bot.growth + 2:
				value -= 500.0 - space
		var food_distance := 999.0
		for morsel in food:
			var candidate := float(distances.get(morsel, 999)) if generation >= 1 else float(absi(morsel.x - next.x) + absi(morsel.y - next.y))
			food_distance = minf(food_distance, candidate)
		value -= food_distance * (1.0 if generation < 3 else 0.5)
		if generation >= 2:
			var ahead := body[0] + direction * (2 if generation == 2 else 3)
			var hunt_distance := float(distances.get(ahead, absi(ahead.x - next.x) + absi(ahead.y - next.y)))
			value -= hunt_distance * (0.8 + 0.4 * (generation - 2))
		if danger.has(next):
			value -= 25.0
		if generation == 0:
			value += rng.randf() * 6.0
		elif generation == 1:
			value += rng.randf() * 1.5
		if heading == bot.direction:
			value += 0.3
		if value > best_value:
			best_value = value
			best = heading
	return best

func _distances(start: Vector2i, blocked: Dictionary) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var distance := {start: 0}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for heading in Grid.DIRECTIONS:
			var next := cell + heading
			if inside(next) and not blocked.has(next) and not distance.has(next):
				distance[next] = int(distance[cell]) + 1
				queue.append(next)
	return distance

func snapshot() -> Dictionary:
	return {"body": body.duplicate(), "direction": direction}
