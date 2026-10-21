@tool
@icon("res://creatures/plastic_bag/plastic_bag_icon.svg")
class_name PlasticBag
extends Node2D
## A plastic bag that tumbles along the ground in the wind and gets lifted by strong gusts.
## When it leaves the screen downwind it comes back in from the other side.

var _vel := Vector2.ZERO
var _rot := 0.0
var _in_air := false
var _ground_y := 0.0
var _seed := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.CREATURES
	_ground_y = global_position.y
	_seed = randf() * 10.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var g := Weather.gust_at(global_position.x)
	if not _in_air:
		_vel.x += (-Weather.wind * 95.0 * g - _vel.x) * delta * 2.0
		global_position.x += _vel.x * delta
		_rot += _vel.x * delta / 7.0
		global_position.y = _ground_y - absf(sin(_rot * 1.3)) * 1.5
		if g > 0.85 and randf() < delta * 0.8 * Weather.wind:
			_in_air = true
			_vel.y = -randf_range(90.0, 200.0)
	else:
		_vel.x += (-Weather.wind * 170.0 * g - _vel.x) * delta * 1.5
		_vel.y += (110.0 - _vel.y * 0.6) * delta + sin(Weather.time * 4.0 + _seed) * 30.0 * delta
		global_position += _vel * delta
		_rot += delta * 3.0 * signf(_vel.x)
		if global_position.y >= _ground_y:
			global_position.y = _ground_y
			_in_air = false
	var view := GameCamera.view_rect
	if global_position.x < view.position.x - 200.0:
		global_position = Vector2(view.end.x + randf_range(100.0, 500.0), _ground_y)
		_in_air = false
	queue_redraw()


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := i / 10.0 * TAU + _rot
		var r := 6.5 + 2.6 * sin(i * 2.3 + _seed + Weather.time * 6.0) + (2.0 if i % 3 == 0 else 0.0)
		pts.append(Vector2(cos(a) * r * 1.2, -5.0 + sin(a) * r * 0.8))
	draw_colored_polygon(pts, Color.BLACK)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-11, -13, 22, 15)
