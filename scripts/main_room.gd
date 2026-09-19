extends Node3D

@onready var hud: CanvasLayer = $HUD
@onready var interaction_ray: RayCast3D = $Player/Head/Camera3D/InteractionRay
@onready var test_object: Node = $TestObject


func _ready() -> void:
	interaction_ray.target_changed.connect(hud.set_interaction_prompt)
	interaction_ray.interacted.connect(_on_object_interacted)


func _on_object_interacted(target: Node) -> void:
	if target == test_object:
		hud.mark_test_complete()