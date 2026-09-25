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
@onready var hotbar_slots: Array[Panel] = [$Hotbar/Slot0, $Hotbar/Slot1, $Hotbar/Slot2]

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

# Premium HUD / pause overlay
var pause_overlay: Control
var pause_card: PanelContainer
var pause_resume_button: Button
var pause_hint_label: Label
var interaction_subtitle: Label
var interaction_progress_track: ColorRect
var interaction_progress_fill: ColorRect
var interaction_progress_value: float = 0.0
var status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_interaction_prompt("")
	sound_button.pressed.connect(_toggle_sound)
	pause_button.pressed.connect(_toggle_pause)
	_build_key_badge()
	_build_suspicion_meter()
	_build_collected_items()
	_build_toast()
	_build_premium_hud()
	_build_pause_menu()
	if has_node("/root/SuspicionManager"):
		get_node("/root/SuspicionManager").connect("suspicion_changed", set_suspicion)


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	if prompt_text.is_empty():
		if interaction_progress_track != null:
			interaction_progress_track.visible = false
		return

	var has_key_action := prompt_text.begins_with("E  ")
	interaction_key_badge.visible = has_key_action
	var clean_percent := -1
	var percent_match := RegEx.new()
	percent_match.compile("(\\d{1,3})%")
	var match := percent_match.search(prompt_text)
	if match != null:
		clean_percent = int(match.get_string(1))

	var display_text := prompt_text
	if has_key_action:
		display_text = prompt_text.substr(3)

	var is_cleaning := clean_percent >= 0 or display_text.to_lower().contains("clean") or display_text.to_lower().contains("scrubb") or display_text.to_lower().contains("clear")
	if interaction_label != null:
		interaction_label.text = display_text
		interaction_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	if interaction_subtitle != null:
		interaction_subtitle.text = "HOLD E  •  CLEANING" if is_cleaning and clean_percent < 0 else ("CLEANING IN PROGRESS" if clean_percent >= 0 else "INTERACT")
		interaction_subtitle.visible = true
	if interaction_progress_track != null:
		interaction_progress_track.visible = clean_percent >= 0
		if clean_percent >= 0:
			interaction_progress_fill.size.x = interaction_progress_track.size.x * clampf(float(clean_percent) / 100.0, 0.0, 1.0)
			interaction_progress_value = float(clean_percent) / 100.0


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
	_set_paused(not is_paused)

func _set_paused(value: bool) -> void:
	is_paused = value
	get_tree().paused = value
	if pause_overlay != null:
		pause_overlay.visible = value
	if pause_resume_button != null:
		if value:
			pause_resume_button.grab_focus()
		else:
			pause_resume_button.release_focus()
	if pause_button != null:
		pause_button.text = "▶" if value else "Ⅱ"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	_set_paused(not is_paused)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not is_paused)
		get_viewport().set_input_as_handled()


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


