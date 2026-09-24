extends Node

## AUTOLOAD SINGLETON - register this as "SuspicionManager" in
## Project Settings -> Autoload (path: res://scripts/suspicion_manager.gd).
## Once registered, call it from anywhere as SuspicionManager.add_suspicion(10.0)
## without needing a node reference.
##
## Tracks how close the player is to blowing their cover. Reaching
## MAX_SUSPICION fires caught_ending_triggered exactly once per run.

signal suspicion_changed(new_value: float, max_value: float)
signal caught_ending_triggered

const MAX_SUSPICION: float = 100.0
# While is_in_cover_state is true (holding/using a legitimate cleaning
# tool), incoming suspicion is halved - matches the spec's "actively
# performing cleaning tasks reduces risk" framing.
const COVER_STATE_REDUCTION: float = 0.5

var current_suspicion: float = 0.0
var suspicion_multiplier: float = 1.0
var is_in_cover_state: bool = false

# Guards against firing caught_ending_triggered more than once if
# add_suspicion keeps getting called after suspicion is already maxed.
var _has_triggered_caught_ending: bool = false


func add_suspicion(amount: float) -> void:
	if amount <= 0.0:
		return

	var scaled_amount := amount * suspicion_multiplier
	if is_in_cover_state:
		scaled_amount *= COVER_STATE_REDUCTION

	current_suspicion = clampf(current_suspicion + scaled_amount, 0.0, MAX_SUSPICION)
	suspicion_changed.emit(current_suspicion, MAX_SUSPICION)

	if current_suspicion >= MAX_SUSPICION and not _has_triggered_caught_ending:
		_has_triggered_caught_ending = true
		caught_ending_triggered.emit()


func reduce_suspicion(amount: float) -> void:
	if amount <= 0.0:
		return
	current_suspicion = clampf(current_suspicion - amount, 0.0, MAX_SUSPICION)
	suspicion_changed.emit(current_suspicion, MAX_SUSPICION)


## Call this whenever the player picks up / puts down a legitimate cleaning
## tool (mop, duster, etc.) so incoming suspicion gets the cover discount.
func set_cover_state(active: bool) -> void:
	is_in_cover_state = active


## Used by RunGenerator's per-run modifiers (e.g. "Squeaky Shoes" = 1.2).
func set_multiplier(multiplier: float) -> void:
	suspicion_multiplier = maxf(multiplier, 0.0)


## Call at the start of a new run (e.g. from your start menu / restart
## flow) so a previous run's suspicion doesn't carry over.
func reset_run() -> void:
	current_suspicion = 0.0
	suspicion_multiplier = 1.0
	is_in_cover_state = false
	_has_triggered_caught_ending = false
	suspicion_changed.emit(current_suspicion, MAX_SUSPICION)
