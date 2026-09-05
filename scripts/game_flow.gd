extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const SnakeStage = preload("res://scripts/snake_stage.gd")
const MazeStage = preload("res://scripts/maze_stage.gd")
const FroggerStage = preload("res://scripts/frogger_stage.gd")
const AsteroidsStage = preload("res://scripts/asteroids_stage.gd")
const Board = preload("res://scripts/game_board.gd")
const RetroAudio = preload("res://scripts/retro_audio.gd")
const Pacing = preload("res://scripts/pacing_config.gd")
const RunRng = preload("res://scripts/run_rng.gd")
const Transition = preload("res://scripts/transition_director.gd")
const Presentation = preload("res://scripts/presentation_director.gd")
const Pixel = preload("res://scripts/ai/pixel_controller.gd")
const PixelPanel = preload("res://scripts/pixel_panel.gd")
const Hardware = preload("res://scripts/controller/hardware_feedback.gd")
const JoystickInput = preload("res://scripts/controller/joystick_input.gd")
const ButtonInput = preload("res://scripts/controller/button_input.gd")
const LightSensor = preload("res://scripts/controller/light_sensor.gd")
const SHIFT_SECONDS := Pacing.TRANSITION_SECONDS

enum State { TITLE, PLAYING, SHIFTING, PAUSED, LIFE_LOST, GAME_OVER, VICTORY, EVOLVED, CONVERSATION }

var state := State.TITLE
var previous_state := State.PLAYING
var current_stage := "snake"
var score := 0
var lives := 1
var active_seed := 2026
var stage: RefCounted
var board: Node2D
var clock := 0.0
var damage_reason := ""
var invulnerable := false
var maze_entry: Dictionary = {}
var next_stage: RefCounted
var next_stage_name := ""
var shift_elapsed := 0.0
var playtest: Node
var audio: Node
var pixel: Node
var pixel_panel: Node2D
var hardware: Node
var light_sensor: Node
var transition := Transition.new()
var profile := "normal"
var seed_override := -1
var run_id := 0
var run_started := false
var run_elapsed := 0.0
var payoff_elapsed := 0.0
var near_checkpoint_sent := false
var last_progress := 0
var model_enabled := true
var last_menu_move := -1.0

