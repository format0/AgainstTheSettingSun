class_name GameCamera
extends Camera2D
## Follows a target with smoothing, stays inside the level and shakes on close lightning.
##
## Screen-space effects (rain, fog, wet ground...) read GameCamera.view_rect to know
## exactly what is on screen this frame.

## World rectangle currently on screen. Updated every frame before other nodes run.
static var view_rect := Rect2(0, 0, 1366, 768)

@export var target: Node2D
## Where the target sits horizontally, as a fraction of the screen width.
@export_range(0.0, 1.0) var target_screen_x := 0.4
@export_range(0.0, 1.0) var target_screen_y := 0.8
@export var follow_speed := 4.5
@export var max_shake := 3.0

var _shake := 0.0


func _ready() -> void:
	process_priority = -50
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position_smoothing_enabled = false
	add_to_group("lightning_listeners")
	add_to_group("game_camera")
	make_current()
	if target:
		global_position = _goal()
	_publish()


func _process(delta: float) -> void:
	if target:
		var goal := _goal()
		global_position = global_position.lerp(goal, 1.0 - exp(-delta * follow_speed))
	_shake *= exp(-delta * 6.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)) * _shake
	_publish()


func snap_to_target() -> void:
	if target:
		global_position = _goal()
		_publish()


func _goal() -> Vector2:
	var vs := get_viewport_rect().size
	var lvl := Level.current
	var w := lvl.level_width if lvl else 100000.0
	var h := lvl.level_height if lvl else vs.y
	var p := target.global_position - Vector2(vs.x * target_screen_x, vs.y * target_screen_y)
	p.x = clampf(p.x, 0.0, maxf(0.0, w - vs.x))
	p.y = clampf(p.y, minf(0.0, h - vs.y), maxf(0.0, h - vs.y))
	return p


func _publish() -> void:
	view_rect = Rect2(global_position + offset, get_viewport_rect().size)


## Called through the "lightning_listeners" group.
func on_lightning(_screen_x: float, strength: float) -> void:
	_shake = maxf(_shake, max_shake * strength)
