extends RefCounted
# Shared "glass" UI helpers for the start and ending screens.


static func label(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = align
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func glass_style(fill: Color, border: Color, radius: int = 4, shadow_color: Color = Color(0, 0, 0, 0.55), shadow_size: int = 24) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func glass_button(text: String, accent: Color, min_size: Vector2 = Vector2(320, 56)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	button.add_theme_stylebox_override("normal", glass_style(Color(accent.r, accent.g, accent.b, 0.16), Color(accent.r, accent.g, accent.b, 0.75), 2, Color(0, 0, 0, 0.0), 0))
	button.add_theme_stylebox_override("hover", glass_style(Color(accent.r, accent.g, accent.b, 0.36), Color(1, 1, 1, 0.9), 2, Color(accent.r, accent.g, accent.b, 0.45), 16))
	button.add_theme_stylebox_override("pressed", glass_style(Color(accent.r, accent.g, accent.b, 0.55), Color(1, 1, 1, 1), 2, Color(accent.r, accent.g, accent.b, 0.6), 10))
	button.add_theme_stylebox_override("disabled", glass_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.2), 2, Color(0, 0, 0, 0.0), 0))
	return button
