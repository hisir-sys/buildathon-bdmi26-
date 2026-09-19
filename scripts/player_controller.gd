extends CharacterBody3D
class_name PlayerController

@export var move_speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var camera_pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)

			camera_pitch -= event.relative.y * mouse_sensitivity
			camera_pitch = clamp(
				camera_pitch,
				deg_to_rad(-89.0),
				deg_to_rad(89.0)
			)
			head.rotation.x = camera_pitch

	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var movement_direction := (
		transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	).normalized()

	if movement_direction != Vector3.ZERO:
		velocity.x = movement_direction.x * move_speed
		velocity.z = movement_direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()
