extends StaticBody3D

const TILE_COLUMNS := 40
const TILE_ROWS := 20
const TILE_WIDTH := 0.47
const TILE_DEPTH := 0.96
const COLUMN_STEP := 0.5
const ROW_STEP := 1.0
const BATHROOM_MIN_X := 3.2
const BATHROOM_MAX_X := 9.6
const BATHROOM_MIN_Z := -9.65
const BATHROOM_MAX_Z := -3.55


func _ready() -> void:
	var base_floor := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if base_floor == null:
		return

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(TILE_WIDTH, 0.045, TILE_DEPTH)

	var wood_materials: Array[StandardMaterial3D] = []
	for color in [
		Color(0.3, 0.14, 0.045, 1),
		Color(0.4, 0.2, 0.07, 1),
		Color(0.24, 0.095, 0.028, 1),
		Color(0.34, 0.16, 0.05, 1)
	]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.82
		wood_materials.append(material)

	for x in range(TILE_COLUMNS):
		for z in range(TILE_ROWS):
			var tile_position := Vector3(
				-9.75 + x * COLUMN_STEP,
				0.125,
				-9.5 + z * ROW_STEP
			)
			# Leave the bathroom footprint to its own tile set so the two
			# materials do not occupy the same surface. A plank is nearly as
			# deep/wide as its own grid step, so checking only the center
			# point let planks whose center sat just outside the boundary
			# still physically overlap into the bathroom by up to half a
			# tile. This checks each plank's full edge-to-edge extent
			# against the bathroom's wall footprint instead, so a plank is
			# skipped the moment any part of it would overlap.
			var tile_min_x := tile_position.x - TILE_WIDTH * 0.5
			var tile_max_x := tile_position.x + TILE_WIDTH * 0.5
			var tile_min_z := tile_position.z - TILE_DEPTH * 0.5
			var tile_max_z := tile_position.z + TILE_DEPTH * 0.5
			if (
				tile_max_x >= BATHROOM_MIN_X
				and tile_min_x <= BATHROOM_MAX_X
				and tile_max_z >= BATHROOM_MIN_Z
				and tile_min_z <= BATHROOM_MAX_Z
			):
				continue
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.material_override = wood_materials[(x * 3 + z * 5) % wood_materials.size()]
			tile.position = tile_position
			tile.rotation.y = deg_to_rad(((x + z) % 2) * 0.7)
			add_child(tile)