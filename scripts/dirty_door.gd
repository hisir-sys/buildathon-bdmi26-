extends StaticBody3D

signal cleaned

const CLEAN_TIME_SECONDS := 6.0
const CLOSED_ANGLE_DEGREES := -6.0
const OPEN_ANGLE_DEGREES := -100.0
const SWING_SPEED_DEGREES := 140.0

var is_cleaned: bool = false
var is_cleaning: bool = false
var is_open: bool = false
var cleaning_elapsed: float = 0.0
var dirt_parts: Array[MeshInstance3D] = []
var hinge: Node3D


func _ready() -> void:
	hinge = get_parent() as Node3D
	for child in get_children():
		if child is MeshInstance3D and (child.name == "DirtLayer" or child.name.begins_with("DirtSmudge")):
			dirt_parts.append(child)


func _process(delta: float) -> void:
	if hinge != null:
		var target_angle := OPEN_ANGLE_DEGREES if is_open else CLOSED_ANGLE_DEGREES
		hinge.rotation_degrees.y = move_toward(hinge.rotation_degrees.y, target_angle, delta * SWING_SPEED_DEGREES)

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
	var door_hint := "  |  SPACE " + ("CLOSE" if is_open else "OPEN")
	if is_cleaned:
		return "DOOR CLEAN" + door_hint
	if is_cleaning:
		return "CLEANING DOOR  %02d%%" % int((cleaning_elapsed / CLEAN_TIME_SECONDS) * 100.0)
	return "E  WIPE DUST (6s)" + door_hint


func interact() -> void:
	if is_cleaned or is_cleaning:
		return
	is_cleaning = true


func stop_interaction() -> void:
	if is_cleaned:
		return
	is_cleaning = false


func toggle_open() -> void:
	is_open = not is_open
