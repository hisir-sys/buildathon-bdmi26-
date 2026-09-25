extends StaticBody3D
# Bonus investigation object: a wall safe. Its 4-digit code is found by
# straightening the picture (see crooked_picture.gd). Purely optional - it
# doesn't touch task_active/_task_complete, so it can't affect winning.
# Call set_code() once the code is known (wired to CrookedPicture's
# "straightened" signal in main_room.gd).

signal opened

const UiKit = preload("res://scripts/ui_kit.gd")

@export var reduce_suspicion_amount: float = 10.0
@export var wrong_guess_suspicion: float = 5.0

# Local layout of the safe. Its front face points along +z, which becomes
# +x (into the room) because main_room.gd rotates the safe 90 degrees.
const BODY_SIZE := Vector3(0.9, 0.9, 0.4)
const BODY_CENTER := Vector3(0.0, 0.0, -0.15)
const DOOR_PIVOT := Vector3(-0.42, 0.0, 0.05)
# Distance a part sits in front of the door's own face.
const FRONT_Z := 0.035

var _required_code: String = ""
var _is_known: bool = false
var _is_open: bool = false
var _is_busy: bool = false

# The digits typed so far. This MUST live on the script (not as a local inside
# _open_keypad()) because GDScript lambdas capture local variables BY VALUE at
# the moment each closure is created - every button's `pressed` callback would
# otherwise get its own frozen copy of a local string. Reading/writing
# `_code_entry` from inside a lambda works because all callbacks share `self`.
var _code_entry: String = ""

var _door: Node3D
var _led_materials: Array = []
var _keypad: CanvasLayer
var _previous_process_mode: int = Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	add_to_group("interactable")
	_build_visuals()


## Called once the code has been read elsewhere (the plaster patch behind
## the picture). Until this fires the safe is just set dressing.
func set_code(code: String) -> void:
	_required_code = code
	_is_known = true


func get_interaction_prompt() -> String:
	if _is_open or _is_busy:
		return ""
	if not _is_known:
		return "A LOCKED WALL SAFE - NO CODE KNOWN"
	return "E  ENTER THE CODE"


func interact() -> void:
	if _is_open or _is_busy or not _is_known:
		return
	_is_busy = true
	_open_keypad()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_busy or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_close_keypad()


