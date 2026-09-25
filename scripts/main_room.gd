extends Node3D

const DirtyMirrorScript = preload("res://scripts/dirty_mirror.gd")
const DirtyDoorScript = preload("res://scripts/dirty_door.gd")
const RewireTaskScript = preload("res://scripts/rewire_task.gd")
const PipelineTaskScript = preload("res://scripts/pipeline_task.gd")
const FurnitureScript = preload("res://scripts/sofa_interactable.gd")
const PowerSwitchScript = preload("res://scripts/power_switch.gd")
const TreasureChestScript = preload("res://scripts/treasure_chest.gd")
const KeyPickupScript = preload("res://scripts/key_pickup.gd")
const GameFlow = preload("res://scripts/game_flow.gd")
const ENDING_SCENE_PATH := "res://scenes/ending_screen.tscn"

# Spy-mechanics update: the 4 new tasks + the scene-local run randomizer.
const LockPickDrawerScript = preload("res://scripts/tasks/lock_pick_drawer.gd")
const CrookedPictureScript = preload("res://scripts/tasks/crooked_picture.gd")
const WallSafeScript = preload("res://scripts/tasks/wall_safe.gd")
const SpillCleanerScript = preload("res://scripts/tasks/spill_cleaner.gd")
const PermanentStainScript = preload("res://scripts/tasks/permanent_stain.gd")
const RunGeneratorScript = preload("res://scripts/autoload/run_generator.gd")

# --- Suspicion + lighting tuning (change these numbers to taste) -----------
const LOITER_RADIUS := 3.0               # how close (flat distance) counts as "standing here"
const LOITER_GRACE_SECONDS := 10.0       # free time before suspicion starts climbing
const LOITER_SUSPICION_PER_SECOND := 4.0 # how fast suspicion climbs after the grace time
const FIXED_CEILING_ENERGY_MULTIPLIER := 5.0  # ceiling light brightness once wiring is fixed
const FIXED_SPOT_ENERGY := 4.5
const FIXED_FILL_ENERGY := 1.4
const FIXED_AMBIENT_ENERGY := 0.55
const FIXED_SUN_ENERGY := 0.35
# Extra soft lights spread around the room. Off while the wiring is broken.
const FILL_LIGHT_POSITIONS: Array[Vector3] = [
	Vector3(-6.0, 3.4, 6.0),
	Vector3(6.0, 3.4, 6.0),
	Vector3(0.0, 3.4, 0.0),
	Vector3(-6.0, 3.4, -4.0),
	Vector3(4.5, 3.4, 4.0),
	Vector3(-6.0, 3.4, -8.0),
	Vector3(7.0, 3.4, 8.0),
]

# Sofa, dining table, 2 chairs and the cabinet.
const FURNITURE_TOTAL := 5

@onready var hud: CanvasLayer = $HUD
@onready var interaction_ray: RayCast3D = $Player/Head/Camera3D/InteractionRay
@onready var player: PlayerController = $Player
@onready var sofa: StaticBody3D = $Sofa
@onready var game_manager: Node = $GameManager
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D

var dust_cleaned: int = 0
var webs_cleared: int = 0
var furniture_placed: int = 0
var bathroom_mirrors_cleaned: int = 0
var bathroom_door_cleaned: int = 0
var bathroom_pipe_cleaned: int = 0
var panel_repaired: int = 0
var fridge_done: int = 0
var fridge_switch: StaticBody3D
var saved_ambient_energy: float = 0.0
var saved_sun_energy: float = 0.0
var dim_tween: Tween
var game_over: bool = false
var ambience_time: float = 0.0
var ceiling_lights: Array[OmniLight3D] = []
var light_bulbs: Array[MeshInstance3D] = []
var light_base_energy: Array[float] = [0.52, 0.48, 0.42, 0.46, 0.46, 0.42]
var lights_fixed: bool = false
var light_is_on: Array[bool] = []
var light_next_change: Array[float] = []
var repair_spotlights: Array[SpotLight3D] = []
var repair_bulbs: Array[MeshInstance3D] = []
var fridge_status_light: MeshInstance3D
var fridge_interior_light: OmniLight3D
var fridge_is_powered: bool = false
var chest_node: StaticBody3D
var suspicion_manager: Node
var loiter_time: float = 0.0
var loiter_warned: bool = false
var loiter_spot_id: String = ""
var fill_lights: Array[OmniLight3D] = []

# --- Fixed 9-task checklist --------------------------------------------------
# All nine tasks are always active. There is no random task selection or
# random task removal, so the HUD always shows the complete 9-task checklist.
var task_active: Dictionary = {
	"dust": true, "panel_repair": true, "fridge": true,
	"furniture": true, "washroom": true,
	"lockpick": true, "picture": true, "spill": true, "stain": true,
}
var lockpick_done: int = 0
var picture_done: int = 0
var spill_done: int = 0
var stain_done: int = 0
var lock_pick_drawer_node: StaticBody3D
var crooked_picture_node: StaticBody3D
var spill_cleaner_node: StaticBody3D
var permanent_stain_node: StaticBody3D
var wall_safe_node: StaticBody3D


func _ready() -> void:
	interaction_ray.target_changed.connect(hud.set_interaction_prompt)
	player.tool_selected.connect(hud.set_active_tool)
	hud.set_active_tool(player.current_tool)
	suspicion_manager = get_node_or_null("/root/SuspicionManager")

	game_manager.time_changed.connect(hud.set_timer)
	game_manager.time_expired.connect(_on_time_expired)
	game_manager.key_changed.connect(hud.set_key_owned)
	_build_floor_plan_props()

	for dust_spot in get_tree().get_nodes_in_group("dust_spot"):
		dust_spot.cleaned.connect(_on_dust_cleaned)

	for spider_web in get_tree().get_nodes_in_group("spider_web"):
		spider_web.cleared.connect(_on_web_cleared)

	for bathroom_mirror in get_tree().get_nodes_in_group("bathroom_mirror"):
		bathroom_mirror.cleaned.connect(_on_bathroom_mirror_cleaned)

	for bathroom_door in get_tree().get_nodes_in_group("bathroom_door"):
		bathroom_door.cleaned.connect(_on_bathroom_door_cleaned)

	for repair_task in get_tree().get_nodes_in_group("repair_task"):
		repair_task.completed.connect(_on_repair_task_completed)

	for furniture_item in get_tree().get_nodes_in_group("furniture_item"):
		furniture_item.placed.connect(_on_furniture_placed)

	ceiling_lights = [$CeilingLightLeft, $CeilingLightRight, $CeilingLightBack, $CeilingLightFrontLeft, $CeilingLightFrontRight, $CeilingLightCenter]
	light_bulbs = [$BlueBulb, $AmberBulb, $GreenBulb, $FrontLeftBulb, $FrontRightBulb, $CenterBulb]
	light_is_on.resize(ceiling_lights.size())
	light_is_on.fill(true)
	light_next_change.resize(ceiling_lights.size())
	for index in range(light_next_change.size()):
		light_next_change[index] = randf_range(1.2, 3.2)
	_refresh_hud()


func _build_floor_plan_props() -> void:
	# The floor-plan additions are built from simple meshes so the project has
	# no external asset dependencies and remains easy to edit in Godot.
	_add_front_wall()
	_build_mop_station(Vector3(-6.7, 0.0, -9.55))
	_build_rug(Vector3(0.0, 0.18, -5.4))
	_build_cabinet()
	_build_chest()
	_build_key()
	# Center the television on the sofa's placement position so it faces the
	# seating area instead of sitting off to the side.
	_build_tv(Vector3(-5.5, 0.0, 9.78))
	_build_broken_floor(Vector3(-5.8, 0.0, 6.7))
	# On the front wall, left of the desk/chest and right of the TV, filling
	# the open gap between them (TV's right edge is ~x -3.1, the desk's left
	# edge is ~x 0.33) - the front wall is at z 10, so this needs the 180
	# rotation to flip the shelf's open front from its default +z to -z,
	# i.e. into the room, same as the chest itself.
	# Purely decorative, not part of any task, same pattern as the TV / mop
	# station / rug.
	_build_bookshelf(Vector3(-1.4, 0.0, 9.6), 180.0)
	_build_furniture_items()
	_build_bathroom()
	_build_reference_game_props()
	_build_spy_mechanics_update()


