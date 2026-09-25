extends StaticBody3D
# The desk + chest are mounted against the front wall. Not movable. The player needs the key
# (found in the bathroom) and has to shift the cabinet away first. Unlocking
# freezes the game, cuts to a fixed camera, dims the room and asks the player
# to STEAL or LEAVE the diamond. The result is stored on the GameManager
# (diamond_taken / diamond_resolved); the endings will read it later.

signal choice_started
signal choice_finished(diamond_taken: bool)

const ChoiceOverlayScript = preload("res://scripts/choice_overlay.gd")

const CABINET_CLEARANCE := 3.2

# Camera positions relative to the chest origin (chest sits on the desk).
# The root is rotated 180 degrees so the chest front faces into the room.
const CAM_START := Vector3(0.8, 2.7, 3.6)
const CAM_END := Vector3(0.3, 2.45, 2.2)
const CAM_TARGET := Vector3(0.0, 1.2, 0.0)
const PADLOCK_DROP_POS := Vector3(0.75, 0.95, 0.3)

var player: Node3D
var hud: CanvasLayer
var game_manager: Node

var is_busy: bool = false
var is_sealed: bool = false
var is_unlocked: bool = false

var lid_pivot: Node3D
var padlock: Node3D
var diamond: Node3D
var diamond_light: OmniLight3D
var cinematic_camera: Camera3D
var overlay: CanvasLayer

# Grouped so the start/ending backdrops can hide or rearrange the chest.
var chest_group: Node3D
var scroll_node: Node3D
var lamp_pool: SpotLight3D
var lamp_glow: OmniLight3D
var lamp_bulb_material: StandardMaterial3D
var lamp_shade_material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("interactable")
	_build_desk()
	chest_group = Node3D.new()
	chest_group.name = "ChestGroup"
	add_child(chest_group)
	_build_chest_body()
	_build_lid()
	_build_padlock()
	_build_contents()
	_build_lamp()
	_build_collision()
	_build_camera()


func setup(player_node: Node3D, hud_node: CanvasLayer, manager: Node) -> void:
	player = player_node
	hud = hud_node
	game_manager = manager


func _process(delta: float) -> void:
	if diamond != null and diamond.visible:
		diamond.rotate_y(delta * 0.9)

	if is_busy:
		if cinematic_camera != null and cinematic_camera.current:
			cinematic_camera.look_at(to_global(CAM_TARGET), Vector3.UP)
		return


# --- Interaction -----------------------------------------------------------

func get_interaction_prompt() -> String:
	if is_sealed or is_busy:
		return ""
	if _cabinet_in_the_way():
		return "SOMETHING IS BEHIND THE CABINET"
	if not _has_key():
		return "THE CHEST IS LOCKED - FIND THE KEY"
	return "E  UNLOCK THE CHEST"


func interact() -> void:
	if is_sealed or is_busy or _cabinet_in_the_way() or not _has_key():
		return
	_run_sequence()


func _has_key() -> bool:
	return game_manager != null and bool(game_manager.get("has_key"))


func _cabinet_in_the_way() -> bool:
	var cabinet := get_tree().current_scene.get_node_or_null("Cabinet") as Node3D
	return cabinet != null and cabinet.global_position.distance_to(global_position) < CABINET_CLEARANCE


# --- Sequence --------------------------------------------------------------

