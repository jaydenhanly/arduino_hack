extends Node

signal feedback_requested(event: Dictionary)

const PULSES := {"collect": 18, "danger": 35, "transform": 45, "death": 70,
	"victory": 60, "checkpoint": 20}
const PATTERNS := {"collect": [0, 0, 4, 14, 4, 0, 0],
	"danger": [4, 4, 4, 4, 0, 4, 0], "transform": [17, 10, 4, 10, 17, 10, 4],
	"death": [17, 10, 4, 10, 17, 0, 0], "victory": [17, 17, 21, 21, 10, 4, 0],
	"checkpoint": [0, 10, 0, 17, 14, 0, 0], "comment": [0, 10, 0, 0, 14, 0, 0]}

var last_event: Dictionary = {}
var recent_events: Array[Dictionary] = []
var transport: Callable
var enabled := true
var time_since_pulse := 1.0
var capability_status := "desktop_mock: kit has no game-to-matrix transport"

func advance(delta: float) -> void:
	time_since_pulse += delta

func emit_feedback(kind: String, progress: float = 0.0) -> void:
	if not enabled or not PATTERNS.has(kind):
		return
	var duration: int = int(PULSES.get(kind, 0))
	if time_since_pulse < 0.15:
		duration = 0
	if duration > 0:
		time_since_pulse = 0.0
	var rows: Array[int] = []
	for row: int in PATTERNS[kind]:
		rows.append(row << 4)
	rows.append((1 << int(clampf(progress, 0.0, 1.0) * 13)) - 1)
	var frame := PackedByteArray()
	for row: int in rows:
		for column in 13:
			frame.append(2 if row & (1 << (12 - column)) else 0)
	last_event = {"kind": kind, "pulse_ms": duration, "matrix_rows": rows, "matrix_frame": frame,
		"progress": clampf(progress, 0.0, 1.0), "color": "blue"}
	recent_events.append(last_event.duplicate(true))
	if recent_events.size() > 32:
		recent_events.pop_front()
	feedback_requested.emit(last_event.duplicate(true))
	if transport.is_valid():
		transport.call(last_event.duplicate(true))
