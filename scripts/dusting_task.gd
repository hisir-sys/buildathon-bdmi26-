extends Node3D
class_name DustingTask

signal dusting_task_completed

@onready var dust_spots: Array = $DustSpots.get_children()
@onready var spider_webs: Array = $SpiderWebs.get_children()

var dust_cleaned: int = 0
var webs_cleaned: int = 0
var total_count: int = 0
var cleaned_count: int = 0


func _ready() -> void:
	add_to_group("dusting_task")
	total_count = dust_spots.size() + spider_webs.size()
	_update_hud()


func clean_spot(dirty_spot: Area3D) -> void:
	print("clean_spot called on: ", dirty_spot.name)
	if not dirty_spot.visible:
		return

	dirty_spot.visible = false
	dirty_spot.get_node("CollisionShape3D").disabled = true
	cleaned_count += 1

	if dirty_spot in dust_spots:
		dust_cleaned += 1
	elif dirty_spot in spider_webs:
		webs_cleaned += 1

	_update_hud()
	_check_completion()


func _update_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	print("hud found: ", hud)
	if hud:
		hud.update_dusting(dust_cleaned, dust_spots.size())
		hud.update_webs(webs_cleaned, spider_webs.size())


func _check_completion() -> void:
	if cleaned_count >= total_count:
		emit_signal("dusting_task_completed")
