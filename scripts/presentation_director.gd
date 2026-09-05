extends RefCounted

const PALETTES := {
	"snake": [Color("9bbc0f"), Color("306230"), Color("0f380f"), Color("8bac0f")],
	"maze": [Color("a9cbb0"), Color("385b63"), Color("183b42"), Color("e7ae68")],
	"frogger": [Color("a4b4ad"), Color("334c5c"), Color("182d3d"), Color("edc477")],
	"asteroids": [Color("172936"), Color("4b6d7f"), Color("b7e3c0"), Color("edba86")],
}

static func palette(stage: String) -> Array:
	return PALETTES.get(stage, PALETTES.snake)
