extends StaticBody3D

signal cleared

const CLEAN_TIME_SECONDS := 10.0

var is_cleared: bool = false
var is_cleaning: bool = false
var cleaning_elapsed: float = 0.0
var web_visual: MeshInstance3D
var web_threads: Array[MeshInstance3D] = []
var thread_material: StandardMaterial3D


func _ready() -> void:
	var placeholder := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if placeholder != null:
		placeholder.visible = false
	_create_corner_web()


func _process(delta: float) -> void:
	if not is_cleaning:
		return

	cleaning_elapsed = minf(CLEAN_TIME_SECONDS, cleaning_elapsed + delta)
	if web_visual != null:
		web_visual.transparency = cleaning_elapsed / CLEAN_TIME_SECONDS
	for thread in web_threads:
		thread.transparency = cleaning_elapsed / CLEAN_TIME_SECONDS

	if cleaning_elapsed >= CLEAN_TIME_SECONDS:
		is_cleared = true
		cleared.emit()
		queue_free()


func get_interaction_prompt() -> String:
	if is_cleared:
		return ""
	if is_cleaning:
		return "CLEARING WEB  %02d%%" % int((cleaning_elapsed / CLEAN_TIME_SECONDS) * 100.0)
	return "E  CLEAR SPIDER WEB  (10 SEC)" if _has_required_tool() else "REQUIRES MOP"


func interact() -> void:
	if is_cleared or is_cleaning or not _has_required_tool():
		return

	is_cleaning = true


func stop_interaction() -> void:
	if is_cleared:
		return
	is_cleaning = false


func _create_corner_web() -> void:
	var web_material := StandardMaterial3D.new()
	web_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web_material.albedo_color = Color(0.7, 0.78, 0.94, 0.56)
	web_material.emission_enabled = true
	web_material.emission = Color(0.12, 0.2, 0.38, 1)
	web_material.emission_energy_multiplier = 0.65
	web_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	web_material.no_depth_test = true
	thread_material = web_material

	var web_mesh := ImmediateMesh.new()
	web_mesh.surface_begin(Mesh.PRIMITIVE_LINES, web_material)

	var radius := 1.3
	var spoke_count := 9
	for spoke in range(spoke_count):
		var angle := (PI * 0.5) * float(spoke) / float(spoke_count - 1)
		var endpoint := Vector3(cos(angle) * radius, -sin(angle) * radius, 0.0)
		_add_line(web_mesh, Vector3.ZERO, endpoint)

	for ring_index in range(1, 5):
		var ring_radius := radius * float(ring_index) / 4.0
		for segment in range(spoke_count - 1):
			var angle_a := (PI * 0.5) * float(segment) / float(spoke_count - 1)
			var angle_b := (PI * 0.5) * float(segment + 1) / float(spoke_count - 1)
			var wobble_a := sin(float(segment + ring_index * 3)) * 0.035
			var wobble_b := sin(float(segment + 1 + ring_index * 3)) * 0.035
			var point_a := Vector3(cos(angle_a) * (ring_radius + wobble_a), -sin(angle_a) * (ring_radius + wobble_a), 0.0)
			var point_b := Vector3(cos(angle_b) * (ring_radius + wobble_b), -sin(angle_b) * (ring_radius + wobble_b), 0.0)
			_add_line(web_mesh, point_a, point_b)

	web_mesh.surface_end()
	web_visual = MeshInstance3D.new()
	web_visual.mesh = web_mesh
	web_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	web_visual.position = Vector3(0.0, 0.0, 0.015)
	add_child(web_visual)


func _add_line(mesh: ImmediateMesh, start: Vector3, end: Vector3) -> void:
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)

	var direction := end - start
	var thread := MeshInstance3D.new()
	var thread_mesh := CylinderMesh.new()
	thread_mesh.top_radius = 0.005
	thread_mesh.bottom_radius = 0.005
	thread_mesh.height = direction.length()
	thread_mesh.radial_segments = 6
	thread.mesh = thread_mesh
	thread.material_override = thread_material
	thread.position = (start + end) * 0.5 + Vector3(0.0, 0.0, 0.02)
	thread.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(thread)
	web_threads.append(thread)

func _has_required_tool() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and int(player.get("current_tool")) == 1
