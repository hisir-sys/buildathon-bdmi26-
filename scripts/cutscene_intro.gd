extends Control

## Plays once at game start. Beats:
##  1) Black screen dialogue (Owner, then Lucas)
##  2) "5 HOURS LATER" time-skip card
##  3) Black fades to reveal the placeholder room
##  4) Phone notification (Owner texting he's almost back)
##  5) Fade to black, premium mission timer appears large in the center
##  6) Timer smoothly shrinks and flies into the top-center HUD position,
##     then gameplay begins with the same compact timer layout.
##
## Self-contained: touches no existing scripts. GameManager (inside
## main_room.tscn) starts the 10-minute timer itself in _ready(), so
## changing scene at the end IS "starting the timer" - nothing in
## game_manager.gd needs to change.

const GAMEPLAY_SCENE_PATH := "res://scenes/main_room.tscn"

const DIALOGUE_LINES: Array[Dictionary] = [
	{"speaker": "Owner", "text": "I'll be back in six hours. Please get this place cleaned up - I'll pay you well for it."},
	{"speaker": "Lucas", "text": "Yes, don't worry. All of it will be done."},
]

const TIME_SKIP_TEXT := "5 HOURS LATER"
const NOTIF_SENDER := "Owner"
const NOTIF_MESSAGE := "Almost done for the day - I'll be home in 10 mins."
const MISSION_NOTIF_SENDER := "Unknown"
const MISSION_NOTIF_MESSAGE := "You have less time than expected. Collect the DIAMOND, PEN DRIVE, and FILES before you leave."

@onready var black_overlay: ColorRect = $BlackOverlay
@onready var placeholder_room: ColorRect = $PlaceholderRoom
@onready var placeholder_caption: Label = $PlaceholderCaption

@onready var dialogue_block: Control = $DialogueBlock
@onready var speaker_label: Label = $DialogueBlock/SpeakerLabel
@onready var quote_label: Label = $DialogueBlock/QuoteLabel

@onready var time_skip_card: Control = $TimeSkipCard
@onready var time_skip_label: Label = $TimeSkipCard/TimeSkipLabel

@onready var phone_notification: Panel = $PhoneNotification
@onready var notif_avatar_letter: Label = $PhoneNotification/Avatar/AvatarLetter
@onready var notif_sender: Label = $PhoneNotification/SenderLabel
@onready var notif_timestamp: Label = $PhoneNotification/TimestampLabel
@onready var notif_message: Label = $PhoneNotification/MessageLabel
@onready var notif_dismiss_bar: ColorRect = $PhoneNotification/DismissBar

@onready var hero_timer_panel: Panel = $HeroTimerPanel
@onready var hero_timer_label: Label = $HeroTimerPanel/HeroTimerLabel

@onready var skip_button: Button = $SkipButton

# Where the real HUD timer panel lives in main_room.tscn (HUD/TimerPanel):
# hud.gd builds that panel at TIMER_HOUSING_POS/TIMER_HOUSING_SIZE - keep
# these in sync with those constants so the fly-in lands exactly on it.
const HUD_TIMER_SIZE := Vector2(266.0, 78.0)
const HUD_TIMER_CENTER := Vector2(640.0, 65.0)
const HERO_SCALE := 1.55
const HERO_CENTER := Vector2(640.0, 360.0)

var skipped: bool = false
var hero_flip_cards: Array = []

const TIMER_CARD_BG := Color(0.058, 0.066, 0.082, 1)
const TIMER_DIGIT_COLOR := Color(0.93, 0.96, 0.99, 1)
const HERO_CARD_W := 34.0
const HERO_CARD_H := 46.0
const HERO_ROW_WIDTH := 241.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	skip_button.pressed.connect(_on_skip_pressed)
	_reset_visual_state()
	_apply_timer_typography()
	_build_hero_flip_timer()
	_play_cutscene()




func _apply_timer_typography() -> void:
	var timer_font := SystemFont.new()
	timer_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "DejaVu Sans"])
	timer_font.font_weight = 700
	hero_timer_label.add_theme_font_override("font", timer_font)


