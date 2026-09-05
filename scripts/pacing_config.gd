extends RefCounted

const STAGES: Array[String] = ["snake", "maze", "frogger", "asteroids"]
const TRANSITION_SECONDS := 3.0
const TARGETS := {
	"normal": {"snake": 10, "maze": 97, "frogger": 3, "asteroids": 12},
	"demo": {"snake": 3, "maze": 10, "frogger": 1, "asteroids": 4},
}

static func options(profile: String, stage: String, seed_value: int) -> Dictionary:
	var targets: Dictionary = TARGETS.get(profile, TARGETS.normal)
	return {"target": int(targets[stage]), "seed": seed_value,
		"advanced_hazards": false, "ghost_respawn_seconds": 4.0,
		"ghost_warning_seconds": 0.9}

static func next_stage(current: String) -> String:
	var index := STAGES.find(current)
	return STAGES[index + 1] if index >= 0 and index + 1 < STAGES.size() else ""
