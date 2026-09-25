extends Node3D
# One of three ending screens, chosen by GameFlow.ending_id (set by
# main_room.gd when the run ends or by the F1/F2/F3 debug shortcuts).

const UiKit = preload("res://scripts/ui_kit.gd")
const GameFlow = preload("res://scripts/game_flow.gd")
const StudyBackdropScript = preload("res://scripts/study_backdrop.gd")
const INTRO_SCENE_PATH := "res://scenes/cutscene_intro.tscn"
const MENU_SCENE_PATH := "res://scenes/start_menu.tscn"

var fade: ColorRect
var body_label: Label
var button_row: HBoxContainer
var type_tween: Tween
var typing_done: bool = false
var leaving: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	var data := _ending_data(GameFlow.ending_id)

	var backdrop := Node3D.new()
	backdrop.set_script(StudyBackdropScript)
	add_child(backdrop)
	backdrop.call("build", data["scene"])

	_build_ui(data)

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.2)
	await tween.finished
	_type_dialogue(data["body"])


func _unhandled_input(event: InputEvent) -> void:
	# Click or press accept to finish the typewriter text instantly.
	if typing_done:
		return
	var skip := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed:
		skip = true
	if skip and type_tween != null and type_tween.is_valid():
		type_tween.kill()
		_finish_typing()


func _ending_data(ending_id: int) -> Dictionary:
	var cam_pos := Vector3(0, 1.5, 2.6)
	var cam_target := Vector3(0, 0.75, -2.0)
	match ending_id:
		2:
			return {
				"title": "ENDING 2: CLEANER SUCCESS — SPY MISSION FAILED",
				"title_color": Color(1.0, 0.78, 0.35, 1),
				"accent": Color(0.9, 0.58, 0.12, 1),
				"body": "You completed every cleaning task, but you did not collect the files, items, or other assets required for the spy objective. The room was cleaned, but the intelligence mission was not completed.",
				"scene": {
					"lamp_on": true,
					"spot_energy": 10.0,
					"fill_energy": 0.8,
					"ambient_color": Color(0.45, 0.38, 0.28, 1),
					"ambient_energy": 0.45,
					"fog_color": Color(0.12, 0.08, 0.04, 1),
					"fog_density": 0.025,
					"window_color": Color(0.75, 0.58, 0.3, 1),
					"moon_energy": 1.8,
					"desk": [],
					"cam_pos": cam_pos,
					"cam_target": cam_target,
				},
			}
		3:
			return {
				"title": "ENDING 3: MISSION SUCCESSFUL",
				"title_color": Color(0.6, 0.95, 0.7, 1),
				"accent": Color(0.3, 0.8, 0.45, 1),
				"body": "Mission accomplished. Every cleaning task is complete, all required files and assets have been collected, and you completed the operation without getting caught. The room is clean and the intelligence is secured.",
				"scene": {
					"lamp_on": true,
					"spot_energy": 14.0,
					"spot_angle": 46.0,
					"fill_energy": 1.4,
					"ambient_color": Color(0.6, 0.5, 0.4, 1),
					"ambient_energy": 0.6,
					"fog_color": Color(0.18, 0.12, 0.08, 1),
					"fog_density": 0.02,
					"window_color": Color(1.0, 0.8, 0.55, 1),
					"moon_energy": 2.5,
					"desk": ["chest", "scroll"],
					"cam_pos": cam_pos,
					"cam_target": cam_target,
				},
			}
		_:
			return {
				"title": "ENDING 1: MISSION FAILED",
				"title_color": Color(1.0, 0.45, 0.42, 1),
				"accent": Color(0.75, 0.12, 0.14, 1),
				"body": "Mission failed. You did not complete the cleaning tasks, and you did not collect any of the files, items, or assets you were sent to retrieve. The operation is over.",
				"scene": {
					"lamp_on": false,
					"ambient_color": Color(0.35, 0.45, 0.7, 1),
					"ambient_energy": 0.35,
					"fog_color": Color(0.05, 0.08, 0.14, 1),
					"fog_density": 0.035,
					"window_color": Color(0.4, 0.55, 0.95, 1),
					"moon_energy": 2.5,
					"desk": [],
					"cam_pos": cam_pos,
					"cam_target": cam_target,
				},
			}


func _build_ui(data: Dictionary) -> void:
	var accent: Color = data["accent"]

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Semi-transparent glass panel along the bottom.
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470.0
	panel.offset_right = 470.0
	panel.offset_top = -320.0
	panel.offset_bottom = -34.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := UiKit.glass_style(
		Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.2, 0.6),
		Color(accent.r, accent.g, accent.b, 0.85),
		4,
		Color(0, 0, 0, 0.6),
		30
	)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	column.add_child(UiKit.label(data["title"], 30, data["title_color"]))

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(accent.r, accent.g, accent.b, 0.8)
	column.add_child(rule)

	body_label = UiKit.label(data["body"], 24, Color(1, 1, 1, 0.96))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(860, 0)
	body_label.visible_ratio = 0.0
	column.add_child(body_label)

	column.add_child(UiKit.label(_stats_text(), 14, Color(0.7, 0.78, 0.9, 0.85)))

	button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 14)
	button_row.modulate.a = 0.0
	column.add_child(button_row)
	var again := UiKit.glass_button("PLAY AGAIN", accent, Vector2(200, 50))
	var menu := UiKit.glass_button("MAIN MENU", accent, Vector2(200, 50))
	var quit := UiKit.glass_button("QUIT", accent, Vector2(140, 50))
	button_row.add_child(again)
	button_row.add_child(menu)
	button_row.add_child(quit)
	again.pressed.connect(_go_to.bind(INTRO_SCENE_PATH))
	menu.pressed.connect(_go_to.bind(MENU_SCENE_PATH))
	quit.pressed.connect(func() -> void: get_tree().quit())

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)


func _stats_text() -> String:
	var seconds := maxi(0, GameFlow.seconds_left)
	return "TASKS  %d / %d      TIME LEFT  %02d:%02d      DIAMOND  %s" % [
		GameFlow.tasks_done,
		GameFlow.tasks_total,
		seconds / 60,
		seconds % 60,
		"TAKEN" if GameFlow.diamond_taken else "LEFT BEHIND",
	]


func _type_dialogue(text: String) -> void:
	type_tween = create_tween()
	type_tween.tween_property(body_label, "visible_ratio", 1.0, maxf(2.0, text.length() * 0.028))
	await type_tween.finished
	_finish_typing()


func _finish_typing() -> void:
	if typing_done:
		return
	typing_done = true
	body_label.visible_ratio = 1.0
	var tween := create_tween()
	tween.tween_property(button_row, "modulate:a", 1.0, 0.5)


func _go_to(path: String) -> void:
	if leaving:
		return
	leaving = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	await tween.finished
	get_tree().change_scene_to_file(path)
