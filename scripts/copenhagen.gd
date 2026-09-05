extends RefCounted

# Copenhagen theme sprites. Everything is draw_rect, like the rest of the game.
# Every building fills a 70x28 box, which is one maze wall (5x2 cells of 14 px).

const Art = preload("res://scripts/pixel_art.gd")
const C := Art.CPH

const WALL_BUILDINGS: Array[String] = ["nyhavn", "borsen", "rundetaarn", "raadhus"]
const SKYLINE: Array[String] = ["nyhavn", "borsen", "rundetaarn", "marmorkirken", "raadhus"]

static func r(canvas: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), color)

static func building(canvas: CanvasItem, name: String, x: float, y: float) -> void:
	match name:
		"nyhavn": nyhavn(canvas, x, y)
		"borsen": borsen(canvas, x, y)
		"rundetaarn": rundetaarn(canvas, x, y)
		"raadhus": raadhus(canvas, x, y)
		"marmorkirken": marmorkirken(canvas, x, y)
		"vorfrelsers": vorfrelsers(canvas, x, y)

static func wall_building(canvas: CanvasItem, index: int, x: float, y: float) -> void:
	building(canvas, WALL_BUILDINGS[index % WALL_BUILDINGS.size()], x, y)

static func skyline(canvas: CanvasItem, x: float, y: float) -> void:
	for index in SKYLINE.size():
		building(canvas, SKYLINE[index], x + index * 72, y)

static func _windows(canvas: CanvasItem, x: float, y: float, count: int, step: int, w: int, h: int) -> void:
	for index in count:
		r(canvas, x + index * step, y, w, h, C.ink)
		r(canvas, x + index * step, y, 1, 1, C.white)

static func nyhavn(canvas: CanvasItem, x: float, y: float) -> void:
	var colors: Array[Color] = [C.red, C.ochre, C.blue, C.cream, C.terra]
	var tops := [8, 5, 9, 6, 8]
	for index in 5:
		var hx: float = x + index * 14
		var top: float = y + tops[index]
		r(canvas, hx + 5, top - 3, 4, 1, C.brick_dark)
		r(canvas, hx + 3, top - 2, 8, 1, C.brick_dark)
		r(canvas, hx + 1, top - 1, 12, 1, C.brick_dark)
		r(canvas, hx + 10, top - 5, 2, 3, C.brick_dark)
		r(canvas, hx, top, 14, y + 28 - top, colors[index])
		r(canvas, hx, top, 1, y + 28 - top, C.ink)
		var wy := top + 3
		while wy + 4 <= y + 21:
			r(canvas, hx + 3, wy, 3, 4, C.ink)
			r(canvas, hx + 8, wy, 3, 4, C.ink)
			r(canvas, hx + 3, wy, 1, 1, C.white)
			r(canvas, hx + 8, wy, 1, 1, C.white)
			wy += 6
		r(canvas, hx + 6, y + 22, 3, 6, C.ink)
	r(canvas, x, y + 27, 70, 1, C.ink)

static func borsen(canvas: CanvasItem, x: float, y: float) -> void:
	r(canvas, x, y + 13, 70, 15, C.brick)
	r(canvas, x, y + 9, 70, 4, C.copper)
	r(canvas, x, y + 8, 70, 1, C.copper_dark)
	for gx in [0, 64]:
		r(canvas, x + gx, y + 5, 6, 8, C.stone)
		r(canvas, x + gx + 1, y + 3, 4, 2, C.stone)
		r(canvas, x + gx + 2, y + 1, 2, 2, C.stone)
	r(canvas, x + 33, y + 5, 4, 4, C.copper_dark)
	r(canvas, x + 34, y + 2, 2, 3, C.copper_dark)
	r(canvas, x + 34, y, 1, 2, C.ochre)
	r(canvas, x + 33, y + 6, 1, 1, C.ink)
	r(canvas, x + 36, y + 7, 1, 1, C.ink)
	r(canvas, x + 32, y + 8, 6, 1, C.copper_dark)
	_windows(canvas, x + 8, y + 16, 4, 6, 2, 4)
	_windows(canvas, x + 40, y + 16, 4, 6, 2, 4)
	_windows(canvas, x + 8, y + 22, 4, 6, 2, 4)
	_windows(canvas, x + 40, y + 22, 4, 6, 2, 4)
	r(canvas, x + 33, y + 21, 4, 7, C.brick_dark)
	r(canvas, x, y + 27, 70, 1, C.ink)

