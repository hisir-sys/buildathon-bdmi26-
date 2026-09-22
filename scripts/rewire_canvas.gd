extends Control

signal pair_connected(pair_id: int)

const HIT_RADIUS := 26.0

var left_positions: Array[Vector2] = []
var right_positions: Array[Vector2] = []
var right_order: Array[int] = []
var connected: Array[bool] = []
var pair_colors: Array[Color] = []

var dragging_pair: int = -1
var drag_point: Vector2 = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for pair_id in range(left_positions.size()):
				if connected[pair_id]:
					continue
				if left_positions[pair_id].distance_to(event.position) <= HIT_RADIUS:
					dragging_pair = pair_id
					drag_point = event.position
					queue_redraw()
					return
		else:
			if dragging_pair != -1:
				var released_slot := -1
				for slot in range(right_positions.size()):
					if right_positions[slot].distance_to(event.position) <= HIT_RADIUS:
						released_slot = slot
						break
				if released_slot != -1 and not connected[right_order[released_slot]] and right_order[released_slot] == dragging_pair:
					connected[dragging_pair] = true
					pair_connected.emit(dragging_pair)
				dragging_pair = -1
				queue_redraw()
	elif event is InputEventMouseMotion and dragging_pair != -1:
		drag_point = event.position
		queue_redraw()


func _draw() -> void:
	for pair_id in range(connected.size()):
		if connected[pair_id]:
			var slot := right_order.find(pair_id)
			_draw_wire(left_positions[pair_id], right_positions[slot], pair_colors[pair_id], 6.0)

	if dragging_pair != -1:
		_draw_wire(left_positions[dragging_pair], drag_point, pair_colors[dragging_pair], 5.0)

	for pair_id in range(left_positions.size()):
		_draw_stub(left_positions[pair_id], pair_colors[pair_id], pair_id, connected[pair_id])
	for slot in range(right_positions.size()):
		var pair_id := right_order[slot]
		_draw_stub(right_positions[slot], pair_colors[pair_id], pair_id, connected[pair_id])


func _draw_wire(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var mid := (from + to) * 0.5
	var control_a := Vector2(mid.x, from.y)
	var control_b := Vector2(mid.x, to.y)
	var steps := 20
	var previous := from
	for index in range(1, steps + 1):
		var t := float(index) / float(steps)
		var point: Vector2 = from.bezier_interpolate(control_a, control_b, to, t)
		draw_line(previous, point, color, width, true)
		previous = point


func _draw_stub(pos: Vector2, color: Color, shape_id: int, is_connected: bool) -> void:
	var ring_color := Color(1, 1, 1, 1) if is_connected else Color(0.7, 0.75, 0.85, 1)
	draw_circle(pos, 16.0, color)
	draw_arc(pos, 16.0, 0, TAU, 24, ring_color, 2.0, true)
	_draw_shape_glyph(pos, shape_id)


func _draw_shape_glyph(pos: Vector2, shape_id: int) -> void:
	var glyph_color := Color(0.05, 0.05, 0.08, 1)
	match shape_id:
		0:
			draw_circle(pos, 5.0, glyph_color)
		1:
			var points: Array[Vector2] = [pos + Vector2(0, -6), pos + Vector2(5, 5), pos + Vector2(-5, 5)]
			draw_colored_polygon(points, glyph_color)
		2:
			draw_line(pos + Vector2(-5, -5), pos + Vector2(5, 5), glyph_color, 2.5, true)
			draw_line(pos + Vector2(-5, 5), pos + Vector2(5, -5), glyph_color, 2.5, true)
		3:
			var points: Array[Vector2] = []
			for index in range(10):
				var angle := -PI * 0.5 + index * PI / 5.0
				var radius := 6.0 if index % 2 == 0 else 2.5
				points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, glyph_color)