func _build_premium_hud() -> void:
	# Refine existing HUD cards without changing the gameplay layout.
	var task_board := get_node_or_null("TaskBoard") as Panel
	if task_board != null:
		var task_style := StyleBoxFlat.new()
		task_style.bg_color = Color(0.018, 0.028, 0.055, 0.94)
		task_style.border_color = Color(0.20, 0.72, 0.92, 0.38)
		task_style.set_border_width_all(1)
		task_style.set_corner_radius_all(12)
		task_style.shadow_color = Color(0, 0, 0, 0.58)
		task_style.shadow_size = 18
		task_style.content_margin_left = 4
		task_style.content_margin_right = 4
		task_style.content_margin_top = 3
		task_style.content_margin_bottom = 3
		task_board.add_theme_stylebox_override("panel", task_style)

	var title := task_board.get_node_or_null("Title") as Label
	if title != null:
		title.text = "SHIFT OBJECTIVES"
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0, 1))
	var fraction := task_board.get_node_or_null("Fraction") as Label
	if fraction != null:
		fraction.add_theme_font_size_override("font_size", 15)
		fraction.add_theme_color_override("font_color", Color(1.0, 0.80, 0.25, 1))

	var timer_panel := get_node_or_null("TimerPanel") as Panel
	if timer_panel != null:
		var timer_style := StyleBoxFlat.new()
		timer_style.bg_color = Color(0.018, 0.028, 0.055, 0.92)
		timer_style.border_color = Color(0.20, 0.72, 0.92, 0.45)
		timer_style.set_border_width_all(1)
		timer_style.set_corner_radius_all(12)
		timer_style.shadow_color = Color(0, 0, 0, 0.55)
		timer_style.shadow_size = 16
		timer_panel.add_theme_stylebox_override("panel", timer_style)

	# Small mission tag.
	var mission := Label.new()
	mission.text = "THE CLEANER  //  NIGHT SHIFT 01"
	mission.position = Vector2(26, 4)
	mission.add_theme_font_size_override("font_size", 9)
	mission.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82, 0.75))
	mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mission)

	# Bottom-right status strip.
	status_label = Label.new()
	status_label.anchor_left = 1.0
	status_label.anchor_right = 1.0
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = -420
	status_label.offset_right = -270
	status_label.offset_top = -46
	status_label.offset_bottom = -26
	status_label.text = "1  ELECTRICAL   2  MOP   3  SCRUBBER   •   ESC  PAUSE   •   E  INTERACT"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.54, 0.66, 0.80, 0.72))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	# Upgrade the interaction card.
	var prompt := interaction_panel as Panel
	if prompt != null:
		var prompt_style := StyleBoxFlat.new()
		prompt_style.bg_color = Color(0.018, 0.028, 0.055, 0.96)
		prompt_style.border_color = Color(1.0, 0.78, 0.22, 0.55)
		prompt_style.set_border_width_all(1)
		prompt_style.set_corner_radius_all(12)
		prompt_style.shadow_color = Color(0, 0, 0, 0.65)
		prompt_style.shadow_size = 18
		prompt.add_theme_stylebox_override("panel", prompt_style)
		interaction_label.position = Vector2(68, 16)
		interaction_label.add_theme_font_size_override("font_size", 16)
		interaction_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1, 1))
		interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		interaction_subtitle = Label.new()
		interaction_subtitle.position = Vector2(68, 39)
		interaction_subtitle.size = Vector2(398, 18)
		interaction_subtitle.add_theme_font_size_override("font_size", 9)
		interaction_subtitle.add_theme_color_override("font_color", Color(0.55, 0.67, 0.80, 0.9))
		interaction_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prompt.add_child(interaction_subtitle)

		interaction_progress_track = ColorRect.new()
		interaction_progress_track.position = Vector2(68, 58)
		interaction_progress_track.size = Vector2(398, 3)
		interaction_progress_track.color = Color(1, 1, 1, 0.08)
		interaction_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		interaction_progress_track.clip_contents = true
		prompt.add_child(interaction_progress_track)
		interaction_progress_fill = ColorRect.new()
		interaction_progress_fill.size = Vector2(0, 3)
		interaction_progress_fill.color = Color(1.0, 0.78, 0.22, 1)
		interaction_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		interaction_progress_track.add_child(interaction_progress_fill)
		interaction_progress_track.visible = false

