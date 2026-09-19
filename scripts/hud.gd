extends CanvasLayer

@onready var interaction_panel: Control = $InteractionPrompt
@onready var interaction_label: Label = $InteractionPrompt/Label
@onready var task_label: Label = $TaskBoard/TaskLabel


func _ready() -> void:
	set_interaction_prompt("")


func set_interaction_prompt(prompt_text: String) -> void:
	interaction_panel.visible = not prompt_text.is_empty()
	interaction_label.text = prompt_text


func mark_test_complete() -> void:
	task_label.text = "TEST TASK                 1/1"
	set_interaction_prompt("TASK COMPLETE")