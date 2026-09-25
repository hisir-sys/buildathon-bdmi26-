extends CanvasLayer

const COLOR_CLEAN := "#ff5c4d"
const COLOR_MECH := "#4da8ff"
const COLOR_WASH := "#5cf0a0"
const COLOR_DONE := "#5c6b82"
const COLOR_TEXT := "#e4edf7"
const FURNITURE_TOTAL := 5

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_key_badge: Control = $InteractionPrompt/KeyBadge
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: RichTextLabel = $TaskBoard/TaskLabel
@onready var task_fraction_label: Label = $TaskBoard/Fraction
@onready var sound_button: Button = $SoundButton
@onready var pause_button: Button = $PauseButton
@onready var hotbar_slots: Array[Panel] = [$Hotbar/Slot0, $Hotbar/Slot1, $Hotbar/Slot2, $Hotbar/Slot3]

const HOTBAR_ACTIVE_BORDER := Color(1, 0.8, 0.3, 1)
const HOTBAR_NORMAL_BORDER := Color(0.14, 0.45, 0.62, 0.55)
const HOTBAR_ACTIVE_BG := Color(0.07, 0.1, 0.16, 0.97)
const HOTBAR_NORMAL_BG := Color(0.03, 0.05, 0.1, 0.85)

var sound_enabled: bool = true
var is_paused: bool = false
var key_badge: PanelContainer
var collected_items_panel: PanelContainer
var collected_items_label: Label
var collected_items: Array[String] = []
var suspicion_bar_fill: ColorRect
var suspicion_bar_track: Control
var suspicion_percent_label: Label
const SUSPICION_BAR_WIDTH := 220.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_interaction_prompt("")
	sound_button.pressed.connect(_toggle_sound)
	pause_button.pressed.connect(_toggle_pause)
	_build_key_badge()
	_build_suspicion_meter()
	_build_collected_items()
	_build_toast()
	if has_node("/root/SuspicionManager"):
		get_node("/root/SuspicionManager").connect("suspicion_changed", set_suspicion)


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	if prompt_text.begins_with("E  "):
		interaction_key_badge.visible = true
		interaction_label.text = prompt_text.substr(3)
	else:
		interaction_key_badge.visible = false
		interaction_label.text = prompt_text


func set_task_counts(rows: Array) -> void:
	# rows: Array of Dictionary {label:String, current:int, total:int, color:String}
	# Only currently-active tasks should be passed in - the fraction shown
	# is "completed / rows.size()", not a hardcoded /5, so it stays correct
	# whether RunGenerator left 5 tasks active (the normal case) or the
	# generator hasn't run yet and all 9 are still active.
	var lines: Array[String] = []
	var completed := 0
	for row in rows:
		var current: int = row.get("current", 0)
		var total: int = row.get("total", 1)
		if current >= total:
			completed += 1
		lines.append(_task_row(row.get("label", ""), current, total, row.get("color", COLOR_TEXT)))
	task_label.text = "\n".join(lines)
	task_fraction_label.text = "%d/%d" % [completed, rows.size()]


func _task_row(label_text: String, current: int, total: int, accent_color: String) -> String:
	var is_done := current >= total
	var padded_label := label_text
	while padded_label.length() < 14:
		padded_label += " "
	var count_text := "%d/%d" % [current, total]
	if is_done:
		return "[color=%s]✓[/color] [s][color=%s]%s %s[/color][/s]" % [accent_color, COLOR_DONE, padded_label, count_text]
	return "[color=%s]◆[/color] [color=%s]%s[/color] %s" % [accent_color, COLOR_TEXT, padded_label, count_text]


func mark_furniture_complete(furniture_count: int, total: int = FURNITURE_TOTAL) -> void:
	if furniture_count >= total:
		set_interaction_prompt("FURNITURE TASK COMPLETE")
	else:
		set_interaction_prompt("FURNITURE %d/%d PLACED" % [furniture_count, total])


func set_timer(seconds_left: int) -> void:
	var minutes := seconds_left / 60
	var seconds := seconds_left % 60
	$TimerPanel/TimerLabel.text = "%02d:%02d" % [minutes, seconds]


func set_time_expired() -> void:
	$TimerPanel/TimerLabel.text = "00:00"


func set_active_tool(tool_index: int) -> void:
	for index in range(hotbar_slots.size()):
		var style := hotbar_slots[index].get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style == null:
			continue
		var is_active := index == tool_index
		style.border_color = HOTBAR_ACTIVE_BORDER if is_active else HOTBAR_NORMAL_BORDER
		var border_width := 3 if is_active else 1
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.bg_color = HOTBAR_ACTIVE_BG if is_active else HOTBAR_NORMAL_BG
		hotbar_slots[index].add_theme_stylebox_override("panel", style)


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	AudioServer.set_bus_mute(0, not sound_enabled)
	sound_button.text = "🔊" if sound_enabled else "🔇"


func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_button.text = "Ⅱ" if is_paused else "▶"


