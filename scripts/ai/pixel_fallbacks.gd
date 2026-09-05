extends RefCounted

const Journal = preload("res://scripts/ai/run_journal.gd")
const EMOTIONS := ["curious", "excited", "worried", "surprised", "proud"]
const LINES := {
	"run_started": ["curious", "PIXEL ONLINE. Ready to play?", "A fresh run. I am here."],
	"stage_start": ["curious", "Here we are. I am watching.", "The world feels different here."],
	"near_completion": ["curious", "The edges are getting restless.", "Something feels close to changing."],
	"transformation_started": ["surprised", "The world is shifting.", "Wait. Those edges are moving."],
	"transformation_completed": ["excited", "A new shape. Still us.", "We came through the change."],
	"death": ["worried", "That run has ended. I am still here.", "A quiet moment. We can try again."],
	"run_ended": ["curious", "That is the end of this run.", "We can leave this run here."],
	"victory": ["proud", "You made it through this run.", "We reached the end together."],
	"progress_milestone": ["excited", "A little more of the path behind us.", "That was another step forward."],
	"collectible_streak": ["excited", "A string of little discoveries.", "Those pickups made a rhythm."],
	"ghost_defeated": ["surprised", "That ghost is gone for now.", "You caught the ghost this time."],
	"crossing_completed": ["proud", "Another crossing behind us.", "You reached the other side."],
	"asteroid_streak": ["excited", "You broke a streak of space rocks.", "Those rocks did not stay whole."],
	"danger_escaped": ["worried", "That danger is behind us for now.", "A close moment. You came through."],
}
const OPENERS := {
	"representative": "We have this run to look back on.",
	"careful": "Those careful moments caught my eye.",
	"aggressive": "Those bold moments caught my eye.",
	"fast": "The quick moments stood out this run.",
}
const TOPICS := ["What stood out?", "How did it feel?", "What about another run?"]
const FOLLOWUPS := [
	["Tell me one detail.", "That mattered to me.", "A different thought?"],
	["I felt that too.", "What did you notice?", "A quiet finish sounds good."],
	["A fresh start sounds good.", "One last detail?", "Just this run for now."],
]
const ACKNOWLEDGEMENTS := [
	["One detail, then.", "We can sit with that.", "A different thought, then."],
	["A shared moment, then.", "Here is what I noticed.", "A quiet finish, then."],
	["A fresh start can wait.", "One last detail, then.", "Just this run, then."],
]
const FINAL_CHOICES := ["Thanks for watching.", "I liked this run.", "See you next time."]


static func commentary(kind: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var line: Array = LINES.get(kind, LINES.run_started)
	var replies: Array[Dictionary] = [
		{"emotion": line[0], "message": line[1]},
		{"emotion": line[0], "message": line[2]},
	]
	if rng.randi_range(0, 1) == 1:
		replies.reverse()
	return replies


static func choose_style(journal: RefCounted, rng: RandomNumberGenerator) -> String:
	var eligible: Array[String] = []
	for style in ["careful", "aggressive", "fast"]:
		if journal.style_evidence(style) > 0:
			eligible.append(style)
	return "representative" if eligible.is_empty() else eligible[rng.randi_range(0, eligible.size() - 1)]


static func detail(journal: RefCounted, style: String) -> String:
	if style == "careful" and journal.count("danger_escaped") > 0:
		var count: int = journal.count("danger_escaped")
		return "You escaped danger %d time%s." % [count, "" if count == 1 else "s"]
	if style == "aggressive" and journal.count("ghost_defeated") > 0:
		var count: int = journal.count("ghost_defeated")
		return "You defeated %d ghost%s." % [count, "" if count == 1 else "s"]
	if style == "aggressive" and journal.count("asteroid_streak") > 0:
		var count: int = journal.count("asteroid_streak")
		return "You made %d asteroid streak%s." % [count, "" if count == 1 else "s"]
	if style == "fast":
		if journal.duration_msec() > 0:
			return "This run took %d seconds." % (journal.duration_msec() / 1000)
		return "This run recorded quick moments."
	if style == "careful":
		return "This run recorded careful moments."
	if style == "aggressive":
		return "This run recorded bold moments."
	return "This run reached a score of %d." % int(journal.latest().get("score", 0))


static func conversation(journal: RefCounted, style: String, history: Array[int]) -> Array[Dictionary]:
	var fact := detail(journal, style)
	var message: String = OPENERS[style]
	var options: Array = TOPICS
	var emotion := "proud"
	if history.size() == 1:
		var branch := history[0]
		message = [fact, "I only know the moments we recorded.", "A new run starts with a clean slate."][branch]
		options = FOLLOWUPS[branch]
		emotion = ["curious", "proud", "excited"][branch]
	elif history.size() == 2:
		message = "%s %s" % [ACKNOWLEDGEMENTS[history[0]][history[1]], fact]
		options = FINAL_CHOICES
		emotion = "curious"
	return [
		{"emotion": emotion, "message": message, "choices": options.duplicate()},
		{"emotion": emotion, "message": "I am here. " + message, "choices": options.duplicate()},
	]


static func farewell(last_choice: int) -> Dictionary:
	return {"emotion": "proud", "message": [
		"Thanks for sharing this run. See you next time.",
		"I am glad we had this run. See you next time.",
		"See you next time. A fresh run awaits.",
	][clampi(last_choice, 0, 2)]}
