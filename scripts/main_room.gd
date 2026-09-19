extends Node3D

@onready var hud: CanvasLayer = $HUD
@onready var interaction_ray: RayCast3D = $Player/Head/Camera3D/InteractionRay
@onready var sofa: StaticBody3D = $Sofa


func _ready() -> void:
	interaction_ray.target_changed.connect(hud.set_interaction_prompt)
	sofa.placed.connect(hud.mark_sofa_complete)