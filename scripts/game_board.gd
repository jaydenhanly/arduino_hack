extends Node2D

const Grid = preload("res://scripts/grid.gd")
const Art = preload("res://scripts/pixel_art.gd")

var stage: RefCounted
var clock := 0.0
var mode := "snake"
var shift_progress := 0.0
var shift_source: Dictionary = {}
var shift_target: RefCounted

func _draw() -> void:
	if mode == "arena" and stage != null and stage.meltdown() and stage.started and not stage.stopped:
		draw_set_transform(Vector2(roundf(sin(clock * 61.0) * 1.5), roundf(cos(clock * 53.0) * 1.5)))
	draw_rect(Rect2(Grid.ORIGIN - Vector2(3, 3), Vector2(Grid.SIZE * Grid.CELL) + Vector2(6, 6)), Art.INK, false, 2)
	for row in Grid.SIZE.y:
		for column in Grid.SIZE.x:
			draw_rect(Rect2(Grid.ORIGIN + Vector2(column, row) * Grid.CELL + Vector2(6, 6), Vector2.ONE), Art.MID)
	if stage == null:
		return
	if mode == "shifting":
		_draw_shift()
		return
	if mode == "shifting_arena":
		_draw_arena_shift()
		return
	if mode == "maze":
		_draw_maze()
		return
	if mode == "arena":
		_draw_arena()
		return
	var snake: RefCounted = stage
	draw_rect(Grid.rect(snake.obstacle).grow(-1), Art.DARK)
	draw_rect(Grid.rect(snake.obstacle).grow(-4), Art.INK)
	Art.bitmap(self, Art.APPLE, Grid.rect(snake.apple).position + Vector2(3, 3), 1, Art.INK)
	for index in range(snake.body.size() - 1, -1, -1):
		if snake.body.size() == 1 and fmod(clock, 0.8) > 0.5:
			continue
		var cell: Vector2i = snake.body[index]
		var tile := Grid.rect(cell).grow(-1)
		if snake.stretch > 0:
			tile.position = Grid.rect(snake.body[0]).grow(-1).position.lerp(tile.position, 1.0 - snake.stretch / 0.22).round()
		draw_rect(tile, Art.INK if index == 0 else Art.DARK)
		if index == 0:
			draw_rect(Rect2(tile.position + Vector2(3, 3), Vector2(2, 2)), Art.LIGHT)
			draw_rect(Rect2(tile.position + Vector2(7, 3), Vector2(2, 2)), Art.LIGHT)

func _draw_maze() -> void:
	for wall: Rect2i in stage.walls:
		_wall(Rect2(Grid.ORIGIN + Vector2(wall.position) * Grid.CELL, Vector2(wall.size) * Grid.CELL))
	for pellet: Vector2i in stage.pellets:
		draw_rect(Rect2(Grid.rect(pellet).get_center().round() - Vector2.ONE * 2, Vector2.ONE * 4), Art.DARK)
	if stage.ghost_alive:
		if stage.started and stage.ghost_elapsed > 0.17:
			draw_rect(Grid.rect(stage.ghost_next).grow(-3), Art.DARK, false, 1)
		_ghost(Grid.rect(stage.ghost).position)
	_draw_tail(stage.body)

