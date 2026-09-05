extends RefCounted

# The four working tones. Every renderer reads these; set_theme() swaps them.
static var LIGHT := Color("9bbc0f")
static var MID := Color("8bac0f")
static var DARK := Color("306230")
static var INK := Color("0f380f")
static var theme := "green"

const THEMES: Array[String] = ["green", "copenhagen"]
const GREEN := {"light": Color("9bbc0f"), "mid": Color("8bac0f"), "dark": Color("306230"), "ink": Color("0f380f")}
# Copenhagen palette: 16 colours, drawn from Nyhavn fronts, copper roofs and the harbour.
const CPH := {
	"ink": Color("1e2230"), "slate": Color("4a5568"), "stone": Color("a8adb4"), "sky": Color("c9d9e3"),
	"cream": Color("f3e9d2"), "white": Color("ffffff"), "water": Color("6fa3b8"), "deep": Color("3e6e86"),
	"blue": Color("3f6fa6"), "copper": Color("5fa98d"), "copper_dark": Color("2e6b5a"), "red": Color("c8102e"),
	"brick": Color("8e3b2f"), "brick_dark": Color("5a2620"), "terra": Color("d9743a"), "ochre": Color("e8b04b")
}
const GLYPHS := {
	"A":"01110/10001/10001/11111/10001/10001/10001", "B":"11110/10001/10001/11110/10001/10001/11110",
	"C":"01111/10000/10000/10000/10000/10000/01111", "D":"11110/10001/10001/10001/10001/10001/11110",
	"E":"11111/10000/10000/11110/10000/10000/11111", "F":"11111/10000/10000/11110/10000/10000/10000",
	"G":"01111/10000/10000/10111/10001/10001/01111", "H":"10001/10001/10001/11111/10001/10001/10001",
	"I":"11111/00100/00100/00100/00100/00100/11111", "J":"00111/00010/00010/00010/10010/10010/01100",
	"K":"10001/10010/10100/11000/10100/10010/10001", "L":"10000/10000/10000/10000/10000/10000/11111",
	"M":"10001/11011/10101/10101/10001/10001/10001", "N":"10001/11001/10101/10011/10001/10001/10001",
	"O":"01110/10001/10001/10001/10001/10001/01110", "P":"11110/10001/10001/11110/10000/10000/10000",
	"Q":"01110/10001/10001/10001/10101/10010/01101", "R":"11110/10001/10001/11110/10100/10010/10001",
	"S":"01111/10000/10000/01110/00001/00001/11110", "T":"11111/00100/00100/00100/00100/00100/00100",
	"U":"10001/10001/10001/10001/10001/10001/01110", "V":"10001/10001/10001/10001/10001/01010/00100",
	"W":"10001/10001/10001/10101/10101/10101/01010", "X":"10001/10001/01010/00100/01010/10001/10001",
	"Y":"10001/10001/01010/00100/00100/00100/00100", "Z":"11111/00001/00010/00100/01000/10000/11111",
	"0":"01110/10001/10011/10101/11001/10001/01110", "1":"00100/01100/00100/00100/00100/00100/01110",
	"2":"01110/10001/00001/00010/00100/01000/11111", "3":"11110/00001/00001/01110/00001/00001/11110",
	"4":"00010/00110/01010/10010/11111/00010/00010", "5":"11111/10000/10000/11110/00001/00001/11110",
	"6":"01110/10000/10000/11110/10001/10001/01110", "7":"11111/00001/00010/00100/01000/01000/01000",
	"8":"01110/10001/10001/01110/10001/10001/01110", "9":"01110/10001/10001/01111/00001/00001/01110",
	".":"00000/00000/00000/00000/00000/00110/00110", ":":"00000/00100/00100/00000/00100/00100/00000",
	"/":"00001/00001/00010/00100/01000/10000/10000", "-":"00000/00000/00000/11111/00000/00000/00000",
	">":"10000/01000/00100/00010/00100/01000/10000", "+":"00000/00100/00100/11111/00100/00100/00000",
	"!":"00100/00100/00100/00100/00100/00000/00100", "?":"01110/10001/00001/00010/00100/00000/00100"
}
const APPLE := ["00000100", "00001000", "01110110", "11111111", "11111111", "11111111", "01111110", "00100100"]
const HEART := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
const GHOST := ["00111100", "01111110", "11111111", "11011011", "10010011", "11111111", "11111111", "10100101"]
const SPIDER := ["01000010", "10100101", "01111110", "11111111", "11111111", "01111110", "10100101", "01000010"]
const MUSHROOM := ["00111100", "01111110", "11111111", "11111111", "00011000", "00011000", "00011000", "00111100"]

static func set_theme(name: String) -> void:
	theme = name if name in THEMES else "green"
	if theme == "copenhagen":
		LIGHT = CPH.cream
		MID = CPH.stone
		DARK = CPH.copper_dark
		INK = CPH.ink
	else:
		LIGHT = GREEN.light
		MID = GREEN.mid
		DARK = GREEN.dark
		INK = GREEN.ink
	RenderingServer.set_default_clear_color(LIGHT)

static func next_theme() -> void:
	set_theme(THEMES[(THEMES.find(theme) + 1) % THEMES.size()])

static func cph() -> bool:
	return theme == "copenhagen"

static func text(canvas: CanvasItem, value: String, origin: Vector2, scale_value: int = 1, color: Color = Color.TRANSPARENT) -> void:
	if color == Color.TRANSPARENT:
		color = INK
	var cursor := origin.round()
	for letter in value.to_upper():
		if GLYPHS.has(letter):
			bitmap(canvas, GLYPHS[letter].split("/"), cursor, scale_value, color)
		cursor.x += 6 * scale_value

static func centered(canvas: CanvasItem, value: String, top: float, scale_value: int = 1, color: Color = Color.TRANSPARENT) -> void:
	text(canvas, value, Vector2((400 - (value.length() * 6 - 1) * scale_value) / 2.0, top), scale_value, color)

static func bitmap(canvas: CanvasItem, rows: Variant, origin: Vector2, scale_value: int, color: Color) -> void:
	for row in rows.size():
		for column in rows[row].length():
			if rows[row][column] == "1":
				canvas.draw_rect(Rect2(origin.round() + Vector2(column, row) * scale_value, Vector2.ONE * scale_value), color)
