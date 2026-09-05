extends "res://tests/autopilot/probe_base.gd"

func event(action: String, pressed: bool) -> void:
	var input := InputEventAction.new()
	input.action = action
	input.pressed = pressed
	Input.parse_input_event(input)
	Input.flush_buffered_events()

func percentile(samples: Array[float], fraction: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * fraction))]

func _ready() -> void:
	await super._ready()
	await settle(4)
	var game: Node = get_tree().current_scene
	game.seed_override = 2026
	game.pixel.model_enabled = true
	var baseline: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 60:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if frame > 15:
			baseline.append(float(now - previous) / 1000.0)
		previous = now
	save_frame("01_before_request")
	var started := Time.get_ticks_msec()
	previous = Time.get_ticks_usec()
	event("confirm", true)
	event("confirm", false)
	report("real_model_enabled", game.pixel.model_enabled)
	report("fallback_immediate", not game.pixel.message.is_empty())
	report("request_started", game.pixel.thinking and game.pixel.adapter != null)
	if game.stage == null or game.pixel.adapter == null:
		report("error", "Input did not start a live game and model request")
		finish()
		return
	var first_cell: Vector2i = game.stage.body[0]
	var first_clock: float = game.clock
	var movement := "move_right" if game.stage.apple.y != first_cell.y else "move_down"
	event(movement, true)
	var samples: Array[float] = []
	var busy_frames := 0
	var moved_while_busy := false
	var captured := false
	var completed := false
	while Time.get_ticks_msec() - started < 12000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		var adapter: Node = game.pixel.adapter
		if adapter.busy:
			busy_frames += 1
			moved_while_busy = moved_while_busy or game.stage.body[0] != first_cell
			if not captured and Engine.get_frames_drawn() > 65:
				save_frame("02_during_inference")
				captured = true
		elif busy_frames > 0:
			completed = true
			break
	report("request_completed", completed)
	report("game_moved_while_busy", moved_while_busy)
	report("game_clock_advanced", game.clock > first_clock)
	report("game_stayed_playable", game.state == game.State.PLAYING and game.lives == 1)
	report("busy_frames", busy_frames)
	report("elapsed_ms", Time.get_ticks_msec() - started)
	report("baseline_p95_ms", percentile(baseline, 0.95))
	report("during_p95_ms", percentile(samples, 0.95))
	report("during_max_ms", percentile(samples, 1.0))
	var service: Node = game.pixel.adapter.service
	report("bundled_service_ready", service != null and service.is_ready())
	report("service_error", service.last_error if service != null else "no service")
	report("service_port", service.get_port() if service != null else 0)
	report("service_process", service.get_process_id() if service != null else 0)
	report("inference_no_error", service != null and service.last_error.is_empty() and game.pixel.adapter.retry_after_msec == 0)
	report("message_after_request", game.pixel.message)
	var diagnostics: Dictionary = game.pixel.diagnostics()
	report("pixel_diagnostics", diagnostics)
	report("journal_events", game.pixel.journal.entries())
	report("llm_authored_message_displayed", diagnostics.source == "llm" and diagnostics.last_request.get("outcome") == "accepted")
	report("accepted_history_matches_screen", not game.pixel.commentary_history().is_empty()
		and game.pixel.commentary_history().back().message == game.pixel.message)
	event(movement, false)
	await settle(3)
	save_frame("03_after_inference")
	game.show_title()
	game.pixel.adapter.shutdown()
	await settle(3)
	report("model_process_stopped", service.get_process_id() == 0)
	finish()