func _draw_shift() -> void:
	var eased := smoothstep(0.0, 1.0, shift_progress)
	for index in shift_target.walls.size():
		var wall: Rect2i = shift_target.walls[index]
		var source_rect := Grid.rect(shift_source.body[index + 4]).grow(-1)
		var target_rect := Rect2(Grid.ORIGIN + Vector2(wall.position) * Grid.CELL, Vector2(wall.size) * Grid.CELL)
		_wall(Rect2(source_rect.position.lerp(target_rect.position, eased).round(), source_rect.size.lerp(target_rect.size, eased).round()))
	var apple_position := Grid.rect(shift_source.apple).position + Vector2(3, 3)
	if shift_progress < 0.4:
		Art.bitmap(self, Art.APPLE, apple_position, 1, Art.INK)
	var scatter := smoothstep(0.18, 0.95, shift_progress)
	for pellet: Vector2i in shift_target.pellets:
		var pellet_position := Grid.rect(pellet).get_center() - Vector2.ONE * 2
		draw_rect(Rect2(apple_position.lerp(pellet_position, scatter).round(), Vector2.ONE * 4), Art.DARK)
	var obstacle_rect := Grid.rect(shift_source.obstacle).grow(-1)
	var awakening := smoothstep(0.35, 0.85, shift_progress)
	var shell := obstacle_rect.grow(-2 * awakening)
	draw_rect(Rect2(shell.position.round(), shell.size.round()), Art.DARK)
	for row in 8:
		for column in 8:
			var is_ghost_pixel: bool = Art.GHOST[row][column] == "1"
			var threshold := float(row * 8 + column) / 64.0
			if is_ghost_pixel or awakening < threshold:
				draw_rect(Rect2(obstacle_rect.position + Vector2(column + 2, row + 2), Vector2.ONE), Art.INK)
	if awakening > 0.6:
		draw_rect(Rect2(obstacle_rect.position + Vector2(4, 5), Vector2(2, 2)), Art.LIGHT)
		draw_rect(Rect2(obstacle_rect.position + Vector2(8, 5), Vector2(2, 2)), Art.LIGHT)
	_draw_tail(shift_target.body)

func _draw_arena() -> void:
	var depth: int = stage.fire_depth()
	if depth > 0:
		for row in stage.SIZE.y:
			for column in stage.SIZE.x:
				var cell := Vector2i(column, row)
				if stage.burning(cell):
					_flame(cell, stage.rect(cell))
	for morsel: Vector2i in stage.food:
		_food(stage.rect(morsel))
	for bot in stage.bots:
		_draw_bot(bot.body, bot.generation)
	_draw_player(stage.body)
	if not stage.started and fmod(clock, 0.6) < 0.4:
		draw_rect(stage.rect(stage.body[0]).grow(2), Art.INK, false, 1)

func _draw_arena_shift() -> void:
	var eased := smoothstep(0.0, 1.0, shift_progress)
	var scale_px := lerpf(Grid.CELL, shift_target.CELL, eased)
	var offset := Vector2(shift_target.OFFSET) * eased
	var walls_fade := smoothstep(0.0, 0.7, shift_progress)
	for wall: Rect2i in shift_source.walls:
		var area := Rect2(Grid.ORIGIN + (Vector2(wall.position) + offset) * scale_px, Vector2(wall.size) * scale_px)
		var shrink := Vector2(area.size) * 0.5 * walls_fade
		var shrunk := area.grow_individual(-shrink.x, -shrink.y, -shrink.x, -shrink.y)
		if shrunk.size.x > 1 and shrunk.size.y > 1:
			_wall(Rect2(shrunk.position.round(), shrunk.size.round()))
	var scatter := smoothstep(0.1, 0.9, shift_progress)
	var ghost_origin := Grid.ORIGIN + (Vector2(shift_source.ghost) + offset) * scale_px
	for index in shift_target.food.size():
		var morsel: Vector2i = shift_target.food[index]
		var from := ghost_origin + Vector2.ONE * scale_px * 0.5
		if index < shift_source.pellets.size():
			from = Grid.ORIGIN + (Vector2(shift_source.pellets[index]) + offset + Vector2(0.5, 0.5)) * scale_px
		var target: Vector2 = shift_target.rect(morsel).get_center()
		var dot := from.lerp(target, scatter).round()
		draw_rect(Rect2(dot - Vector2.ONE, Vector2.ONE * 3), Art.DARK)
	if shift_progress < 0.5:
		var pixel := scale_px / 14.0
		for row in 8:
			for column in 8:
				if Art.GHOST[row][column] == "1" and fmod(float(row * 8 + column) * 0.37, 1.0) > shift_progress * 2.0:
					draw_rect(Rect2((ghost_origin + Vector2(column + 3, row + 3) * pixel).round(), Vector2.ONE * maxf(1.0, pixel)), Art.INK)
	var wake := smoothstep(0.55, 1.0, shift_progress)
	for bot in shift_target.bots:
		for index in bot.body.size():
			if float(index) / bot.body.size() < wake:
				var tile: Rect2 = shift_target.rect(bot.body[index]).grow(-1)
				draw_rect(tile, Art.DARK)
				draw_rect(tile.grow(-2), Art.MID)
	for index in range(shift_source.body.size() - 1, -1, -1):
		var cell: Vector2i = shift_source.body[index]
		var tile := Rect2(Grid.ORIGIN + (Vector2(cell) + offset) * scale_px, Vector2.ONE * scale_px).grow(-1)
		draw_rect(Rect2(tile.position.round(), tile.size.round()), Art.INK if index == 0 else Art.DARK)
		if index == 0:
			var eye := maxf(1.0, scale_px / 7.0)
			draw_rect(Rect2((tile.position + Vector2(2, 2) * eye).round(), Vector2.ONE * eye), Art.LIGHT)
			draw_rect(Rect2((tile.position + Vector2(4, 2) * eye).round(), Vector2.ONE * eye), Art.LIGHT)