static func rundetaarn(canvas: CanvasItem, x: float, y: float) -> void:
	r(canvas, x, y + 16, 24, 12, C.cream)
	r(canvas, x, y + 14, 24, 2, C.slate)
	r(canvas, x + 2, y + 13, 20, 1, C.slate)
	_windows(canvas, x + 4, y + 19, 3, 7, 3, 4)
	r(canvas, x + 24, y + 2, 20, 26, C.brick)
	r(canvas, x + 25, y + 1, 18, 1, C.brick)
	r(canvas, x + 26, y, 16, 1, C.ink)
	r(canvas, x + 24, y + 2, 1, 26, C.brick_dark)
	r(canvas, x + 43, y + 2, 1, 26, C.brick_dark)
	r(canvas, x + 24, y + 9, 20, 1, C.cream)
	r(canvas, x + 24, y + 19, 20, 1, C.cream)
	r(canvas, x + 29, y + 12, 2, 4, C.ink)
	r(canvas, x + 37, y + 12, 2, 4, C.ink)
	r(canvas, x + 33, y + 4, 2, 4, C.ink)
	r(canvas, x + 33, y + 22, 2, 6, C.ink)
	r(canvas, x + 44, y + 12, 26, 16, C.brick)
	r(canvas, x + 44, y + 9, 26, 3, C.copper_dark)
	r(canvas, x + 46, y + 8, 22, 1, C.copper_dark)
	for wx in [49, 56, 63]:
		r(canvas, x + wx, y + 15, 2, 6, C.ink)
		r(canvas, x + wx, y + 15, 1, 1, C.white)
	r(canvas, x, y + 27, 70, 1, C.ink)

static func raadhus(canvas: CanvasItem, x: float, y: float) -> void:
	r(canvas, x, y + 11, 70, 17, C.brick)
	r(canvas, x, y + 8, 70, 3, C.copper_dark)
	r(canvas, x + 8, y + 2, 12, 26, C.brick)
	r(canvas, x + 8, y + 2, 1, 26, C.brick_dark)
	r(canvas, x + 8, y + 3, 12, 1, C.copper)
	r(canvas, x + 9, y + 1, 10, 2, C.copper)
	r(canvas, x + 12, y, 4, 1, C.copper_dark)
	r(canvas, x + 11, y + 5, 6, 5, C.white)
	r(canvas, x + 13, y + 7, 2, 1, C.ink)
	r(canvas, x + 13, y + 6, 1, 1, C.ink)
	r(canvas, x + 11, y + 13, 2, 4, C.ink)
	r(canvas, x + 15, y + 13, 2, 4, C.ink)
	r(canvas, x + 13, y + 21, 2, 7, C.ink)
	_windows(canvas, x + 26, y + 14, 7, 6, 2, 4)
	_windows(canvas, x + 26, y + 21, 7, 6, 2, 4)
	r(canvas, x + 30, y + 4, 12, 4, C.brick)
	r(canvas, x + 32, y + 2, 8, 2, C.brick)
	r(canvas, x + 34, y + 1, 4, 1, C.copper)
	r(canvas, x, y + 27, 70, 1, C.ink)

static func marmorkirken(canvas: CanvasItem, x: float, y: float) -> void:
	r(canvas, x, y + 18, 70, 10, C.stone)
	r(canvas, x, y + 16, 18, 2, C.slate)
	r(canvas, x + 52, y + 16, 18, 2, C.slate)
	_windows(canvas, x + 4, y + 21, 2, 7, 2, 4)
	_windows(canvas, x + 56, y + 21, 2, 7, 2, 4)
	r(canvas, x + 20, y + 13, 30, 15, C.cream)
	var cx := x + 22
	while cx < x + 50:
		r(canvas, cx, y + 14, 1, 8, C.slate)
		cx += 4
	r(canvas, x + 20, y + 22, 30, 1, C.slate)
	var rows := [[20, 30], [20, 30], [21, 28], [22, 26], [23, 24], [24, 22], [26, 18], [28, 14], [30, 10], [32, 6]]
	for index in rows.size():
		r(canvas, x + rows[index][0], y + 12 - index, rows[index][1], 1, C.copper)
	for rib in [29, 35, 41]:
		r(canvas, x + rib, y + 5, 1, 8, C.copper_dark)
	r(canvas, x + 20, y + 12, 30, 1, C.copper_dark)
	r(canvas, x + 33, y + 1, 4, 2, C.cream)
	r(canvas, x + 34, y, 2, 1, C.ochre)
	r(canvas, x + 33, y + 24, 4, 4, C.ink)
	r(canvas, x, y + 27, 70, 1, C.ink)