func _material(color: Color, emission: Color = Color(0, 0, 0, 1), emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _sphere(parent: Node3D, node_name: String, radius: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _static_box(node_name: String, size: Vector3, world_position: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	_box(body, "MeshInstance3D", size, Vector3.ZERO, material)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _new_prop_root(node_name: String, world_position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = world_position
	add_child(root)
	return root


func _add_front_wall() -> void:
	var wall := StaticBody3D.new()
	wall.name = "FrontWall"
	wall.position = Vector3(0.0, 2.0, 10.0)
	add_child(wall)

	var wall_material := _material(Color(0.702, 0.681, 0.556, 1))
	_box(wall, "MeshInstance3D", Vector3(20.0, 4.0, 0.2), Vector3.ZERO, wall_material)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 4.0, 0.2)
	collision.shape = shape
	wall.add_child(collision)


func _build_mop_station(world_position: Vector3) -> void:
	var root := _new_prop_root("MopStation", world_position)
	var dark := _material(Color(0.06, 0.08, 0.13, 1))
	var metal := _material(Color(0.348, 0.385, 0.432, 1))
	var yellow := _material(Color(0.828, 0.666, 0.39, 1), Color(0.35, 0.17, 0.01, 1), 0.35)
	_box(root, "StationBack", Vector3(2.8, 2.3, 0.12), Vector3(0, 1.25, 0), dark)
	_box(root, "Shelf", Vector3(2.8, 0.12, 0.7), Vector3(0, 0.45, 0.38), metal)
	_box(root, "Rack", Vector3(2.2, 0.08, 0.08), Vector3(0, 2.05, 0.34), metal)
	_box(root, "Bucket", Vector3(0.82, 0.58, 0.82), Vector3(-0.78, 0.28, 0.35), yellow)
	for index in range(3):
		var handle := _cylinder(root, "StoredMop%d" % index, 0.035, 1.8, Vector3(0.45 + index * 0.22, 1.1, 0.34), metal)
		handle.rotation_degrees = Vector3(0, 0, -7.0 + index * 7.0)
		_box(root, "MopHead%d" % index, Vector3(0.42, 0.11, 0.18), Vector3(0.45 + index * 0.22, 0.25, 0.34), yellow)


func _build_rug(world_position: Vector3) -> void:
	var root := _new_prop_root("Rug", world_position)
	var border := _material(Color(0.22, 0.045, 0.055, 1))
	var inner := _material(Color(0.495, 0.302, 0.271, 1))
	_box(root, "RugBorder", Vector3(4.8, 0.06, 2.55), Vector3.ZERO, border)
	_box(root, "RugPattern", Vector3(4.35, 0.075, 2.1), Vector3(0, 0.035, 0), inner)
	for x in range(-2, 3):
		_box(root, "RugStripe%d" % x, Vector3(0.08, 0.02, 1.9), Vector3(x * 0.75, 0.09, 0), border)


func _build_cabinet() -> void:
	# Starts in front of the desk + chest in the back-left corner, hiding them
	# from the room. Pick it up and carry it to the pink footprint on the right
	# wall. It counts toward the FURNITURE task like the sofa/table/chairs.
	var root := _new_furniture_item(
		"Cabinet",
		"CABINET",
		Vector3(-7.6, 0.0, -5.0),
		Vector3(9.15, 0.0, -1.2),
		Vector3(2.9, 0.04, 1.5),
		Vector3(0.0, 90.0, 0.0),
		0.55,
		Vector3(0.0, 180.0, 0.0)
	)
	var wood := _material(Color(0.28, 0.12, 0.055, 1))
	var trim := _material(Color(0.504, 0.353, 0.259, 1))
	_box(root, "CabinetBody", Vector3(2.5, 2.2, 1.25), Vector3(0, 1.1, 0), wood)
	_box(root, "CabinetTop", Vector3(2.75, 0.14, 1.4), Vector3(0, 2.27, 0), trim)
	for row in range(2):
		for column in range(2):
			var drawer := _box(root, "Drawer%d%d" % [row, column], Vector3(1.0, 0.72, 0.05), Vector3(-0.55 + column * 1.1, 1.55 - row * 0.82, -0.65), trim)
			drawer.rotation_degrees.x = -2.0
			_cylinder(root, "Handle%d%d" % [row, column], 0.05, 0.28, Vector3(-0.55 + column * 1.1, 1.55 - row * 0.82, -0.74), wood).rotation_degrees = Vector3(90, 0, 0)
	_add_body_collision(root, Vector3(2.5, 2.2, 1.25), Vector3(0, 1.1, 0))


func _build_chest() -> void:
	# Desk + chest placed in the open room area shown in the reference image.
	# Not movable. Needs the key (see _build_key).
	var chest := StaticBody3D.new()
	chest.name = "TreasureChest"
	# Wall-mounted placement: keep the desk + chest against the front wall,
	# parallel to the wall and well clear of the refrigerator/TV. The desk is
	# flush to the wall and the chest opens toward the room.
	chest.position = Vector3(1.5, 0.1, 9.25)
	chest.rotation_degrees.y = 180.0
	chest.set_script(TreasureChestScript)
	add_child(chest)
	chest_node = chest
	chest.call("setup", player, hud, game_manager)
	chest.connect("choice_started", _on_chest_choice_started)
	chest.connect("choice_finished", _on_chest_choice_finished)


func _build_key() -> void:
	# Hidden on the middle shelf of the bathroom storage rack (rack is at
	# x 3.42, z -5.15; the middle shelf top is at y 1.195).
	var key := StaticBody3D.new()
	key.name = "ChestKey"
	key.position = Vector3(3.62, 1.2, -4.75)
	key.rotation_degrees.y = 100.0
	key.set_script(KeyPickupScript)
	key.add_to_group("chest_key")
	add_child(key)


# --- Spy mechanics update: 4 new tasks + run randomizer --------------------
# Placed by hand against this room's actual layout (see INTEGRATION_GUIDE.md
# for the coordinates reasoning). All 4 build their own meshes/collision in
# their own scripts' _ready(), same as every other prop in this file - this
# just instantiates them at a world position, matching _build_chest()'s
# pattern above.

func _build_spy_mechanics_update() -> void:
	_build_lock_pick_drawer()
	_build_crooked_picture()
	_build_spill_tasks()
	_build_run_generator()
	_build_safe_corner_light()
	_build_fill_lights()


func _build_lock_pick_drawer() -> void:
	# A secret drawer built into the left-wall paneling, between the fridge
	# switch (z 0) and the TV corner (z ~9.8) - open wall real estate.
	var drawer := StaticBody3D.new()
	drawer.name = "LockPickDrawer"
	drawer.position = Vector3(-9.85, 0.9, 4.0)
	drawer.rotation_degrees.y = 90.0
	drawer.set_script(LockPickDrawerScript)
	add_child(drawer)
	lock_pick_drawer_node = drawer
	drawer.connect("unlocked", _on_lockpick_unlocked)


func _build_crooked_picture() -> void:
	# Right wall, beside the cabinet's furniture destination. The picture is
	# flipped to face into the room; the hidden code plaster patch is a child
	# of this prop, so it flips with the picture too.
	var picture := StaticBody3D.new()
	picture.name = "CrookedPicture"
	picture.position = Vector3(9.82, 1.85, 2.0)
	picture.rotation_degrees.y = -90.0
	picture.set_script(CrookedPictureScript)
	add_child(picture)
	crooked_picture_node = picture
	picture.connect("straightened", _on_picture_straightened)

	# The safe code the picture reveals needs somewhere to go, but a real
	# hidden safe reads better on a DIFFERENT wall than the picture that
	# gives away its code - not sitting right next to it. Left wall, between
	# the back corner (z -9.8) and the rewire panel (z -4.5), well clear of
	# both and of the lock-pick drawer further up at z 4.0. Entirely
	# optional: it isn't in RunGenerator's task pool and doesn't affect
	# _task_complete()/winning either way.
	var safe := StaticBody3D.new()
	safe.name = "WallSafe"
	safe.position = Vector3(-9.85, 1.0, -7.5)
	safe.rotation_degrees.y = 90.0
	safe.set_script(WallSafeScript)
	add_child(safe)
	wall_safe_node = safe
	safe.connect("opened", _on_safe_opened)


func _build_spill_tasks() -> void:
	# Open floor, away from the rug (roughly x -2.4..2.4, z -6.7..-4.1),
	# the dust spots, and the rewire-panel/fridge wall furniture.
	var spill := StaticBody3D.new()
	spill.name = "SpillCleaner"
	spill.position = Vector3(-3.5, 0.1, -2.0)
	spill.set_script(SpillCleanerScript)
	add_child(spill)
	spill_cleaner_node = spill
	spill.connect("cleaned", _on_spill_cleaned)

	# Just outside the bathroom doorway (door is at x 6.4, z -3.65) - reads
	# as "something was dragged out of the bathroom and scrubbed here".
	var stain := StaticBody3D.new()
	stain.name = "PermanentStain"
	stain.position = Vector3(6.4, 0.1, -3.0)
	stain.set_script(PermanentStainScript)
	add_child(stain)
	permanent_stain_node = stain
	stain.connect("capped", _on_stain_capped)


func _build_run_generator() -> void:
	# 3 candidate key-spawn points: the original bathroom shelf spot, the
	# rack's top shelf, and the mop station shelf out in the main room, so
	# a run can occasionally NOT hide the key in the bathroom at all.
	var spawn_a := Marker3D.new()
	spawn_a.name = "KeySpawn_A"
	spawn_a.position = Vector3(3.62, 1.2, -4.75)
	spawn_a.rotation_degrees.y = 100.0
	spawn_a.add_to_group("key_spawn_point")
	add_child(spawn_a)

	var spawn_b := Marker3D.new()
	spawn_b.name = "KeySpawn_B"
	spawn_b.position = Vector3(3.62, 1.7, -4.75)
	spawn_b.rotation_degrees.y = 100.0
	spawn_b.add_to_group("key_spawn_point")
	add_child(spawn_b)

	var spawn_c := Marker3D.new()
	spawn_c.name = "KeySpawn_C"
	spawn_c.position = Vector3(-6.7, 0.5, -9.2)
	spawn_c.rotation_degrees.y = 30.0
	spawn_c.add_to_group("key_spawn_point")
	add_child(spawn_c)

	# All 9 tasks (the project's original 5 + the 4 new ones) are in the
	# randomizable pool now - RunGenerator picks 5 of them active per run.
	# Connect BEFORE add_child: adding a node whose parent is already in the
	# tree runs its _ready() immediately, and run_generated fires from
	# inside _ready() - connecting after add_child would miss the signal.
	var run_generator := Node.new()
	run_generator.name = "RunGenerator"
	run_generator.set_script(RunGeneratorScript)
	run_generator.connect("run_generated", _on_run_generated)
	add_child(run_generator)


func _on_run_generated(_modifier_id: String, _key_spawn_name: String, _deactivated_task_ids: Array) -> void:
	# The run generator no longer removes tasks. Keep every task enabled and
	# visible so every playthrough has the same complete 9-task checklist.
	for id in task_active.keys():
		task_active[id] = true
	RunGeneratorScript.apply_node_active(lock_pick_drawer_node, true)
	RunGeneratorScript.apply_node_active(crooked_picture_node, true)
	RunGeneratorScript.apply_node_active(wall_safe_node, true)
	RunGeneratorScript.apply_node_active(spill_cleaner_node, true)
	RunGeneratorScript.apply_node_active(permanent_stain_node, true)
	_refresh_hud()


func _on_chest_choice_started() -> void:
	# The game is paused at this point; dim the room with a tween that keeps
	# running while paused. Ceiling lights and spotlights are re-driven every
	# frame by _process once play resumes, so only the environment and sun
	# need explicit restoring.
	if world_environment.environment != null:
		saved_ambient_energy = world_environment.environment.ambient_light_energy
	saved_sun_energy = directional_light.light_energy

	dim_tween = create_tween()
	dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	dim_tween.set_parallel(true)
	for light in ceiling_lights:
		dim_tween.tween_property(light, "light_energy", light.light_energy * 0.15, 0.8)
	for fill in fill_lights:
		dim_tween.tween_property(fill, "light_energy", fill.light_energy * 0.15, 0.8)
	for spotlight in repair_spotlights:
		dim_tween.tween_property(spotlight, "light_energy", spotlight.light_energy * 0.15, 0.8)
	if world_environment.environment != null:
		dim_tween.tween_property(world_environment.environment, "ambient_light_energy", saved_ambient_energy * 0.2, 0.8)
	dim_tween.tween_property(directional_light, "light_energy", saved_sun_energy * 0.2, 0.8)


func _on_chest_choice_finished(diamond_taken: bool) -> void:
	if dim_tween != null and dim_tween.is_valid():
		dim_tween.kill()
	if world_environment.environment != null:
		world_environment.environment.ambient_light_energy = saved_ambient_energy
	directional_light.light_energy = saved_sun_energy
	if diamond_taken:
		hud.call("add_collected_item", "DIAMOND")


func _build_tv(world_position: Vector3) -> void:
	var root := _new_prop_root("TV", world_position)
	var stand := _material(Color(0.035, 0.04, 0.055, 1))
	var screen := _material(Color(0.025, 0.12, 0.19, 1), Color(0.01, 0.13, 0.23, 1), 1.2)
	_box(root, "TVStand", Vector3(4.8, 0.18, 0.9), Vector3(0, 0.35, 0), stand)
	_box(root, "TVStem", Vector3(0.18, 0.75, 0.18), Vector3(0, 0.8, 0), stand)
	_box(root, "TVFrame", Vector3(4.7, 2.5, 0.18), Vector3(0, 2.1, 0), stand)
	_box(root, "TVScreen", Vector3(4.35, 2.15, 0.035), Vector3(0, 2.1, -0.11), screen)
	for index in range(4):
		_box(root, "TVGlow%d" % index, Vector3(0.05, 1.65, 0.012), Vector3(-1.5 + index * 1.0, 2.1, -0.135), _material(Color(0.287, 0.469, 0.558, 1), Color(0.02, 0.2, 0.4, 1), 1.0))


func _build_broken_floor(world_position: Vector3) -> void:
	var root := _new_prop_root("BrokenFloorArea", world_position)
	var hole := _material(Color(0.018, 0.02, 0.026, 1))
	var broken_wood := _material(Color(0.2, 0.075, 0.025, 1))
	_box(root, "DarkOpening", Vector3(3.1, 0.035, 2.8), Vector3.ZERO, hole)
	for index in range(7):
		var plank := _box(root, "BrokenPlank%d" % index, Vector3(0.75, 0.07, 0.22), Vector3(-1.25 + (index % 4) * 0.8, 0.07, -0.95 + (index / 4) * 1.8), broken_wood)
		plank.rotation_degrees.y = -18.0 + index * 11.0
		plank.rotation_degrees.z = -7.0 + index * 4.0


func _build_bookshelf(world_position: Vector3, rotation_y: float = 0.0) -> void:
	# Decorative only (no collision, no task hookup) - same treatment as the
	# TV and mop station. Built from primitives so it stays consistent with
	# the rest of the room's no-external-assets art style. Faces +z by
	# default (its open front), which is "into the room" when mounted flush
	# against the back wall at z -10, matching the wall-mount convention
	# used by the rewire panel / wall safe / lock-pick drawer.
	var root := _new_prop_root("Bookshelf", world_position)
	root.rotation_degrees.y = rotation_y

	var carcass := _material(Color(0.223, 0.127, 0.065, 1))
	var trim := _material(Color(0.32, 0.19, 0.098, 1))
	var shelf_wood := _material(Color(0.27, 0.155, 0.078, 1))
	var palette: Array[StandardMaterial3D] = [
		_material(Color(0.5, 0.1, 0.09, 1)),
		_material(Color(0.09, 0.26, 0.17, 1)),
		_material(Color(0.13, 0.15, 0.4, 1)),
		_material(Color(0.52, 0.36, 0.11, 1)),
		_material(Color(0.28, 0.17, 0.09, 1)),
		_material(Color(0.4, 0.38, 0.33, 1)),
		_material(Color(0.47, 0.06, 0.26, 1)),
		_material(Color(0.16, 0.32, 0.35, 1)),
	]

	var width := 2.4
	var height := 3.15
	var depth := 0.46
	var half_width := width * 0.5

	# Carcass: sides, top, kick base, and a recessed back panel.
	_box(root, "SideLeft", Vector3(0.08, height, depth), Vector3(-half_width + 0.04, height * 0.5, 0.0), carcass)
	_box(root, "SideRight", Vector3(0.08, height, depth), Vector3(half_width - 0.04, height * 0.5, 0.0), carcass)
	_box(root, "TopCap", Vector3(width + 0.1, 0.1, depth + 0.06), Vector3(0.0, height + 0.05, 0.0), trim)
	_box(root, "KickBase", Vector3(width, 0.14, depth), Vector3(0.0, 0.07, 0.0), trim)
	_box(root, "BackPanel", Vector3(width - 0.14, height - 0.14, 0.03), Vector3(0.0, height * 0.5, -depth * 0.5 + 0.015), carcass)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var shelf_count := 5
	var usable_height := height - 0.34
	for row in range(shelf_count):
		var shelf_y: float = 0.3 + (float(row) / float(shelf_count - 1)) * usable_height
		_box(root, "ShelfBoard%d" % row, Vector3(width - 0.18, 0.05, depth - 0.05), Vector3(0.0, shelf_y, 0.01), shelf_wood)
		if row == shelf_count - 1:
			continue

		# Fill the shelf with a row of upright books of varied width,
		# height and colour, each with a slight random lean.
		var x := -half_width + 0.16
		var limit := half_width - 0.12
		while x < limit:
			if rng.randf() < 0.09:
				x += rng.randf_range(0.06, 0.16)
				continue
			var book_width: float = rng.randf_range(0.055, 0.11)
			if x + book_width > limit:
				break
			var book_height: float = rng.randf_range(0.3, 0.5)
			var book_depth: float = depth - rng.randf_range(0.14, 0.2)
			var lean: float = rng.randf_range(-5.0, 5.0)
			var book := _box(
				root,
				"Book_%d_%d" % [row, int(x * 1000.0)],
				Vector3(book_width, book_height, book_depth),
				Vector3(x + book_width * 0.5, shelf_y + 0.025 + book_height * 0.5, 0.0),
				palette[rng.randi() % palette.size()]
			)
			book.rotation_degrees.z = lean
			x += book_width + 0.012

	# A couple of books stacked flat on top, plus a small potted plant, so
	# the top of the shelf doesn't read as bare.
	_box(root, "TopBookA", Vector3(0.46, 0.06, 0.32), Vector3(-0.6, height + 0.13, 0.0), palette[3])
	_box(root, "TopBookB", Vector3(0.38, 0.06, 0.28), Vector3(-0.58, height + 0.19, 0.02), palette[1])
	var pot_material := _material(Color(0.34, 0.2, 0.11, 1))
	var leaf_material := _material(Color(0.13, 0.3, 0.14, 1))
	_cylinder(root, "PlantPot", 0.13, 0.2, Vector3(0.65, height + 0.2, 0.0), pot_material)
	_sphere(root, "PlantLeaves", 0.17, Vector3(0.65, height + 0.4, 0.0), leaf_material)


func _build_furniture_items() -> void:
	# The furniture starts in empty staging spots. The dining table's final
	# pink footprint is centered on the rug, with the two chairs aligned
	# opposite each other at the rug's long sides.
	var table := _new_furniture_item(
		"DiningTable",
		"DINING TABLE",
		Vector3(6.5, 0.0, 4.35),
		Vector3(0.0, 0.18, -5.4),
		Vector3(2.9, 0.04, 1.65),
		Vector3(0.0, 0.0, 0.0),
		0.72,
		Vector3(0.0, 90.0, 0.0)
	)
	var table_wood := _material(Color(0.36, 0.16, 0.065, 1))
	var table_trim := _material(Color(0.522, 0.365, 0.271, 1))
	_box(table, "TableTop", Vector3(2.9, 0.18, 1.55), Vector3(0, 1.48, 0), table_wood)
	_box(table, "TableEdge", Vector3(2.75, 0.12, 1.42), Vector3(0, 1.36, 0), table_trim)
	for index in range(4):
		_box(
			table,
			"TableLeg%d" % index,
			Vector3(0.16, 1.35, 0.16),
			Vector3(-1.15 if index % 2 == 0 else 1.15, 0.68, -0.58 if index < 2 else 0.58),
			table_wood
		)
	_add_body_collision(table, Vector3(2.85, 1.55, 1.5), Vector3(0, 0.78, 0))

	var chair_a := _new_furniture_item(
		"DiningChairA",
		"CHAIR 1",
		Vector3(8.3, 0.0, 5.3),
		Vector3(0.0, 0.18, -7.0),
		Vector3(0.95, 0.04, 0.95),
		Vector3(0.0, 180.0, 0.0),
		0.82,
		Vector3(0.0, 0.0, 0.0)
	)
	_build_dining_chair_meshes(chair_a)

	var chair_b := _new_furniture_item(
		"DiningChairB",
		"CHAIR 2",
		Vector3(7.35, 0.0, 2.5),
		Vector3(0.0, 0.18, -3.8),
		Vector3(0.95, 0.04, 0.95),
		Vector3(0.0, 0.0, 0.0),
		0.82,
		Vector3(0.0, 180.0, 0.0)
	)
	_build_dining_chair_meshes(chair_b)


func _new_furniture_item(
	node_name: String,
	label: String,
	start_position: Vector3,
	target_position: Vector3,
	highlight_size: Vector3,
	target_rotation: Vector3,
	carry_scale: float,
	start_rotation: Vector3 = Vector3.ZERO,
	starts_placed: bool = false,
	join_task_group: bool = true
) -> StaticBody3D:
	var item := StaticBody3D.new()
	item.name = node_name
	item.position = start_position
	item.rotation_degrees = start_rotation
	item.set_script(FurnitureScript)
	item.set("item_label", label)
	item.set("placement_position", target_position)
	item.set("placement_rotation_degrees", target_rotation)
	item.set("highlight_size", highlight_size)
	item.set("carry_scale", carry_scale)
	item.set("starts_placed", starts_placed)
	item.add_to_group("interactable")
	if join_task_group:
		item.add_to_group("furniture_item")
	add_child(item)
	return item


func _build_dining_chair_meshes(chair: StaticBody3D) -> void:
	var wood := _material(Color(0.38, 0.17, 0.07, 1))
	var seat_material := _material(Color(0.495, 0.323, 0.26, 1))
	_box(chair, "Seat", Vector3(0.85, 0.14, 0.85), Vector3(0, 0.9, 0), seat_material)
	_box(chair, "Back", Vector3(0.85, 1.1, 0.14), Vector3(0, 1.42, 0.36), wood)
	for index in range(4):
		_box(
			chair,
			"Leg%d" % index,
			Vector3(0.1, 0.85, 0.1),
			Vector3(-0.3 if index % 2 == 0 else 0.3, 0.42, -0.3 if index < 2 else 0.3),
			wood
		)
	_add_body_collision(chair, Vector3(0.9, 1.65, 0.9), Vector3(0, 0.82, 0))


func _build_bathroom() -> void:
	var wall_material := _material(Color(0.675, 0.654, 0.534, 1))
	var bathroom_floor := _material(Color(0.24, 0.27, 0.3, 1))
	var bathroom_ceiling := _material(Color(0.08, 0.1, 0.15, 1))

	# The bathroom is a 6.4m x 6m room built inside the back-right corner
	# of the existing 20m x 20m room. The original outer walls stay intact.
	# The front wall has a doorway gap so the bathroom can be entered.
	_static_box("BathroomFloor", Vector3(6.4, 0.2, 6.0), Vector3(6.4, 0.0, -6.6), bathroom_floor)
	_static_box("BathroomLeftWall", Vector3(0.2, 4.0, 6.0), Vector3(3.3, 2.0, -6.6), wall_material)
	_static_box("BathroomRightWall", Vector3(0.2, 4.0, 6.0), Vector3(9.5, 2.0, -6.6), wall_material)
	_static_box("BathroomBackWall", Vector3(6.4, 4.0, 0.2), Vector3(6.4, 2.0, -9.55), wall_material)
	# The front wall is split to leave a doorway (sized up from the previous
	# pass, but still narrower than a regular interior door - true to how
	# bathroom doors are usually undersized) instead of one solid wall.
	# Shifted further left along the front wall (away from the commode/tub
	# corner) so the door isn't crowded against the right-side fixtures.
	_static_box("BathroomFrontWallLeft", Vector3(2.6, 4.0, 0.2), Vector3(4.5, 2.0, -3.65), wall_material)
	_static_box("BathroomFrontWallRight", Vector3(2.6, 4.0, 0.2), Vector3(8.3, 2.0, -3.65), wall_material)
	_static_box("BathroomDoorHeader", Vector3(1.2, 1.85, 0.2), Vector3(6.4, 3.075, -3.65), wall_material)
	_build_bathroom_door(Vector3(6.4, 0.0, -3.65))
	_static_box("BathroomCeiling", Vector3(6.4, 0.2, 6.0), Vector3(6.4, 4.0, -6.6), bathroom_ceiling)
	var tile_root := _new_prop_root("BathroomFloorTiles", Vector3.ZERO)
	var tile_a := _material(Color(0.31, 0.34, 0.37, 1))
	var tile_b := _material(Color(0.25, 0.29, 0.33, 1))
	# Tiles are sized and centered to fill exactly between the inner wall
	# faces (x: 3.4 to 9.4, z: -9.45 to -3.75) with a small uniform gap
	# between tiles, so the grid neither overlaps the main-room floor nor
	# leaves a bare strip at the walls.
	for column in range(6):
		for row in range(6):
			_box(
				tile_root,
				"Tile%d_%d" % [column, row],
				Vector3(0.96, 0.035, 0.91),
				Vector3(3.9 + column * 1.0, 0.13, -8.975 + row * 0.95),
				tile_a if (column + row) % 2 == 0 else tile_b
			)
	var bathroom_light := OmniLight3D.new()
	bathroom_light.name = "BathroomLight"
	bathroom_light.position = Vector3(6.4, 3.35, -6.6)
	bathroom_light.omni_range = 7.0
	bathroom_light.light_energy = 1.25
	bathroom_light.light_color = Color(0.72, 0.82, 1.0, 1)
	add_child(bathroom_light)

	var bathroom := _new_prop_root("BathroomFixtures", Vector3.ZERO)
	_build_basin(bathroom)
	_build_commode(bathroom)
	_build_bathtub(bathroom)
	_build_dirty_bathroom_mirror(bathroom)
	_build_storage_rack(bathroom)
	_build_bathroom_pipe(bathroom)


func _build_basin(parent: Node3D) -> void:
	var basin_root := StaticBody3D.new()
	basin_root.name = "Basin"
	basin_root.position = Vector3(4.65, 0.0, -8.8)
	parent.add_child(basin_root)
	var porcelain := _material(Color(0.68, 0.72, 0.76, 1))
	var metal := _material(Color(0.36, 0.43, 0.5, 1), Color(0.06, 0.08, 0.1, 1), 0.2)
	_box(basin_root, "Vanity", Vector3(1.65, 1.05, 0.65), Vector3(0, 0.55, 0), _material(Color(0.22, 0.12, 0.07, 1)))
	_box(basin_root, "Countertop", Vector3(1.85, 0.12, 0.82), Vector3(0, 1.12, 0), porcelain)
	_box(basin_root, "SinkBowl", Vector3(1.2, 0.18, 0.5), Vector3(0, 1.2, -0.02), porcelain)
	_cylinder(basin_root, "Faucet", 0.045, 0.42, Vector3(0, 1.42, 0.18), metal)
	_box(basin_root, "FaucetSpout", Vector3(0.34, 0.06, 0.06), Vector3(0, 1.61, 0.02), metal)
	_add_body_collision(basin_root, Vector3(1.7, 1.3, 0.75), Vector3(0, 0.65, 0))


func _build_commode(parent: Node3D) -> void:
	var commode_root := StaticBody3D.new()
	commode_root.name = "Commode"
	commode_root.position = Vector3(8.65, 0.0, -8.3)
	# The tank is fixed to the right wall and the bowl faces left,
	# toward the basin, exactly as in the floor-plan reference.
	commode_root.rotation_degrees.y = -90.0
	parent.add_child(commode_root)
	var porcelain := _material(Color(0.64, 0.68, 0.72, 1))
	var dark := _material(Color(0.18, 0.2, 0.22, 1))
	var bowl := _sphere(commode_root, "Bowl", 0.58, Vector3(0, 0.35, 0), porcelain)
	bowl.scale = Vector3(1.0, 0.62, 1.0)
	_torus(commode_root, "Seat", 0.52, 0.1, Vector3(0, 0.67, 0), dark)
	# The tank is against the back wall; the bowl faces the room and doorway.
	_box(commode_root, "Tank", Vector3(0.95, 1.05, 0.42), Vector3(0, 0.98, -0.48), porcelain)
	_box(commode_root, "TankLid", Vector3(1.05, 0.08, 0.5), Vector3(0, 1.54, -0.48), porcelain)
	_box(commode_root, "FlushButton", Vector3(0.18, 0.05, 0.12), Vector3(0, 1.61, -0.48), dark)
	_box(commode_root, "TankBackPlate", Vector3(1.1, 1.75, 0.08), Vector3(0, 0.88, -0.72), porcelain)
	_add_body_collision(commode_root, Vector3(1.1, 1.7, 1.15), Vector3(0, 0.85, 0.2))


func _torus(parent: Node3D, node_name: String, outer_radius: float, inner_radius: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_bathtub(parent: Node3D) -> void:
	var tub_root := StaticBody3D.new()
	tub_root.name = "Bathtub"
	tub_root.position = Vector3(8.3, 0.0, -5.55)
	# The tub is against the far-right wall between the toilet and doorway.
	tub_root.rotation_degrees.y = 0.0
	parent.add_child(tub_root)
	var porcelain := _material(Color(0.62, 0.68, 0.73, 1))
	var inside := _material(Color(0.12, 0.2, 0.25, 1), Color(0.03, 0.1, 0.14, 1), 0.35)
	var metal := _material(Color(0.36, 0.43, 0.5, 1), Color(0.06, 0.08, 0.1, 1), 0.2)
	_box(tub_root, "TubOuter", Vector3(2.0, 0.72, 3.35), Vector3(0, 0.42, 0), porcelain)
	_box(tub_root, "TubInterior", Vector3(1.66, 0.08, 2.95), Vector3(0, 0.82, 0), inside)
	_box(tub_root, "TubRimLeft", Vector3(0.18, 0.15, 3.55), Vector3(-0.92, 0.84, 0), porcelain)
	_box(tub_root, "TubRimRight", Vector3(0.18, 0.15, 3.55), Vector3(0.92, 0.84, 0), porcelain)
	_box(tub_root, "TubRimBack", Vector3(2.0, 0.15, 0.18), Vector3(0, 0.84, -1.68), porcelain)
	_cylinder(tub_root, "ShowerPipe", 0.045, 2.25, Vector3(0.66, 1.8, 1.38), metal)
	_cylinder(tub_root, "ShowerHead", 0.22, 0.1, Vector3(0.66, 2.85, 1.38), metal)
	_box(tub_root, "TapBar", Vector3(0.72, 0.06, 0.06), Vector3(0, 0.95, 1.48), metal)
	_add_body_collision(tub_root, Vector3(2.0, 1.0, 3.35), Vector3(0, 0.5, 0))


func _build_dirty_bathroom_mirror(parent: Node3D) -> void:
	var mirror := StaticBody3D.new()
	mirror.name = "DirtyBathroomMirror"
	mirror.position = Vector3(4.65, 2.65, -9.42)
	mirror.set_script(DirtyMirrorScript)
	mirror.add_to_group("interactable")
	mirror.add_to_group("bathroom_mirror")
	var frame := _material(Color(0.24, 0.27, 0.32, 1))
	var glass := _material(Color(0.1, 0.22, 0.28, 1), Color(0.03, 0.1, 0.14, 1), 0.6)
	var dirt := _material(Color(0.26, 0.2, 0.12, 0.78))
	dirt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(mirror, "Frame", Vector3(2.25, 1.75, 0.12), Vector3.ZERO, frame)
	_box(mirror, "Glass", Vector3(1.98, 1.48, 0.035), Vector3(0, 0, 0.09), glass)
	_box(mirror, "DirtLayer", Vector3(1.9, 1.4, 0.025), Vector3(0, 0, 0.115), dirt)
	for index in range(5):
		var streak := _box(mirror, "DirtStreak%d" % index, Vector3(0.11, 0.85, 0.02), Vector3(-0.72 + index * 0.36, 0.1 - index * 0.16, 0.135), dirt)
		streak.rotation_degrees.z = -12.0 + index * 6.0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.25, 1.75, 0.3)
	collision.shape = shape
	mirror.add_child(collision)
	parent.add_child(mirror)


func _build_storage_rack(parent: Node3D) -> void:
	# Mounted flat on the left wall, moved away from the basin. It has no
	# rotation applied - built directly with its open shelf side facing
	# +x (across the room, toward the bathtub) so the wall mount is exact.
	# Built directly (not via _new_prop_root, which parents to the room
	# itself) since this needs to be a child of the bathroom fixtures group -
	# calling both was a double-parent that Godot rejected at runtime.
	var rack := Node3D.new()
	rack.name = "StorageRack"
	rack.position = Vector3(3.42, 0.0, -5.15)
	parent.add_child(rack)
	var wood := _material(Color(0.32, 0.16, 0.07, 1))
	var metal := _material(Color(0.4, 0.46, 0.52, 1), Color(0.05, 0.06, 0.08, 1), 0.15)
	_box(rack, "BackPanel", Vector3(0.04, 1.9, 1.3), Vector3(0, 1.3, 0), wood)
	for index in range(3):
		var shelf_y := 0.55 + index * 0.62
		_box(rack, "Shelf%d" % index, Vector3(0.36, 0.05, 1.2), Vector3(0.2, shelf_y, 0), wood)
		_box(rack, "BracketFront%d" % index, Vector3(0.36, 0.04, 0.04), Vector3(0.2, shelf_y - 0.02, -0.56), metal)
		_box(rack, "BracketBack%d" % index, Vector3(0.36, 0.04, 0.04), Vector3(0.2, shelf_y - 0.02, 0.56), metal)
	_cylinder(rack, "Bottle0", 0.07, 0.28, Vector3(0.2, 0.72, -0.35), _material(Color(0.286, 0.495, 0.495, 1)))
	_cylinder(rack, "Bottle1", 0.06, 0.22, Vector3(0.2, 0.68, 0.1), _material(Color(0.675, 0.466, 0.362, 1)))
	_box(rack, "FoldedTowel", Vector3(0.3, 0.12, 0.4), Vector3(0.2, 1.36, 0.3), _material(Color(0.85, 0.85, 0.9, 1)))


func _build_bathroom_door(world_position: Vector3) -> void:
	# Hinged at the left jamb of the doorway opening. Rests at a small ajar
	# crack by default; SPACE swings it fully open/closed (handled by
	# DirtyDoorScript, which also owns the dust-wipe interaction on E).
	var hinge := Node3D.new()
	hinge.name = "BathroomDoorHinge"
	hinge.position = Vector3(world_position.x - 0.55, 0.0, world_position.z)
	hinge.rotation_degrees.y = -6.0
	add_child(hinge)

	var door := StaticBody3D.new()
	door.name = "BathroomDoor"
	door.position = Vector3(0.55, 0.0, 0.0)
	door.set_script(DirtyDoorScript)
	door.add_to_group("interactable")
	door.add_to_group("bathroom_door")
	hinge.add_child(door)

	var door_material := _material(Color(0.28, 0.16, 0.08, 1))
	var panel_material := _material(Color(0.34, 0.19, 0.09, 1))
	var handle_material := _material(Color(0.495, 0.469, 0.391, 1), Color(0.1, 0.09, 0.05, 1), 0.15)
	# Sized up from the previous pass, but still a touch smaller than a
	# regular interior door - matching how bathroom doors are usually built.
	_box(door, "DoorSlab", Vector3(1.05, 2.05, 0.05), Vector3(0, 1.025, 0), door_material)
	_box(door, "PanelTop", Vector3(0.78, 0.78, 0.015), Vector3(0, 1.46, 0.033), panel_material)
	_box(door, "PanelBottom", Vector3(0.78, 0.68, 0.015), Vector3(0, 0.56, 0.033), panel_material)
	_cylinder(door, "Handle", 0.028, 0.16, Vector3(0.44, 1.025, 0.05), handle_material).rotation_degrees.x = 90.0

	var dust_material := StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.albedo_color = Color(0.42, 0.34, 0.18, 0.55)
	dust_material.roughness = 1.0
	_box(door, "DirtLayer", Vector3(0.85, 1.7, 0.02), Vector3(0, 1.025, 0.045), dust_material)
	for index in range(3):
		var smudge := _box(door, "DirtSmudge%d" % index, Vector3(0.6 - index * 0.08, 0.18, 0.015), Vector3(0, 1.65 - index * 0.42, 0.05), dust_material)
		smudge.rotation_degrees.z = -6.0 + index * 5.0

	_add_body_collision(door, Vector3(1.1, 2.05, 0.4), Vector3(0, 1.025, 0))


func _build_bathroom_pipe(parent: Node3D) -> void:
	# A leaking wall pipe mounted along the right wall, near the bathtub -
	# reuses the same rotate-to-connect puzzle as the main-room pipeline,
	# with its own task_kind so it's tracked as part of the washroom tasks.
	# No extra decorative ring/porthole is added next to it.
	var pipe := StaticBody3D.new()
	pipe.name = "BathroomPipe"
	pipe.position = Vector3(9.3, 1.45, -5.7)
	pipe.set_script(PipelineTaskScript)
	pipe.set("task_kind", "bathroom_pipe")
	pipe.add_to_group("interactable")
	pipe.add_to_group("repair_task")
	var metal := _material(Color(0.62, 0.68, 0.73, 1))
	var rust := _material(Color(0.648, 0.377, 0.314, 1), Color(0.32, 0.03, 0.01, 1), 0.35)
	_cylinder(pipe, "Pipe", 0.11, 3.25, Vector3.ZERO, metal).rotation_degrees.x = 90.0
	var back_joint := _torus(pipe, "PipeJointBack", 0.15, 0.035, Vector3(0, 0, -1.0), metal)
	back_joint.rotation_degrees.x = 90.0
	var front_joint := _torus(pipe, "PipeJointFront", 0.15, 0.035, Vector3(0, 0, 1.0), metal)
	front_joint.rotation_degrees.x = 90.0
	_cylinder(pipe, "Valve", 0.28, 0.12, Vector3(0, 0, 0.18), rust).rotation_degrees.x = 90.0
	_cylinder(pipe, "ValveStem", 0.05, 0.38, Vector3(0, 0.25, 0.18), rust)
	_torus(pipe, "ValveHandle", 0.2, 0.045, Vector3(0, 0.45, 0.18), rust)
	_box(pipe, "StatusLight", Vector3(0.12, 0.12, 0.12), Vector3(0, 0.18, 0), _material(Color(0.855, 0.49, 0.411, 1), Color(0.63, 0.285, 0.27, 1), 2.0))
	_add_body_collision(pipe, Vector3(0.3, 0.3, 3.1), Vector3.ZERO)
	var leak_collision := CollisionShape3D.new()
	var leak_shape := BoxShape3D.new()
	leak_shape.size = Vector3(0.9, 0.28, 0.9)
	leak_collision.position = Vector3(0.0, -1.3, 0.15)
	leak_collision.shape = leak_shape
	pipe.add_child(leak_collision)
	parent.add_child(pipe)


func _build_reference_game_props() -> void:
	_build_hanging_lamp(Vector3(0.0, 0.0, 0.0))
	_build_refrigerator()
	_build_rewire_panel(Vector3(-9.78, 2.2, -4.5))
	_build_wall_spotlights()


func _build_wall_spotlights() -> void:
	# These fixtures are visibly mounted from the start, but their bulbs and
	# spotlights stay dead until the electrical panel is repaired.
	_build_wall_spotlight("BackSpotlightLeft", Vector3(-7.2, 2.65, -9.72), Vector3(0, 180, 0))
	_build_wall_spotlight("BackSpotlightCenter", Vector3(-1.8, 2.65, -9.72), Vector3(0, 180, 0))
	_build_wall_spotlight("FrontSpotlightLeft", Vector3(-7.2, 2.65, 9.72), Vector3.ZERO)
	_build_wall_spotlight("FrontSpotlightRight", Vector3(7.2, 2.65, 9.72), Vector3.ZERO)


func _build_wall_spotlight(node_name: String, world_position: Vector3, world_rotation: Vector3) -> void:
	var root := _new_prop_root(node_name, world_position)
	root.rotation_degrees = world_rotation
	var bracket_material := _material(Color(0.1, 0.11, 0.14, 1))
	var dead_bulb_material := _material(Color(0.06, 0.065, 0.08, 1))
	_box(root, "WallMount", Vector3(0.52, 0.18, 0.16), Vector3(0, 0, 0.04), bracket_material)
	_box(root, "LampShade", Vector3(0.34, 0.24, 0.3), Vector3(0, -0.13, -0.12), bracket_material)
	var bulb := _sphere(root, "DeadBulb", 0.09, Vector3(0, -0.22, -0.25), dead_bulb_material)
	repair_bulbs.append(bulb)

	var spotlight := SpotLight3D.new()
	spotlight.name = "RepairSpotlight"
	spotlight.position = Vector3(0, -0.22, -0.28)
	spotlight.light_energy = 0.0
	spotlight.light_color = Color(1.0, 0.92, 0.78, 1)
	spotlight.spot_range = 8.0
	spotlight.spot_angle = 48.0
	spotlight.spot_attenuation = 1.35
	spotlight.shadow_enabled = true
	root.add_child(spotlight)
	repair_spotlights.append(spotlight)


func _build_hanging_lamp(world_position: Vector3) -> void:
	var root := _new_prop_root("HangingLamp", world_position)
	var cable := _material(Color(0.02, 0.025, 0.04, 1))
	var shade := _material(Color(0.34, 0.38, 0.48, 1))
	var bulb_material := _material(Color(0.9, 0.508, 0.472, 1), Color(0.9, 0.409, 0.388, 1), 3.0)
	_cylinder(root, "Cable", 0.035, 1.1, Vector3(0, 3.5, 0), cable)
	var shade_mesh := _cylinder(root, "Shade", 0.42, 0.24, Vector3(0, 2.92, 0), shade)
	# A shallow cone-like shade reads correctly from below without external assets.
	shade_mesh.scale = Vector3(1.0, 0.7, 1.0)
	_sphere(root, "RedBulb", 0.14, Vector3(0, 2.72, 0), bulb_material)
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "LampLight"
	lamp_light.position = Vector3(0, 2.7, 0)
	lamp_light.omni_range = 7.0
	lamp_light.light_energy = 1.15
	lamp_light.light_color = Color(1.0, 0.32, 0.25, 1)
	root.add_child(lamp_light)


func _build_refrigerator() -> void:
	# Spawns at the centre of the room. Carry it to the pink footprint
	# against the left wall; once it is placed the wall switch unlocks and
	# turns it on.
	var fridge := _new_furniture_item(
		"Fridge",
		"FRIDGE",
		Vector3(0.0, 0.0, 0.0),
		Vector3(-9.15, 0.0, -1.6),
		Vector3(2.35, 0.04, 1.55),
		Vector3(0.0, -90.0, 0.0),
		0.45,
		Vector3.ZERO,
		false,
		false
	)
	fridge.connect("placed", _on_fridge_placed)
	var body := _material(Color(0.55, 0.6, 0.67, 1))
	var door := _material(Color(0.68, 0.72, 0.78, 1))
	var handle := _material(Color(0.1, 0.12, 0.16, 1))
	_box(fridge, "FridgeBody", Vector3(2.15, 3.35, 1.35), Vector3(0, 1.68, 0), body)
	_box(fridge, "FreezerDoor", Vector3(1.95, 1.02, 0.06), Vector3(0, 2.72, -0.7), door)
	_box(fridge, "FridgeDoor", Vector3(1.95, 1.95, 0.06), Vector3(0, 1.2, -0.7), door)
	_box(fridge, "FreezerHandle", Vector3(0.08, 0.62, 0.08), Vector3(0.78, 2.72, -0.78), handle)
	_box(fridge, "FridgeHandle", Vector3(0.08, 1.2, 0.08), Vector3(0.78, 1.2, -0.78), handle)
	fridge_status_light = _box(fridge, "StatusLight", Vector3(0.12, 0.12, 0.06), Vector3(-0.72, 3.0, -0.78), _material(Color(0.35, 0.08, 0.06, 1), Color(0.35, 0.08, 0.06, 1), 1.0))
	_add_body_collision(fridge, Vector3(2.15, 3.35, 1.35), Vector3(0, 1.68, 0))

	# Child of the fridge so the glow travels with it when it is carried.
	fridge_interior_light = OmniLight3D.new()
	fridge_interior_light.name = "FridgeInteriorGlow"
	fridge_interior_light.position = Vector3(0, 1.5, -0.9)
	fridge_interior_light.omni_range = 2.2
	fridge_interior_light.light_energy = 0.0
	fridge_interior_light.light_color = Color(0.75, 0.9, 1.0, 1)
	fridge.add_child(fridge_interior_light)

	_build_fridge_wall_switch(Vector3(-9.88, 1.4, 0.0))


func _build_fridge_wall_switch(world_position: Vector3) -> void:
	# Flush on the left wall (inner face at x = -9.9), just beside the
	# fridge's pink footprint, facing into the room. Locked until the fridge
	# has been placed.
	fridge_switch = StaticBody3D.new()
	fridge_switch.name = "FridgeSwitch"
	fridge_switch.position = world_position
	fridge_switch.rotation_degrees.y = -90.0
	fridge_switch.scale = Vector3.ONE * 1.5
	fridge_switch.set_script(PowerSwitchScript)
	fridge_switch.set("label_text", "FRIDGE")
	fridge_switch.set("requires_unlock", true)
	fridge_switch.add_to_group("interactable")
	var plate := _material(Color(0.85, 0.85, 0.82, 1))
	_box(fridge_switch, "Plate", Vector3(0.22, 0.32, 0.04), Vector3.ZERO, plate)
	var lever := _box(fridge_switch, "Lever", Vector3(0.08, 0.14, 0.05), Vector3(0, 0.04, -0.03), _material(Color(0.1, 0.1, 0.12, 1)))
	lever.rotation_degrees.x = 30.0
	_sphere(fridge_switch, "Indicator", 0.03, Vector3(0, -0.11, -0.03), _material(Color(0.45, 0.231, 0.22, 1), Color(0.45, 0.231, 0.22, 1), 1.0))
	# Without a collision shape the interaction ray could never hit it.
	_add_body_collision(fridge_switch, Vector3(0.26, 0.36, 0.14), Vector3(0, 0, -0.03))
	fridge_switch.connect("toggled", _on_fridge_switch_toggled)
	add_child(fridge_switch)


func _build_rewire_panel(world_position: Vector3) -> void:
	var panel := StaticBody3D.new()
	panel.name = "RewirePanel"
	panel.position = world_position
	# Mounted on the left wall (mirrors the old right-wall mount), facing
	# into the room.
	panel.rotation_degrees.y = 90.0
	panel.set_script(RewireTaskScript)
	panel.set("task_kind", "panel")
	panel.add_to_group("interactable")
	panel.add_to_group("repair_task")

	# Soft cyan halo glowing out from behind the panel, matching the
	# reference. A big dim omni-light plus a translucent unshaded disc so
	# the glow reads even without bloom.
	var halo_light := OmniLight3D.new()
	halo_light.name = "HaloGlow"
	halo_light.position = Vector3(0, 0.25, 0.35)
	halo_light.omni_range = 4.5
	halo_light.light_energy = 2.0
	halo_light.light_color = Color(0.25, 0.85, 1.0, 1)
	panel.add_child(halo_light)

	var halo_material := _material(Color(0.26, 0.417, 0.495, 0.16), Color(0.482, 0.796, 0.9, 1), 1.4)
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var halo_disc := _cylinder(panel, "HaloDisc", 1.15, 0.01, Vector3(0, 0.05, 0.2), halo_material)
	halo_disc.rotation_degrees.x = 90.0

	var frame := _material(Color(0.03, 0.045, 0.075, 1))
	var panel_material := _material(Color(0.05, 0.07, 0.11, 1))
	_box(panel, "PanelFrame", Vector3(1.35, 1.95, 0.12), Vector3.ZERO, frame)
	_box(panel, "PanelFace", Vector3(1.05, 1.6, 0.05), Vector3(0, 0, -0.09), panel_material)

	# Colorful wire stubs poking out of the top and bottom edges at an
	# angle, each with a small dark "frayed" tip - broken until the panel
	# is repaired, at which point the fray caps hide and the wires glow
	# brighter, reading as freshly reconnected.
	var stub_colors: Array[Color] = [
		Color(0.4, 0.765, 0.765, 1),
		Color(0.627, 0.81, 0.445, 1),
		Color(0.9, 0.561, 0.769, 1),
		Color(0.855, 0.777, 0.437, 1)
	]
	var tilt_angles: Array[float] = [-22.0, -8.0, 8.0, 22.0]
	var fray_material := _material(Color(0.32, 0.22, 0.14, 1))

	for index in range(4):
		var stub_x := -0.4 + index * 0.27
		var tilt := tilt_angles[index]
		var top_color := stub_colors[index]
		var bottom_color := stub_colors[(index + 2) % stub_colors.size()]

		var top_rod := _cylinder(panel, "TopWire%d" % index, 0.035, 0.42, Vector3(stub_x, 0.95, -0.1), _material(top_color, top_color, 1.3))
		top_rod.rotation_degrees.z = tilt
		_sphere(panel, "TopFray%d" % index, 0.045, Vector3(stub_x + sin(deg_to_rad(tilt)) * 0.22, 1.16, -0.1), fray_material)

		var bottom_rod := _cylinder(panel, "BottomWire%d" % index, 0.035, 0.42, Vector3(stub_x, -0.95, -0.1), _material(bottom_color, bottom_color, 1.3))
		bottom_rod.rotation_degrees.z = -tilt
		_sphere(panel, "BottomFray%d" % index, 0.045, Vector3(stub_x - sin(deg_to_rad(tilt)) * 0.22, -1.16, -0.1), fray_material)

	# The glowing ring at the panel's center - dim amber while broken,
	# brightens to green once every wire is reconnected.
	var ring_material := _material(Color(0.54, 0.394, 0.253, 1), Color(0.9, 0.665, 0.43, 1), 1.6)
	var ring := _torus(panel, "CenterRing", 0.16, 0.11, Vector3(0, 0, -0.1), ring_material)
	ring.rotation_degrees.x = 90.0

	var ring_light := OmniLight3D.new()
	ring_light.name = "CenterRingLight"
	ring_light.position = Vector3(0, 0, 0.2)
	ring_light.omni_range = 2.2
	ring_light.light_energy = 1.1
	ring_light.light_color = Color(1.0, 0.6, 0.15, 1)
	panel.add_child(ring_light)

	_box(panel, "StatusLight", Vector3(0.12, 0.12, 0.06), Vector3(0.57, 0.45, -0.14), _material(Color(0.9, 0.456, 0.42, 1), Color(0.9, 0.456, 0.42, 1), 2.4))
	_add_body_collision(panel, Vector3(1.35, 1.95, 0.3), Vector3.ZERO)
	add_child(panel)


func _add_body_collision(body: StaticBody3D, size: Vector3, local_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.position = local_position
	collision.shape = shape
	body.add_child(collision)
func _unhandled_input(event: InputEvent) -> void:
	# Debug ending shortcuts. On laptops, hold the hardware Fn key so the
	# physical F1/F2/F3 keys are sent to Godot. These are the ONLY three
	# endings available for testing. There is deliberately no F4 ending.
	if not OS.is_debug_build() or game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = int(event.keycode if event.keycode != KEY_NONE else event.physical_keycode)
		match key:
			KEY_F1:
				_debug_force_ending(1)
			KEY_F2:
				_debug_force_ending(2)
			KEY_F3:
				_debug_force_ending(3)


func _debug_force_ending(ending_id: int) -> void:
	# F1: failed — no cleaning and no assets.
	# F2: cleaning complete — no assets collected.
	# F3: everything complete — assets collected and not caught.
	if ending_id < 1 or ending_id > 3:
		return

	# Set the exact state represented by the requested ending so the normal
	# ending transition and existing UI are reused without creating another UI.
	game_manager.set("diamond_taken", ending_id == 3)
	lockpick_done = 1 if ending_id == 3 else 0
	if suspicion_manager != null:
		suspicion_manager.call("reset_run")

	_finish_game(ending_id != 1, ending_id)


func _process(delta: float) -> void:
	ambience_time += delta
	_update_loitering(delta)

	if lights_fixed:
		# Wiring is repaired: lights stop flickering and hold a steady,
		# properly-lit glow instead.
		for index in range(ceiling_lights.size()):
			ceiling_lights[index].light_energy = light_base_energy[index] * FIXED_CEILING_ENERGY_MULTIPLIER
			var fixed_bulb_material := light_bulbs[index].material_override as StandardMaterial3D
			if fixed_bulb_material != null:
				fixed_bulb_material.emission_energy_multiplier = 2.6
			light_bulbs[index].visible = true
		for spotlight in repair_spotlights:
			spotlight.light_energy = FIXED_SPOT_ENERGY
		for fill in fill_lights:
			fill.light_energy = FIXED_FILL_ENERGY
		for bulb in repair_bulbs:
			bulb.visible = true
			var repaired_bulb_material := bulb.material_override as StandardMaterial3D
			if repaired_bulb_material != null:
				repaired_bulb_material.albedo_color = Color(1.0, 0.86, 0.55, 1)
				repaired_bulb_material.emission_enabled = true
				repaired_bulb_material.emission = Color(1.0, 0.62, 0.2, 1)
				repaired_bulb_material.emission_energy_multiplier = 3.0
		if world_environment.environment != null:
			world_environment.environment.ambient_light_energy = FIXED_AMBIENT_ENERGY
		directional_light.light_energy = FIXED_SUN_ENERGY
		return

	# Haunted-house flicker: each light stays on for a short stretch, then
	# snaps completely dark for a beat (not just dimmer - genuinely off,
	# energy 0), then back on, each on its own staggered schedule. Fixing
	# the wiring panel (above) is what stops this.
	for index in range(ceiling_lights.size()):
		if ambience_time >= light_next_change[index]:
			light_is_on[index] = not light_is_on[index]
			if light_is_on[index]:
				light_next_change[index] = ambience_time + randf_range(2.0, 4.5)
			else:
				light_next_change[index] = ambience_time + randf_range(0.2, 0.6)

		var energy := light_base_energy[index] if light_is_on[index] else 0.0
		ceiling_lights[index].light_energy = energy

		var bulb_material := light_bulbs[index].material_override as StandardMaterial3D
		if bulb_material != null:
			bulb_material.emission_energy_multiplier = 0.6 if light_is_on[index] else 0.0
		light_bulbs[index].visible = light_is_on[index]


func _refresh_hud() -> void:
	var rows: Array = []
	if task_active.get("dust", true):
		rows.append({"label": "DUSTING", "current": dust_cleaned, "total": 6, "color": "#e69089"})
	if task_active.get("panel_repair", true):
		rows.append({"label": "REWIRE PANEL", "current": panel_repaired, "total": 1, "color": "#89b8e6"})
	if task_active.get("fridge", true):
		rows.append({"label": "FRIDGE", "current": fridge_done, "total": 1, "color": "#89b8e6"})
	if task_active.get("furniture", true):
		rows.append({"label": "FURNITURE", "current": furniture_placed, "total": FURNITURE_TOTAL, "color": "#e69089"})
	if task_active.get("washroom", true):
		rows.append({"label": "WASHROOM", "current": _washroom_total(), "total": 3, "color": "#8bd8ae"})
	if task_active.get("lockpick", true):
		rows.append({"label": "LOCK-PICK DRAWER", "current": lockpick_done, "total": 1, "color": "#89b8e6"})
	if task_active.get("picture", true):
		rows.append({"label": "STRAIGHTEN PICTURE", "current": picture_done, "total": 1, "color": "#e69089"})
	if task_active.get("spill", true):
		rows.append({"label": "SCRUB SPILL", "current": spill_done, "total": 1, "color": "#8bd8ae"})
	if task_active.get("stain", true):
		rows.append({"label": "OLD STAIN", "current": stain_done, "total": 1, "color": "#8bd8ae"})
	hud.set_task_counts(rows)

	if _all_tasks_done():
		_finish_game(true)


func _washroom_total() -> int:
	return bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned


func _task_complete(id: String) -> bool:
	match id:
		"dust":
			return dust_cleaned >= 6
		"panel_repair":
			return panel_repaired >= 1
		"fridge":
			return fridge_done >= 1
		"furniture":
			return furniture_placed >= FURNITURE_TOTAL
		"washroom":
			return _washroom_total() >= 3
		"lockpick":
			return lockpick_done >= 1
		"picture":
			return picture_done >= 1
		"spill":
			return spill_done >= 1
		"stain":
			return stain_done >= 1
	return true


func _active_task_ids() -> Array:
	var ids: Array = []
	for id in task_active.keys():
		if task_active[id]:
			ids.append(id)
	return ids


func _all_tasks_done() -> bool:
	var active_ids := _active_task_ids()
	if active_ids.is_empty():
		return false
	for id in active_ids:
		if not _task_complete(id):
			return false
	return true


func _tasks_done_count() -> int:
	var count := 0
	for id in _active_task_ids():
		if _task_complete(id):
			count += 1
	return count


func _finish_game(tasks_finished: bool, forced_ending_id: int = 0) -> void:
	# Three endings only:
	# 1) Cleaning incomplete + spy assets not secured.
	# 2) Cleaning complete, but spy objective failed or the operation was compromised.
	# 3) Cleaning complete + required spy assets secured + player was never caught.
	if game_over:
		return
	if has_node("/root/EndingStateMachine") and bool(get_node("/root/EndingStateMachine").call("is_transitioning")):
		return

	game_over = true
	game_manager.set("is_running", false)

	var taken: bool = bool(game_manager.get("diamond_taken"))
	var assets_secured: bool = taken and lockpick_done >= 1
	var caught: bool = false
	if suspicion_manager != null:
		caught = float(suspicion_manager.get("current_suspicion")) >= 100.0

	var ending := forced_ending_id
	if ending == 0:
		if tasks_finished:
			ending = 3 if assets_secured and not caught else 2
		else:
			ending = 1

	GameFlow.ending_id = ending
	GameFlow.tasks_done = _tasks_done_count()
	GameFlow.tasks_total = _active_task_ids().size()
	GameFlow.seconds_left = int(ceil(float(game_manager.get("seconds_left"))))
	GameFlow.diamond_taken = taken

	if tasks_finished:
		hud.set_interaction_prompt("ALL TASKS COMPLETE")
		await get_tree().create_timer(1.6).timeout

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_layer.add_child(fade)
	add_child(fade_layer)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file(ENDING_SCENE_PATH)


func _on_dust_cleaned() -> void:
	dust_cleaned += 1
	_refresh_hud()


func _on_web_cleared() -> void:
	webs_cleared += 1
	_refresh_hud()


func _on_fridge_placed() -> void:
	if fridge_switch != null:
		fridge_switch.call("set_unlocked", true)


func _on_fridge_switch_toggled(is_on: bool) -> void:
	fridge_is_powered = is_on
	fridge_done = 1 if is_on else 0
	_refresh_hud()
	fridge_interior_light.light_energy = 1.1 if is_on else 0.0
	var status_material := fridge_status_light.material_override as StandardMaterial3D
	if status_material != null:
		var lit_color := Color(0.482, 0.9, 0.587, 1)
		var dead_color := Color(0.35, 0.08, 0.06, 1)
		status_material.albedo_color = lit_color if is_on else dead_color
		status_material.emission = lit_color if is_on else dead_color
		status_material.emission_energy_multiplier = 2.4 if is_on else 1.0


func _on_furniture_placed() -> void:
	furniture_placed = mini(furniture_placed + 1, FURNITURE_TOTAL)
	hud.mark_furniture_complete(furniture_placed, FURNITURE_TOTAL)
	_refresh_hud()


func _on_bathroom_mirror_cleaned() -> void:
	bathroom_mirrors_cleaned = 1
	_refresh_hud()


func _on_bathroom_door_cleaned() -> void:
	bathroom_door_cleaned = 1
	_refresh_hud()


func _on_repair_task_completed(task_kind: String) -> void:
	match task_kind:
		"panel":
			panel_repaired = 1
			lights_fixed = true
		"bathroom_pipe":
			bathroom_pipe_cleaned = 1
	_refresh_hud()


func _on_lockpick_unlocked(item_name: String) -> void:
	lockpick_done = 1
	hud.call("show_toast", "PENDRIVE COLLECTED")
	hud.call("add_collected_item", item_name)
	_refresh_hud()


func _on_picture_straightened(safe_code: String) -> void:
	picture_done = 1
	if wall_safe_node != null:
		wall_safe_node.call("set_code", safe_code)
	_refresh_hud()


func _on_spill_cleaned() -> void:
	spill_done = 1
	_refresh_hud()


func _on_stain_capped() -> void:
	stain_done = 1
	_refresh_hud()


func _on_time_expired() -> void:
	hud.set_time_expired()
	_finish_game(false)
	hud.set_interaction_prompt("TIME IS UP")


# --- Suspicion: lingering near restricted investigation spots ----------------

func _update_loitering(delta: float) -> void:
	if game_over or not bool(game_manager.get("is_running")):
		return
	var spot_id := _near_watch_spot_id()
	if spot_id.is_empty():
		loiter_time = 0.0
		loiter_warned = false
		loiter_spot_id = ""
		return

	if spot_id != loiter_spot_id:
		loiter_time = 0.0
		loiter_warned = false
		loiter_spot_id = spot_id

	loiter_time += delta
	if loiter_time < LOITER_GRACE_SECONDS:
		return

	if not loiter_warned:
		loiter_warned = true
		var inner_voice := get_node_or_null("/root/InnerVoiceManager")
		if inner_voice != null:
			var warning := "Lingering by the lockpick drawer. Keep moving before someone notices."
			if spot_id != "lockpick":
				warning = "Standing here too long. Someone is going to notice."
			inner_voice.call("queue_thought", "CAUTION", warning, 3.5)

	if suspicion_manager != null:
		suspicion_manager.call("add_suspicion", LOITER_SUSPICION_PER_SECOND * delta)


func _near_watch_spot_id() -> String:
	if _player_near_watch_node(lock_pick_drawer_node):
		return "lockpick"
	if _player_near_watch_node(chest_node):
		return "chest"
	if _player_near_watch_node(wall_safe_node):
		return "safe"
	return ""


func _player_near_watch_node(watch_node: Node3D) -> bool:
	if watch_node == null or not is_instance_valid(watch_node) or not watch_node.visible:
		return false
	# Flat (x/z) distance, so the player's height doesn't matter.
	var player_flat := Vector2(player.global_position.x, player.global_position.z)
	var spot_flat := Vector2(watch_node.global_position.x, watch_node.global_position.z)
	return player_flat.distance_to(spot_flat) <= LOITER_RADIUS


# --- Safe corner light ----------------------------------------------------

func _build_safe_corner_light() -> void:
	# A wall sconce right above the safe. It's not tied to the wiring, so the
	# corner is lit from the start.
	var root := _new_prop_root("SafeCornerLight", Vector3(-9.81, 2.95, -7.5))
	root.rotation_degrees.y = 90.0
	var fixture := _material(Color(0.15, 0.15, 0.17, 1))
	var bulb := _material(Color(1.0, 0.92, 0.72, 1), Color(0.9, 0.822, 0.665, 1), 2.5)
	_box(root, "SconceBody", Vector3(0.5, 0.22, 0.18), Vector3.ZERO, fixture)
	_sphere(root, "SconceBulb", 0.07, Vector3(0.0, -0.02, 0.1), bulb)

	var light := OmniLight3D.new()
	light.name = "SafeCornerGlow"
	light.position = Vector3(0.0, -0.1, 0.5)
	light.omni_range = 6.0
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.9, 0.7, 1)
	root.add_child(light)


# --- Fill lights -------------------------------------------------------------

func _build_fill_lights() -> void:
	# Soft lights spread around the room. They stay OFF while the wiring is
	# broken (the room is meant to feel gloomy) and switch on at full strength
	# once the panel is repaired (see _process).
	for fill_position in FILL_LIGHT_POSITIONS:
		var fill := OmniLight3D.new()
		fill.name = "FillLight"
		fill.position = fill_position
		fill.omni_range = 8.0
		fill.light_energy = 0.0
		fill.light_color = Color(1.0, 0.96, 0.88, 1)
		add_child(fill)
		fill_lights.append(fill)


# --- Safe feedback ---------------------------------------------------------

func _on_safe_opened() -> void:
	hud.call("show_toast", "FILE COLLECTED")
	hud.call("add_collected_item", "FILE")
