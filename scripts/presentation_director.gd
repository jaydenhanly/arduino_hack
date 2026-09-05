extends RefCounted

const PALETTES := {
	"snake": [Color("9bbc0f"), Color("306230"), Color("0f380f"), Color("8bac0f")],
	"maze": [Color("a9cbb0"), Color("385b63"), Color("183b42"), Color("e7ae68")],
	"frogger": [Color("a4b4ad"), Color("334c5c"), Color("182d3d"), Color("edc477")],
	"asteroids": [Color("172936"), Color("4b6d7f"), Color("b7e3c0"), Color("edba86")],
}
# How far a fully dark room dims each palette color toward black. Kept well
# under 1.0 so ink and background stay distinguishable, never crushed flat.
const MAX_DARKEN := 0.6

static var _dark_level := 0.0

## Called by LightSensor as ambient lux changes: 0 is full brightness (no
## board, or a well-lit room), 1 is the sensor's darkest reading.
static func set_dark_level(level: float) -> void:
	_dark_level = clampf(level, 0.0, 1.0)

static func palette(stage: String) -> Array:
	var colors: Array = PALETTES.get(stage, PALETTES.snake)
	if _dark_level <= 0.0:
		return colors
	var darkened: Array = []
	for color: Color in colors:
		darkened.append(color.lerp(Color.BLACK, _dark_level * MAX_DARKEN))
	return darkened
