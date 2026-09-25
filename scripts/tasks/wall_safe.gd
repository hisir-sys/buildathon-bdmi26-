extends StaticBody3D
# Bonus investigation object: a small wall safe, closing the loose thread
# left by crooked_picture.gd's safe code (which used to have nowhere to go).
# Purely optional - it doesn't touch task_active/_task_complete, so it can't
# affect winning either way. Call set_code() once the code is known (wired
# to CrookedPicture's "straightened" signal in main_room.gd).

signal opened

const UiKit = preload("res://scripts/ui_kit.gd")

@export var reduce_suspicion_amount: float = 10.0
@export var wrong_guess_suspicion: float = 5.0

var _required_code: String = ""
var _is_known: bool = false
var _is_open: bool = false
var _is_busy: bool = false

var _door: Node3D
var _dial_lights: Array = []
var _keypad: CanvasLayer


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


func _open_keypad() -> void:
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

	var entered := ""
	var digit_buttons: Array = []

	var refresh_display := func() -> void:
		var display := ""
		for i in range(4):
			display += (entered[i] if i < entered.length() else "-") + " "
		entry_label.text = display.strip_edges()

	var make_digit_button := func(digit: int) -> Button:
		var button := UiKit.glass_button(str(digit), Color(0.6, 0.5, 0.3, 1), Vector2(70, 54))
		button.pressed.connect(func() -> void:
			if entered.length() >= 4:
				return
			entered += str(digit)
			refresh_display.call()
		)
		return button

	# 1-9 fill the 3x3 grid in order, then 0 gets its own centered last row.
	for digit in range(1, 10):
		var button: Button = make_digit_button.call(digit)
		digit_buttons.append(button)
		grid.add_child(button)

	var spacer_left := Control.new()
	var zero_button: Button = make_digit_button.call(0)
	var spacer_right := Control.new()
	digit_buttons.append(zero_button)
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

	clear_button.pressed.connect(func() -> void:
		entered = ""
		status_label.text = " "
		refresh_display.call()
	)
	cancel_button.pressed.connect(func() -> void:
		_close_keypad()
	)
	enter_button.pressed.connect(func() -> void:
		if entered.length() != 4:
			status_label.text = "ENTER ALL 4 DIGITS"
			return
		if entered == _required_code:
			status_label.text = "ACCEPTED"
			_close_keypad()
			_on_correct_code()
		else:
			status_label.text = "INCORRECT - TRY AGAIN"
			entered = ""
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


func _on_correct_code() -> void:
	_is_open = true
	var suspicion_manager := get_node_or_null("/root/SuspicionManager")
	if suspicion_manager != null:
		suspicion_manager.call("reduce_suspicion", reduce_suspicion_amount)

	var tween := create_tween()
	tween.tween_property(_door, "rotation_degrees:y", -100.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for light in _dial_lights:
		tween.parallel().tween_property(light, "light_energy", 0.9, 0.5)

	var inner_voice := get_node_or_null("/root/InnerVoiceManager")
	if inner_voice != null:
		inner_voice.call(
			"queue_thought",
			"SATISFACTION",
			"The safe clicks open. So the wall panel wasn't just decoration.",
			4.0
		)
	opened.emit()


func _build_visuals() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.23, 0.25, 1)
	steel.metallic = 0.7
	steel.roughness = 0.4
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.48, 0.16, 1)
	brass.metallic = 0.8
	brass.roughness = 0.35

	var frame := MeshInstance3D.new()
	frame.name = "SafeFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.42, 0.42, 0.1)
	frame.mesh = frame_mesh
	frame.material_override = steel
	add_child(frame)

	_door = Node3D.new()
	_door.name = "DoorPivot"
	_door.position = Vector3(-0.19, 0, 0.05)
	add_child(_door)

	var door_panel := MeshInstance3D.new()
	door_panel.name = "DoorPanel"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.38, 0.38, 0.03)
	door_panel.mesh = door_mesh
	door_panel.material_override = steel
	door_panel.position = Vector3(0.19, 0, 0)
	_door.add_child(door_panel)

	var handle := MeshInstance3D.new()
	handle.name = "DoorHandle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.04
	handle_mesh.bottom_radius = 0.04
	handle_mesh.height = 0.03
	handle.mesh = handle_mesh
	handle.material_override = brass
	handle.position = Vector3(0.32, 0, 0.03)
	handle.rotation_degrees.x = 90.0
	_door.add_child(handle)

	for offset in [-0.12, 0.0, 0.12]:
		var indicator := MeshInstance3D.new()
		indicator.name = "DialLight"
		var indicator_mesh := SphereMesh.new()
		indicator_mesh.radius = 0.015
		indicator_mesh.height = 0.03
		indicator.mesh = indicator_mesh
		var indicator_material := StandardMaterial3D.new()
		indicator_material.albedo_color = Color(0.5, 0.08, 0.06, 1)
		indicator_material.emission_enabled = true
		indicator_material.emission = Color(0.5, 0.08, 0.06, 1)
		indicator_material.emission_energy_multiplier = 0.0
		indicator.material_override = indicator_material
		indicator.position = Vector3(offset, 0.16, 0.052)
		add_child(indicator)
		_dial_lights.append(indicator)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 0.42, 0.14)
	collision.shape = shape
	add_child(collision)
