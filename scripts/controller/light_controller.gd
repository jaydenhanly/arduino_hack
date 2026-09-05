extends RefCounted
## Builds the Uno Q kit's 13x8 blue LED-matrix frame for a feedback cue: seven
## pattern rows plus a bottom progress row. Pure logic, no I/O: no game-facing
## matrix RPC exists yet (see README's "Uno Q and hardware feedback"), so this
## is the desktop-verifiable frame `hardware_feedback.gd` would hand to one
## when it does.

const PATTERNS := {"collect": [0, 0, 4, 14, 4, 0, 0],
	"danger": [4, 4, 4, 4, 0, 4, 0], "transform": [17, 10, 4, 10, 17, 10, 4],
	"death": [17, 10, 4, 10, 17, 0, 0], "victory": [17, 17, 21, 21, 10, 4, 0],
	"checkpoint": [0, 10, 0, 17, 14, 0, 0], "comment": [0, 10, 0, 0, 14, 0, 0]}

func has_pattern(kind: String) -> bool:
	return PATTERNS.has(kind)

## Returns {"rows": Array[int], "frame": PackedByteArray, "progress": float}
## for `kind`. `progress` is clamped to [0, 1] before the bottom row is built.
func frame_for(kind: String, progress: float) -> Dictionary:
	var clamped := clampf(progress, 0.0, 1.0)
	var rows: Array[int] = []
	for row: int in PATTERNS[kind]:
		rows.append(row << 4)
	rows.append((1 << int(clamped * 13)) - 1)
	var frame := PackedByteArray()
	for row: int in rows:
		for column in 13:
			frame.append(2 if row & (1 << (12 - column)) else 0)
	return {"rows": rows, "frame": frame, "progress": clamped}
