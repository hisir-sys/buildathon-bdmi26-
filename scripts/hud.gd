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
var note_panel: PanelContainer
var note_title: Label
var note_body: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_interaction_prompt("")
	sound_button.pressed.connect(_toggle_sound)
	pause_button.pressed.connect(_toggle_pause)
	_build_key_badge()
	_build_note()


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	if prompt_text.begins_with("E  "):
		interaction_key_badge.visible = true
		interaction_label.text = prompt_text.substr(3)
	else:
		interaction_key_badge.visible = false
		interaction_label.text = prompt_text


func set_task_counts(
	dust_cleaned: int,
	webs_cleared: int,
	furniture_placed: int,
	bathroom_mirrors_cleaned: int = 0,
	panel_repaired: int = 0,
	fridge_done: int = 0
) -> void:
	var rows := [
		_task_row("DUSTING", dust_cleaned, 6, COLOR_CLEAN),
		_task_row("REWIRE PANEL", panel_repaired, 1, COLOR_MECH),
		_task_row("FRIDGE", fridge_done, 1, COLOR_MECH),
		_task_row("FURNITURE", furniture_placed, FURNITURE_TOTAL, COLOR_CLEAN),
		_task_row("WASHROOM", bathroom_mirrors_cleaned, 3, COLOR_WASH),
	]
	task_label.text = "\n".join(rows)

	var done := int(dust_cleaned >= 6) + panel_repaired + fridge_done + int(furniture_placed >= FURNITURE_TOTAL) + int(bathroom_mirrors_cleaned >= 3)
	task_fraction_label.text = "%d/5" % done


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


func show_note(title_text: String, body_text: String) -> void:
	note_title.text = title_text
	note_body.text = body_text
	note_panel.visible = true


func hide_note() -> void:
	note_panel.visible = false


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


func _build_note() -> void:
	# Paper note shown at the top-centre while the player is near the chest
	# and hasn't found the key yet.
	note_panel = PanelContainer.new()
	note_panel.name = "ChestNote"
	note_panel.anchor_left = 0.5
	note_panel.anchor_right = 0.5
	note_panel.offset_left = -230.0
	note_panel.offset_right = 230.0
	note_panel.offset_top = 110.0
	note_panel.offset_bottom = 110.0
	note_panel.grow_vertical = Control.GROW_DIRECTION_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.87, 0.7, 0.97)
	style.border_color = Color(0.45, 0.3, 0.12, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	note_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	note_panel.add_child(column)

	note_title = Label.new()
	note_title.add_theme_font_size_override("font_size", 12)
	note_title.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1, 1))
	column.add_child(note_title)

	note_body = Label.new()
	note_body.custom_minimum_size = Vector2(420, 0)
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_body.add_theme_font_size_override("font_size", 17)
	note_body.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06, 1))
	column.add_child(note_body)

	note_panel.visible = false
	add_child(note_panel)
