extends Node

## AUTOLOAD SINGLETON - register as "RunGenerator"
## (res://scripts/run_generator.gd).
##
## An autoload has no scene of its own, so there's nothing to drag your
## Marker3D / task nodes into ahead of time in the Inspector. Instead, call
## initialize_run() once from your main room's _ready(), passing in that
## scene's own node references - see the example at the bottom of this
## comment block. After that, the chosen modifier's multipliers are
## readable from anywhere as RunGenerator.cleaning_speed_multiplier, etc.
##
## Example, in main_room.gd:
##
##     func _ready() -> void:
##         var key_markers: Array[Marker3D] = [$KeySpawn_A, $KeySpawn_B, $KeySpawn_C]
##         var task_pool: Array[Node] = [$Task1, $Task2, $Task3, $Task4, $Task5,
##                                        $Task6, $Task7, $Task8, $Task9]
##         RunGenerator.initialize_run(key_markers, $ChestKey, task_pool)

signal run_initialized(modifier_name: StringName, key_spawn_index: int, active_task_indices: Array[int])

enum Modifier { SQUEAKY_SHOES, ERGONOMIC_MOP, HEAVY_LOCK }

const MODIFIER_NAMES: Dictionary = {
	Modifier.SQUEAKY_SHOES: &"Squeaky Shoes",
	Modifier.ERGONOMIC_MOP: &"Ergonomic Mop",
	Modifier.HEAVY_LOCK: &"Heavy Lock",
}

const SQUEAKY_SHOES_SUSPICION_MULTIPLIER: float = 1.2  # +20% faster suspicion build-up
const ERGONOMIC_MOP_SPEED_MULTIPLIER: float = 1.3       # +30% faster cleaning
const HEAVY_LOCK_CURSOR_MULTIPLIER: float = 1.35         # faster lockpick needle

const TOTAL_TASK_POOL_SIZE: int = 9
const ACTIVE_TASK_COUNT: int = 5
const DEACTIVATED_TASK_COUNT: int = 4

var current_modifier: Modifier = Modifier.SQUEAKY_SHOES
# Read these two from your cleaning-task and lock-pick scripts respectively;
# they stay at 1.0 (no-op) unless this run's modifier changes them.
var cleaning_speed_multiplier: float = 1.0
var lockpick_cursor_multiplier: float = 1.0

var chosen_key_spawn_index: int = -1
var active_task_indices: Array[int] = []


func initialize_run(
	key_spawn_markers: Array[Marker3D],
	key_node: Node3D,
	task_pool: Array[Node]
) -> void:
	_spawn_key(key_spawn_markers, key_node)
	_select_active_tasks(task_pool)
	_apply_random_modifier()


func _spawn_key(key_spawn_markers: Array[Marker3D], key_node: Node3D) -> void:
	if key_spawn_markers.is_empty() or key_node == null:
		push_warning("RunGenerator: no key spawn markers / key_node supplied - skipping key placement.")
		return
	chosen_key_spawn_index = randi() % key_spawn_markers.size()
	var chosen_marker := key_spawn_markers[chosen_key_spawn_index]
	key_node.global_transform = chosen_marker.global_transform


func _select_active_tasks(task_pool: Array[Node]) -> void:
	if task_pool.size() != TOTAL_TASK_POOL_SIZE:
		push_warning("RunGenerator: expected a %d-task pool, got %d." % [TOTAL_TASK_POOL_SIZE, task_pool.size()])

	var indices: Array[int] = []
	for i in range(task_pool.size()):
		indices.append(i)
	indices.shuffle()

	var deactivate_count := mini(DEACTIVATED_TASK_COUNT, indices.size())
	active_task_indices = []
	for i in range(indices.size()):
		var pool_index: int = indices[i]
		if i < deactivate_count:
			_deactivate_task(task_pool[pool_index])
		else:
			active_task_indices.append(pool_index)
	active_task_indices.sort()


func _deactivate_task(task_node: Node) -> void:
	# Prefer a task's own set_active(bool) if it has one - implement that
	# on your individual task scripts for tighter control over what
	# "inactive" should mean for that specific task (e.g. also disabling
	# its own outline highlight). Otherwise this falls back to a generic,
	# safe disable that works on any Node3D task.
	if task_node.has_method("set_active"):
		task_node.call("set_active", false)
		return
	if task_node is Node3D:
		(task_node as Node3D).visible = false
	if task_node is Area3D:
		(task_node as Area3D).set_deferred("monitoring", false)
		(task_node as Area3D).set_deferred("monitorable", false)
	task_node.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_random_modifier() -> void:
	current_modifier = Modifier.values()[randi() % Modifier.size()]
	cleaning_speed_multiplier = 1.0
	lockpick_cursor_multiplier = 1.0

	match current_modifier:
		Modifier.SQUEAKY_SHOES:
			SuspicionManager.set_multiplier(SQUEAKY_SHOES_SUSPICION_MULTIPLIER)
		Modifier.ERGONOMIC_MOP:
			cleaning_speed_multiplier = ERGONOMIC_MOP_SPEED_MULTIPLIER
		Modifier.HEAVY_LOCK:
			lockpick_cursor_multiplier = HEAVY_LOCK_CURSOR_MULTIPLIER

	run_initialized.emit(MODIFIER_NAMES[current_modifier], chosen_key_spawn_index, active_task_indices)


## Call at the start of a new run (alongside SuspicionManager.reset_run())
## so re-rolling doesn't inherit the previous run's modifier.
func reset_run() -> void:
	current_modifier = Modifier.SQUEAKY_SHOES
	cleaning_speed_multiplier = 1.0
	lockpick_cursor_multiplier = 1.0
	chosen_key_spawn_index = -1
	active_task_indices.clear()
	SuspicionManager.set_multiplier(1.0)