func _open_keypad() -> void:
	_previous_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_keypad = CanvasLayer.new()
	_keypad.layer = 60
	_keypad.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_keypad)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_keypad.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", UiKit.glass_style(Color(0.05, 0.06, 0.08, 0.95), Color(0.6, 0.5, 0.3, 0.85), 6))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	column.add_child(UiKit.label("ENTER 4-DIGIT CODE", 14, Color(0.8, 0.7, 0.5, 1), HORIZONTAL_ALIGNMENT_CENTER))

	var entry_label := UiKit.label("- - - -", 30, Color(1, 1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(entry_label)

	var status_label := UiKit.label(" ", 13, Color(1.0, 0.4, 0.35, 1), HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(status_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)

	_code_entry = ""

	var refresh_display := func() -> void:
		var display := ""
		for i in range(4):
			display += (_code_entry[i] if i < _code_entry.length() else "-") + " "
		entry_label.text = display.strip_edges()

	var make_digit_button := func(digit: int) -> Button:
		var button := UiKit.glass_button(str(digit), Color(0.6, 0.5, 0.3, 1), Vector2(70, 54))
		button.pressed.connect(func() -> void:
			if _code_entry.length() >= 4:
				return
			_code_entry += str(digit)
			refresh_display.call()
		)
		return button

	# 1-9 fill the 3x3 grid in order, then 0 gets its own centered last row.
	for digit in range(1, 10):
		grid.add_child(make_digit_button.call(digit))

	var spacer_left := Control.new()
	var zero_button: Button = make_digit_button.call(0)
	var spacer_right := Control.new()
	grid.add_child(spacer_left)
	grid.add_child(zero_button)
	grid.add_child(spacer_right)

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 8)
	column.add_child(buttons_row)

	var clear_button := UiKit.glass_button("CLEAR", Color(0.6, 0.3, 0.25, 1), Vector2(110, 44))
	var enter_button := UiKit.glass_button("ENTER", Color(0.3, 0.55, 0.35, 1), Vector2(110, 44))
	var cancel_button := UiKit.glass_button("CANCEL", Color(0.4, 0.4, 0.45, 1), Vector2(90, 44))
	buttons_row.add_child(clear_button)
	buttons_row.add_child(enter_button)
	buttons_row.add_child(cancel_button)
	column.add_child(UiKit.label("PRESS E TO CLOSE", 11, Color(0.7, 0.72, 0.76, 0.85), HORIZONTAL_ALIGNMENT_CENTER))

	clear_button.pressed.connect(func() -> void:
		_code_entry = ""
		status_label.text = " "
		refresh_display.call()
	)
	cancel_button.pressed.connect(func() -> void:
		_close_keypad()
	)
	enter_button.pressed.connect(func() -> void:
		if _code_entry.length() != 4:
			status_label.text = "ENTER ALL 4 DIGITS"
			return
		if _code_entry == _required_code:
			status_label.text = "ACCEPTED"
			_close_keypad()
			_on_correct_code()
		else:
			status_label.text = "INCORRECT - TRY AGAIN"
			_code_entry = ""
			refresh_display.call()
			var suspicion_manager := get_node_or_null("/root/SuspicionManager")
			if suspicion_manager != null:
				suspicion_manager.call("add_suspicion", wrong_guess_suspicion)
	)


func _close_keypad() -> void:
	if _keypad != null:
		_keypad.queue_free()
		_keypad = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	_is_busy = false
	process_mode = _previous_process_mode


func _on_correct_code() -> void:
	_is_open = true
	var suspicion_manager := get_node_or_null("/root/SuspicionManager")
	if suspicion_manager != null:
		suspicion_manager.call("reduce_suspicion", reduce_suspicion_amount)

	var tween := create_tween()
	tween.tween_property(_door, "rotation_degrees:y", -100.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The keypad LED flips from red to green as the door swings.
	for led_material in _led_materials:
		tween.parallel().tween_property(led_material, "emission", Color(0.2, 1.0, 0.4, 1), 0.4)
		tween.parallel().tween_property(led_material, "emission_energy_multiplier", 2.5, 0.4)

	opened.emit()


# --- Visuals ---------------------------------------------------------------
# Built from primitive meshes (no external assets), same as the rest of the
# room. Layout: a steel carcass sunk into the wall, a fixed frame around the
# opening, and a hinged door carrying the dial, keypad, and handle.

func _steel(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _add_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_sphere(parent: Node3D, node_name: String, radius: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_visuals() -> void:
	var carcass_steel := _steel(Color(0.16, 0.17, 0.19, 1), 0.6, 0.55)
	var door_steel := _steel(Color(0.3, 0.31, 0.34, 1), 0.75, 0.32)
	var brass := _steel(Color(0.72, 0.56, 0.2, 1), 0.9, 0.3)
	var dark := _steel(Color(0.05, 0.05, 0.06, 1), 0.2, 0.7)

	# Carcass: the solid box that sits inside the wall, so only its front shows.
	_add_box(self, "Carcass", BODY_SIZE, BODY_CENTER, carcass_steel)

	# Fixed frame around the opening (top, bottom, left, right).
	_add_box(self, "FrameTop", Vector3(0.96, 0.06, 0.06), Vector3(0.0, 0.45, 0.03), door_steel)
	_add_box(self, "FrameBottom", Vector3(0.96, 0.06, 0.06), Vector3(0.0, -0.45, 0.03), door_steel)
	_add_box(self, "FrameLeft", Vector3(0.06, 0.9, 0.06), Vector3(-0.45, 0.0, 0.03), door_steel)
	_add_box(self, "FrameRight", Vector3(0.06, 0.9, 0.06), Vector3(0.45, 0.0, 0.03), door_steel)

	# Hinge knuckles on the fixed side (they stay put when the door swings).
	for hinge_y in [-0.3, 0.3]:
		var hinge := _add_cylinder(self, "Hinge", 0.025, 0.12, Vector3(DOOR_PIVOT.x, hinge_y, DOOR_PIVOT.z + FRONT_Z), brass)
		hinge.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	# The door. Everything under _door rotates together when it opens. The
	# pivot sits on the left edge, so the door's own centre is at +0.41 on x.
	_door = Node3D.new()
	_door.name = "DoorPivot"
	_door.position = DOOR_PIVOT
	add_child(_door)
	_add_box(_door, "DoorPanel", Vector3(0.82, 0.82, 0.06), Vector3(0.41, 0.0, 0.0), door_steel)
	_add_box(_door, "DoorInset", Vector3(0.7, 0.7, 0.01), Vector3(0.41, 0.0, 0.032), carcass_steel)

	# Dial: a brass disc with eight tick marks around it.
	var dial_center := Vector3(0.6, 0.05, FRONT_Z)
	var dial := _add_cylinder(_door, "Dial", 0.075, 0.03, dial_center, brass)
	dial.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	for tick_index in range(8):
		var angle := TAU * float(tick_index) / 8.0
		var tick_position := dial_center + Vector3(cos(angle) * 0.11, sin(angle) * 0.11, 0.006)
		_add_box(_door, "DialTick%d" % tick_index, Vector3(0.018, 0.018, 0.012), tick_position, dark)

	# Handle lever on the right side of the door.
	_add_box(_door, "Handle", Vector3(0.14, 0.04, 0.05), Vector3(0.7, -0.08, 0.045), brass)

	# Keypad: a dark plate with a 3x4 grid of buttons, and a status LED above it.
	var keypad_center := Vector3(0.2, -0.2, FRONT_Z)
	_add_box(_door, "KeypadPlate", Vector3(0.22, 0.26, 0.012), keypad_center, dark)
	for row in range(4):
		for column in range(3):
			var button_position := keypad_center + Vector3((column - 1) * 0.062, 0.085 - row * 0.05, 0.008)
			_add_box(_door, "KeyButton%d%d" % [row, column], Vector3(0.045, 0.035, 0.012), button_position, door_steel)

	var led_material := _steel(Color(0.5, 0.08, 0.06, 1), 0.0, 0.5)
	led_material.emission_enabled = true
	led_material.emission = Color(0.5, 0.08, 0.06, 1)
	led_material.emission_energy_multiplier = 1.0
	_add_sphere(_door, "StatusLed", 0.014, Vector3(0.2, -0.045, FRONT_Z + 0.005), led_material)
	_led_materials.append(led_material)

	# One collision box for the whole safe so the interaction ray can hit it.
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = BODY_SIZE
	collision.shape = shape
	collision.position = BODY_CENTER
	add_child(collision)
