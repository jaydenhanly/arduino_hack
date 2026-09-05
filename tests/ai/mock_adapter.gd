extends Node

signal released(reply: Dictionary)

var requests: Array[Dictionary] = []
var active_requests: int = 0
var maximum_active: int = 0
var busy: bool = false
var closed: bool = false


func request(context: Dictionary, candidates: Array[Dictionary], conversation: bool,
		timeout_seconds: float) -> Dictionary:
	requests.append({"context": context.duplicate(true), "candidates": candidates.duplicate(true),
		"conversation": conversation, "timeout": timeout_seconds})
	active_requests += 1
	maximum_active = maxi(maximum_active, active_requests)
	busy = true
	var result: Dictionary = await released
	active_requests -= 1
	busy = false
	return result


func complete(reply: Dictionary = {}) -> void:
	released.emit(reply)


func shutdown() -> void:
	closed = true
	if busy:
		complete()
