@tool
@icon("res://environment/cattails/cattails_icon.svg")
class_name Cattails
extends Node2D
## Reeds and bulrushes at the water's edge, their brown heads nodding in the wind.
## Scenery only. The node's position is the left end, on the ground.

@export var width := 90.0:
	set(v):
		width = v
		_grow()
@export var height := 55.0:
	set(v):
		height = v
		_grow()
@export var reed_seed := 1:
	set(v):
		reed_seed = v
		_grow()

var _stems: Array[Vector4] = []


func _ready() -> void:
	_grow()


func _grow() -> void:
	_stems.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = reed_seed
	var x := 0.0
	while x < width:
		_stems.append(Vector4(x, height * rng.randf_range(0.5, 1.1), rng.randf() * TAU, 1.0 if rng.randf() < 0.35 else 0.0))
		x += rng.randf_range(2.5, 7.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	for s in _stems:
		var gust := Weather.gust_at(global_position.x + s.x)
		var bend := -Weather.wind * (0.25 + 0.5 * gust) * 0.5 + sin(t * 1.8 + s.z) * 0.05 * (0.3 + Weather.wind)
		var pts := PackedVector2Array()
		for i in 6:
			var u := i / 5.0
			pts.append(Vector2(s.x + sin(bend) * s.y * u * u, -s.y * u * cos(bend * u)))
		draw_polyline(pts, c, 1.3 if s.w > 0.5 else 1.0)
		if s.w > 0.5:
			var top := pts[5]
			var dir := (pts[5] - pts[4]).normalized()
			DrawKit.limb(self, top - dir * 13.0, top - dir * 3.0, 4.2, 4.2)
		else:
			# a blade leaf curling off the stem
			var p := pts[2]
			draw_polyline(PackedVector2Array([p, p + Vector2(4 + bend * 10.0, -8), p + Vector2(9 + bend * 22.0, -10)]), c, 1.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(0, -height, width, height)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(width, -height), "props": ["width", "height"]}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	width = maxf(10.0, p.x)
	height = maxf(10.0, -p.y)
