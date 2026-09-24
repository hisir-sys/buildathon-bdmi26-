extends CanvasLayer

## TASK 1 (minigame half): the lockpicking overlay. Whoever triggers this
## (LockedDrawer.gd, below) instances lock_pick_minigame.tscn, adds it to
## the tree, and connects to lockpick_succeeded / lockpick_failed. This
## scene frees itself after resolving either way - no manual cleanup
## needed by the caller.
##
## Node setup (already built into lock_pick_minigame.tscn - listed here so
## you know what you're looking at if you open it in the editor):
##   CanvasLayer (this script)
##   +- Backdrop          (Control, full rect, dim background)
##      +- Panel          (Panel, glass-morphism style)
##         +- Title       (Label, "PICKING LOCK...")
##         +- Track       (Control, the horizontal bar)
##            +- TrackBG      (ColorRect, dark groove)
##            +- TargetZone   (ColorRect, green - repositioned each attempt)
##            +- Needle       (ColorRect, bright - bounces left/right)
##         +- Hint        (Label, "SPACE / CLICK TO STOP")

signal lockpick_succeeded
signal lockpick_failed

const TRACK_WIDTH: float = 360.0
const NEEDLE_WIDTH: float = 4.0
const MIN_TARGET_WIDTH: float = 46.0
const MAX_TARGET_WIDTH: float = 78.0
const BASE_NEEDLE_SPEED: float = 340.0  # px/sec

@onready var target_zone: ColorRect = $Backdrop/Panel/Track/TargetZone
@onready var needle: ColorRect = $Backdrop/Panel/Track/Needle
@onready var track: Control = $Backdrop/Panel/Track

var _needle_x: float = 0.0
var _direction: float = 1.0
var _needle_speed: float = BASE_NEEDLE_SPEED
var _target_left: float = 0.0
var _target_right: float = 0.0
var _resolved: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Heavy Lock run-modifier (if rolled) speeds the needle up - read
	# straight from RunGenerator rather than duplicating the multiplier here.
	_needle_speed = BASE_NEEDLE_SPEED * RunGenerator.lockpick_cursor_multiplier
	needle.size.x = NEEDLE_WIDTH
	_roll_target_zone()


func _process(delta: float) -> void:
	if _resolved:
		return
	_needle_x += _direction * _needle_speed * delta
	if _needle_x <= 0.0:
		_needle_x = 0.0
		_direction = 1.0
	elif _needle_x >= TRACK_WIDTH - NEEDLE_WIDTH:
		_needle_x = TRACK_WIDTH - NEEDLE_WIDTH
		_direction = -1.0
	needle.position.x = _needle_x


func _unhandled_input(event: InputEvent) -> void:
	if _resolved:
		return
	var wants_to_stop := event.is_action_pressed("ui_accept")  # Space, by default
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		wants_to_stop = true
	if wants_to_stop:
		_resolve_attempt()


func _roll_target_zone() -> void:
	var target_width := randf_range(MIN_TARGET_WIDTH, MAX_TARGET_WIDTH)
	var target_left := randf_range(0.0, TRACK_WIDTH - target_width)
	_target_left = target_left
	_target_right = target_left + target_width
	target_zone.position.x = target_left
	target_zone.size.x = target_width


func _resolve_attempt() -> void:
	_resolved = true
	var needle_center := _needle_x + NEEDLE_WIDTH * 0.5
	var hit := needle_center >= _target_left and needle_center <= _target_right
	if hit:
		lockpick_succeeded.emit()
	else:
		lockpick_failed.emit()
	queue_free()
