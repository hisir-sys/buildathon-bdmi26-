extends RayCast3D

signal target_changed(prompt_text: String)
signal interacted(target: Node)

var current_target: Node = null
var last_prompt: String = ""
var held_target: Node = null


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
	elif hit == null or (hit is Node and ((hit as Node).is_in_group("floor") or (hit as Node).name == "Floor")):
		next_target = _find_floor_cleaning_target()

	var next_prompt := ""
	if next_target != null:
		next_prompt = next_target.get_interaction_prompt()

	if next_target != current_target and held_target != null:
		if held_target.has_method("stop_interaction"):
			held_target.stop_interaction()
		held_target = null

	if next_target == current_target and next_prompt == last_prompt:
		return

	current_target = next_target
	last_prompt = next_prompt
	target_changed.emit(next_prompt)


func _find_floor_cleaning_target() -> Node:
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return null
	forward = forward.normalized()

	var nearest_target: Node = null
	var nearest_distance := 3.2
	for candidate in get_tree().get_nodes_in_group("floor_cleaning_task"):
		var floor_task := candidate as Node3D
		if floor_task == null or not floor_task.is_visible_in_tree():
			continue
		var offset := floor_task.global_position - global_position
		var horizontal_offset := Vector3(offset.x, 0.0, offset.z)
		var distance := horizontal_offset.length()
		if distance < 0.15 or distance > nearest_distance:
			continue
		if forward.dot(horizontal_offset / distance) < 0.68:
			continue
		nearest_target = floor_task
		nearest_distance = distance
	return nearest_target


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if current_target != null and current_target.has_method("interact"):
			current_target.interact()
			if current_target.has_method("stop_interaction"):
				held_target = current_target
			interacted.emit(current_target)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_released("interact"):
		if held_target != null and held_target.has_method("stop_interaction"):
			held_target.stop_interaction()
		held_target = null
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_door"):
		if current_target != null and current_target.has_method("toggle_open"):
			current_target.toggle_open()


func cancel_current_interaction() -> void:
	if held_target != null and held_target.has_method("stop_interaction"):
		held_target.stop_interaction()
	held_target = null
