extends Node

const Service = preload("res://scripts/llm/llm_service.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const Commentary = preload("res://scripts/ai/commentary_prompt.gd")
const Conversation = preload("res://scripts/ai/conversation_prompt.gd")
const Quality = preload("res://scripts/ai/pixel_quality.gd")

var service: Node
var busy: bool = false
var closed: bool = false
var retry_after_msec: int = 0
var failure_backoff_msec: int = 30000
var last_failure: String = ""
var last_prompt_tokens: int = 0
var last_history_size: int = 0
var last_raw: String = ""
var last_quality_findings: Array[String] = []


func request(context: Dictionary, candidates: Array[Dictionary], conversation: bool,
		timeout_seconds: float) -> Dictionary:
	if busy or closed or not is_inside_tree() or Time.get_ticks_msec() < retry_after_msec:
		last_failure = "unavailable" if closed or busy else "backoff"
		return {}
	last_failure = ""
	last_prompt_tokens = 0
	last_raw = ""
	last_quality_findings.clear()
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
	var prompt_script: Script = Conversation if conversation else Commentary
	var history_key := "history" if conversation else "commentary_history"
	var output_tokens: int = prompt_script.OUTPUT_TOKENS
	var prompt: String = prompt_script.render(input)
	while true:
		last_prompt_tokens = await service.count_prompt_tokens(prompt, prompt_script.SYSTEM,
			maxi(1, deadline - Time.get_ticks_msec()))
		if closed or Time.get_ticks_msec() >= deadline or last_prompt_tokens < 0:
			last_failure = "timeout" if Time.get_ticks_msec() >= deadline else "token_count_failed"
			busy = false
			return {}
		if last_prompt_tokens + output_tokens + Commentary.TOKEN_MARGIN <= Commentary.CONTEXT_TOKENS:
			break
		if not input.get(history_key, []).is_empty():
			input[history_key].pop_front()
		elif not conversation and not input.get("summary", {}).is_empty():
			input.summary = {}
		else:
			last_failure = "context_limit"
			busy = false
			return {}
		prompt = prompt_script.render(input)
	last_history_size = input.get(history_key, []).size()
	var options := {
		"system_prompt": prompt_script.SYSTEM,
		"json_schema": Reply.schema(conversation, candidates),
		"timeout_msec": maxi(1, deadline - Time.get_ticks_msec()),
	}
	options.merge({"repeat_last_n": Commentary.CONTEXT_TOKENS, "repeat_penalty": 1.15})
	var raw: String = await service.generate(prompt, output_tokens, options)
	last_raw = raw.left(1024)
	var parser := JSON.new()
	if parser.parse(raw) == OK and parser.data is Dictionary and parser.data.get("message") is String:
		last_quality_findings = Quality.findings(parser.data.message)
		if conversation and parser.data.get("choices") is Array:
			for choice in parser.data.choices:
				if choice is String and not Quality.complete_message(choice):
					last_quality_findings.append("choice_incomplete")
	busy = false
	if closed or Time.get_ticks_msec() >= deadline:
		last_failure = "timeout"
		return {}
	if raw.is_empty():
		last_failure = "inference_failed"
		retry_after_msec = Time.get_ticks_msec() + failure_backoff_msec
	var result := Reply.validate(raw, conversation, candidates)
	if result.is_empty() and last_failure.is_empty():
		last_failure = "quality_rejected" if not last_quality_findings.is_empty() else "invalid_reply"
	return result


func shutdown() -> void:
	closed = true
	if service != null:
		service.stop()


func _exit_tree() -> void:
	shutdown()
