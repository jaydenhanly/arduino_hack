extends Node2D

const Grid = preload("res://scripts/grid.gd")
const Art = preload("res://scripts/pixel_art.gd")
const Presentation = preload("res://scripts/presentation_director.gd")
const Transition = preload("res://scripts/transition_director.gd")

var stage: RefCounted
var clock := 0.0
var mode := "snake"
var shift_progress := 0.0
var shift_source: Dictionary = {}
var shift_target: RefCounted
var shift_from := "snake"
var shift_to := "maze"

func _draw() -> void:
	if stage == null:
		return
	if mode == "shifting":
		_draw_shift()
	else:
		_draw_stage(stage, mode)

func _draw_stage(value: RefCounted, stage_name: String) -> void:
	var colors := Presentation.palette(stage_name)
	draw_rect(Rect2(0, 0, 400, 192), Art.map_tone(colors[0]))
	if stage_name in ["frogger", "asteroids"]:
		value.draw_stage(self, clock)
		return
	draw_rect(Rect2(Grid.ORIGIN - Vector2(3, 3), Vector2(Grid.SIZE * Grid.CELL) + Vector2(6, 6)), Art.map_tone(colors[2]), false, 2)
	for row in Grid.SIZE.y:
		for column in Grid.SIZE.x:
			draw_rect(Rect2(Grid.ORIGIN + Vector2(column, row) * Grid.CELL + Vector2(6, 6), Vector2.ONE), Art.map_tone(colors[3] if stage_name == "snake" else Color("99b9a1")))
	if stage_name == "maze":
		_draw_maze(value)
	else:
		_draw_snake(value)

func _draw_snake(snake: RefCounted) -> void:
	for wall: Vector2i in snake.walls:
		_wall(Grid.rect(wall).grow(-1), Art.DARK, Art.LIGHT)
	for spider: Vector2i in snake.spiders:
		Art.bitmap(self, Art.SPIDER, Grid.rect(spider).position + Vector2(2, 2), 1, Art.INK)
	if snake.mushroom.x >= 0:
		Art.bitmap(self, Art.MUSHROOM, Grid.rect(snake.mushroom).position + Vector2(2, 2), 1, Art.INK)
	# The apple is the player's objective, not part of the map — its color is
	# fixed to the base theme and never inverts with ambient lux.
	var base := Art.base_palette()
	Art.bitmap(self, Art.APPLE, Grid.rect(snake.apple).position + Vector2(2, 2), 1, base.ink)
	for index in range(snake.body.size() - 1, -1, -1):
		if snake.body.size() == 1 and fmod(clock, 0.8) > 0.5:
			continue
		var tile := Grid.rect(snake.body[index]).grow(-1)
		if snake.stretch > 0:
			tile.position = Grid.rect(snake.body[0]).grow(-1).position.lerp(tile.position, 1.0 - snake.stretch / 0.22).round()
		# The snake itself is the player, not part of the map — fixed color.
		draw_rect(tile, base.ink if index == 0 else base.dark)
		if index == 0:
			_eyes(tile.position, base.light)

func _draw_maze(maze: RefCounted) -> void:
	var colors := Presentation.palette("maze")
	for endpoint: Vector2i in [maze.topology.tunnel_left, maze.topology.tunnel_right]:
		var edge_x: float = Grid.ORIGIN.x - 4 if endpoint.x == 0 else Grid.ORIGIN.x + Grid.SIZE.x * Grid.CELL
		draw_rect(Rect2(Vector2(edge_x, Grid.rect(endpoint).position.y), Vector2(4, Grid.CELL)), Art.map_tone(colors[0]))
	for cell: Vector2i in maze.topology.wall_cells:
		var tile := Grid.rect(cell)
		draw_rect(tile, Art.map_tone(colors[1]))
		for heading in Grid.DIRECTIONS:
			if maze.walkable(cell + heading):
				var center := tile.get_center() + Vector2(heading) * (Grid.CELL * 0.5 - 1)
				var half_edge := Vector2(0, 6) if heading.x != 0 else Vector2(6, 0)
				draw_line(center - half_edge, center + half_edge, Art.map_tone(colors[2]))
	for pellet: Vector2i in maze.pellets:
		draw_rect(Rect2(Grid.rect(pellet).get_center().round() - Vector2.ONE, Vector2.ONE * 3), Art.map_tone(colors[3]))
	if maze.ghost_alive:
		if maze.started and maze.ghost_elapsed > 0.17:
			draw_rect(Grid.rect(maze.ghost_next).grow(-3), Art.map_tone(colors[1]), false, 1)
		_ghost(Grid.rect(maze.ghost).position, Art.map_tone(colors[3]), Art.map_tone(colors[2]))
	elif maze.respawn_warning:
		if int(clock * 8) % 2 == 0:
			_ghost(Grid.rect(maze.ghost).position, Art.map_tone(colors[3]), Art.map_tone(colors[2]))
	# The tail is the player, not part of the map — fixed color, unlike the
	# walls/pellets/ghost above.
	_draw_tail(maze.body, colors[2], colors[1], colors[0])

