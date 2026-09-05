# Probe: does the tail-bite point penalty fire on stage 1 (snake)?
extends "res://tests/autopilot/probe_base.gd"

const SnakeStage = preload("res://scripts/snake_stage.gd")

var received: Array[int] = []
var deaths: Array[String] = []

func _on_points(amount: int) -> void:
	received.append(amount)

func _ready() -> void:
	await super._ready()
	await settle(2)
	var stage := SnakeStage.new()
	stage.initialize(2026)
	stage.points_earned.connect(_on_points)
	stage.life_lost.connect(func(r): deaths.append(r))
	stage.steer(Vector2i.RIGHT)
	# Grow the snake by hand so a tight loop can reach the body.
	for i in 6:
		stage.body.append(stage.body[stage.body.size() - 1])
	report("length_before", stage.body.size())
	# Tight square: right (already), down, left, up -> head re-enters the body.
	stage.steer(Vector2i.DOWN); stage.step()
	stage.steer(Vector2i.LEFT); stage.step()
	stage.steer(Vector2i.UP); stage.step()
	stage.steer(Vector2i.RIGHT); stage.step()
	report("body", str(stage.body))
	report("still_running", not stage.stopped)
	report("deaths", str(deaths))
	report("length_after", stage.body.size())
	report("emitted", str(received))
	finish()
