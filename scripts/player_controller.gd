class_name PlayerController
extends CharacterBody3D

# -- Tunables --
const MOVE_SPEED := 4.5
const MOUSE_SENSITIVITY := 0.0025
const PITCH_LIMIT := deg_to_rad(85.0)
const INTERACT_RANGE := 2.5
const GRAVITY := 9.8

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay

# Emitted whenever the thing the player is looking at changes, so the UI
# script (Member 2) can show/hide the prompt without this script knowing
# anything about labels or screens.
signal interact_target_changed(prompt_text: String)

var _current_target: Node = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interact_ray.target_position = Vector3(0, 0, -INTERACT_RANGE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_apply_look(event.relative)

	if event.is_action_pressed("ui_cancel"):
		# Buildathon-friendly escape hatch to free the mouse for debugging.
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact"):
		_try_interact()

func _apply_look(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x * MOUSE_SENSITIVITY)
	camera_pivot.rotate_x(-mouse_delta.y * MOUSE_SENSITIVITY)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()
	_update_interact_target()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _apply_movement() -> void:
	# Read raw input, convert it into a direction relative to where the
	# player is facing (not world axes) so WASD always means forward/back
	# relative to the camera.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = direction.x * MOVE_SPEED
	velocity.z = direction.z * MOVE_SPEED

func _update_interact_target() -> void:
	var collider := interact_ray.get_collider() if interact_ray.is_colliding() else null

	if collider == _current_target:
		return

	_current_target = collider

	if _current_target != null and _current_target.is_in_group("interactable"):
		interact_target_changed.emit(_current_target.get_prompt_text())
	else:
		_current_target = null
		interact_target_changed.emit("")

func _try_interact() -> void:
	if _current_target != null and _current_target.has_method("interact"):
		_current_target.interact()
