extends Node
# Autoload: SuspicionManager
#
# Tracks how "hot" the player's cover is. Snooping (lockpicking, drawers,
# the chest) adds suspicion; authentic cleaning tasks (dust, spills, mirrors)
# remove it. Reaching 100 ends the run immediately via
# EndingStateMachine.CAUGHT_RED_HANDED.
#
# Register as an autoload named "SuspicionManager" in Project Settings so it
# is reachable from anywhere as a global singleton, e.g.:
#   SuspicionManager.add_suspicion(25.0)

signal suspicion_changed(new_value: float, max_value: float)
signal caught_ending_triggered

const MAX_SUSPICION := 100.0
const COVER_DISCOUNT := 0.5  # 50% less incoming suspicion while in cover.

@export var suspicion_multiplier: float = 1.0
@export var is_in_cover_state: bool = false

var current_suspicion: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, MAX_SUSPICION)
		if is_equal_approx(clamped, current_suspicion):
			return
		current_suspicion = clamped
		suspicion_changed.emit(current_suspicion, MAX_SUSPICION)
		if current_suspicion >= MAX_SUSPICION and not _caught_fired:
			_caught_fired = true
			caught_ending_triggered.emit()

var _caught_fired: bool = false


func _ready() -> void:
	# Runs before gameplay nodes read it, so it should be safe as an autoload.
	suspicion_changed.emit(current_suspicion, MAX_SUSPICION)


## Adds suspicion, scaled by suspicion_multiplier and halved while in cover.
func add_suspicion(amount: float) -> void:
	if amount <= 0.0:
		return
	var scaled := amount * suspicion_multiplier
	if is_in_cover_state:
		scaled *= COVER_DISCOUNT
	current_suspicion += scaled


## Safely lowers suspicion, clamped at 0.
func reduce_suspicion(amount: float) -> void:
	if amount <= 0.0:
		return
	current_suspicion -= amount


## Call when the player picks up / uses a legitimate cleaning tool (mop,
## duster, etc). Call again with false when they put it away.
func set_cover_state(active: bool) -> void:
	is_in_cover_state = active


## Run modifiers (RunGenerator) adjust this - e.g. "Squeaky Shoes" = 1.2.
func set_suspicion_multiplier(value: float) -> void:
	suspicion_multiplier = maxf(0.0, value)


## Resets state for a fresh run (call from RunGenerator on run start).
func reset_run() -> void:
	_caught_fired = false
	suspicion_multiplier = 1.0
	is_in_cover_state = false
	current_suspicion = 0.0
	suspicion_changed.emit(current_suspicion, MAX_SUSPICION)
