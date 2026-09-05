extends SceneTree

const Controller = preload("res://scripts/ai/pixel_controller.gd")
const Adapter = preload("res://scripts/ai/gemma_adapter.gd")
const Service = preload("res://scripts/llm/llm_service.gd")
const Commentary = preload("res://scripts/ai/commentary_prompt.gd")

var failures: Array[String] = []
var completions: Array[Dictionary] = []
var grounding_findings: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pixel := Controller.new()
	pixel.adapter = Adapter.new()
	pixel.adapter.service = Service.new()
	pixel.adapter.add_child(pixel.adapter.service)
	pixel.add_child(pixel.adapter)
	root.add_child(pixel)
	pixel.request_finished.connect(func(details: Dictionary) -> void: completions.append(details))
	var startup: Error = await pixel.adapter.service.start(45000)
	if startup != OK:
		push_error("COMMENTARY_MODEL_SMOKE_FAILED: startup " + pixel.adapter.service.last_error)
		pixel.free()
		quit(1)
		return
	pixel.begin_run(91, 2026)
	var events := [
		["snake", "stage_start", 0, 10, 0, {}],
		["snake", "collectible_streak", 3, 10, 30, {"count": 3}],
		["snake", "near_completion", 9, 10, 90, {}],
		["maze", "stage_start", 0, 30, 100, {}],
		["maze", "danger_escaped", 2, 30, 120, {"danger": "wall"}],
		["maze", "ghost_defeated", 3, 30, 150, {}],
		["frogger", "crossing_completed", 1, 3, 160, {}],
		["frogger", "danger_escaped", 1, 3, 160, {"danger": "traffic"}],
		["asteroids", "asteroid_streak", 3, 12, 190, {"count": 3}],
		["asteroids", "danger_escaped", 4, 12, 200, {"danger": "asteroid"}],
	]
	var accepted := 0
	for event in events:
		var previous := completions.size()
		if event[1] in ["stage_start", "near_completion"]:
			pixel.checkpoint(event[0], event[1], event[2], event[3], event[4])
		else:
			pixel.observe(event[0], event[1], event[2], event[3], event[4], event[5])
			pixel.tick(12.0)
		var fallback: String = pixel.message
		var deadline := Time.get_ticks_msec() + 10000
		while completions.size() == previous and Time.get_ticks_msec() < deadline:
			await process_frame
		var diagnostics: Dictionary = pixel.diagnostics()
		if completions.size() == previous:
			failures.append("completion timeout " + event[1])
			break
		if diagnostics.source == "llm" and pixel.message != fallback:
			accepted += 1
			var issues := grounding_issues(pixel.message, event[0], event[1])
			if not issues.is_empty():
				grounding_findings.append({"sequence": pixel.journal.sequence, "message": pixel.message, "issues": issues})
		elif diagnostics.source != "fallback" or diagnostics.fallback_reason != "repeated_reply" or pixel.message != fallback:
			failures.append("not accepted: %s / %s" % [event[1], diagnostics.fallback_reason])
		if pixel.adapter.last_prompt_tokens + Commentary.OUTPUT_TOKENS + Commentary.TOKEN_MARGIN > Commentary.CONTEXT_TOKENS:
			failures.append("context overflow " + event[1])
		print("COMMENTARY_SAMPLE: " + JSON.stringify({"event": pixel.journal.latest(),
			"reply": {"emotion": pixel.emotion, "message": pixel.message}, "fallback": fallback,
			"diagnostics": diagnostics, "history_sent": pixel.adapter.last_history_size}))
	var diagnostic_totals: Dictionary = pixel.diagnostics().totals
	print("COMMENTARY_ACCEPTANCE: " + JSON.stringify(diagnostic_totals))
	print("COMMENTARY_GROUNDING_FINDINGS: " + JSON.stringify(grounding_findings))
	if accepted == 0:
		failures.append("no generated replies reached the display")
	if "--strict-grounding" in OS.get_cmdline_user_args() and not grounding_findings.is_empty():
		failures.append("grounding review failed")
	var maximum_context := {"summary": {"run_id": 999999, "counts": {}},
		"current_event": {"sequence": 999999, "stage": "asteroids", "kind": "danger_escaped",
			"progress": 99999, "target": 100000, "score": 1000000000,
			"tags": {"danger": "asteroid", "count": 3600000, "duration_ms": 3600000, "style": "representative", "outcome": "escaped"}},
		"current_emotion": "surprised", "commentary_history": []}
	for kind in Commentary.EVENTS:
		maximum_context.summary.counts[kind] = 100000
	for index in 3:
		maximum_context.commentary_history.append({"event_sequence": index, "stage": "asteroids",
			"kind": "asteroid_streak", "emotion": "excited", "message": "x!".repeat(40)})
	var no_candidates: Array[Dictionary] = []
	var maximum_reply: Dictionary = await pixel.adapter.request(maximum_context, no_candidates, false, 8.0)
	if maximum_reply.is_empty() or pixel.adapter.last_prompt_tokens + Commentary.OUTPUT_TOKENS + Commentary.TOKEN_MARGIN > Commentary.CONTEXT_TOKENS:
		failures.append("maximum context failed bounded generation: " + pixel.adapter.last_failure)
	print("COMMENTARY_MAX_CONTEXT: " + JSON.stringify({"prompt_tokens": pixel.adapter.last_prompt_tokens,
		"history_retained": pixel.adapter.last_history_size, "output_budget": Commentary.OUTPUT_TOKENS}))
	pixel.adapter.shutdown()
	pixel.free()
	if failures.is_empty():
		print("COMMENTARY_MODEL_SMOKE_OK: %d/%d original replies accepted; %d grounding findings" % [accepted, events.size(), grounding_findings.size()])
	else:
		push_error("COMMENTARY_MODEL_SMOKE_FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)


func grounding_issues(message: String, stage: String, kind: String) -> Array[String]:
	var issues: Array[String] = []
	var text := message.to_lower()
	for phrase in ["json", "instruction", "characters", "last run", "previous run", "i changed your", "i gave you", "i collected", "i defeated", "i got out"]:
		if text.contains(phrase):
			issues.append("unsupported claim or prompt echo: " + phrase)
	var stage_terms := {"snake": ["apple"], "maze": ["maze", "ghost", "pellet"],
		"frogger": ["traffic", "frogger"], "asteroids": ["asteroid", "space rock"]}
	for other_stage in stage_terms:
		if other_stage != stage:
			for term in stage_terms[other_stage]:
				if text.contains(term):
					issues.append("review non-current stage reference: " + term)
	if kind == "stage_start":
		for phrase in ["finished", "completed", "almost", "won", "free feeling"]:
			if text.contains(phrase):
				issues.append("stage-start contradiction: " + phrase)
	return issues
