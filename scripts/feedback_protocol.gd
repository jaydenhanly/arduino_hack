extends RefCounted

const VERSION := 1
const MAX_BYTES := 8192
const MAX_DURATION_MS := 5000


static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func keys_match(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


static func valid(packet: Variant) -> bool:
	if not keys_match(packet, ["version", "sequence", "priority", "replace", "loop", "vibration", "frames"]):
		return false
	if not whole(packet.version, VERSION, VERSION) or not whole(packet.sequence, 1, 2147483647) or not whole(packet.priority, 0, 5):
		return false
	if not packet.replace is bool or not packet.loop is bool or not packet.vibration is Array or not packet.frames is Array:
		return false
	if packet.vibration.size() > 8 or packet.frames.is_empty() or packet.frames.size() > 32:
		return false
	if packet.loop and (packet.priority != 0 or not packet.vibration.is_empty()):
		return false
	var on_total := 0
	var pulse_total := 0
	for pulse in packet.vibration:
		if not keys_match(pulse, ["on_ms", "off_ms"]) or not whole(pulse.on_ms, 10, 120) or not whole(pulse.off_ms, 0, 1000):
			return false
		on_total += int(pulse.on_ms)
		pulse_total += int(pulse.on_ms + pulse.off_ms)
	var frame_total := 0
	for frame in packet.frames:
		if not keys_match(frame, ["rows", "duration_ms", "level"]) or not frame.rows is Array or frame.rows.size() != 8:
			return false
		if not whole(frame.duration_ms, 100, 1000) or not whole(frame.level, 0, 7):
			return false
		for row in frame.rows:
			if not whole(row, 0, 8191):
				return false
		frame_total += int(frame.duration_ms)
	return on_total <= 600 and pulse_total <= MAX_DURATION_MS and frame_total <= MAX_DURATION_MS and JSON.stringify(packet).to_utf8_buffer().size() <= MAX_BYTES


static func duration(packet: Dictionary) -> float:
	var frames := 0
	var pulses := 0
	for frame in packet.frames:
		frames += int(frame.duration_ms)
	for pulse in packet.vibration:
		pulses += int(pulse.on_ms + pulse.off_ms)
	return float(maxi(frames, pulses)) / 1000.0
