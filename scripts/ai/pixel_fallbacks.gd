extends RefCounted

const Journal = preload("res://scripts/ai/run_journal.gd")
const EMOTIONS := ["curious", "excited", "worried", "surprised", "proud"]
const LINES := {
	"run_started": ["curious", "I'm awake! Is that an adventure or a very large snack?", "New run! I packed courage. Probably."],
	"stage_start": ["curious", "Ooh! A new room for my extremely important confusion!", "I recognize this place! No, wait. I don't."],
	"near_completion": ["curious", "My bolts are tingling. Is the floor plotting something?", "I smell a surprise! Do robots smell?"],
	"transformation_started": ["surprised", "Wait! Who folded the universe while I was looking?", "My map just turned into soup!"],
	"transformation_completed": ["excited", "New shape! Same tiny me! Slightly louder screaming!", "I survived the world's furniture rearrangement!"],
	"death": ["worried", "Oh! My brave little circuits need a minute.", "That hurt my imaginary knees. I'm still here!"],
	"run_ended": ["curious", "Is that the end? I was just finding my elbows!", "I'm putting this run in my very tiny thought cupboard."],
	"victory": ["proud", "We did it! I'm awarding us a magnificent imaginary hat!", "My victory dance has too many elbows!"],
	"progress_milestone": ["excited", "Ooh! My happy circuits just did a cartwheel!", "I'm collecting little reasons to squeak!"],
	"collectible_streak": ["excited", "More snacks! My imaginary pockets are getting heroic!", "I want to name every crumb. This may take a while!"],
	"ghost_defeated": ["surprised", "Our tail ate a ghost?! I have several new questions!", "Boo to YOU, spooky bedsheet!"],
	"crossing_completed": ["proud", "Dry land! I would kiss it, but I forgot my lips!", "I'm calling that bank my emotional support rectangle!"],
	"asteroid_streak": ["excited", "Space gravel! I'm mentally sweeping it under a planet!", "Those rocks had too many corners anyway!"],
	"danger_escaped": ["worried", "Eep! My courage just hid behind a very small bolt!", "I briefly became a screaming calculator!"],
}
const OPENERS := {
	"representative": "I have so many thoughts! Most of them are squeaking!",
	"careful": "My nerves are wearing tiny crash helmets! What a run!",
	"aggressive": "I think our tail deserves its own victory hat!",
	"fast": "My thoughts are still trying to catch up with us!",
}
const TOPICS := ["Which bit made you squeak?", "Tell me your oddest thought.", "Did your circuits survive?"]


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
		return "I counted %d danger escapes. My bolts nearly fled!" % count
	if style == "aggressive" and journal.count("ghost_defeated") > 0:
		var count: int = journal.count("ghost_defeated")
		return "%d ghosts! I need a bigger imaginary broom!" % count
	if style == "aggressive" and journal.count("asteroid_streak") > 0:
		var count: int = journal.count("asteroid_streak")
		return "%d rock streaks! I call that cosmic confetti!" % count
	if style == "fast":
		if journal.duration_msec() > 0:
			return "%d seconds! My thoughts arrived fashionably late!" % (journal.duration_msec() / 1000)
		return "My thoughts need little running shoes!"
	if style == "careful":
		return "My courage has a very small safety helmet!"
	if style == "aggressive":
		return "My bravery is mostly enthusiastic beeping!"
	return "%d points! Can I stack them into a robot throne?" % int(journal.latest().get("score", 0))


static func conversation(journal: RefCounted, style: String, history: Array[int], turn: int = 0) -> Array[Dictionary]:
	var fact := detail(journal, style)
	var message: String = OPENERS[style]
	var options: Array = TOPICS
	var emotion := "proud"
	if not history.is_empty():
		var branch: int = history.back()
		var reactions := [
			[fact, "My favorite bit? When my panic turned into confetti!", "I am filing that thought under 'magnificent squeaking'!"],
			["I suspect the universe is a snack with complicated rules!", "What if our tail was a very determined scarf?", "My oddest thought has escaped. It was wearing a hat!"],
			["My circuits survived! My dignity is still buffering!", "I might be three excited calculators in a coat!", "I'm okay! My imaginary knees are just applauding!"],
		]
		message = reactions[branch][posmod(turn, 3)]
		options = [
			["What surprised you most?", "Give that thought a name.", "Are you still buzzing?"],
			["Which moment inspired that?", "Make it even stranger.", "How does a robot celebrate?"],
			["Tell me one more detail.", "What are imaginary knees?", "I might be a calculator too."],
		][branch]
		emotion = ["curious", "surprised", "excited"][branch]
	return [
		{"emotion": emotion, "message": message, "choices": options.duplicate()},
		{"emotion": emotion, "message": message, "choices": options.duplicate()},
	]
