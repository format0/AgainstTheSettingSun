@tool
class_name RunnerAnimator
extends Sprite2D
## Plays the 16-frame run cycle from player/runner_sheet.png.
##
## The cycle advances with the distance actually covered, not with time, so the feet
## never slide: walk into a wall and he stands still, speed up and he strides faster.
## Frames 0, 4, 8 and 12 are the planted foot (used for footstep sounds and splashes).

signal footstep

@export var px_per_frame := 11.0
@export var idle_frame := 1
@export var rising_frame := 3
@export var falling_frame := 2
## Fraction of the frame width where the body's centre line is (keeps flipping stable).
@export var anchor_x := 0.6
## Fraction of the frame height where the soles are.
@export var feet_y := 0.979
@export var draw_scale := 0.5

var _distance := 0.0
var _last_step := -1


func _ready() -> void:
	centered = false
	hframes = 16
	var fw := texture.get_width() / hframes
	offset = Vector2(-anchor_x * fw, -feet_y * texture.get_height())
	scale = Vector2(draw_scale, draw_scale)
	if Engine.is_editor_hint():
		frame = idle_frame   # the editor shows him standing, not the whole sheet


func face(direction: int) -> void:
	scale.x = draw_scale * (1.0 if direction >= 0 else -1.0)


func advance(moved_x: float, on_floor: bool, velocity_y: float) -> void:
	if not on_floor:
		frame = rising_frame if velocity_y < 0.0 else falling_frame
		return
	if absf(moved_x) > 0.05:
		_distance += absf(moved_x)
		frame = int(_distance / px_per_frame) % hframes
		if frame % 4 == 0 and frame != _last_step:
			footstep.emit()
		_last_step = frame
	else:
		frame = idle_frame
		_distance = idle_frame * px_per_frame
		_last_step = -1
