extends CanvasLayer

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: Label = $TaskBoard/TaskLabel
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
	interaction_label.text = prompt_text


func set_task_counts(
	dust_cleaned: int,
	webs_cleared: int,
	furniture_placed: int,
	bathroom_mirrors_cleaned: int = 0,
	panel_repaired: int = 0,
	pipeline_cleaned: int = 0,
	fridge_cleaned: int = 0
) -> void:
	task_label.text = (
		"DUSTING                    %d/6\n"
		+ "REWIRE PANEL              %d/1\n"
		+ "PIPELINE                   %d/1\n"
		+ "FRIDGE                     %d/1\n"
		+ "FURNITURE                 %d/1\n"
	+ "WASHROOM                  %d/2"
) % [dust_cleaned, panel_repaired, pipeline_cleaned, fridge_cleaned, furniture_placed, bathroom_mirrors_cleaned]


func set_score(score: int) -> void:
	score_label.text = str(score)


func mark_sofa_complete() -> void:
	set_interaction_prompt("FURNITURE TASK COMPLETE")


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
