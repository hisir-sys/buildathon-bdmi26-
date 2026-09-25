extends CanvasLayer
# LockPickUI - the screen-space timing-bar minigame used by lock_pick_drawer.gd
# (and reusable by any other locked object). Built entirely in code, the same
# way scripts/choice_overlay.gd builds the chest's decision panel, so it
# needs no companion .tscn.
#
# Usage:
#   const LockPickMinigame = preload("res://scripts/tasks/lock_pick_minigame.gd")
#   var minigame := LockPickMinigame.new()
#   get_tree().current_scene.add_child(minigame)
#   minigame.resolved.connect(_on_lockpick_resolved)  # (hit: bool)
#   minigame.start()

signal resolved(hit: bool)
signal cancelled

const TRACK_WIDTH := 520.0
const TRACK_HEIGHT := 14.0
const MIN_TARGET_WIDTH_RATIO := 0.14
const MAX_TARGET_WIDTH_RATIO := 0.22
const LOCKOUT_SECONDS := 2.0

var _needle_speed_px_per_sec: float = 480.0  # scaled by RunGenerator's "Heavy Lock" modifier

var root: Control
var track_bg: ColorRect
var target_zone: ColorRect
var needle: ColorRect
var status_label: Label
var prompt_label: Label

var _needle_pos: float = 0.0
var _needle_dir: int = 1
var _target_start: float = 0.0
var _target_end: float = 0.0
var _running: bool = false
var _locked_out: bool = false
var _resolved: bool = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	var run_generator_path := "res://scripts/autoload/run_generator.gd"
	if ResourceLoader.exists(run_generator_path):
		var RunGeneratorScript := load(run_generator_path)
		_needle_speed_px_per_sec *= float(RunGeneratorScript.lockpick_cursor_multiplier)


## Call once after adding this node to the tree.
func start() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_roll_target()
	_needle_pos = 0.0
	_needle_dir = 1
	_running = true
	_resolved = false
	_locked_out = false
	status_label.text = "SPACE / CLICK TO PICK  •  E TO CLOSE"
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if not _running:
		return
	_needle_pos += _needle_dir * _needle_speed_px_per_sec * delta
	if _needle_pos >= TRACK_WIDTH:
		_needle_pos = TRACK_WIDTH
		_needle_dir = -1
	elif _needle_pos <= 0.0:
		_needle_pos = 0.0
		_needle_dir = 1
	needle.position.x = _needle_pos - (needle.size.x * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_cancel()
		return
	if not _running or _locked_out or _resolved:
		return
	var pressed := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	_attempt_stop()


func _cancel() -> void:
	if _resolved:
		return
	_resolved = true
	_running = false
	_locked_out = false

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 0.0, 0.2)
	await tween.finished

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	cancelled.emit()
	queue_free()


func _attempt_stop() -> void:
	_running = false
	var hit := _needle_pos >= _target_start and _needle_pos <= _target_end
	if hit:
		_finish(true)
	else:
		_locked_out = true
		status_label.text = "MISSED - RESETTING..."
		needle.color = Color(0.9, 0.2, 0.2, 1)
		await get_tree().create_timer(LOCKOUT_SECONDS, true).timeout
		needle.color = Color(0.95, 0.95, 1.0, 1)
		_finish(false)


func _finish(hit: bool) -> void:
	if _resolved:
		return
	_resolved = true
	status_label.text = "UNLOCKED" if hit else "LOCK RESISTS - TRY AGAIN"

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 0.0, 0.3)
	await tween.finished

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	resolved.emit(hit)
	queue_free()


func _roll_target() -> void:
	var ratio := randf_range(MIN_TARGET_WIDTH_RATIO, MAX_TARGET_WIDTH_RATIO)
	var target_width := TRACK_WIDTH * ratio
	_target_start = randf_range(0.0, TRACK_WIDTH - target_width)
	_target_end = _target_start + target_width
	target_zone.position.x = _target_start
	target_zone.size.x = target_width


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate = Color(1, 1, 1, 0)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Glass-morphism panel per the visual spec.
	style.bg_color = Color(0.04, 0.06, 0.09, 0.82)
	style.border_color = Color(0.3, 0.6, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 24
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	prompt_label = Label.new()
	prompt_label.text = "LOCK-PICK"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	column.add_child(prompt_label)

	var track_holder := Control.new()
	track_holder.custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	column.add_child(track_holder)

	track_bg = ColorRect.new()
	track_bg.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	track_bg.color = Color(0.08, 0.09, 0.12, 0.9)
	track_holder.add_child(track_bg)

	target_zone = ColorRect.new()
	target_zone.size = Vector2(80, TRACK_HEIGHT)
	target_zone.color = Color(0.25, 0.9, 0.45, 0.85)
	track_holder.add_child(target_zone)

	needle = ColorRect.new()
	needle.size = Vector2(4, TRACK_HEIGHT + 8)
	needle.position.y = -4.0
	needle.color = Color(0.95, 0.95, 1.0, 1)
	track_holder.add_child(needle)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92, 0.9))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(status_label)
