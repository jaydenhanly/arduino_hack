extends Node
## Sends a vibration pulse to the Uno Q board over UDP. Wired as
## HardwareFeedback's `transport` Callable — the only piece of this game's
## feedback stack that touches real hardware; everything upstream of it
## (VibrationController, LightController) stays pure logic.
##
## The board's install step (the ship-to-unoq skill's board/install-game.sh)
## disables the bridge's own per-button-press buzz and starts
## summer_haptics_bridge.py instead: a UDP listener on port 5560, in the same
## container as the rest of the Python bridge ("main" in `docker ps` on the
## board), that forwards {"type": "vibrate", "ms": int} straight to the MCU's
## vibrate RPC. "main" is that container's Compose service-name — confirmed
## on-board via `docker exec <slug>-game_runner-1 getent hosts main`, which
## resolves it on the same network this game's own container is on. No Vibro
## attached is a safe no-op on the receiving end.
##
## UDP has no delivery confirmation, so failure here only ever means the local
## send couldn't be attempted at all (hostname didn't resolve, socket wouldn't
## connect) — logged to LOG_PATH for on-board diagnosis, same mount point as
## /game/light_state.json. A silent log is not proof the board buzzed, only
## that nothing stopped the packet from being sent.

const HOST := "main"
const PORT := 5560
const LOG_PATH := "/game/vibrate-debug.log"

var _socket := PacketPeerUDP.new()
var _ready_to_send := false

func _ready() -> void:
	var ip := IP.resolve_hostname(HOST)
	if ip.is_empty():
		_log("could not resolve host '%s' — off the board, or the bridge isn't on this network" % HOST)
		return
	var error := _socket.connect_to_host(ip, PORT)
	if error != OK:
		_log("connect_to_host(%s:%d) failed with engine error %d" % [ip, PORT, error])
		return
	_ready_to_send = true

## Matches the Callable signature HardwareFeedback.transport expects: called
## with a duplicate of its last_event dict.
func send(event: Dictionary) -> void:
	var pulse_ms: int = event.get("pulse_ms", 0)
	if pulse_ms <= 0 or not _ready_to_send:
		return
	var body := JSON.stringify({"type": "vibrate", "ms": pulse_ms}).to_utf8_buffer()
	var error := _socket.put_packet(body)
	if error != OK:
		_log("put_packet failed with engine error %d" % error)

func _log(message: String) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%.2f %s" % [Time.get_ticks_msec() / 1000.0, message])
