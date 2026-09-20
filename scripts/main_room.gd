extends Node3D

@onready var hud: CanvasLayer = $HUD
@onready var interaction_ray: RayCast3D = $Player/Head/Camera3D/InteractionRay
@onready var sofa: StaticBody3D = $Sofa
@onready var game_manager: Node = $GameManager

var dust_cleaned: int = 0
var webs_cleared: int = 0
var furniture_placed: int = 0
var ambience_time: float = 0.0
var ceiling_lights: Array[OmniLight3D] = []
var light_bulbs: Array[MeshInstance3D] = []
var light_base_energy: Array[float] = [1.8, 1.65, 1.3]


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

	ceiling_lights = [$CeilingLightLeft, $CeilingLightRight, $CeilingLightBack]
	light_bulbs = [$BlueBulb, $AmberBulb, $GreenBulb]
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed)


func _process(delta: float) -> void:
	ambience_time += delta
	for index in range(ceiling_lights.size()):
		var pulse := 0.62 + 0.38 * (0.5 + 0.5 * sin(ambience_time * (1.15 + index * 0.16) + index * 2.0))
		var glitch_wave := sin(ambience_time * (3.3 + index * 0.45) + index * 1.7)
		var glitch := 0.38 if glitch_wave > 0.94 else 1.0
		var energy := light_base_energy[index] * pulse * glitch
		ceiling_lights[index].light_energy = energy

		var bulb_material := light_bulbs[index].material_override as StandardMaterial3D
		if bulb_material != null:
			bulb_material.emission_energy_multiplier = 2.5 * pulse * glitch
		light_bulbs[index].visible = energy > light_base_energy[index] * 0.3


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