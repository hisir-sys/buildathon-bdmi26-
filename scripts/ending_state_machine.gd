extends Node

## AUTOLOAD SINGLETON - register this as "EndingStateMachine" in
## Project Settings -> Autoload (path: res://scripts/ending_state_machine.gd).
##
## This deliberately does NOT assume how your ending screens are built - it
## works out which of the 5 endings the run resolved to, dips the audio,
## does an optional fallback fade, and emits `ending_triggered`. Connect
## your actual ending-screen / dialogue-panel script to that signal (you
## already have ending_screen.gd + game_flow.gd from earlier - just connect
## one of their functions to this signal rather than duplicating the fade
## logic in two places).
##
## Call evaluate_and_trigger_ending() from wherever you currently detect
## "timer hit 0", "tasks_complete flipped true", etc. It only resolves
## once per run - later calls after that are ignored.

signal ending_triggered(ending_id: StringName, ending_index: int)

enum Ending {
	TOTAL_FAILURE,        # 1 - timer expired, contract not retrieved, diamond untouched
	THE_GREED_TRAP,       # 2 - timer expired, diamond stolen, contract forgotten
	MISSION_ACCOMPLISHED, # 3 - contract secured, diamond left alone
	SHADOW_VICTORY,       # 4 - contract secured, diamond stolen
	CAUGHT_RED_HANDED,    # 5 - suspicion maxed out
}

const ENDING_NAMES: Dictionary = {
	Ending.TOTAL_FAILURE: &"TOTAL_FAILURE",
	Ending.THE_GREED_TRAP: &"THE_GREED_TRAP",
	Ending.MISSION_ACCOMPLISHED: &"MISSION_ACCOMPLISHED",
	Ending.SHADOW_VICTORY: &"SHADOW_VICTORY",
	Ending.CAUGHT_RED_HANDED: &"CAUGHT_RED_HANDED",
}

# Optional: assign a CanvasLayer with a full-rect ColorRect named "Fade" as
# a child, and this will fade it to black on its own. Leave empty if your
# existing ending_screen.gd already owns the transition - then just listen
# for ending_triggered and drive your own screen from there.
@export var fallback_overlay: CanvasLayer
@export var audio_dampen_bus: String = "Master"
@export var audio_dampen_db: float = -14.0
@export var fade_duration: float = 1.2

var has_resolved: bool = false


func evaluate_and_trigger_ending(
	suspicion_maxed: bool,
	time_expired: bool,
	tasks_complete: bool,
	diamond_taken: bool
) -> void:
	if has_resolved:
		return

	var ending: Ending
	if suspicion_maxed:
		ending = Ending.CAUGHT_RED_HANDED
	elif tasks_complete and diamond_taken:
		ending = Ending.SHADOW_VICTORY
	elif tasks_complete and not diamond_taken:
		ending = Ending.MISSION_ACCOMPLISHED
	elif time_expired and diamond_taken:
		ending = Ending.THE_GREED_TRAP
	elif time_expired and not diamond_taken:
		ending = Ending.TOTAL_FAILURE
	else:
		# None of the resolving conditions are true - this function got
		# called too early (e.g. suspicion isn't maxed AND time hasn't
		# expired AND tasks aren't complete). Nothing to resolve yet.
		push_warning("EndingStateMachine: evaluate_and_trigger_ending() called with no resolving condition true.")
		return

	has_resolved = true
	_play_transition()
	ending_triggered.emit(ENDING_NAMES[ending], ending)


func _play_transition() -> void:
	var dampen_tween := create_tween()
	dampen_tween.tween_method(_set_bus_db, 0.0, audio_dampen_db, fade_duration)

	if fallback_overlay == null:
		return
	fallback_overlay.visible = true
	var canvas_fade := fallback_overlay.get_node_or_null("Fade") as ColorRect
	if canvas_fade == null:
		return
	canvas_fade.color.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(canvas_fade, "color:a", 1.0, fade_duration)


func _set_bus_db(target_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(audio_dampen_bus)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, target_db)


## Call at the start of a new run so a previous run's resolved ending and
## dampened audio don't carry over.
func reset_run() -> void:
	has_resolved = false
	if fallback_overlay != null:
		fallback_overlay.visible = false
	_set_bus_db(0.0)
