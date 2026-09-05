class_name LlmService
extends Node

signal service_ready
signal failed(message: String)

const HOST := "127.0.0.1"
const PORT_FIRST := 18080
const PORT_LAST := 18089
const STARTUP_TIMEOUT_MSEC := 45_000
const REQUEST_TIMEOUT_MSEC := 30_000
const DEFAULT_SYSTEM_PROMPT := "Reply with one concise gameplay comment. Return only the comment."

var runtime_root_override: String = ""
var last_error: String = ""

var _manifest: Dictionary = {}
var _process_id: int = 0
var _port: int = 0
var _server_ready: bool = false
var _request_in_flight: bool = false
var _lifecycle: int = 0


func start(timeout_msec: int = STARTUP_TIMEOUT_MSEC) -> Error:
	if is_ready():
		return OK
	_server_ready = false
	if _process_id > 0 and OS.is_process_running(_process_id):
		return ERR_ALREADY_IN_USE

	var manifest_error := _load_manifest()
	if manifest_error != OK:
		return manifest_error

	_port = _find_available_port()
	if _port == 0:
		return _fail(ERR_CANT_CREATE, "No free local LLM port in %d-%d" % [PORT_FIRST, PORT_LAST])

	var runtime_path := _runtime_path()
	var model_path := _model_path()
	if not FileAccess.file_exists(runtime_path):
		return _fail(ERR_FILE_NOT_FOUND, "LLM runtime not found: %s" % runtime_path)
	if not FileAccess.file_exists(model_path):
		return _fail(ERR_FILE_NOT_FOUND, "LLM model not found: %s" % model_path)

	var arguments := PackedStringArray([
		"--model", model_path,
		"--host", HOST,
		"--port", str(_port),
		"--ctx-size", "1024",
		"--threads", "4",
		"--parallel", "1",
		"--n-gpu-layers", "0",
		"--alias", "retro-ai-gemma",
		"--cors-origins", "localhost",
		"--no-webui",
	])
	_process_id = OS.create_process(runtime_path, arguments, false)
	if _process_id <= 0:
		_process_id = 0
		return _fail(ERR_CANT_FORK, "Could not start the bundled LLM runtime")

	var lifecycle := _lifecycle
	var deadline := Time.get_ticks_msec() + maxi(1, timeout_msec)
	while Time.get_ticks_msec() < deadline:
		if lifecycle != _lifecycle:
			return ERR_SKIP
		if not OS.is_process_running(_process_id):
			_process_id = 0
			return _fail(ERR_CANT_OPEN, "The bundled LLM runtime exited during startup")
		var response: Dictionary = await _request(HTTPClient.METHOD_GET, "/health", "",
			mini(1000, maxi(1, deadline - Time.get_ticks_msec())))
		if lifecycle != _lifecycle:
			return ERR_SKIP
		if int(response.get("code", 0)) == 200:
			_server_ready = true
			last_error = ""
			service_ready.emit()
			return OK
		await get_tree().create_timer(0.1).timeout

	if lifecycle != _lifecycle:
		return ERR_SKIP
	stop()
	return _fail(ERR_TIMEOUT, "The bundled LLM runtime did not become ready")


func is_ready() -> bool:
	return _server_ready and _process_id > 0 and OS.is_process_running(_process_id)


func generate(prompt: String, max_tokens: int = 48, options: Dictionary = {}) -> String:
	if not is_ready():
		_fail(ERR_UNAVAILABLE, "The bundled LLM runtime is not ready")
		return ""
	if _request_in_flight:
		_fail(ERR_BUSY, "The bundled LLM runtime already has a request in flight")
		return ""
	if prompt.strip_edges().is_empty():
		_fail(ERR_INVALID_PARAMETER, "The LLM prompt is empty")
		return ""

	_request_in_flight = true
	var lifecycle := _lifecycle
	var payload := {
		"model": "retro-ai-gemma",
		"messages": [
			{"role": "system", "content": options.get("system_prompt", DEFAULT_SYSTEM_PROMPT)},
			{"role": "user", "content": prompt},
		],
		"max_tokens": clampi(max_tokens, 1, 512),
		"temperature": 0.7,
		"stream": false,
	}
	if options.has("json_schema"):
		payload["response_format"] = {"type": "json_schema", "json_schema": {
			"name": "pixel_reply", "strict": true, "schema": options.json_schema}}
	var response: Dictionary = await _request(
		HTTPClient.METHOD_POST,
		"/v1/chat/completions",
		JSON.stringify(payload),
		clampi(int(options.get("timeout_msec", REQUEST_TIMEOUT_MSEC)), 1, 120000)
	)
	if lifecycle != _lifecycle:
		return ""
	_request_in_flight = false

	if int(response.get("code", 0)) != 200:
		stop()
		_fail(ERR_CANT_CONNECT, "LLM request failed: %s" % response.get("error", "HTTP error"))
		return ""
	var data: Variant = response.get("json")
	if not data is Dictionary:
		_fail(ERR_PARSE_ERROR, "LLM response was not a JSON object")
		return ""
	var choices: Variant = data.get("choices")
	if not choices is Array or choices.is_empty():
		_fail(ERR_PARSE_ERROR, "LLM response did not contain a choice")
		return ""
	if not choices[0] is Dictionary:
		_fail(ERR_PARSE_ERROR, "LLM choice was not an object")
		return ""
	var message: Variant = choices[0].get("message")
	if not message is Dictionary:
		_fail(ERR_PARSE_ERROR, "LLM response did not contain a message")
		return ""
	var content := str(message.get("content", "")).strip_edges()
	if content.is_empty():
		_fail(ERR_PARSE_ERROR, "LLM returned an empty response")
		return ""
	last_error = ""
	return content


