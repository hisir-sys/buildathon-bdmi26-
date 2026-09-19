extends RayCast3D

signal target_changed(prompt_text: String)
signal interacted(target: Node)

var current_target: Node = null


func _ready() -> void:
	enabled = true
	target_position = Vector3(0.0, 0.0, -3.0)


func _process(_delta: float) -> void:
	force_raycast_update()

	var hit := get_collider()
	var next_target: Node = null

	var carried_target := get_tree().get_first_node_in_group("carried_interactable")

	if carried_target != null:
		next_target = carried_target
	elif hit != null and hit.has_method("get_interaction_prompt"):
		next_target = hit

	if next_target == current_target:
		return

	current_target = next_target

	if current_target == null:
		target_changed.emit("")
	else:
		target_changed.emit(current_target.get_interaction_prompt())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if current_target != null and current_target.has_method("interact"):
		current_target.interact()
		interacted.emit(current_target)