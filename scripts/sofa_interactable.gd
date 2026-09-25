extends StaticBody3D

signal placed

@export var item_label: String = "SOFA"
@export var placement_position: Vector3 = Vector3(-5.5, 0.0, 1.8)
@export var placement_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var highlight_size: Vector3 = Vector3(3.8, 0.04, 1.65)
@export var carry_scale: float = 0.65
# Props that are already standing in the room (like the cabinet) start with
# this on - no corner pile, no pink target, just pick up and drop anywhere.
@export var starts_placed: bool = false

var is_carried: bool = false
var has_been_placed: bool = false
var placement_highlight: MeshInstance3D
var details_built: bool = false


func _ready() -> void:
	has_been_placed = starts_placed
	if item_label == "SOFA":
		_build_sofa_details()


func get_interaction_prompt() -> String:
	if not is_carried:
		return "E  MOVE THE %s" % item_label if has_been_placed else "E  PICK UP THE %s" % item_label

	if has_been_placed:
		return "E  PUT DOWN THE %s" % item_label

	if global_position.distance_to(placement_position) <= 1.8:
		return "E  PLACE THE %s" % item_label

	return "CARRY %s TO THE PINK HIGHLIGHT" % item_label


func interact() -> void:
	if not is_carried:
		_pick_up()
		return

	if has_been_placed:
		_drop_here()
	elif global_position.distance_to(placement_position) <= 1.8:
		_place_at_zone()


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
	scale = Vector3.ONE * carry_scale

	if not has_been_placed:
		_show_placement_highlight()


func _place_at_zone() -> void:
	is_carried = false
	has_been_placed = true
	remove_from_group("carried_interactable")

	reparent(get_tree().current_scene, true)
	global_position = placement_position
	global_rotation = Vector3(
		deg_to_rad(placement_rotation_degrees.x),
		deg_to_rad(placement_rotation_degrees.y),
		deg_to_rad(placement_rotation_degrees.z)
	)
	scale = Vector3.ONE
	collision_layer = 1
	collision_mask = 1
	_hide_placement_highlight()

	placed.emit()


func _drop_here() -> void:
	# Free placement for anything that's already done its one-time task
	# placement (or started pre-placed, like the cabinet) - drop it wherever
	# the player is currently standing and facing.
	var drop_position := global_position
	var drop_yaw := global_rotation.y

	is_carried = false
	remove_from_group("carried_interactable")

	reparent(get_tree().current_scene, true)
	global_position = Vector3(drop_position.x, 0.0, drop_position.z)
	global_rotation = Vector3(0.0, drop_yaw, 0.0)
	scale = Vector3.ONE
	collision_layer = 1
	collision_mask = 1


func _show_placement_highlight() -> void:
	if placement_highlight != null:
		placement_highlight.visible = true
		return

	placement_highlight = MeshInstance3D.new()
	placement_highlight.name = "%sPinkPlacementHighlight" % item_label.replace(" ", "")
	var mesh := BoxMesh.new()
	mesh.size = highlight_size
	placement_highlight.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.38, 0.66, 0.5)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.08, 0.42, 1)
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	placement_highlight.material_override = material
	# Main-room floor tiles sit at y=0.125, so keep the footprint above them
	# instead of letting the floor occlude the pink placement target.
	placement_highlight.position = placement_position + Vector3(0.0, 0.17, 0.0)
	placement_highlight.rotation_degrees = placement_rotation_degrees
	get_tree().current_scene.add_child(placement_highlight)


func _hide_placement_highlight() -> void:
	if placement_highlight != null:
		placement_highlight.queue_free()
		placement_highlight = null


func _build_sofa_details() -> void:
	if details_built:
		return
	details_built = true

	var cushion_material := _sofa_material(Color(0.432, 0.265, 0.223, 1))
	var piping_material := _sofa_material(Color(0.648, 0.424, 0.335, 1))
	var pillow_material := _sofa_material(Color(0.558, 0.349, 0.287, 1))
	var leg_material := _sofa_material(Color(0.12, 0.07, 0.04, 1))

	_add_sofa_box("SeatCushionLeft", Vector3(1.35, 0.2, 1.02), Vector3(-0.7, 0.7, -0.04), cushion_material)
	_add_sofa_box("SeatCushionRight", Vector3(1.35, 0.2, 1.02), Vector3(0.7, 0.7, -0.04), cushion_material)
	_add_sofa_box("BackCushionLeft", Vector3(1.25, 0.72, 0.18), Vector3(-0.7, 1.35, 0.27), piping_material)
	_add_sofa_box("BackCushionRight", Vector3(1.25, 0.72, 0.18), Vector3(0.7, 1.35, 0.27), piping_material)
	_add_sofa_box("PillowLeft", Vector3(0.5, 0.34, 0.22), Vector3(-1.02, 1.35, 0.08), pillow_material)
	_add_sofa_box("PillowRight", Vector3(0.5, 0.34, 0.22), Vector3(1.02, 1.35, 0.08), pillow_material)

	for index in range(4):
		_add_sofa_cylinder(
			"Leg%d" % index,
			0.07,
			0.42,
			Vector3(-1.15 if index % 2 == 0 else 1.15, 0.2, -0.42 if index < 2 else 0.42),
			leg_material
		)


func _sofa_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func _add_sofa_box(node_name: String, size: Vector3, local_position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _add_sofa_cylinder(node_name: String, radius: float, height: float, local_position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	add_child(mesh_instance)
