extends Node2D

const Grid = preload("res://scripts/grid.gd")
const Art = preload("res://scripts/pixel_art.gd")
const Cph = preload("res://scripts/copenhagen.gd")
const SnakeStage = preload("res://scripts/snake_stage.gd")
const Board = preload("res://scripts/game_board.gd")
const MazeStage = preload("res://scripts/maze_stage.gd")
const ArenaStage = preload("res://scripts/arena_stage.gd")
const SHIFT_SECONDS := 2.4
const ARENA_SHIFT_SECONDS := 1.8
const RetroAudio = preload("res://scripts/retro_audio.gd")

enum State { TITLE, PLAYING, SHIFTING, PAUSED, LIFE_LOST, GAME_OVER, VICTORY }

var state := State.TITLE
var previous_state := State.PLAYING
var current_stage := "snake"
var score := 0
var lives := 5
var active_seed := 2026
var stage: RefCounted
var board: Node2D
var clock := 0.0
var damage_reason := ""
var invulnerable := false
var maze_entry: Dictionary = {}
var arena_entry: Dictionary = {}
var next_stage: RefCounted
var shift_elapsed := 0.0
var playtest: Node
var audio: Node
var start_stage := "snake"
var last_alarm := -1

func _ready() -> void:
	Engine.max_fps = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Grid.install_inputs()
	board = Board.new()
	board.z_index = -1
	add_child(board)
	board.visible = false
	audio = RetroAudio.new()
	add_child(audio)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			start_stage = argument.trim_prefix("--stage=")
	if OS.is_debug_build() and not OS.has_feature("pixel_shift_release"):
		var playtest_script: Script = load("res://scripts/dev/playtest_manager.gd")
		playtest = playtest_script.new()
		add_child(playtest)
		playtest.initialize(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if playtest != null and playtest.panel_open:
		return
	if event.is_action_pressed("cancel"):
		state = State.TITLE
		board.visible = false
		audio.set_paused(false)
	elif event.is_action_pressed("pause"):
		if state == State.PAUSED:
			state = previous_state
		elif state in [State.PLAYING, State.SHIFTING]:
			previous_state = state
			state = State.PAUSED
		elif state == State.TITLE:
			Art.next_theme()
	elif state == State.TITLE and event is InputEventKey and event.pressed and event.keycode == KEY_3:
		start_stage = "arena"
		start_run()
	elif event.is_action_pressed("confirm"):
		if state in [State.TITLE, State.GAME_OVER, State.VICTORY]:
			start_run()
		elif state == State.LIFE_LOST:
			resume_stage()
		elif state == State.PAUSED:
			state = previous_state
	elif state == State.PLAYING:
		stage.steer(Grid.direction_for(event))
	audio.set_paused(state == State.PAUSED)
	queue_redraw()

func _process(delta: float) -> void:
	if state != State.PAUSED:
		clock += delta
		board.clock = clock
	var tools_open: bool = playtest != null and playtest.panel_open
	if state == State.PLAYING and not tools_open:
		stage.advance(delta)
		if current_stage == "arena" and state == State.PLAYING and stage.started and stage.meltdown():
			var second := int(stage.survived)
			if second != last_alarm:
				last_alarm = second
				audio.play("alarm")
	elif state == State.SHIFTING and not tools_open:
		var length := shift_length()
		shift_elapsed = minf(length, shift_elapsed + delta)
		board.shift_progress = shift_elapsed / length
		if shift_elapsed >= length:
			_enter_next_stage()
	board.queue_redraw()
	queue_redraw()

func start_run(seed_value: int = 2026) -> void:
	active_seed = seed_value
	score = 0
	lives = 5
	current_stage = "snake"
	maze_entry.clear()
	arena_entry.clear()
	if start_stage == "arena":
		current_stage = "arena"
		arena_entry = {"body": [Vector2i(24, 12), Vector2i(23, 12), Vector2i(22, 12), Vector2i(21, 12)], "direction": Vector2i.RIGHT}
	audio.play("start")
	restart_stage()

func restart_stage() -> void:
	audio.set_paused(false)
	if current_stage == "maze":
		stage = MazeStage.new()
		stage.initialize(maze_entry)
	elif current_stage == "arena":
		stage = ArenaStage.new()
		stage.initialize(arena_entry, active_seed)
	else:
		stage = SnakeStage.new()
		stage.initialize(active_seed)
	_connect_stage()
	board.mode = current_stage
	board.stage = stage
	board.visible = true
	state = State.PLAYING

# Losing a life costs a heart, not the run so far: the stage keeps going with the
# same body, the same score and the same board.
func resume_stage() -> void:
	if stage == null:
		restart_stage()
		return
	audio.set_paused(false)
	stage.resume()
	state = State.PLAYING

func _connect_stage() -> void:
	stage.invulnerable = invulnerable
	stage.points_earned.connect(_on_points)
	stage.life_lost.connect(_on_life_lost)
	stage.objective_completed.connect(_on_objective_completed)
	if current_stage != "maze":
		stage.tail_severed.connect(_on_tail_severed)
	if current_stage == "snake":
		stage.boost_triggered.connect(_on_boost)

func _on_tail_severed(_segments: int) -> void:
	audio.play("damage")

func _on_boost() -> void:
	audio.play("boost")

func _on_points(amount: int) -> void:
	score = maxi(0, score + amount)
	if amount == ArenaStage.KO_POINTS and current_stage == "arena":
		audio.play("ko")
	elif amount > 0 and amount < 100:
		audio.play("apple" if current_stage == "snake" else "pellet")

func _on_life_lost(reason: String) -> void:
	lives -= 1
	damage_reason = reason
	state = State.GAME_OVER if lives == 0 else State.LIFE_LOST
	audio.play("damage")

func _on_objective_completed() -> void:
	if current_stage == "snake":
		maze_entry = stage.snapshot()
		next_stage = MazeStage.new()
		next_stage.initialize(maze_entry)
		shift_elapsed = 0.0
		board.shift_source = maze_entry
		board.shift_target = next_stage
		board.shift_progress = 0.0
		board.mode = "shifting"
		state = State.SHIFTING
		audio.play("shift")
	elif current_stage == "maze":
		arena_entry = ArenaStage.from_maze(stage.snapshot())
		next_stage = ArenaStage.new()
		next_stage.initialize(arena_entry, active_seed)
		shift_elapsed = 0.0
		board.shift_source = {"walls": stage.walls.duplicate(), "pellets": stage.pellets.duplicate(), "ghost": stage.ghost, "body": stage.body.duplicate()}
		board.shift_target = next_stage
		board.shift_progress = 0.0
		board.mode = "shifting_arena"
		state = State.SHIFTING
		audio.play("shift")
	else:
		state = State.VICTORY
		audio.play("victory")

func shift_length() -> float:
	return ARENA_SHIFT_SECONDS if board.mode == "shifting_arena" else SHIFT_SECONDS

func _enter_next_stage() -> void:
	if board.mode == "shifting_arena":
		_enter_arena()
	else:
		_enter_maze()

func _enter_maze() -> void:
	current_stage = "maze"
	stage = next_stage
	_connect_stage()
	board.stage = stage
	board.mode = "maze"
	state = State.PLAYING

func _enter_arena() -> void:
	current_stage = "arena"
	stage = next_stage
	_connect_stage()
	board.stage = stage
	board.mode = "arena"
	state = State.PLAYING

func _draw() -> void:
	if state == State.TITLE:
		_draw_title()
		if playtest != null:
			playtest.draw_overlay(self)
		return
	Art.text(self, {"snake": "01 SNAKE", "maze": "02 MAZE", "arena": "03 ARENA"}[current_stage], Vector2(14, 12))
	Art.text(self, "SCORE %04d" % score, Vector2(154, 12))
	for index in 5:
		var heart: Color = (Cph.C.red if Art.cph() else Art.INK) if index < lives else Art.MID
		Art.bitmap(self, Art.HEART, Vector2(312 + index * 12, 11), 1, heart)
	draw_line(Vector2(12, 28), Vector2(388, 28), Art.DARK, 2)
	if current_stage == "snake":
		Art.centered(self, "APPLES %d/%d   BUTTON C PAUSE" % [stage.apples, SnakeStage.APPLE_TARGET], 222)
	elif current_stage == "maze":
		Art.centered(self, "LURE THE GHOST INTO YOUR TAIL", 222)
	else:
		Art.centered(self, "SURVIVE %03d   FOOD -5S   SNAKES %d   KO %d" % [stage.seconds_left(), stage.bots.size(), stage.kos], 222)
	if state == State.SHIFTING and board.mode == "shifting_arena":
		Art.centered(self, "PIXEL SHIFT / THE ARENA OPENS", 31)
	elif state == State.PLAYING and current_stage == "arena" and stage.started and stage.meltdown():
		if fmod(clock, 0.5) < 0.3:
			Art.centered(self, "MELTDOWN! THE ARENA IS BURNING", 31)
	elif state == State.PLAYING and current_stage == "arena" and stage.started and stage.banner_visible():
		if fmod(clock, 0.4) < 0.28:
			Art.centered(self, stage.banner, 31, 2)
	elif state == State.SHIFTING:
		Art.centered(self, "PIXEL SHIFT / THE RULES ARE CHANGING", 31)
	elif state == State.PLAYING and current_stage == "snake" and stage.awaiting_input:
		if stage.direction == Vector2i.ZERO:
			Art.centered(self, "ONE PIXEL. YOUR MOVE.", 61)
			Art.centered(self, "JOYSTICK TO BEGIN", 77, 1, Art.DARK)
		else:
			Art.centered(self, "JOYSTICK TO CONTINUE", 31)
	elif state == State.PLAYING and current_stage == "maze" and not stage.started:
		Art.centered(self, "YOUR TAIL IS NOW A WEAPON", 212)
		Art.centered(self, "JOYSTICK TO HUNT", 31)
	elif state == State.PLAYING and current_stage == "arena" and not stage.started:
		Art.centered(self, "BIG AND SLOW. THEY ARE SMALL AND FAST.", 212)
		Art.centered(self, "JOYSTICK TO SURVIVE", 31)
	elif state == State.PAUSED:
		_panel("PAUSED", "BUTTON C RESUME", "BUTTON B TITLE")
	elif state == State.LIFE_LOST:
		_panel(damage_reason, "%d LIVES LEFT" % lives, "BUTTON A CONTINUE")
	elif state == State.GAME_OVER:
		_panel("GAME OVER", "SCORE %04d" % score, "BUTTON A REPLAY")
	elif state == State.VICTORY:
		_panel("ARENA SURVIVED!", "PIXEL SHIFT COMPLETE / %04d" % score, "BUTTON A REPLAY")
	if playtest != null:
		playtest.draw_overlay(self)

func _panel(title: String, line_one: String, line_two: String, top: int = 85, height: int = 78) -> void:
	draw_rect(Rect2(42, top + 4, 320, height), Art.INK)
	draw_rect(Rect2(38, top, 320, height), Art.LIGHT)
	draw_rect(Rect2(38, top, 320, height), Art.INK, false, 2)
	Art.centered(self, title, top + 11, 2 if title.length() < 20 else 1)
	Art.centered(self, line_one, top + 36)
	Art.centered(self, line_two, top + height - 15)

func _draw_title() -> void:
	var cph := Art.cph()
	draw_rect(Rect2(12, 12, 376, 216), Art.INK, false, 2)
	Art.text(self, "COPENHAGEN / ONE CONTINUOUS GAME" if cph else "RETRO-AI / ONE CONTINUOUS GAME", Vector2(24, 24), 1, Art.DARK)
	# The skyline needs the bottom 30 px, so the Copenhagen layout sits 10 px higher.
	var lift := 10 if cph else 0
	Art.centered(self, "PIXEL", 48 - lift, 4)
	Art.centered(self, "SHIFT", 83 - lift, 4)
	for index in 7:
		var position_value := Vector2(123 + index * 20, 127 - lift + (8 if index > 3 else 0))
		draw_rect(Rect2(position_value, Vector2(16, 16)), board._head() if index == 0 else board._body())
		if index == 0:
			draw_rect(Rect2(position_value + Vector2(3, 3), Vector2(3, 3)), board._eye())
	Art.centered(self, "A LITTLE SNAKE. A BIG CITY." if cph else "A LITTLE SNAKE. A BIG CHANGE.", 157 - lift)
	if fmod(clock, 1.1) < 0.85:
		Art.centered(self, "BUTTON A START", 165 if cph else 181, 2)
	Art.centered(self, "JOYSTICK MOVE  /  BUTTON C STYLE", 184 if cph else 211, 1, Art.DARK)
	if cph:
		# Five landmarks along the bottom edge, the same sprites the maze walls use.
		Cph.skyline(self, 21, 198)
	var style := "STYLE " + Art.theme.to_upper()
	Art.text(self, style, Vector2(386 - (style.length() * 6 - 1), 24), 1, Art.DARK)
	if start_stage == "arena":
		Art.text(self, "ARENA ONLY", Vector2(316, 36), 1, Art.DARK)
