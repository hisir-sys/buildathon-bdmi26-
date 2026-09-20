extends StaticBody3D

signal cleaned

const CLEAN_TIME_SECONDS := 6.0

var is_cleaned: bool = false
var is_cleaning: bool = false
var cleaning_elapsed: float = 0.0
var dirt_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and (child.name == "DirtLayer" or child.name.begins_with("DirtSmudge")):
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
		cleaned.emit()


func get_interaction_prompt() -> String:
	if is_cleaned:
		return "DOOR CLEAN"
	if is_cleaning:
		return "CLEANING DUSTY DOOR  %02d%%" % int((cleaning_elapsed / CLEAN_TIME_SECONDS) * 100.0)
	return "E  WIPE DUST OFF DOOR  (6 SEC)"


func interact() -> void:
	if is_cleaned or is_cleaning:
		return
	is_cleaning = true
