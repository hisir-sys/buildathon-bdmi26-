extends Node3D
# Procedural vintage study used behind the start menu and the four ending
# screens. Call build(config) once after adding it to the tree.
#
# config keys (all optional):
#   lamp_on, spot_energy, spot_angle, fill_energy, ambient_color,
#   ambient_energy, fog_color, fog_density, window_color, moon_energy,
#   accent_color, accent_energy, desk (Array of "chest"/"scroll"/"diamond"),
#   cam_pos, cam_target, fov

var rng := RandomNumberGenerator.new()
var camera: Camera3D
var cam_base: Vector3 = Vector3(0, 1.5, 2.6)
var cam_target: Vector3 = Vector3(0, 0.8, -2.0)
var sway_time: float = 0.0
var diamond_node: Node3D


func build(config: Dictionary) -> void:
	rng.seed = 7
	_build_environment(config)
	_build_room()
	_build_bookshelf(-3.7)
	_build_bookshelf(3.7)
	_build_window(config)
	_build_desk()
	_build_lamp(config)
	_build_desk_items(config)
	_build_dust(config)
	_build_accent(config)
	_build_camera(config)


func _process(delta: float) -> void:
	sway_time += delta
	if diamond_node != null:
		diamond_node.rotate_y(delta * 0.8)
	if camera == null:
		return
	# Slow handheld-style drift plus a gentle push-in.
	var drift := Vector3(sin(sway_time * 0.25) * 0.22, sin(sway_time * 0.19) * 0.05, -minf(sway_time * 0.03, 0.7))
	camera.position = cam_base + drift
	camera.look_at(cam_target, Vector3.UP)


# --- helpers ---------------------------------------------------------------

