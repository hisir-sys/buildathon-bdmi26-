extends Area3D
class_name DirtySpot

func get_interaction_prompt() -> String:
	return "Clean"

func interact() -> void:
	var dusting_task := get_tree().get_first_node_in_group("dusting_task")
	if dusting_task:
		dusting_task.clean_spot(self)
