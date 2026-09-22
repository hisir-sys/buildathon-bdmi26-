extends StaticBody3D

signal completed(task_kind: String)

const RewireCanvasScript = preload("res://scripts/rewire_canvas.gd")

@export var task_kind: String = "panel"

const PAIR_COLORS: Array[Color] = [
	Color(0.95, 0.25, 0.2, 1),
	Color(0.25, 0.55, 0.95, 1),
	Color(0.95, 0.85, 0.15, 1),
	Color(0.95, 0.35, 0.85, 1)
]

var is_complete: bool = false
var puzzle_open: bool = false
var overlay: CanvasLayer
var canvas: Control
var status_label: Label
var connected_count: int = 0

var top_wires: Array[MeshInstance3D] = []
var bottom_wires: Array[MeshInstance3D] = []
var top_frays: Array[MeshInstance3D] = []
var bottom_frays: Array[MeshInstance3D] = []
var center_ring: MeshInstance3D
var center_ring_light: OmniLight3D
var status_light: MeshInstance3D


func _ready() -> void:
	for index in range(4):
		top_wires.append(get_node_or_null("TopWire%d" % index))
		bottom_wires.append(get_node_or_null("BottomWire%d" % index))
		top_frays.append(get_node_or_null("TopFray%d" % index))
		bottom_frays.append(get_node_or_null("BottomFray%d" % index))
	center_ring = get_node_or_null("CenterRing")
	center_ring_light = get_node_or_null("CenterRingLight")
	status_light = get_node_or_null("StatusLight")


func interact() -> void:
	if is_complete or puzzle_open:
		return
	_open_puzzle()


func get_interaction_prompt() -> String:
	if is_complete:
		return "WIRING FIXED"
	if puzzle_open:
		return ""
	return "E  FIX THE WIRING"


func _open_puzzle() -> void:
	puzzle_open = true
	connected_count = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	overlay = CanvasLayer.new()
	overlay.name = "RewirePuzzleOverlay"
	overlay.layer = 30
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.005, 0.012, 0.03, 0.84)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(390, 96)
	panel.size = Vector2(500, 528)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.15, 0.98), Color(0.12, 0.28, 0.5, 1.0), 2))
	overlay.add_child(panel)

	var title := Label.new()
	title.position = Vector2(24, 18)
	title.size = Vector2(400, 34)
	title.text = "REWIRE PANEL"
	title.add_theme_color_override("font_color", Color(0.18, 0.86, 1.0, 1))
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)

	var instructions := Label.new()
	instructions.position = Vector2(24, 54)
	instructions.size = Vector2(452, 40)
	instructions.text = "DRAG EACH FRAYED WIRE TO ITS MATCHING COLOR AND SHAPE.\nTHE CLOCK IS STILL RUNNING."
	instructions.add_theme_color_override("font_color", Color(0.68, 0.77, 0.9, 1))
	instructions.add_theme_font_size_override("font_size", 12)
	panel.add_child(instructions)

	# The two dark "conduit" columns the wires emerge from, like the
	# reference - a subtler backdrop than a flat panel.
	var conduit_style := _panel_style(Color(0.055, 0.06, 0.075, 1.0), Color(0.02, 0.02, 0.03, 1.0), 1)
	var left_conduit := Panel.new()
	left_conduit.position = Vector2(4, 104)
	left_conduit.size = Vector2(74, 340)
	left_conduit.add_theme_stylebox_override("panel", conduit_style)
	panel.add_child(left_conduit)

	var right_conduit := Panel.new()
	right_conduit.position = Vector2(398, 104)
	right_conduit.size = Vector2(74, 340)
	right_conduit.add_theme_stylebox_override("panel", conduit_style)
	panel.add_child(right_conduit)

	canvas = Control.new()
	canvas.name = "RewireCanvas"
	canvas.position = Vector2(24, 104)
	canvas.size = Vector2(452, 340)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.set_script(RewireCanvasScript)
	panel.add_child(canvas)

	var left_positions: Array[Vector2] = []
	var right_positions: Array[Vector2] = []
	for index in range(PAIR_COLORS.size()):
		left_positions.append(Vector2(30, 40 + index * 90))
		right_positions.append(Vector2(422, 40 + index * 90))

	var right_order: Array[int] = []
	for index in range(PAIR_COLORS.size()):
		right_order.append(index)
	right_order.shuffle()
	# Guard against an accidental identity shuffle so the puzzle isn't trivial.
	var is_identity := true
	for index in range(right_order.size()):
		if right_order[index] != index:
			is_identity = false
			break
	if is_identity:
		right_order.reverse()

	var connected_flags: Array[bool] = []
	connected_flags.resize(PAIR_COLORS.size())
	connected_flags.fill(false)

	canvas.set("left_positions", left_positions)
	canvas.set("right_positions", right_positions)
	canvas.set("right_order", right_order)
	canvas.set("connected", connected_flags)
	canvas.set("pair_colors", PAIR_COLORS)
	canvas.pair_connected.connect(_on_pair_connected)

	status_label = Label.new()
	status_label.position = Vector2(24, 456)
	status_label.size = Vector2(280, 28)
	status_label.text = "0 / %d WIRES CONNECTED" % PAIR_COLORS.size()
	status_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 1))
	status_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(status_label)

	var walk_away := Button.new()
	walk_away.position = Vector2(350, 452)
	walk_away.size = Vector2(126, 38)
	walk_away.text = "WALK AWAY"
	walk_away.focus_mode = Control.FOCUS_NONE
	walk_away.add_theme_font_size_override("font_size", 12)
	walk_away.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.13, 0.23, 1), Color(0.18, 0.3, 0.48, 1), 1))
	walk_away.pressed.connect(_close_puzzle)
	panel.add_child(walk_away)


