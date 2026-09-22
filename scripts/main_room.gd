extends Node3D

const DirtyMirrorScript = preload("res://scripts/dirty_mirror.gd")
const DirtyDoorScript = preload("res://scripts/dirty_door.gd")
const RepairTaskScript = preload("res://scripts/repair_task.gd")
const PipelineTaskScript = preload("res://scripts/pipeline_task.gd")

@onready var hud: CanvasLayer = $HUD
@onready var interaction_ray: RayCast3D = $Player/Head/Camera3D/InteractionRay
@onready var sofa: StaticBody3D = $Sofa
@onready var game_manager: Node = $GameManager

var dust_cleaned: int = 0
var webs_cleared: int = 0
var furniture_placed: int = 0
var bathroom_mirrors_cleaned: int = 0
var bathroom_door_cleaned: int = 0
var bathroom_pipe_cleaned: int = 0
var panel_repaired: int = 0
var fridge_cleaned: int = 0
var score: int = 50
var ambience_time: float = 0.0
var ceiling_lights: Array[OmniLight3D] = []
var light_bulbs: Array[MeshInstance3D] = []
var light_base_energy: Array[float] = [0.55, 0.5, 0.45, 0.5, 0.5, 0.45]
var light_is_on: Array[bool] = []
var light_next_change: Array[float] = []


func _ready() -> void:
	interaction_ray.target_changed.connect(hud.set_interaction_prompt)
	sofa.placed.connect(hud.mark_sofa_complete)
	sofa.placed.connect(_on_sofa_placed)

	game_manager.time_changed.connect(hud.set_timer)
	game_manager.time_expired.connect(_on_time_expired)
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

	ceiling_lights = [$CeilingLightLeft, $CeilingLightRight, $CeilingLightBack, $CeilingLightFrontLeft, $CeilingLightFrontRight, $CeilingLightCenter]
	light_bulbs = [$BlueBulb, $AmberBulb, $GreenBulb, $FrontLeftBulb, $FrontRightBulb, $CenterBulb]
	light_is_on.resize(ceiling_lights.size())
	light_is_on.fill(true)
	light_next_change.resize(ceiling_lights.size())
	for index in range(light_next_change.size()):
		light_next_change[index] = randf_range(2.0, 6.0)
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _build_floor_plan_props() -> void:
	# The floor-plan additions are built from simple meshes so the project has
	# no external asset dependencies and remains easy to edit in Godot.
	_add_front_wall()
	_build_mop_station(Vector3(-6.7, 0.0, -9.55))
	_build_rug(Vector3(0.0, 0.18, -6.6))
	_build_cabinet(Vector3(7.0, 0.0, 6.4))
	_build_tv(Vector3(0.0, 0.0, 9.78))
	_build_broken_floor(Vector3(-5.8, 0.0, 6.7))
	_build_bathroom()
	_build_reference_game_props()


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

	var wall_material := _material(Color(0.78, 0.74, 0.5, 1))
	_box(wall, "MeshInstance3D", Vector3(20.0, 4.0, 0.2), Vector3.ZERO, wall_material)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 4.0, 0.2)
	collision.shape = shape
	wall.add_child(collision)


func _build_mop_station(world_position: Vector3) -> void:
	var root := _new_prop_root("MopStation", world_position)
	var dark := _material(Color(0.06, 0.08, 0.13, 1))
	var metal := _material(Color(0.32, 0.39, 0.48, 1))
	var yellow := _material(Color(0.92, 0.61, 0.08, 1), Color(0.35, 0.17, 0.01, 1), 0.35)
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
	var inner := _material(Color(0.55, 0.18, 0.12, 1))
	_box(root, "RugBorder", Vector3(4.8, 0.06, 2.55), Vector3.ZERO, border)
	_box(root, "RugPattern", Vector3(4.35, 0.075, 2.1), Vector3(0, 0.035, 0), inner)
	for x in range(-2, 3):
		_box(root, "RugStripe%d" % x, Vector3(0.08, 0.02, 1.9), Vector3(x * 0.75, 0.09, 0), border)


