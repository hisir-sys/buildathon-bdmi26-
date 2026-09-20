extends Node3D
class_name FurnitureTask

signal furniture_task_completed

@onready var pieces: Array = $PiledFurniture.get_children()

var placed_count: int = 0
var total_count: int = 0


func _ready() -> void:
	add_to_group("furniture_task")
	total_count = pieces.size()
	_update_hud()


func piece_placed() -> void:
	placed_count += 1
	_update_hud()
	if placed_count >= total_count:
		emit_signal("furniture_task_completed")


func _update_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_furniture(placed_count, total_count)
