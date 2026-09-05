extends SceneTree

const Hardware = preload("res://scripts/hardware_feedback.gd")
const Transport = preload("res://scripts/feedback_transport.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var client := Transport.new()
	root.add_child(client)
	client.send(Hardware.program("victory"))
	var deadline := Time.get_ticks_msec() + 1500
	while client.sent == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed: bool = client.sent == 1 and client.status == "socket_connected"
	await create_timer(0.4).timeout
	print("FEEDBACK_SOCKET_OK" if passed else "FEEDBACK_SOCKET_FAILED " + client.status)
	client.queue_free()
	await process_frame
	quit(0 if passed else 1)
