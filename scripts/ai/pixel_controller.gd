extends Node

signal changed
signal conversation_finished
signal request_finished(details: Dictionary)

const Journal = preload("res://scripts/ai/run_journal.gd")
const Fallbacks = preload("res://scripts/ai/pixel_fallbacks.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const Adapter = preload("res://scripts/ai/gemma_adapter.gd")
const PERIODIC_COOLDOWN := 12.0
const HISTORY_LIMIT := 3

var emotion: String = "curious"
var message: String = "PIXEL ONLINE. Ready to play?"
var thinking: bool = false
var choices: Array[String] = []
var conversing: bool = false
var exchange: int = 0
var model_enabled: bool = true
var request_timeout_seconds: float = 8.0
var farewell_seconds: float = 1.5
var journal: RefCounted = Journal.new()
var adapter: Node

var _rng := RandomNumberGenerator.new()
var _generation: int = 0
var _run_id: int = 0
var _stage: String = ""
var _active: bool = false
var _victory: bool = false
var _clock: float = 0.0
var _last_comment: float = 0.0
var _pending_activity: Dictionary = {}
var _queued: Dictionary = {}
var _in_flight: bool = false
var _request_clock_deadline: float = 0.0
var _history: Array[int] = []
var _choice_history: Array[String] = []
var _style: String = "representative"
var _farewell_remaining: float = 0.0
var _commentary_history: Array[Dictionary] = []
var _message_source: String = "authored"
var _message_sequence: int = 0
var _latest_commentary_sequence: int = 0
var _fallback_reason: String = ""
var _last_request: Dictionary = {}
var _request_totals := {"requested": 0, "accepted": 0, "stale": 0, "failed": 0}


func begin_run(run_id: int, seed: int) -> void:
	reset()
	_run_id = run_id
	_rng.seed = seed ^ 0x504958454C
	journal.begin(run_id)
	_active = true
	changed.emit()


func observe(stage: String, kind: String, progress: int, target: int, score: int,
		tags: Dictionary = {}) -> void:
	kind = Journal.normalize(kind)
	var victory_after_end: bool = kind == "victory" and journal.latest().get("kind") == "run_ended"
	if (not _active and not victory_after_end) or not journal.append(stage, kind, progress, target, score, tags):
		return
	_change_stage(stage)
	if kind in ["run_ended", "victory"]:
		_active = false
		_victory = kind == "victory"
		_invalidate()
		_pending_activity = {}
		changed.emit()
	elif kind in Journal.ACTIVITY:
		_pending_activity = journal.latest()
		_latest_commentary_sequence = journal.sequence


func checkpoint(stage: String, kind: String, progress: int, target: int, score: int) -> void:
	kind = Journal.normalize(kind)
	if kind not in Journal.CHECKPOINTS or stage not in Journal.STAGES or conversing:
		return
	var ended_checkpoint: bool = journal.count("run_ended") > 0 and kind in ["death", "run_ended"]
	if not _active and not (_victory and kind == "victory") and not ended_checkpoint:
		return
	if not journal.active:
		var last: Dictionary = journal.latest()
		if last.get("stage") != stage or last.get("progress") != progress or last.get("target") != target or last.get("score") != score:
			return
	var event_kind := "run_ended" if kind == "death" else kind
	if journal.active and not journal.append(stage, event_kind, progress, target, score):
		return
	_change_stage(stage)
	_invalidate()
	_pending_activity = {}
	if kind in ["death", "run_ended", "victory"]:
		_active = false
		_victory = kind == "victory"
	var candidates := Fallbacks.commentary(kind, _rng)
	_comment(candidates, journal.latest(), kind not in ["death", "run_ended"])


func begin_conversation() -> void:
	if not _victory or conversing:
		return
	_invalidate()
	conversing = true
	exchange = 0
	_history.clear()
	_choice_history.clear()
	_style = Fallbacks.choose_style(journal, _rng)
	_conversation_turn()


func select_choice(index: int) -> void:
	if not conversing or exchange >= 3 or choices.size() != 3 or index < 0 or index >= 3:
		return
	_choice_history.append(choices[index])
	_history.append(index)
	exchange += 1
	_invalidate()
	if exchange == 3:
		_show(Fallbacks.farewell(index))
		_farewell_remaining = maxf(0.01, farewell_seconds)
	else:
		_conversation_turn()


func end_conversation() -> void:
	var was_conversing := conversing
	_invalidate()
	conversing = false
	choices.clear()
	_history.clear()
	_choice_history.clear()
	_farewell_remaining = 0.0
	_victory = false
	_active = false
	journal.clear()
	_commentary_history.clear()
	changed.emit()
	if was_conversing:
		conversation_finished.emit()


func reset() -> void:
	_invalidate()
	journal.clear()
	_commentary_history.clear()
	_active = false
	_victory = false
	_run_id = 0
	_latest_commentary_sequence = 0
	_stage = ""
	_clock = 0.0
	_last_comment = 0.0
	_pending_activity = {}
	conversing = false
	exchange = 0
	_history.clear()
	_choice_history.clear()
	_farewell_remaining = 0.0
	_show({"emotion": "curious", "message": "PIXEL ONLINE. Ready to play?"})


func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_clock += delta
	if thinking and not model_enabled:
		_fallback_reason = "model_disabled"
		_invalidate()
		changed.emit()
	if conversing and exchange == 3:
		_farewell_remaining -= delta
		if _farewell_remaining <= 0.0:
			end_conversation()
		return
	if thinking and _clock >= _request_clock_deadline:
		_fallback_reason = "timeout"
		_invalidate()
		changed.emit()
	if _active and not _pending_activity.is_empty() and _queued.is_empty() and not thinking:
		if _clock - _last_comment >= PERIODIC_COOLDOWN:
			var event := _pending_activity
			_pending_activity = {}
			var candidates := Fallbacks.commentary(event.kind, _rng)
			_comment(candidates, event)
	_dispatch()


func conversation_context() -> Dictionary:
	return {"summary": journal.summary(), "emotion": emotion,
		"prior_choices": _choice_history.duplicate(), "exchange": exchange}


func commentary_history() -> Array[Dictionary]:
	return _commentary_history.duplicate(true)


func commentary_context(event: Dictionary) -> Dictionary:
	var recent: Array[Dictionary] = []
	for record in _commentary_history:
		if record.event_sequence != event.sequence:
			recent.append(record.duplicate(true))
	var current := event.duplicate(true)
	current.erase("run_id")
	return {"summary": {"run_id": _run_id, "counts": journal.summary().counts},
		"current_event": current, "current_emotion": emotion, "commentary_history": recent}


func diagnostics() -> Dictionary:
	return {"source": _message_source, "event_sequence": _message_sequence,
		"fallback_reason": _fallback_reason, "last_request": _last_request.duplicate(true),
		"totals": _request_totals.duplicate(), "thinking": thinking}


func _record_comment(event: Dictionary, reply: Dictionary) -> void:
	var record := {"event_sequence": event.sequence, "stage": event.stage, "kind": event.kind,
		"emotion": reply.emotion, "message": reply.message}
	for index in _commentary_history.size():
		if _commentary_history[index].event_sequence == event.sequence:
			_commentary_history[index] = record
			return
	_commentary_history.append(record)
	while _commentary_history.size() > HISTORY_LIMIT:
		_commentary_history.pop_front()


func _comment(candidates: Array[Dictionary], event: Dictionary, infer: bool = true) -> void:
	_invalidate()
	_latest_commentary_sequence = event.sequence
	_last_comment = _clock
	_record_comment(event, candidates[0])
	_show(candidates[0], "fallback", event.sequence,
		"pending" if model_enabled and infer else ("model_disabled" if not model_enabled else "authored_only"))
	if infer:
		_enqueue(candidates, false, event)


func _change_stage(stage: String) -> void:
	if stage != _stage:
		_stage = stage
		_pending_activity = {}
		_invalidate()
		changed.emit()


func _conversation_turn() -> void:
	var candidates := Fallbacks.conversation(journal, _style, _history)
	_show(candidates[0])
	_enqueue(candidates, true)


func _show(reply: Dictionary, source: String = "authored", sequence: int = 0, reason: String = "") -> void:
	_message_source = source
	_message_sequence = sequence
	_fallback_reason = reason
	emotion = reply.emotion
	message = reply.message
	choices.assign(reply.get("choices", []))
	changed.emit()


func _invalidate() -> void:
	_generation += 1
	_queued.clear()
	thinking = false


func _enqueue(candidates: Array[Dictionary], conversation: bool, event: Dictionary = {}) -> void:
	if not model_enabled:
		return
	var context := conversation_context() if conversation else commentary_context(event)
	_queued = {"generation": _generation, "run_id": _run_id, "stage": _stage,
		"sequence": journal.sequence if conversation else event.sequence,
		"event": event.duplicate(true), "context": context, "candidates": candidates,
		"conversation": conversation, "deadline": Time.get_ticks_msec() + int(request_timeout_seconds * 1000.0)}
	thinking = true
	_request_clock_deadline = _clock + request_timeout_seconds
	changed.emit()
	_dispatch()


func _dispatch() -> void:
	if _in_flight or _queued.is_empty() or not is_inside_tree():
		return
	if not model_enabled:
		_invalidate()
		changed.emit()
		return
	var request: Dictionary = _queued
	_queued = {}
	if adapter == null:
		adapter = Adapter.new()
		add_child(adapter)
	var remaining := float(int(request.deadline) - Time.get_ticks_msec()) / 1000.0
	if remaining <= 0.0:
		thinking = false
		_fallback_reason = "timeout"
		changed.emit()
		return
	_in_flight = true
	_request_totals.requested += 1
	var started := Time.get_ticks_msec()
	var result: Dictionary = await adapter.request(request.context, request.candidates,
		request.conversation, remaining)
	_in_flight = false
	var current: bool = int(request.generation) == _generation and int(request.run_id) == _run_id and request.stage == _stage
	var reason := "stale"
	if current:
		thinking = false
		if Time.get_ticks_msec() >= int(request.deadline) or _clock >= _request_clock_deadline:
			reason = "timeout"
		elif request.conversation or int(request.sequence) == _latest_commentary_sequence:
			var validated := Reply.validate(JSON.stringify(result), request.conversation, request.candidates)
			reason = "invalid_reply"
			if validated.is_empty() and adapter.get("last_failure") is String and not adapter.last_failure.is_empty():
				reason = adapter.last_failure
			elif not validated.is_empty():
				reason = "accepted"
				if not request.conversation and Reply.repeats_commentary(validated.message, _commentary_history):
					reason = "repeated_reply"
				if reason == "accepted":
					if not request.conversation:
						_record_comment(request.event, validated)
					_show(validated, "llm_selected" if request.conversation else "llm", request.sequence)
		if reason != "accepted" and not request.conversation:
			_fallback_reason = reason
		changed.emit()
	_request_totals["accepted" if reason == "accepted" else ("stale" if reason == "stale" else "failed")] += 1
	_last_request = {"run_id": request.run_id, "event_sequence": request.sequence,
		"conversation": request.conversation, "outcome": reason,
		"latency_ms": Time.get_ticks_msec() - started,
		"prompt_tokens": adapter.get("last_prompt_tokens")}
	request_finished.emit(_last_request.duplicate(true))
	_dispatch()


func _exit_tree() -> void:
	_invalidate()
	if adapter != null and adapter.has_method("shutdown"):
		adapter.shutdown()
