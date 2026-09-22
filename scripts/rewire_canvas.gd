extends Control

signal pair_connected(pair_id: int)

const HIT_RADIUS := 26.0
const FRAY_COLOR := Color(0.42, 0.3, 0.18, 1)

var left_positions: Array[Vector2] = []
var right_positions: Array[Vector2] = []
var right_order: Array[int] = []
var connected: Array[bool] = []
var pair_colors: Array[Color] = []

var dragging_pair: int = -1
var drag_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	# Keeps the loose, frayed wire ends gently drifting so the panel reads
	# as "broken" rather than static, until each pair is connected.
	queue_redraw()


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
	var time := Time.get_ticks_msec() / 1000.0

	for pair_id in range(connected.size()):
		if connected[pair_id]:
			var slot := right_order.find(pair_id)
			_draw_cable(left_positions[pair_id], right_positions[slot], pair_colors[pair_id], 8.0)
		else:
			_draw_fray(left_positions[pair_id], pair_colors[pair_id], time, pair_id * 1.7)
			var slot := right_order.find(pair_id)
			_draw_fray(right_positions[slot], pair_colors[pair_id], time, pair_id * 1.7 + 3.1)

	if dragging_pair != -1:
		_draw_cable(left_positions[dragging_pair], drag_point, pair_colors[dragging_pair], 7.0)

	for pair_id in range(left_positions.size()):
		_draw_stub(left_positions[pair_id], pair_colors[pair_id], pair_id, connected[pair_id])
	for slot in range(right_positions.size()):
		var pair_id := right_order[slot]
		_draw_stub(right_positions[slot], pair_colors[pair_id], pair_id, connected[pair_id])


func _draw_cable(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var mid := (from + to) * 0.5
	var control_a := Vector2(mid.x, from.y)
	var control_b := Vector2(mid.x, to.y)
	var steps := 24
	var previous := from
	var shadow_color := color.darkened(0.55)
	shadow_color.a = 0.9
	var highlight_color := color.lightened(0.5)
	highlight_color.a = 0.55
	for index in range(1, steps + 1):
		var t := float(index) / float(steps)
		var point: Vector2 = from.bezier_interpolate(control_a, control_b, to, t)
		# Cable shadow underneath, the colored strand on top, and a thin
		# highlight stripe for a glossy, tangible-wire look.
		draw_line(previous, point, shadow_color, width + 3.0, true)
		draw_line(previous, point, color, width, true)
		draw_line(previous + Vector2(0, -width * 0.22), point + Vector2(0, -width * 0.22), highlight_color, width * 0.28, true)
		previous = point


func _draw_fray(pos: Vector2, color: Color, time: float, phase: float) -> void:
	# A short, twitchy frayed-copper tail hanging off an unconnected stub -
	# reads as a broken wire waiting to be reconnected.
	var strand_count := 4
	for strand in range(strand_count):
		var wobble := sin(time * 3.5 + phase + strand) * 5.0
		var base_angle := (float(strand) / float(strand_count - 1) - 0.5) * 1.1 + PI * 0.5
		var length := 13.0 + strand % 2 * 4.0
		var tip := pos + Vector2(cos(base_angle), sin(base_angle)) * length + Vector2(wobble, 0)
		draw_line(pos, tip, FRAY_COLOR, 2.0, true)
	draw_circle(pos, 4.0, color.darkened(0.3))


func _draw_stub(pos: Vector2, color: Color, shape_id: int, is_connected: bool) -> void:
	var badge_size := Vector2(30, 20)
	var badge_rect := Rect2(pos - badge_size * 0.5, badge_size)
	draw_rect(badge_rect, color, true)
	var ring_color := Color(1, 1, 1, 1) if is_connected else Color(0.15, 0.15, 0.18, 0.9)
	draw_rect(badge_rect, ring_color, false, 2.0)
	_draw_shape_glyph(pos, shape_id)


func _draw_shape_glyph(pos: Vector2, shape_id: int) -> void:
	var glyph_color := Color(0.05, 0.05, 0.08, 1)
	match shape_id:
		0:
			draw_arc(pos, 6.0, 0, TAU, 16, glyph_color, 2.2, true)
		1:
			var points: Array[Vector2] = [pos + Vector2(0, -6), pos + Vector2(5, 5), pos + Vector2(-5, 5)]
			for index in range(points.size()):
				draw_line(points[index], points[(index + 1) % points.size()], glyph_color, 2.2, true)
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
