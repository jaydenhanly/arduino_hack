extends Node
## Reads ambient lux from the Uno Q's Modulino Light sensor and dims
## Presentation's stage palettes to match the room. The board's bridge writes
## the latest reading to STATE_PATH; off the board that file never appears,
## so the game stays at full brightness. Runs its own _process so the fade
## keeps tracking the room even while gameplay is paused.

const Presentation = preload("res://scripts/presentation_director.gd")

const STATE_PATH := "/game/light_state.json"
const POLL_INTERVAL := 0.5
# Lux thresholds bracketing the fade; tune against the actual sensor on the board.
const LUX_DARK := 15.0
const LUX_LIGHT := 250.0
const FADE_PER_SECOND := 0.5

var _poll_elapsed := 0.0
var _target_level := 0.0
var _current_level := 0.0

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed >= POLL_INTERVAL:
		_poll_elapsed = 0.0
		_poll()
	if not is_equal_approx(_current_level, _target_level):
		_current_level = move_toward(_current_level, _target_level, FADE_PER_SECOND * delta)
		Presentation.set_dark_level(_current_level)

func _poll() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var level: Variant = level_for_state(file.get_as_text())
	if level != null:
		_target_level = level

## Pure parse+threshold step, split out from _poll so it's testable without a
## real board or /game mount: given the bridge's raw JSON text, returns the
## target dark level in [0, 1], or null for anything malformed.
static func level_for_state(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("lux"):
		return null
	var lux: float = float(parsed["lux"])
	return 1.0 - clampf((lux - LUX_DARK) / (LUX_LIGHT - LUX_DARK), 0.0, 1.0)
