extends Node

signal released

var startup_error: Error = OK
var wait_for_startup: bool = false
var wait_for_generation: bool = false
var response: String = ""
var prompt: String = ""
var tokens: int = 0
var options: Dictionary = {}
var starts: int = 0
var generations: int = 0
var stopped: bool = false
var prompt_token_count: int = 600
var token_counts: Array[int] = []
var tokenized_prompts: Array[String] = []


func count_prompt_tokens(input: String, _system: String, _timeout_msec: int) -> int:
	tokenized_prompts.append(input)
	return token_counts.pop_front() if not token_counts.is_empty() else prompt_token_count


func start(_timeout_msec: int = 1000) -> Error:
	starts += 1
	if wait_for_startup:
		await released
	return startup_error


func generate(input: String, max_tokens: int = 48, settings: Dictionary = {}) -> String:
	generations += 1
	prompt = input
	tokens = max_tokens
	options = settings.duplicate(true)
	if wait_for_generation:
		await released
	return response


func stop() -> void:
	stopped = true
	if wait_for_startup or wait_for_generation:
		wait_for_startup = false
		wait_for_generation = false
		released.emit()
