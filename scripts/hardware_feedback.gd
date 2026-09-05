extends Node

signal feedback_requested(event: Dictionary)

const Protocol = preload("res://scripts/feedback_protocol.gd")
const Transport = preload("res://scripts/feedback_transport.gd")
const PRIORITY := {"idle": 0, "comment": 1, "collect": 2, "danger": 3, "transform": 4, "death": 5, "victory": 5}
const HAPTICS := {
	"idle": [], "comment": [], "collect": [{"on_ms": 18, "off_ms": 0}],
	"danger": [{"on_ms": 30, "off_ms": 0}],
	"transform": [{"on_ms": 24, "off_ms": 60}, {"on_ms": 40, "off_ms": 0}],
	"death": [{"on_ms": 70, "off_ms": 60}, {"on_ms": 25, "off_ms": 0}],
	"victory": [{"on_ms": 25, "off_ms": 70}, {"on_ms": 25, "off_ms": 70}, {"on_ms": 55, "off_ms": 0}],
}
const FRAME_COUNTS := {"idle": 32, "collect": 8, "danger": 5, "transform": 16, "death": 10, "victory": 14, "comment": 6}

var last_event: Dictionary = {}
var recent_events: Array[Dictionary] = []
var transport: Callable
var enabled: bool = true
var capability_status: String = "desktop_mock"
var dropped: int = 0
var _client: Node
var _pending: String = "idle"
var _active: String = "idle"
var _clock: float = 0.0
var _until: float = 0.0
var _last_sent: float = -1.0
var _last_pulse: float = -1.0
var _sequence: int = 0
var _was_enabled: bool = true


func _ready() -> void:
	_client = Transport.new()
	add_child(_client)
	if not _client.endpoint.is_empty():
		transport = _client.send


func reset() -> void:
	_pending = "idle"
	_active = "idle"
	_until = 0.0
	_last_sent = -1.0
	_last_pulse = -1.0
	if _client != null:
		_client.reset_connection()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	_clock += delta
	if _client != null:
		capability_status = _client.status
	if not enabled:
		if _was_enabled:
			reset()
		_was_enabled = false
		return
	_was_enabled = true
	if _clock >= _until and _pending.is_empty():
		_pending = "idle"
	if _pending.is_empty() or _clock - _last_sent < 0.1 - 0.000000001:
		return
	var kind := _pending
	var previous_priority: int = PRIORITY[_active]
	_pending = ""
	_active = kind
	_sequence = _sequence % 2147483647 + 1
	var packet := program(kind, _sequence)
	if _clock - _last_pulse < 0.15 - 0.000000001 and int(PRIORITY[kind]) <= previous_priority:
		packet.vibration = []
	if not packet.vibration.is_empty():
		_last_pulse = _clock
	_until = _clock + Protocol.duration(packet)
	_last_sent = _clock
	last_event = {"kind": kind, "packet": packet}
	recent_events.append(last_event.duplicate(true))
	if recent_events.size() > 32:
		recent_events.pop_front()
	feedback_requested.emit(last_event.duplicate(true))
	if transport.is_valid():
		transport.call(packet.duplicate(true))


func emit_feedback(kind: String, _progress: float = 0.0) -> void:
	if not enabled or not PRIORITY.has(kind):
		return
	var priority: int = PRIORITY[kind]
	if (not _pending.is_empty() and priority < int(PRIORITY[_pending])) or (_clock < _until and priority < int(PRIORITY[_active])):
		dropped += 1
		return
	if _clock < _until and _active in ["death", "victory"]:
		dropped += 1
		return
	_pending = kind


static func program(kind: String, sequence: int = 1) -> Dictionary:
	if not PRIORITY.has(kind):
		return {}
	var frames: Array[Dictionary] = []
	var count: int = FRAME_COUNTS[kind]
	for step in count:
		var phase := float(step) / float(count - 1)
		var rows: Array[int] = []
		var level := 2
		var breath := (1.0 - cos(phase * TAU)) * 0.5
		if kind == "idle":
			level = 1 + int(breath * 2.0)
		elif kind == "comment":
			level = 1
		elif kind == "death" and step == count - 1:
			level = 0
		for row in 8:
			var mask := 0
			for column in 13:
				var distance := Vector2(column - 6.0, (row - 3.5) * 1.3).length()
				var lit := false
				match kind:
					"idle": lit = distance < 1.0 + breath * 2.3
					"collect": lit = absf(distance - phase * 8.0) < 0.8
					"danger": lit = distance < 5.0 * (1.0 - phase)
					"transform": lit = posmod(column + row * 2 + step * 3, 7) < 2
					"death": lit = distance < 7.0 * (1.0 - phase)
					"victory": lit = absf(distance - phase * 9.0) < 1.5 or distance < 1.5 * (1.0 - phase)
					"comment": lit = distance < 4.0 and posmod(column * 3 + row + step, 5) < 2
				if lit:
					mask |= 1 << (12 - column)
			rows.append(mask)
		frames.append({"rows": rows, "duration_ms": 100, "level": level})
	return {"version": Protocol.VERSION, "sequence": sequence, "priority": PRIORITY[kind],
		"replace": true, "loop": kind == "idle", "vibration": HAPTICS[kind].duplicate(true), "frames": frames}
