extends StaticBody3D

signal placed

@export var placement_zone_path: NodePath

@onready var placement_zone: Node3D = get_node(placement_zone_path)
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_carried: bool = false
var is_placed: bool = false


func get_interaction_prompt() -> String:
	if is_placed:
		return ""

	if not is_carried:
		return "E  PICK UP THE SOFA"

	if global_position.distance_to(placement_zone.global_position) <= 1.8:
		return "E  PLACE THE SOFA"

	return "CARRY SOFA TO THE HIGHLIGHTED ZONE"


func interact() -> void:
	if is_placed:
		return

	if not is_carried:
		_pick_up()
	elif global_position.distance_to(placement_zone.global_position) <= 1.8:
		_place()


func _pick_up() -> void:
	var hold_point := get_tree().get_first_node_in_group("hold_point")
	if hold_point == null:
		return

	is_carried = true
	add_to_group("carried_interactable")
	collision_layer = 0
	collision_mask = 0

	reparent(hold_point, false)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3(0.65, 0.65, 0.65)


func _place() -> void:
	is_carried = false
	is_placed = true
	remove_from_group("carried_interactable")

	reparent(get_tree().current_scene, true)
	global_position = Vector3(
		placement_zone.global_position.x,
		0.0,
		placement_zone.global_position.z
	)
	global_rotation = Vector3(0, deg_to_rad(90.0), 0)
	scale = Vector3.ONE
	collision_layer = 1
	collision_mask = 1

	placed.emit()
