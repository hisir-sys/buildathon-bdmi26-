extends StaticBody3D

signal cleaned

var is_cleaned: bool = false


func get_interaction_prompt() -> String:
	if is_cleaned:
		return ""
	return "E  DUST THE FLOOR"


func interact() -> void:
	if is_cleaned:
		return

	is_cleaned = true
	cleaned.emit()
	queue_free()