func _build_cabinet(world_position: Vector3) -> void:
	var root := _new_prop_root("Cabinet", world_position)
	var wood := _material(Color(0.28, 0.12, 0.055, 1))
	var trim := _material(Color(0.56, 0.27, 0.09, 1))
	_box(root, "CabinetBody", Vector3(2.5, 2.2, 1.25), Vector3(0, 1.1, 0), wood)
	_box(root, "CabinetTop", Vector3(2.75, 0.14, 1.4), Vector3(0, 2.27, 0), trim)
	for row in range(2):
		for column in range(2):
			var drawer := _box(root, "Drawer%d%d" % [row, column], Vector3(1.0, 0.72, 0.05), Vector3(-0.55 + column * 1.1, 1.55 - row * 0.82, -0.65), trim)
			drawer.rotation_degrees.x = -2.0
			_cylinder(root, "Handle%d%d" % [row, column], 0.05, 0.28, Vector3(-0.55 + column * 1.1, 1.55 - row * 0.82, -0.74), wood).rotation_degrees = Vector3(90, 0, 0)


func _build_tv(world_position: Vector3) -> void:
	var root := _new_prop_root("TV", world_position)
	var stand := _material(Color(0.035, 0.04, 0.055, 1))
	var screen := _material(Color(0.025, 0.12, 0.19, 1), Color(0.01, 0.13, 0.23, 1), 1.2)
	_box(root, "TVStand", Vector3(4.8, 0.18, 0.9), Vector3(0, 0.35, 0), stand)
	_box(root, "TVStem", Vector3(0.18, 0.75, 0.18), Vector3(0, 0.8, 0), stand)
	_box(root, "TVFrame", Vector3(4.7, 2.5, 0.18), Vector3(0, 2.1, 0), stand)
	_box(root, "TVScreen", Vector3(4.35, 2.15, 0.035), Vector3(0, 2.1, -0.11), screen)
	for index in range(4):
		_box(root, "TVGlow%d" % index, Vector3(0.05, 1.65, 0.012), Vector3(-1.5 + index * 1.0, 2.1, -0.135), _material(Color(0.1, 0.45, 0.62, 1), Color(0.02, 0.2, 0.4, 1), 1.0))


func _build_broken_floor(world_position: Vector3) -> void:
	var root := _new_prop_root("BrokenFloorArea", world_position)
	var hole := _material(Color(0.018, 0.02, 0.026, 1))
	var broken_wood := _material(Color(0.2, 0.075, 0.025, 1))
	_box(root, "DarkOpening", Vector3(3.1, 0.035, 2.8), Vector3.ZERO, hole)
	for index in range(7):
		var plank := _box(root, "BrokenPlank%d" % index, Vector3(0.75, 0.07, 0.22), Vector3(-1.25 + (index % 4) * 0.8, 0.07, -0.95 + (index / 4) * 1.8), broken_wood)
		plank.rotation_degrees.y = -18.0 + index * 11.0
		plank.rotation_degrees.z = -7.0 + index * 4.0


func _build_bathroom() -> void:
	var wall_material := _material(Color(0.75, 0.71, 0.48, 1))
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
	var rack := _new_prop_root("StorageRack", Vector3(3.42, 0.0, -5.15))
	parent.add_child(rack)
	var wood := _material(Color(0.32, 0.16, 0.07, 1))
	var metal := _material(Color(0.4, 0.46, 0.52, 1), Color(0.05, 0.06, 0.08, 1), 0.15)
	_box(rack, "BackPanel", Vector3(0.04, 1.9, 1.3), Vector3(0, 1.3, 0), wood)
	for index in range(3):
		var shelf_y := 0.55 + index * 0.62
		_box(rack, "Shelf%d" % index, Vector3(0.36, 0.05, 1.2), Vector3(0.2, shelf_y, 0), wood)
		_box(rack, "BracketFront%d" % index, Vector3(0.36, 0.04, 0.04), Vector3(0.2, shelf_y - 0.02, -0.56), metal)
		_box(rack, "BracketBack%d" % index, Vector3(0.36, 0.04, 0.04), Vector3(0.2, shelf_y - 0.02, 0.56), metal)
	_cylinder(rack, "Bottle0", 0.07, 0.28, Vector3(0.2, 0.72, -0.35), _material(Color(0.15, 0.55, 0.55, 1)))
	_cylinder(rack, "Bottle1", 0.06, 0.22, Vector3(0.2, 0.68, 0.1), _material(Color(0.75, 0.35, 0.15, 1)))
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
	var handle_material := _material(Color(0.55, 0.5, 0.35, 1), Color(0.1, 0.09, 0.05, 1), 0.15)
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
	var rust := _material(Color(0.72, 0.2, 0.08, 1), Color(0.32, 0.03, 0.01, 1), 0.35)
	_cylinder(pipe, "Pipe", 0.11, 3.25, Vector3.ZERO, metal).rotation_degrees.x = 90.0
	var back_joint := _torus(pipe, "PipeJointBack", 0.15, 0.035, Vector3(0, 0, -1.0), metal)
	back_joint.rotation_degrees.x = 90.0
	var front_joint := _torus(pipe, "PipeJointFront", 0.15, 0.035, Vector3(0, 0, 1.0), metal)
	front_joint.rotation_degrees.x = 90.0
	_cylinder(pipe, "Valve", 0.28, 0.12, Vector3(0, 0, 0.18), rust).rotation_degrees.x = 90.0
	_cylinder(pipe, "ValveStem", 0.05, 0.38, Vector3(0, 0.25, 0.18), rust)
	_torus(pipe, "ValveHandle", 0.2, 0.045, Vector3(0, 0.45, 0.18), rust)
	_box(pipe, "StatusLight", Vector3(0.12, 0.12, 0.12), Vector3(0, 0.18, 0), _material(Color(0.95, 0.25, 0.1, 1), Color(0.7, 0.04, 0.01, 1), 2.0))
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
	_build_refrigerator(Vector3(-7.15, 0.0, -1.0))
	_build_rewire_panel(Vector3(-9.78, 2.2, -4.5))


