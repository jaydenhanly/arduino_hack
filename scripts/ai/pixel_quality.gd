extends RefCounted


static func complete_message(message: String) -> bool:
	if message.is_empty() or message[-1] not in ".!?":
		return false
	if message.ends_with("...") or message.ends_with("-!") or message.ends_with("-?") or message.ends_with("-.") or message.ends_with(".?") or message.ends_with(",?"):
		return false
	var first := message.unicode_at(0)
	if not ((first >= 65 and first <= 90) or (first >= 97 and first <= 122) or (first >= 48 and first <= 57)):
		return false
	var text := message.to_lower()
	for punctuation in ".,!?:/-+>":
		text = text.replace(punctuation, " ")
	var words := text.split(" ", false)
	if words.is_empty():
		return false
	if words.size() > 1 and words[-1].length() == 1 and words[-2] in ["of", "a", "the", "to"]:
		return false
	if words.size() > 1 and words[-2] == "of" and words[-1] == "some":
		return false
	if " ".join(words).ends_with("they've even got"):
		return false
	var clauses := message.to_lower().replace("!", ".").replace("?", ".").replace(",", ".").split(".", false)
	var ending := clauses[-1].strip_edges() if not clauses.is_empty() else ""
	if ending in ["it", "i", "but i had", "and i had"]:
		return false
	if words[-1] == "i" and not " ".join(words).ends_with("so do i") and not " ".join(words).ends_with("so am i"):
		return false
	return words[-1] not in ["a", "an", "the", "and", "but", "because", "of", "with", "to", "were", "was", "are", "is", "have", "has", "such", "my", "your", "our", "their", "it's", "i'm", "we're", "they've", "you'd"]


static func boilerplate(message: String) -> bool:
	var lower := message.to_lower()
	for phrase in ["as an ai", "language model", "here is the json", "here is your json", "i cannot assist", "system prompt", "http:", "https:", "1-80 characters", "one line,", "ascii", "how can i help"]:
		if lower.contains(phrase):
			return true
	return false


static func findings(message: String) -> Array[String]:
	var result: Array[String] = []
	var lower := message.to_lower()
	if lower.begins_with("the player ") or lower.contains("successfully "):
		result.append("telemetry_voice")
	if lower in ["it was exhilarating!", "that was exciting!", "great job!"]:
		result.append("generic_reaction")
	if not complete_message(message):
		result.append("incomplete_sentence")
	if boilerplate(message):
		result.append("unrelated_boilerplate")
	var words := lower.replace("!", " ").replace("?", " ").replace(".", " ").split(" ", false)
	var counts := {}
	for word in words:
		counts[word] = int(counts.get(word, 0)) + 1
	for count: int in counts.values():
		if words.size() >= 8 and count * 2 >= words.size():
			result.append("repetitive_output")
			break
	return result