func _ready() -> void:
	Engine.max_fps = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	JoystickInput.install()
	ButtonInput.install()
	for argument in OS.get_cmdline_user_args():
		if argument == "--demo":
			profile = "demo"
		elif argument == "--no-model":
			model_enabled = false
		elif argument.begins_with("--seed="):
			seed_override = int(argument.trim_prefix("--seed="))
	board = Board.new()
	board.z_index = -1
	add_child(board)
	board.visible = false
	audio = RetroAudio.new()
	add_child(audio)
	hardware = Hardware.new()
	add_child(hardware)
	light_sensor = LightSensor.new()
	add_child(light_sensor)
	pixel = Pixel.new()
	pixel.model_enabled = model_enabled
	add_child(pixel)
	pixel.conversation_finished.connect(_on_conversation_finished)
	pixel.changed.connect(_on_pixel_changed)
	pixel_panel = PixelPanel.new()
	pixel_panel.controller = pixel
	pixel_panel.z_index = 5
	add_child(pixel_panel)
	if OS.is_debug_build() and not OS.has_feature("pixel_shift_release"):
		var playtest_script: Script = load("res://scripts/dev/playtest_manager.gd")
		playtest = playtest_script.new()
		add_child(playtest)
		playtest.initialize(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or (playtest != null and playtest.panel_open):
		return
	if state == State.CONVERSATION:
		_handle_conversation_input(event)
		return
	if event.is_action_pressed("cancel"):
		if state == State.EVOLVED:
			pixel.end_conversation()
			state = State.VICTORY
		else:
			show_title()
	elif event.is_action_pressed("pause"):
		if state == State.PAUSED:
			state = previous_state
		elif state in [State.PLAYING, State.SHIFTING]:
			previous_state = state
			state = State.PAUSED
	elif event.is_action_pressed("confirm"):
		if state in [State.TITLE, State.GAME_OVER, State.VICTORY]:
			start_run()
		elif state == State.PAUSED:
			state = previous_state
		elif state == State.PLAYING and current_stage == "asteroids" and event.is_action_pressed("shoot"):
			_mark_run_started()
			stage.set_controls(Vector2.ZERO, true)
	elif state == State.PLAYING:
		if current_stage == "asteroids" and event.is_action_pressed("shoot"):
			_mark_run_started()
			stage.set_controls(Vector2.ZERO, true)
		else:
			var heading := JoystickInput.direction_for(event)
			if heading != Vector2i.ZERO:
				_mark_run_started()
				stage.steer(heading)
	audio.set_paused(state == State.PAUSED)
	queue_redraw()

func _handle_conversation_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		pixel.end_conversation()
		_on_conversation_finished()
	elif event.is_action_pressed("confirm") and not pixel.choices.is_empty():
		pixel.select_choice(pixel_panel.selected)
		pixel_panel.selected = 0
		audio.play("pellet")
	elif not pixel.choices.is_empty():
		var heading := JoystickInput.direction_for(event)
		if heading != Vector2i.ZERO and clock - last_menu_move >= 0.15:
			var movement := -1 if heading.y < 0 or heading.x < 0 else 1
			pixel_panel.selected = posmod(pixel_panel.selected + movement, pixel.choices.size())
			last_menu_move = clock
	pixel_panel.queue_redraw()

func _process(delta: float) -> void:
	var tools_open: bool = playtest != null and playtest.panel_open
	if state != State.PAUSED and not tools_open:
		clock += delta
		pixel.tick(delta)
		hardware.advance(delta)
		if state == State.PLAYING:
			if current_stage == "asteroids" and stage.started:
				var axis := JoystickInput.vector()
				stage.set_controls(axis, Input.is_action_pressed("shoot"))
			elif current_stage == "frogger" and stage.started:
				var axis := JoystickInput.vector()
				if axis.length() > 0.5:
					stage.steer(Vector2i(signf(axis.x), 0) if absf(axis.x) > absf(axis.y) else Vector2i(0, signf(axis.y)))
			if run_started:
				run_elapsed += delta
			stage.advance(delta)
		elif state == State.SHIFTING:
			var complete := transition.advance(delta)
			shift_elapsed = transition.elapsed
			board.shift_progress = transition.progress
			if complete:
				_enter_next_stage()
		elif state == State.EVOLVED:
			payoff_elapsed += delta
			if payoff_elapsed >= 1.2:
				state = State.CONVERSATION
				pixel_panel.expanded = true
				pixel_panel.selected = 0
				pixel.begin_conversation()
	board.clock = clock
	board.queue_redraw()
	pixel_panel.clock = clock
	pixel_panel.queue_redraw()
	queue_redraw()

func start_run(seed_value: int = -1) -> void:
	active_seed = seed_value if seed_value >= 0 else seed_override
	if active_seed < 0:
		active_seed = RunRng.fresh_seed()
	run_id += 1
	score = 0
	lives = 1
	run_started = false
	run_elapsed = 0.0
	current_stage = "snake"
	maze_entry.clear()
	next_stage = null
	board.shift_target = null
	board.shift_source.clear()
	transition.active = false
	pixel.begin_run(run_id, active_seed)
	pixel_panel.expanded = false
	pixel_panel.selected = 0
	audio.set_paused(false)
	audio.play("start")
	stage = SnakeStage.new()
	stage.initialize(active_seed, Pacing.options(profile, "snake", active_seed))
	_activate_stage()

func _mark_run_started() -> void:
	if run_started:
		return
	run_started = true
	_observe("run_started")

func _activate_stage() -> void:
	near_checkpoint_sent = false
	last_progress = stage.get_progress()
	_connect_stage()
	board.mode = current_stage
	board.stage = stage
	board.visible = true
	state = State.PLAYING
	_checkpoint("stage_start")

func _connect_stage() -> void:
	stage.invulnerable = invulnerable
	stage.points_earned.connect(_on_points)
	stage.life_lost.connect(_on_life_lost)
	stage.objective_completed.connect(_on_objective_completed)
	stage.journal_event.connect(_on_stage_event)
	if current_stage == "snake":
		stage.boost_triggered.connect(_on_boost)

func _on_boost() -> void:
	audio.play("boost")

func _on_points(amount: int) -> void:
	score += amount
	audio.play("apple" if current_stage == "snake" else "pellet")
	hardware.emit_feedback("collect", float(stage.get_progress()) / stage.target)
	var progress: int = stage.get_progress()
	if progress > last_progress:
		last_progress = progress
		_observe("objective_milestone")
		var near_at := maxi(1, mini(stage.target - 1, ceili(stage.target * 0.8)))
		if not near_checkpoint_sent and progress >= near_at and progress < stage.target:
			near_checkpoint_sent = true
			_checkpoint("near_completion")

func _on_stage_event(kind: String, tags: Dictionary) -> void:
	_observe(kind, tags)
	if kind == "danger_escaped":
		hardware.emit_feedback("danger")
	elif kind == "ghost_defeated":
		audio.play("ghost")
	elif kind == "crossing_completed":
		audio.play("crossing")
	elif kind == "asteroid_streak":
		audio.play("impact")

func _on_life_lost(reason: String) -> void:
	lives = 0
	damage_reason = reason
	state = State.GAME_OVER
	_observe("run_ended", {"outcome": "death", "duration_seconds": int(run_elapsed)})
	_checkpoint("death")
	audio.play("damage")
	hardware.emit_feedback("death")

func _on_objective_completed() -> void:
	next_stage_name = Pacing.next_stage(current_stage)
	if next_stage_name.is_empty():
		state = State.EVOLVED
		payoff_elapsed = 0.0
		_observe("run_ended", {"outcome": "victory", "duration_seconds": int(run_elapsed)})
		_observe("victory_reached")
		_checkpoint("victory")
		audio.play("victory")
		hardware.emit_feedback("victory")
		return
	var source: Dictionary = stage.snapshot()
	var next_seed := RunRng.stream_seed(active_seed, next_stage_name)
	var options := Pacing.options(profile, next_stage_name, next_seed)
	match next_stage_name:
		"maze":
			maze_entry = source.duplicate(true)
			next_stage = MazeStage.new()
		"frogger":
			next_stage = FroggerStage.new()
		"asteroids":
			next_stage = AsteroidsStage.new()
	next_stage.initialize(source, options)
	next_stage.invulnerable = invulnerable
	board.shift_source = source
	board.shift_target = next_stage
	board.shift_from = current_stage
	board.shift_to = next_stage_name
	board.shift_progress = 0.0
	board.mode = "shifting"
	transition.begin()
	shift_elapsed = 0.0
	state = State.SHIFTING
	_checkpoint("transformation_started")
	audio.play("shift")
	hardware.emit_feedback("transform")

func _enter_next_stage() -> void:
	current_stage = next_stage_name
	stage = next_stage
	next_stage = null
	_activate_stage()
	_checkpoint("transformation_completed")

func _enter_maze() -> void:
	_enter_next_stage()

func _observe(kind: String, tags: Dictionary = {}) -> void:
	pixel.observe(current_stage, kind, stage.get_progress(), stage.target, score, tags)

func _checkpoint(kind: String) -> void:
	pixel.checkpoint(current_stage, kind, stage.get_progress(), stage.target, score)
	# death/victory/transformation_started each fire their own specific cue right
	# after this call; the generic checkpoint pulse would otherwise land in the
	# same instant and rate-limit that more important cue's vibration to 0ms.
	if kind not in ["death", "victory", "transformation_started"]:
		hardware.emit_feedback("checkpoint")

func _on_pixel_changed() -> void:
	if pixel_panel != null:
		pixel_panel.selected = clampi(pixel_panel.selected, 0, maxi(0, pixel.choices.size() - 1))
		pixel_panel.queue_redraw()
	if hardware != null and not pixel.thinking:
		hardware.emit_feedback("comment")

func _on_conversation_finished() -> void:
	if state not in [State.CONVERSATION, State.EVOLVED]:
		return
	pixel_panel.expanded = false
	state = State.VICTORY

func show_title() -> void:
	pixel.reset()
	pixel_panel.expanded = false
	state = State.TITLE
	board.visible = false
	board.stage = null
	board.shift_target = null
	board.shift_source.clear()
	stage = null
	next_stage = null
	transition.active = false
	audio.set_paused(false)

func restart_stage() -> void:
	start_run(active_seed)

func _draw() -> void:
	if state == State.TITLE:
		_draw_title()
	else:
		var colors := Presentation.palette(current_stage)
		var ink: Color = colors[2]
		Art.text(self, "SCORE %04d" % score, Vector2(14, 12), 1, ink)
		Art.bitmap(self, Art.HEART, Vector2(377, 11), 1, ink)
		draw_line(Vector2(12, 27), Vector2(388, 27), colors[1], 1)
		if state == State.PLAYING and not _stage_started():
			var hint := "JOYSTICK TO BEGIN"
			if current_stage == "asteroids":
				hint = "JOYSTICK MOVE / A FIRE"
			draw_rect(Rect2(12, 181, 376, 11), colors[0])
			Art.centered(self, hint, 183, 1, ink)
		elif state == State.PAUSED:
			_panel("PAUSED", "BUTTON C RESUME", "BUTTON B TITLE")
		elif state == State.GAME_OVER:
			_panel("GAME OVER", damage_reason, "BUTTON A REPLAY")
		elif state == State.EVOLVED:
			_panel("SYSTEM EVOLVED", "RUN COMPLETE / %04d" % score, "PIXEL IS STILL HERE")
		elif state == State.VICTORY:
			_panel("RUN COMPLETE", "SCORE %04d" % score, "BUTTON A REPLAY")
	if playtest != null:
		playtest.draw_overlay(self)

func _stage_started() -> bool:
	return not stage.awaiting_input if current_stage == "snake" else stage.started

func _panel(title: String, line_one: String, line_two: String) -> void:
	draw_rect(Rect2(34, 73, 336, 86), Art.INK)
	draw_rect(Rect2(30, 69, 336, 86), Art.LIGHT)
	draw_rect(Rect2(30, 69, 336, 86), Art.INK, false, 2)
	Art.centered(self, title, 82, 2 if title.length() < 23 else 1)
	Art.centered(self, line_one, 115)
	Art.centered(self, line_two, 139)

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 400, 192), Art.LIGHT)
	draw_rect(Rect2(18, 18, 364, 157), Art.INK, false, 2)
	Art.text(self, "POCKET GAME", Vector2(30, 29), 1, Art.DARK)
	Art.centered(self, "PIXEL", 59, 4)
	for index in 7:
		draw_rect(Rect2(125 + index * 20, 109 + (10 if index > 4 else 0), 15, 15), Art.INK if index == 0 else Art.DARK)
	if fmod(clock, 1.1) < 0.85:
		Art.centered(self, "BUTTON A START", 147, 2)
