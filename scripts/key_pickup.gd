extends StaticBody3D
# The chest key. Lies on the middle shelf of the bathroom storage rack.
# Pick it up with E; it then shows as "KEY" on the HUD.


func _ready() -> void:
	add_to_group("interactable")
	_build_visuals()


func get_interaction_prompt() -> String:
	return "E  PICK UP THE KEY"


func interact() -> void:
	var manager := get_tree().get_first_node_in_group("game_manager")
	if manager != null:
		manager.call("set_has_key", true)
	queue_free()


func _build_visuals() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.72, 0.22, 1)
	gold.metallic = 0.85
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.6, 0.1, 1)
	gold.emission_energy_multiplier = 0.6

	# Bow (the ring you hold) - lies flat on the shelf.
	var bow := MeshInstance3D.new()
	bow.name = "Bow"
	var bow_mesh := TorusMesh.new()
	bow_mesh.inner_radius = 0.035
	bow_mesh.outer_radius = 0.07
	bow.mesh = bow_mesh
	bow.material_override = gold
	bow.position = Vector3(-0.14, 0.012, 0.0)
	bow.scale = Vector3(1.0, 0.45, 1.0)
	add_child(bow)

	# Shaft along local X.
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.012
	shaft_mesh.bottom_radius = 0.012
	shaft_mesh.height = 0.26
	shaft.mesh = shaft_mesh
	shaft.material_override = gold
	shaft.position = Vector3(0.02, 0.012, 0.0)
	shaft.rotation_degrees.z = 90.0
	add_child(shaft)

	# Teeth at the far end.
	for index in range(3):
		var tooth := MeshInstance3D.new()
		tooth.name = "Tooth%d" % index
		var tooth_mesh := BoxMesh.new()
		tooth_mesh.size = Vector3(0.02, 0.02, 0.05 - index * 0.008)
		tooth.mesh = tooth_mesh
		tooth.material_override = gold
		tooth.position = Vector3(0.1 - index * 0.035, 0.012, 0.03)
		add_child(tooth)

	# A faint warm glint so it can actually be spotted on the shelf.
	var glint := OmniLight3D.new()
	glint.name = "KeyGlint"
	glint.position = Vector3(0.0, 0.12, 0.0)
	glint.omni_range = 1.4
	glint.light_energy = 0.7
	glint.light_color = Color(1.0, 0.82, 0.4, 1)
	add_child(glint)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.12, 0.2)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.04, 0.0)
	add_child(collision)
