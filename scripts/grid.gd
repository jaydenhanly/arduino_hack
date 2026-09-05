extends RefCounted

const SIZE := Vector2i(24, 12)
const CELL := 12
const ORIGIN := Vector2(56, 36)
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
const ACTIONS: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y

static func wrap(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, SIZE.x), posmod(cell.y, SIZE.y))

static func rect(cell: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cell) * CELL, Vector2.ONE * CELL)
