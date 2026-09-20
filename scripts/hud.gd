extends CanvasLayer

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: Label = $TaskBoard/TaskLabel

var furniture_done: int = 0
var furniture_total: int = 1
var dusting_done: int = 0
var dusting_total: int = 6
var webs_done: int = 0
var webs_total: int = 4


func _ready() -> void:
	set_interaction_prompt("")
	_refresh_task_board()


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	interaction_label.text = prompt_text


func mark_sofa_complete() -> void:
	furniture_done = furniture_total
	_refresh_task_board()
	set_interaction_prompt("TASK COMPLETE")


func update_dusting(done: int, total: int) -> void:
	dusting_done = done
	dusting_total = total
	_refresh_task_board()


func update_webs(done: int, total: int) -> void:
	webs_done = done
	webs_total = total
	_refresh_task_board()


func _refresh_task_board() -> void:
	task_label.text = "FURNITURE                  %d/%d\n\nDUSTING                    %d/%d\nSPIDER WEBS                %d/%d" % [
		furniture_done, furniture_total,
		dusting_done, dusting_total,
		webs_done, webs_total
	]