func _flame(cell: Vector2i, area: Rect2) -> void:
	var phase := int(clock * 14.0) + cell.x * 3 + cell.y * 5
	var tone := phase % 4
	draw_rect(area, Art.DARK if tone != 0 else Art.INK)
	var tip := area.position + Vector2(1 + (phase / 2) % 4, 1 + phase % 3)
	draw_rect(Rect2(tip, Vector2(2, 2)), Art.LIGHT if tone == 2 else Art.INK)
	if tone == 1:
		draw_rect(Rect2(area.position + Vector2(3, 4), Vector2.ONE), Art.LIGHT)

func _food(area: Rect2) -> void:
	draw_rect(Rect2(area.get_center().round() - Vector2.ONE, Vector2.ONE * 3), Art.DARK)

func _draw_player(cells: Array[Vector2i]) -> void:
	for index in range(cells.size() - 1, -1, -1):
		var tile: Rect2 = stage.rect(cells[index]).grow(-1)
		draw_rect(tile, Art.INK if index == 0 else Art.DARK)
		if index == 0:
			draw_rect(Rect2(tile.position + Vector2(1, 1), Vector2.ONE), Art.LIGHT)
			draw_rect(Rect2(tile.position + Vector2(3, 1), Vector2.ONE), Art.LIGHT)

func _draw_bot(cells: Array[Vector2i], generation: int) -> void:
	for index in range(cells.size() - 1, -1, -1):
		var tile: Rect2 = stage.rect(cells[index]).grow(-1)
		if index == 0:
			draw_rect(tile, Art.DARK)
			draw_rect(Rect2(tile.position + Vector2(1, 1), Vector2.ONE), Art.LIGHT)
			draw_rect(Rect2(tile.position + Vector2(3, 1), Vector2.ONE), Art.LIGHT)
			continue
		draw_rect(tile, Art.DARK, false, 1)
		draw_rect(tile.grow(-1), Art.MID if generation < 2 else Art.DARK)
		if generation >= 4:
			draw_rect(tile.grow(-2), Art.INK)

func _draw_tail(cells: Array[Vector2i]) -> void:
	for index in range(cells.size() - 1, -1, -1):
		var tile := Grid.rect(cells[index]).grow(-1)
		draw_rect(tile, Art.INK if index == 0 else Art.DARK)
		if index == 0:
			draw_rect(Rect2(tile.position + Vector2(3, 3), Vector2(2, 2)), Art.LIGHT)
			draw_rect(Rect2(tile.position + Vector2(7, 3), Vector2(2, 2)), Art.LIGHT)
		else:
			draw_rect(tile.grow(-4), Art.MID)

func _wall(area: Rect2) -> void:
	draw_rect(area, Art.DARK)
	if area.size.x > 6 and area.size.y > 6:
		draw_rect(area.grow(-3), Art.LIGHT, false, 1)

func _ghost(origin: Vector2) -> void:
	Art.bitmap(self, Art.GHOST, origin + Vector2(3, 3), 1, Art.INK)
	draw_rect(Rect2(origin + Vector2(5, 6), Vector2(2, 2)), Art.LIGHT)
	draw_rect(Rect2(origin + Vector2(9, 6), Vector2(2, 2)), Art.LIGHT)
