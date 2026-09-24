extends StaticBody3D

## TASK 2: Crooked Picture Frame.
## Click the frame once to straighten it - a quiet "restoring order" cover
## action that reduces suspicion and reveals a hidden safe code that was
## written on the wall behind it.
##
## Node setup:
##   StaticBody3D (this script) - leave THIS node's own rotation at 0;
##     the crooked look lives on the MeshInstance3D child below, not here,
##     so the CollisionShape3D stays click-accurate even while the frame
##     looks tilted.
##   +- MeshInstance3D "Frame"   (this is what gets tilted/straightened -
##                                  assign it to the frame_mesh export)
##   +- CollisionShape3D          (sized to the frame, for raycast clicking)
##   +- Label3D "SafeCode"        (hidden behind the frame - position it
##                                  slightly behind Frame's mesh along its
##                                  local -Z; starts invisible)

signal straightened

@export var frame_mesh: Node3D
@export var safe_code_label: Label3D
@export var safe_code: String = "4127"
@export var suspicion_reward: float = 10.0
@export var straighten_duration: float = 0.6
@export var initial_tilt_degrees: float = -18.5

var _has_been_interacted: bool = false


func _ready() -> void:
	if frame_mesh != null:
		frame_mesh.rotation_degrees.z = initial_tilt_degrees
	if safe_code_label != null:
		safe_code_label.text = safe_code
		safe_code_label.visible = false


## Matches the interact() convention your other interactable scripts use
## (rewire_task.gd and friends) - your interaction_raycast.gd should
## already call this on click without any extra wiring on your end.
func interact() -> void:
	if _has_been_interacted or frame_mesh == null:
		return
	_has_been_interacted = true

	var tween := create_tween()
	tween.tween_property(frame_mesh, "rotation_degrees:z", 0.0, straighten_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	SuspicionManager.reduce_suspicion(suspicion_reward)
	if safe_code_label != null:
		safe_code_label.visible = true
	straightened.emit()