func _draw_shift() -> void:
	var frame := Transition.cut(shift_progress)
	var show_target := frame >= 9 or (frame >= 2 and frame % 3 == 2)
	_draw_stage(shift_target if show_target else stage, shift_to if show_target else shift_from)
	if frame % 3 == 1:
		draw_rect(Rect2(12, 30, 376, 160), Art.map_tone(Color(0.82, 0.92, 0.73, 0.83)))
		_draw_conversions(frame)
	for stripe in 4:
		var stripe_y := 35 + posmod(frame * 19 + stripe * 43, 148)
		if frame % 2 == stripe % 2:
			draw_rect(Rect2(12, stripe_y, 376, 2), Art.map_tone(Color(0.08, 0.2, 0.18, 0.28)))
	var origin: Vector2 = shift_source.get("player_position", stage.get_player_position())
	var target_position: Vector2 = shift_target.get_player_position()
	var fraction := floorf(shift_progress * 4.0) / 4.0
	var player_position := origin.lerp(target_position, fraction).round()
	# The player mid-transformation is still the player — fixed color.
	var base := Art.base_palette()
	draw_rect(Rect2(player_position - Vector2(5, 5), Vector2(10, 10)), base.ink)
	_eyes(player_position - Vector2(5, 5), base.light)

func _draw_conversions(frame: int) -> void:
	var fraction := float(frame / 3) / 3.0
	var base := Art.base_palette()
	if shift_from == "snake":
		var body: Array = shift_source.get("body", [])
		for index in shift_target.walls.size():
			var wall: Rect2i = shift_target.walls[index]
			var from := Grid.rect(body[index % body.size()]) if not body.is_empty() else Rect2(190, 96, 12, 12)
			var to := Rect2(Grid.ORIGIN + Vector2(wall.position) * Grid.CELL, Vector2(wall.size) * Grid.CELL)
			_wall(Rect2(from.position.lerp(to.position, fraction).round(), from.size.lerp(to.size, fraction).round()), Art.DARK, Art.LIGHT)
		# The apple is the player's objective — fixed color, even mid-morph.
		var apple: Vector2i = shift_source.get("apple", Vector2i(12, 6))
		for pellet: Vector2i in shift_target.pellets:
			var point := Grid.rect(apple).get_center().lerp(Grid.rect(pellet).get_center(), fraction).round()
			draw_rect(Rect2(point, Vector2(3, 3)), base.dark)
	elif shift_from == "maze":
		for index in stage.walls.size():
			var wall: Rect2i = stage.walls[index]
			var from := Grid.ORIGIN + Vector2(wall.position) * Grid.CELL
			var to := Vector2(12, 48 + (index % 5) * 24)
			var width := lerpf(wall.size.x * Grid.CELL, 376, fraction)
			draw_rect(Rect2(from.lerp(to, fraction).round(), Vector2(width, 6)), Art.DARK)
	else:
		for row in 5:
			for column in 9:
				var origin := Vector2(18 + column * 42, 48 + row * 24)
				var drift := Vector2((column - 4) * frame, (row - 2) * frame)
				draw_rect(Rect2(origin + drift, Vector2(8, 8)), Art.map_tone(Color("486771")))

func _draw_tail(cells: Array[Vector2i], ink: Color, dark: Color, light: Color) -> void:
	for index in range(cells.size() - 1, -1, -1):
		var tile := Grid.rect(cells[index]).grow(-1)
		draw_rect(tile, ink if index == 0 else dark)
		if index == 0:
			_eyes(tile.position, light)
		else:
			draw_rect(tile.grow(-3), light)

func _eyes(origin: Vector2, color: Color) -> void:
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(2, 2)), color)
	draw_rect(Rect2(origin + Vector2(6, 2), Vector2(2, 2)), color)

func _wall(area: Rect2, dark: Color, light: Color) -> void:
	draw_rect(area, dark)
	if area.size.x > 6 and area.size.y > 6:
		draw_rect(area.grow(-3), light, false, 1)

func _ghost(origin: Vector2, color: Color, ink: Color) -> void:
	var bounce := Vector2(0, int(clock * 4.0) % 2)
	Art.bitmap(self, Art.GHOST, origin + Vector2(2, 1) + bounce, 1, color)
	draw_rect(Rect2(origin + Vector2(4, 4) + bounce, Vector2(2, 2)), ink)
	draw_rect(Rect2(origin + Vector2(8, 4) + bounce, Vector2(2, 2)), ink)