func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0, emission: Color = Color(0, 0, 0, 1), energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _cyl(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, material: Material, segments: int = 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
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


# --- scene -----------------------------------------------------------------

func _build_environment(config: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = config.get("ambient_color", Color(0.3, 0.35, 0.5, 1))
	env.ambient_light_energy = config.get("ambient_energy", 0.3)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = config.get("fog_color", Color(0.06, 0.08, 0.12, 1))
	env.fog_density = config.get("fog_density", 0.03)
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_room() -> void:
	var wall := _mat(Color(0.16, 0.075, 0.085, 1), 0.9)
	var wood := _mat(Color(0.08, 0.045, 0.028, 1), 0.5)
	var dark := _mat(Color(0.04, 0.03, 0.03, 1), 0.9)
	_box(self, Vector3(12, 0.2, 10), Vector3(0, -0.1, -0.5), wood)
	_box(self, Vector3(12, 5, 0.2), Vector3(0, 2.5, -3.1), wall)
	_box(self, Vector3(0.2, 5, 10), Vector3(-6, 2.5, -0.5), wall)
	_box(self, Vector3(0.2, 5, 10), Vector3(6, 2.5, -0.5), wall)
	_box(self, Vector3(12, 0.2, 10), Vector3(0, 5.1, -0.5), dark)
	_box(self, Vector3(12, 1.2, 0.08), Vector3(0, 0.6, -2.96), wood)
	_box(self, Vector3(12, 0.15, 0.12), Vector3(0, 4.6, -2.96), wood)
	_box(self, Vector3(4.4, 0.03, 3.2), Vector3(0, 0.02, -0.8), _mat(Color(0.27, 0.05, 0.07, 1), 1.0))
	_box(self, Vector3(4.0, 0.035, 2.8), Vector3(0, 0.025, -0.8), _mat(Color(0.18, 0.035, 0.05, 1), 1.0))


func _build_bookshelf(center_x: float) -> void:
	var wood := _mat(Color(0.12, 0.06, 0.03, 1), 0.7)
	var palette: Array[StandardMaterial3D] = [
		_mat(Color(0.35, 0.08, 0.08, 1), 0.85),
		_mat(Color(0.08, 0.2, 0.14, 1), 0.85),
		_mat(Color(0.12, 0.14, 0.3, 1), 0.85),
		_mat(Color(0.4, 0.28, 0.1, 1), 0.85),
		_mat(Color(0.22, 0.14, 0.08, 1), 0.85),
		_mat(Color(0.3, 0.3, 0.26, 1), 0.85),
	]
	var root := Node3D.new()
	root.position = Vector3(center_x, 0, -2.75)
	add_child(root)
	_box(root, Vector3(0.08, 3.4, 0.5), Vector3(-1.15, 1.7, 0), wood)
	_box(root, Vector3(0.08, 3.4, 0.5), Vector3(1.15, 1.7, 0), wood)
	_box(root, Vector3(2.38, 0.1, 0.5), Vector3(0, 3.4, 0), wood)
	_box(root, Vector3(2.3, 3.4, 0.04), Vector3(0, 1.7, -0.23), wood)
	for row in range(5):
		var shelf_y := 0.25 + row * 0.66
		_box(root, Vector3(2.3, 0.05, 0.46), Vector3(0, shelf_y, 0), wood)
		if row == 4:
			continue
		var x := -1.06
		while x < 1.0:
			if rng.randf() < 0.07:
				x += rng.randf_range(0.1, 0.25)
				continue
			var width := rng.randf_range(0.05, 0.11)
			var height := rng.randf_range(0.34, 0.56)
			_box(root, Vector3(width, height, 0.28), Vector3(x + width * 0.5, shelf_y + 0.025 + height * 0.5, 0.04), palette[rng.randi() % palette.size()])
			x += width + 0.008


func _build_window(config: Dictionary) -> void:
	var glass_color: Color = config.get("window_color", Color(0.523, 0.601, 0.81, 1))
	var glass := _mat(Color(glass_color.r * 0.5, glass_color.g * 0.5, glass_color.b * 0.5, 1), 0.3, 0.0, glass_color, 1.4)
	var frame := _mat(Color(0.05, 0.03, 0.02, 1), 0.6)
	_box(self, Vector3(1.5, 1.9, 0.04), Vector3(0, 2.7, -2.98), glass)
	_box(self, Vector3(0.06, 1.98, 0.07), Vector3(0, 2.7, -2.94), frame)
	_box(self, Vector3(1.58, 0.06, 0.07), Vector3(0, 2.7, -2.94), frame)
	_box(self, Vector3(1.58, 0.07, 0.08), Vector3(0, 3.68, -2.94), frame)
	_box(self, Vector3(1.58, 0.07, 0.08), Vector3(0, 1.72, -2.94), frame)
	_box(self, Vector3(0.07, 1.98, 0.08), Vector3(-0.79, 2.7, -2.94), frame)
	_box(self, Vector3(0.07, 1.98, 0.08), Vector3(0.79, 2.7, -2.94), frame)

	var moon := SpotLight3D.new()
	moon.position = Vector3(0, 3.0, -2.7)
	moon.spot_range = 7.0
	moon.spot_angle = 42.0
	moon.light_energy = config.get("moon_energy", 1.5)
	moon.light_color = glass_color
	add_child(moon)
	moon.look_at(Vector3(0, 0.9, -1.4), Vector3.UP)


func _build_desk() -> void:
	var walnut := _mat(Color(0.2, 0.1, 0.05, 1), 0.55)
	var trim := _mat(Color(0.3, 0.16, 0.08, 1), 0.5)
	var leather := _mat(Color(0.05, 0.16, 0.11, 1), 0.7)
	_box(self, Vector3(3.0, 0.12, 1.4), Vector3(0, 0.9, -2.0), walnut)
	_box(self, Vector3(3.08, 0.05, 1.48), Vector3(0, 0.82, -2.0), trim)
	_box(self, Vector3(3.0, 0.7, 0.06), Vector3(0, 0.45, -1.33), walnut)
	for x_pos in [-1.4, 1.4]:
		for z_pos in [-2.6, -1.4]:
			_box(self, Vector3(0.14, 0.85, 0.14), Vector3(x_pos, 0.42, z_pos), walnut)
	_box(self, Vector3(1.7, 0.02, 0.85), Vector3(0, 0.97, -1.9), leather)


func _build_lamp(config: Dictionary) -> void:
	var lamp_on: bool = config.get("lamp_on", true)
	var brass := _mat(Color(0.62, 0.48, 0.16, 1), 0.35, 0.85)
	var shade_material: StandardMaterial3D
	var bulb_material: StandardMaterial3D
	if lamp_on:
		shade_material = _mat(Color(0.9, 0.62, 0.22, 1), 0.6, 0.0, Color(1.0, 0.6, 0.15, 1), 1.2)
		bulb_material = _mat(Color(1.0, 0.9, 0.6, 1), 0.5, 0.0, Color(1.0, 0.75, 0.3, 1), 3.5)
	else:
		shade_material = _mat(Color(0.28, 0.2, 0.1, 1), 0.7)
		bulb_material = _mat(Color(0.25, 0.24, 0.22, 1), 0.4)

	var lamp := Node3D.new()
	lamp.position = Vector3(-1.05, 0.98, -2.15)
	add_child(lamp)
	_cyl(lamp, 0.13, 0.16, 0.06, Vector3(0, 0.03, 0), brass, 18)
	_cyl(lamp, 0.022, 0.022, 0.4, Vector3(0, 0.26, 0), brass, 10)
	_cyl(lamp, 0.09, 0.22, 0.24, Vector3(0, 0.56, 0), shade_material, 18)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	bulb.mesh = sphere
	bulb.material_override = bulb_material
	bulb.position = Vector3(0, 0.47, 0)
	lamp.add_child(bulb)

	if not lamp_on:
		return

	var pool := SpotLight3D.new()
	pool.position = Vector3(-1.05, 1.5, -2.15)
	pool.spot_range = 6.0
	pool.spot_angle = config.get("spot_angle", 40.0)
	pool.spot_attenuation = 1.0
	pool.light_energy = config.get("spot_energy", 10.0)
	pool.light_color = Color(1.0, 0.82, 0.5, 1)
	pool.shadow_enabled = true
	add_child(pool)
	pool.look_at(Vector3(0.05, 0.98, -1.95), Vector3.UP)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.05, 1.5, -2.0)
	fill.omni_range = 5.0
	fill.light_energy = config.get("fill_energy", 0.5)
	fill.light_color = Color(1.0, 0.75, 0.42, 1)
	add_child(fill)

	# Faint cone of light under the shade - a cheap stand-in for volumetric fog
	# (the Compatibility renderer has none).
	var shaft_material := StandardMaterial3D.new()
	shaft_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft_material.albedo_color = Color(1.0, 0.8, 0.5, 0.07)
	var spread := 0.55 if float(config.get("spot_angle", 40.0)) < 30.0 else 0.95
	_cyl(self, 0.12, spread, 0.95, Vector3(-1.05, 1.02, -2.15), shaft_material, 24)


func _build_desk_items(config: Dictionary) -> void:
	var items: Array = config.get("desk", [])
	if items.has("chest"):
		_build_chest(Vector3(0.1, 0.98, -2.05))
	if items.has("scroll"):
		var parchment := _mat(Color(0.86, 0.78, 0.58, 1), 0.85)
		var ribbon := _mat(Color(0.6, 0.08, 0.08, 1), 0.85)
		var scroll := Node3D.new()
		scroll.position = Vector3(0.95, 1.02, -1.7)
		scroll.rotation_degrees.y = 24.0
		add_child(scroll)
		_cyl(scroll, 0.045, 0.045, 0.42, Vector3.ZERO, parchment, 14).rotation_degrees.z = 90.0
		_cyl(scroll, 0.05, 0.05, 0.04, Vector3.ZERO, ribbon, 14).rotation_degrees.z = 90.0
	if items.has("diamond"):
		_build_diamond(Vector3(0.05, 0.98, -1.95))


func _build_chest(base: Vector3) -> void:
	var wood := _mat(Color(0.34, 0.17, 0.07, 1), 0.65)
	var iron := _mat(Color(0.1, 0.1, 0.12, 1), 0.5, 0.8)
	var brass := _mat(Color(0.62, 0.48, 0.16, 1), 0.35, 0.85)
	var chest := Node3D.new()
	chest.position = base
	add_child(chest)
	_box(chest, Vector3(1.1, 0.5, 0.7), Vector3(0, 0.25, 0), wood)
	_box(chest, Vector3(1.14, 0.16, 0.74), Vector3(0, 0.58, 0), wood)
	_box(chest, Vector3(1.06, 0.06, 0.66), Vector3(0, 0.69, 0), wood)
	for x_pos in [-0.34, 0.34]:
		_box(chest, Vector3(0.09, 0.5, 0.72), Vector3(x_pos, 0.25, 0), iron)
		_box(chest, Vector3(0.09, 0.2, 0.76), Vector3(x_pos, 0.6, 0), iron)
	_box(chest, Vector3(0.16, 0.26, 0.03), Vector3(0, 0.5, 0.38), iron)
	_box(chest, Vector3(0.14, 0.16, 0.07), Vector3(0, 0.42, 0.42), brass)


func _build_diamond(base: Vector3) -> void:
	var velvet := _mat(Color(0.45, 0.05, 0.09, 1), 1.0)
	var crystal := _mat(Color(0.75, 0.95, 1.0, 0.78), 0.05, 0.3, Color(0.5, 0.85, 1.0, 1), 1.8)
	_box(self, Vector3(0.5, 0.08, 0.35), base + Vector3(0, 0.04, 0), velvet)
	diamond_node = Node3D.new()
	diamond_node.position = base + Vector3(0, 0.3, 0)
	add_child(diamond_node)
	_cyl(diamond_node, 0.07, 0.14, 0.08, Vector3(0, 0.04, 0), crystal, 8)
	_cyl(diamond_node, 0.14, 0.0, 0.16, Vector3(0, -0.08, 0), crystal, 8)
	var glow := OmniLight3D.new()
	glow.position = base + Vector3(0, 0.45, 0)
	glow.omni_range = 2.4
	glow.light_energy = 1.4
	glow.light_color = Color(0.75, 0.9, 1.0, 1)
	add_child(glow)


func _build_dust(config: Dictionary) -> void:
	if not bool(config.get("lamp_on", true)):
		return
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.albedo_color = Color(1.0, 0.85, 0.6, 0.55)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	quad.material = mote_material

	var dust := CPUParticles3D.new()
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.5, 1.2, 1.8)
	dust.position = Vector3(0, 1.4, -1.0)
	dust.direction = Vector3(0.2, 0.4, 0.0)
	dust.spread = 180.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.08
	dust.mesh = quad
	add_child(dust)


func _build_accent(config: Dictionary) -> void:
	var energy: float = config.get("accent_energy", 0.0)
	if energy <= 0.0:
		return
	var accent := OmniLight3D.new()
	accent.position = Vector3(2.6, 1.6, -1.2)
	accent.omni_range = 6.0
	accent.light_energy = energy
	accent.light_color = config.get("accent_color", Color(0.6, 0.35, 0.95, 1))
	add_child(accent)


func _build_camera(config: Dictionary) -> void:
	cam_base = config.get("cam_pos", cam_base)
	cam_target = config.get("cam_target", cam_target)
	camera = Camera3D.new()
	camera.fov = config.get("fov", 42.0)
	add_child(camera)
	camera.position = cam_base
	camera.look_at(cam_target, Vector3.UP)
	camera.make_current()
