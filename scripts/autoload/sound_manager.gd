extends Node
# Autoload: SoundManager
#
# Central sound-effects hub for the whole game. Every clip is synthesized on
# the fly with AudioStreamGenerator (same technique already used in
# inner_voice_manager.gd, choice_overlay.gd and lock_pick_drawer.gd), so the
# project needs zero imported audio assets and stays tiny. A small pool of
# AudioStreamPlayer nodes lets several short sounds overlap without cutting
# each other off, and everything routes through the Master bus so the
# existing HUD mute button (AudioServer.set_bus_mute(0, ...)) silences it.
#
# Usage from anywhere:
#   SoundManager.play_ui_click()
#   SoundManager.play_task_success()
#   SoundManager.play_pickup()
#   SoundManager.play_toggle(true)   # true = switching on, false = off
#   SoundManager.play_footstep()
#   SoundManager.play_alarm()
#   SoundManager.play_suspicion_tick()
#   SoundManager.play_ending(true)   # true = good ending, false = bad ending

const SAMPLE_RATE := 22050.0
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _footstep_toggle: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = 1.2
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % i
		player.stream = stream
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


## Short, bright click for menu/UI buttons and generic interaction presses.
func play_ui_click() -> void:
	_play(0.06, -10.0, func(t: float) -> float:
		var envelope := exp(-t * 90.0)
		return sin(TAU * 1500.0 * t) * envelope
	)


## Cheerful two-note ascending chime for finishing a cleaning/repair task.
func play_task_success() -> void:
	_play(0.32, -8.0, func(t: float) -> float:
		var note_a := 0.0
		var note_b := 0.0
		if t < 0.14:
			note_a = sin(TAU * 660.0 * t) * exp(-t * 16.0)
		if t >= 0.1:
			var t2 := t - 0.1
			note_b = sin(TAU * 880.0 * t2) * exp(-t2 * 12.0)
		return (note_a + note_b) * 0.8
	)


## Bright upward blip for picking up an item (key, collectibles).
func play_pickup() -> void:
	_play(0.18, -9.0, func(t: float) -> float:
		var envelope := exp(-t * 10.0)
		var freq := lerpf(520.0, 980.0, clampf(t / 0.15, 0.0, 1.0))
		return sin(TAU * freq * t) * envelope
	)


## Soft mechanical click for switches, levers and toggled doors.
func play_toggle(turning_on: bool = true) -> void:
	var base_freq := 320.0 if turning_on else 220.0
	_play(0.08, -12.0, func(t: float) -> float:
		var envelope := exp(-t * 70.0)
		return (sin(TAU * base_freq * t) * 0.6 + sin(TAU * base_freq * 2.0 * t) * 0.3) * envelope
	)


## Muffled footstep thump. Call this on a short interval while the player is
## walking; alternates a tiny bit of pitch so a run of steps doesn't sound
## robotic.
func play_footstep() -> void:
	_footstep_toggle = not _footstep_toggle
	var base_freq := 95.0 if _footstep_toggle else 85.0
	_play(0.09, -18.0, func(t: float) -> float:
		var envelope := exp(-t * 38.0)
		var thump := sin(TAU * base_freq * t)
		var noise := (randf() * 2.0 - 1.0) * 0.18
		return (thump * 0.75 + noise) * envelope
	)


## Tense little rising tick, used when suspicion increases noticeably.
func play_suspicion_tick() -> void:
	_play(0.14, -14.0, func(t: float) -> float:
		var envelope := exp(-t * 24.0)
		var freq := lerpf(360.0, 560.0, clampf(t / 0.12, 0.0, 1.0))
		return sin(TAU * freq * t) * envelope
	)


## Short flat buzz for a wrong guess / rejected input (shorter than the
## full alarm siren, which is reserved for getting caught or time running out).
func play_error() -> void:
	_play(0.22, -9.0, func(t: float) -> float:
		var envelope := exp(-t * 9.0)
		return (sin(TAU * 180.0 * t) * 0.7 + sin(TAU * 185.0 * t) * 0.7) * envelope
	)


## Harsh alarm buzzer for getting caught or the timer running out.
func play_alarm() -> void:
	_play(0.7, -6.0, func(t: float) -> float:
		var envelope := 0.5 + 0.5 * sin(TAU * 5.0 * t)
		var siren := sin(TAU * 640.0 * t) + sin(TAU * 900.0 * t) * 0.5
		return siren * envelope * exp(-t * 1.6) * 0.7
	)


## Final stinger played once when the ending screen resolves.
## good = true for the successful ending, false for a failed/compromised run.
func play_ending(good: bool) -> void:
	if good:
		_play(1.0, -6.0, func(t: float) -> float:
			var notes := [523.25, 659.25, 783.99]  # C5, E5, G5
			var total := 0.0
			for i in range(notes.size()):
				var start := i * 0.16
				if t >= start:
					var lt := t - start
					total += sin(TAU * notes[i] * lt) * exp(-lt * 3.0)
			return total * 0.4
		)
	else:
		_play(1.0, -6.0, func(t: float) -> float:
			var notes := [392.0, 349.23, 293.66]  # G4, F4, D4 - a descending, downbeat fall
			var total := 0.0
			for i in range(notes.size()):
				var start := i * 0.2
				if t >= start:
					var lt := t - start
					total += sin(TAU * notes[i] * lt) * exp(-lt * 2.2)
			return total * 0.4
		)


# --- internals ---------------------------------------------------------

func _next_player() -> AudioStreamPlayer:
	var player := _pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _pool.size()
	return player


func _play(duration: float, volume_db: float, recipe: Callable) -> void:
	var player := _next_player()
	player.stop()
	player.volume_db = volume_db
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frame_count := int(SAMPLE_RATE * duration)
	var increment := 1.0 / SAMPLE_RATE
	var t := 0.0
	for i in range(frame_count):
		var sample: float = clampf(recipe.call(t), -1.0, 1.0)
		playback.push_frame(Vector2.ONE * sample)
		t += increment
