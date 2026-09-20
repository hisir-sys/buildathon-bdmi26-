extends StaticBody3D

signal completed(task_kind: String)

const GRID_COLUMNS := 4
const GRID_ROWS := 3
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8

@export var task_kind: String = "pipeline"

var is_complete: bool = false
var puzzle_open: bool = false
var overlay: CanvasLayer
var cell_buttons: Array[Button] = []
var current_masks: Array[int] = []
var target_masks: Array[int] = [
	6, 10, 10, 12,
	13, 5, 5, 7,
	3, 10, 10, 9
]
var initial_rotations: Array[int] = [1, 2, 3, 1, 2, 1, 3, 2, 1, 3, 2, 1]
var water_droplets: Array[MeshInstance3D] = []
var water_puddle: MeshInstance3D
var flow_parts: Array[MeshInstance3D] = []
var leak_time: float = 0.0


func _ready() -> void:
	_build_water_leak()
	_build_flow_visual()
	current_masks.clear()
	for index in range(target_masks.size()):
		current_masks.append(_rotate_mask(target_masks[index], initial_rotations[index]))


func _process(delta: float) -> void:
	if is_complete:
		return

	leak_time += delta
	for index in range(water_droplets.size()):
		var droplet := water_droplets[index]
		droplet.position.y -= delta * (1.15 + (index % 4) * 0.18)
		if droplet.position.y < -1.35:
			droplet.position.y = 0.12 + (index % 3) * 0.08
			droplet.position.x = -0.13 + (index % 5) * 0.065
			droplet.position.z = 0.05 + sin(leak_time * 1.7 + index) * 0.06
		droplet.scale = Vector3.ONE * (0.8 + 0.2 * sin(leak_time * 5.0 + index))


func get_interaction_prompt() -> String:
	if is_complete:
		return "PIPELINE CONNECTED"
	if puzzle_open:
		return ""
	return "E  RECONNECT THE PIPE"


func interact() -> void:
	if is_complete or puzzle_open:
		return
	_open_puzzle()


func _open_puzzle() -> void:
	puzzle_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = CanvasLayer.new()
	overlay.name = "PipelinePuzzleOverlay"
	overlay.layer = 30
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.005, 0.012, 0.03, 0.84)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(350, 86)
	panel.size = Vector2(580, 548)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.15, 0.98), Color(0.12, 0.28, 0.5, 1.0), 2))
	overlay.add_child(panel)

	var warning := Label.new()
	warning.position = Vector2(24, 14)
	warning.size = Vector2(532, 24)
	warning.text = "⚠  ⚠  ⚠  ⚠  ⚠  ⚠  ⚠  ⚠  ⚠  ⚠  ⚠  ⚠"
	warning.add_theme_color_override("font_color", Color(1.0, 0.72, 0.12, 1))
	warning.add_theme_font_size_override("font_size", 18)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(warning)

	var title := Label.new()
	title.position = Vector2(24, 52)
	title.size = Vector2(420, 34)
	title.text = "PIPELINE"
	title.add_theme_color_override("font_color", Color(0.18, 0.86, 1.0, 1))
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)

	var instructions := Label.new()
	instructions.position = Vector2(24, 89)
	instructions.size = Vector2(532, 46)
	instructions.text = "TAP SEGMENTS TO ROTATE — CONNECT THE INLET TO THE OUTLET.\nTHE CLOCK IS STILL RUNNING."
	instructions.add_theme_color_override("font_color", Color(0.68, 0.77, 0.9, 1))
	instructions.add_theme_font_size_override("font_size", 12)
	panel.add_child(instructions)

	var inlet := Label.new()
	inlet.position = Vector2(28, 273)
	inlet.size = Vector2(30, 40)
	inlet.text = "▶"
	inlet.add_theme_color_override("font_color", Color(1.0, 0.78, 0.16, 1))
	inlet.add_theme_font_size_override("font_size", 26)
	panel.add_child(inlet)

	var outlet := Label.new()
	outlet.position = Vector2(526, 273)
	outlet.size = Vector2(30, 40)
	outlet.text = "◀"
	outlet.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55, 1))
	outlet.add_theme_font_size_override("font_size", 26)
	panel.add_child(outlet)

	cell_buttons.clear()
	for index in range(current_masks.size()):
		var cell := Button.new()
		var column := index % GRID_COLUMNS
		var row := index / GRID_COLUMNS
		cell.position = Vector2(70 + column * 112, 163 + row * 100)
		cell.size = Vector2(104, 92)
		cell.focus_mode = Control.FOCUS_NONE
		cell.add_theme_font_size_override("font_size", 42)
		cell.add_theme_color_override("font_color", Color(0.53, 0.63, 0.78, 1))
		cell.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0, 1))
		cell.add_theme_stylebox_override("normal", _panel_style(Color(0.06, 0.12, 0.23, 1), Color(0.1, 0.2, 0.36, 1), 1))
		cell.add_theme_stylebox_override("hover", _panel_style(Color(0.09, 0.18, 0.32, 1), Color(0.2, 0.55, 0.75, 1), 2))
		cell.add_theme_stylebox_override("pressed", _panel_style(Color(0.04, 0.1, 0.2, 1), Color(0.25, 0.8, 1.0, 1), 2))
		cell.pressed.connect(_on_cell_pressed.bind(index))
		panel.add_child(cell)
		cell_buttons.append(cell)

	var status := Label.new()
	status.name = "PipelineStatus"
	status.position = Vector2(24, 466)
	status.size = Vector2(280, 28)
	status.text = "NO FLOW YET"
	status.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 1))
	status.add_theme_font_size_override("font_size", 13)
	panel.add_child(status)

	var walk_away := Button.new()
	walk_away.position = Vector2(420, 462)
	walk_away.size = Vector2(126, 38)
	walk_away.text = "WALK AWAY"
	walk_away.focus_mode = Control.FOCUS_NONE
	walk_away.add_theme_font_size_override("font_size", 12)
	walk_away.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.13, 0.23, 1), Color(0.18, 0.3, 0.48, 1), 1))
	walk_away.pressed.connect(_close_puzzle)
	panel.add_child(walk_away)

	_refresh_cells()


