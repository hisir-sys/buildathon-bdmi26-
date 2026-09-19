extends StaticBody3D

signal interacted

var already_cleaned: bool = false


func get_interaction_prompt() -> String:
	if already_cleaned:
		return ""
	return "E  CLEAN THE TEST OBJECT"


func interact() -> void:
	if already_cleaned:
		return

	already_cleaned = true
	interacted.emit()
	queue_free()