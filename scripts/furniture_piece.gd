extends Area3D
class_name FurniturePiece

@export var target_spot_path: NodePath
var is_placed: bool = false


func get_interaction_prompt() -> String:
	return "Place"


func interact() -> void:
	if is_placed:
		return

	var target_spot := get_node(target_spot_path) as Node3D
	if target_spot == null:
		return

	global_position = target_spot.global_position
	global_rotation = target_spot.global_rotation
	is_placed = true

	get_node("CollisionShape3D").disabled = true

	var furniture_task := get_tree().get_first_node_in_group("furniture_task")
	if furniture_task:
		furniture_task.piece_placed()
