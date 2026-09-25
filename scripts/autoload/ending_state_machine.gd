extends Node
# Autoload: EndingStateMachine
#
# Centralises the run-outcome logic. The project already hands the chosen
# ending off to scenes/ending_screen.tscn through the static GameFlow bag
# (scripts/game_flow.gd) using ending_id 1-4:
#   1 TOTAL_FAILURE       (timer out, diamond left)
#   2 THE_GREED_TRAP      (timer out, diamond taken)
#   3 MISSION_ACCOMPLISHED(tasks done, diamond left)
#   4 SHADOW_VICTORY      (tasks done, diamond taken)
# This autoload keeps that exact numbering so ending_screen.gd's existing
# match statement keeps working untouched, and adds:
#   5 CAUGHT_RED_HANDED   (suspicion maxed out - overrides everything else)
#
# ending_screen.gd needs one additional `5:` branch in its _ending_data()
# match to render bespoke copy/lighting for the new ending - see
# INTEGRATION_GUIDE.md. Until that branch is added, id 5 falls through to
# ending_screen.gd's default ("_:") case, which is ENDING 1's copy, so
# nothing crashes in the meantime.

signal ending_evaluated(ending_id: int)

const GameFlow = preload("res://scripts/game_flow.gd")
const ENDING_SCENE_PATH := "res://scenes/ending_screen.tscn"

enum Outcome {
	TOTAL_FAILURE = 1,
	THE_GREED_TRAP = 2,
	MISSION_ACCOMPLISHED = 3,
	SHADOW_VICTORY = 4,
	CAUGHT_RED_HANDED = 5,
}

var _transition_in_progress: bool = false


func _ready() -> void:
	# If SuspicionManager is present, wire the "caught" signal automatically
	# so any scene gets ending 5 for free without extra glue code.
	if has_node("/root/SuspicionManager"):
		var manager := get_node("/root/SuspicionManager")
		if manager.has_signal("caught_ending_triggered"):
			manager.connect("caught_ending_triggered", _on_caught)


## Works out which of the 5 endings applies and stores it on GameFlow, ready
## for ending_screen.tscn to read. Does NOT change scenes by itself unless
## `transition` is true, so callers that already manage their own fade
## (like main_room.gd's _finish_game) can pass transition = false and keep
## doing their own scene change.
func evaluate_and_trigger_ending(
	suspicion_maxed: bool,
	time_expired: bool,
	tasks_complete: bool,
	diamond_taken: bool,
	transition: bool = true
) -> int:
	var ending_id: int

	if suspicion_maxed:
		ending_id = Outcome.CAUGHT_RED_HANDED
	elif tasks_complete:
		ending_id = Outcome.SHADOW_VICTORY if diamond_taken else Outcome.MISSION_ACCOMPLISHED
	elif time_expired:
		ending_id = Outcome.THE_GREED_TRAP if diamond_taken else Outcome.TOTAL_FAILURE
	else:
		# Neither the timer nor the tasks have resolved yet - nothing to do.
		ending_id = Outcome.TOTAL_FAILURE

	GameFlow.ending_id = ending_id
	GameFlow.diamond_taken = diamond_taken
	ending_evaluated.emit(ending_id)

	if transition:
		_run_transition()

	return ending_id


## True while this autoload is mid-fade to the ending screen. main_room.gd
## checks this before starting its own transition (timer-out / tasks-done),
## so the two can't both call change_scene_to_file for the same run.
func is_transitioning() -> bool:
	return _transition_in_progress


func _on_caught() -> void:
	if _transition_in_progress:
		return

	# If the current scene already claimed the ending itself (main_room.gd's
	# own game_over flag, set the instant its timer/tasks path fires), don't
	# also trigger the caught ending on top of it - whichever happened first
	# wins. Both checks below happen synchronously with no yield in between,
	# so this is race-safe despite looking like two separate reads.
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var scene := tree.current_scene
		if bool(scene.get("game_over")):
			return

	var taken := bool(GameFlow.diamond_taken)
	evaluate_and_trigger_ending(true, false, false, taken, true)


## Canvas fade-to-black + audio dampening + scene swap to the ending screen.
## Mirrors the fade main_room.gd already performs for the other 4 endings so
## the caught ending feels consistent rather than abrupt.
func _run_transition() -> void:
	if _transition_in_progress:
		return
	_transition_in_progress = true

	var tree := get_tree()
	if tree == null:
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Duck the master bus instead of touching individual players, so any
	# ambience/music already playing in the current scene fades out cleanly.
	var master_bus := AudioServer.get_bus_index("Master")
	var start_db := AudioServer.get_bus_volume_db(master_bus)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.05, 0.0, 0.0, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_layer.add_child(fade)

	var root := tree.current_scene
	if root != null:
		root.add_child(fade_layer)
	else:
		add_child(fade_layer)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(master_bus, db),
		start_db,
		start_db - 18.0,
		1.0
	)
	await tween.finished

	tree.change_scene_to_file(ENDING_SCENE_PATH)
	# Restore the bus for the next scene/run.
	AudioServer.set_bus_volume_db(master_bus, start_db)
	_transition_in_progress = false
