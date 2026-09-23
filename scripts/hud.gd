extends CanvasLayer

const COLOR_CLEAN := "#ff5c4d"
const COLOR_MECH := "#4da8ff"
const COLOR_WASH := "#5cf0a0"
const COLOR_DONE := "#5c6b82"
const COLOR_TEXT := "#e4edf7"

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_key_badge: Control = $InteractionPrompt/KeyBadge
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: RichTextLabel = $TaskBoard/TaskLabel
@onready var task_fraction_label: Label = $TaskBoard/Fraction
@onready var score_label: Label = $ScorePanel/ScoreLabel
@onready var sound_button: Button = $SoundButton
@onready var pause_button: Button = $PauseButton

var sound_enabled: bool = true
var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_interaction_prompt("")
	sound_button.pressed.connect(_toggle_sound)
	pause_button.pressed.connect(_toggle_pause)


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
	fridge_cleaned: int = 0
) -> void:
	var rows := [
		_task_row("DUSTING", dust_cleaned, 6, COLOR_CLEAN),
		_task_row("REWIRE PANEL", panel_repaired, 1, COLOR_MECH),
		_task_row("FRIDGE", fridge_cleaned, 1, COLOR_MECH),
		_task_row("FURNITURE", furniture_placed, 4, COLOR_CLEAN),
		_task_row("WASHROOM", bathroom_mirrors_cleaned, 3, COLOR_WASH),
	]
	task_label.text = "\n".join(rows)

	var done := int(dust_cleaned >= 6) + panel_repaired + fridge_cleaned + int(furniture_placed >= 4) + int(bathroom_mirrors_cleaned >= 3)
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


func set_score(score: int) -> void:
	score_label.text = str(score)


func mark_furniture_complete(furniture_count: int) -> void:
	if furniture_count >= 4:
		set_interaction_prompt("FURNITURE TASK COMPLETE")
	else:
		set_interaction_prompt("FURNITURE %d/4 PLACED" % furniture_count)


func set_timer(seconds_left: int) -> void:
	var minutes := seconds_left / 60
	var seconds := seconds_left % 60
	$TimerPanel/TimerLabel.text = "%02d:%02d" % [minutes, seconds]


func set_time_expired() -> void:
	$TimerPanel/TimerLabel.text = "00:00"


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	AudioServer.set_bus_mute(0, not sound_enabled)
	sound_button.text = "🔊" if sound_enabled else "🔇"


func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_button.text = "Ⅱ" if is_paused else "▶"