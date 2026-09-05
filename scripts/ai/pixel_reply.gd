extends RefCounted

const Fallbacks = preload("res://scripts/ai/pixel_fallbacks.gd")
const MAX_RAW_BYTES := 1024


static func valid_text(value: Variant, maximum: int) -> bool:
	if not value is String or value.is_empty() or value.length() > maximum:
		return false
	if value != value.strip_edges():
		return false
	for index in value.length():
		var code: int = value.unicode_at(index)
		var letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var digit := code >= 48 and code <= 57
		if not letter and not digit and value[index] not in " .,:/-+!?>'":
			return false
	return true


static func validate(raw: String, conversation: bool, candidates: Array[Dictionary]) -> Dictionary:
	if raw.to_utf8_buffer().size() > MAX_RAW_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {}
	var reply: Variant = parser.data
	if not reply is Dictionary or reply.size() != (3 if conversation else 2):
		return {}
	if reply.get("emotion") not in Fallbacks.EMOTIONS or not valid_text(reply.get("message"), 80):
		return {}
	if not conversation:
		return reply.duplicate(true)
	if conversation:
		var options: Variant = reply.get("choices")
		if not options is Array or options.size() != 3:
			return {}
		var distinct: Dictionary = {}
		for option in options:
			if not valid_text(option, 32) or distinct.has(option.to_lower()):
				return {}
			distinct[option.to_lower()] = true
	for candidate in candidates:
		if reply == candidate:
			return reply.duplicate(true)
	return {}


static func schema(conversation: bool, candidates: Array[Dictionary]) -> Dictionary:
	if not conversation:
		return {"type": "object", "additionalProperties": false,
			"required": ["emotion", "message"], "properties": {
				"emotion": {"type": "string", "enum": Fallbacks.EMOTIONS,
					"description": "Pixel's reaction to the newest supplied gameplay event."},
				"message": {"type": "string", "minLength": 1, "maxLength": 80,
					"pattern": "^[-A-Za-z0-9.,:/+!?>']([-A-Za-z0-9 .,:/+!?>']{0,78}[-A-Za-z0-9.,:/+!?>'])?$",
					"description": "One original, grounded, single-line reaction. No surrounding spaces."},
			}}
	var variants: Array[Dictionary] = []
	for candidate in candidates:
		var properties := {
			"emotion": {"type": "string", "enum": [candidate.emotion]},
			"message": {"type": "string", "enum": [candidate.message]},
		}
		var required: Array[String] = ["emotion", "message"]
		if conversation:
			properties["choices"] = {"const": candidate.choices}
			required.append("choices")
		variants.append({"type": "object", "properties": properties,
			"required": required, "additionalProperties": false})
	return {"oneOf": variants}


static func repeats_commentary(message: String, history: Array[Dictionary]) -> bool:
	var words := _words(message)
	var normalized := " ".join(words)
	for record in history:
		var previous := _words(record.message)
		if normalized == " ".join(previous):
			return true
		for index in maxi(0, previous.size() - 4):
			if (" " + normalized + " ").contains(" " + " ".join(previous.slice(index, index + 5)) + " "):
				return true
	return false


static func _words(message: String) -> PackedStringArray:
	var normalized := message.to_lower()
	for punctuation in ".,:/-+!?>'":
		normalized = normalized.replace(punctuation, " ")
	return normalized.split(" ", false)
