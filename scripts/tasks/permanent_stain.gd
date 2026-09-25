extends StaticBody3D
# Task 4: The Permanent Stain (narrative clue trigger). Visually identical
# setup to Task 3, but scrub_progress caps at 0.99 and never reaches 1.0, so
# it never queue_frees itself - the stain stays behind as a piece of the
# story. After 3 seconds of scrubbing it fires the LOGIC inner-voice line
# once, then keeps letting the player scrub (harmlessly) without re-firing.

signal capped

const StainShader = preload("res://shaders/spill_stain.gdshader")
const MAX_SCRUB_PROGRESS := 0.99
const CLEAN_TIME_TO_CAP_SECONDS := 6.0
const NARRATIVE_TRIGGER_SECONDS := 3.0

const CLUE_TEXT := "This carpet fiber has been burnt by chemical industrial solvent. Someone was scrubbing blood out of this floor long before you arrived..."

var _stain_mesh: MeshInstance3D
var _shader_material: ShaderMaterial
var scrub_progress: float = 0.0
var _is_scrubbing: bool = false
var _scrub_elapsed_seconds: float = 0.0
var _clue_fired: bool = false
var _capped_fired: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("floor_cleaning_task")
	_build_visuals()


func _process(delta: float) -> void:
	if not _is_scrubbing:
		return

	_scrub_elapsed_seconds += delta
	scrub_progress = clampf(scrub_progress + (delta / CLEAN_TIME_TO_CAP_SECONDS), 0.0, MAX_SCRUB_PROGRESS)
	_shader_material.set_shader_parameter("scrub_progress", scrub_progress)

	if not _capped_fired and scrub_progress >= MAX_SCRUB_PROGRESS:
		_capped_fired = true
		capped.emit()

	if not _clue_fired and _scrub_elapsed_seconds >= NARRATIVE_TRIGGER_SECONDS:
		_clue_fired = true
		_fire_clue()


func get_interaction_prompt() -> String:
	if _is_scrubbing:
		return "SCRUBBING  %02d%%  (THIS ONE WON'T COME OUT)" % int(scrub_progress * 100.0)
	if not _mop_equipped():
		return "EQUIP THE MOP (1) TO CLEAN THIS"
	return "E  SCRUB THE STAIN"


func interact() -> void:
	if _is_scrubbing or not _mop_equipped():
		return
	_is_scrubbing = true


func _fire_clue() -> void:
	var inner_voice := get_node_or_null("/root/InnerVoiceManager")
	if inner_voice != null:
		inner_voice.call("queue_thought", "LOGIC", CLUE_TEXT, 5.0, Color(0.35, 0.85, 0.95, 1))


func _mop_equipped() -> bool:
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player == null:
		return true
	return int(player.get("current_tool")) == 0


func _build_visuals() -> void:
	_stain_mesh = MeshInstance3D.new()
	_stain_mesh.name = "PermanentStainQuad"
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.1, 0.78)
	quad.orientation = PlaneMesh.FACE_Y
	_stain_mesh.mesh = quad
	_stain_mesh.position = Vector3(0, 0.008, 0)

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = StainShader
	# Darker, rust-brown tint - reads as old and organic rather than a
	# fresh spill.
	_shader_material.set_shader_parameter("stain_color", Color(0.24, 0.105, 0.06, 0.76))
	_shader_material.set_shader_parameter("stain_age", 1.0)
	_shader_material.set_shader_parameter("scrub_progress", 0.0)
	_shader_material.set_shader_parameter("edge_softness", 0.24)
	_stain_mesh.material_override = _shader_material
	add_child(_stain_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 0.025, 0.84)
	collision.shape = shape
	collision.position = Vector3(0, 0.0125, 0)
	add_child(collision)
