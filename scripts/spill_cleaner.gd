extends StaticBody3D

## TASK 3: Liquid Spill Scrubbing.
## Attach to a floor-stain mesh using a ShaderMaterial built from
## spill_stain.gdshader (assign it as the mesh's surface material in the
## editor - this script just drives the "scrub_progress" uniform).
##
## Node setup:
##   StaticBody3D (this script)
##   +- MeshInstance3D "StainMesh"  (flat plane/decal; surface material =
##                                    a ShaderMaterial using spill_stain.gdshader)
##   +- CollisionShape3D             (matches the mesh footprint, for
##                                     raycast hit-testing)
##
## Wiring note: scrubbing is continuous (hold, not a single tap), so this
## doesn't use an interact() single-shot method. Instead, call
## set_being_scrubbed(true/false) every frame from wherever you're already
## tracking mouse-held + raycast target - see the bottom of this file.

signal scrubbed_clean

@export var mesh_instance: MeshInstance3D
@export var scrub_speed: float = 0.45  # progress per second of continuous scrubbing
@export var suspicion_reward: float = 15.0

var scrub_progress: float = 0.0
var _is_being_scrubbed: bool = false
var _shader_material: ShaderMaterial


func _ready() -> void:
	if mesh_instance != null:
		_shader_material = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	_update_shader()


func _process(delta: float) -> void:
	if not _is_being_scrubbed:
		return
	_advance_scrub(delta)


## Only actually scrubs while the player is holding a legitimate cleaning
## tool (SuspicionManager.is_in_cover_state) AND the caller says the mop
## is being held down on this stain - matches the spec's "while holding
## the Mop item" condition.
func set_being_scrubbed(active: bool) -> void:
	_is_being_scrubbed = active and SuspicionManager.is_in_cover_state


func _advance_scrub(delta: float) -> void:
	if scrub_progress >= 1.0:
		return
	var speed := scrub_speed * RunGenerator.cleaning_speed_multiplier
	scrub_progress = clampf(scrub_progress + speed * delta, 0.0, 1.0)
	_update_shader()
	if scrub_progress >= 1.0:
		_on_fully_scrubbed()


func _update_shader() -> void:
	if _shader_material != null:
		_shader_material.set_shader_parameter("scrub_progress", scrub_progress)


func _on_fully_scrubbed() -> void:
	SuspicionManager.reduce_suspicion(suspicion_reward)
	scrubbed_clean.emit()
	queue_free()

# --- Wiring note ---
# Your interaction_raycast.gd likely calls something like
# `current_target.interact()` on a single keypress for tap-interactions.
# This task is hold-based instead, so from wherever you already poll
# Input.is_action_pressed for the mop / left click each physics frame,
# call:
#     if raycast_hit_node is SpillCleaner:
#         raycast_hit_node.set_being_scrubbed(Input.is_action_pressed("scrub"))
# and call `previous_hit_node.set_being_scrubbed(false)` the frame the
# raycast target changes or the mouse button is released, so scrubbing
# doesn't keep counting once you look away.
