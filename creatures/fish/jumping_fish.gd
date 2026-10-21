@tool
@icon("res://creatures/fish/jumping_fish_icon.svg")
class_name JumpingFish
extends Node2D
## Now and then a fish leaps out of the water and drops back with a splash. Place it at the
## water's surface; it jumps anywhere within `width` to the right.

@export var width := 200.0:
	set(v):
		width = v
		queue_redraw()

var _t := -1.0
var _from := Vector2.ZERO
var _span := 0.0
var _height := 0.0
var _wait := 3.0


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.WATER + 1
	_wait = randf_range(2.0, 7.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
			_from = Vector2(randf() * width, 4)
			_span = randf_range(24, 46) * (1.0 if randf() < 0.5 else -1.0)
			_height = randf_range(22, 40)
			get_tree().call_group("splash_emitters", "burst", global_position + _from, 6, 0.7)
	else:
		_t += delta / 0.75
		if _t >= 1.0:
			_t = -1.0
			_wait = randf_range(4.0, 11.0)
			get_tree().call_group("splash_emitters", "burst", global_position + _from + Vector2(_span, 0), 9, 0.8)
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2.ZERO, Vector2(width, 0), Color(0.5, 0.8, 1.0, 0.7), 2.0)
		DrawKit.editor_caption(self, Vector2(0, -4), Color(0.5, 0.8, 1.0, 0.7), "fish")
		return
	if _t < 0.0:
		return
	var p := _from + Vector2(_span * _t, -4.0 * _height * _t * (1.0 - _t))
	var slope := Vector2(_span, -4.0 * _height * (1.0 - 2.0 * _t)).angle()
	draw_set_transform(p, slope, Vector2(1, 1))
	DrawKit.ellipse(self, Vector2.ZERO, Vector2(6, 2.3), 0.0, Color.BLACK, 10)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-10, -3.5 + sin(Weather.time * 30.0)), Vector2(-10, 3.5 + sin(Weather.time * 30.0))]), Color.BLACK)
	draw_set_transform(Vector2.ZERO)
