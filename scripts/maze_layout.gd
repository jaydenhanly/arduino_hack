extends RefCounted

const Grid = preload("res://scripts/grid.gd")
const OFF_GRID := Vector2i(-1, -1)
const CELLS := [
	"########################",
	"#..........##..........#",
	"#.###.####.##.####.###.#",
	"#...#......##......#...#",
	"###.#.####....####.#.###",
	"L...#.....hGhh.....#...R",
	"#.###.##.#hhhh#.##.###.#",
	"#.....##........##.....#",
	"#.###.##.######.##.###.#",
	"#....#.....##.....#....#",
	"#87654321P.............#",
	"########################",
]

var wall_cells: Array[Vector2i] = []
var pellet_cells: Array[Vector2i] = []
var ghost_area: Array[Vector2i] = []
var body: Array[Vector2i] = []
var entrance := OFF_GRID
var ghost_spawn := OFF_GRID
var tunnel_left := OFF_GRID
var tunnel_right := OFF_GRID
var _floor: Dictionary = {}


func _init() -> void:
	var segments: Dictionary = {}
	assert(CELLS.size() == Grid.SIZE.y)
	for row in CELLS.size():
		assert(CELLS[row].length() == Grid.SIZE.x)
		for column in CELLS[row].length():
			var cell := Vector2i(column, row)
			var marker: String = CELLS[row][column]
			assert(marker in "#.P12345678GhLR")
			if marker == "#":
				wall_cells.append(cell)
				continue
			_floor[cell] = true
			match marker:
				".": pellet_cells.append(cell)
				"P":
					entrance = cell
					segments[0] = cell
				"G":
					ghost_spawn = cell
					ghost_area.append(cell)
				"h": ghost_area.append(cell)
				"L": tunnel_left = cell
				"R": tunnel_right = cell
				_: segments[int(marker)] = cell
	for index in segments.size():
		body.append(segments[index])


func walkable(cell: Vector2i) -> bool:
	return _floor.has(cell)


func neighbor(cell: Vector2i, heading: Vector2i) -> Vector2i:
	if not walkable(cell) or heading not in Grid.DIRECTIONS:
		return OFF_GRID
	if cell == tunnel_left and heading == Vector2i.LEFT:
		return tunnel_right
	if cell == tunnel_right and heading == Vector2i.RIGHT:
		return tunnel_left
	var destination := cell + heading
	return destination if walkable(destination) else OFF_GRID


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for heading in Grid.DIRECTIONS:
		var destination := neighbor(cell, heading)
		if destination != OFF_GRID:
			result.append(destination)
	return result


func heading_to(cell: Vector2i, destination: Vector2i) -> Vector2i:
	for heading in Grid.DIRECTIONS:
		if neighbor(cell, heading) == destination:
			return heading
	return Vector2i.ZERO


func distances(start: Vector2i) -> Dictionary:
	if not walkable(start):
		return {}
	var queue: Array[Vector2i] = [start]
	var result := {start: 0}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for destination in neighbors(cell):
			if not result.has(destination):
				result[destination] = int(result[cell]) + 1
				queue.append(destination)
	return result
