extends Node
# Autoload: InnerVoiceManager
#
# A small stack of mental personas (GREED, LOGIC, CAUTION, SUSPICION) that
# comment on what the player is doing. Thoughts are queued so they never
# overlap; each one types out letter-by-letter and plays a short, low
# ambient cue when it appears. Builds its own glass-morphism panel in code
# (matching scripts/ui_kit.gd) rather than depending on a .tscn, so it works
# as a bare autoload with no scene wiring required.
#
# Usage from anywhere:
#   InnerVoiceManager.queue_thought("LOGIC", "This carpet fiber has been...")
#   InnerVoiceManager.queue_thought("GREED", "Nobody would know...", 5.0, Color(0.85, 0.65, 0.15))

const UiKit = preload("res://scripts/ui_kit.gd")
const SAMPLE_RATE := 22050.0

# Default accent colors per persona; callers can still override per-call.
const PERSONA_COLORS := {
	"GREED": Color(0.85, 0.62, 0.16, 1),
	"LOGIC": Color(0.35, 0.85, 0.95, 1),
	"CAUTION": Color(0.95, 0.75, 0.25, 1),
	"SUSPICION": Color(0.85, 0.25, 0.3, 1),
}

class Thought:
	var persona: String
	var text: String
	var duration: float
	var color: Color

	func _init(p: String, t: String, d: float, c: Color) -> void:
		persona = p
		text = t
		duration = d
		color = c


var _queue: Array[Thought] = []
var _busy: bool = false

var _layer: CanvasLayer
var _panel: PanelContainer
var _persona_label: Label
var _body_label: Label
var _type_tween: Tween
var _cue_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_audio_cue()


## Queues a thought. Persona should be one of GREED / LOGIC / CAUTION /
## SUSPICION (any string works; unknown personas just use accent_color/white).
func queue_thought(
	persona: String,
	dialogue_text: String,
	display_duration: float = 4.0,
	accent_color: Color = Color.WHITE
) -> void:
	var color := accent_color
	if accent_color == Color.WHITE and PERSONA_COLORS.has(persona):
		color = PERSONA_COLORS[persona]
	_queue.append(Thought.new(persona, dialogue_text, display_duration, color))
	if not _busy:
		_advance_queue()


## Clears anything queued (e.g. on ending trigger) without cutting off the
## thought currently on screen.
func clear_queue() -> void:
	_queue.clear()


func _advance_queue() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var thought: Thought = _queue.pop_front()
	_show_thought(thought)


func _show_thought(thought: Thought) -> void:
	_persona_label.text = thought.persona
	_persona_label.add_theme_color_override("font_color", thought.color)
	_body_label.text = thought.text
	_body_label.visible_ratio = 0.0

	var border_style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	border_style.border_color = Color(thought.color.r, thought.color.g, thought.color.b, 0.6)
	_panel.add_theme_stylebox_override("panel", border_style)

	_play_cue()

	_panel.visible = true
	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(_panel, "modulate:a", 1.0, 0.35)

	_type_tween = create_tween()
	_type_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var type_duration := maxf(0.6, thought.text.length() * 0.03)
	_type_tween.tween_property(_body_label, "visible_ratio", 1.0, type_duration)
	await _type_tween.finished

	await get_tree().create_timer(thought.duration, true).timeout

	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(_panel, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	_panel.visible = false

	_advance_queue()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "InnerVoiceLayer"
	_layer.layer = 40
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.name = "ThoughtPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -300.0
	_panel.offset_right = 300.0
	_panel.offset_top = 26.0
	_panel.offset_bottom = 26.0
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_panel.visible = false

	# Glass-morphism panel per the spec's UI theme.
	var style := UiKit.glass_style(
		Color(0.04, 0.06, 0.09, 0.82),
		Color(0.3, 0.6, 1.0, 0.35),
		10,
		Color(0, 0, 0, 0.5),
		20
	)
	style.set_border_width_all(1)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)

	_persona_label = UiKit.label("LOGIC", 13, PERSONA_COLORS["LOGIC"])
	column.add_child(_persona_label)

	_body_label = UiKit.label("", 17, Color(1, 1, 1, 0.96))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_body_label.add_theme_constant_override("shadow_offset_x", 1)
	_body_label.add_theme_constant_override("shadow_offset_y", 1)
	_body_label.custom_minimum_size = Vector2(556, 0)
	_body_label.visible_ratio = 0.0
	column.add_child(_body_label)


func _build_audio_cue() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.25
	_cue_player = AudioStreamPlayer.new()
	_cue_player.stream = stream
	_cue_player.volume_db = -14.0
	add_child(_cue_player)


func _play_cue() -> void:
	_cue_player.play()
	var playback := _cue_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	# Short, low-frequency "thought bubble" blip - two soft sine pulses.
	var frames := playback.get_frames_available()
	var increment := 1.0 / SAMPLE_RATE
	var t := 0.0
	for i in range(frames):
		var envelope := exp(-t * 14.0) * sin(min(t * 40.0, PI))
		var tone := sin(TAU * 180.0 * t) * 0.5 + sin(TAU * 90.0 * t) * 0.3
		playback.push_frame(Vector2.ONE * tone * envelope * 0.6)
		t += increment
