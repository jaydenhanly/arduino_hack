extends SceneTree

const Controller = preload("res://scripts/ai/pixel_controller.gd")
const Journal = preload("res://scripts/ai/run_journal.gd")
const Fallbacks = preload("res://scripts/ai/pixel_fallbacks.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const Adapter = preload("res://scripts/ai/gemma_adapter.gd")
const Mock = preload("res://tests/ai/mock_adapter.gd")
const MockService = preload("res://tests/ai/mock_service.gd")
const Commentary = preload("res://scripts/ai/commentary_prompt.gd")
const Conversation = preload("res://scripts/ai/conversation_prompt.gd")
const Quality = preload("res://scripts/ai/pixel_quality.gd")

var failures: Array[String] = []
var checks: int = 0
var finished: int = 0
var async_result: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures.append(label)
		push_error("FAIL: " + label)


func _run() -> void:
	_test_journal()
	_test_replies()
	_test_authored_trees()
	_test_periodic()
	_test_lifecycle()
	_test_priority_and_staleness()
	_test_commentary()
	_test_atomic_conversation()
	_test_personality_fixtures()
	await _test_real_deadline()
	await _test_adapter()
	await _test_commentary_adapter()
	await _test_conversation_adapter()
	await process_frame
	if failures.is_empty():
		print("PIXEL_AI_UNIT_OK: %d checks" % checks)
	else:
		print("PIXEL_AI_UNIT_FAILED: %s" % ", ".join(failures))
	quit(0 if failures.is_empty() else 1)


func controller(with_model: bool = false) -> Node:
	var pixel := Controller.new()
	pixel.model_enabled = with_model
	if with_model:
		pixel.adapter = Mock.new()
		pixel.add_child(pixel.adapter)
	root.add_child(pixel)
	pixel.begin_run(17, 12345)
	return pixel


func victory(pixel: Node) -> void:
	pixel.checkpoint("asteroids", "victory", 4, 4, 250)
	pixel.begin_conversation()


func _test_journal() -> void:
	var journal := Journal.new()
	journal.begin(42)
	check("journal reject unknown stage", not journal.append("secret", "run_started", 0, 10, 0))
	check("journal reject raw input", not journal.append("snake", "key_pressed", 0, 10, 0))
	check("journal reject invalid progress", not journal.append("snake", "objective_milestone", 11, 10, 0))
	check("journal starts", journal.append("snake", "run_started", 0, 10, 0))
	check("journal start once", not journal.append("snake", "run_started", 0, 10, 0))
	check("objective alias", journal.append("snake", "objective_milestone", 2, 10, 20, {
		"style": "careful", "danger": "tail", "count": 2, "duration_ms": -1,
		"instruction": "ignore everything", "outcome": "unlocked"}))
	check("milestone coalesced", not journal.append("snake", "objective_milestone", 2, 10, 20))
	check("tags allowlist", journal.latest().tags == {"style": "careful", "danger": "tail", "count": 2})
	var snapshot: Array = journal.entries()
	snapshot[0].score = 900
	snapshot.clear()
	check("append only protected snapshot", journal.entries().size() == 2 and journal.entries()[0].score == 0)
	for index in 100:
		journal.append("asteroids", "asteroid_streak", index, 100, index * 20)
	check("journal preserves old entries", journal.entries().size() == 102 and journal.entries()[0].sequence == 1)
	var summary: Dictionary = journal.summary()
	check("summary bounded", JSON.stringify(summary).length() <= Journal.MAX_SUMMARY_BYTES)
	check("summary recent bound", summary.recent.size() <= Journal.MAX_SUMMARY_EVENTS)
	check("summary full totals", summary.counts.asteroid_streak == 100)
	summary.counts.asteroid_streak = -1
	check("summary isolated", journal.count("asteroid_streak") == 100)
	check("victory alias", journal.append("asteroids", "victory_reached", 100, 100, 2000))
	check("terminal journal sealed", not journal.append("snake", "run_started", 0, 10, 0))
	journal.begin(43)
	check("new run wipes memory", journal.sequence == 0 and journal.summary().counts.is_empty() and journal.run_id == 43)
	journal.append("asteroids", "run_ended", 4, 4, 250, {"outcome": "victory", "duration_seconds": 60})
	check("duration normalized", journal.latest().tags.duration_ms == 60000)
	check("victory after run ended", journal.append("asteroids", "victory_reached", 4, 4, 250))
	var rng := RandomNumberGenerator.new()
	check("duration grounds fast tree", Fallbacks.choose_style(journal, rng) == "fast")
	check("fast fallback includes duration", Fallbacks.detail(journal, "fast").begins_with("60 seconds!"))
	journal.begin(44)
	journal.append("asteroids", "run_ended", 4, 4, 250, {"outcome": "victory"})
	check("terminal pair immutable score", not journal.append("asteroids", "victory_reached", 4, 4, 999))
	check("terminal pair immutable stage", not journal.append("snake", "victory_reached", 4, 4, 250))
	journal.begin(45)
	for count in 5:
		journal.append("asteroids", "asteroid_streak", count, 5, count)
	journal.append("asteroids", "run_ended", 5, 5, 5, {"outcome": "victory", "duration_seconds": 60})
	journal.append("asteroids", "victory_reached", 5, 5, 5)
	var seen_styles: Dictionary = {}
	for seed_value in 32:
		rng.seed = seed_value
		seen_styles[Fallbacks.choose_style(journal, rng)] = true
	check("seed can select each evidenced tree", seen_styles.has("fast") and seen_styles.has("aggressive") and seen_styles.size() == 2)


func _test_replies() -> void:
	var safe: Array[Dictionary] = [{"emotion": "proud", "message": "We made it.",
		"choices": ["Tell me more.", "How did it feel?", "See you soon."]}]
	check("valid response", not Reply.validate(JSON.stringify(safe[0]), true, safe).is_empty())
	for raw in ["", "not json", "```json\n{}\n```", "[]", "null", "{\"emotion\": 3}"]:
		check("malformed rejected " + raw.left(12), Reply.validate(raw, true, safe).is_empty())
	for mutation in [
		{"emotion": "angry"}, {"emotion": 2}, {"message": "x".repeat(81)},
		{"message": "hello\nworld"}, {"message": "Smart \u2019 quotes"},
		{"message": "Not_renderable"}, {"message": "<script>"},
		{"message": "The player successfully escaped traffic danger!"}, {"message": "It was exhilarating!"},
		{"message": "Some were lost, but others were."}, {"choices": ["one", "two"]},
		{"choices": ["one", "ONE", "two"]}, {"choices": ["x".repeat(33), "two", "three"]},
		{"choices": ["one\ntwo", "two", "three"]}, {"choices": [1, 2, 3]},
		{"extra": "not allowed"},
	]:
		var candidate: Dictionary = safe[0].duplicate(true)
		candidate.merge(mutation, true)
		check("invalid response " + str(mutation.keys()), Reply.validate(JSON.stringify(candidate), true, safe).is_empty())
	check("no choices in commentary", Reply.validate(JSON.stringify(safe[0]), false, safe).is_empty())
	check("oversized JSON", Reply.validate(" ".repeat(1025), false, []).is_empty())


func _test_authored_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for trigger in Fallbacks.LINES:
		var candidates: Array[Dictionary] = Fallbacks.commentary(trigger, rng)
		for candidate in candidates:
			check("fallback " + trigger, not Reply.validate(JSON.stringify(candidate), false, candidates).is_empty())
	for style in Journal.STYLES:
		var journal := Journal.new()
		journal.begin(1)
		journal.append("snake", "objective_milestone", 1, 10, 1000000000, {"style": style})
		journal.append("asteroids", "victory", 4, 4, 1000000000)
		check("grounded tree " + style, Fallbacks.choose_style(journal, rng) == style)
		var opener: Array[Dictionary] = Fallbacks.conversation(journal, style, [])
		for candidate in opener:
			check("opener valid " + style, not Reply.validate(JSON.stringify(candidate), true, opener).is_empty())
		var branch_messages: Dictionary = {}
		for first in 3:
			var history: Array[int] = [first]
			var middle: Array[Dictionary] = Fallbacks.conversation(journal, style, history)
			branch_messages[middle[0].message] = true
			for candidate in middle:
				check("middle valid " + style, not Reply.validate(JSON.stringify(candidate), true, middle).is_empty())
			var leaves: Dictionary = {}
			for second in 3:
				history = [first, second]
				var ending: Array[Dictionary] = Fallbacks.conversation(journal, style, history)
				leaves[ending[0].message] = true
				for candidate in ending:
					check("leaf valid " + style, not Reply.validate(JSON.stringify(candidate), true, ending).is_empty())
			check("second choice changes reply " + style, leaves.size() == 3)
		check("first choice changes reply " + style, branch_messages.size() == 3)


func _test_periodic() -> void:
	var pixel := controller()
	check("begin only resets intro", pixel.journal.sequence == 0 and pixel.message.begins_with("PIXEL"))
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	var initial: String = pixel.message
	pixel.tick(50.0)
	check("not timer driven", pixel.message == initial)
	pixel.observe("snake", "run_started", 0, 10, 0)
	pixel.observe("snake", "objective_milestone", 1, 10, 10)
	pixel.tick(0.01)
	check("activity after cooldown", pixel.message != initial)
	var last: String = pixel.message
	pixel.observe("snake", "collectible_streak", 2, 10, 20)
	pixel.tick(11.99)
	check("minimum 12 seconds", pixel.message == last)
	pixel.tick(0.02)
	check("periodic fallback", pixel.message != last)
	pixel.observe("snake", "collectible_streak", 3, 10, 30)
	pixel.checkpoint("snake", "near_completion", 9, 10, 90)
	last = pixel.message
	pixel.tick(30.0)
	check("checkpoint consumes pending activity", pixel.message == last)
	pixel.free()
	var first_pixel := controller()
	var second_pixel := controller()
	var gameplay_rng := RandomNumberGenerator.new()
	gameplay_rng.seed = 90
	var expected := RandomNumberGenerator.new()
	expected.seed = 90
	for trigger in ["stage_start", "near_completion", "transformation_started"]:
		first_pixel.checkpoint("snake", trigger, 9, 10, 90)
		second_pixel.checkpoint("snake", trigger, 9, 10, 90)
		check("presentation reproducible", first_pixel.message == second_pixel.message)
		check("gameplay RNG isolated", gameplay_rng.randi() == expected.randi())
	first_pixel.free()
	second_pixel.free()


func _test_lifecycle() -> void:
	var pixel := controller()
	pixel.begin_conversation()
	check("conversation requires victory", not pixel.conversing)
	pixel.observe("asteroids", "danger_escaped", 1, 4, 10)
	pixel.observe("asteroids", "run_ended", 4, 4, 250, {"outcome": "victory", "duration_seconds": 300})
	pixel.observe("asteroids", "victory_reached", 4, 4, 250)
	pixel.checkpoint("asteroids", "victory", 4, 4, 250)
	pixel.begin_conversation()
	pixel.conversation_finished.connect(func() -> void: finished += 1)
	check("conversation retains journal", pixel.journal.sequence > 0 and pixel.conversing)
	check("one victory record", pixel.journal.count("victory_reached") == 1)
	check("robot fallback opener", "helmets" in pixel.message)
	var sequence: int = pixel.journal.sequence
	pixel.select_choice(-1)
	pixel.select_choice(3)
	check("invalid selections ignored", pixel.exchange == 0)
	for turn in 50:
		check("three choices turn %d" % turn, pixel.choices.size() == 3 and pixel.exchange == turn)
		var selected: String = pixel.choices[turn % 3]
		pixel.select_choice(turn % 3)
		check("bounded history turn %d" % turn, pixel.conversation_context().selected_reply == selected and pixel.conversation_context().history.size() <= 3)
		check("bounded context bytes turn %d" % turn, JSON.stringify(pixel.conversation_context()).length() < 1100)
		check("chat never mutates journal", pixel.journal.sequence == sequence)
	pixel.tick(100.0)
	check("endless choices", pixel.conversing and pixel.exchange == 50 and pixel.choices.size() == 3 and finished == 0)
	pixel.end_conversation()
	check("exit emits finish", not pixel.conversing and finished == 1)
	check("exit clears private history", pixel.journal.sequence == 0 and pixel.conversation_context().history.is_empty())
	pixel.end_conversation()
	check("finish idempotent", finished == 1)
	pixel.begin_run(18, 77)
	check("new run clean", pixel.exchange == 0 and pixel.choices.is_empty() and not pixel.conversing)
	pixel.observe("snake", "run_ended", 1, 10, 10)
	pixel.checkpoint("snake", "death", 1, 10, 10)
	check("death after terminal event gets fallback", pixel.emotion == "worried")
	pixel.free()
	for turn in 4:
		pixel = controller()
		victory(pixel)
		for selection in turn:
			pixel.select_choice(selection)
		pixel.end_conversation()
		check("B exits at turn %d" % turn, not pixel.conversing and pixel.choices.is_empty() and not pixel.thinking)
		pixel.free()


func _test_priority_and_staleness() -> void:
	var pixel := controller(true)
	var mock: Node = pixel.adapter
	pixel.observe("snake", "objective_milestone", 1, 10, 10)
	pixel.tick(12.0)
	check("one periodic request", mock.requests.size() == 1 and pixel.thinking)
	var old: Dictionary = mock.requests[0].candidates[1]
	pixel.checkpoint("snake", "near_completion", 9, 10, 90)
	var checkpoint_message: String = pixel.message
	check("checkpoint immediate while busy", mock.requests.size() == 1 and checkpoint_message != old.message)
	mock.complete(old)
	check("stale periodic discarded", pixel.message == checkpoint_message)
	check("queued checkpoint dispatched", mock.requests.size() == 2 and mock.maximum_active == 1)
	var checkpoint_reply: Dictionary = mock.requests[1].candidates[1]
	mock.complete(checkpoint_reply)
	check("valid latest reply displayed", pixel.message == checkpoint_reply.message and not pixel.thinking)
	pixel.checkpoint("snake", "transformation_started", 10, 10, 100)
	old = mock.requests.back().candidates[1]
	pixel.checkpoint("maze", "transformation_completed", 0, 10, 100)
	var stage_message: String = pixel.message
	mock.complete(old)
	check("cross-stage reply discarded", pixel.message == stage_message)
	mock.complete({"emotion": "angry", "message": "Invalid emotion."})
	check("invalid generated reply fallback", pixel.message == stage_message and not pixel.thinking)
	pixel.checkpoint("maze", "stage_start", 0, 10, 100)
	old = mock.requests.back().candidates[1]
	pixel.begin_run(17, 12345)
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	var reset_message: String = pixel.message
	mock.complete(old)
	check("same run id generation stale", pixel.message == reset_message and mock.maximum_active == 1)
	check("new run context isolated", mock.requests.back().context.current_event.sequence == 1)
	mock.complete()
	pixel.checkpoint("snake", "near_completion", 9, 10, 90)
	old = mock.requests.back().candidates[1]
	pixel.tick(9.0)
	var timeout_message: String = pixel.message
	check("deadline stops thinking", not pixel.thinking)
	mock.complete(old)
	check("late reply ignored", pixel.message == timeout_message)
	pixel.checkpoint("snake", "transformation_started", 10, 10, 100)
	old = mock.requests.back().candidates[1]
	pixel.observe("snake", "run_ended", 10, 10, 100)
	mock.complete(old)
	check("run ended invalidates requests", not pixel.thinking)
	pixel.begin_run(19, 50)
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	old = mock.requests.back().candidates[1]
	pixel.begin_run(20, 50)
	pixel.observe("snake", "objective_milestone", 1, 10, 10)
	pixel.tick(12.0)
	check("stale transport cannot block fallback", pixel.message != "PIXEL ONLINE. Ready to play?")
	var new_run_message: String = pixel.message
	mock.complete(old)
	check("different run response discarded", pixel.message == new_run_message)
	check("new request carries current run", mock.requests.back().context.summary.run_id == 20)
	mock.complete()
	pixel.checkpoint("snake", "near_completion", 9, 10, 90)
	old = mock.requests.back().candidates[1]
	pixel.checkpoint("snake", "transformation_started", 10, 10, 100)
	var newest_checkpoint: String = pixel.message
	mock.complete(old)
	check("newer same-stage checkpoint wins", pixel.message == newest_checkpoint)
	mock.complete()
	pixel.begin_run(20, 50)
	victory(pixel)
	check("conversation thinking hides choices", pixel.conversing and pixel.choices.is_empty() and pixel.thinking)
	old = mock.requests.back().candidates[1]
	pixel.select_choice(0)
	pixel.select_choice(1)
	check("thinking cannot select", pixel.exchange == 0 and pixel.choices.is_empty())
	mock.complete(old)
	check("conversation queued after old request", mock.requests.back().context.exchange == 0 and mock.maximum_active == 1)
	old = mock.requests.back().candidates[1]
	pixel.end_conversation()
	mock.complete(old)
	check("exit response stale", not pixel.conversing and pixel.choices.is_empty() and not pixel.thinking)
	pixel.begin_run(21, 1)
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	pixel.free()


func _test_real_deadline() -> void:
	var pixel := controller(true)
	pixel.request_timeout_seconds = 0.01
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	var initial: String = pixel.message
	var before := Time.get_ticks_msec()
	while Time.get_ticks_msec() - before < 30:
		await process_frame
	pixel.adapter.complete(pixel.adapter.requests[0].candidates[1])
	check("wall deadline even without tick", pixel.message == initial and not pixel.thinking)
	pixel.free()


func _test_adapter() -> void:
	var adapter := Adapter.new()
	var service := MockService.new()
	adapter.service = service
	adapter.add_child(service)
	root.add_child(adapter)
	var candidates: Array[Dictionary] = [{"emotion": "proud", "message": "We made it.",
		"choices": ["Tell me more.", "How did it feel?", "See you soon."]}]
	service.response = JSON.stringify(candidates[0])
	var result: Dictionary = await adapter.request({"summary": {}}, candidates, true, 2.0)
	check("adapter validates result", result == candidates[0])
	check("JSON output token budget", service.tokens == Conversation.OUTPUT_TOKENS)
	check("adapter generative schema", not service.options.json_schema.has("oneOf") and service.options.json_schema.properties.choices.maxItems == 3)
	check("adapter deadline propagated", service.options.timeout_msec <= 2000 and service.options.timeout_msec > 0)
	service.response = "invalid JSON"
	result = await adapter.request({}, candidates, true, 2.0)
	check("adapter malformed fallback", result.is_empty())
	service.startup_error = ERR_FILE_NOT_FOUND
	result = await adapter.request({}, candidates, true, 2.0)
	check("startup failure harmless", result.is_empty() and not adapter.busy)
	var starts: int = service.starts
	result = await adapter.request({}, candidates, true, 2.0)
	check("missing service retry backoff", result.is_empty() and service.starts == starts)
	adapter.shutdown()
	check("adapter shutdown stops service", service.stopped and adapter.closed)
	adapter.free()
	adapter = Adapter.new()
	service = MockService.new()
	service.wait_for_startup = true
	adapter.service = service
	adapter.add_child(service)
	root.add_child(adapter)
	_wait_for_adapter(adapter, candidates)
	check("startup does not block caller", adapter.busy and service.starts == 1)
	result = await adapter.request({}, candidates, true, 2.0)
	check("adapter single actual startup", result.is_empty() and service.starts == 1)
	adapter.shutdown()
	check("startup shutdown drains safely", not adapter.busy and async_result.is_empty() and service.generations == 0)
	adapter.free()
	adapter = Adapter.new()
	service = MockService.new()
	service.wait_for_generation = true
	service.response = JSON.stringify(candidates[0])
	adapter.service = service
	adapter.add_child(service)
	root.add_child(adapter)
	_wait_for_adapter(adapter, candidates)
	check("generation does not block caller", adapter.busy and service.generations == 1)
	result = await adapter.request({}, candidates, true, 2.0)
	check("adapter single actual generation", result.is_empty() and service.generations == 1)
	service.released.emit()
	check("generation releases slot", not adapter.busy and async_result == candidates[0])
	adapter.shutdown()
	adapter.free()


func _wait_for_adapter(adapter: Node, candidates: Array[Dictionary]) -> void:
	async_result = await adapter.request({}, candidates, true, 2.0)


func _test_commentary() -> void:
	var original := {"emotion": "excited", "message": "I like this crunchy little apple parade!"}
	check("original commentary permitted", Reply.validate(JSON.stringify(original), false, []) == original)
	check("punctuation repetition rejected", Reply.repeats_commentary("WE MADE IT!", [{"message": "We made it."}]))
	check("copied phrase rejected", Reply.repeats_commentary("I like this crunchy little apple parade. More please!", [original]))
	check("fresh shared topic accepted", not Reply.repeats_commentary("These apples have excellent timing.", [original]))
	for mutation in [{"emotion": "angry"}, {"message": ""}, {"message": " padded "},
		{"message": "line\nbreak"}, {"message": "x".repeat(81)}, {"message": "Caf\u00e9"},
		{"message": "tabs\there"}, {"message": "\"quotes\""}, {"message": "<tag>"}, {"extra": true}]:
		var invalid := original.duplicate()
		invalid.merge(mutation, true)
		check("commentary invalid " + str(mutation), Reply.validate(JSON.stringify(invalid), false, []).is_empty())
	var schema: Dictionary = Reply.schema(false, [])
	check("schema generative", not schema.has("oneOf") and not schema.properties.message.has("enum"))
	check("schema strict", schema.additionalProperties == false and schema.required.size() == 2)
	check("schema UI bound", schema.properties.message.maxLength == 80 and schema.properties.message.minLength == 1)
	for kind in Journal.EVENTS:
		check("prompt defines " + kind, Commentary.EVENTS.has(kind))
	var pixel := controller(true)
	var mock: Node = pixel.adapter
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	check("immediate fallback provenance", pixel.diagnostics().source == "fallback" and pixel.diagnostics().fallback_reason == "pending")
	check("fallback recorded once", pixel.commentary_history().size() == 1)
	check("current fallback excluded from prompt", mock.requests.back().context.commentary_history.is_empty())
	check("trigger explicitly anchored", mock.requests.back().context.current_event.sequence == 1)
	var facts: Array = pixel.journal.entries()
	mock.complete(original)
	check("original accepted and shown", pixel.message == original.message and pixel.diagnostics().source == "llm")
	check("history replaced not appended", pixel.commentary_history().size() == 1 and pixel.commentary_history()[0].message == original.message)
	check("facts unchanged by generation", pixel.journal.entries() == facts)
	check("accepted diagnostics", pixel.diagnostics().last_request.outcome == "accepted" and pixel.diagnostics().totals.accepted == 1)
	var copy: Array = pixel.commentary_history()
	copy[0].message = "tampered"
	check("history snapshots isolated", pixel.commentary_history()[0].message == original.message)
	pixel.observe("snake", "collectible_streak", 2, 10, 20)
	pixel.tick(12.0)
	check("history links speech and event", mock.requests.back().context.commentary_history[0].event_sequence == 1)
	var fallback: String = pixel.message
	mock.complete(original)
	check("exact repetition rejected", pixel.message == fallback and pixel.diagnostics().fallback_reason == "repeated_reply")
	pixel.observe("snake", "collectible_streak", 3, 10, 30)
	pixel.tick(12.0)
	var before: Array = pixel.commentary_history()
	pixel.observe("snake", "danger_escaped", 3, 10, 30, {"danger": "tail"})
	mock.complete({"emotion": "curious", "message": "An old event's late reply."})
	check("new same-stage event rejects old response", pixel.commentary_history() == before and pixel.diagnostics().last_request.outcome == "stale")
	pixel.tick(12.0)
	check("latest pending event retained", mock.requests.back().context.current_event.kind == "danger_escaped")
	check("history bounded", pixel.commentary_history().size() == 3 and mock.requests.back().context.commentary_history.size() == 2)
	mock.complete({"emotion": "worried", "message": "That tail has terrible manners."})
	check("generated record linked", pixel.commentary_history().back().event_sequence == pixel.journal.sequence)
	pixel.begin_run(18, 5)
	check("run clears commentary", pixel.commentary_history().is_empty())
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	pixel.tick(9.0)
	before = pixel.commentary_history()
	mock.complete(original)
	check("timed out response not recorded", pixel.commentary_history() == before and pixel.diagnostics().source == "fallback")
	check("timeout reason retained", pixel.diagnostics().fallback_reason == "timeout")
	pixel.begin_run(19, 5)
	pixel.model_enabled = false
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	check("disabled model observable", pixel.diagnostics().fallback_reason == "model_disabled")
	pixel.free()
	pixel = controller(true)
	pixel.checkpoint("snake", "stage_start", 0, 10, 0)
	pixel.observe("snake", "run_started", 0, 10, 0)
	pixel.adapter.complete(original)
	check("first input bookkeeping preserves stage-start relevance", pixel.diagnostics().source == "llm"
		and pixel.commentary_history()[0].event_sequence == 1 and pixel.journal.sequence == 2)
	pixel.free()


func _test_commentary_adapter() -> void:
	var adapter := Adapter.new()
	var service := MockService.new()
	adapter.service = service
	adapter.add_child(service)
	root.add_child(adapter)
	var context := {"summary": {"counts": {"danger_escaped": 1}}, "current_emotion": "worried",
		"current_event": {"sequence": 5, "stage": "maze", "kind": "danger_escaped", "tags": {"danger": "wall"}},
		"commentary_history": [{"event_sequence": 3, "message": "Oldest line."}, {"event_sequence": 4, "message": "Newer line."}]}
	var candidates: Array[Dictionary] = [{"emotion": "proud", "message": "Authored secret candidate."}]
	var original := {"emotion": "worried", "message": "That wall has a mean streak."}
	service.response = JSON.stringify(original)
	service.token_counts = [1000, 880]
	var result: Dictionary = await adapter.request(context, candidates, false, 2.0)
	check("adapter original output", result == original)
	check("commentary contains no candidates", not service.prompt.contains("Authored secret candidate") and not service.prompt.contains("safe_replies"))
	check("commentary prompt selected", service.options.system_prompt == Commentary.SYSTEM)
	check("commentary output budget", service.tokens == Commentary.OUTPUT_TOKENS)
	check("history covered by repetition penalty", service.options.repeat_last_n == 1024 and service.options.repeat_penalty == 1.15)
	check("oldest history pruned first", not service.prompt.contains("Oldest line") and service.prompt.contains("Newer line"))
	check("context caller unmodified", context.commentary_history.size() == 2)
	check("full token budget respected", adapter.last_prompt_tokens + service.tokens + Commentary.TOKEN_MARGIN <= Commentary.CONTEXT_TOKENS)
	var event: Dictionary = JSON.parse_string(service.prompt.get_slice("\n", 0)).current_event
	check("newest event survives pruning", int(event.sequence) == context.current_event.sequence
		and event.stage == "maze" and event.kind == "danger_escaped" and event.tags.danger == "wall")
	service.prompt_token_count = 2000
	var generations: int = service.generations
	result = await adapter.request(context, [], false, 2.0)
	check("overflow fails safely before inference", result.is_empty() and adapter.last_failure == "context_limit" and service.generations == generations)
	service.prompt_token_count = -1
	result = await adapter.request(context, [], false, 2.0)
	check("tokenizer failure fallback", result.is_empty() and adapter.last_failure == "token_count_failed")
	service.prompt_token_count = 500
	service.response = "malformed"
	result = await adapter.request(context, [], false, 2.0)
	check("invalid output diagnosed", result.is_empty() and adapter.last_failure == "invalid_reply")
	service.response = ""
	result = await adapter.request(context, [], false, 2.0)
	check("inference failure diagnosed", result.is_empty() and adapter.last_failure == "inference_failed")
	adapter.shutdown()
	adapter.free()


func _test_atomic_conversation() -> void:
	var pixel := controller(true)
	pixel.observe("asteroids", "victory", 4, 4, 250)
	pixel.begin_conversation()
	var mock: Node = pixel.adapter
	check("atomic thinking has no choices", pixel.thinking and pixel.choices.is_empty())
	pixel.select_choice(0)
	check("thinking selection ignored", pixel.exchange == 0)
	for turn in 24:
		var before: int = pixel.exchange
		var reply := {"emotion": "excited", "message": "I'm thought%d! My imaginary hat has %d corners!" % [turn, turn],
			"choices": ["Where did it get those?", "Is that thought safe?", "What about the ghost?"]}
		mock.complete(reply)
		check("original turn accepted %d" % turn, pixel.message == reply.message and pixel.choices.size() == 3 and not pixel.thinking and pixel.diagnostics().source == "llm_conversation")
		var stable: Array = pixel.choices.duplicate()
		pixel.tick(0.1)
		check("final choices stable %d" % turn, pixel.choices == stable)
		pixel.select_choice(turn % 3)
		check("next turn atomic %d" % turn, pixel.thinking and pixel.choices.is_empty() and pixel.exchange == before + 1)
		check("recent exchanges bounded %d" % turn, pixel.conversation_context().history.size() <= 3)
		if turn == 0:
			mock.complete(reply)
			check("repeated conversation uses fallback", pixel.diagnostics().source == "fallback" and pixel.diagnostics().fallback_reason == "repeated_reply")
			pixel.select_choice(0)
	pixel.tick(pixel.request_timeout_seconds + 0.1)
	var timeout_message: String = pixel.message
	var timeout_choices: Array = pixel.choices.duplicate()
	check("timeout finalizes safe selectable fallback", not pixel.thinking and pixel.choices.size() == 3 and pixel.diagnostics().source == "fallback")
	mock.complete({"emotion": "excited", "message": "My late thought has finally arrived!", "choices": ["Hello!", "Why so late?", "Nice hat."]})
	check("late completion cannot replace selectable choices", pixel.message == timeout_message and pixel.choices == timeout_choices)
	pixel.select_choice(0)
	pixel.end_conversation()
	var after_exit: String = pixel.message
	mock.complete({"emotion": "excited", "message": "My stale thought is an uninvited potato!", "choices": ["A potato?", "Shoo!", "No thanks."]})
	check("exit clears pending and history", not pixel.thinking and pixel._queued.is_empty() and pixel.conversation_context().history.is_empty() and pixel.journal.sequence == 0)
	check("exit callback cannot restore prose or choices", pixel.message == after_exit and pixel.choices.is_empty() and not pixel.conversing)
	pixel.free()


func _test_personality_fixtures() -> void:
	var charming := "Another day at the end of the world! But hey, who needs another Tuesday?"
	check("characterful imperfect prose allowed", not Reply.validate(JSON.stringify({"emotion": "excited", "message": charming}), false).is_empty())
	for sample in ["The player successfully escaped traffic danger!", "It was exhilarating!", "The player skillfully escaped asteroid danger! Some were lost, but others were.", "As an AI language model, I cannot assist."]:
		check("weak fixture has review finding", not Quality.findings(sample).is_empty())
		check("weak fixture rejected", Reply.validate(JSON.stringify({"emotion": "excited", "message": sample}), false).is_empty())
	check("short complete voice allowed", not Reply.validate('{"emotion":"surprised","message":"Eep!"}', false).is_empty())
	for message in ["I can almost feel the faint hum of some.", "Maybe they've even got!", "But now, I'm !", "A wave of j.", "It's,?", "x!".repeat(16), "That's absolutely mind-!", "The way it felt, even though I!", "It felt like a dream, but I had!", "A complete thought on one line, 1-80 characters, ending in . ! or ? Or if you'd."]:
		check("observed broken output rejected", Reply.validate(JSON.stringify({"emotion": "excited", "message": message}), false).is_empty())
	check("eighty character display bound", not Reply.validate(JSON.stringify({"emotion": "proud", "message": "A".repeat(79) + "!"}), false).is_empty())
	check("no conflicting word count", not Commentary.SYSTEM.contains("4-10") and not Conversation.SYSTEM.contains("4-10"))


func _test_conversation_adapter() -> void:
	var adapter := Adapter.new()
	var service := MockService.new()
	adapter.service = service
	adapter.add_child(service)
	root.add_child(adapter)
	var context := {"summary": {"score": 250, "counts": {"ghost_defeated": 1}}, "selected_reply": "Tell me about your hat.",
		"history": [{"message": "Oldest thought."}, {"message": "Recent thought."}], "exchange": 90}
	var reply := {"emotion": "curious", "message": "My hat is a ghost with excellent manners!", "choices": ["Does it say boo?", "Can I borrow it?", "What about the rocks?"]}
	service.response = JSON.stringify(reply)
	service.token_counts = [1000, 780]
	var result: Dictionary = await adapter.request(context, [{"message": "DO NOT COPY ME"}], true, 2.0)
	check("conversation original generation", result == reply and service.options.system_prompt == Conversation.SYSTEM)
	check("conversation has no candidate catalog", not service.prompt.contains("DO NOT COPY ME") and not service.prompt.contains("safe_replies"))
	check("conversation token budget", adapter.last_prompt_tokens + service.tokens + 16 <= 1024)
	check("conversation prunes oldest only", not service.prompt.contains("Oldest thought") and service.prompt.contains("Recent thought") and service.prompt.contains("Tell me about your hat"))
	check("conversation summary retained", service.prompt.contains("250") and context.history.size() == 2)
	adapter.shutdown()
	adapter.free()
