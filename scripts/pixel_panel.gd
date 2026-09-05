extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const PAPER := Color("d4dfbb")
const INK := Color("203b3c")
const MUTED := Color("657c68")

var controller: Node
var selected := 0
var clock := 0.0
var expanded := false

func _draw() -> void:
	if controller == null:
		return
	if expanded:
		_draw_conversation()
	else:
		_draw_compact()

func _draw_compact() -> void:
	draw_rect(Rect2(0, 192, 400, 48), PAPER)
	draw_line(Vector2(0, 192), Vector2(400, 192), INK, 2)
	_avatar(Vector2(9, 201))
	Art.text(self, "PIXEL", Vector2(51, 199), 1, MUTED)
	var lines := wrap_text(controller.message, 55, 2)
	for index in lines.size():
		Art.text(self, lines[index], Vector2(51, 211 + index * 11), 1, INK)
	_thinking(Vector2(367, 201))

func _draw_conversation() -> void:
	draw_rect(Rect2(0, 0, 400, 240), Color(0.03, 0.08, 0.1, 0.74))
	draw_rect(Rect2(16, 40, 372, 191), INK)
	draw_rect(Rect2(12, 36, 372, 191), PAPER)
	draw_rect(Rect2(12, 36, 372, 191), INK, false, 2)
	Art.text(self, "PIXEL / RUN COMPLETE", Vector2(27, 49), 1, MUTED)
	_avatar(Vector2(27, 69))
	var lines := wrap_text(controller.message, 47, 3)
	for index in lines.size():
		Art.text(self, lines[index], Vector2(75, 73 + index * 12), 1, INK)
	_thinking(Vector2(347, 50))
	for index in controller.choices.size():
		var area := Rect2(26, 119 + index * 25, 342, 22)
		if selected == index:
			draw_rect(area, INK)
		else:
			draw_rect(area, MUTED, false, 1)
		var color := PAPER if selected == index else INK
		Art.text(self, ">" if selected == index else " ", area.position + Vector2(7, 7), 1, color)
		Art.text(self, controller.choices[index], area.position + Vector2(23, 7), 1, color)
	if not controller.choices.is_empty():
		Art.text(self, "A CHOOSE  /  B SKIP", Vector2(27, 205), 1, MUTED)
		Art.text(self, "%d/3" % mini(controller.exchange + 1, 3), Vector2(344, 205), 1, MUTED)
	else:
		Art.text(self, "B REPLAY MENU", Vector2(27, 205), 1, MUTED)

func _thinking(origin: Vector2) -> void:
	if not controller.thinking:
		return
	for index in 3:
		var height := 5 if int(clock * 5.0) % 3 == index else 2
		draw_rect(Rect2(origin + Vector2(index * 6, -height + 5), Vector2(3, height)), MUTED)

func _avatar(origin: Vector2) -> void:
	var bob := roundf(sin(clock * 3.0)) if controller.emotion in ["excited", "surprised"] else 0.0
	var base := origin + Vector2(0, bob)
	draw_rect(Rect2(base + Vector2(3, 4), Vector2(26, 24)), INK)
	draw_rect(Rect2(base + Vector2(5, 6), Vector2(22, 18)), PAPER)
	draw_rect(Rect2(base + Vector2(14, 0), Vector2(3, 5)), INK)
	draw_rect(Rect2(base + Vector2(12, 0), Vector2(7, 2)), MUTED)
	draw_rect(Rect2(base + Vector2(0, 11), Vector2(3, 9)), INK)
	draw_rect(Rect2(base + Vector2(29, 11), Vector2(3, 9)), INK)
	var blink := fmod(clock, 4.7) > 4.5
	var eye_height := 1 if blink else 4
	draw_rect(Rect2(base + Vector2(9, 11), Vector2(4, eye_height)), INK)
	draw_rect(Rect2(base + Vector2(20, 11), Vector2(4, eye_height)), INK)
	match controller.emotion:
		"curious":
			draw_line(base + Vector2(19, 8), base + Vector2(24, 7), INK)
			draw_rect(Rect2(base + Vector2(14, 19), Vector2(6, 2)), INK)
		"excited":
			draw_rect(Rect2(base + Vector2(12, 18), Vector2(10, 4)), INK)
			draw_rect(Rect2(base + Vector2(14, 18), Vector2(6, 1)), PAPER)
		"worried":
			draw_line(base + Vector2(9, 7), base + Vector2(14, 9), INK)
			draw_line(base + Vector2(19, 9), base + Vector2(24, 7), INK)
			draw_rect(Rect2(base + Vector2(13, 19), Vector2(8, 1)), INK)
		"surprised":
			draw_rect(Rect2(base + Vector2(14, 18), Vector2(5, 5)), INK)
		"proud":
			draw_line(base + Vector2(12, 18), base + Vector2(15, 21), INK)
			draw_line(base + Vector2(15, 21), base + Vector2(22, 17), INK)
	draw_rect(Rect2(base + Vector2(6, 29), Vector2(7, 2)), INK)
	draw_rect(Rect2(base + Vector2(20, 29), Vector2(7, 2)), INK)

static func wrap_text(value: String, width: int, limit: int) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in value.split(" ", false):
		if not line.is_empty() and line.length() + word.length() + 1 > width:
			lines.append(line)
			line = ""
		line += (" " if not line.is_empty() else "") + word
	if not line.is_empty():
		lines.append(line)
	if lines.size() > limit:
		lines.resize(limit)
	return lines
