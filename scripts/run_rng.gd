extends RefCounted

static func stream_seed(run_seed: int, stream: String) -> int:
	return (run_seed ^ int(stream.hash())) & 0x7fffffff

static func fresh_seed() -> int:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator.randi_range(1, 0x7fffffff)