func _unhandled_input(event: InputEvent) -> void:
	if not puzzle_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_puzzle()
		get_viewport().set_input_as_handled()


func _on_cell_pressed(index: int) -> void:
	if not puzzle_open or is_complete:
		return
	current_masks[index] = _rotate_mask(current_masks[index], 1)
	_refresh_cells()
	if _is_solved():
		_complete_puzzle()


func _refresh_cells() -> void:
	for index in range(cell_buttons.size()):
		var cell := cell_buttons[index]
		cell.text = _mask_symbol(current_masks[index])
		cell.tooltip_text = "Rotate pipe"
		if current_masks[index] == target_masks[index]:
			cell.add_theme_color_override("font_color", Color(0.54, 0.67, 0.82, 1))
		else:
			cell.add_theme_color_override("font_color", Color(0.38, 0.48, 0.64, 1))


func _is_solved() -> bool:
	for index in range(target_masks.size()):
		if current_masks[index] != target_masks[index]:
			return false
	return true


func _complete_puzzle() -> void:
	is_complete = true
	_hide_leak()
	for flow_part in flow_parts:
		flow_part.visible = true
	completed.emit(task_kind)
	_close_puzzle()


func _close_puzzle() -> void:
	if not puzzle_open:
		return
	puzzle_open = false
	if overlay != null:
		overlay.queue_free()
		overlay = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rotate_mask(mask: int, turns: int) -> int:
	var result := mask
	for _turn in range(turns % 4):
		var rotated := 0
		if result & UP:
			rotated |= RIGHT
		if result & RIGHT:
			rotated |= DOWN
		if result & DOWN:
			rotated |= LEFT
		if result & LEFT:
			rotated |= UP
		result = rotated
	return result


func _mask_symbol(mask: int) -> String:
	match mask:
		1:
			return "╵"
		2:
			return "╴"
		3:
			return "└"
		4:
			return "╷"
		5:
			return "│"
		6:
			return "┌"
		7:
			return "├"
		8:
			return "╶"
		9:
			return "┘"
		10:
			return "─"
		11:
			return "┴"
		12:
			return "┐"
		13:
			return "┤"
		14:
			return "┬"
		15:
			return "┼"
		_:
			return "·"


func _panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.72, 1.0, 0.78)
	material.emission_enabled = true
	material.emission = Color(0.02, 0.34, 0.85, 1)
	material.emission_energy_multiplier = 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.18
	return material


func _build_water_leak() -> void:
	var water_material := _water_material()
	for index in range(12):
		var droplet := MeshInstance3D.new()
		droplet.name = "LeakingWater%d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 0.035 + (index % 3) * 0.012
		mesh.height = 0.1 + (index % 2) * 0.04
		mesh.radial_segments = 8
		mesh.rings = 4
		droplet.mesh = mesh
		droplet.material_override = water_material
		droplet.position = Vector3(
			-0.13 + (index % 5) * 0.065,
			0.12 + (index % 4) * 0.11,
			0.05 + sin(index * 1.9) * 0.07
		)
		add_child(droplet)
		water_droplets.append(droplet)

	water_puddle = MeshInstance3D.new()
	water_puddle.name = "PipelineLeakPuddle"
	var puddle_mesh := CylinderMesh.new()
	puddle_mesh.top_radius = 0.38
	puddle_mesh.bottom_radius = 0.38
	puddle_mesh.height = 0.025
	puddle_mesh.radial_segments = 32
	water_puddle.mesh = puddle_mesh
	water_puddle.material_override = water_material
	water_puddle.position = Vector3(0.0, -1.3, 0.15)
	add_child(water_puddle)


func _build_flow_visual() -> void:
	var flow_material := _water_material()
	flow_material.albedo_color = Color(0.1, 0.9, 1.0, 1)
	flow_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	for index in range(4):
		var segment := MeshInstance3D.new()
		segment.name = "PipelineFlow%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.15, 0.15, 0.68)
		segment.mesh = mesh
		segment.material_override = flow_material
		segment.position = Vector3(0, 0, -1.02 + index * 0.68)
		segment.visible = false
		add_child(segment)
		flow_parts.append(segment)


func _hide_leak() -> void:
	for droplet in water_droplets:
		droplet.visible = false
	if water_puddle != null:
		water_puddle.visible = false