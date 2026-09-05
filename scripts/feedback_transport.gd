extends Node

const Protocol = preload("res://scripts/feedback_protocol.gd")
const SEND_TIMEOUT_MS := 250
const RETRY_MS := 2000

var endpoint: String = ""
var status: String = "disabled"
var dropped: int = 0
var sent: int = 0
var _peer: RefCounted
var _pending: Dictionary = {}
var _buffer := PackedByteArray()
var _offset: int = 0
var _deadline: int = 0
var _retry_at: int = 0


func _ready() -> void:
	endpoint = OS.get_environment("SUMMER_FEEDBACK_SOCKET")
	status = "unavailable" if not endpoint.is_empty() else "disabled"


func send(packet: Dictionary) -> void:
	if endpoint.is_empty() or not Protocol.valid(packet):
		dropped += 1
		return
	if not _pending.is_empty() and packet.priority < _pending.priority:
		dropped += 1
		return
	if _pending.is_empty() and _buffer.is_empty():
		_deadline = Time.get_ticks_msec() + SEND_TIMEOUT_MS
	_pending = packet.duplicate(true)


func _process(_delta: float) -> void:
	if endpoint.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _peer != null:
		_peer.poll()
		if _peer.get_status() == 3 or _peer.get_status() == 0:
			_disconnect("unavailable")
	if _pending.is_empty() and _buffer.is_empty():
		return
	if now >= _deadline:
		_disconnect("send_timeout")
		return
	if _peer == null:
		if now < _retry_at:
			_pending.clear()
			dropped += 1
			return
		if not ClassDB.class_exists("StreamPeerUDS"):
			_disconnect("unsupported")
			return
		if not DirAccess.dir_exists_absolute(endpoint.get_base_dir()) or not DirAccess.get_files_at(endpoint.get_base_dir()).has(endpoint.get_file()):
			_disconnect("unavailable")
			return
		_peer = ClassDB.instantiate("StreamPeerUDS")
		if _peer.connect_to_host(endpoint) != OK:
			_disconnect("unavailable")
			return
		_peer.poll()
	if _peer.get_status() != 2:
		return
	status = "socket_connected"
	if _buffer.is_empty():
		_buffer = (JSON.stringify(_pending) + "\n").to_utf8_buffer()
		_pending.clear()
		_offset = 0
	var result: Array = _peer.put_partial_data(_buffer.slice(_offset))
	if result[0] != OK:
		_disconnect("send_error")
		return
	_offset += int(result[1])
	if _offset == _buffer.size():
		sent += 1
		_buffer.clear()
		_deadline = now + SEND_TIMEOUT_MS


func _disconnect(reason: String) -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	_buffer.clear()
	_pending.clear()
	status = reason
	dropped += 1
	_retry_at = Time.get_ticks_msec() + RETRY_MS


func reset_connection() -> void:
	_disconnect("disabled" if endpoint.is_empty() else "unavailable")
	_retry_at = 0


func _exit_tree() -> void:
	_disconnect("closed")
