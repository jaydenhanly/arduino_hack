extends Node

const Service = preload("res://scripts/llm/llm_service.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const Commentary = preload("res://scripts/ai/commentary_prompt.gd")
const OUTPUT_TOKENS := 320
const SYSTEM_PROMPT := "You are Pixel. Choose one supplied safe reply for this run. Copy that JSON object exactly. No extra text."

var service: Node
var busy: bool = false
var closed: bool = false
var retry_after_msec: int = 0
var failure_backoff_msec: int = 30000
var last_failure: String = ""
var last_prompt_tokens: int = 0
var last_history_size: int = 0


func request(context: Dictionary, candidates: Array[Dictionary], conversation: bool,
		timeout_seconds: float) -> Dictionary:
	if busy or closed or not is_inside_tree() or Time.get_ticks_msec() < retry_after_msec:
		last_failure = "unavailable" if closed or busy else "backoff"
		return {}
	last_failure = ""
	last_prompt_tokens = 0
	busy = true
	if service == null:
		service = Service.new()
		add_child(service)
	var deadline := Time.get_ticks_msec() + int(maxf(0.01, timeout_seconds) * 1000.0)
	var startup: Error = await service.start(maxi(1, deadline - Time.get_ticks_msec()))
	if closed or startup != OK or Time.get_ticks_msec() >= deadline:
		last_failure = "startup_failed" if startup != OK else "timeout"
		busy = false
		retry_after_msec = Time.get_ticks_msec() + failure_backoff_msec
		return {}
	var input := context.duplicate(true)
	var prompt := JSON.stringify({"context": input, "safe_replies": candidates}) if conversation else Commentary.render(input)
	if not conversation:
		while true:
			last_prompt_tokens = await service.count_prompt_tokens(prompt, Commentary.SYSTEM,
				maxi(1, deadline - Time.get_ticks_msec()))
			if closed or Time.get_ticks_msec() >= deadline or last_prompt_tokens < 0:
				last_failure = "timeout" if Time.get_ticks_msec() >= deadline else "token_count_failed"
				busy = false
				return {}
			if last_prompt_tokens + Commentary.OUTPUT_TOKENS + Commentary.TOKEN_MARGIN <= Commentary.CONTEXT_TOKENS:
				break
			if not input.get("commentary_history", []).is_empty():
				input.commentary_history.pop_front()
			elif not input.get("summary", {}).is_empty():
				input.summary = {}
			else:
				last_failure = "context_limit"
				busy = false
				return {}
			prompt = Commentary.render(input)
	last_history_size = input.get("commentary_history", []).size()
	var options := {
		"system_prompt": SYSTEM_PROMPT if conversation else Commentary.SYSTEM,
		"json_schema": Reply.schema(conversation, candidates),
		"timeout_msec": maxi(1, deadline - Time.get_ticks_msec()),
	}
	if not conversation:
		options.merge({"repeat_last_n": Commentary.CONTEXT_TOKENS, "repeat_penalty": 1.15})
	var raw: String = await service.generate(prompt, OUTPUT_TOKENS if conversation else Commentary.OUTPUT_TOKENS, options)
	busy = false
	if closed or Time.get_ticks_msec() >= deadline:
		last_failure = "timeout"
		return {}
	if raw.is_empty():
		last_failure = "inference_failed"
		retry_after_msec = Time.get_ticks_msec() + failure_backoff_msec
	var result := Reply.validate(raw, conversation, candidates)
	if result.is_empty() and last_failure.is_empty():
		last_failure = "invalid_reply"
	return result


func shutdown() -> void:
	closed = true
	if service != null:
		service.stop()


func _exit_tree() -> void:
	shutdown()
