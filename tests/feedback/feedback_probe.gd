extends SceneTree

const Hardware = preload("res://scripts/hardware_feedback.gd")
const Protocol = preload("res://scripts/feedback_protocol.gd")
const Transport = preload("res://scripts/feedback_transport.gd")

var checks := 0
var failures: Array[String] = []


func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures.append(label)
		push_error(label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var programs: Dictionary = {}
	for kind in Hardware.PRIORITY:
		var packet: Dictionary = Hardware.program(kind)
		programs[kind] = packet
		check(kind + " valid bounded packet", Protocol.valid(packet))
		check(kind + " deterministic", packet == Hardware.program(kind))
		check(kind + " no progress", not packet.has("progress"))
		for frame in packet.frames:
			check(kind + " matrix geometry", frame.rows.size() == 8)
			check(kind + " at most ten FPS", frame.duration_ms >= 100)
	check("comment never vibrates", programs.comment.vibration.is_empty())
	check("idle never vibrates", programs.idle.vibration.is_empty())
	check("distinct collect and transform", programs.collect.vibration != programs.transform.vibration)
	check("distinct death and victory", programs.death.vibration != programs.victory.vibration)
	check("idle loops", programs.idle.loop)
	for invalid in [null, [], {}, {"version": 1}]:
		check("malformed envelope", not Protocol.valid(invalid))
	for field in ["version", "sequence", "priority", "replace", "loop", "vibration", "frames"]:
		var malformed: Dictionary = programs.collect.duplicate(true)
		malformed[field] = "invalid"
		check("invalid field " + field, not Protocol.valid(malformed))
	for row in [-1, 8192, 0.5, true, NAN, INF]:
		var malformed: Dictionary = JSON.parse_string(JSON.stringify(programs.collect))
		malformed.frames[0].rows[0] = row
		check("invalid row", not Protocol.valid(malformed))
	for milliseconds in [0, 99, 1001]:
		var malformed: Dictionary = programs.collect.duplicate(true)
		malformed.frames[0].duration_ms = milliseconds
		check("invalid frame duration", not Protocol.valid(malformed))
	for milliseconds in [-1, 0, 9, 121]:
		var malformed: Dictionary = programs.collect.duplicate(true)
		malformed.vibration[0].on_ms = milliseconds
		check("invalid pulse duration", not Protocol.valid(malformed))
	var long_packet: Dictionary = programs.idle.duplicate(true)
	for frame in long_packet.frames:
		frame.duration_ms = 1000
	check("bounded total animation", not Protocol.valid(long_packet))
	var feedback := Hardware.new()
	var sent: Array = []
	feedback.transport = func(packet: Dictionary) -> void: sent.append(packet)
	feedback.emit_feedback("collect")
	feedback.emit_feedback("checkpoint")
	feedback.emit_feedback("transform")
	feedback.emit_feedback("comment")
	feedback.advance(0.0)
	check("coalesced highest priority", sent.size() == 1 and feedback.last_event.kind == "transform")
	feedback.emit_feedback("death")
	feedback.advance(0.099)
	check("rate limited", sent.size() == 1)
	feedback.advance(0.001)
	check("terminal preempts with haptics", sent.size() == 2 and feedback.last_event.kind == "death" and not sent[-1].vibration.is_empty())
	feedback.emit_feedback("collect")
	feedback.emit_feedback("death")
	feedback.advance(0.2)
	check("terminal cannot be restarted or downgraded", sent.size() == 2)
	feedback.advance(0.8)
	check("returns to idle", feedback.last_event.kind == "idle")
	feedback.enabled = false
	feedback.emit_feedback("victory")
	feedback.advance(1.0)
	check("disabled is silent", sent.size() == 3)
	feedback.enabled = true
	feedback.advance(0.1)
	check("reenable resumes idle", feedback.last_event.kind == "idle" and sent.size() == 4)
	feedback.reset()
	feedback.transport = Callable()
	feedback.emit_feedback("collect")
	feedback.advance(0.1)
	check("missing transport stays functional", feedback.last_event.kind == "collect")
	feedback.free()
	var client := Transport.new()
	client.send(programs.collect)
	check("empty endpoint drops safely", client.dropped == 1)
	client.endpoint = "/tmp/pixel-shift-no-feedback-" + str(OS.get_process_id())
	client.send(programs.collect)
	client._process(0.0)
	check("missing endpoint fail soft", client.status in ["unavailable", "unsupported"])
	client.send(programs.collect)
	var deadline: int = client._deadline
	client.send(programs.victory)
	client.send(programs.comment)
	check("pending transport keeps highest priority", client._pending.priority == 5)
	check("replacement cannot extend connection deadline", client._deadline == deadline)
	client._deadline = 0
	client._process(0.0)
	check("transport timeout clears pending", client._pending.is_empty() and client.status == "send_timeout")
	client.free()
	var destination := OS.get_environment("FEEDBACK_PACKETS_PATH")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		file.store_string(JSON.stringify(programs))
	print("FEEDBACK_CHECKS %d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)
