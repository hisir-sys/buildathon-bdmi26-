extends Node3D
# Title screen: dark vintage study behind a glass-style menu.
# The mission briefing is delivered as an FBI secure-channel sequence before the intro starts.

const UiKit = preload("res://scripts/ui_kit.gd")
const StudyBackdropScript = preload("res://scripts/study_backdrop.gd")
const INTRO_SCENE_PATH := "res://scenes/cutscene_intro.tscn"

const BLUE := Color(0.535, 0.743, 0.9, 1)
const GOLD := Color(0.837, 0.748, 0.519, 1)
const FBI_BLUE := Color(0.576, 0.754, 0.9, 1)

var fade: ColorRect
var toast: Label
var toast_tween: Tween
var starting: bool = false
var start_button: Button
var load_button: Button
var quit_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	var backdrop := Node3D.new()
	backdrop.set_script(StudyBackdropScript)
	add_child(backdrop)
	backdrop.call("build", {
		"lamp_on": true,
		"spot_energy": 10.0,
		"spot_angle": 42.0,
		"fill_energy": 0.5,
		"ambient_color": Color(0.32, 0.346, 0.45, 1),
		"ambient_energy": 0.25,
		"fog_color": Color(0.06, 0.08, 0.14, 1),
		"fog_density": 0.04,
		"window_color": Color(0.523, 0.601, 0.81, 1),
		"moon_energy": 1.5,
		"desk": ["chest", "scroll"],
		"cam_pos": Vector3(-0.6, 1.5, 2.7),
		"cam_target": Vector3(-1.2, 1.15, -2.0),
	})
	_build_ui()

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Left half of the screen holds the logo + buttons; the desk sits right.
	var left := Control.new()
	left.anchor_right = 0.55
	left.anchor_bottom = 1.0
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	column.add_child(UiKit.label("A  DARK  NIGHT  SHIFT", 14, Color(0.627, 0.695, 0.81, 0.9), HORIZONTAL_ALIGNMENT_CENTER))

	var title_top := UiKit.label("THE FINAL", 60, Color(0.95, 0.93, 0.88, 1), HORIZONTAL_ALIGNMENT_CENTER)
	title_top.add_theme_constant_override("outline_size", 8)
	title_top.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	column.add_child(title_top)

	var title_main := UiKit.label("CONTRACT", 96, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title_main.add_theme_constant_override("outline_size", 10)
	title_main.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
	column.add_child(title_main)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(380, 2)
	divider.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.8)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(divider)

	column.add_child(UiKit.label("Ten minutes. One house. One choice.", 18, Color(0.7, 0.78, 0.92, 1), HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	column.add_child(spacer)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(buttons)

	start_button = UiKit.glass_button("START", BLUE)
	load_button = UiKit.glass_button("LOAD", BLUE)
	quit_button = UiKit.glass_button("QUIT", BLUE)
	buttons.add_child(start_button)
	buttons.add_child(load_button)
	buttons.add_child(quit_button)
	start_button.pressed.connect(_on_start)
	load_button.pressed.connect(_on_load)
	quit_button.pressed.connect(_on_quit)

	toast = UiKit.label("", 15, Color(0.9, 0.796, 0.639, 1), HORIZONTAL_ALIGNMENT_CENTER)
	toast.modulate.a = 0.0
	column.add_child(toast)


	# Fade layer sits on top of everything.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)


func _on_start() -> void:
	if starting:
		return
	starting = true
	start_button.disabled = true
	load_button.disabled = true
	quit_button.disabled = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.7)
	await tween.finished
	get_tree().change_scene_to_file(INTRO_SCENE_PATH)


func _on_load() -> void:
	# There is no mid-run save (a run is a single 10-minute shift), so this
	# just tells the player so.
	toast.text = "NO SAVED GAME FOUND"
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.6)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)


func _on_quit() -> void:
	get_tree().quit()