func _build_hanging_lamp(world_position: Vector3) -> void:
	var root := _new_prop_root("HangingLamp", world_position)
	var cable := _material(Color(0.02, 0.025, 0.04, 1))
	var shade := _material(Color(0.34, 0.38, 0.48, 1))
	var bulb_material := _material(Color(1.0, 0.25, 0.18, 1), Color(1.0, 0.06, 0.02, 1), 3.0)
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


func _build_refrigerator(world_position: Vector3) -> void:
	var fridge := StaticBody3D.new()
	fridge.name = "Fridge"
	fridge.position = world_position
	fridge.set_script(RepairTaskScript)
	fridge.set("task_kind", "fridge")
	fridge.set("task_label", "CLEAN FRIDGE")
	fridge.set("action_label", "CLEAN FRIDGE")
	fridge.set("duration_seconds", 7.0)
	fridge.add_to_group("interactable")
	fridge.add_to_group("repair_task")
	var body := _material(Color(0.55, 0.6, 0.67, 1))
	var door := _material(Color(0.68, 0.72, 0.78, 1))
	var handle := _material(Color(0.1, 0.12, 0.16, 1))
	_box(fridge, "FridgeBody", Vector3(2.15, 3.35, 1.35), Vector3(0, 1.68, 0), body)
	_box(fridge, "FreezerDoor", Vector3(1.95, 1.02, 0.06), Vector3(0, 2.72, -0.7), door)
	_box(fridge, "FridgeDoor", Vector3(1.95, 1.95, 0.06), Vector3(0, 1.2, -0.7), door)
	_box(fridge, "FreezerHandle", Vector3(0.08, 0.62, 0.08), Vector3(0.78, 2.72, -0.78), handle)
	_box(fridge, "FridgeHandle", Vector3(0.08, 1.2, 0.08), Vector3(0.78, 1.2, -0.78), handle)
	_box(fridge, "StatusLight", Vector3(0.12, 0.12, 0.06), Vector3(-0.72, 3.0, -0.78), _material(Color(0.95, 0.2, 0.12, 1), Color(0.8, 0.04, 0.02, 1), 2.5))
	_add_body_collision(fridge, Vector3(2.15, 3.35, 1.35), Vector3(0, 1.68, 0))
	add_child(fridge)


