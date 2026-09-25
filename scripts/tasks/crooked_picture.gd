extends StaticBody3D
# Task 2: Crooked Picture Frame. Click to straighten it - a cover action
# ("just tidying up") that also happens to reveal a hidden 4-digit safe
# code scratched into the wall substrate behind it.

signal straightened(safe_code: String)

@export var reduce_suspicion_amount: float = 10.0
@export var safe_code: String = "" # left blank = randomised on _ready()

var _frame: Node3D
var _code_label_root: Node3D
var _is_busy: bool = false
var _is_done: bool = false


func _ready() -> void:
	add_to_group("interactable")
	if safe_code.is_empty():
		safe_code = "%04d" % randi_range(0, 9999)
	_build_visuals()
	_frame.rotation_degrees.z = -18.5


func get_interaction_prompt() -> String:
	if _is_done or _is_busy:
		return ""
	return "E  STRAIGHTEN THE PICTURE"


func interact() -> void:
	if _is_done or _is_busy:
		return
	_is_busy = true

	var tween := create_tween()
	tween.tween_property(_frame, "rotation_degrees:z", 0.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	_is_busy = false
	_is_done = true

	var suspicion_manager := get_node_or_null("/root/SuspicionManager")
	if suspicion_manager != null:
		suspicion_manager.call("reduce_suspicion", reduce_suspicion_amount)

	_reveal_code()
	straightened.emit(safe_code)

	var inner_voice := get_node_or_null("/root/InnerVoiceManager")
	if inner_voice != null:
		inner_voice.call(
			"queue_thought",
			"CAUTION",
			"Someone scratched numbers into the plaster before hanging this. Worth remembering: %s." % safe_code,
			4.5
		)


func _reveal_code() -> void:
	_code_label_root.visible = true
	var label_3d := _code_label_root.get_node("CodeText") as Label3D
	var fade := create_tween()
	fade.tween_property(label_3d, "modulate:a", 1.0, 0.6)


func _build_visuals() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.28, 0.15, 0.06, 1)
	wood.roughness = 0.65
	var gold_trim := StandardMaterial3D.new()
	gold_trim.albedo_color = Color(0.55, 0.42, 0.18, 1)
	gold_trim.metallic = 0.55
	gold_trim.roughness = 0.4
	var mat_board := StandardMaterial3D.new()
	mat_board.albedo_color = Color(0.86, 0.82, 0.72, 1)
	mat_board.roughness = 0.95
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.72, 0.68, 0.6, 1)
	plaster.roughness = 1.0

	# The scratched code sits on the wall substrate just past the frame's
	# bottom-left corner - close enough to read as "behind/beside the
	# picture", but NOT inside the frame's own footprint. It used to sit at
	# the same x/y as the frame at a z depth inside the solid wood border
	# mesh, which meant it was permanently occluded by that opaque geometry
	# and could never actually be seen once revealed, regardless of its
	# visibility flag.
	_code_label_root = Node3D.new()
	_code_label_root.name = "SafeCodeMark"
	_code_label_root.position = Vector3(-0.65, -0.3, 0.01)
	add_child(_code_label_root)

	var plate := MeshInstance3D.new()
	plate.name = "PlasterPatch"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.3, 0.14, 0.01)
	plate.mesh = plate_mesh
	plate.material_override = plaster
	_code_label_root.add_child(plate)

	var label_3d := Label3D.new()
	label_3d.name = "CodeText"
	label_3d.text = safe_code
	label_3d.font_size = 42
	label_3d.pixel_size = 0.0028
	label_3d.modulate = Color(0.15, 0.12, 0.1, 1)
	label_3d.position = Vector3(0, 0, 0.006)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_code_label_root.add_child(label_3d)
	# Node3D has no `modulate` property (that's a 2D/Control thing) - hide the
	# whole plaster-patch subtree instead, and fade the Label3D itself (which
	# does have modulate) when it's revealed.
	_code_label_root.visible = false
	label_3d.modulate.a = 0.0

	_frame = Node3D.new()
	_frame.name = "FramePivot"
	add_child(_frame)

	# Outer wood frame, then a cream mat board (the passe-partout border you'd
	# see around a real framed print), then the canvas on top - three visible
	# layers instead of one flat rectangle.
	var frame_border := MeshInstance3D.new()
	frame_border.name = "FrameBorder"
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(0.92, 0.68, 0.05)
	frame_border.mesh = border_mesh
	frame_border.material_override = wood
	frame_border.position = Vector3(0, 0, -0.015)
	_frame.add_child(frame_border)

	var gold_liner := MeshInstance3D.new()
	gold_liner.name = "GoldLiner"
	var liner_mesh := BoxMesh.new()
	liner_mesh.size = Vector3(0.86, 0.62, 0.015)
	gold_liner.mesh = liner_mesh
	gold_liner.material_override = gold_trim
	gold_liner.position = Vector3(0, 0, 0.005)
	_frame.add_child(gold_liner)

	var mat := MeshInstance3D.new()
	mat.name = "MatBoard"
	var mat_mesh := BoxMesh.new()
	mat_mesh.size = Vector3(0.82, 0.58, 0.012)
	mat.mesh = mat_mesh
	mat.material_override = mat_board
	mat.position = Vector3(0, 0, 0.009)
	_frame.add_child(mat)

	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var canvas_mesh := BoxMesh.new()
	canvas_mesh.size = Vector3(0.78, 0.54, 0.02)
	canvas.mesh = canvas_mesh
	canvas.position = Vector3(0, 0, 0.012)
	_frame.add_child(canvas)

	_build_landscape_scene()

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.92, 0.68, 0.08)
	collision.shape = shape
	add_child(collision)


