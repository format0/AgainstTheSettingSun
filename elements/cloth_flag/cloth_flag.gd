@tool
@icon("res://elements/cloth_flag/cloth_flag_icon.svg")
class_name ClothFlag
extends Node2D
## A flag on a pole, simulated as a small cloth (verlet points and springs) blowing in the wind.
## The node's position is the foot of the pole.

@export var pole_height := 44.0:
	set(v):
		pole_height = v
		_reset_cloth()
@export var columns := 11
@export var rows := 6
@export var spacing := 4.4

var _pts: Array[Vector2] = []
var _old: Array[Vector2] = []


func _ready() -> void:
	_reset_cloth()


func _reset_cloth() -> void:
	_pts.clear()
	_old.clear()
	for j in rows:
		for i in columns:
			var p := Vector2(-i * spacing, -pole_height + 2.0 + j * spacing * 0.9)
			_pts.append(p)
			_old.append(p)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sub := 3
	var h := minf(delta, 1.0 / 30.0) / sub
	for s in sub:
		for k in _pts.size():
			var i := k % columns
			if i == 0:
				continue
			var j := k / columns
			var gust := 0.55 + 0.45 * sin(Weather.time * 3.1 + i * 0.5 - j * 0.3) * sin(Weather.time * 1.7 + j)
			var force := Vector2(-Weather.wind * (520.0 + 380.0 * gust) * (0.4 + 0.6 * Weather.gust),
				260.0 + sin(Weather.time * 9.0 + i * 0.9) * 160.0 * Weather.wind)
			var v := (_pts[k] - _old[k]) * 0.985
			_old[k] = _pts[k]
			_pts[k] += v + force * h * h
		for it in 3:
			for k in _pts.size():
				var i := k % columns
				var j := k / columns
				if i < columns - 1:
					_link(k, k + 1, spacing)
				if j < rows - 1:
					_link(k, k + columns, spacing * 0.9)
	queue_redraw()


func _link(a: int, b: int, length: float) -> void:
	var d := _pts[b] - _pts[a]
	var dist := maxf(d.length(), 0.001)
	var corr := d * ((dist - length) / dist * 0.5)
	var a_pinned := a % columns == 0
	var b_pinned := b % columns == 0
	if not a_pinned:
		_pts[a] += corr * (1.0 if not b_pinned else 2.0)
	if not b_pinned:
		_pts[b] -= corr * (1.0 if not a_pinned else 2.0)


func _draw() -> void:
	draw_rect(Rect2(-1.0, -pole_height - 4.0, 2.0, pole_height + 4.0), Color.BLACK)
	if _pts.size() != columns * rows:
		return
	var outline := PackedVector2Array()
	for i in columns:
		outline.append(_pts[i])
	for j in range(1, rows):
		outline.append(_pts[j * columns + columns - 1])
	for i in range(columns - 2, -1, -1):
		outline.append(_pts[(rows - 1) * columns + i])
	for j in range(rows - 2, 0, -1):
		outline.append(_pts[j * columns])
	draw_colored_polygon(outline, Color.BLACK)