func _make_button_style(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_key_chip(text_value: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := _make_button_style(Color(0.08, 0.11, 0.18, 1), Color(0.98, 0.78, 0.22, 0.65), 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1))
	chip.add_child(label)
	return chip

func _build_pause_menu() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	add_child(pause_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.009, 0.018, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(dim)

	pause_card = PanelContainer.new()
	pause_card.anchor_left = 0.5
	pause_card.anchor_right = 0.5
	pause_card.anchor_top = 0.5
	pause_card.anchor_bottom = 0.5
	pause_card.offset_left = -190
	pause_card.offset_right = 190
	pause_card.offset_top = -205
	pause_card.offset_bottom = 205
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.045, 0.09, 0.98)
	card_style.border_color = Color(0.16, 0.27, 0.42, 0.85)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(5)
	card_style.shadow_color = Color(0, 0, 0, 0.7)
	card_style.shadow_size = 30
	card_style.content_margin_left = 22
	card_style.content_margin_right = 22
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 18
	pause_card.add_theme_stylebox_override("panel", card_style)
	pause_overlay.add_child(pause_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	pause_card.add_child(column)

	var hazard := Label.new()
	hazard.text = "—  —  —  —  —  —  —  —  —  —"
	hazard.add_theme_font_size_override("font_size", 18)
	hazard.add_theme_color_override("font_color", Color(1.0, 0.80, 0.22, 1))
	hazard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hazard)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.22, 1))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THE CLOCK IS STOPPED. THE SHIFT IS ON HOLD."
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.56, 0.65, 0.77, 1))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 5)
	column.add_child(controls)
	var move_row := HBoxContainer.new()
	move_row.add_theme_constant_override("separation", 5)
	for key in ["W", "A", "S", "D"]:
		move_row.add_child(_make_key_chip(key))
	var move_label := Label.new()
	move_label.text = "  MOVE"
	move_label.add_theme_font_size_override("font_size", 10)
	move_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86, 1))
	move_row.add_child(move_label)
	controls.add_child(move_row)

	var look_row := HBoxContainer.new()
	look_row.add_theme_constant_override("separation", 5)
	look_row.add_child(_make_key_chip("MOUSE"))
	var look_label := Label.new()
	look_label.text = "  LOOK"
	look_label.add_theme_font_size_override("font_size", 10)
	look_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86, 1))
	look_row.add_child(look_label)
	controls.add_child(look_row)

	var interact_row := HBoxContainer.new()
	interact_row.add_theme_constant_override("separation", 5)
	interact_row.add_child(_make_key_chip("E"))
	var interact_label := Label.new()
	interact_label.text = "  INTERACT / CLEAN"
	interact_label.add_theme_font_size_override("font_size", 10)
	interact_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86, 1))
	interact_row.add_child(interact_label)
	controls.add_child(interact_row)

	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 5)
	utility_row.add_child(_make_key_chip("SHIFT"))
	var util_label := Label.new()
	util_label.text = "  SPRINT     "
	util_label.add_theme_font_size_override("font_size", 10)
	util_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86, 1))
	utility_row.add_child(util_label)
	utility_row.add_child(_make_key_chip("1-3"))
	var tools_label := Label.new()
	tools_label.text = "  TOOLS"
	tools_label.add_theme_font_size_override("font_size", 10)
	tools_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86, 1))
	utility_row.add_child(tools_label)
	controls.add_child(utility_row)

	pause_resume_button = Button.new()
	pause_resume_button.text = "RESUME"
	pause_resume_button.custom_minimum_size = Vector2(0, 44)
	pause_resume_button.add_theme_font_size_override("font_size", 13)
	pause_resume_button.add_theme_color_override("font_color", Color(0.035, 0.05, 0.08, 1))
	pause_resume_button.add_theme_stylebox_override("normal", _make_button_style(Color(1.0, 0.80, 0.22, 1), Color(1.0, 0.90, 0.50, 1), 3))
	pause_resume_button.add_theme_stylebox_override("hover", _make_button_style(Color(1.0, 0.86, 0.35, 1), Color(1, 1, 1, 0.7), 3))
	pause_resume_button.pressed.connect(func() -> void: _set_paused(false))
	column.add_child(pause_resume_button)

	var restart := Button.new()
	restart.text = "RESTART SHIFT"
	restart.custom_minimum_size = Vector2(0, 34)
	restart.add_theme_font_size_override("font_size", 10)
	restart.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94, 1))
	restart.add_theme_stylebox_override("normal", _make_button_style(Color(0.04, 0.07, 0.13, 1), Color(0.18, 0.28, 0.43, 1), 3))
	restart.add_theme_stylebox_override("hover", _make_button_style(Color(0.07, 0.11, 0.19, 1), Color(0.28, 0.55, 0.78, 0.9), 3))
	restart.pressed.connect(_restart_shift)
	column.add_child(restart)

	var quit := Button.new()
	quit.text = "QUIT TO MENU"
	quit.custom_minimum_size = Vector2(0, 34)
	quit.add_theme_font_size_override("font_size", 10)
	quit.add_theme_color_override("font_color", Color(0.60, 0.68, 0.80, 1))
	quit.add_theme_stylebox_override("normal", _make_button_style(Color(0.03, 0.055, 0.10, 1), Color(0.14, 0.22, 0.34, 1), 3))
	quit.add_theme_stylebox_override("hover", _make_button_style(Color(0.07, 0.10, 0.16, 1), Color(0.35, 0.45, 0.58, 0.9), 3))
	quit.pressed.connect(_quit_to_menu)
	column.add_child(quit)

func _restart_shift() -> void:
	_set_paused(false)
	get_tree().reload_current_scene()

func _quit_to_menu() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
