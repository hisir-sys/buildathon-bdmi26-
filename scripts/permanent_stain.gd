extends StaticBody3D

## TASK 4: The Permanent Stain (narrative clue trigger).
## Same setup as SpillCleaner.gd (see that file's Node setup comment) -
## reuses the same spill_stain.gdshader - but this stain isn't a real
## cleaning task: scrub_progress visually caps at 99% and never fully
## clears, and after 3 continuous seconds of scrubbing it fires an
## InnerVoiceManager thought instead of rewarding suspicion reduction.

const MAX_VISUAL_PROGRESS: float = 0.99
const NARRATIVE_TRIGGER_SECONDS: float = 3.0
const THOUGHT_PERSONA := "LOGIC"
const THOUGHT_TEXT := "This carpet fiber has been burnt by chemical industrial solvent. Someone was scrubbing blood out of this floor long before you arrived..."
const THOUGHT_ACCENT_COLOR := Color(0.35, 0.85, 0.95, 1.0)  # cyan, per spec
const THOUGHT_DISPLAY_DURATION: float = 5.0

@export var mesh_instance: MeshInstance3D
@export var scrub_speed: float = 0.45

var scrub_progress: float = 0.0
var _is_being_scrubbed: bool = false
var _continuous_scrub_time: float = 0.0
var _has_triggered_thought: bool = false
var _shader_material: ShaderMaterial


func _ready() -> void:
	if mesh_instance != null:
		_shader_material = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	_update_shader()


func _process(delta: float) -> void:
	if not _is_being_scrubbed:
		# Scrubbing must be continuous to reach the 3-second reveal - looking
		# away or letting go resets the count, same as a real "you stopped
		# and lost your nerve" beat.
		_continuous_scrub_time = 0.0
		return

	_advance_scrub(delta)
	_continuous_scrub_time += delta
	if _continuous_scrub_time >= NARRATIVE_TRIGGER_SECONDS and not _has_triggered_thought:
		_has_triggered_thought = true
		_trigger_narrative_thought()


func set_being_scrubbed(active: bool) -> void:
	_is_being_scrubbed = active and SuspicionManager.is_in_cover_state


func _advance_scrub(delta: float) -> void:
	if scrub_progress >= MAX_VISUAL_PROGRESS:
		return
	var speed := scrub_speed * RunGenerator.cleaning_speed_multiplier
	scrub_progress = clampf(scrub_progress + speed * delta, 0.0, MAX_VISUAL_PROGRESS)
	_update_shader()


func _update_shader() -> void:
	if _shader_material != null:
		_shader_material.set_shader_parameter("scrub_progress", scrub_progress)


func _trigger_narrative_thought() -> void:
	InnerVoiceManager.queue_thought(
		THOUGHT_PERSONA,
		THOUGHT_TEXT,
		THOUGHT_DISPLAY_DURATION,
		THOUGHT_ACCENT_COLOR
	)

# Same wiring note as SpillCleaner.gd applies here - call
# set_being_scrubbed(true/false) from your mop-hold + raycast polling code.