func stop() -> void:
	_lifecycle += 1
	_server_ready = false
	_request_in_flight = false
	if _process_id > 0 and OS.is_process_running(_process_id):
		OS.kill(_process_id)
	_process_id = 0
	_port = 0


func get_process_id() -> int:
	return _process_id


func get_port() -> int:
	return _port


func _exit_tree() -> void:
	stop()


func _load_manifest() -> Error:
	var manifest_path := _runtime_root().path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		return _fail(ERR_FILE_NOT_FOUND, "LLM manifest not found: %s" % manifest_path)
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return _fail(FileAccess.get_open_error(), "Could not open the LLM manifest")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail(ERR_PARSE_ERROR, "LLM manifest is not a JSON object")
	_manifest = parsed
	return OK


func _runtime_root() -> String:
	if not runtime_root_override.is_empty():
		return runtime_root_override.simplify_path()
	if OS.has_feature("standalone"):
		return OS.get_executable_path().get_base_dir().path_join("llm")
	return ProjectSettings.globalize_path("res://vendor/llm")


func _runtime_path() -> String:
	var runtimes: Dictionary = _manifest.get("runtimes", {})
	return _runtime_root().path_join(str(runtimes.get(_platform_key(), "")))


func _model_path() -> String:
	var model: Dictionary = _manifest.get("model", {})
	return _runtime_root().path_join(str(model.get("file", "")))


func _platform_key() -> String:
	var platform_name := OS.get_name().to_lower()
	if platform_name == "macos":
		platform_name = "macos"
	elif platform_name == "linux":
		platform_name = "linux"
	return "%s-%s" % [platform_name, Engine.get_architecture_name()]


func _find_available_port() -> int:
	for candidate in range(PORT_FIRST, PORT_LAST + 1):
		var listener := TCPServer.new()
		if listener.listen(candidate, HOST) == OK:
			listener.stop()
			return candidate
	return 0


func _request(method: HTTPClient.Method, path: String, body: String, timeout_msec: int) -> Dictionary:
	var lifecycle := _lifecycle
	var client := HTTPClient.new()
	var connect_error := client.connect_to_host(HOST, _port)
	if connect_error != OK:
		return {"error": error_string(connect_error)}
	var deadline := Time.get_ticks_msec() + timeout_msec

	while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		if lifecycle != _lifecycle:
			client.close()
			return {"error": "cancelled"}
		client.poll()
		if Time.get_ticks_msec() >= deadline:
			return {"error": "connection timeout"}
		await get_tree().process_frame
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "connection failed with status %d" % client.get_status()}

	var headers := PackedStringArray(["Content-Type: application/json"])
	var request_error := client.request(method, path, headers, body)
	if request_error != OK:
		return {"error": error_string(request_error)}
	while not client.has_response():
		if lifecycle != _lifecycle:
			client.close()
			return {"error": "cancelled"}
		client.poll()
		if Time.get_ticks_msec() >= deadline:
			return {"error": "response timeout"}
		if client.get_status() in [
			HTTPClient.STATUS_DISCONNECTED,
			HTTPClient.STATUS_CANT_CONNECT,
			HTTPClient.STATUS_CONNECTION_ERROR,
		]:
			return {"error": "connection closed before a response"}
		await get_tree().process_frame

	var response_code := client.get_response_code()
	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		if lifecycle != _lifecycle:
			client.close()
			return {"error": "cancelled"}
		client.poll()
		var chunk := client.read_response_body_chunk()
		if not chunk.is_empty():
			response_body.append_array(chunk)
			if response_body.size() > 65536:
				client.close()
				return {"error": "response too large"}
		if Time.get_ticks_msec() >= deadline:
			return {"code": response_code, "error": "body timeout"}
		await get_tree().process_frame

	var response_text := response_body.get_string_from_utf8()
	var parser := JSON.new()
	var parsed: Variant = parser.data if parser.parse(response_text) == OK else null
	return {
		"code": response_code,
		"json": parsed,
		"error": response_text.left(240),
	}


func _fail(code: Error, message: String) -> Error:
	last_error = message
	failed.emit(message)
	return code