static func vorfrelsers(canvas: CanvasItem, x: float, y: float) -> void:
	r(canvas, x, y + 18, 27, 10, C.cream)
	r(canvas, x, y + 16, 27, 2, C.slate)
	_windows(canvas, x + 4, y + 21, 3, 8, 3, 4)
	r(canvas, x + 43, y + 16, 27, 12, C.brick)
	r(canvas, x + 43, y + 13, 27, 3, C.copper_dark)
	_windows(canvas, x + 47, y + 19, 3, 8, 2, 5)
	r(canvas, x + 27, y + 13, 16, 15, C.brick)
	r(canvas, x + 27, y + 13, 1, 15, C.brick_dark)
	r(canvas, x + 31, y + 17, 2, 4, C.ink)
	r(canvas, x + 37, y + 17, 2, 4, C.ink)
	r(canvas, x + 34, y + 23, 2, 5, C.ink)
	for index in 13:
		var w: int = maxi(1, 14 - index)
		var xx: float = x + 35 - floori(w / 2.0)
		var yy: float = y + 12 - index
		r(canvas, xx, yy, w, 1, C.copper_dark)
		r(canvas, xx + (index * 3) % w, yy, 1, 1, C.ochre)
	r(canvas, x + 34, y, 2, 1, C.ochre)
	r(canvas, x, y + 27, 70, 1, C.ink)

# A parked bicycle, one 14x14 cell. floor_color fills the wheel hubs.
static func bike(canvas: CanvasItem, origin: Vector2, floor_color: Color) -> void:
	var x := origin.x
	var y := origin.y
	for wx in [1, 8]:
		r(canvas, x + wx, y + 7, 5, 5, C.ink)
		r(canvas, x + wx + 1, y + 8, 3, 3, floor_color)
	r(canvas, x + 4, y + 8, 6, 1, C.red)
	r(canvas, x + 6, y + 5, 1, 3, C.red)
	r(canvas, x + 8, y + 4, 1, 4, C.red)
	r(canvas, x + 5, y + 4, 3, 1, C.ink)
	r(canvas, x + 8, y + 3, 3, 1, C.ink)

# Brick block used while a wall is still growing or dissolving.
static func brick_block(canvas: CanvasItem, area: Rect2) -> void:
	canvas.draw_rect(area, C.brick)
	if area.size.x > 6 and area.size.y > 6:
		canvas.draw_rect(area.grow(-3), C.cream, false, 1)

static func apple(canvas: CanvasItem, origin: Vector2) -> void:
	Art.bitmap(canvas, Art.APPLE.slice(2), origin + Vector2(0, 2), 1, C.red)
	r(canvas, origin.x + 5, origin.y, 1, 1, C.copper_dark)
	r(canvas, origin.x + 4, origin.y + 1, 1, 1, C.copper_dark)
	r(canvas, origin.x + 3, origin.y + 1, 1, 1, C.copper)
	r(canvas, origin.x + 2, origin.y + 3, 1, 1, C.white)

static func ghost(canvas: CanvasItem, origin: Vector2) -> void:
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		Art.bitmap(canvas, Art.GHOST, origin + offset, 1, C.ink)
	Art.bitmap(canvas, Art.GHOST, origin, 1, C.white)
	r(canvas, origin.x + 2, origin.y + 3, 1, 2, C.ink)
	r(canvas, origin.x + 5, origin.y + 3, 1, 2, C.ink)

# Board floor: pale sky with a stone dot in every cell.
static func floor(canvas: CanvasItem, origin: Vector2, size: Vector2i, cell: int) -> void:
	canvas.draw_rect(Rect2(origin, Vector2(size) * cell), C.sky)
	for row in size.y:
		for column in size.x:
			canvas.draw_rect(Rect2(origin + Vector2(column, row) * cell + Vector2(cell / 2, cell / 2), Vector2.ONE), C.stone)
