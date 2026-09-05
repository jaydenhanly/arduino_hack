extends Node
## Reads ambient lux from the Uno Q's Modulino Light sensor and fades the game's
## palette between light mode (dark ink on green) and dark mode (green ink on
## black) to match the room. The bridge running alongside the game on the board
## writes the latest reading to STATE_PATH; off the board that file never
## appears, so the game just stays in light mode.

const Art = preload("res://scripts/pixel_art.gd")

const STATE_PATH := "/game/light_state.json"
const POLL_INTERVAL := 0.5
# Lux thresholds bracketing the transition; tune against the actual sensor on the board.
const LUX_DARK := 15.0
const LUX_LIGHT := 250.0
const FADE_PER_SECOND := 0.5

var _poll_elapsed := 0.0
var _target_t := 0.0
var _current_t := 0.0

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed >= POLL_INTERVAL:
		_poll_elapsed = 0.0
		_poll()
	if not is_equal_approx(_current_t, _target_t):
		_current_t = move_toward(_current_t, _target_t, FADE_PER_SECOND * delta)
		Art.apply_light_level(_current_t)

func _poll() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("lux"):
		return
	var lux: float = float(parsed["lux"])
	_target_t = 1.0 - clampf((lux - LUX_DARK) / (LUX_LIGHT - LUX_DARK), 0.0, 1.0)
