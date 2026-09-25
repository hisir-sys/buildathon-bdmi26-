extends Node
# Autoload: EndingStateMachine
# Three-outcome ending coordinator. The visual ending UI remains unchanged;
# this script only decides which existing ending screen copy is shown.

signal ending_evaluated(ending_id: int)

const GameFlow = preload("res://scripts/game_flow.gd")
const ENDING_SCENE_PATH := "res://scenes/ending_screen.tscn"

enum Outcome {
	MISSION_FAILED = 1,
	SPY_MISSION_FAILED = 2,
	MISSION_SUCCESSFUL = 3,
}

var _transition_in_progress: bool = false

func evaluate_and_trigger_ending(
	suspicion_maxed: bool,
	time_expired: bool,
	tasks_complete: bool,
	diamond_taken: bool,
	transition: bool = true
) -> int:
	# Full success requires every cleaning task, both spy assets (pendrive +
	# diamond), and no detection. A completed cleaning shift without the
	# covert objective is the middle ending. Anything else is total failure.
	var ending_id := Outcome.MISSION_FAILED
	if tasks_complete:
		# Calls from older integrations only know about the diamond, so treat
		# suspicion as the deciding detection condition here. main_room.gd uses
		# the stricter pendrive + diamond check before setting ending_id.
		ending_id = Outcome.SPY_MISSION_FAILED if suspicion_maxed or not diamond_taken else Outcome.MISSION_SUCCESSFUL
	
	GameFlow.ending_id = ending_id
	ending_evaluated.emit(ending_id)

	if transition:
		_run_transition()

	return ending_id

func is_transitioning() -> bool:
	return _transition_in_progress

func _on_caught() -> void:
	# Detection no longer creates a fourth/fifth ending. If the room is already
	# being resolved, its three-ending decision owns the result. Otherwise a
	# caught run is routed to the middle outcome only when cleaning is complete.
	if _transition_in_progress:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene := tree.current_scene
	if bool(scene.get("game_over")):
		return

	var tasks_complete := bool(scene.call("_all_tasks_done")) if scene.has_method("_all_tasks_done") else false
	GameFlow.ending_id = Outcome.SPY_MISSION_FAILED if tasks_complete else Outcome.MISSION_FAILED
	_transition_to_ending()

func _transition_to_ending() -> void:
	if _transition_in_progress:
		return
	_transition_in_progress = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tree := get_tree()
	if tree == null:
		_transition_in_progress = false
		return

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
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	await tween.finished
	tree.change_scene_to_file(ENDING_SCENE_PATH)
	_transition_in_progress = false

func _run_transition() -> void:
	_transition_to_ending()
