extends StaticBody3D

signal cleaned

const CLEAN_TIME_SECONDS := 8.0

var is_cleaned: bool = false
var is_cleaning: bool = false
var cleaning_elapsed: float = 0.0
var dirt_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and (child.name == "DirtLayer" or child.name.begins_with("DirtStreak")):
			dirt_parts.append(child)


func _process(delta: float) -> void:
	if not is_cleaning:
		return

	cleaning_elapsed = minf(CLEAN_TIME_SECONDS, cleaning_elapsed + delta)
	var progress := cleaning_elapsed / CLEAN_TIME_SECONDS
	for dirt_part in dirt_parts:
		dirt_part.transparency = progress

	if cleaning_elapsed >= CLEAN_TIME_SECONDS:
		is_cleaned = true
		for dirt_part in dirt_parts:
			dirt_part.visible = false
			dirt_part.transparency = 0.0
		collision_layer = 0
		collision_mask = 0
		cleaned.emit()


func get_interaction_prompt() -> String:
	if is_cleaned:
		return "BATHROOM MIRROR CLEAN"
	if is_cleaning:
		return "CLEANING BATHROOM MIRROR  %02d%%" % int((cleaning_elapsed / CLEAN_TIME_SECONDS) * 100.0)
	return "E  CLEAN DIRTY BATHROOM MIRROR  (8 SEC)" if _has_required_tool() else "REQUIRES BATHROOM SCRUBBER"


func interact() -> void:
	if is_cleaned or is_cleaning or not _has_required_tool():
		return
	is_cleaning = true

func _has_required_tool() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and int(player.get("current_tool")) == 2
