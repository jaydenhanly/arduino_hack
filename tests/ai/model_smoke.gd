extends SceneTree

const Controller = preload("res://scripts/ai/pixel_controller.gd")
const Adapter = preload("res://scripts/ai/gemma_adapter.gd")
const Service = preload("res://scripts/llm/llm_service.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const Conversation = preload("res://scripts/ai/conversation_prompt.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pixel := Controller.new()
	pixel.adapter = Adapter.new()
	pixel.adapter.service = Service.new()
	pixel.adapter.add_child(pixel.adapter.service)
	pixel.add_child(pixel.adapter)
	root.add_child(pixel)
	var failures: Array[String] = []
	var startup: Error = await pixel.adapter.service.start(45000)
	if startup != OK:
		push_error("PIXEL_MODEL_SMOKE_FAILED: " + pixel.adapter.service.last_error)
		pixel.free()
		quit(1)
		return
	pixel.begin_run(1, 2026)
	pixel.observe("snake", "collectible_streak", 10, 10, 100, {"count": 3})
	pixel.observe("maze", "ghost_defeated", 20, 30, 200)
	pixel.observe("frogger", "crossing_completed", 3, 3, 240)
	pixel.observe("asteroids", "asteroid_streak", 4, 4, 250, {"count": 4})
	pixel.observe("asteroids", "run_ended", 4, 4, 250, {"outcome": "victory", "duration_seconds": 90})
	pixel.observe("asteroids", "victory", 4, 4, 250)
	pixel.begin_conversation()
	var accepted := 0
	var structured := 0
	for turn in 10:
		if not pixel.thinking or not pixel.choices.is_empty():
			failures.append("turn not atomic " + str(turn))
		var deadline := Time.get_ticks_msec() + 10000
		while pixel.thinking and Time.get_ticks_msec() < deadline:
			pixel.tick(0.0)
			await process_frame
		if pixel.thinking or pixel.choices.size() != 3:
			failures.append("turn did not finalize " + str(turn))
			break
		var diagnostics: Dictionary = pixel.diagnostics()
		if diagnostics.source == "llm_conversation":
			accepted += 1
		if not Reply.validate_structure(pixel.adapter.last_raw, true).is_empty():
			structured += 1
		var context: Dictionary = pixel.conversation_context()
		if context.history.size() > 3 or pixel.adapter.last_prompt_tokens + Conversation.OUTPUT_TOKENS + 16 > 1024:
			failures.append("context exceeded " + str(turn))
		print("CONVERSATION_SAMPLE: " + JSON.stringify({"turn": turn, "model_raw": pixel.adapter.last_raw,
			"quality_findings": pixel.adapter.last_quality_findings, "diagnostics": diagnostics,
			"display": {"emotion": pixel.emotion, "message": pixel.message, "choices": pixel.choices},
			"history_stored": context.history.size(), "history_sent": pixel.adapter.last_history_size}))
		pixel.select_choice(turn % 3)
	var before_exit: String = pixel.message
	pixel.end_conversation()
	var deadline := Time.get_ticks_msec() + 10000
	while pixel.adapter.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	if pixel.conversing or pixel.message != before_exit or not pixel.choices.is_empty() or pixel.journal.sequence != 0:
		failures.append("late reply changed exited conversation")
	if accepted == 0:
		failures.append("no original generated dialogue accepted")
	var legacy: String = await pixel.adapter.service.generate("Say hello in three words.", 16)
	if legacy.is_empty():
		failures.append("legacy service API returned no reply")
	pixel.adapter.shutdown()
	if pixel.adapter.service.get_process_id() != 0:
		failures.append("owned server not stopped")
	pixel.free()
	print("CONVERSATION_ACCEPTANCE: " + JSON.stringify({"turns": 10, "structurally_valid": structured, "accepted": accepted, "failures": failures}))
	if failures.is_empty():
		print("PIXEL_MODEL_SMOKE_OK: ten atomic turns, bounded history, exit, legacy API, shutdown")
	else:
		push_error("PIXEL_MODEL_SMOKE_FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
