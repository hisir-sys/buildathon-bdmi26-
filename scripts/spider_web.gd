extends StaticBody3D

signal cleared

var is_cleared: bool = false


func get_interaction_prompt() -> String:
	if is_cleared:
		return ""
	return "E  REMOVE SPIDER WEB"


func interact() -> void:
	if is_cleared:
		return

	is_cleared = true
	cleared.emit()
	queue_free()