func _build_hero_flip_timer() -> void:
	var bezel := StyleBoxFlat.new()
	bezel.bg_color = Color(0.018, 0.022, 0.030, 0.96)
	bezel.border_color = Color(0.16, 0.19, 0.24, 0.55)
	bezel.set_border_width_all(1)
	bezel.set_corner_radius_all(12)
	bezel.shadow_color = Color(0, 0, 0, 0.4)
	bezel.shadow_size = 6
	hero_timer_panel.add_theme_stylebox_override("panel", bezel)
	hero_timer_label.visible = false
	var caption_old := get_node_or_null("HeroTimerPanel/HeroTimerCaption") as Label
	if caption_old != null:
		caption_old.visible = false

	for child in hero_timer_panel.get_children():
		if child.name in ["TopLine", "StatusDot", "AccentLine"]:
			child.queue_free()

	for corner in [Vector2(8, 7), Vector2(HUD_TIMER_SIZE.x - 12, 7), Vector2(8, HUD_TIMER_SIZE.y - 11), Vector2(HUD_TIMER_SIZE.x - 12, HUD_TIMER_SIZE.y - 11)]:
		var rivet := Panel.new()
		rivet.position = corner
		rivet.size = Vector2(4, 4)
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rivet_style := StyleBoxFlat.new()
		rivet_style.bg_color = Color(0.16, 0.19, 0.24, 0.9)
		rivet_style.border_color = Color(0.35, 0.4, 0.48, 0.4)
		rivet_style.set_border_width_all(1)
		rivet_style.set_corner_radius_all(2)
		rivet.add_theme_stylebox_override("panel", rivet_style)
		hero_timer_panel.add_child(rivet)

	var caption := Label.new()
	caption.text = "T I M E   R E M A I N I N G"
	caption.position = Vector2(0, 6)
	caption.size = Vector2(HUD_TIMER_SIZE.x, 13)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", Color(0.50, 0.55, 0.62, 0.8))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_timer_panel.add_child(caption)

	var row := HBoxContainer.new()
	row.name = "HeroFlipTimer"
	row.position = Vector2((HUD_TIMER_SIZE.x - HERO_ROW_WIDTH) / 2.0, 24)
	row.size = Vector2(HERO_ROW_WIDTH, HERO_CARD_H)
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_timer_panel.add_child(row)

	hero_flip_cards.clear()
	for i in range(6):
		if i == 2 or i == 4:
			row.add_child(_make_hero_colon_dots())
		var card := _make_hero_flip_card()
		row.add_child(card.card)
		hero_flip_cards.append(card)


func _hero_digit_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Arial Bold", "DejaVu Sans Bold"])
	f.font_weight = 700
	return f