func set_key_owned(has_key: bool) -> void:
	key_badge.visible = has_key
	if has_key:
		add_collected_item("CHEST KEY")


func add_collected_item(item_name: String) -> void:
	var normalized_name := item_name.strip_edges().to_upper()
	if normalized_name.is_empty() or collected_items.has(normalized_name):
		return
	collected_items.append(normalized_name)

	var lines: Array[String] = []
	for item in collected_items:
		lines.append("• " + item)
	collected_items_label.text = "\n".join(lines)


func set_suspicion(new_value: float, max_value: float) -> void:
	var ratio := clampf(new_value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	suspicion_bar_fill.size.x = SUSPICION_BAR_WIDTH * ratio
	suspicion_percent_label.text = "SUSPICION  %d%%" % int(ratio * 100.0)
	# Green -> amber -> red as suspicion climbs, so the risk reads at a glance.
	var color: Color
	if ratio < 0.5:
		color = Color(0.3, 0.8, 0.45, 1).lerp(Color(0.95, 0.75, 0.2, 1), ratio / 0.5)
	else:
		color = Color(0.95, 0.75, 0.2, 1).lerp(Color(0.9, 0.2, 0.22, 1), (ratio - 0.5) / 0.5)
	suspicion_bar_fill.color = color


func _build_key_badge() -> void:
	# Small "KEY" chip under the task board, shown while the key is carried.
	key_badge = PanelContainer.new()
	key_badge.name = "KeyBadge"
	key_badge.offset_left = 24.0
	key_badge.offset_top = 300.0
	key_badge.offset_right = 184.0
	key_badge.offset_bottom = 338.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.1, 0.9)
	style.border_color = Color(0.92, 0.72, 0.22, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	key_badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "KEY COLLECTED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3, 1))
	key_badge.add_child(label)
	key_badge.visible = false
	add_child(key_badge)


func _build_suspicion_meter() -> void:
	# Top-right glass panel, sits above the interaction prompt row.
	var panel := PanelContainer.new()
	panel.name = "SuspicionMeter"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -260.0
	panel.offset_right = -24.0
	panel.offset_top = 24.0
	panel.offset_bottom = 24.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.82)
	style.border_color = Color(0.9, 0.3, 0.25, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	suspicion_percent_label = Label.new()
	suspicion_percent_label.text = "SUSPICION  0%"
	suspicion_percent_label.add_theme_font_size_override("font_size", 13)
	suspicion_percent_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98, 0.9))
	column.add_child(suspicion_percent_label)

	suspicion_bar_track = Control.new()
	suspicion_bar_track.custom_minimum_size = Vector2(SUSPICION_BAR_WIDTH, 8)
	column.add_child(suspicion_bar_track)

	var track_bg := ColorRect.new()
	track_bg.size = Vector2(SUSPICION_BAR_WIDTH, 8)
	track_bg.color = Color(1, 1, 1, 0.08)
	suspicion_bar_track.add_child(track_bg)

	suspicion_bar_fill = ColorRect.new()
	suspicion_bar_fill.size = Vector2(0, 8)
	suspicion_bar_fill.color = Color(0.3, 0.8, 0.45, 1)
	suspicion_bar_track.add_child(suspicion_bar_fill)


func _build_collected_items() -> void:
	collected_items_panel = PanelContainer.new()
	collected_items_panel.name = "CollectedItems"
	collected_items_panel.anchor_left = 1.0
	collected_items_panel.anchor_right = 1.0
	collected_items_panel.anchor_top = 1.0
	collected_items_panel.anchor_bottom = 1.0
	collected_items_panel.offset_left = -264.0
	collected_items_panel.offset_right = -24.0
	collected_items_panel.offset_top = -164.0
	collected_items_panel.offset_bottom = -24.0
	collected_items_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	collected_items_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	collected_items_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.86)
	style.border_color = Color(0.3, 0.6, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	collected_items_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	collected_items_panel.add_child(column)

	var title := Label.new()
	title.text = "COLLECTED ITEMS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.62, 0.78, 0.94, 0.95))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	collected_items_label = Label.new()
	collected_items_label.text = "None yet"
	collected_items_label.add_theme_font_size_override("font_size", 13)
	collected_items_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.95))
	collected_items_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(collected_items_label)

	add_child(collected_items_panel)


# --- Toast: a short message that fades out on its own ----------------------

var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.name = "Toast"
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.offset_left = -160.0
	toast_panel.offset_right = 160.0
	toast_panel.offset_top = 70.0
	toast_panel.offset_bottom = 70.0
	toast_panel.grow_vertical = Control.GROW_DIRECTION_END
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.92)
	style.border_color = Color(0.92, 0.72, 0.22, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	toast_panel.add_theme_stylebox_override("panel", style)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3, 1))
	toast_panel.add_child(toast_label)

	toast_panel.visible = false
	add_child(toast_panel)


func show_toast(message: String, seconds: float = 2.5) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(seconds)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.tween_callback(func() -> void:
		toast_panel.visible = false
	)
