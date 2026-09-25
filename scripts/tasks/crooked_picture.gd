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
	var canvas_mat := StandardMaterial3D.new()
	canvas_mat.albedo_color = Color(0.42, 0.32, 0.22, 1)
	canvas_mat.roughness = 0.9
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.72, 0.68, 0.6, 1)
	plaster.roughness = 1.0

	# The scratched code sits on the wall substrate, hidden behind the
	# picture until it hangs straight.
	_code_label_root = Node3D.new()
	_code_label_root.name = "SafeCodeMark"
	_code_label_root.position = Vector3(0, 0, -0.03)
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

	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var canvas_mesh := BoxMesh.new()
	canvas_mesh.size = Vector3(0.5, 0.36, 0.02)
	canvas.mesh = canvas_mesh
	canvas.material_override = canvas_mat
	_frame.add_child(canvas)

	var frame_border := MeshInstance3D.new()
	frame_border.name = "FrameBorder"
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(0.56, 0.42, 0.04)
	frame_border.mesh = border_mesh
	frame_border.material_override = wood
	frame_border.position = Vector3(0, 0, -0.01)
	_frame.add_child(frame_border)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.56, 0.42, 0.06)
	collision.shape = shape
	add_child(collision)
