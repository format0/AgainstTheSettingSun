@tool
@icon("res://environment/rusty_pipes/rusty_pipes_icon.svg")
class_name RustyPipes
extends Node2D
## A run of old pipe along a wall: flanged joints, brackets, a valve wheel, water dripping from
## a leak. Scenery only. `path` is the run of the pipe (relative to the node).

@export var path := PackedVector2Array([Vector2(0, 0), Vector2(160, 0), Vector2(160, 90)]):
	set(v):
		path = v
		queue_redraw()
@export var thickness := 9.0:
	set(v):
		thickness = v
		queue_redraw()
@export var leaks := true

var _drops: Array[Vector2] = []
var _drip_wait := 0.5


func _ready() -> void:
	z_index = Layers.ELEMENTS_BACK


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or path.size() < 2:
		return
	if leaks:
		_drip_wait -= delta
		if _drip_wait <= 0.0:
			_drip_wait = randf_range(0.3, 1.2)
			_drops.append(path[0].lerp(path[1], 0.62) + Vector2(0, thickness * 0.5))
		for i in _drops.size():
			_drops[i] += Vector2(-Weather.wind * 10.0, 260.0) * delta
		_drops = _drops.filter(func(d): return d.y < path[0].y + 240.0)
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	if path.size() < 2:
		return
	draw_polyline(path, c, thickness, false)
	for p in path:
		draw_circle(p, thickness * 0.5, c)
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var n := dir.orthogonal()
		var k := 40.0
		while k < length - 10.0:
			var p := a + dir * k
			draw_line(p - n * (thickness * 0.5 + 2.5), p + n * (thickness * 0.5 + 2.5), c, 4.0)
			k += 70.0
	if path.size() >= 2:
		var v := path[0].lerp(path[1], 0.3) - Vector2(0, thickness * 0.5 + 8.0)
		draw_line(v, v + Vector2(0, 8), c, 2.0)
		draw_arc(v, 6.0, 0.0, TAU, 16, c, 1.8)
		draw_line(v - Vector2(6, 0), v + Vector2(6, 0), c, 1.2)
	for d in _drops:
		draw_line(d, d + Vector2(0, 3), Color(0.8, 0.75, 0.7, 0.4 * Daylight.light()), 1.0)
