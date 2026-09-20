extends CanvasLayer

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: Label = $TaskBoard/TaskLabel
@onready var timer_label: Label = $TimerPanel/TimerLabel
@onready var score_label: Label = $ScorePanel/ScoreLabel

var furniture_done: int = 0
var furniture_total: int = 4
var dusting_done: int = 0
var dusting_total: int = 0
var webs_done: int = 0
var webs_total: int = 0
var bathroom_done: int = 0
var bathroom_total: int = 2
var panel_done: int = 0
var pipeline_done: int = 0
var fridge_done: int = 0


func _ready() -> void:
	set_interaction_prompt("")


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	interaction_label.text = prompt_text


func mark_sofa_complete() -> void:
	furniture_done = furniture_total
	_refresh_task_board()


func set_timer(time_left: float) -> void:
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]


func set_score(score: int) -> void:
	score_label.text = str(score)


func set_task_counts(dust: int, webs: int, furniture: int, bathroom: int, panel: int, pipeline: int, fridge: int) -> void:
	dusting_done = dust
	webs_done = webs
	furniture_done = furniture
	bathroom_done = bathroom
	panel_done = panel
	pipeline_done = pipeline
	fridge_done = fridge
	_refresh_task_board()


func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_button.text = "Ⅱ" if is_paused else "▶"
