extends StaticBody3D

signal cleaned

const CLEAN_TIME_SECONDS := 10.0

var is_cleaned: bool = false
var is_cleaning: bool = false
var cleaning_elapsed: float = 0.0
var dust_pieces: Array[MeshInstance3D] = []


func _ready() -> void:
	var placeholder := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if placeholder != null:
		placeholder.visible = false
	_create_scattered_dust()


func _process(delta: float) -> void:
	if not is_cleaning:
		return

	cleaning_elapsed = minf(CLEAN_TIME_SECONDS, cleaning_elapsed + delta)
	var progress := cleaning_elapsed / CLEAN_TIME_SECONDS
	for piece in dust_pieces:
		piece.transparency = progress

	if cleaning_elapsed >= CLEAN_TIME_SECONDS:
		is_cleaned = true
		cleaned.emit()
		queue_free()


func get_interaction_prompt() -> String:
	if is_cleaned:
		return ""
	if is_cleaning:
		return "CLEANING DUST  %02d%%" % int((cleaning_elapsed / CLEAN_TIME_SECONDS) * 100.0)
	return "E  DUST THE FLOOR  (10 SEC)" if _has_required_tool() else "REQUIRES MOP"


func interact() -> void:
	if is_cleaned or is_cleaning or not _has_required_tool():
		return

	is_cleaning = true


func stop_interaction() -> void:
	if is_cleaned:
		return
	is_cleaning = false


func _create_scattered_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(str(global_position)))

	var dust_material := StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.albedo_color = Color(0.48, 0.3, 0.055, 0.34)
	dust_material.roughness = 1.0
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Irregular low-opacity smears make the dirt read as dust, not six circles.
	for index in range(7):
		var smear := MeshInstance3D.new()
		var smear_mesh := SphereMesh.new()
		smear_mesh.radius = rng.randf_range(0.12, 0.22)
		smear_mesh.height = rng.randf_range(0.012, 0.025)
		smear_mesh.radial_segments = 10
		smear_mesh.rings = 3
		smear.mesh = smear_mesh
		smear.material_override = dust_material
		smear.position = Vector3(
			rng.randf_range(-0.48, 0.48),
			rng.randf_range(0.012, 0.028),
			rng.randf_range(-0.4, 0.4)
		)
		smear.scale = Vector3(
			rng.randf_range(1.5, 3.2),
			rng.randf_range(0.35, 0.65),
			rng.randf_range(0.45, 1.15)
		)
		smear.rotation.y = rng.randf_range(-PI, PI)
		add_child(smear)
		dust_pieces.append(smear)

	for index in range(24):
		var piece := MeshInstance3D.new()
		var dust_mesh := SphereMesh.new()
		dust_mesh.radius = rng.randf_range(0.02, 0.075)
		dust_mesh.height = rng.randf_range(0.012, 0.04)
		dust_mesh.radial_segments = 8
		dust_mesh.rings = 3
		piece.mesh = dust_mesh
		piece.material_override = dust_material
		piece.position = Vector3(
			rng.randf_range(-0.58, 0.58),
			rng.randf_range(0.015, 0.045),
			rng.randf_range(-0.48, 0.48)
		)
		piece.scale = Vector3(
			rng.randf_range(0.7, 1.8),
			rng.randf_range(0.5, 1.0),
			rng.randf_range(0.7, 1.8)
		)
		add_child(piece)
		dust_pieces.append(piece)

func _has_required_tool() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and int(player.get("current_tool")) == 1
