extends StaticBody3D
# Task 1: Lock-Pick Desk Drawer. Interact to open the timing-bar minigame
# (scripts/tasks/lock_pick_minigame.gd). Hit the target -> drawer opens and
# grants an item, +5 suspicion. Miss -> 2s lockout + metallic clang, +25
# suspicion. Follows the same get_interaction_prompt()/interact() interface
# as every other interactable in this project (see dust_spot.gd).

signal unlocked(item_name: String)

const LockPickMinigame = preload("res://scripts/tasks/lock_pick_minigame.gd")

@export var granted_item_name: String = "Pendrive"
@export var hit_suspicion: float = 5.0
@export var miss_suspicion: float = 25.0

var _drawer_panel: Node3D
var _item_mesh: MeshInstance3D
var _is_locked: bool = true
var _is_busy: bool = false


func _ready() -> void:
	add_to_group("interactable")
	_build_visuals()


func get_interaction_prompt() -> String:
	if not _is_locked:
		return ""
	if _is_busy:
		return ""
	return "E  PICK THE LOCK"


func interact() -> void:
	if not _is_locked or _is_busy:
		return
	_is_busy = true

	var minigame := LockPickMinigame.new()
	get_tree().current_scene.add_child(minigame)
	minigame.resolved.connect(_on_minigame_resolved)
	minigame.cancelled.connect(_on_minigame_cancelled)
	minigame.start()


func _on_minigame_cancelled() -> void:
	_is_busy = false


func _on_minigame_resolved(hit: bool) -> void:
	_is_busy = false
	var suspicion_manager := get_node_or_null("/root/SuspicionManager")

	if hit:
		_is_locked = false
		_open_drawer()
		if suspicion_manager != null:
			suspicion_manager.call("add_suspicion", hit_suspicion)
		unlocked.emit(granted_item_name)
	else:
		_play_clang()
		if suspicion_manager != null:
			suspicion_manager.call("add_suspicion", miss_suspicion)


func _open_drawer() -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null and animation_player.has_animation("open"):
		animation_player.play("open")
	else:
		var tween := create_tween()
		tween.tween_property(_drawer_panel, "position:z", 0.32, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _item_mesh != null:
		var reveal := create_tween()
		reveal.tween_interval(0.4)
		reveal.tween_property(_item_mesh, "position:y", 0.05, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_clang() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.2
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -6.0
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	var frames := playback.get_frames_available()
	var increment := 1.0 / 22050.0
	var t := 0.0
	for i in range(frames):
		var envelope := exp(-t * 22.0)
		var tone := sin(TAU * 1400.0 * t) * 0.5 + sin(TAU * 2600.0 * t) * 0.3 + sin(TAU * 780.0 * t) * 0.2
		playback.push_frame(Vector2.ONE * tone * envelope)
		t += increment
	player.finished.connect(player.queue_free)


func _build_visuals() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.16, 0.07, 1)
	wood.roughness = 0.7
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.48, 0.16, 1)
	brass.metallic = 0.8
	brass.roughness = 0.35

	var frame := MeshInstance3D.new()
	frame.name = "DrawerFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.6, 0.2, 0.05)
	frame.mesh = frame_mesh
	frame.material_override = wood
	frame.position = Vector3(0, 0, 0.02)
	add_child(frame)

	_drawer_panel = Node3D.new()
	_drawer_panel.name = "DrawerPanel"
	add_child(_drawer_panel)

	var panel_mesh := MeshInstance3D.new()
	panel_mesh.name = "PanelFront"
	var box := BoxMesh.new()
	box.size = Vector3(0.56, 0.18, 0.42)
	panel_mesh.mesh = box
	panel_mesh.material_override = wood
	panel_mesh.position = Vector3(0, 0, -0.19)
	_drawer_panel.add_child(panel_mesh)

	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.015
	handle_mesh.bottom_radius = 0.015
	handle_mesh.height = 0.14
	handle.mesh = handle_mesh
	handle.material_override = brass
	handle.position = Vector3(0, 0, 0.02)
	handle.rotation_degrees.x = 90.0
	_drawer_panel.add_child(handle)

	var keyhole := MeshInstance3D.new()
	keyhole.name = "Keyhole"
	var keyhole_mesh := CylinderMesh.new()
	keyhole_mesh.top_radius = 0.012
	keyhole_mesh.bottom_radius = 0.012
	keyhole_mesh.height = 0.01
	keyhole.mesh = keyhole_mesh
	keyhole.material_override = brass
	keyhole.position = Vector3(0.22, -0.04, 0.03)
	keyhole.rotation_degrees.x = 90.0
	_drawer_panel.add_child(keyhole)

	_item_mesh = MeshInstance3D.new()
	_item_mesh.name = "GrantedItem"
	var item_shape := BoxMesh.new()
	item_shape.size = Vector3(0.18, 0.02, 0.05)
	_item_mesh.mesh = item_shape
	_item_mesh.material_override = brass
	_item_mesh.position = Vector3(0, -0.06, -0.19)
	_drawer_panel.add_child(_item_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.2, 0.45)
	collision.shape = shape
	add_child(collision)
