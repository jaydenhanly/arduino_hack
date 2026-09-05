extends SceneTree

const Adapter = preload("res://scripts/ai/gemma_adapter.gd")
const Journal = preload("res://scripts/ai/run_journal.gd")
const Fallbacks = preload("res://scripts/ai/pixel_fallbacks.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	var journal := Journal.new()
	journal.begin(1)
	journal.append("snake", "run_started", 0, 10, 0)
	journal.append("snake", "objective_milestone", 10, 10, 100)
	journal.append("snake", "collectible_streak", 10, 10, 100, {"count": 3})
	journal.append("snake", "transformation_started", 10, 10, 100)
	journal.append("maze", "transformation_completed", 0, 30, 100)
	journal.append("maze", "ghost_defeated", 20, 30, 200)
	journal.append("maze", "danger_escaped", 25, 30, 225)
	journal.append("frogger", "crossing_completed", 3, 3, 240)
	journal.append("asteroids", "asteroid_streak", 4, 4, 250, {"count": 4})
	journal.append("asteroids", "run_ended", 4, 4, 250, {"outcome": "victory", "duration_seconds": 90})
	journal.append("asteroids", "victory_reached", 4, 4, 250)
	var history: Array[int] = []
	var prior_choices: Array[String] = []
	var failures: Array[String] = []
	var frames := [0]
	var on_frame := func() -> void: frames[0] += 1
	process_frame.connect(on_frame)
	for turn in 3:
		var candidates := Fallbacks.conversation(journal, "aggressive", history)
		var reply: Dictionary = await adapter.request({"summary": journal.summary(),
			"emotion": "proud", "prior_choices": prior_choices, "exchange": turn}, candidates, true, 45.0)
		if reply.is_empty():
			failures.append("turn %d returned no validated reply" % turn)
			break
		print("PIXEL_MODEL_TURN_%d: %s" % [turn, JSON.stringify(reply)])
		prior_choices.append(reply.choices[turn])
		history.append(turn)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var comments := Fallbacks.commentary("victory", rng)
	var comment: Dictionary = await adapter.request({"summary": {"counts": journal.summary().counts},
		"current_event": journal.latest(), "current_emotion": "proud", "commentary_history": []}, comments, false, 8.0)
	if comment.is_empty():
		failures.append("commentary returned no validated reply: " + adapter.last_failure)
	print("PIXEL_MODEL_COMMENT: %s; prompt_tokens=%d" % [JSON.stringify(comment), adapter.last_prompt_tokens])
	if frames[0] < 3:
		failures.append("inference did not yield frames")
	process_frame.disconnect(on_frame)
	var legacy: String = await adapter.service.generate("Say hello in three words.", 16)
	if legacy.is_empty():
		failures.append("legacy service API returned no reply")
	var server_port: int = adapter.service.get_port()
	adapter.shutdown()
	var released := false
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var listener := TCPServer.new()
		if listener.listen(server_port, "127.0.0.1") == OK:
			listener.stop()
			released = true
			break
		await process_frame
	if not released or adapter.service.get_process_id() != 0:
		failures.append("server not released after shutdown")
	adapter.free()
	if not failures.is_empty():
		push_error("PIXEL_MODEL_SMOKE_FAILED: " + ", ".join(failures))
		quit(1)
	else:
		print("PIXEL_MODEL_SMOKE_OK: 3 conversation turns, commentary, legacy API, shutdown; %d frames" % frames[0])
		quit(0)
