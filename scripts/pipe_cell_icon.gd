extends Control

const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8

var mask: int = 0:
	set(value):
		mask = value
		queue_redraw()

var line_color: Color = Color(0.572, 0.624, 0.702, 1):
	set(value):
		line_color = value
		queue_redraw()

var line_width: float = 10.0


func _draw() -> void:
	var center := size * 0.5
	var reach: float = minf(size.x, size.y) * 0.5 - line_width * 0.5
	if mask & UP:
		draw_line(center, center + Vector2(0, -reach), line_color, line_width, true)
	if mask & DOWN:
		draw_line(center, center + Vector2(0, reach), line_color, line_width, true)
	if mask & LEFT:
		draw_line(center, center + Vector2(-reach, 0), line_color, line_width, true)
	if mask & RIGHT:
		draw_line(center, center + Vector2(reach, 0), line_color, line_width, true)
	draw_circle(center, line_width * 0.62, line_color)