func _make_hero_colon_dots() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(8, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(2):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(5, 5)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = Color(0.55, 0.60, 0.66, 1)
		dot_style.set_corner_radius_all(2)
		dot.add_theme_stylebox_override("panel", dot_style)
		box.add_child(dot)
	return box


func _make_hero_flip_card() -> Dictionary:
	var w := HERO_CARD_W
	var h := HERO_CARD_H
	var card := Panel.new()
	card.custom_minimum_size = Vector2(w, h)
	card.size = Vector2(w, h)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = TIMER_CARD_BG
	card_style.border_color = Color(0, 0, 0, 0.55)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(5)
	card_style.shadow_color = Color(0, 0, 0, 0.3)
	card_style.shadow_size = 2
	card.add_theme_stylebox_override("panel", card_style)

	var font := _hero_digit_font()

	var top_clip := Control.new()
	top_clip.position = Vector2(0, 0)
	top_clip.size = Vector2(w, h / 2.0)
	top_clip.clip_contents = true
	top_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_clip)

	var top_label := Label.new()
	top_label.text = "0"
	top_label.position = Vector2(0, 0)
	top_label.size = Vector2(w, h)
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_label.add_theme_font_override("font", font)
	top_label.add_theme_font_size_override("font_size", 30)
	top_label.add_theme_color_override("font_color", TIMER_DIGIT_COLOR)
	top_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_clip.add_child(top_label)

	var bottom_clip := Control.new()
	bottom_clip.position = Vector2(0, h / 2.0)
	bottom_clip.size = Vector2(w, h / 2.0)
	bottom_clip.clip_contents = true
	bottom_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bottom_clip)

	var bottom_label := Label.new()
	bottom_label.text = "0"
	bottom_label.position = Vector2(0, -h / 2.0)
	bottom_label.size = Vector2(w, h)
	bottom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_label.add_theme_font_override("font", font)
	bottom_label.add_theme_font_size_override("font_size", 30)
	bottom_label.add_theme_color_override("font_color", TIMER_DIGIT_COLOR.darkened(0.15))
	bottom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_clip.add_child(bottom_label)

	var hinge_shadow := ColorRect.new()
	hinge_shadow.position = Vector2(0, h / 2.0 - 1)
	hinge_shadow.size = Vector2(w, 2)
	hinge_shadow.color = Color(0, 0, 0, 0.55)
	hinge_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hinge_shadow)

	var hinge_gloss := ColorRect.new()
	hinge_gloss.position = Vector2(0, h / 2.0 + 1)
	hinge_gloss.size = Vector2(w, 1)
	hinge_gloss.color = Color(1, 1, 1, 0.05)
	hinge_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hinge_gloss)

	var top_gloss := ColorRect.new()
	top_gloss.position = Vector2(0, 0)
	top_gloss.size = Vector2(w, 1)
	top_gloss.color = Color(1, 1, 1, 0.08)
	top_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_gloss)

	return {"card": card, "top": top_label, "bottom": bottom_label}


func _set_hero_flip_timer(value: String) -> void:
	if hero_flip_cards.size() != 6:
		return
	for i in range(6):
		var digit := value.substr(i, 1)
		(hero_flip_cards[i].top as Label).text = digit
		(hero_flip_cards[i].bottom as Label).text = digit


func _reset_visual_state() -> void:
	black_overlay.color.a = 1.0
	placeholder_room.visible = false
	placeholder_caption.visible = false

	dialogue_block.modulate.a = 0.0

	time_skip_card.modulate.a = 0.0

	phone_notification.modulate.a = 0.0
	phone_notification.position.y = -120.0
	phone_notification.scale = Vector2.ONE

	hero_timer_panel.visible = false
	hero_timer_panel.modulate.a = 0.0
	hero_timer_panel.size = HUD_TIMER_SIZE
	hero_timer_panel.pivot_offset = HUD_TIMER_SIZE * 0.5
	hero_timer_panel.position = HUD_TIMER_CENTER - HUD_TIMER_SIZE * 0.5
	hero_timer_panel.scale = Vector2.ONE


func _on_skip_pressed() -> void:
	skipped = true
	_go_to_gameplay()


func _play_cutscene() -> void:
	await _play_dialogue()
	if skipped:
		return
	await _play_time_skip_card()
	if skipped:
		return
	await _reveal_room()
	if skipped:
		return
	await _play_notification()
	if skipped:
		return
	await _play_notification_message(MISSION_NOTIF_SENDER, MISSION_NOTIF_MESSAGE)
	if skipped:
		return
	await _play_hero_timer()
	if skipped:
		return
	_go_to_gameplay()


func _play_dialogue() -> void:
	for line in DIALOGUE_LINES:
		if skipped:
			return
		speaker_label.text = String(line["speaker"]).to_upper()
		quote_label.text = "\"%s\"" % line["text"]
		await _fade_modulate(dialogue_block, 0.0, 1.0, 0.5)
		if skipped:
			return
		await get_tree().create_timer(2.3).timeout
		if skipped:
			return
		await _fade_modulate(dialogue_block, 1.0, 0.0, 0.4)


