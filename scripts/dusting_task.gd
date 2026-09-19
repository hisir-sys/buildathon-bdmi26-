extends Node3D
class_name DustingTask

signal dusting_task_completed

@onready var dust_spots: Array = $DustSpots.get_children()
@onready var spider_webs: Array = $SpiderWebs.get_children()

var cleaned_count: int = 0
var total_count: int = 0

func _ready() -> void:
	add_to_group("dusting_task")
	total_count = dust_spots.size() + spider_webs.size()

func clean_spot(dirty_spot: Area3D) -> void:
	if dirty_spot.visible:
		dirty_spot.visible = false
		dirty_spot.get_node("CollisionShape3D").disabled = true
		cleaned_count += 1
		_check_completion()

func _check_completion() -> void:
	if cleaned_count >= total_count:
		print("Dusting task completed!")
		emit_signal("dusting_task_completed")
