extends SceneTree

const LlmServiceScript = preload("res://scripts/llm/llm_service.gd")

var service: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	service = LlmServiceScript.new()
	service.runtime_root_override = ProjectSettings.globalize_path("res://vendor/llm")
	root.add_child(service)

	var start_error: Error = await service.start()
	if start_error != OK:
		_fail("startup: %s" % service.last_error)
		return
	var server_port: int = service.get_port()
	var response: String = await service.generate(
		"The player collected an apple in a retro snake game. Write one comment of eight words or fewer.",
		24
	)
	if response.is_empty():
		_fail("generation: %s" % service.last_error)
		return
	if response.length() > 160:
		_fail("generation was unexpectedly long: %d characters" % response.length())
		return

	service.stop()
	var port_released := false
	for _attempt in 20:
		var listener := TCPServer.new()
		if listener.listen(server_port, "127.0.0.1") == OK:
			listener.stop()
			port_released = true
			break
		await create_timer(0.05).timeout
	if not port_released:
		_fail("llama-server still held its port after stop")
		return
	print("LLM_SMOKE_OK: %s" % response.replace("\n", " "))
	quit(0)


func _fail(message: String) -> void:
	if service != null:
		service.stop()
	push_error("LLM_SMOKE_FAILED: %s" % message)
	quit(1)