func _run_sequence() -> void:
	is_busy = true
	is_unlocked = true
	hud.call("set_interaction_prompt", "")
	game_manager.call("set_has_key", false)

	var suspicion_manager := get_node_or_null("/root/SuspicionManager")
	if suspicion_manager != null:
		suspicion_manager.call("add_suspicion", 15.0)

	# Freeze the game: timer, movement and the world all stop. This node and
	# the overlay keep running (PROCESS_MODE_ALWAYS).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	player.visible = false

	cinematic_camera.global_position = to_global(CAM_START)
	cinematic_camera.look_at(to_global(CAM_TARGET), Vector3.UP)
	cinematic_camera.make_current()
	var dolly := _make_tween()
	dolly.tween_property(cinematic_camera, "global_position", to_global(CAM_END), 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await _wait(0.7)
	await _unlock_and_open()
	await _wait(0.6)

	choice_started.emit()
	overlay = CanvasLayer.new()
	overlay.set_script(ChoiceOverlayScript)
	get_tree().current_scene.add_child(overlay)
	overlay.connect("chosen", _on_choice)
	overlay.call("show_choice")


func _unlock_and_open() -> void:
	var lock_tween := _make_tween()
	lock_tween.tween_property(padlock, "rotation_degrees:z", 20.0, 0.2)
	lock_tween.tween_property(padlock, "position", PADLOCK_DROP_POS, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	lock_tween.parallel().tween_property(padlock, "rotation_degrees", Vector3(-90.0, 35.0, 20.0), 0.45)
	await lock_tween.finished

	var lid_tween := _make_tween()
	lid_tween.tween_property(lid_pivot, "rotation_degrees:x", -115.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await lid_tween.finished

	var glow := _make_tween()
	glow.tween_property(diamond_light, "light_energy", 1.8, 0.8)


func _on_choice(steal: bool) -> void:
	# Called at the peak of the white flash, so all of this happens unseen.
	lid_pivot.rotation_degrees.x = 0.0
	diamond_light.light_energy = 0.0
	if steal:
		diamond.visible = false
	is_sealed = true
	is_busy = false

	game_manager.call("resolve_diamond", steal)

	player.visible = true
	player.get_node("Head/Camera3D").call("make_current")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	choice_finished.emit(steal)


func _make_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# --- Display helpers (used by the start / ending backdrops) ----------------

func set_lamp(power: float, spot_angle: float = 38.0) -> void:
	# power: 0 = lamp off, 1 = normal glow, higher = brighter.
	lamp_pool.light_energy = 9.0 * power
	lamp_pool.spot_angle = spot_angle
	lamp_glow.light_energy = 0.5 * power
	lamp_bulb_material.emission_energy_multiplier = 3.0 * power
	lamp_shade_material.emission_energy_multiplier = 1.2 * power
	lamp_bulb_material.albedo_color = Color(1.0, 0.9, 0.6, 1) if power > 0.0 else Color(0.22, 0.2, 0.17, 1)


func set_chest_visible(value: bool) -> void:
	chest_group.visible = value


func show_treasure_on_desk() -> void:
	# Chest gone; the diamond and contract rest on the bare desk.
	diamond.reparent(self, false)
	diamond.position = Vector3(0.0, 1.08, 0.15)
	scroll_node.reparent(self, false)
	scroll_node.position = Vector3(0.5, 0.95, 0.2)
	diamond_light.light_energy = 1.6
	chest_group.visible = false


# --- Construction ----------------------------------------------------------
# Local origin is on the floor at the centre of the desk. Desk top is y=0.9;
# the chest front faces +z (into the room).

func _mat(color: Color, emission: Color = Color(0, 0, 0, 1), energy: float = 0.0, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _cyl(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, pos: Vector3, material: Material, segments: int = 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _build_desk() -> void:
	var walnut := _mat(Color(0.2, 0.1, 0.05, 1), Color(0, 0, 0, 1), 0.0, 0.0, 0.7)
	var trim := _mat(Color(0.32, 0.17, 0.08, 1))
	_box(self, "DeskTop", Vector3(2.3, 0.1, 1.0), Vector3(0, 0.85, 0), walnut)
	_box(self, "DeskEdge", Vector3(2.36, 0.04, 1.06), Vector3(0, 0.8, 0), trim)
	for index in range(4):
		_box(self, "DeskLeg%d" % index, Vector3(0.12, 0.8, 0.12), Vector3(-1.05 if index % 2 == 0 else 1.05, 0.4, -0.4 if index < 2 else 0.4), walnut)
	_box(self, "DeskDrawer", Vector3(0.9, 0.22, 0.03), Vector3(0, 0.66, 0.51), trim)
	_cyl(self, "DrawerKnob", 0.03, 0.03, 0.05, Vector3(0, 0.66, 0.55), _mat(Color(0.7, 0.55, 0.2, 1), Color(0, 0, 0, 1), 0.0, 0.8, 0.4), 12).rotation_degrees.x = 90.0


func _build_chest_body() -> void:
	var wood := _mat(Color(0.34, 0.17, 0.07, 1), Color(0, 0, 0, 1), 0.0, 0.0, 0.65)
	var iron := _mat(Color(0.1, 0.1, 0.12, 1), Color(0, 0, 0, 1), 0.0, 0.8, 0.5)
	var velvet := _mat(Color(0.32, 0.03, 0.07, 1), Color(0, 0, 0, 1), 0.0, 0.0, 1.0)

	# Hollow box so the inside can be seen once the lid is open.
	_box(chest_group, "ChestFloor", Vector3(1.1, 0.06, 0.72), Vector3(0, 0.93, 0), wood)
	_box(chest_group, "ChestFront", Vector3(1.1, 0.5, 0.06), Vector3(0, 1.15, 0.33), wood)
	_box(chest_group, "ChestBack", Vector3(1.1, 0.5, 0.06), Vector3(0, 1.15, -0.33), wood)
	_box(chest_group, "ChestLeft", Vector3(0.06, 0.5, 0.72), Vector3(-0.52, 1.15, 0), wood)
	_box(chest_group, "ChestRight", Vector3(0.06, 0.5, 0.72), Vector3(0.52, 1.15, 0), wood)
	_box(chest_group, "ChestLining", Vector3(1.0, 0.02, 0.6), Vector3(0, 0.97, 0), velvet)

	# Iron banding: corner posts plus two straps front and back.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_box(chest_group, "CornerIron", Vector3(0.09, 0.52, 0.09), Vector3(0.53 * x_sign, 1.15, 0.33 * z_sign), iron)
	for x_pos in [-0.25, 0.25]:
		_box(chest_group, "StrapFront", Vector3(0.08, 0.52, 0.075), Vector3(x_pos, 1.15, 0.345), iron)
		_box(chest_group, "StrapBack", Vector3(0.08, 0.52, 0.075), Vector3(x_pos, 1.15, -0.345), iron)
	_box(chest_group, "RimIron", Vector3(1.14, 0.05, 0.08), Vector3(0, 0.95, 0.34), iron)

	# Lock keep on the body front.
	_box(chest_group, "LockKeep", Vector3(0.14, 0.12, 0.03), Vector3(0, 1.3, 0.37), iron)


func _build_lid() -> void:
	var wood := _mat(Color(0.38, 0.19, 0.08, 1), Color(0, 0, 0, 1), 0.0, 0.0, 0.65)
	var iron := _mat(Color(0.1, 0.1, 0.12, 1), Color(0, 0, 0, 1), 0.0, 0.8, 0.5)

	# Hinged along the back-top edge; extends toward +z.
	lid_pivot = Node3D.new()
	lid_pivot.name = "LidPivot"
	lid_pivot.position = Vector3(0, 1.4, -0.36)
	chest_group.add_child(lid_pivot)

	_box(lid_pivot, "LidBoard", Vector3(1.14, 0.14, 0.78), Vector3(0, 0.07, 0.39), wood)
	_box(lid_pivot, "LidCrown", Vector3(1.06, 0.06, 0.66), Vector3(0, 0.17, 0.39), wood)
	for x_pos in [-0.34, 0.34]:
		_box(lid_pivot, "LidStrap", Vector3(0.09, 0.2, 0.8), Vector3(x_pos, 0.09, 0.39), iron)
	_box(lid_pivot, "LidHasp", Vector3(0.16, 0.28, 0.03), Vector3(0, 0.0, 0.79), iron)


func _build_padlock() -> void:
	var brass := _mat(Color(0.62, 0.48, 0.16, 1), Color(0, 0, 0, 1), 0.0, 0.85, 0.35)
	padlock = Node3D.new()
	padlock.name = "Padlock"
	padlock.position = Vector3(0, 1.24, 0.46)
	chest_group.add_child(padlock)
	_box(padlock, "LockBody", Vector3(0.14, 0.16, 0.07), Vector3.ZERO, brass)
	var shackle := MeshInstance3D.new()
	shackle.name = "Shackle"
	var shackle_mesh := TorusMesh.new()
	shackle_mesh.inner_radius = 0.03
	shackle_mesh.outer_radius = 0.055
	shackle.mesh = shackle_mesh
	shackle.material_override = brass
	shackle.position = Vector3(0, 0.1, 0)
	shackle.rotation_degrees.x = 90.0
	padlock.add_child(shackle)


func _build_contents() -> void:
	var velvet := _mat(Color(0.45, 0.05, 0.09, 1), Color(0, 0, 0, 1), 0.0, 0.0, 1.0)
	var parchment := _mat(Color(0.86, 0.78, 0.58, 1))
	var ribbon := _mat(Color(0.6, 0.08, 0.08, 1))
	var crystal := _mat(Color(0.75, 0.95, 1.0, 0.78), Color(0.5, 0.85, 1.0, 1), 1.8, 0.3, 0.05)

	# Velvet cushion with the diamond on top.
	_box(chest_group, "Cushion", Vector3(0.56, 0.1, 0.4), Vector3(-0.2, 1.05, 0), velvet)
	diamond = Node3D.new()
	diamond.name = "Diamond"
	diamond.position = Vector3(-0.2, 1.28, 0)
	chest_group.add_child(diamond)
	_cyl(diamond, "Crown", 0.07, 0.14, 0.08, Vector3(0, 0.04, 0), crystal, 8)
	_cyl(diamond, "Pavilion", 0.14, 0.0, 0.16, Vector3(0, -0.08, 0), crystal, 8)
	diamond_light = OmniLight3D.new()
	diamond_light.name = "DiamondGlow"
	diamond_light.position = Vector3(0, 0.15, 0)
	diamond_light.omni_range = 2.6
	diamond_light.light_energy = 0.0
	diamond_light.light_color = Color(0.7, 0.92, 1.0, 1)
	diamond.add_child(diamond_light)

	# The rolled-up 'Contract' scroll next to it.
	var scroll := Node3D.new()
	scroll.name = "ContractScroll"
	scroll_node = scroll
	scroll.position = Vector3(0.25, 1.05, 0.02)
	scroll.rotation_degrees.y = 18.0
	chest_group.add_child(scroll)
	_cyl(scroll, "Roll", 0.045, 0.045, 0.42, Vector3.ZERO, parchment, 14).rotation_degrees.z = 90.0
	_cyl(scroll, "RibbonBand", 0.05, 0.05, 0.04, Vector3.ZERO, ribbon, 14).rotation_degrees.z = 90.0


func _build_lamp() -> void:
	var brass := _mat(Color(0.62, 0.48, 0.16, 1), Color(0, 0, 0, 1), 0.0, 0.85, 0.35)
	var shade := _mat(Color(0.9, 0.62, 0.22, 1), Color(1.0, 0.6, 0.15, 1), 1.2)
	var bulb := _mat(Color(1.0, 0.9, 0.6, 1), Color(1.0, 0.75, 0.3, 1), 3.0)

	# Antique desk lamp, left of the chest.
	var lamp := Node3D.new()
	lamp.name = "AntiqueLamp"
	lamp.position = Vector3(-0.85, 0.9, -0.15)
	add_child(lamp)
	_cyl(lamp, "LampBase", 0.13, 0.15, 0.06, Vector3(0, 0.03, 0), brass, 16)
	_cyl(lamp, "LampStem", 0.02, 0.02, 0.4, Vector3(0, 0.26, 0), brass, 10)
	_cyl(lamp, "LampShade", 0.08, 0.2, 0.22, Vector3(0, 0.55, 0), shade, 16)
	var bulb_mesh := MeshInstance3D.new()
	bulb_mesh.name = "LampBulb"
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	bulb_mesh.mesh = sphere
	bulb_mesh.material_override = bulb
	bulb_mesh.position = Vector3(0, 0.46, 0)
	lamp.add_child(bulb_mesh)

	var warm_glow := OmniLight3D.new()
	warm_glow.name = "LampGlow"
	warm_glow.position = Vector3(0, 0.5, 0)
	warm_glow.omni_range = 2.4
	warm_glow.light_energy = 0.5
	warm_glow.light_color = Color(1.0, 0.75, 0.4, 1)
	lamp.add_child(warm_glow)

	# The concentrated pool of light on the chest.
	var pool := SpotLight3D.new()
	pool.name = "LampPool"
	pool.position = Vector3(-0.85, 1.55, -0.15)
	pool.spot_range = 4.5
	pool.spot_angle = 38.0
	pool.spot_attenuation = 1.0
	pool.light_energy = 9.0
	pool.light_color = Color(1.0, 0.82, 0.5, 1)
	pool.shadow_enabled = true
	add_child(pool)
	lamp_pool = pool
	lamp_glow = warm_glow
	lamp_bulb_material = bulb
	lamp_shade_material = shade
	pool.look_at(to_global(Vector3(0.0, 1.1, 0.0)), Vector3.UP)


func _build_collision() -> void:
	var desk_shape := CollisionShape3D.new()
	var desk_box := BoxShape3D.new()
	desk_box.size = Vector3(2.3, 0.9, 1.0)
	desk_shape.shape = desk_box
	desk_shape.position = Vector3(0, 0.45, 0)
	add_child(desk_shape)

	var chest_shape := CollisionShape3D.new()
	var chest_box := BoxShape3D.new()
	chest_box.size = Vector3(1.14, 0.62, 0.8)
	chest_shape.shape = chest_box
	chest_shape.position = Vector3(0, 1.2, 0)
	add_child(chest_shape)


func _build_camera() -> void:
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "ChestCamera"
	cinematic_camera.top_level = true
	cinematic_camera.fov = 50.0
	add_child(cinematic_camera)
