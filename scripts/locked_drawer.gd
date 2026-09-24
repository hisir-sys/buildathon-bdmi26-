extends StaticBody3D

## TASK 1 (world half): the locked desk drawer that opens the lockpicking
## minigame on interact(). Pairs with lock_pick_minigame.tscn / lock_pick_ui.gd.
##
## Node setup:
##   StaticBody3D (this script)
##   +- MeshInstance3D "DrawerMesh"
##   +- CollisionShape3D
##   +- AnimationPlayer     (needs an "open" animation - slide or rotate
##                            DrawerMesh open; name it whatever you like
##                            and update open_animation_name to match)

const LOCK_PICK_MINIGAME_SCENE := preload("res://scenes/lock_pick_minigame.tscn")

const MISS_LOCKOUT_SECONDS: float = 2.0
const SUCCESS_SUSPICION: float = 5.0
const FAIL_SUSPICION: float = 25.0

@export var animation_player: AnimationPlayer
@export var open_animation_name: String = "open"
@export var metallic_miss_sound: AudioStream
# Placeholder hook - wire this into your actual inventory system;
# left as a plain export + print() so this script compiles and runs
# standalone without needing that system to exist yet.
@export var granted_item_name: String = "Desk Key"

var _is_unlocked: bool = false
var _is_locked_out: bool = false
var _audio_player: AudioStreamPlayer


func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)


## Same interact() convention as your other interactables.
func interact() -> void:
	if _is_unlocked or _is_locked_out:
		return
	var minigame: CanvasLayer = LOCK_PICK_MINIGAME_SCENE.instantiate()
	get_tree().root.add_child(minigame)
	minigame.lockpick_succeeded.connect(_on_lockpick_succeeded)
	minigame.lockpick_failed.connect(_on_lockpick_failed)


func _on_lockpick_succeeded() -> void:
	_is_unlocked = true
	SuspicionManager.add_suspicion(SUCCESS_SUSPICION)
	if animation_player != null:
		animation_player.play(open_animation_name)
	print("Granted item: ", granted_item_name)  # swap for your inventory call


func _on_lockpick_failed() -> void:
	SuspicionManager.add_suspicion(FAIL_SUSPICION)
	if metallic_miss_sound != null:
		_audio_player.stream = metallic_miss_sound
		_audio_player.play()
	_is_locked_out = true
	await get_tree().create_timer(MISS_LOCKOUT_SECONDS).timeout
	_is_locked_out = false