func _build_rewire_panel(world_position: Vector3) -> void:
	var panel := StaticBody3D.new()
	panel.name = "RewirePanel"
	panel.position = world_position
	# Mounted on the left wall (mirrors the old right-wall mount), facing
	# into the room.
	panel.rotation_degrees.y = 90.0
	panel.set_script(RepairTaskScript)
	panel.set("task_kind", "panel")
	panel.set("task_label", "REWIRE PANEL")
	panel.set("action_label", "FIX THE WIRING")
	panel.set("duration_seconds", 6.0)
	panel.add_to_group("interactable")
	panel.add_to_group("repair_task")
	var frame := _material(Color(0.03, 0.045, 0.075, 1))
	var panel_material := _material(Color(0.05, 0.07, 0.11, 1))
	_box(panel, "PanelFrame", Vector3(1.35, 1.95, 0.12), Vector3.ZERO, frame)
	_box(panel, "PanelFace", Vector3(1.05, 1.6, 0.05), Vector3(0, 0, -0.09), panel_material)

	# Colorful wire stubs poking out of the top and bottom edges, like the
	# reference image - purely visual for now (the drag-to-reconnect
	# mechanic is a separate, bigger build).
	var stub_colors: Array[Color] = [
		Color(0.15, 0.85, 0.85, 1),
		Color(0.55, 0.9, 0.2, 1),
		Color(1.0, 0.35, 0.75, 1),
		Color(0.95, 0.8, 0.15, 1)
	]
	for index in range(4):
		var stub_x := -0.4 + index * 0.27
		var top_color := stub_colors[index]
		var bottom_color := stub_colors[(index + 2) % stub_colors.size()]
		_box(panel, "TopWire%d" % index, Vector3(0.05, 0.34, 0.05), Vector3(stub_x, 0.97, -0.1), _material(top_color, top_color, 1.2))
		_box(panel, "BottomWire%d" % index, Vector3(0.05, 0.34, 0.05), Vector3(stub_x, -0.97, -0.1), _material(bottom_color, bottom_color, 1.2))

	# The soft cyan glow floating above the panel, matching the reference.
	var glow_light := OmniLight3D.new()
	glow_light.name = "PanelGlow"
	glow_light.position = Vector3(0, 1.55, 0.3)
	glow_light.omni_range = 3.0
	glow_light.light_energy = 1.3
	glow_light.light_color = Color(0.25, 0.85, 1.0, 1)
	panel.add_child(glow_light)
	_sphere(panel, "GlowOrb", 0.12, Vector3(0, 1.55, 0.3), _material(Color(0.4, 0.9, 1.0, 1), Color(0.4, 0.9, 1.0, 1), 3.0))

	_box(panel, "StatusLight", Vector3(0.12, 0.12, 0.06), Vector3(0.57, 0.45, -0.14), _material(Color(1.0, 0.15, 0.08, 1), Color(1.0, 0.15, 0.08, 1), 2.4))
	_add_body_collision(panel, Vector3(1.35, 1.95, 0.3), Vector3.ZERO)
	add_child(panel)


func _add_body_collision(body: StaticBody3D, size: Vector3, local_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.position = local_position
	collision.shape = shape
	body.add_child(collision)
func _process(delta: float) -> void:
	ambience_time += delta
	# Haunted-house flicker: each light stays fully on for a stretch, then
	# snaps completely dark for a short beat (not just dimmer - genuinely
	# off, energy 0), then back on, each on its own staggered schedule.
	for index in range(ceiling_lights.size()):
		if ambience_time >= light_next_change[index]:
			light_is_on[index] = not light_is_on[index]
			if light_is_on[index]:
				light_next_change[index] = ambience_time + randf_range(5.0, 10.0)
			else:
				light_next_change[index] = ambience_time + randf_range(0.4, 1.1)

		var energy := light_base_energy[index] if light_is_on[index] else 0.0
		ceiling_lights[index].light_energy = energy

		var bulb_material := light_bulbs[index].material_override as StandardMaterial3D
		if bulb_material != null:
			bulb_material.emission_energy_multiplier = 1.1 if light_is_on[index] else 0.0
		light_bulbs[index].visible = light_is_on[index]


func _on_dust_cleaned() -> void:
	dust_cleaned += 1
	score += 5
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _on_web_cleared() -> void:
	webs_cleared += 1
	score += 5
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _on_sofa_placed() -> void:
	furniture_placed = 1
	score += 10
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _on_bathroom_mirror_cleaned() -> void:
	bathroom_mirrors_cleaned = 1
	score += 10
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _on_bathroom_door_cleaned() -> void:
	bathroom_door_cleaned = 1
	score += 10
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _on_repair_task_completed(task_kind: String) -> void:
	match task_kind:
		"panel":
			panel_repaired = 1
		"fridge":
			fridge_cleaned = 1
		"bathroom_pipe":
			bathroom_pipe_cleaned = 1
	score += 10
	hud.set_task_counts(dust_cleaned, webs_cleared, furniture_placed, bathroom_mirrors_cleaned + bathroom_door_cleaned + bathroom_pipe_cleaned, panel_repaired, fridge_cleaned)
	hud.set_score(score)


func _on_time_expired() -> void:
	hud.set_time_expired()
	hud.set_interaction_prompt("TIME IS UP")