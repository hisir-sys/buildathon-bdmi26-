extends CanvasLayer

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: Label = $TaskBoard/TaskLabel


func _ready() -> void:
	set_interaction_prompt("")


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	interaction_label.text = prompt_text


func set_task_counts(dust_cleaned: int, webs_cleared: int, furniture_placed: int) -> void:
	task_label.text = (
		"FURNITURE                  %d/1\n\n"
		+ "DUSTING                    %d/6\n"
		+ "SPIDER WEBS                %d/4"
	) % [furniture_placed, dust_cleaned, webs_cleared]


func mark_sofa_complete() -> void:
	set_interaction_prompt("FURNITURE TASK COMPLETE")


func set_timer(seconds_left: int) -> void:
	var minutes := seconds_left / 60
	var seconds := seconds_left % 60
	$TimerPanel/TimerLabel.text = "OWNER ARRIVES  %02d:%02d" % [minutes, seconds]


func set_time_expired() -> void:
	$TimerPanel/TimerLabel.text = "OWNER ARRIVES  00:00"