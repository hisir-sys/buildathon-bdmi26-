extends CharacterBody3D
class_name PlayerController

signal tool_selected(tool_index: int)

@export var move_speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var camera_pitch: float = 0.0
# Tool IDs: 0 = electrical kit, 1 = mop, 2 = bathroom scrubber.
var current_tool: int = 0
var tool_nodes: Array[Node3D] = []
const TOOL_ELECTRICAL := 0
const TOOL_MOP := 1
const TOOL_SCRUBBER := 2

const FOOTSTEP_INTERVAL := 0.38
var _footstep_timer: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	add_to_group("player")
	tool_nodes = [
		camera.get_node("ElectricalKit"),
		camera.get_node("Mop"),
		camera.get_node("Scrubber"),
	]
	_select_tool(TOOL_ELECTRICAL)


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
		var hud := get_node_or_null("../HUD")
		if hud != null and hud.has_method("toggle_pause"):
			hud.toggle_pause()
			get_viewport().set_input_as_handled()
		else:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_select_tool(TOOL_ELECTRICAL)
			KEY_2:
				_select_tool(TOOL_MOP)
			KEY_3:
				_select_tool(TOOL_SCRUBBER)


func _select_tool(index: int) -> void:
	var interaction_ray := camera.get_node_or_null("InteractionRay")
	if interaction_ray != null and interaction_ray.has_method("cancel_current_interaction"):
		interaction_ray.cancel_current_interaction()
	current_tool = index
	for tool_index in range(tool_nodes.size()):
		tool_nodes[tool_index].visible = (tool_index == index)
	SoundManager.play_ui_click()
	tool_selected.emit(index)
	if has_node("/root/SuspicionManager"):
		get_node("/root/SuspicionManager").call("set_cover_state", index == TOOL_MOP) # Mop


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

	var is_walking := movement_direction != Vector3.ZERO and is_on_floor()
	if is_walking:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			SoundManager.play_footstep()
	else:
		_footstep_timer = 0.0

	move_and_slide()