func _play_time_skip_card() -> void:
	time_skip_label.text = TIME_SKIP_TEXT
	await _fade_modulate(time_skip_card, 0.0, 1.0, 0.5)
	if skipped:
		return
	await get_tree().create_timer(1.6).timeout
	if skipped:
		return
	await _fade_modulate(time_skip_card, 1.0, 0.0, 0.5)


func _reveal_room() -> void:
	placeholder_room.visible = true
	placeholder_caption.visible = true
	await _fade_color_alpha(black_overlay, 1.0, 0.0, 0.8)
	if skipped:
		return
	await get_tree().create_timer(0.5).timeout


func _play_notification() -> void:
	await _play_notification_message(NOTIF_SENDER, NOTIF_MESSAGE)


func _play_notification_message(sender: String, message: String) -> void:
	notif_sender.text = sender
	notif_avatar_letter.text = sender.substr(0, 1).to_upper()
	notif_timestamp.text = "now"
	notif_message.text = message
	notif_dismiss_bar.size.x = 396.0
	phone_notification.pivot_offset = phone_notification.size * 0.5

	# Same notification UI, animation, bounce, and dismiss bar for every message.
	var tween_in := create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(phone_notification, "position:y", 24.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(phone_notification, "modulate:a", 1.0, 0.3)
	await tween_in.finished
	if skipped:
		return

	var punch := create_tween()
	punch.tween_property(phone_notification, "scale", Vector2(1.03, 1.03), 0.09)
	punch.tween_property(phone_notification, "scale", Vector2.ONE, 0.12)
	await punch.finished

	var hold_time := 3.2
	var drain := create_tween()
	drain.tween_property(notif_dismiss_bar, "size:x", 0.0, hold_time).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(hold_time).timeout
	if skipped:
		return

	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(phone_notification, "position:y", -120.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_out.tween_property(phone_notification, "modulate:a", 0.0, 0.3)
	await tween_out.finished


func _play_hero_timer() -> void:
	# Bring the mission clock in on a clean black beat.
	await _fade_color_alpha(black_overlay, 0.0, 1.0, 0.7)
	if skipped:
		return

	_set_hero_flip_timer("001000")
	hero_timer_panel.visible = true
	hero_timer_panel.pivot_offset = HUD_TIMER_SIZE * 0.5

	# Hero pose: large, centered, then it physically travels into the HUD slot.
	hero_timer_panel.position = HERO_CENTER - HUD_TIMER_SIZE * 0.5
	hero_timer_panel.scale = Vector2(HERO_SCALE, HERO_SCALE)
	hero_timer_panel.modulate.a = 0.0

	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(hero_timer_panel, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(hero_timer_panel, "scale", Vector2(HERO_SCALE + 0.08, HERO_SCALE + 0.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	if skipped:
		return

	var settle := create_tween()
	settle.tween_property(hero_timer_panel, "scale", Vector2(HERO_SCALE, HERO_SCALE), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await settle.finished
	if skipped:
		return

	await get_tree().create_timer(0.65).timeout
	if skipped:
		return

	# Main transition: shrink and fly upward at the same time.
	var move_to_hud := create_tween()
	move_to_hud.set_parallel(true)
	move_to_hud.tween_property(hero_timer_panel, "position", HUD_TIMER_CENTER - HUD_TIMER_SIZE * 0.5, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	move_to_hud.tween_property(hero_timer_panel, "scale", Vector2.ONE, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await move_to_hud.finished
	if skipped:
		return

	await get_tree().create_timer(0.3).timeout


func _go_to_gameplay() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)


func _fade_modulate(node: CanvasItem, from_alpha: float, to_alpha: float, duration: float) -> void:
	node.modulate.a = from_alpha
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", to_alpha, duration)
	await tween.finished


func _fade_color_alpha(rect: ColorRect, from_alpha: float, to_alpha: float, duration: float) -> void:
	rect.color.a = from_alpha
	var tween := create_tween()
	tween.tween_property(rect, "color:a", to_alpha, duration)
	await tween.finished