## A small painted-looking landscape - sky band, ground band, a pale moon and
## two mountain silhouettes - so the canvas reads as an actual picture rather
## than a single flat-colored panel. All built from primitive meshes, no
## external texture/image assets needed.
func _build_landscape_scene() -> void:
	var canvas_front_z := 0.023 # just in front of the Canvas box built above.

	var sky_material := StandardMaterial3D.new()
	sky_material.albedo_color = Color(0.24, 0.3, 0.4, 1)
	sky_material.roughness = 1.0
	var sky := MeshInstance3D.new()
	sky.name = "PaintingSky"
	var sky_mesh := BoxMesh.new()
	sky_mesh.size = Vector3(0.74, 0.32, 0.006)
	sky.mesh = sky_mesh
	sky.material_override = sky_material
	sky.position = Vector3(0, 0.09, canvas_front_z)
	_frame.add_child(sky)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.2, 0.14, 0.09, 1)
	ground_material.roughness = 1.0
	var ground := MeshInstance3D.new()
	ground.name = "PaintingGround"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(0.74, 0.22, 0.006)
	ground.mesh = ground_mesh
	ground.material_override = ground_material
	ground.position = Vector3(0, -0.16, canvas_front_z + 0.001)
	_frame.add_child(ground)

	var moon_material := StandardMaterial3D.new()
	moon_material.albedo_color = Color(0.85, 0.82, 0.68, 1)
	moon_material.emission_enabled = true
	moon_material.emission = Color(0.85, 0.82, 0.68, 1)
	moon_material.emission_energy_multiplier = 0.35
	moon_material.roughness = 0.7
	var moon := MeshInstance3D.new()
	moon.name = "PaintingMoon"
	var moon_mesh := CylinderMesh.new()
	moon_mesh.top_radius = 0.055
	moon_mesh.bottom_radius = 0.055
	moon_mesh.height = 0.005
	moon.mesh = moon_mesh
	moon.material_override = moon_material
	moon.position = Vector3(0.2, 0.16, canvas_front_z + 0.003)
	moon.rotation_degrees.x = 90.0
	_frame.add_child(moon)

	var near_mountain_material := StandardMaterial3D.new()
	near_mountain_material.albedo_color = Color(0.1, 0.09, 0.1, 1)
	near_mountain_material.roughness = 1.0
	var near_mountain := MeshInstance3D.new()
	near_mountain.name = "PaintingMountainNear"
	var near_mesh := PrismMesh.new()
	near_mesh.size = Vector3(0.34, 0.17, 0.006)
	near_mesh.left_to_right = 0.4
	near_mountain.mesh = near_mesh
	near_mountain.material_override = near_mountain_material
	near_mountain.position = Vector3(-0.14, -0.045, canvas_front_z + 0.002)
	_frame.add_child(near_mountain)

	var far_mountain_material := StandardMaterial3D.new()
	far_mountain_material.albedo_color = Color(0.22, 0.22, 0.28, 1)
	far_mountain_material.roughness = 1.0
	var far_mountain := MeshInstance3D.new()
	far_mountain.name = "PaintingMountainFar"
	var far_mesh := PrismMesh.new()
	far_mesh.size = Vector3(0.24, 0.1, 0.006)
	far_mesh.left_to_right = 0.6
	far_mountain.mesh = far_mesh
	far_mountain.material_override = far_mountain_material
	far_mountain.position = Vector3(0.13, -0.06, canvas_front_z + 0.001)
	_frame.add_child(far_mountain)
