extends Node

## AUTOLOAD SINGLETON - register as "InnerVoiceManager"
## (res://scripts/inner_voice_manager.gd).
##
## Disco-Elysium-style inner monologue. Call InnerVoiceManager.queue_thought()
## from anywhere and it handles: queuing (so two thoughts never fight for
## the screen at once), a letter-by-letter reveal, and a short audio cue.
##
## The audio cue is generated in code (a short descending blip) rather than
## loaded from a sound file, so this works immediately with zero asset
## setup. Swap it for a real AudioStream later if you record proper SFX -
## see _play_thought_cue() below, it's fully isolated from everything else.

signal thought_started(persona: String, dialogue_text: String)
signal thought_finished(persona: String)

const TYPE_SPEED_CHARS_PER_SEC: float = 32.0
const FADE_DURATION: float = 0.25

var _queue: Array[Dictionary] = []
var _is_showing: bool = false

var _panel: PanelContainer
var _persona_label: Label
var _body_label: Label
var _audio_player: AudioStreamPlayer


func _ready() -> void:
	# So thoughts can still play out even if you pause the game elsewhere
	# (e.g. your HUD's pause button sets get_tree().paused = true).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_audio_player()


func queue_thought(
	persona: String,
	dialogue_text: String,
	display_duration: float = 4.0,
	accent_color: Color = Color.WHITE
) -> void:
	_queue.append({
		"persona": persona,
		"text": dialogue_text,
		"duration": display_duration,
		"color": accent_color,
	})
	if not _is_showing:
		_advance_queue()


## Drops anything waiting in line - use this if e.g. the game ends and you
## don't want three queued thoughts firing over the ending screen.
func clear_queue() -> void:
	_queue.clear()


func _advance_queue() -> void:
	if _queue.is_empty():
		_is_showing = false
		return
	_is_showing = true
	var thought: Dictionary = _queue.pop_front()
	_show_thought(thought)


func _show_thought(thought: Dictionary) -> void:
	_persona_label.text = String(thought["persona"]).to_upper()
	_persona_label.add_theme_color_override("font_color", thought["color"])
	_body_label.text = thought["text"]
	_body_label.visible_ratio = 0.0
	_panel.modulate.a = 0.0
	_panel.visible = true

	_play_thought_cue()
	thought_started.emit(thought["persona"], thought["text"])

	var fade_in := create_tween()
	fade_in.tween_property(_panel, "modulate:a", 1.0, FADE_DURATION)
	await fade_in.finished

	var char_count: int = String(thought["text"]).length()
	var type_duration := maxf(char_count / TYPE_SPEED_CHARS_PER_SEC, 0.2)
	var type_tween := create_tween()
	type_tween.tween_property(_body_label, "visible_ratio", 1.0, type_duration)
	await type_tween.finished

	await get_tree().create_timer(float(thought["duration"])).timeout

	var fade_out := create_tween()
	fade_out.tween_property(_panel, "modulate:a", 0.0, FADE_DURATION)
	await fade_out.finished
	_panel.visible = false

	thought_finished.emit(thought["persona"])
	_advance_queue()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50 # above the regular HUD
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -280.0
	_panel.offset_right = 280.0
	_panel.offset_top = -190.0
	_panel.offset_bottom = -120.0
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Glass-morphism styling straight from the spec's Section 4B.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.82)
	style.border_color = Color(0.3, 0.6, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)

	_persona_label = Label.new()
	_persona_label.add_theme_font_size_override("font_size", 12)
	_persona_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_persona_label.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(_persona_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1, 1))
	_body_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_body_label.add_theme_constant_override("shadow_offset_y", 1)
	_body_label.visible_ratio = 0.0
	column.add_child(_body_label)

	layer.add_child(_panel)


func _build_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.2
	_audio_player.stream = generator
	add_child(_audio_player)


func _play_thought_cue() -> void:
	# Short, low, descending sine blip - a "thought arriving" cue with no
	# audio asset required. If get_stream_playback() ever comes back null
	# (e.g. the generator hasn't spun up yet) this just silently skips the
	# cue rather than erroring.
	_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var mix_rate := 44100.0
	var sample_count := int(mix_rate * 0.15)
	for i in range(sample_count):
		var t := float(i) / mix_rate
		var frequency := lerpf(220.0, 140.0, float(i) / sample_count)
		var envelope := 1.0 - (float(i) / sample_count)
		var sample := sin(TAU * frequency * t) * 0.25 * envelope
		playback.push_frame(Vector2(sample, sample))
