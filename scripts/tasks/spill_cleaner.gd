extends StaticBody3D
# Task 3: Liquid Spill Scrubbing. Requires the Mop equipped (tool index 0 in
# player_controller.gd) to clean. Interact (E) starts scrubbing; progress
# then ticks up automatically over CLEAN_TIME_SECONDS, matching the
# hold-to-clean convention already used by scripts/dust_spot.gd in this
# project (the spec describes a literal held mouse button - adapted here to
# the project's existing E-to-start / auto-progress interaction pattern so
# it behaves consistently with every other cleaning task).
#
# The stain's alpha is driven every frame by a ShaderMaterial using
# shaders/spill_stain.gdshader's `scrub_progress` uniform.

signal cleaned

const CLEAN_TIME_SECONDS := 6.0
const StainShader = preload("res://shaders/spill_stain.gdshader")

@export var reduce_suspicion_amount: float = 15.0

var _stain_mesh: MeshInstance3D
var _shader_material: ShaderMaterial
var scrub_progress: float = 0.0
var _is_cleaning: bool = false
var _is_cleaned: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("floor_cleaning_task")
	_build_visuals()


func _process(delta: float) -> void:
	if not _is_cleaning:
		return

	var speed_multiplier := _cleaning_speed_multiplier()
	scrub_progress = clampf(scrub_progress + (delta / CLEAN_TIME_SECONDS) * speed_multiplier, 0.0, 1.0)
	_shader_material.set_shader_parameter("scrub_progress", scrub_progress)

	if scrub_progress >= 1.0:
		_finish_clean()


func get_interaction_prompt() -> String:
	if _is_cleaned:
		return ""
	if _is_cleaning:
		return "SCRUBBING  %02d%%" % int(scrub_progress * 100.0)
	if not _mop_equipped():
		return "EQUIP THE MOP (1) TO CLEAN THIS"
	return "E  SCRUB THE SPILL" if _has_required_tool() else "REQUIRES MOP"


func interact() -> void:
	if _is_cleaned or _is_cleaning or not _has_required_tool():
		return
	_is_cleaning = true


func stop_interaction() -> void:
	if _is_cleaned:
		return
	_is_cleaning = false


func _finish_clean() -> void:
	_is_cleaning = false
	_is_cleaned = true
	var suspicion_manager := get_node_or_null("/root/SuspicionManager")
	if suspicion_manager != null:
		suspicion_manager.call("reduce_suspicion", reduce_suspicion_amount)
	cleaned.emit()
	queue_free()


func _has_required_tool() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and int(player.get("current_tool")) == 1


func _mop_equipped() -> bool:
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player == null:
		return true # fail-open so the task never gets stuck if the path differs
	return int(player.get("current_tool")) == 1


func _cleaning_speed_multiplier() -> float:
	var run_generator_path := "res://scripts/autoload/run_generator.gd"
	if not ResourceLoader.exists(run_generator_path):
		return 1.0
	var RunGeneratorScript := load(run_generator_path)
	return float(RunGeneratorScript.cleaning_speed_multiplier)


func _build_visuals() -> void:
	_stain_mesh = MeshInstance3D.new()
	_stain_mesh.name = "StainQuad"
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.1, 0.85)
	quad.orientation = PlaneMesh.FACE_Y
	_stain_mesh.mesh = quad
	_stain_mesh.position = Vector3(0, 0.008, 0)

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = StainShader
	_shader_material.set_shader_parameter("stain_color", Color(0.085, 0.105, 0.09, 0.76))
	_shader_material.set_shader_parameter("stain_age", 0.0)
	_shader_material.set_shader_parameter("scrub_progress", 0.0)
	_stain_mesh.material_override = _shader_material
	add_child(_stain_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Keep the collider broad and paper-thin: the stain is easy to target while
	# the player can still walk over it without bumping into an invisible block.
	shape.size = Vector3(1.15, 0.025, 0.95)
	collision.shape = shape
	collision.position = Vector3(0, 0.0125, 0)
	add_child(collision)
