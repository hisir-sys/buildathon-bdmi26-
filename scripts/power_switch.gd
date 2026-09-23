extends StaticBody3D

signal toggled(is_on: bool)

@export var label_text: String = "FRIDGE"

var is_on: bool = false


func get_interaction_prompt() -> String:
	return "E  TURN %s %s" % [label_text, "OFF" if is_on else "ON"]


func interact() -> void:
	is_on = not is_on
	_update_visual()
	toggled.emit(is_on)


func _update_visual() -> void:
	var lever := get_node_or_null("Lever")
	if lever != null:
		lever.rotation_degrees.x = -30.0 if is_on else 30.0

	var indicator := get_node_or_null("Indicator") as MeshInstance3D
	if indicator == null:
		return
	var material := indicator.material_override as StandardMaterial3D
	if material == null:
		return
	var lit_color := Color(0.25, 1.0, 0.45, 1)
	var dead_color := Color(0.5, 0.08, 0.06, 1)
	material.albedo_color = lit_color if is_on else dead_color
	material.emission = lit_color if is_on else dead_color
	material.emission_energy_multiplier = 2.4 if is_on else 1.0
