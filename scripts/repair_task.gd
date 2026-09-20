extends StaticBody3D

signal completed(task_kind: String)

@export var task_kind: String = "panel"
@export var task_label: String = "REPAIR"
@export var action_label: String = "REPAIR"
@export var duration_seconds: float = 6.0

var is_complete: bool = false
var is_working: bool = false
var elapsed: float = 0.0
var status_light: MeshInstance3D


func _ready() -> void:
	status_light = get_node_or_null("StatusLight") as MeshInstance3D


func _process(delta: float) -> void:
	if not is_working:
		return
	elapsed = minf(duration_seconds, elapsed + delta)
	if status_light != null:
		status_light.visible = fmod(elapsed, 0.35) > 0.12
	if elapsed >= duration_seconds:
		is_working = false
		is_complete = true
		if status_light != null:
			status_light.visible = true
		completed.emit(task_kind)


func get_interaction_prompt() -> String:
	if is_complete:
		return "%s COMPLETE" % task_label
	if is_working:
		return "%s  %02d%%" % [task_label, int((elapsed / duration_seconds) * 100.0)]
	return "E  %s  (%d SEC)" % [action_label, int(duration_seconds)]


func interact() -> void:
	if is_complete or is_working:
		return
	is_working = true