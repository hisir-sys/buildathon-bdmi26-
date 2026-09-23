extends Control

## Plays once at game start. Beats:
##  1) Black screen dialogue (Owner, then Lucas)
##  2) "5 HOURS LATER" time-skip card
##  3) Black fades to reveal the placeholder room
##  4) Phone notification (Owner texting he's almost back)
##  5) Fade to black, big centered timer pops in
##  6) Timer shrinks + flies up into the exact spot/style of the real HUD
##     timer panel, holds, then we cut straight to gameplay - the real panel
##     is pixel-identical, so the cut reads as one continuous object.
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
# offset_left=505, top=24, right=775, bottom=92 -> size 270x68, so with a
# center pivot the panel's on-screen center is (640, 58). Matching this
# exactly is what makes the shrink-into-HUD transition read as one object
# instead of two different things cutting between each other.
const HUD_TIMER_SIZE := Vector2(270.0, 68.0)
const HUD_TIMER_CENTER := Vector2(640.0, 58.0)
const HERO_SCALE := 3.4

var skipped: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	skip_button.pressed.connect(_on_skip_pressed)
	_reset_visual_state()
	_play_cutscene()


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
	notif_sender.text = NOTIF_SENDER
	notif_avatar_letter.text = NOTIF_SENDER.substr(0, 1).to_upper()
	notif_timestamp.text = "now"
	notif_message.text = NOTIF_MESSAGE
	notif_dismiss_bar.size.x = 356.0
	phone_notification.pivot_offset = phone_notification.size * 0.5

	# Slide down with a slight overshoot bounce, like a real banner.
	var tween_in := create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(phone_notification, "position:y", 24.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(phone_notification, "modulate:a", 1.0, 0.3)
	await tween_in.finished
	if skipped:
		return

	# A small tactile "landed" punch.
	var punch := create_tween()
	punch.tween_property(phone_notification, "scale", Vector2(1.03, 1.03), 0.09)
	punch.tween_property(phone_notification, "scale", Vector2.ONE, 0.12)
	await punch.finished

	# Dismiss bar drains over the visible duration - the same "about to
	# auto-close" cue real toast notifications use.
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
	# Back to black before the timer beat.
	await _fade_color_alpha(black_overlay, 0.0, 1.0, 0.7)
	if skipped:
		return

	hero_timer_label.text = "10:00"
	hero_timer_panel.visible = true
	hero_timer_panel.pivot_offset = HUD_TIMER_SIZE * 0.5
	# Position is the fixed top-left of the (never-changing) 270x68 rect;
	# because the pivot is the rect's center, scaling it up around that
	# same fixed point is what makes it appear "screen-centered and huge"
	# without needing a different position for the hero pose.
	hero_timer_panel.position = HUD_TIMER_CENTER - HUD_TIMER_SIZE * 0.5
	hero_timer_panel.scale = Vector2(HERO_SCALE, HERO_SCALE)

	var pop := create_tween()
	pop.tween_property(hero_timer_panel, "modulate:a", 1.0, 0.35)
	await pop.finished
	if skipped:
		return
	await get_tree().create_timer(0.9).timeout
	if skipped:
		return

	# The actual "fly up and shrink into the HUD slot" move: only scale
	# changes, tweening down to 1:1 around the center pivot - which lands
	# it exactly on the real HUD panel's position, size, and style.
	var shrink := create_tween()
	shrink.tween_property(hero_timer_panel, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await shrink.finished
	if skipped:
		return
	await get_tree().create_timer(0.35).timeout


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
