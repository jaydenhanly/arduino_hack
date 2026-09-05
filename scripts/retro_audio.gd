extends Node

var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)
	sounds["apple"] = _tone([523.0, 784.0], 0.055)
	sounds["pellet"] = _tone([1047.0], 0.035)
	sounds["damage"] = _tone([220.0, 165.0, 110.0], 0.09)
	sounds["shift"] = _tone([262.0, 330.0, 392.0, 523.0, 659.0, 784.0], 0.09)
	sounds["victory"] = _tone([523.0, 659.0, 784.0, 1047.0], 0.14)
	sounds["start"] = _tone([392.0, 523.0], 0.07)
	sounds["boost"] = _tone([660.0, 880.0, 1175.0], 0.045)
	sounds["ghost"] = _tone([784.0, 1175.0, 1568.0], 0.065)
	sounds["crossing"] = _tone([440.0, 660.0, 880.0, 1320.0], 0.065)
	sounds["impact"] = _tone([220.0, 330.0, 110.0], 0.035)

func play(cue: String) -> void:
	if not sounds.has(cue):
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = sounds[cue]
	voice.play()

func set_paused(value: bool) -> void:
	for voice in voices:
		voice.stream_paused = value

func _tone(notes: Array, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples_per_note := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(samples_per_note * notes.size() * 2)
	for note_index in notes.size():
		for sample_index in samples_per_note:
			var seconds := float(sample_index) / stream.mix_rate
			var envelope := minf(seconds / 0.003, 1.0) * maxf(0.0, 1.0 - seconds / duration)
			var wave := 1.0 if fmod(seconds * float(notes[note_index]), 1.0) < 0.5 else -1.0
			data.encode_s16((note_index * samples_per_note + sample_index) * 2, int(wave * envelope * 9000))
	stream.data = data
	return stream
