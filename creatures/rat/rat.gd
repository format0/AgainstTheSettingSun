@icon("res://creatures/rat/rat_icon.svg")
class_name Rat
extends Node2D
## A rat that scurries along the ground in short dashes, stops to sniff, and bolts when
## the player comes near. The node's position is where it lives (on the ground).

@export var territory := 140.0

var _home := 0.0
var _facing := 1
var _vx := 0.0
var _timer := 1.0
var _stride := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.CREATURES
	_home = position.x


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	_timer -= delta
	if p and absf(p.global_position.x - global_position.x) < 70.0 and absf(p.global_position.y - global_position.y) < 40.0:
		_facing = 1 if global_position.x > p.global_position.x else -1
		_vx = _facing * 170.0
		_timer = 0.6
	elif _timer <= 0.0:
		if absf(_vx) > 0.0:
			_vx = 0.0
			_timer = randf_range(0.6, 2.5)
		else:
			_facing = 1 if randf() < 0.5 else -1
			if absf(position.x + _facing * 40.0 - _home) > territory:
				_facing = -_facing
			_vx = _facing * randf_range(60, 110)
			_timer = randf_range(0.2, 0.6)
	position.x += _vx * delta
	position.x = clampf(position.x, _home - territory * 1.6, _home + territory * 1.6)
	_stride += absf(_vx) * delta / 4.0
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1))
	var sniff := sin(Weather.time * 18.0) * 0.6 if _vx == 0.0 else 0.0
	var bob := absf(sin(_stride * PI)) * 1.2
	DrawKit.ellipse(self, Vector2(0, -3.5 - bob), Vector2(6.0, 3.2), 0.0, c, 10)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -6 - bob), Vector2(10 + sniff, -3 - bob), Vector2(4, -1.5 - bob)]), c)
	draw_circle(Vector2(3.5, -6.5 - bob), 1.6, c)
	draw_polyline(PackedVector2Array([Vector2(-5, -3), Vector2(-11, -2 + sin(Weather.time * 5.0)), Vector2(-16, -4)]), c, 1.0)
	draw_set_transform(Vector2.ZERO)
