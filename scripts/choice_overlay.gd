extends CanvasLayer
# The chest decision panel. Fades in over the frozen, dimmed scene with a low
# humming tone, and forces a choice between two buttons. Clicking one plays a
# bright flash; at the peak of the flash `chosen` fires (the chest applies the
# result while the screen is white), then the flash fades out and this layer
# frees itself.

signal chosen(steal: bool)

const SAMPLE_RATE := 22050.0

var root: Control
var dim: ColorRect
var panel: PanelContainer
var flash: ColorRect
var steal_button: Button
var leave_button: Button
var hum_player: AudioStreamPlayer
var hum_playback: AudioStreamGeneratorPlayback
var hum_active: bool = false
var hum_time: float = 0.0
var hum_level: float = 0.0
var locked: bool = false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_hum()


func show_choice() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.visible = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.9)
	tween.tween_property(dim, "color:a", 0.35, 0.9)
	_start_hum()


func _process(delta: float) -> void:
	if not hum_active or hum_playback == null:
		return
	hum_level = minf(hum_level + delta * 0.5, 1.0)
	var increment := 1.0 / SAMPLE_RATE
	var frames := hum_playback.get_frames_available()
	for i in range(frames):
		hum_time += increment
		var swell := 0.75 + 0.25 * sin(TAU * 0.35 * hum_time)
		var tone := sin(TAU * 55.0 * hum_time) * 0.6
		tone += sin(TAU * 110.5 * hum_time) * 0.25
		tone += sin(TAU * 164.0 * hum_time) * 0.1
		var sample := tone * swell * hum_level
		hum_playback.push_frame(Vector2(sample, sample))


func _build_ui() -> void:
	root = Control.new()
	root.name = "ChoiceRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate = Color(1, 1, 1, 0)
	root.visible = false
	add_child(root)

	dim = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.05, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	panel = PanelContainer.new()
	panel.name = "ChoicePanel"
	panel.custom_minimum_size = Vector2(640, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.11, 0.96)
	panel_style.border_color = Color(0.765, 0.676, 0.478, 1)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 26
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	column.add_child(_label("A  DECISION", 13, Color(0.765, 0.676, 0.478, 1)))
	column.add_child(_label("THE DIAMOND", 42, Color(0.92, 0.96, 1.0, 1)))
	column.add_child(_label("Nobody's watching. Nobody would know.", 17, Color(0.6, 0.7, 0.86, 1)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	column.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)

	steal_button = _make_button("STEAL THE DIAMOND", Color(0.45, 0.241, 0.262, 1), Color(0.738, 0.404, 0.435, 1))
	leave_button = _make_button("LEAVE THE DIAMOND", Color(0.07, 0.34, 0.32, 1), Color(0.287, 0.522, 0.491, 1))
	buttons.add_child(steal_button)
	buttons.add_child(leave_button)
	steal_button.pressed.connect(_on_pressed.bind(true))
	leave_button.pressed.connect(_on_pressed.bind(false))

	column.add_child(_label("This choice cannot be undone.", 12, Color(0.436, 0.477, 0.54, 1)))

	flash = ColorRect.new()
	flash.name = "Flash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, base: Color, hover: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 66)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.95, 0.97, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_stylebox_override("normal", _button_style(base, base.lightened(0.25)))
	button.add_theme_stylebox_override("hover", _button_style(hover, Color(1, 1, 1, 0.9)))
	button.add_theme_stylebox_override("pressed", _button_style(hover.darkened(0.2), Color(1, 1, 1, 0.9)))
	button.add_theme_stylebox_override("disabled", _button_style(base.darkened(0.3), base))
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style


func _build_hum() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.3
	hum_player = AudioStreamPlayer.new()
	hum_player.stream = stream
	hum_player.volume_db = -16.0
	add_child(hum_player)


func _start_hum() -> void:
	hum_player.play()
	hum_playback = hum_player.get_stream_playback() as AudioStreamGeneratorPlayback
	hum_active = hum_playback != null


func _on_pressed(steal: bool) -> void:
	if locked:
		return
	locked = true
	SoundManager.play_ui_click()
	steal_button.disabled = true
	leave_button.disabled = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(flash, "color:a", 1.0, 0.12)
	tween.tween_callback(_at_flash_peak.bind(steal))
	tween.tween_interval(0.08)
	tween.tween_property(flash, "color:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _at_flash_peak(steal: bool) -> void:
	# Screen is fully white: clear the UI, silence the hum, and let the chest
	# apply the result and hand control back to the player.
	panel.visible = false
	dim.color.a = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hum_active = false
	hum_player.stop()
	chosen.emit(steal)
