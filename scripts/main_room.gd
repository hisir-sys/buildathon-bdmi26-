extends Node3D

@onready var hud: CanvasLayer = $HUD
@onready var interaction_ray: RayCast3D = $Player/Head/Camera3D/InteractionRay
@onready var sofa: StaticBody3D = $Sofa
@onready var game_manager: Node = $GameManager

var dust_cleaned: int = 0
var webs_cleared: int = 0
var furniture_placed: int = 0


func _ready() -> void:
	interaction_ray.target_changed.connect(hud.set_interaction_prompt)
	sofa.placed.connect(hud.mark_sofa_complete)
	sofa.placed.connect(_on_sofa_placed)

	game_manager.time_changed.connect(hud.set_timer)
	game_manager.time_expired.connect(_on_time_expired)

	for dust_spot in get_tree().get_nodes_in_group("dust_spot"):
		dust_spot.cleaned.connect(_on_dust_cleaned)

	for spider_web in get_tree().get_nodes_in_group("spider_web"):
		spider_web.cleared.connect(_on_web_cleared)

	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed)


func _on_dust_cleaned() -> void:
	dust_cleaned += 1
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed)


func _on_web_cleared() -> void:
	webs_cleared += 1
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed)


func _on_sofa_placed() -> void:
	furniture_placed = 1
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed)


func _on_time_expired() -> void:
	hud.set_time_expired()
	hud.set_interaction_prompt("TIME IS UP")