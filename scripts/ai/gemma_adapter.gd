extends Node

const Service = preload("res://scripts/llm/llm_service.gd")
const Reply = preload("res://scripts/ai/pixel_reply.gd")
const OUTPUT_TOKENS := 320
const SYSTEM_PROMPT := "You are Pixel. Choose one supplied safe reply for this run. Copy that JSON object exactly. No extra text."

var service: Node
var busy: bool = false
var closed: bool = false
var retry_after_msec: int = 0
var failure_backoff_msec: int = 30000


func request(context: Dictionary, candidates: Array[Dictionary], conversation: bool,
		timeout_seconds: float) -> Dictionary:
	if busy or closed or not is_inside_tree() or Time.get_ticks_msec() < retry_after_msec:
		return {}
	busy = true
	if service == null:
		service = Service.new()
		add_child(service)
	var deadline := Time.get_ticks_msec() + int(maxf(0.01, timeout_seconds) * 1000.0)
	var startup: Error = await service.start(maxi(1, deadline - Time.get_ticks_msec()))
	if closed or startup != OK or Time.get_ticks_msec() >= deadline:
		busy = false
		retry_after_msec = Time.get_ticks_msec() + failure_backoff_msec
		return {}
	var prompt := JSON.stringify({"context": context, "safe_replies": candidates})
	var raw: String = await service.generate(prompt, OUTPUT_TOKENS, {
		"system_prompt": SYSTEM_PROMPT, "json_schema": Reply.schema(conversation, candidates),
		"timeout_msec": maxi(1, deadline - Time.get_ticks_msec()),
	})
	busy = false
	if closed or Time.get_ticks_msec() >= deadline:
		return {}
	if raw.is_empty():
		retry_after_msec = Time.get_ticks_msec() + failure_backoff_msec
	return Reply.validate(raw, conversation, candidates)


func shutdown() -> void:
	closed = true
	if service != null:
		service.stop()


func _exit_tree() -> void:
	shutdown()
