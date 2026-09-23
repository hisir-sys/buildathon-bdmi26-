extends Node

signal time_changed(seconds_left: int)
signal time_expired
signal key_changed(has_key: bool)
signal diamond_decided(taken: bool)

@export var duration_seconds: float = 600.0

var seconds_left: float
var is_running: bool = true

# Chest state. The endings (added later) read these:
#   diamond_resolved - the player has opened the chest and made the choice
#   diamond_taken    - true = STEAL THE DIAMOND, false = LEAVE THE DIAMOND
var has_key: bool = false
var diamond_resolved: bool = false
var diamond_taken: bool = false


func _ready() -> void:
	add_to_group("game_manager")
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


func set_has_key(value: bool) -> void:
	has_key = value
	key_changed.emit(has_key)


func resolve_diamond(taken: bool) -> void:
	diamond_resolved = true
	diamond_taken = taken
	diamond_decided.emit(taken)


func _display_seconds() -> int:
	return maxi(0, int(ceil(seconds_left)))
