extends CharacterBody3D
class_name PlayerController

signal tool_selected(tool_index: int)

@export var move_speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var camera_pitch: float = 0.0
var current_tool: int = 0
var tool_nodes: Array[Node3D] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	tool_nodes = [
		camera.get_node("Mop"),
		camera.get_node("Scrubber"),
		camera.get_node("Cloth"),
		camera.get_node("ElectricalKit"),
	]
	_select_tool(0)


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
				_select_tool(0)
			KEY_2:
				_select_tool(1)
			KEY_3:
				_select_tool(2)
			KEY_4:
				_select_tool(3)


func _select_tool(index: int) -> void:
	current_tool = index
	for tool_index in range(tool_nodes.size()):
		tool_nodes[tool_index].visible = (tool_index == index)
	tool_selected.emit(index)
	if has_node("/root/SuspicionManager"):
		get_node("/root/SuspicionManager").call("set_cover_state", index == 0) # Mop


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