func _unhandled_input(event: InputEvent) -> void:
	if not puzzle_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_puzzle()
		get_viewport().set_input_as_handled()


func _on_pair_connected(_pair_id: int) -> void:
	connected_count += 1
	if status_label != null:
		status_label.text = "%d / %d WIRES CONNECTED" % [connected_count, PAIR_COLORS.size()]
	if connected_count >= PAIR_COLORS.size():
		_complete_puzzle()


func _complete_puzzle() -> void:
	is_complete = true
	if status_label != null:
		status_label.text = "WIRING FIXED"
		status_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1))
	_apply_fixed_visual()
	completed.emit(task_kind)
	await get_tree().create_timer(1.0).timeout
	_close_puzzle()


func _apply_fixed_visual() -> void:
	# The frayed break in each wire disappears and the strand glows
	# brighter, reading as freshly rejoined.
	for wire in top_wires + bottom_wires:
		if wire == null:
			continue
		var wire_material := wire.material_override as StandardMaterial3D
		if wire_material != null:
			wire_material.emission_energy_multiplier = 2.4
	for fray in top_frays + bottom_frays:
		if fray != null:
			fray.visible = false
	if center_ring != null:
		var ring_material := center_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color = Color(0.2, 1.0, 0.5, 1)
			ring_material.emission = Color(0.25, 1.0, 0.5, 1)
			ring_material.emission_energy_multiplier = 2.6
	if center_ring_light != null:
		center_ring_light.light_color = Color(0.3, 1.0, 0.55, 1)
		center_ring_light.light_energy = 1.8
	if status_light != null:
		var status_material := status_light.material_override as StandardMaterial3D
		if status_material != null:
			status_material.albedo_color = Color(0.2, 1.0, 0.4, 1)
			status_material.emission = Color(0.2, 1.0, 0.4, 1)


func _close_puzzle() -> void:
	if not puzzle_open:
		return
	puzzle_open = false
	if overlay != null:
		overlay.queue_free()
		overlay = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style
