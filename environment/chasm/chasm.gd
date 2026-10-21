@tool
@icon("res://environment/chasm/chasm_icon.svg")
class_name Chasm
extends Node2D
## Fills a ravine or a pit with depth: dark rock walls receding into the haze and a darkness
## that thickens towards the bottom, with mist drifting in it, so a gap in the ground reads
## as a drop and not as a window onto the sky. Scenery only (put a KillZone at the bottom).
## The node's position is the top-left corner at the rim.

@export var size := Vector2(400, 200):
	set(v):
		size = v
		_rebuild()
@export var chasm_seed := 1:
	set(v):
		chasm_seed = v
		_rebuild()
@export var mist := true

var _walls: Array[PackedVector2Array] = []


func _ready() -> void:
	z_index = Layers.BACKDROP + 2
	_rebuild()


func _rebuild() -> void:
	_walls.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = chasm_seed
	# two layers of rock walls stepping inwards as they go down
	for layer in 2:
		for side in 2:
			var pts := PackedVector2Array()
			var x0 := 0.0 if side == 0 else size.x
			var dir := 1.0 if side == 0 else -1.0
			pts.append(Vector2(x0, size.y + 40.0))
			pts.append(Vector2(x0, 10.0 + layer * 30.0))
			var y := 10.0 + layer * 30.0
			var reach := 0.0
			while true:
				reach += rng.randf_range(4, 18) * (1.0 + layer)
				y = minf(y + rng.randf_range(12, 30), size.y + 39.0)
				pts.append(Vector2(x0 + dir * minf(reach, size.x * 0.42), y))
				if y >= size.y + 39.0:
					break
			pts.append(Vector2(x0 + dir * minf(reach, size.x * 0.42), size.y + 40.0))
			_walls.append(pts)
	queue_redraw()


func _process(_delta: float) -> void:
	if mist and not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var light := Daylight.light()
	for i in _walls.size():
		var a := 0.55 if i < 2 else 0.8
		draw_colored_polygon(_walls[i], Color(0, 0, 0, a))
	var top := Color(0, 0, 0, 0.3)
	var bottom := Color(0, 0, 0, 1.0)
	var mid_y := size.y * 0.6
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([top, top, bottom, bottom]))
	draw_rect(Rect2(0, mid_y, size.x, size.y * 0.4 + 40.0), bottom)
	if mist:
		var t := Weather.time
		for k in 5:
			var y := size.y * (0.25 + k * 0.13)
			var x := fmod(k * 97.0 - Weather.wind_acc * 40.0 * (1.0 + k * 0.2), size.x + 200.0) - 100.0
			var col := Color(0.55, 0.38, 0.3, 0.07 * light * (1.0 - k * 0.15))
			DrawKit.ellipse(self, Vector2(x, y + sin(t * 0.3 + k) * 6.0), Vector2(120.0 + k * 20.0, 10.0 + k * 3.0), 0.0, col, 20)
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), Color(0.6, 0.6, 0.7, 0.6), "chasm (scenery)")
