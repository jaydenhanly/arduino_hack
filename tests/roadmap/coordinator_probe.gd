extends SceneTree

const Pacing = preload("res://scripts/pacing_config.gd")
const RunRng = preload("res://scripts/run_rng.gd")
const Hardware = preload("res://scripts/controller/hardware_feedback.gd")
const Grid = preload("res://scripts/grid.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, valid: bool) -> void:
	checks += 1
	if not valid:
		failures.append(label)
		push_error(label)

func _run() -> void:
	check("panel never overlaps grid", Grid.ORIGIN.y + Grid.SIZE.y * Grid.CELL < 192)
	check("subsystem seeds repeat", RunRng.stream_seed(42, "maze") == RunRng.stream_seed(42, "maze"))
	check("subsystem seeds independent", RunRng.stream_seed(42, "maze") != RunRng.stream_seed(42, "pixel"))
	check("last stage is terminal", Pacing.next_stage("asteroids").is_empty())
	var feedback := Hardware.new()
	feedback.emit_feedback("comment")
	check("periodic comments never vibrate", feedback.last_event.pulse_ms == 0)
	feedback.emit_feedback("checkpoint")
	check("checkpoint has light haptic", feedback.last_event.pulse_ms > 0 and feedback.last_event.pulse_ms <= 20)
	feedback.emit_feedback("collect")
	check("haptics have a rate limit", feedback.last_event.pulse_ms == 0)
	feedback.advance(1.0)
	feedback.emit_feedback("victory", 2.0)
	check("progress clamps", feedback.last_event.progress == 1.0)
	check("matrix remains optional", feedback.last_event.matrix_rows.size() == 8)
	check("matrix matches supplied bridge geometry", feedback.last_event.matrix_frame.size() == 104)
	feedback.free()
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	game.model_enabled = false
	root.add_child(game)
	game.set_process(false)
	for profile in ["demo", "normal"]:
		game.profile = profile
		for stage_name in Pacing.STAGES:
			for preset in ["start", "midpoint", "near-completion"]:
				game.playtest.load_preset(stage_name, preset)
				var label := "%s %s %s" % [profile, stage_name, preset]
				check(label + " built", game.playtest.last_error.is_empty())
				check(label + " stage", game.current_stage == stage_name)
				check(label + " playing", game.state == game.State.PLAYING)
				check(label + " one life", game.lives == 1)
				var target := int(Pacing.TARGETS[profile][stage_name])
				var expected := 0 if preset == "start" else (target - 1 if preset == "near-completion" else int(target / 2))
				check(label + " progress", game.stage.get_progress() == expected)
				check(label + " safe first input", not game._stage_started())
		for stage_name in ["frogger", "asteroids"]:
			game.playtest.load_preset(stage_name, "start")
			Input.action_press("move_up")
			Input.action_press("shoot")
			game._process(0.1)
			check(profile + " " + stage_name + " ignores held previous-stage input", not game.stage.started)
			Input.action_release("move_up")
			Input.action_release("shoot")
			if stage_name == "asteroids":
				var fire := InputEventAction.new()
				fire.action = "shoot"
				fire.pressed = true
				game._unhandled_input(fire)
				check(profile + " fresh fire starts space without movement", game.stage.started and game.stage.firing)
		game.playtest.load_preset("snake", "near-completion")
		check(profile + " near-completion checkpoint before final apple", game.near_checkpoint_sent)
		game.playtest.complete_objective()
		check(profile + " real completion begins transition", game.state == game.State.SHIFTING)
		check(profile + " transform vibrates (not swallowed by the checkpoint cue)", game.hardware.last_event.pulse_ms == 45)
		game.previous_state = game.state
		game.state = game.State.PAUSED
		game._process(2.0)
		check(profile + " pause freezes transition", game.shift_elapsed == 0)
		game.state = game.State.SHIFTING
		game._process(2.99)
		check(profile + " transition does not end early", game.state == game.State.SHIFTING)
		game._process(0.02)
		check(profile + " transition ends after three seconds", game.current_stage == "maze")
	game.start_run(77)
	var first_run: int = game.run_id
	game._mark_run_started()
	game._on_life_lost("TEST COLLISION")
	check("fatal hit ends run", game.state == game.State.GAME_OVER and game.lives == 0)
	check("death vibrates (not swallowed by the checkpoint cue)", game.hardware.last_event.pulse_ms == 70)
	game.playtest.load_preset("asteroids", "near-completion")
	game.playtest.complete_objective()
	check("final stage completion reaches victory", game.state == game.State.EVOLVED)
	check("victory vibrates (not swallowed by the checkpoint cue)", game.hardware.last_event.pulse_ms == 60)
	game.start_run(77)
	check("same seed replay gets new run identity", game.run_id != first_run)
	check("replay resets score and one life", game.score == 0 and game.lives == 1)
	for entry in game.pixel.journal.entries():
		check("journal has no previous run", entry.run_id == game.run_id)
	game.show_title()
	check("title clears journal", game.pixel.journal.entries().is_empty())
	for voice in game.audio.voices:
		voice.stop()
	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	print("COORDINATOR_CHECKS %d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
