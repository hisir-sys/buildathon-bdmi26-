extends Node

signal time_changed(seconds_left: int)
signal time_expired

@export var duration_seconds: float = 600.0

var seconds_left: float
var is_running: bool = true


func _ready() -> void:
	seconds_left = duration_seconds
	time_changed.emit(_display_seconds())


func _process(delta: float) -> void:
	if not is_running:
		return

	seconds_left = maxf(0.0, seconds_left - delta)
	time_changed.emit(_display_seconds())

	if seconds_left <= 0.0:
		is_running = false
		time_expired.emit()


func _display_seconds() -> int:
	return maxi(0, int(ceil(seconds_left)))