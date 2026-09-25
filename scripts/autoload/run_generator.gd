extends Node
# RunGenerator - NOT an autoload.
#
# Unlike SuspicionManager / EndingStateMachine / InnerVoiceManager, this
# manager needs direct references to *this scene's* Marker3D key-spawn
# points, so it follows the same pattern the project already uses for
# scripts/game_manager.gd: a plain node placed as a child of
# main_room.tscn (e.g. named "RunGenerator"), not a global singleton.
#
# Task-pool selection is deliberately generic: it knows the 9 task IDs and
# picks which 4 to deactivate each run, but it does NOT touch the actual
# task nodes/systems itself. main_room.gd owns every one of those 9 systems
# (5 pre-existing multi-node systems like dust spots, plus the 4 new
# single-node tasks), so it's the only place with the references needed to
# actually apply a deactivation. Connect to `run_generated` (BEFORE
# add_child, see main_room.gd's _build_run_generator()) to receive the
# decision and apply it.
#
# Scene setup expected:
#   - 3 Marker3D nodes in the "key_spawn_point" group named
#     "KeySpawn_A" / "KeySpawn_B" / "KeySpawn_C" (names are just for
#     clarity - only group membership matters).
#   - A key/keypickup node assigned to `key_node` (falls back to searching
#     the "chest_key" group if left empty).
#
# Static vars mirror scripts/game_flow.gd's pattern so any task script can
# read the active modifier without needing a reference to this node:
#   const RunGenerator = preload("res://scripts/autoload/run_generator.gd")
#   var speed := RunGenerator.cleaning_speed_multiplier

signal run_generated(modifier_id: String, key_spawn_name: String, deactivated_task_ids: Array[String])

enum Modifier { SQUEAKY_SHOES, ERGONOMIC_MOP, HEAVY_LOCK }

const MODIFIER_NAMES := {
	Modifier.SQUEAKY_SHOES: "Squeaky Shoes",
	Modifier.ERGONOMIC_MOP: "Ergonomic Mop",
	Modifier.HEAVY_LOCK: "Heavy Lock",
}

# The full 9-task pool from the spec: the project's 5 pre-existing tasks
# plus the 4 new ones added by this update. 7 or 8 of the 9 (see
# ACTIVE_TASK_COUNT_MIN/MAX below) stay active each run; the rest are handed
# back as `deactivated_task_ids` for main_room.gd to switch off.
const TASK_IDS: Array[String] = [
	"dust", "panel_repair", "fridge", "furniture", "washroom",
	"lockpick", "picture", "spill", "stain",
]
# 10 minutes is tight, so most/all of the pool should be live each run rather
# than the original 5-of-9 split: each run now randomly leaves 7 OR 8 of the
# 9 tasks active (i.e. deactivates only 1 or 2), decided fresh every run.
const ACTIVE_TASK_COUNT_MIN := 7
const ACTIVE_TASK_COUNT_MAX := 8
const TASK_POOL_SIZE := 9

# Cross-script modifier state (see header). Reset every run by _ready().
static var current_modifier: int = Modifier.SQUEAKY_SHOES
static var suspicion_build_multiplier: float = 1.0   # Squeaky Shoes: x1.2
static var cleaning_speed_multiplier: float = 1.0     # Ergonomic Mop: x1.3
static var lockpick_cursor_multiplier: float = 1.0    # Heavy Lock: cursor speed up

@export var key_node: Node3D
@export var seed_override: int = -1  # -1 = random every run; set >=0 to reproduce a run for testing.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if seed_override >= 0:
		_rng.seed = seed_override
	else:
		_rng.randomize()

	var spawn_name := _spawn_key()
	var deactivated_ids := _select_deactivated_tasks()
	var modifier_id := _apply_modifier()

	run_generated.emit(modifier_id, spawn_name, deactivated_ids)


# --- Key spawning -----------------------------------------------------------

func _spawn_key() -> String:
	var spawn_points := get_tree().get_nodes_in_group("key_spawn_point")
	if spawn_points.is_empty():
		push_warning("RunGenerator: no Marker3D nodes in the 'key_spawn_point' group - key was not moved.")
		return ""

	var chosen: Node3D = spawn_points[_rng.randi_range(0, spawn_points.size() - 1)]

	var target := key_node
	if target == null:
		target = get_tree().get_first_node_in_group("chest_key") as Node3D
	if target == null:
		push_warning("RunGenerator: no key node found (assign `key_node` or add it to the 'chest_key' group).")
		return chosen.name

	target.global_position = chosen.global_position
	if "global_rotation" in target:
		target.global_rotation = chosen.global_rotation
	return chosen.name


# --- Task pool selection -----------------------------------------------------

## Returns the IDs of the tasks to deactivate this run (out of TASK_IDS' 9),
## leaving a randomly-chosen 7 OR 8 active (see ACTIVE_TASK_COUNT_MIN/MAX).
## Pure selection - no scene access here, see main_room.gd's
## _on_run_generated() for how each ID maps to an actual system getting
## switched off.
func _select_deactivated_tasks() -> Array[String]:
	var ids := TASK_IDS.duplicate()
	# Manual Fisher-Yates using this RunGenerator's own RNG (not the engine's
	# global RNG) so `seed_override` reliably reproduces the same run.
	for i in range(ids.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: String = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp

	var active_count: int = _rng.randi_range(ACTIVE_TASK_COUNT_MIN, ACTIVE_TASK_COUNT_MAX)
	var deactivate_count: int = maxi(0, TASK_POOL_SIZE - active_count)
	var deactivated: Array[String] = []
	for i in range(deactivate_count):
		deactivated.append(ids[i])
	return deactivated


## Convenience helper for the 4 new single-node tasks: hides, stops
## processing, and disables collision on `node`. main_room.gd's legacy
## 5 systems are multi-node/aggregate, so they aren't physically hidden by
## this - see INTEGRATION_GUIDE.md for why that's a deliberate, safer
## trade-off for this update rather than a gap.
static func apply_node_active(node: Node, active: bool) -> void:
	if node == null:
		return
	if node is CanvasItem or node is Node3D:
		node.set("visible", active)
	node.set_process(active)
	node.set_physics_process(active)
	if node.has_method("set_collision_layer_value"):
		node.call("set_collision_layer_value", 1, active)


# --- Run modifier -------------------------------------------------------------

func _apply_modifier() -> String:
	var modifier: int = _rng.randi_range(0, Modifier.size() - 1)
	current_modifier = modifier

	suspicion_build_multiplier = 1.0
	cleaning_speed_multiplier = 1.0
	lockpick_cursor_multiplier = 1.0

	match modifier:
		Modifier.SQUEAKY_SHOES:
			suspicion_build_multiplier = 1.2
			if has_node("/root/SuspicionManager"):
				get_node("/root/SuspicionManager").call("set_suspicion_multiplier", suspicion_build_multiplier)
		Modifier.ERGONOMIC_MOP:
			cleaning_speed_multiplier = 1.3
		Modifier.HEAVY_LOCK:
			lockpick_cursor_multiplier = 1.35

	return MODIFIER_NAMES[modifier]


func get_modifier_label() -> String:
	return MODIFIER_NAMES.get(current_modifier, "")
