extends RefCounted

const STAGES := ["snake", "maze", "frogger", "asteroids"]
const EVENTS := [
	"run_started", "progress_milestone", "collectible_streak", "ghost_defeated",
	"crossing_completed", "asteroid_streak", "danger_escaped",
	"transformation_started", "transformation_completed", "run_ended", "victory",
	"stage_start", "near_completion",
]
const ACTIVITY := [
	"progress_milestone", "collectible_streak", "ghost_defeated",
	"crossing_completed", "asteroid_streak", "danger_escaped",
]
const CHECKPOINTS := [
	"stage_start", "near_completion", "transformation_started",
	"transformation_completed", "death", "run_ended", "victory",
]
const STYLES := ["representative", "careful", "aggressive", "fast"]
const MAX_SUMMARY_EVENTS := 3
const MAX_SUMMARY_BYTES := 900
const FAST_RUN_LIMIT_MSEC := 120000

var run_id: int = 0
var sequence: int = 0
var active: bool = false
var _events: Array[Dictionary] = []
var _counts: Dictionary = {}
var _styles: Dictionary = {}
var _milestones: Dictionary = {}


func begin(id: int) -> void:
	clear()
	run_id = id
	active = true


func clear() -> void:
	run_id = 0
	sequence = 0
	active = false
	_events.clear()
	_counts.clear()
	_styles.clear()
	_milestones.clear()


func append(stage: String, kind: String, progress: int, target: int, score: int,
		tags: Dictionary = {}) -> bool:
	kind = normalize(kind)
	var victory_after_end: bool = (kind == "victory" and not _events.is_empty()
		and _events.back().kind == "run_ended" and _events.back().stage == stage
		and _events.back().tags.get("outcome") == "victory"
		and _events.back().progress == progress and _events.back().target == target
		and _events.back().score == score)
	if (not active and not victory_after_end) or stage not in STAGES or kind not in EVENTS:
		return false
	if target < 0 or target > 100000 or progress < 0 or progress > target:
		return false
	if score < 0 or score > 1000000000:
		return false
	if kind == "run_started" and count(kind) > 0:
		return false
	var milestone_key := "%s:%s:%d" % [stage, kind, progress]
	if kind in ["progress_milestone", "near_completion"]:
		if _milestones.has(milestone_key):
			return false
		_milestones[milestone_key] = true
	var validated := validate_tags(tags)
	sequence += 1
	_events.append({
		"run_id": run_id, "sequence": sequence, "stage": stage, "kind": kind,
		"progress": progress, "target": target, "score": score, "tags": validated,
	})
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	if validated.has("style"):
		_styles[validated.style] = int(_styles.get(validated.style, 0)) + 1
	if kind in ["run_ended", "victory"]:
		active = false
	return true


func entries() -> Array[Dictionary]:
	return _events.duplicate(true)


func latest() -> Dictionary:
	return {} if _events.is_empty() else _events.back().duplicate(true)


func count(kind: String) -> int:
	return int(_counts.get(normalize(kind), 0))


static func normalize(kind: String) -> String:
	return {"objective_milestone": "progress_milestone", "victory_reached": "victory"}.get(kind, kind)


func style_evidence(style: String) -> int:
	var evidence := int(_styles.get(style, 0))
	if style == "careful":
		evidence += count("danger_escaped")
	elif style == "aggressive":
		evidence += count("ghost_defeated") + count("asteroid_streak")
	elif style == "fast":
		for entry in _events:
			if entry.kind == "run_ended" and entry.tags.get("outcome") == "victory":
				var duration: int = entry.tags.get("duration_ms", 0)
				if duration > 0 and duration <= FAST_RUN_LIMIT_MSEC:
					evidence += 1
	return evidence


func duration_msec() -> int:
	for entry in _events:
		if entry.kind == "run_ended":
			return int(entry.tags.get("duration_ms", 0))
	return 0


func summary() -> Dictionary:
	var recent: Array[Dictionary] = []
	for entry in _events.slice(maxi(0, _events.size() - MAX_SUMMARY_EVENTS)):
		var compact: Dictionary = entry.duplicate(true)
		compact.erase("run_id")
		recent.append(compact)
	var result := {"run_id": run_id, "sequence": sequence, "counts": _counts.duplicate(),
		"styles": _styles.duplicate(), "recent": recent}
	while JSON.stringify(result).length() > MAX_SUMMARY_BYTES and not recent.is_empty():
		recent.pop_front()
	return result


static func validate_tags(tags: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["count", "duration_ms"]:
		var value: Variant = tags.get(key)
		if value is int and value >= 0 and value <= 3600000:
			result[key] = value
	var seconds: Variant = tags.get("duration_seconds")
	if not result.has("duration_ms") and seconds is int and seconds >= 0 and seconds <= 3600:
		result["duration_ms"] = seconds * 1000
	for key in ["style", "danger", "outcome"]:
		var value: Variant = tags.get(key)
		var allowed: Array = STYLES if key == "style" else (
			["ghost", "traffic", "asteroid", "wall", "tail"] if key == "danger"
			else ["escaped", "completed", "collision", "abandoned", "death", "victory"])
		if value is String and value in allowed:
			result[key] = value
	return result
